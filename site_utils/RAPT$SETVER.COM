$ ! RAPT$SETVER.COM --                                             'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2004 by LockWorks LLC.  All rights reserved.
$ !
$ !  v1.5 - Make all /SYSTEM logicals /EXECUTIVE_MODE too.         07/20/04 LMR
$ !         Improve subroutine DeaLog (clean up "everything").
$ !         Improve debug/verbose output. 
$ !         Oops, including RMGNET.EXE, too.
$ !  v1.4 - Added support for RMG$SHELL                            04/01/04 LMR
$ !  v1.3 - Added legal versions for RAPT v7.1,...                 02/26/04 LMR
$ !  v1.2 - Added logical names for compiling purposes:            11/26/02 LMR
$ !         PASCAL$RMG_ROUTINES, RMG_LINK
$ !  v1.1 - Added /RDB=version qualifier to permit simultaneous    11/25/02 LMR
$ !         setup of both RAPT and Rdb multiversions.
$ !  v1.0 - Initial release.                                       11/06/02 LMR
$ !
$ !  Set the version of RAPT to use in a multiversion environment.
$ !
$ !  use: @RAPT$SetVer [ version | STANDARD | SHOW | RESET ] -
$ !                    [ /JOB (D) | /SYSTEM ] [ /RDB=Rdb_version ]
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done0
$ !
$ Fac     = F$ENVIRONMENT("PROCEDURE")
$ Fac     = F$PARSE(Fac,,,"NAME","SYNTAX_ONLY")
$ Verbose = F$TRNLNM("Tools$Debug")
$ !
$ ! *** LTClient identifies itself as an Interactive VT100 (archaic!)
$ GUI = ( F$MODE() .EQS. "INTERACTIVE" ) -
        .AND. ( F$GETDVI("TT","DEVICE_TYPE_NAME") .EQS. "VT100" )
$ IF GUI
$ THEN DEFINE /PROCESS /NOLOG sys$output _nla0:
$      DEFINE /PROCESS /NOLOG sys$error  _nla0:
$ ENDIF
$ wso = "WRITE sys$output"  !these writes must be "silent" for LTclient/GUI
$ !
$ ! There is a dependence between these corresponding RAPT<->Rdb versions, but
$ !  currently **no compatibility checks are done** by this command procedure.
$ RdbLegalVersions  = ",070,071,"
$ ! Synch this with RAPT_*_MVKIT.COM:
$ RAPTLegalVersions = ",STANDARD,060,070,071,072,"
$ !
$ ! These are the RAPT components that get logical names defined & managed...
$ !   Note that the dynamically reassignable logicals RMG$FRONT and RMG$BACK
$ !   are *not* included in this list, nor are the command files SPA_LINK.COM
$ !   and RAPT_LINK.COM:
$ LogList =  "RAPT$Variant" -
          + ",RAPT$Version" -
          + ",RMG$Back_RDB" -
          + ",RMG$Back_RMS" -
          + ",RMG$Front_SMG" -
          + ",RMG$Front_NET" -
          + ",RMG$Load" -
          + ",RMG$Merge_Report" -
          + ",RMG" -
          + ",RMGNET" -
          + ",RMS" -
          + ",RMG$SHELL|.COM" -
          + ",PASCAL$RMG_ROUTINES|.PEN|_PEN|er$library:" -
          + ",PASCAL$RMG_ROUTINES|.OBJ|_OBJ|er$library:" -
          + ",RMG_LINK|.COM||er$library:"
$ !
$ ! From VMS "HELP symbol parameters":
$ ! "DCL uses a buffer that is 1024 bytes  long  to  hold  an  assignment
$ !  statement, and to evaluate the expression.  The length of the symbol
$ !  name, the  expression,  and  the  expression's  calculations  cannot
$ !  exceed 1024 bytes."
$ LLlen = F$LENGTH(LogList)
$ LLlim = 900              ! post warning if we approach this practical limit:
$ IF LLlen .GE. LLlim -
  THEN wso F$FAO( "%!AS-W-SYMLEN, value of symbol [4mLogList[0m exceeds !ZL characters", -
                  Fac, LLlim )
$ !
$L1:
$ IF P1 .EQS. ""
$ THEN READ sys$command P1 /END_OF_FILE=Done -
         /PROMPT="RAPT version to use: "
