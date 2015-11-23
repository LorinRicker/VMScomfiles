$ ! LTSETUP.COM -- LTClient Environment Setup Script               'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2004 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1998-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  use:  invoked from LTClient's Options | Applications |
$ !          "Run this command file before launching application:"
$ !          check-box/text-box control;
$ !   or:  interactively as:
$ !
$ !        $ @site$utils:LTsetup [ option [ option ]... | ? ]
$ !
$ !  See inline Help for description of options.
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Proc       = F$ENVIRONMENT("PROCEDURE")
$ Fac        = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ wso        = "WRITE sys$output"
$ Redirected = 0
$ Verbose    = 0
$ ! *** LTClient identifies itself as an Interactive VT100 (archaic!)
$ GUI = ( F$MODE() .EQS. "INTERACTIVE" ) -
        .AND. ( F$GETDVI("TT","DEVICE_TYPE_NAME") .EQS. "VT100" )
$ !
$ IF ( F$EXTRACT(0,1,P1) .EQS. "?" ) .OR. ( P1 .EQS. "" )
$ THEN IF GUI
$      THEN GOTO Done  !no place to put help text, so just exit silently...
$      ELSE GOTO Help  ! display help text
$      ENDIF
$ ENDIF
$ !
$ Cmd =  "DUMP       " -
      + "|DEVELOPMENT" -
      + "|TEST       " -
      + "|PRODUCTION " -
      + "|LTONLINE   " -  !synonym PRODUCTION (L&TOnline)
      + "|RMG70      " -
      + "|RMG60      " -
      + "|RAPT       " -  !set RAPT version
      + "|RSET       " -
      + "|MV70       " -
      + "|MV60       " -
      + "|SQLTRACE   " -
      + "|VERBOSE    " -
      + "|DEBUG      "
