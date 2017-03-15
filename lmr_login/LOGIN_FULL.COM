$ ! [L_RICKER]LOGIN.COM --                                         'F$VERIFY(0)'
$ !
$ ! Copyright � 1986-2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$SearchAt:  SUBROUTINE
$ ! P1: com-file to check & invoke
$ ! P2: arg-string for com-file
$ ! P3: alternative command (if com-file not found)
$ ! P4: verbose flag
$ SET NOON
$ IF F$SEARCH(P1) .NES. ""
$ THEN IF P4 THEN wso "  (...@''P1')"
$      @'P1' 'P2'
$ ELSE IF P3 .EQS. "" THEN P3 = "CONTINUE"
$      'P3'
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Trace:  SUBROUTINE
$ SET NOON
$ Term = F$GETJPI("","TERMINAL")
$ IF Term .NES. "" THEN Term = Term + F$STR(F$GETDVI(Term,"TRM"))
$ SOut = F$GETDVI("sys$output","DEVNAM")
$ SOut = SOut + F$STR(F$GETDVI("sys$output","TRM"))
$ DEFINE /PROCESS sys$error f
$ DEFINE /PROCESS sys$output f
$ WRITE f F$GETJPI("","PID"), -
          "  ", F$GETJPI("","PRCNAM"), -
          "  ", F$GETJPI("","MODE"), -
          "  ", Term, -
          "  ", SOut
$ EXIT 1
$ ENDSUBROUTINE
$ !
$VMS$Install:  SUBROUTINE
$ SET NOON
$ LF[0,32]=10
$ CR[0,32]=13
$ CRLF = CR + LF
$ READ sys$command Answer /END_OF_FILE=VMIDone -
    /PROMPT="Log this VMSINSTAL session to file [[1m<filename>[0m (Yes), [1mN[0m or [1mCtrl/Z[0m]: "
$ Answer = F$EDIT(Answer,"COLLAPSE,UPCASE")
$ IF Answer .EQS. "N"
$ THEN wso F$FAO("!AS!78*=!AS",CRLF,CRLF)
$      Prv = F$SETPRV("ALL")
$      @sys$update:vmsinstal  ! deletes all process global symbols...
$      Prv = F$SETPRV(Prv)
$      wso F$FAO("!AS!78*=!AS",CRLF,CRLF)
$      @sys$sylogin           ! restore global symbols & context...
$ ELSE SLog = F$PARSE(Answer,"VMSINSTAL","sys$scratch:.log",,"SYNTAX_ONLY")
$      wso ""
$      wso "%LOGIN-I-LOGGING, logging VMSINSTAL session to ''SLog'"
$      wso ""
$      wso "      -I-VMSINSTAL, login to account, then use [1m$ @SYS$UPDATE:VMSINSTAL[0m"
$      wso ""
$      wso "      -I-PRIVILEGES, [4mbe sure to acquire appropriate privileges[0m"
$      ! If SMART$SetHost.com is available, use it:
$      IF F$TYPE(SetHost) .EQS. "STRING"
$      THEN SetHost 0 "''SLog'"
$      ELSE ! hope for the best (on a foreign system):
$           wso F$FAO("!AS!78*-!AS",CRLF,CRLF)
$           DEFINE /USER_MODE sys$input sys$command
$           TELNET /LOG='SLog' localhost  !or SET HOST 0 /LOG='SLog'
$      ENDIF
$      wso ""
$      DIRECTORY /SIZE /DATE 'SLog' /SINCE
$      wso F$FAO("!AS!78*-!AS",CRLF,CRLF)
$ ENDIF
$VMIDone:
$ EXIT 1
$ ENDSUBROUTINE  ! VMS$Install
$ !
$PureDCL: SUBROUTINE
$ SET NOON
$ ! Sanity check for site-specific global string, make it go away!...
$ IF ( F$TYPE('P1') .EQS. "STRING" )
$ THEN DELETE = "DELETE"
$      DEFINE /NOLOG /USER_MODE sys$output NLA0:
$      DEFINE /NOLOG /USER_MODE sys$error  NLA0:
$      DELETE /SYMBOL /GLOBAL 'P1'
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! PureDCL
$ !
$ !
$MAIN:
$ ON ERROR THEN GOTO Done
$ ON CONTROL THEN GOSUB Ctrl_Y
$ !      
$ SET CONTROL=(T,Y)
$ SET PROTECTION=(S:RWED,O:RWED,G,W) /DEFAULT
$ !
$ CALL PureDCL "DELETE"
$ CALL PureDCL "COPY"
$ CALL PureDCL "RENAME"
$ CALL PureDCL "PURGE"
$ CALL PureDCL "DIRECTORY"
$ CALL PureDCL "SEARCH"
$ !
$ ! Copy-a-new-version-of-self support:
$ IF ( P1 .EQS. "NEW" )
$ THEN IF ( F$SEARCH("sys$login:LOGIN_FULL.COM") .NES. "" )
$      THEN COPY /LOG lmr$login:LOGIN_FULL.COM sys$login:*.*
$      ELSE COPY /LOG lmr$login:LOGIN_FULL.COM sys$login:LOGIN.*
$      ENDIF
$      PURGE /SINCE  /NOLOG sys$login:LOGIN*.COM
$      PURGE /KEEP=2 /NOLOG sys$login:LOGIN*.COM
$      EXIT 1  ! 'F$VERIFY(0)'
$ !    ======
$ ENDIF
$ !
$ Interactive = ( F$MODE() .EQS. "INTERACTIVE" )
$ Lprv = ""
$ wso  = "WRITE sys$output"
$ DD = F$ENVIRONMENT("PROCEDURE")
$ DD = F$PARSE(DD,"sys$login","sys$disk:[]","DEVICE","SYNTAX_ONLY") -
     + F$PARSE(DD,"sys$login","sys$disk:[]","DIRECTORY","SYNTAX_ONLY")
