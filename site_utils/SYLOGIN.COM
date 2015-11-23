$ ! SYLOGIN.COM -- system-wide login procedure
$ Ver = 'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1990-2001 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ SET NOON
$ DEFINE  = "DEFINE /NOLOG"
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ !
$ Scratch = F$SEARCH("sys$login:scratch.dir")
$ IF Scratch .NES. ""
$ THEN SDev = F$PARSE(Scratch,,,"DEVICE")
$      SDir = F$PARSE(Scratch,,,"DIRECTORY") - "]"
$      DEFINE /JOB sys$scratch 'SDev''SDir'.scratch]
$      DEFINE /JOB SortWork0   'SDev''SDir'.scratch]
$      DEFINE /JOB SortWork1   'SDev''SDir'.scratch]
$ ELSE ! A "short-term sanity check", builds confidence or traps problems:
$      IF Verbose THEN MAIL nl: L_RICKER /SUBJ="%SYLOGIN-E, cannot redefine SYS$SCRATCH as [.scratch]"
$ ENDIF
$ !
$ ! *** Just who are you, really?...
$ Usr = F$GETJPI("","UIC") - "[" - "]"    ! e.g., "[BENTON_OR,J_ADAMSKI]"
$ IF F$LOCATE(",",Usr) .NE. F$LENGTH(Usr)
$ THEN Grp = F$ELEMENT(0,",",Usr)         !       "BENTON_OR"
$      Usr = F$ELEMENT(1,",",Usr)         !                  "J_ADAMSKI"
$ ELSE Grp = ""
$ ENDIF
$ RID         = "," + F$GETJPI("","RIGHTSLIST") + ","
$ RIDL        = F$LENGTH(RID)
$ Guest       = ( Grp .EQS. "GUEST" )
$ LTclient    = ( F$LOCATE(",LTCLIENT,",    RID) .LT. RIDL )
$ Trainee     = ( F$LOCATE(",DB_TRAINEE,",  RID) .LT. RIDL )
$ Tester      = ( F$LOCATE(",LT_TESTER,",   RID) .LT. RIDL )
$ ER_Employee = ( F$LOCATE(",E$R_EMPLOYEE,",RID) .LT. RIDL )
$ DbManager   = ( F$LOCATE(",DB_MANAGER,",  RID) .LT. RIDL )
$ Developer   = ( F$LOCATE(",DB_DEVELOPER,",RID) .LT. RIDL )
$ Production  = .NOT. ( Developer .OR. DbManager -
                        .OR. Trainee .OR. Tester .OR. Guest )