$ !
$ i = 0
$Loop:                                                            !'F$VERIFY(0)'
$ i = i + 1
$ IF i .GT. 8 THEN GOTO Done
$ Tmp = P'i'
$ IF Tmp .NES. ""
$ THEN ON ERROR THEN GOTO Done
$      CALL Parse "''Tmp'" "CmdOption" "PROD" "''Cmd'"
$      Verbose = F$TRNLNM("Tools$Debug")  !re-eval each loop...
$      GOTO 'F$EXTRACT(0,4,CmdOption)'
$ ENDIF
$ !
$ !  ======================================================================
$ !
$Dump:                                                   !'F$VERIFY(Redirected)'
$ Redirected = 1
$ DumpF = "SYS$SCRATCH:LTSETUP_DUMP.LIS"
$ DEFINE /PROCESS /NOLOG LT$Dump    "YES"
$ DEFINE /PROCESS /NOLOG sys$output 'DumpF'
$ wso F$FAO("!80*=")
$ wso "%''Fac'-I-DUMP, dump output file is ''DumpF'"
$ !'F$VERIFY(Redirected)' ...SYS$OUTPUT redirected
$ GOTO Loop
$ !
$Deve:                                                   !'F$VERIFY(Redirected)'
$Development:                                            !'F$VERIFY(Redirected)'
$ wso "%''Fac'-I-SET, context is Lock&Track DEVELOPMENT"
$ CtxF = "LT$DevTree:context.com"
$ IF F$SEARCH(CtxF) .NES. ""
$ THEN @'CtxF' $DEV
$      !'F$VERIFY(Redirected)' ...SYS$OUTPUT redirected
$ ELSE wso "%''Fac'-F-SET, failed to set DEVELOPMENT context"
$ ENDIF
$ GOTO Loop
$ !
$Test:                                                   !'F$VERIFY(Redirected)'
$LTTe:                                                   !'F$VERIFY(Redirected)'
$ wso "%''Fac'-I-SET, context is Lock&Track TEST"
$ CtxF = "LT$TestTree:context.com"
$ IF F$SEARCH(CtxF) .NES. ""
$ THEN @'CtxF' IN
$      !'F$VERIFY(Redirected)' ...SYS$OUTPUT redirected
$ ELSE wso "%''Fac'-F-SET, failed to set TEST context"
$ ENDIF
$ GOTO Loop
$ !
$Prod:                                                   !'F$VERIFY(Redirected)'
$Production:                                             !'F$VERIFY(Redirected)'
$LTOn:                                                   !'F$VERIFY(Redirected)'
$LTOnline:                                               !'F$VERIFY(Redirected)'
$ wso "%''Fac'-I-SET, context is Lock&Track PRODUCTION"
$ CtxF = "LT$ProdTree:context.com"
$ IF F$SEARCH(CtxF) .NES. ""
$ THEN @'CtxF' IN
$      !'F$VERIFY(Redirected)' ...SYS$OUTPUT redirected
$ ELSE wso "%''Fac'-F-SET, failed to set PRODUCTION context"
$ ENDIF
$ GOTO Loop
$ !
$RMG7:                                                   !'F$VERIFY(Redirected)'
$ R7Msg = "%''Fac'-W-NO_RAPT070, RAPT v7.0 is not available on this system"
$ Ctxt = "site$sources:[rmg070]context.com"
$ IF F$SEARCH(Ctxt) .NES. ""
$ THEN wso "%''Fac'-I-SET, LockWorks RAPT/RMG v7.0 Test Environment"
$      @'Ctxt' IN
$      !'F$VERIFY(Redirected)' ...SYS$OUTPUT redirected
$ ELSE wso R7Msg
$ ENDIF
$ GOTO Loop
$ !
$RMG6:                                                   !'F$VERIFY(Redirected)'
$ R6Msg = "%''Fac'-W-NO_RAPT060, RAPT v6.0 is not available on this system"
$ Ctxt = "site$sources:[rmg060]context.com"
$ IF F$SEARCH(Ctxt) .NES. ""
$ THEN wso "%''Fac'-I-SET, LockWorks RAPT/RMG v6.0 Test Environment"
$      @'Ctxt' IN
$      !'F$VERIFY(Redirected)' ...SYS$OUTPUT redirected
$ ELSE wso R6Msg
$ ENDIF
$ GOTO Loop
$ !
$RAPT:                                                   !'F$VERIFY(Redirected)'
$RSET:                                                   !'F$VERIFY(Redirected)'
$ IF P2 .NES. ""
$ THEN RAPTV = P2
$      P2 = ""    ! don't reparse this one in main-loop
$ ELSE RAPTV = "070"
$ ENDIF
$ RAPTV = RAPTV - "V" - "v" - "." - "." - "-"
$ RAPTVL = F$LENGTH(RAPTV)
$ IF RAPTVL .EQ. 1 THEN RAPTV = "0" + RAPTV + "0"
$ IF RAPTVL .EQ. 2 THEN RAPTV = "0" + RAPTV
$ MVMsg = "%''Fac'-W-NO_RAPT_MV, RAPT_''RAPTV' multiversion not available"
$ RSet  = "site$utils:RAPT$SetVer.com"
$ RSet  = F$SEARCH(RSet)
$ RF    = "site$utils:RMG$FRONT_NET_''RAPTV'.EXE"
$ RF    = F$SEARCH(RF)
$ IF RAPTV .LTS. "070"
$ THEN RdbV = "70"  !RAPT v6.0 compatible with Rdb v7.0-x only
$ ELSE RdbV = "71"  !RAPT v7.0 compatible with Rdb v7.1 only
$ ENDIF
$ IF ( RSet .NES. "" ) .AND. ( RF .NES. "" )
$ THEN @'RSet' 'RAPTV' /RDB='RdbV'
$      !'F$VERIFY(Redirected)' ...SYS$OUTPUT redirected
$ ELSE wso MVMsg
$ ENDIF
$ GOTO Loop
$ !
$MV70:                                                   !'F$VERIFY(Redirected)'
$ MVMsg = "%''Fac'-W-NO_RAPT_MV, RAPT v7.0 multiversion not available"
$ RSet  = "site$utils:RAPT$SetVer.com"
$ RSet  = F$SEARCH(RSet)
$ RF    = "site$utils:RMG$FRONT_NET_070.EXE"
$ RF    = F$SEARCH(RF)
$ IF ( RSet .NES. "" ) .AND. ( RF .NES. "" )
$ THEN @'RSet' 7 /RDB=71  !RAPT v7.0 compatible with Rdb v7.1 only
$      !'F$VERIFY(Redirected)' ...SYS$OUTPUT redirected
$ ELSE wso MVMsg
$ ENDIF
$ GOTO Loop
$ !
$MV60:                                                   !'F$VERIFY(Redirected)'
$ MVMsg = "%''Fac'-W-NO_RAPT_MV, RAPT v6.0 multiversion not available"
$ RSet  = "site$utils:RAPT$SetVer.com"
$ RSet  = F$SEARCH(RSet)
$ RF    = "site$utils:RMG$FRONT_NET_060.EXE"
$ RF    = F$SEARCH(RF)
$ IF ( RSet .NES. "" ) .AND. ( RF .NES. "" )
$ THEN @'RSet' 6 /RDB=70  !RAPT v6.0 compatible with Rdb v7.0-x only
$      !'F$VERIFY(Redirected)' ...SYS$OUTPUT redirected
$ ELSE wso MVMsg
$ ENDIF
$ GOTO Loop
$ !
$SQLT:                                                   !'F$VERIFY(Redirected)'
$SQLTrace:                                               !'F$VERIFY(Redirected)'
$ IF F$TRNLNM("RDBVMS$VERSION") .GES. "7.1"
$ THEN Flg = "TRACE"
$ ELSE Flg = "Xt"
$ ENDIF
$ @site$utils:rdbflags "''Flg'" sys$scratch:sql_trace.lis
$ !'F$VERIFY(Redirected)' ...SYS$OUTPUT redirected
$ GOTO Loop
$ !
$Verb:                                                   !'F$VERIFY(Redirected)'
$Verbose:                                                !'F$VERIFY(Redirected)'
$ TDebug = "site$utils:tools$debug.com"
$ IF F$SEARCH(TDebug) .NES. ""
$ THEN @'TDebug' ON
$      !'F$VERIFY(Redirected)' ...SYS$OUTPUT redirected
$ ELSE DEFINE /JOB /NOLOG Tools$Debug "TRUE"
$      wso "%''Fac'-I-VERBOSE, verbose mode is ON (Tools$Debug=""TRUE"")"
$ ENDIF
$ GOTO Loop
$ !
$Debu:                                                   !'F$VERIFY(Redirected)'
$Debug:                                                  !'F$VERIFY(Redirected)'
$ !'F$VERIFY(Redirected)' ...SYS$OUTPUT redirected
$ wso "%''Fac'-I-SET, context is DEBUG"
$ IPAddress = F$TRNLNM("DBG$DECW$My_IPAddress")
$ IF IPAddress .NES. ""
$ THEN SET DISPLAY /CREATE /TRANSPORT=TCPIP /NODE="''IPAddress'"
$      SHOW DISPLAY
$      DEFINE /JOB /NOLOG dbg$decw$display decw$display
$      wso "%''Fac'-I-SET, DECWindows debugging on ",F$TRNLNM("dbg$decw$display")
$ ENDIF
$!DEFINE /JOB /NOLOG RMG$DEBUG_FLAGS G,sys$scratch:ltclient_trace.lis
$ GOTO Loop
$ !
$Done:                                                            !'F$VERIFY(0)'
$ IF Verbose .OR. Redirected
$ THEN wso "%''Fac'-I-LOGICAL, LT$Active   = ""''F$TRNLNM("LT$ACTIVE")'"""
$      wso "%''Fac'-I-LOGICAL, LT$Root     = ""''F$TRNLNM("LT$ROOT")'"""
$      wso "%''Fac'-I-LOGICAL, RMG$Back    = ""''F$TRNLNM("RMG$BACK_RDB")'"""
$      wso "%''Fac'-I-LOGICAL, RMG$Front   = ""''F$TRNLNM("RMG$FRONT_SMG")'"""
$      wso "%''Fac'-I-LOGICAL,             = ""''F$TRNLNM("RMG$FRONT_NET")'"""
$      wso "%''Fac'-I-LOGICAL, Rdb Version = ""''F$TRNLNM("RDBVMS$IDENT")'"""
$ ENDIF
$ IF Redirected
$ THEN wso "%''Fac'-I-EXITING, exiting..."
$      wso F$FAO("!80*=")
$      DEASSIGN /PROCESS sys$output
$      DEFINE /PROCESS /NOLOG LT$Dump "YES"
$ ENDIF
$ EXIT 1
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$Parse: SUBROUTINE
$ ! P1: command to parse
$ ! P2: global symbol to receive answer
$ ! P3: default command
$ ! P4: command set ("C1|C2[|Cn...]") -- options must be same-length fields
$ ! P5: command separator
$ SET NOON
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
$ ENDSUBROUTINE  !Parse
$ !
$ !  ======================================================================
$ !
$Help:
$ TYPE /PAGE sys$input

  LTSETUP.COM is a "login-helper" command procedure which can establish
  specific Lock&Track development, testing or production runtime contexts,
  which is especially useful when running L&T desktop applications in the
  LTClient (GUI).

  LTSETUP is most typically invoked from the LTClient Options | Applications
  tab's "Run this command file before launching application:" check-box and
  text-box.  The check-box enables or disables the text-box; the text-box
  then has text similar to the following:  [4m@site$utils:ltsetup [option...][0m

  Use:  $ [1m@SITE$UTILS:LTSetup[0m [ [1moption[0m [ [1moption[0m ]... ]

  where [1moption[0m is one or more of the following option-commands; if
  more than one [1moption[0m is used, they are separated by blanks (spaces).
  Options can be abbreviated to a minimum of four (4) characters, and
  may be in either UPPER or lower case (case-insensitive).

  [1mDUMP[0m        -- Redirects all command file output (SYS$OUTPUT) to the
                 file SYS$SCRATCH:LTSETUP_DUMP.LIS, permitting you to
                 review the actions of this command file from the point
                 that DUMP is invoked.  This option also sets the /PROCESS
                 logical name LT$DUMP to "YES", which may trigger similar
                 dump-file redirection by successor command files such as
                 DESKTOP_STARTUP.COM.

  [1mDEVELOPMENT[0m -- Establishes a Production context (using /JOB and/or
                 /PROCESS logical names for all relevant components)
                 for the L&T desktop application:
                 $ @LT$DevTree:CONTEXT $DEV.

  [1mTEST[0m        -- Establishes a Testing context (using /SYSTEM logical
                 names for all relevant components) for the L&T desktop
                 application:  $ @LT$TestTree:CONTEXT IN.

  [1mPRODUCTION[0m  -- Establishes a Production context (using /SYSTEM logical
                 names for all relevant components) for the L&T desktop
                 application:  $ @LT$ProdTree:CONTEXT IN.

  [1mRMG70[0m       -- Attempts to execute the SITE$SOURCES:[RMG070]CONTEXT.COM,
                 if that development directory is available; this command
                 file establishes a test/evaluation version of RAPT v7.x
                 as your runtime environment for this session.  If this
                 development directory kit is not available on the system,
                 an error message is generated and the original RAPT/Rdb
                 context is preserved.

  [1mRMG60[0m       -- Attempts to execute the SITE$SOURCES:[RMG060]CONTEXT.COM,
                 if that development directory is available; this command
                 file establishes a test/evaluation version of RAPT v6.x
                 as your runtime environment for this session.  If this
                 development directory kit is not available on the system,
                 an error message is generated and the original RAPT/Rdb
                 context is preserved.

  [1mRAPT[0m        -- Attempts to execute [1m$ RAPTSETVERSION 'RAPTV' /RDB='RdbV'[0m to
                 establish a MulitVersion RAPT vX.X Kit context. If a vX.X
                 multiversion kit is not available on the system, an error
                 message is generated and the original RAPT/Rdb context is
                 preserved.  You must specify the RAPT version to use as P2.

  [1mMV70[0m        -- Attempts to execute [1m$ RAPTSETVERSION 7.0 /RDB=7.1[0m to
                 establish a MulitVersion RAPT v7.0 Kit context. If a v7.0
                 multiversion kit is not available on the system, an error
                 message is generated and the original RAPT/Rdb context is
                 preserved.  Deprecated - use RAPT option instead.

  [1mMV60[0m        -- Attempts to execute [1m$ RAPTSETVERSION 6.0 /RDB=7.0[0m to
                 establish a MulitVersion RAPT v6.0 Kit context. If a v6.0
                 multiversion kit is not available on the system, an error
                 message is generated and the original RAPT/Rdb context is
                 preserved.  Deprecated - use RAPT option instead.

  [1mSQLTRACE[0m    -- Enables the Rdb TRACE ("Xt") debug flag for stored-SQL
                 routine tracing/output.  The trace output is captured in
                 the file SYS$SCRATCH:SQL_TRACE.LIS.

  [1mVERBOSE[0m     -- Sets the /JOB logical name TOOLS$DEBUG to "TRUE", typically
                 enabling verbose trace-output from various command files.

  [1mDEBUG[0m       -- Enables LTclient-VMS/server (client-server) command conver-
                 sation tracing, the output of which is captured in the file
                 SYS$SCRATCH:LTCLIENT_TRACE.LIS.

                 Also optionally enables DECwindows/Windows-style application
                 debugging.  To enable this application debugging, you must:
                 
                 a) ensure that the target application program is correctly
                    compiled and linked for debugging.
                 b) Ensure that the logical name DBG$DECW$MY_IPADDRESS is
                    defined at the /GROUP or /SYSTEM level (global to your
                    interactive process to ensure visibility), and that its
                    value is that of your PC/workstation's IP address, in the
                    form "XXX.XXX.XXX.XXX" (e.g., "216.15.207.1").  This IP
                    address provides the VMS Debugger with the PC-location
                    where the Debugger window will be displayed.

                 If the logical name DBG$DECW$MY_IPADDRESS is not defined,
                 remote PC/workstation debugging will not be established;
                 however, LTclient-server command conversation tracing will
                 be logged.


  [4mExamples[0m

  These examples are shown invoked interactively from a DCL command prompt;
  omit the dollar-sign "$" when invoking LTSETUP from LTClient's Options |
  Application | "Run this command file before launching application:" command
  in the text-box.  You may use UPPER/lower case to enhance readability; the
  command is processed case-insensitively.

  1.  A developer setting up a desktop application in Developer context,
      running the application from the LT$DevTree directory tree and
      typically connecting to the LT$Development database:

      $ [1m@site$utils:LTsetup DEVELOPMENT[0m

  2.  As above, but also enabling dump-file (specified first to see maximal
      dump-output) and verbose tracing:

      $ [1m@site$utils:LTsetup DUMP VERBOSE DEVEL[0m

  3.  A developer needs to turn on stored-SQL routine tracing on the Prod-
      uction database:

      $ [1m@site$utils:LTsetup PROD SQLTRACE[0m

  4.  A developer needs to run a new application, designed for RAPT v7.0
      and Rdb v7.1, in a default/production multiversion environment at
      RAPT v6.0 and Rdb v7.0:

      $ [1m@site$utils:LTsetup DEVEL RMG70[0m

$ !
$ GOTO Done
