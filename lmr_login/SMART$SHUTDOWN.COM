$ ! SMART$SHUTDOWN.COM --                                          'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1987-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  Perform LOGOUT-type cleanup on behalf of user/manager, then
$ !  shutdown or reboot the system.  Replaces FASTSHUT.COM, and
$ !  redefines SMART's commands SHUTDOWN, REBOOT & FASTSHUT.
$ !
$ !  use:  @SMART$SYSTEM_SHUTDOWNS -
$ !          [ BOUNCE (D) | FASTSHUT
$ !            | SHUTDOWN | REBOOT
$ !            | LOGINS   | NOLOGINS
$ !            | COMMANDS ]
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Verbose = F$TRNLNM("Tools$Debug")
$ !
$ wso = "WRITE sys$output"
$ Fac = F$ENVIRONMENT("PROCEDURE")
$ DD  = F$PARSE(Fac,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(Fac,,,"DIRECTORY","SYNTAX_ONLY")
$ Fac = F$PARSE(Fac,,,"NAME","SYNTAX_ONLY")
$ !
$ NeedPrvs = "AUDIT,CMKRNL,EXQUOTA,LOG_IO,NETMBX,OPER,SECURITY,SYSNAM,SYSPRV,TMPMBX,WORLD"
$ Prv      = F$SETPRV(NeedPrvs)
$ IF .NOT. F$PRIVILEGE(NeedPrvs)
$ THEN wso "%''Fac'-E-PRIVS, insufficient privileges; these are required:"
$      wso "  ''NeedPrvs'"
$      GOTO Done
$ ENDIF
$ !
$ Cmd = "BOUNCE  |FASTSHUT|REBOOT  |SHUTDOWN|LOGINS  |NOLOGINS|COMMANDS"
$ CALL Parse "''F$EXTRACT(0,5,P1)'" Parse$Cmd "BOUNCE" "''Cmd'"
$ IF F$TYPE(Parse$Cmd) .EQS. "" THEN GOTO UndefCmd
$ !
$ GOTO 'Parse$Cmd'
$ !
$UndefCmd:
$ wso "%''Fac'-E-UNDEF_CMD, could not parse command ""''P1'"""
$Done:
$ Prv = F$SETPRV(Prv)
$ EXIT
$ !
$COMMANDS:
$ ComF      = "@" + DD + Fac
$ ! (re)define these commands:
$ bounce   == ComF + " BOUNCE"
$ fastshut == ComF + " FASTSHUT"
$ reboot   == ComF + " REBOOT"
$ shutdown == ComF + " SHUTDOWN"
$ logins   == ComF + " LOGINS"
$ nologins == ComF + " NOLOGINS"
$ GOTO Done
$ !
$LOGINS:
$ NUsers = F$TRNLNM("mgr$interactive_users","lnm$manager")
$ IF NUsers .EQS. "" THEN NUsers = "16"  !guess at a reasonable default...
$ IF Verbose
$ THEN wso "%''Fac'-I-ECHO, $ SET LOGINS /INTERACTIVE=''NUsers'"
$ ELSE SET LOGINS /INTERACTIVE='NUsers'
$ ENDIF
$ GOTO Done
$ !
$NOLOGINS:
$ IF Verbose
$ THEN wso "%''Fac'-I-ECHO, $ SET LOGINS /INTERACTIVE=0"
$ ELSE SET LOGINS /INTERACTIVE=0
$ ENDIF
$ GOTO Done
$ !
$ ! --- No return from here, system will shutdown ---
$BOUNCE:
$ SP1 = "0"
$ SP2 = "System Bounce"
$ SP3 = "NO"
$ SP4 = "YES"
$ SP5 = "soon"
$ SP6 = "YES"
$ SP7 = "REBOOT_CHECK"
$ GOTO DoShutdown
$ !
$FASTSHUT:
$ SP1 = "0"
$ SP2 = "FastShut"
$ SP3 = "NO"
$ SP4 = "YES"
$ SP5 = "soon"
$ SP6 = "NO"
$ SP7 = "REBOOT_CHECK"
$ GOTO DoShutdown
$ !
$REBOOT:
$ SP1 = ""
$ SP2 = "System Reboot"
$ SP3 = "NO"
$ SP4 = "YES"
$ SP5 = "soon"
$ SP6 = "YES"
$ SP7 = "REBOOT_CHECK"
$ GOTO DoShutdown
$ !
$SHUTDOWN:
$ SP1 = ""
$ SP2 = "System Shutdown"
$ SP3 = "NO"
$ SP4 = "YES"
$ SP5 = "later"
$ SP6 = "NO"
$ SP7 = "REBOOT_CHECK"
$ GOTO DoShutdown
$ !
$DoShutdown:
$ ! If using a SMART-style LOGOUT command, then execute a sys$scratch cleanup:
$ IF F$TYPE(LOGOUT) .NES. ""
$ THEN Logout = F$EDIT(Logout,"COMPRESS")
$      LogCmd = F$ELEMENT(0," ",Logout)        !"S" means shutdown-in-progress,
$      LP1    = F$ELEMENT(1," ",Logout) + "S"  !  so logout.com EXITs instead
$      LP2    = F$ELEMENT(2," ",Logout)        !  of logging-out...
$      LP1    = F$EDIT(LP1,"TRIM")
$ ELSE LogCmd = ""
$ ENDIF
$ IF Verbose
$ THEN IF LogCmd .NES. ""
$      THEN wso F$FAO( "%!AS-I-ECHO, $ !AS !AS !AS !!(cleanup sys$scratch:)", -
                       Fac, LogCmd, LP1, LP2 )
$      ENDIF
$      wso F$FAO( "%!AS-I-ECHO, $ @SYS$SYSTEM:SHUTDOWN -",  Fac )
$      wso F$FAO( "!#* ""!AS"" ""!AS"" ""!AS"" ""!AS"" -", -
                  F$LENGTH(Fac)+14, SP1, SP2, SP3, SP4 )
$      wso F$FAO( "!#* ""!AS"" ""!AS"" ""!AS""", -
                  F$LENGTH(Fac)+14, SP5, SP6, SP7 )
$      GOTO Done
$ ELSE IF LogCmd .NES. "" THEN 'LogCmd' 'LP1' 'LP2'
$      @sys$system:shutdown "''SP1'" "''SP2'" "''SP3'" "''SP4'" "''SP5'" "''SP6'" "''SP7'" 
$      ! ...shutdown.com does not return...
$ ENDIF
$ !
$ !
$ !
$Parse: SUBROUTINE
$ ! P1: command to parse
$ ! P2: global symbol to receive answer
$ ! P3: default command
$ ! P4: command set ("C1|C2[|Cn...]") -- options must be same-length fields
$ ! P5: command separator
$ IF P1 .EQS. "" THEN P1 = P3
$ IF P2 .EQS. "" THEN P2 = "Parse$Cmd"
$ IF P5 .EQS. "" THEN P5 = "|"
$ P4 = F$EDIT(P4,"UPCASE")
$ S  = F$LOCATE(P5,P4) + 1               !Determine field length
$ P4 = P5 + P4                           !Add separator to front of list...
$ T  = P5 + F$EDIT(P1,"COLLAPSE,UPCASE") !...and to target
$ L  = F$LOCATE( F$EDIT(T,"COLLAPSE,UPCASE"), P4 )      !Test substring
$ IF ( L .LT. F$LENGTH(P4) ) .AND. ( L-(L/S)*S .EQ. 0 ) !Found?
$ THEN L = ( ( L + 1 ) / S ) + 1                        !Calculate offset
$      'P2' == F$EDIT( F$ELEMENT(L,P5,P4), "COLLAPSE" )
$      EXIT 1
$ ELSE 'P2' == "$Err$"
$      WRITE sys$output "\''P1'\ (expecting: ''F$EDIT(P4,"COLLAPSE")')"
$      EXIT 229522  !%DCL-E-IVVERB, unrecognized command verb
$ ENDIF
$ ENDSUBROUTINE
$ !
$Ctrl_Y:
$ RETURN %X2C
