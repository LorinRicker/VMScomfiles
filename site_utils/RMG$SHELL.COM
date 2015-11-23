$ ! RMG$SHELL.COM -- RAPT calls to DCL utilities
$ !                                                               'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2004 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1998-2001 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  use:  @RMG$SHELL operation
$ !
$ !  where:  P1 - RAPT support operation to perform in subprocess
$ !               [ PASSWORD | UUENCODE | UUDECODE | DUMPENV ]
$ !          P2 - old password                       ( P1 = PASSWORD )
$ !               file to UUEncode                   ( P1 = UUENCODE )
$ !               file to UUDecode                   ( P1 = UUDECODE )
$ !          P3 - new password                       ( P1 = PASSWORD )
$ !               final destination (path) for image ( P1 = UUDECODE )
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Verbose = F$TRNLNM("TOOLS$DEBUG")
$ IF Verbose
$ THEN ShowTime = ( F$SEARCH("site$utils:dc$datecalc.exe") .NES. "" )
$      IF ShowTime THEN Time_0 = F$TIME()    ! Capture elapsed start time
$ ENDIF
$ !
$ GOTO 'P1'
$ !
$PASSWORD:
$ SF = "sys$scratch:chg_pwd.com"
$ OPEN t 'SF' /WRITE
$ WRITE t "$ SET NOON"
$ WRITE t "$ SET MESSAGE /NOFACILITY /NOIDENTIFICATION /NOSEVERITY"
$ WRITE t "$ SET PASSWORD"
$ WRITE t "''P2'"
$ WRITE t "''P3'"
$ WRITE t "''P3'"
$ WRITE t "$ IF $STATUS THEN WRITE sys$output ""ER PWDOK"""
$ WRITE t "$ DELETE /NOLOG /NOCONFIRM 'F$ENVIRONMENT(""PROCEDURE"")'"
$ WRITE t "$ EXIT"
$ CLOSE t
$ @'SF'
$ IF F$SEARCH(SF) .NES. "" THEN DELETE /NOLOG /NOLOG 'SF';*
$ GOTO Done
$ !
$ ! Prior to VMS v7.2, UCX package provides UCX$UU(EN,DE)CODE.EXE programs;
$ ! With VMS v7.2, TCPIP v5 package provides TCPIP$UU(EN,DE)CODE.EXE programs;
$ ! wildcard search lets us use whatever's available:
$UUENCODE:
$ UU = F$SEARCH("sys$system:*$uuEncode.exe")
$ IF UU .NES. ""
$ THEN Encode = "$" + UU - F$PARSE(UU,,,"VERSION","SYNTAX_ONLY") - F$PARSE(UU,,,"TYPE","SYNTAX_ONLY")
$      WAIT 00:00:01
$      CALL Trap "Encode ''P2' sys$output"
$      IF .NOT. Trap$Status
$      THEN StatusText = F$MESSAGE(Trap$Status)
$           WRITE sys$output "end"
$           WRITE sys$output StatusText
$      ENDIF
$ ENDIF
$ GOTO Done
$ !
$UUDECODE:
$ UU = F$SEARCH("sys$system:*$uuDecode.exe")
$ IF UU .NES. ""
$ THEN Decode = "$" + UU - F$PARSE(UU,,,"VERSION","SYNTAX_ONLY") - F$PARSE(UU,,,"TYPE","SYNTAX_ONLY")
$      WRITE sys$output "SF N=''P2'|T=U"
$      Tmp = P2
$      IF F$LOCATE("\",Tmp) .LT. F$LENGTH(Tmp) THEN Tmp = F$ELEMENT( 1, "\", Tmp )
$! $      CALL Trap "Decode sys$command sys$scratch:''Tmp'"
$! $      GOTO L3
$      OPEN /WRITE uufile sys$scratch:'Tmp'
$L1:
$!      READ /PROMPT="" sys$command uurecord /TIME_OUT=5 /ERROR=L2
$      READ /PROMPT="" sys$command uurecord 
$      WRITE uufile uurecord
$      IF F$LOCATE("end",uurecord) .EQ. F$LENGTH(uurecord) THEN GOTO L1
$      CLOSE uufile
$      Decode sys$scratch:'Tmp' 'P3'
$!! $      SET FILE /ATTR=(RFM:FIX, LRL:512) 'P3'
$      GOTO L3
$L2:   CLOSE uufile
$      WRITE sys$output "ER B=Network timeout receiving file ''P3'. File is not uploaded to server."
$      GOTO Done
$L3:   DELETE /NOLOG sys$scratch:'Tmp';*
$!     WRITE sys$output "ME T=P3 is ''P3'"
$ ENDIF
$ GOTO Done
$ !
$DUMPENV:
$ CALL Trap "SHOW PROCESS /ALL"
$ CALL Trap "SHOW LOGICAL sys$scratch /FULL"
$ CALL Trap "SHOW PROTECTION /DEFAULT"
$ CALL Trap "SHOW WORKING_SET"
$ GOTO Done
$ !
$Done:
$ SET NOON
$ IF F$TYPE(Trap$Status) .NES. "" THEN DELETE /SYMBOL /GLOBAL Trap$Status
$ IF Verbose
$ THEN IF ( F$TYPE(Time_0) .NES. "" ) .AND. ShowTime
$      THEN Days = "$site$utils:dc$datecalc"
$           Days "''Time_0'" /DELTA /SYMBOL=Time_1 /SCOPE=LOCAL
$           WRITE sys$output "ME T=Operation: ''P1' ", F$FAO("%RMG$SHELL-I-ELAPSED, elapsed time is !AS",TIME_1)
$      ENDIF
$ ENDIF
$ EXIT
$ !
$ !
$ !
$Trap:  SUBROUTINE
$ ! P1 - Command to execute
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN EXIT $STATUS
$ F  = "sys$scratch:rmg$shell_dump.lis"
$ wf = "WRITE f"
$ !
$ 'P1'      !command
$ Trap$Status == $STATUS
$ IF Verbose
$ THEN WRITE sys$output F$FAO( "*** %X!XL !AS", Trap$Status, F$MESSAGE(Trap$Status) )
$ ENDIF
$ !
$ IF .NOT. Trap$Status
$ THEN IF F$SEARCH(F) .EQS. ""
$      THEN CREATE 'F'
$           DECK
$           EOD            ! write nothing to it... empty file
$      ENDIF
$      OPEN /APPEND /ERROR=OpenErr f 'F'
$      wf F$FAO( "!#*=", 16 )
$      wf F$FAO( "command: !AS", P1 )
$      wf F$FAO( " status: %X!XL", Trap$Status )
$      wf F$FAO( "!#* !AS", 9, F$MESSAGE(Trap$Status) )
$      wf ""
$      IF F$TRNLNM("f","lnm$process") .NES. "" THEN CLOSE /ERROR=CloseErr f
$ ENDIF
$ EXIT Trap$Status
$ !
$OpenErr:
$ Trap$Status == $STATUS
$ WRITE sys$output "%RMG$SHELL-E-OPENOUT, error opening Trap file ''F' for output"
$ EXIT Trap$Status
$ !
$CloseErr:
$ Trap$Status == $STATUS
$ WRITE sys$output "%RMG$SHELL-E-CLOSERR, error closing Trap file ''F'"
$ EXIT Trap$Status
$ ENDSUBROUTINE  ! Trap
$ !
$Ctrl_Y:
$ RETURN %X2C