$ !
$ ! LTclient?
$ IF Interactive .AND. (F$GETDVI("TT","DEVICE_TYPE_NAME") .EQS. "VT100") THEN EXIT
$ !      
$ ! Debugging support:
$ Debug = ( P1 .EQS. "DEBUG" )
$ IF Debug
$ THEN ver = F$VERIFY(1)
$      OPEN /WRITE f 'DD'login.log
$      CALL Trace
$ ENDIF
$ !
$ ! Support for VMSINSTAL, with restoration...
$ IF Interactive .AND. ( P1 .EQS. "VMSINSTAL" ) THEN CALL VMS$Install
$ !
$ isTerm = ""
$ Term   = F$GETJPI("","TERMINAL")
$ IF Term .NES. "" THEN isTerm = F$GETDVI(Term,"TRM")
$ LNode  = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ LBase  = F$TRNLNM("sys$login_device") -
         + "[" + F$EDIT(F$GETJPI("","USERNAME"),"TRIM")
$ DEFINE /JOB /NOLOG lmr$login 'LBase'.login]    !!,'LBase'.$decw$]
$ !
$ HomeNodes = ",CLASS8,VMSPR1,VMSPR3,"   ! <== customized <== !
$ atHome    = ( F$LOCATE(",''LNode',",HomeNodes) .LT. F$LENGTH(HomeNodes) )
$ !
$ GOTO 'F$MODE()'
$ !
$INTERACTIVE:
$ LMR$Unavailable == ""
$ CALL SearchAt lmr$login:common$login.com
$ CALL SearchAt lmr$login:logicals.com
$ IF isTerm
$ THEN wso "..."   !type-ahead ok...
$      !!! CALL SearchAt lmr$login:delsymbols.com NO
$      CALL SearchAt com:ansiseq.com
$      CALL SearchAt lmr$login:symbols.com REDEFINE
$      CALL SearchAt lmr$login:Ruby_Setup.com
$      IF ( F$TYPE( LMR$promptstr ) .EQS. "STRING" )
$      THEN SET PROMPT="''LMR$promptstr'"
$      ELSE SET PROMPT="''LNode'$ "
$      ENDIF
$      CALL SearchAt dcl$init
$!! $  !!! retired --> CALL SearchAt mgr$login
$      CALL SearchAt com:tpu.com
$      dbginit = F$SEARCH("lmr$login:dbg$init.dbg")
$      IF atHome .AND. ( F$TYPE(cjobs) .EQS. "STRING" ) THEN cjobs  !check periodic jobs
$      IF atHome .AND. ( dbginit .NES. "" )
$      THEN DEFINE /JOB /NOLOG dbg$init 'dbginit'
$           wso "%LOGIN-I-DBG$INIT, VMS debugger initialization: "
$           wso "                   DBG$INIT = """,F$TRNLNM("dbg$init"),""""
$      ENDIF
$ ENDIF
$LogSpecific:
$ !Invoke an optional, site-specific, personal <Locale>_SPECIFIC$LOGIN.COM:
$ LoginSpecific = "sys$login:login$specific.dat"  !contains NAME of locale
$ IF F$SEARCH(LoginSpecific) .NES. ""
$ THEN OPEN /READ /ERROR=LS0 ls 'LoginSpecific'
$      READ /ERROR=LS1 ls LoginWhere
$      !1st record/row is name of locale (customer), e.g., "NTS", "MC", etc.
$      IF F$TYPE(LoginWhere) .EQS. "STRING"
$      THEN CALL SearchAt lmr$login:'LoginWhere'_specific$login.com "" "" "TRUE"
$      ENDIF
$LS1:  IF F$TRNLNM("ls") .NES. "" THEN CLOSE ls
$ ENDIF
$LS0:  ! Also provide for Node-specific processing:
$ IF F$TYPE(LNode) .EQS. "STRING"
$ THEN CALL SearchAt lmr$login:'LNode'_specific$login.com "" "" "TRUE"
$ ENDIF
$ wso ""
$ !
$ GOTO Done
$ !
$NETWORK:
$ CALL SearchAt lmr$login:logicals.com
$!! $ !! IF atHome THEN DEFINE netserver$servers_L_RICKER 8
$!! $ !!! retired --> CALL SearchAt mgr$login
$ Lprv = "sysprv"
$ GOTO Done
$ !
$BATCH:
$ CALL SearchAt lmr$login:logicals.com
$!! $ !!! retired --> CALL SearchAt mgr$login
$ subm*it == "SUBMIT /KEEP /NOPRINT /LOG_FILE=logs:"
$ make == "@site$utils:make"
$ !!!�� IF atHome THEN @'LBase'.music]context LOG   !for weekly backup (Music$Database)
$ GOTO Done
$ !
$OTHER:
$ CALL SearchAt lmr$login:logicals.com
$ GOTO Done
$ !
$Done:
$ SET NOON
$ IF Lprv .NES. "" THEN Lprv = F$SETPRV(Lprv)
$ ! Debugging support:
$ IF Debug
$ THEN DEASSIGN /PROCESS sys$output
$      DEASSIGN /PROCESS sys$error
$      CLOSE f
$ ENDIF
$ EXIT 1
$ !
$Ctrl_Y:
$ RETURN %X2C