$ !
$ GOTO 'F$MODE()'
$ !
$INTERACTIVE:
$ SET MESSAGE site$utils:util_messages
$ !
$ IF F$GETDVI("sys$output","EXISTS")
$ THEN IF F$GETDVI("sys$output","TRM")
$      THEN kp = F$TRNLNM("smsk$keypad")
$           IF kp .NES. "" THEN TQ = "/" + kp
$           ! Add /INQUIRE to non-(DECwindow,OpCon) terminals only:
$           Dvn  = F$GETDVI("sys$output","DEVNAM") - "_" - "_"
$           Dn   = "," + F$EXTRACT(0,2,Dvn) + ","
$           DWt  = ",OP,RT,TK,TW,WT,"
$           DTrm = F$LOCATE(Dn,DWt) .LT. F$LENGTH(DWt)
$           ! Not a DECWindow or OpCon terminal
$           IF .NOT. DTrm THEN TQ = TQ + " /INQUIRE"
$           IF dvn .EQS. "OPA0:" THEN TQ = TQ + " /DEVICE=VT300"
$           IF TQ .NES. ""
$           THEN SET TERMINAL 'TQ'
$           ELSE SET TERMINAL /DEVICE=VT200
$           ENDIF
$           ! A GUI/LTclient session both holds the LTCLIENT rights-id
$           !  *and* responds as a VT100-type terminal:
$           IF LTclient
$           THEN IF ( F$GETDVI("TT","DEVICE_TYPE_NAME") .EQS. "VT100" )
$                THEN SET TERMINAL /NOECHO
$                ELSE ! set-up for TUI by dropping the rights-id
$                     SET RIGHTS_LIST /DISABLE LTCLIENT
$                ENDIF
$           ENDIF
$      ENDIF
$ ENDIF
$ !
$ ! create global DCL symbols for all users:
$ cd      == "@site$utils:cd"
$ cls     == "@site$utils:cls"
$ ked     == "$site$utils:ked"
$ lo*gout == "@site$utils:logout wn"
$ who     == "$site$utils:who"
$ !
$ F = "site$utils:itell.exe"    !new & Improved TELL
$ IF F$SEARCH(F) .NES. "" THEN tell == "$''F'"
$ !
$ ! ==== Lock&Track Online Setup ===
$ !
$LTO_Setup:
$ ! Default for Production, Trainee and Guest users ---
$ !  all of these use the "released-to-production" program tree!
$ LTOLoginDir = F$TRNLNM("LT$Active","lnm$system")
$ !
$ IF ER_Employee
$ THEN IF F$SEARCH("dcl$init") .NES. "" THEN @dcl$init
$      bake    == "@site$utils:bake"
$      bru     == "@site$utils:bru$backup_recover"
$      make    == "@site$utils:make"
$      perl    == "$sys$sysdevice:[decus$freeware.perl]perl.exe"
$      rq      == "@site$utils:rq$interactive"
$      IF F$SEARCH("cd$active:cd$login.com") .NES. "" THEN @cd$active:cd$login
$      IF F$LOCATE(",MANAGER,",RID) .LT. RIDL
$      THEN IF F$SEARCH("mgr$login") .NES. ""
$           THEN @mgr$login                     !set up System Manager context
$           ENDIF
$      ENDIF
$ !    Developers will re-invoke LT$LOGIN via CONTEXT.COM or LTSETUP.COM...
$ ENDIF
$ IF Developer .OR. DbManager
$ THEN LTOLoginDir = F$TRNLNM("LT$DevTree","lnm$system")
$      ! Point LT$(Root,Active) at [LT_DEV] only...
$      Context = F$SEARCH("LT$DevTree:Context.com")
$      IF Context .NES. "" THEN @'Context' LOG
$      GOTO LTO_Continue1
$ ENDIF
$ !
$ IF Tester
$ THEN LTOLoginDir = F$TRNLNM("LT$TestTree","lnm$system")
$      ! Point LT$(Root,Active) at [LT_TEST] only...
$      Context = F$SEARCH("LT$TestTree:Context.com")
$      IF Context .NES. "" THEN @'Context' LOG
$      GOTO LTO_Continue1
$ ENDIF
$ !
$ IF Grp .EQS. "MARION_OR"      !Marion Jail & WC (dev/test only)
$ THEN LTOLoginDir = F$TRNLNM("LT$Active","lnm$job")
$      ! Point LT$(Root,Active) at [MC] only...
$      Context = F$SEARCH("sys$user1:[MC]Context.com")
$      IF Context .NES. "" THEN @'Context' IN
$      GOTO LTO_Continue1
$ ENDIF
$ !
$LTO_Continue1:
$ ! Lock&Track Online customers gravitate to here:
$ ! Define all L&T desktop commands...
$ LTOLogin = F$SEARCH("''LTOLoginDir'lt$login.com")
$ IF LTOLogin .NES. "" THEN @'LTOLogin' SETUP
$ IF Verbose
$ THEN SHOW SYMBOL /LOCAL LTOLoginDir
$      SHOW SYMBOL /LOCAL LTOLogin
$      SHOW SYMBOL /LOCAL RID
$      SHOW SYMBOL /LOCAL Grp
$      SHOW SYMBOL /LOCAL Usr
$ ENDIF
$ !
$ IF ER_Employee .OR. Developer .OR. DbManager
$ THEN SET PROMPT="''F$EDIT(F$GETSYI("SCSNODE"),"COLLAPSE")'$ "
$ ELSE SET PROMPT="LTO$ "
$ ENDIF
$ !
$ !Setup a reasonable/traceable process name for multi-logins (not "_TNAxxx:")
$ PName = F$PROCESS()
$ UName = F$EDIT(F$GETJPI("","USERNAME"),"TRIM")
$ IF PName .NES. UName  !not the first/only login for this user?
$ THEN TName = F$TRNLNM("TT") - "_" - ":"
$      N0 = F$ELEMENT(0,"_",UName)  !"RICKER" from "RICKER_L"
$      N1 = F$ELEMENT(1,"_",UName)  !"RICKER" from "L_RICKER"
$      IF ( F$LENGTH(N1) .GT. 1 ) .AND. ( F$LENGTH(N0) .EQ. 1 ) THEN N0 = N1
$      IF N0 .EQS. "" THEN N0 = UName
$      !Process name becomes "N0 TName" (15-char max):
$      IF TName .NES. PName THEN SET PROCESS /NAME="''F$EXTRACT(0,7,N0)' ''TName'"
$ ENDIF
$ !
$!! $ ! Establish Photo Viewing based on system-logical name for this group:
$!! $ PV = F$EDIT(F$TRNLNM("LT$View_''Grp'"),"COLLAPSE,UPCASE")
$!! $ PM = "LT,TFP"
$!! $ SET RIGHTS_LIST /DISABLE Photo_LT     !start by disabling both methods...
$!! $ SET RIGHTS_LIST /DISABLE Photo_TFP
$!! $ IF PV .NES. ""
$!! $ THEN IF F$LOCATE(PV,PM) .LT. F$LENGTH(PM)
$!! $      THEN SET RIGHTS_LIST /ENABLE Photo_'PV'
$!! $      ENDIF
$!! $ ENDIF
$ !
$ GOTO Done
$ !
$BATCH:
$ SET MESSAGE site$utils:util_messages
$ F = "site$utils:itell.exe" !new & Improved TELL, needed for BACKUP/batch jobs
$ IF F$SEARCH(F) .NES. "" THEN tell == "$''F'"
$ GOTO Done
$ !
$NETWORK:
$OTHER:
$ GOTO Done
$ !
$Done:
$ SET NOON
$ IF F$SEARCH("site$sylogin") .NES. "" THEN @site$sylogin
$ EXIT (%X10000000 .OR. $STATUS) + 0 * F$VERIFY(Ver)
