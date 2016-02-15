$ ! UAF$DETAILED_ANALYSIS.COM                                      'F$VERIFY(0)'
$ !
$ !  use: @UAF$DETAILED_ANALYSIS [ input_full_sysuaf_listing ] [ output_report ]
$ !
$ ! Copyright © 2014-2015 by Lorin Ricker.  All rights reserved, with acceptance,
$ ! use, modification and/or distribution permissions as granted and controlled
$ ! by and under the GPL described herein.
$ !
$ ! This program (software) is Free Software, licensed under the terms and
$ ! conditions of the GNU General Public License Version 3 as published by
$ ! the Free Software Foundation: http://www.gnu.org/copyleft/gpl.txt,
$ ! which is hereby incorporated into this software and is a non-severable
$ ! part thereof.  You have specific rights and obligations under this GPL
$ ! which are binding if and when you accept, use, modify and/or distribute
$ ! this software program (source code file) and/or derivatives thereof.
$ !
$ ! This command procedure scans a UAF-listing file for:
$ !     inactive accounts that have not been disabled
$ !     disabled accounts
$ !     disabled accounts with new mail
$ !     accounts with excessive new mail
$ !     accounts without sys$login directories
$ !     mail files without an account
$ !
$ ON CONTROL_Y THEN GOTO Abort_Y
$ ON ERROR THEN GOTO Abort
$ !
$ ! Constants
$ NULL   = ""
$ SPACE  = " "
$ COMMA  = ","
$ COLON  = ":"
$ RBRAC  = "]"
$ NONE   = "(none)"
$ INDENT = 3
$ !
$ ! Initialization
$ max_passlife = 180
$ max_lfail    = 0
$ max_prio     = 4
$ min_pwdlen   = 6
$ old_used_abs = F$CVTIME( "-180-", "ABSOLUTE", "DATE" )
$ old_used     = F$CVTIME( old_used_abs, , "date" )
$ !
$ wso = "WRITE sys$output"
$ !
$ ! uafinbrief = "sys$scratch:uaf_brief.list"
$ uafinfull  = "sys$scratch:uaf_full.list"
$ uafreport  = "UAF$DETAIL_ANALYSIS.REPORT"
$ uaftemp    = "sys$scratch:uaf.tmp"
$ uafsort    = "sys$scratch:uaf.srt"
$ !
$ IF ( P1 .NES. NULL )
$ THEN uafinfull = P1
$ ELSE IF ( F$TRNLNM( "sysuaf" ) .EQS. NULL ) THEN DEFINE /USER_MODE sysuaf SYS$SYSTEM:SYSUAF.DAT
$      MCR AUTHORIZE LIST * /FULL
$      uafinfull = "[]sysuaf.lis"
$ ENDIF
$ !
$ ! OPEN /READ  inbrief 'uafinbrief'
$ OPEN /READ  infull  'uafinfull'
$ !
$ ! OPEN /WRITE outbrief 'uaftemp'
$ ! OPEN /WRITE outfile 'uafreport'
$ OPEN /WRITE outfull  'uaftemp'
$ !
$ User$Counter  = 0
$ !               Potential futures: LGICMD AuthorizedPrivileges DefaultPrivileges
$ Valid$Tags    = "\Username\Account\Default\Flags\Expiration\Pwdlifetime\Prio\LastLogin\"
$ Valid$TagsLen = F$LENGTH( Valid$Tags )
$ !
$ ! Get next user from SYSUAF listing, parse...
$Next_User:
$ flags    = NULL
$ passlife = NULL
$ last     = NULL
$ own      = NULL
$ !
$Next_Rec:
$ READ /END_OF_FILE=Do_Report infull rec
$Next2:
$ rec = F$EDIT( rec, "COMPRESS,TRIM" )
$ IF ( rec .EQS. NULL )
$ THEN IF ( User$Counter .GT. 0 ) THEN GOSUB Do_User
$      GOTO Next_User
$ ENDIF
$ !
$ tag = F$EDIT( F$ELEMENT( 0, COLON, rec ), "COLLAPSE" )
$ IF ( F$LOCATE( "\''tag'\", Valid$Tags ) .GE. Valid$TagsLen )
$ THEN GOTO Next_Rec
$ ELSE ! ...a valid tag to proces:
$      GOTO CASE$'tag'
$ ! $CASE$AuthorizedPrivileges:
$ ! $   IF ( User$Counter .GT. 0 ) THEN GOSUB Do_User
$ ! $   GOTO Next_User
$CASE$Username:
$   user = F$ELEMENT( 1, SPACE, rec )
$   own  = F$EDIT( F$ELEMENT( 2, COLON, rec ), "TRIM" )
$   User$Counter = User$Counter + 1
$   GOTO Next_Rec
$CASE$Account:
$   uic = F$EDIT( F$ELEMENT( 2, COLON, rec ), "TRIM" )
$   uic = F$ELEMENT( 0, RBRAC, uic ) + RBRAC
$   GOTO Next_Rec
$CASE$Default:
$ ! here, split on <space> to get the whole Dev:[Dir] --
$   dflt = F$EDIT( F$ELEMENT( 1, SPACE, rec ), "TRIM" )
$   GOTO Next_Rec
$CASE$Flags:
$   flags = F$EDIT( F$ELEMENT( 1, COLON, rec ), "TRIM" )
$   READ /END_OF_FILE=Do_Report infull rec                 ! look-ahead one record...
$   IF F$ELEMENT( 0, COLON, rec ) .NES. COLON THEN GOTO Next2  !   loop-back if next rec is "Primary Days:"...
$   flags = flags + SPACE + rec
$   flags = F$EDIT( flags, "TRIM,COMPRESS" )
$   GOTO Next_Rec
$CASE$Expiration:
$   lfail  = F$EDIT( F$ELEMENT( 3, COLON, rec ), "TRIM" )
$   lfail  = F$INTEGER( lfail )
$   pwdmin = F$ELEMENT( 0, SPACE, F$EDIT( F$ELEMENT( 2, COLON, rec ), "TRIM" ) )
$   pwdmin = F$INTEGER( pwdmin )
$   GOTO Next_Rec
$CASE$Pwdlifetime:
$   passlife = F$INTEGER( F$ELEMENT( 0, SPACE, F$EDIT( F$ELEMENT( 1, COLON, rec ), "TRIM" ) ) )
$   GOTO Next_Rec
$CASE$Prio:
$   baseprio = F$INTEGER( F$ELEMENT( 0, SPACE, F$EDIT( F$ELEMENT( 1, COLON, rec ), "TRIM" ) ) )
$   GOTO Next_Rec
$CASE$LastLogin:
$   last     = F$EDIT( rec, "COMPRESS" )
$   last_int = F$ELEMENT( 2, SPACE, last )
$   last_non = F$EDIT(F$ELEMENT( 1, COMMA, last ), "TRIM" )
$   last_non = F$ELEMENT( 0, SPACE, last_non )
$   GOTO Next_Rec
$ ENDIF
$ !
$ ! All done, display report, clean up & exit
$Do_Report:
$ CLOSE infull
$ ! CLOSE inbrief
$ !
$ CALL Check_Mail
$ CLOSE outfull
$ ! CLOSE outfile
$ !
$ SORT 'uaftemp' 'uafsort'
$ OPEN /READ infull 'uafsort'
$ !
$ last = NULL
$disp:
$ READ /END_OF_FILE=Do_Report2 infull rec
$ rec = F$EDIT( rec, "COMPRESS,TRIM" )
$ reclabel = F$ELEMENT(0, SPACE, rec)
$ IF reclabel .NES. last
$ THEN last = reclabel
$      GOTO 'last'
$1logfail:
$      label = "unreported login failures:"
$      GOTO writesubh
$2defdir:
$      label = "invalid default directories:"
$      GOTO writesubh
$3unused:
$      label = "never been used:"
$      GOTO writesubh
$4old:
$      label = "not been used (logged-in) since ''old_used_abs':"
$      GOTO writesubh
$5disuser:
$      label = "been Disusered:"
$      GOTO writesubh
$6priority:
$      label = "an elevated priority:"
$      GOTO writesubh
$passlife:
$      label = "excessive password lifetimes:"
$      GOTO writesubh
$passlen:
$      label = "short password length requirements:"
$      GOTO writesubh
$passhist:
$      label = "ignore password histories:"
$      GOTO writesubh
$passdict:
$      label = "ignore password dictionary checking:"
$      GOTO writesubh
$passlock:
$      label = "a locked password:"
$      GOTO writesubh
$passnoforce:
$      label = "no requirement to change password during next login:"
$      GOTO writesubh
$xmlnew:
$      label = "unread email:"
$      GOTO writesubh
$xmlfwd:
$      label = "forwarded email:"
$      GOTO writesubh
$xmlinv:
$      label = "an account in VMSMAIL_PROFILE, but not in SYSUAF:"
$      GOTO writesubh
$ !
$writesubh:
$      wso F$FAO( "!#*=", 10 )
$      wso ""
$      wso F$FAO( "These accounts have !AS", label )
$ ENDIF
$ !
$ t1 = F$ELEMENT(1, SPACE, rec)
$ t2 = F$ELEMENT(2, SPACE, rec)
$ !!! wso "rec: \''rec'\  -- t1: \''t1'\  -- t2: \''t2'\"
$ IF t2 .EQS. SPACE
$ THEN wso F$FAO( "!#* !AS", INDENT, t1 )
$ ELSE t1 = t1 + "                               "
$      t1 = F$EXTRACT(0, 31, t1)
$      wso F$FAO( "!#* !AS !AS", INDENT, t1, t2 )
$ ENDIF
$ GOTO disp
$ !
$Do_Report2:
$ CLOSE /NOLOG infull
$ CLOSE /NOLOG outfile
$ !
$ ! IF ( P3 .NES. NULL )
$ ! THEN node = F$GETSYI("nodename")
$ !      MAIL /SUBJECT="UAF report from ''node'" 'uafreport' "''P3'"
$ !      DELETE /NOLOG 'uafreport';*
$ ! ENDIF
$ wso NULL
$ wso "All processing done"
$ GOTO abort
$ !
$Abort_Y:
$ wso "%UAF$DETAILED_ANALYSIS-F-ABORT, user abort"
$ !
$Cleanup:
$Abort:
$ CLOSE /NOLOG outfile
$ CLOSE /NOLOG infull
$ CLOSE /NOLOG outfull
$ IF F$SEARCH( uaftemp )   .NES. NULL THEN DELETE /NOLOG 'uaftemp';*
$ IF F$SEARCH( uafsort )   .NES. NULL THEN DELETE /NOLOG 'uafsort';*
$ !! IF F$SEARCH( uafinfull ) .NES. NULL THEN DELETE /NOLOG 'uafinfull';*
$ EXIT
$ !
$ ! =========
$ !
$ ! Process one user
$Do_User:
$ ! Finish parsing input
$ disuser     = 0
$ dispwdhis   = 0
$ lockpwd     = 0
$ disforcepwd = 0
$ dispwddic   = 0
$ flaglen     = F$LENGTH( flags )
$ IF F$LOCATE("DisUser", flags)             .NE. flaglen THEN disuser = 1
$ IF F$LOCATE("DisPwdHis", flags)           .NE. flaglen THEN dispwdhis = 1
$ IF F$LOCATE("LockPwd", flags)             .NE. flaglen THEN lockpwd = 1
$ IF F$LOCATE("DisForce_Pwd_Change", flags) .NE. flaglen THEN disforcepwd = 1
$ IF F$LOCATE("DisPwdDic", flags)           .NE. flaglen THEN dispwddic = 1
$ !
$ ! Evaluate input for user
$ IF lfail .GT. max_lfail THEN WRITE outfull "1logfail     ''user' ''lfail'"
$ IF disuser
$ THEN WRITE outfull "5disuser    ''user' ''own'"
$      RETURN
$ ENDIF
$ !
$ ! Evaluate input for non-disabled accounts
$ IF ( F$PARSE( dflt ) .EQS. NULL ) .OR. ( dflt .EQS. NULL )
$ THEN WRITE outfull "2defdir        ''user' ''dflt'"
$ ENDIF
$ IF lockpwd
$ THEN WRITE outfull "passlock  ''user'"
$ ELSE IF ( passlife .EQ. 0 ) .OR. ( passlife .GT. max_passlife )
$      THEN WRITE outfull "passlife        ''user' ''passlife'"
$      ENDIF
$      IF pwdmin .LT. min_pwdlen
$      THEN WRITE outfull "passlen ''user' ''pwdmin'"
$      ENDIF
$      IF dispwdhis   THEN WRITE outfull "passhist  ''user'"
$      IF dispwddic   THEN WRITE outfull "passdict  ''user'"
$      IF disforcepwd THEN WRITE outfull "passnoforce     ''user'"
$ ENDIF
$ IF baseprio .GT. max_prio THEN WRITE outfull "6priority  ''user' ''baseprio'"
$ IF ( last_int .EQS. NONE ) .AND. ( last_non .EQS. NONE )
$ THEN WRITE outfull "3unused     ''user' ''own'"
$      RETURN
$ ENDIF
$ IF last_int .NES. NONE
$ THEN last_int = F$CVTIME(last_int,,"date")
$ ELSE last_int = old_used
$ ENDIF
$ IF last_non .NES. NONE
$ THEN last_non = F$CVTIME(last_non,,"date")
$ ELSE last_non = old_used
$ ENDIF
$ IF ( last_int .LES. old_used ) .AND. ( last_non .LES. old_used )
$ THEN WRITE outfull "4old   ''user' ''own'"
$ ENDIF
$ RETURN
$ !
$ ! =========
$ !
$ ! Check mail
$check_mail: SUBROUTINE
$ CLOSE /NOLOG infm
$ CLOSE /NOLOG infull
$ ON WARNING THEN GOTO mail_done
$ ON CONTROL_Y THEN GOTO mail_done
$ flnm = F$PARSE( "VMSMAIL_PROFILE", "SYS$SYSTEM:.DATA" )
$ OPEN /READ /SHARE=WRITE infm 'flnm'
$ flnm = F$PARSE( "SYSUAF", "SYS$SYSTEM:SYSUAF.DAT" )
$ OPEN /READ /SHARE=WRITE infull 'flnm'
$ GOTO loop_mail_first
$loop_mail:
$ IF fwd .NES. NULL THEN write outfull F$FAO("xmlfwd !AS     !AS", user, fwd)
$ IF .NOT. valid
$ THEN WRITE outfull "xmlinv      ''user'"
$ ELSE IF nct .NE. 0 THEN WRITE outfull "xmlnew   ''user' ''nct'"
$ ENDIF
$loop_mail_first:
$ READ /END_OF_FILE=mail_done infm recm
$ user = F$EDIT(F$EXTRACT(0, 31, recm), "trim")
$ recm = F$EXTRACT(31, 9999, recm)
$ nct = 0
$ fwd = NULL
$ valid = 0
$ READ /nolock /key="''user'" /index=0 /match=eq /error=nouser infull recu
$ valid = 1
$nouser:
$ GOTO loop_info
$loop_next_info:
$ IF F$LENGTH(recm) .LE. (4+v2) THEN GOTO loop_mail
$ recm = F$EXTRACT(4+v2, 9999, recm)
$loop_info:
$ IF F$LENGTH(recm) .LT. 2 THEN GOTO loop_mail
$ v1 = F$CVUI(0, 16, recm)
$ v2 = F$CVUI(16, 16, recm)
$ IF (v1 .EQ. 1)
$ THEN nct = F$CVUI(32, v2*8, recm)
$      GOTO loop_next_info
$ ENDIF
$ IF ( v1 .EQ. 2 ) THEN GOTO loop_next_info
$ IF ( v1 .EQ. 3 ) THEN GOTO loop_next_info
$ IF ( v1 .EQ. 4 )
$ THEN fwd = F$EXTRACT(4, v2, recm)
$      GOTO loop_next_info
$ ENDIF
$ IF ( v1 .EQ.  5 ) THEN GOTO loop_next_info
$ IF ( v1 .EQ.  8 ) THEN GOTO loop_next_info
$ IF ( v1 .EQ.  9 ) THEN GOTO loop_next_info
$ IF ( v1 .EQ. 13 ) THEN GOTO loop_next_info
$ WRITE sys$output "Debug: ''user'      ''v1'   ''v2'"
$ GOTO loop_next_info
$mail_done:
$ CLOSE /NOLOG infm
$ CLOSE /NOLOG infull
$ EXIT
$ ENDSUBROUTINE
$ !