$      IF P1 .EQS. "" THEN P1 = "STANDARD"
$ ENDIF
$ P1 = F$EDIT(P1,"COLLAPSE,UPCASE")
$ !
$ IF P1 .EQS. "?" THEN GOTO Help
$ !
$ IF F$EXTRACT(0,3,P1) .EQS. "STA" THEN P1 = "STANDARD"
$ !
$ ! Swap things around...
$ IF F$EXTRACT(0,4,P2) .EQS. "/RDB"
$ THEN Tmp = P3
$      P3  = P2
$      P2  = Tmp
$ ENDIF
$ !
$ ! Assert:  Logical names will be created either as /SYSTEM /EXECUTIVE, *or*
$ !          as /JOB logicals (process/user-private).  Any of the logical names
$ !          managed by this procedure which might appear as either /PROCESS or
$ !          /SYSTEM /SUPERVISOR are "strays" (created accidentally by user),
$ !          and will be auto-cleaned-up by subroutine DeaLog.
$ IF F$EXTRACT(0,4,P2) .EQS. "/SYS"
$ THEN DQual   = "/SYSTEM /EXECUTIVE"
$      SysFlag = "TRUE"
$      Prv     = F$SETPRV("SYSNAM,SYSPRV,CMKRNL")
$ ELSE DQual   = "/JOB"
$      SysFlag = "FALSE"
$ ENDIF
$ !
$ IF F$EXTRACT(0,4,P3) .EQS. "/RDB"
$ THEN RdbVer = F$ELEMENT(1,"=",P3)
$      RdbVer = RdbVer - "V" - "v" - "." - "." - "-"
$      RdbVL  = F$LENGTH(RdbVer)
$      IF RdbVL .EQ. 1 THEN RdbVer = RdbVer + "0"
$      IF F$LOCATE(RdbVer,RdbLegalVersions) .GE. F$LENGTH(RdbLegalVersions)
$      THEN wso "%''Fac'-E-BAD_VERSION, invalid Rdb version selected"
$           wso ""
$           GOTO Help
$      ELSE IF RdbVer .EQS. F$TRNLNM("RDBVMS$Variant","lnm$system")
$           THEN wso "%''Fac'-I-RDB_BASE, the requested base Rdb variant is ""[4m''P1'[0m"","
$                wso "                         which is the installed version"
$                wso ""
$           ENDIF
$           @sys$library:rdb$setver 'RdbVer'
$           wso ""
$      ENDIF
$ ELSE RdbVer = ""
$ ENDIF
$ !
$ IF Verbose
$ THEN SHOW SYMBOL P1
$      SHOW SYMBOL RdbVer
$      SHOW SYMBOL RAPTLegalVersions
$      SHOW SYMBOL RdbLegalVersions
$      SHOW SYMBOL LogList
$      SHOW SYMBOL SysFlag
$      SHOW SYMBOL DQual
$ ENDIF
$ !
$ IF F$EXTRACT(0,3,P1) .EQS. "RES"  ! RESET?
$ THEN CALL DeassignLogicals "''SysFlag'"
$      ! Refresh the system-wide logicals:
$      @site$startup:RAPT$Startup STARTUP
$      IF SysFlag
$      THEN CALL ShowLogicals "''SysFlag'" "''DQual'" "''Verbose'"
$      ELSE CALL ShowLogicals "TRUE"       "/SYSTEM"  "''Verbose'"
$      ENDIF
$      GOTO Done
$ ENDIF
$ !
$ IF F$EXTRACT(0,3,P1) .EQS. "SHO" THEN GOTO DoShowLogicals  ! SHOW?
$ P1 = P1 - "V" - "v" - "." - "." - "-"
$ P1L = F$LENGTH(P1)
$ IF P1L .EQ. 1 THEN P1 = "0" + P1 + "0"
$ IF P1L .EQ. 2 THEN P1 = "0" + P1
$ IF F$LOCATE(P1,RAPTLegalVersions) .GE. F$LENGTH(RAPTLegalVersions)
$ THEN wso "%''Fac'-E-BAD_VERSION, invalid RAPT version selected"
$      wso ""
$      GOTO Help
$ ELSE IF P1 .EQS. F$TRNLNM("RAPT$Variant","lnm$system")
$      THEN wso "%''Fac'-I-RAPT_BASE, the requested base RAPT variant is [4m''P1'[0m,"
$           wso "                          which is the installed version"
$           wso ""
$           DQual   = "/JOB"
$           SysFlag = "FALSE"
$           CALL DeassignLogicals "/JOB"
$           CALL ShowLogicals "TRUE" "/SYSTEM" "''Verbose'"
$           GOTO Done
$      ENDIF
$ ENDIF
$ !
$DoDefineLogicals:
$ CALL DefineLogicals "''P1'" "''SysFlag'" "''DQual'"
$ CALL ShowLogicals "''SysFlag'" "''DQual'" "''Verbose'"
$ GOTO Done
$ !
$DoDeassignLogicals:
$ CALL DeassignLogicals "''SysFlag'"
$ CALL ShowLogicals "''SysFlag'" "''DQual'" "''Verbose'"
$ GOTO Done
$ !
$DoShowLogicals:
$ CALL ShowLogicals "''SysFlag'" "''DQual'" "TRUE"
$ GOTO Done
$ !
$Done:
$ wso ""
$ @site$utils:rapt_tools  !update user's foreign commands LOAD, RMERGE & RMG
$ IF Verbose
$ THEN CALL ShowSymbol "Load"
$      CALL ShowSymbol "RMerge"
$      CALL ShowSymbol "RMG"
$ ENDIF
$ !
$Done0:
$ SET NOON
$ IF F$TRNLNM("sys$output","lnm$process") .EQS. "_NLA0:" THEN DEASSIGN /PROCESS sys$output
$ IF F$TRNLNM("sys$error","lnm$process")  .EQS. "_NLA0:" THEN DEASSIGN /PROCESS sys$error
$ IF F$TYPE(Prv) .EQS. "STRING" THEN Prv = F$SETPRV(Prv)
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$ !
$DefineLogicals:  SUBROUTINE
$ ! P1 = RAPT variant string
$ ! P2 = system flag
$ ! P3 = qualifiers
$ SET NOON
$ Define = "DEFINE /NOLOG"
$ IF .NOT. P2
$ THEN Define RAPT$Variant "''P1'" 'P3'
$      Ver = F$EXTRACT(1,1,P1) + "." + F$EXTRACT(2,1,P1)
$      Define RAPT$Version "''Ver'" 'P3'
$ ENDIF
$ IF P1 .NES. "STANDARD"
$ THEN Var = "_" + P1  !now looks like the VerTag
$ ELSE Var = ""
$ ENDIF
$ !
$ i = 0
$DL0:
$ Itm = F$ELEMENT(i,",",LogList)
$ IF Itm .EQS. "," THEN GOTO DL1
$ IF F$EXTRACT(0,5,Itm) .NES. "RAPT$"
$ THEN Lnm = F$ELEMENT(0,"|",Itm)
$      Fnm = Lnm
$      Typ = F$ELEMENT(1,"|",Itm)
$      Lxt = F$ELEMENT(2,"|",Itm)
$      Loc = F$ELEMENT(3,"|",Itm)
$      IF ( Typ .EQS. "" ) .OR. ( Typ .EQS. "|" ) THEN Typ = ".EXE"
$      IF ( Lxt .EQS. "|" ) THEN Lxt = ""
$      IF ( Lxt .NES. "" ) THEN Lnm = Lnm + Lxt
$      IF ( Loc .EQS. "" ) .OR. ( Loc .EQS. "|" ) THEN Loc = "site$utils:"
$      Eqv = Loc + Fnm + Var + Typ
$      CALL DefLog 'Lnm' "''Eqv'" "''P3'"
$ ENDIF
$ i = i + 1
$ GOTO DL0
$DL1:
$ EXIT 1
$ ENDSUBROUTINE  ! DefineLogicals
$ !
$DefLog:  SUBROUTINE
$ ! P1 = logical name
$ ! P2 = filename equivalence string
$ ! P3 = qualifiers
$ SET NOON
$ Define = "DEFINE /NOLOG"
$ IF Verbose
$ THEN wso "%''Fac'-I-ECHO, -"
$      wso "$ [1mDEFINE ''P3' ''P1' ''P2'[0m"
$ ENDIF
$ IF F$SEARCH(P2) .NES. ""
$ THEN Define 'P3' 'P1' 'P2'
$ ELSE wso "%''Fac'-E-FNF, no such file ''P2',"
$      wso "                    logical name ''P1' not defined"
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! ShLog
$ !
$ShowLogicals:  SUBROUTINE
$ ! P1 = system flag
$ ! P2 = qualifiers
$ ! P3 = early exit flag
$ SET NOON
$ RV = F$TRNLNM("RDBVMS$Version")
$ IF RV .EQS. ""
$ THEN RV = "STANDARD"
$ ELSE RV = "v" + RV
$ ENDIF
$ wso F$FAO("%!AS-I-RDBVMS, Rdb multiversion is currently set to !AS", Fac, RV)
$ RV = F$TRNLNM("RAPT$Version")
$ IF RV .EQS. ""
$ THEN RV = "STANDARD"
$ ELSE RV = "v" + RV
$ ENDIF
$ wso F$FAO("%!AS-I-RAPT,  RAPT multiversion is currently set to !AS", Fac, RV)
$ IF .NOT. P3 THEN EXIT 1  !  (don't use global Verbose here!)
$ !
$ i = 0
$SL0:
$ Lnm = F$ELEMENT(i,",",LogList)
$ IF Lnm .EQS. "," THEN GOTO SL1
$ Lxt = F$ELEMENT(2,"|",Lnm)
$ Lnm = F$ELEMENT(0,"|",Lnm)
$ IF ( Lxt .EQS. "|" ) THEN Lxt = ""
$ IF ( Lxt .NES. "" ) THEN Lnm = Lnm + Lxt
$ CALL ShoLog 'Lnm' "''P1'" "''P2'"
$ i = i + 1
$ GOTO SL0
$SL1:
$ EXIT 1
$ ENDSUBROUTINE  ! ShowLogicals
$ !
$ShoLog:  SUBROUTINE
$ ! P1 = logical name
$ ! P2 = system flag
$ ! P3 = qualifiers
$ SET NOON
$ IF P2
$ THEN Tbl = "lnm$system"
$ ELSE Tbl = "lnm$job"
$ ENDIF
$ TP3 = F$EDIT(F$EXTRACT(0,4,P3),"TRIM,LOWERCASE") - "/"
$ Lnm = F$TRNLNM(P1,Tbl)
$ IF Lnm .NES. ""
$ THEN P1 = """" + P1 + """"
$      Lnm = """" + Lnm + """"
$      wso F$FAO(" !26AS = !43AS [!AS]", P1, Lnm, TP3)
$ ELSE wso "%''Fac'-I-NOLOGNAME, no ''P3' logical name ''P1'"
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! ShLog
$ !
$DeassignLogicals:  SUBROUTINE
$ ! P1 = system flag
$ SET NOON
$ i = 0
$DL0:
$ Lnm = F$ELEMENT(i,",",LogList)
$ IF Lnm .EQS. "," THEN GOTO DL1
$ Lxt = F$ELEMENT(2,"|",Lnm)
$ Lnm = F$ELEMENT(0,"|",Lnm)
$ IF ( Lxt .EQS. "|" ) THEN Lxt = ""
$ IF ( Lxt .NES. "" ) THEN Lnm = Lnm + Lxt
$ CALL DeaLog 'Lnm' "''P1'"
$ i = i + 1
$ GOTO DL0
$DL1:
$ EXIT 1
$ ENDSUBROUTINE  ! DeassignLogicals
$ !
$DeaLog:  SUBROUTINE
$ ! P1 = logical name
$ ! P2 = system flag
$ SET NOON
$ Qual = ""
$ ! Be thorough:  If SysFlag (P2), then remove either/both /EXECUTIVE and
$ !               /SUPERVISOR mode system-table logicals;
$ !               else remove either/both /JOB and /PROCESS logical names.
$ IF P2
$ THEN IF F$TRNLNM(P1,"lnm$system",,"EXECUTIVE") .NES. ""
$      THEN IF Verbose
$           THEN wso "%''Fac'-I-ECHO $ [1mDEASSIGN /SYSTEM /EXECUTIVE ''P1'[0m"
$           ELSE DEASSIGN /SYSTEM /EXECUTIVE 'P1'
$           ENDIF
$      ENDIF
$      IF F$TRNLNM(P1,"lnm$system",,"SUPERVISOR") .NES. ""
$      THEN IF Verbose
$           THEN wso "%''Fac'-I-ECHO $ [1mDEASSIGN /SYSTEM /SUPERVISOR ''P1'[0m"
$           ELSE DEASSIGN /SUPERVISOR /EXECUTIVE 'P1'
$           ENDIF
$      ENDIF
$ ELSE IF F$TRNLNM(P1,"lnm$job") .NES. ""
$      THEN IF Verbose
$           THEN wso "%''Fac'-I-ECHO $ [1mDEASSIGN /JOB ''P1'[0m"
$           ELSE DEASSIGN /JOB 'P1'
$           ENDIF
$      ENDIF
$      IF F$TRNLNM(P1,"lnm$process") .NES. ""
$      THEN IF Verbose
$           THEN wso "%''Fac'-I-ECHO $ [1mDEASSIGN /PROCESS ''P1'[0m"
$           ELSE DEASSIGN /PROCESS 'P1'
$           ENDIF
$      ENDIF
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! DeaLog
$ !
$ShowSymbol:  SUBROUTINE
$ SET NOON
$ IF F$TYPE('P1') .EQS. "STRING"
$ THEN Sym = 'P1'
$      wso F$FAO("  !AS == ""!AS""", P1, Sym)
$ ELSE wso "%''Fac'-E-NOSYMBOL, no such global symbol ''P1'"
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! ShowSymbol
$ !
$ !
$ !
$Help:
$ ContPrompt = F$FAO("!28* [7mPress RETURN to continue[0m")
$ TYPE sys$input

  RAPT$SetVer is a command procedure to set the working version of RAPT in
  a multiversion environment.  It can be used by both application users and
  developers alike.

  RAPT$SetVer simply establishes a group of logical names for the various
  runtime and developer environments of RAPT.  It is intended for use in,
  for example, situations where the production application environment is
  using an established RAPT version (like V6.0-n), while program develop-
  ment and evaluation must proceed using a later RAPT version (say V7.0-n).

  use:  $ [1m@RAPT$SetVer version[0m -
                       [ [1m/JOB[0m | [1m/SYSTEM[0m ] -
                       [ [1m/RDB=Rdb_version[0m ]

  where:

    [1mversion[0m -- A string of characters which represents the version of RAPT
               to set as the working environment, or the keyword "[1mSHOW[0m"
               which displays a list of all logical names defined by
               RAPT$SetVer.

               This string has the general form "[1mnnn[0m", where [1mn[0m is a digit.
               Typically, you will enter something like "070" (for RAPT
               V7.0).  Where there is no version-number ambiguity, the
               string can be abbreviated to "NN" or even "N"; both "70"
               and "7" are equivalent to "070".

               The word STANDARD sets the version to the installed default
               (no version-tags).  Current legal RAPT versions are:
$ !
$ ! Display the current legal variants/versions ---
$ ! RAPTLegalVersions = ",STANDARD,060,070,...,", so start with i = 1, not 0:
$ i = 1
$ LVar = ""
$ LVer = ""
$H1:
$ Tmp = F$ELEMENT(i,",",RAPTLegalVersions)
$ IF ( Tmp .EQS. "" ) .OR. ( Tmp .EQS. "," ) THEN GOTO H2
$ IF LVar .EQS. ""
$ THEN LVar = Tmp
$ ELSE LVar = LVar + ", " + Tmp
$ ENDIF
$ IF Tmp .NES. "STANDARD"
$ THEN Tmp = "v" + F$EXTRACT(1,1,Tmp) + "." + F$EXTRACT(2,1,Tmp)
$      IF LVer .EQS. ""
$      THEN LVer = Tmp
$      ELSE LVer = LVer + ", " + Tmp
$      ENDIF
$ ENDIF
$ i = i + 1
$ GOTO H1
$H2:
$ wso ""
$ wso F$FAO("!15* [1m[4m!AS[0m ([1m!AS[0m)", LVar, LVer)
$ wso ""
$ !
$ ! Continue with help text:
$ READ sys$command Dummy /END_OF_FILE=Done /PROMPT="''ContPrompt'"
$ TYPE /PAGE sys$input

  [1m/JOB[0m      -- Controls which table, LNM$JOB or LNM$SYSTEM, where the logical
  [1m/SYSTEM[0m      names will be created.  /JOB logical names are intended for
               use by user processes in a single job-tree;  /SYSTEM logical
               names can be created only by privileged users (system managers)
               and affect all users on the system.  /SYSTEM logical names are
               created and managed in /EXECUTIVE mode.  /JOB is the default.

  [1m/RDB=Rdb_version[0m -- Executes $ [1m@SYS$LIBRARY:RDB$SETVER 'Rdb_version'[0m to set
               the requested version of Rdb (in a multiversion installation).
               It is up to you, the user, to ensure that you are requesting an
               Rdb version which is compatible with the version of RAPT which
               you've requested -- no version compatibility checks are done by
               this procedure.  See also the [1mRdbSetVer[0m command which executes
               SYS$LIBRARY:RDBSETVER.COM.


  or use: $ [1m@RAPT$SetVer[0m [ [1mSHOW[0m | [1mRESET[0m ] [ [1m/JOB[0m | [1m/SYSTEM[0m ]

  where:

    [1mSHOW[0m    -- Shows the list of logical names, together with their current
               equivalence strings, which are managed by RAPT$SetVer.  You
               can show either the /JOB or the /SYSTEM group of logical names.
               /JOB is the default.

    [1mRESET[0m   -- Deassigns (resets)the list of logical names, allowing either
               the user's job-tree or the system to revert to a non-multi-
               version RAPT configuration.  You can reset your own /JOB
               logical names; only a privileged user (system manager) can
               reset the /SYSTEM group.  /JOB is the default.

$ GOTO Done0
