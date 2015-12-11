$ ! [L_RICKER]LOGIN.COM --                                         'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Lorin Ricker.  Any unauthorized use, reproduction or transfer
$ !  of this program is strictly prohibited.
$ !
$ ! Copyright © 2004-2015 by Lorin Ricker.  All rights reserved.
$ ! Copyright © 2002-2003 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1986-2002 by Evans & Ricker, Inc.  All rights reserved.
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
$ !
$MAIN:
$ ON ERROR THEN GOTO Done
$ ON CONTROL THEN GOSUB Ctrl_Y
$ SET CONTROL=(T,Y)
$ SET PROTECTION=(S:RWED,O:RWED,G,W) /DEFAULT
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
$ !
$ HomeNodes = ",MWC304,"   !,BANDIT,COLT,HARLEY,OUTLAW,"          ! <== customized <== !
$ atHome    = ( F$LOCATE(",''LNode',",HomeNodes) .LT. F$LENGTH(HomeNodes) )
$ !
$ ! Customize this IP-address for client-server PC/VMS-Debug --
$ !  this IP is unwrapped and used by LTSETUP.COM (and others):
$ IF atHome
$ THEN DEFINE /JOB /NOLOG dbg$decw$My_IPAddress "192.169.27.99"  ! mwc304
$ ! "10.0.1.6"    ! <== pony <== !
$ ENDIF
$ !
$ DEFINE /JOB /NOLOG lmr$login 'LBase'.$login],'LBase'.$decw$]
$ DEFINE /JOB /NOLOG decw$user_defaults -
     'LBase'.$DECW$.'LNode'],'LBase'.$DECW$],'LBase']
$ IF Debug
$ THEN SHOW LOGICAL decw$user_defaults
$      dir decw$user_defaults:decw$xdefaults.*
$ ENDIF
$ !
$ GOTO 'F$MODE()'
$ !
$INTERACTIVE:
$ LMR$Unavailable == ""
$ CALL SearchAt lmr$login:common$login.com
$ CALL SearchAt lmr$login:logicals.com
$ IF isTerm
$ THEN wso "..."   !type-ahead ok...
$      !!!SET PROMPT="''LNode'$ "
$      SET PROMPT="''LMR$promptstr'"
$      !!! CALL SearchAt lmr$login:delsymbols.com NO
$      CALL SearchAt com:ansiseq.com
$      CALL SearchAt lmr$login:symbols.com REDEFINE
$      CALL SearchAt dcl$init
$      CALL SearchAt mgr$login
$      IF atHome .AND. ( F$TYPE(cjobs) .EQS. "STRING" ) -
       THEN cjobs  !check periodic jobs
$      CALL SearchAt com:tpu.com
$      dbginit = F$SEARCH("lmr$login:dbg$init.dbg")
$      IF atHome .AND. ( dbginit .NES. "" )
$      THEN DEFINE /JOB /NOLOG dbg$init 'dbginit'
$           wso "%LOGIN-I-DBG$INIT, VMS debugger initialization: "
$           wso "                   DBG$INIT = """,F$TRNLNM("dbg$init"),""""
$      ENDIF
$! $      IF atHome .AND. ( Keyboard .EQS. "PCDECW" )
$! $      THEN xset = "$decw$utils:xset"  !enable auto-repeat for eXcursion
$! $           xset r on
$! $         ! Under eXcursion, debug to TCP/IP PC display:
$! $           IF F$TYPE(IP_Address) .EQS. "STRING" -
$!             THEN DEFINE /JOB /NOLOG dbg$decw$display "''IP_Address':0.0"
$! $      ENDIF
$      ! Setup interactive context:
$      CALL SearchAt sys$disk:[]context.com IN where
$      ! Used for routine/common CD commands, etc.:
$      LoginAux = "sys$login:login$aux.com"
$      LoginAux = F$SEARCH(LoginAux)
$      IF LoginAux .NES. "" THEN @'LoginAux'
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
$ !! IF atHome THEN DEFINE netserver$servers_L_RICKER 8
$ CALL SearchAt lmr$login:logicals.com
$ CALL SearchAt mgr$login
$ Lprv = "sysprv"
$ GOTO Done
$ !
$BATCH:
$ CALL SearchAt lmr$login:logicals.com
$ CALL SearchAt mgr$login
$ subm*it == "SUBMIT /KEEP /NOPRINT /LOG_FILE=logs:"
$ make == "@site$utils:make"
$ !!!«» IF atHome THEN @'LBase'.music]context LOG   !for weekly backup (Music$Database)
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
