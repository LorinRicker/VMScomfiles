$ ! LT$MODULES.COM --  Replaces L&T Stored-SQL modules             'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1996-2001 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  use:  @LT$MODULES ModuleName[,ModuleName,...]
$ !                    [ ModuleLevel_to_load
$ !                      | /LOAD=ModuleLevel_to_load
$ !                      | /SET=ModuleLevel_to_set
$ !                      | /SHOW                               ]
$ !                    [ /DIFFIE=DiffieFileName
$ !                      | /VERSIONS=(V1[,V2,V3])
$ !                      | /COMMENT="comment text for logfile" ]
$ !
$ !  v2.1 - Add logging to module loading, ability to show currently loaded
$ !         modules in a database, support for Diffie auto-editing (to "pin"
$ !         *_MODULE references to a particular release-level), file-version-
$ !         specific support for both /SET and /LOAD.  This edit adds multi-
$ !         module processing (P1 can be comma-separated list).  LMR 01/19/2001
$ !         Note: LogEvent procedure moved to UTILITY.COM and improved.
$ !  v2.0 - Add "modular coordination" to existing load functions, inventing
$ !         both /SET= and /LOAD= command qualifiers.  Add Help procedure
$ !         and text.  New procedures Coordinate and LogEntry, plus various
$ !         improvements & tweaks to existing code.  LMR 01/17/2001
$ !  v1.x - Baseline releases, load-only functionality.  LMR
$ !
$MAIN:
$ ON ERROR THEN GOTO AllDone
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ IF F$TYPE(Util$Fac) .EQS. ""
$ THEN Util == "@site$utils:utility.com"
$      Util START LTM "" "V2001.03.01"  !Require this minimum version of UTILITY.COM
$ ENDIF
$ !
$ wso = "WRITE sys$output"
$ Ver = F$TRNLNM("TOOLS$Debug")     !generic Tools debug flag
$ IF F$TYPE(sql) .EQS. "" THEN sql = "$sys$system:sql$"
$ !
$ IF P1 .EQS. "?" THEN GOTO Help
$ !
$ Prv = F$SETPRV("SETPRV,BYPASS")
$ DD  = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(DD,,,"NAME","SYNTAX_ONLY")
$ DD  = F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ !
$ ! Define temp-lnm LTM$DevRoot equiv. to either LT$DevRoot *or* LT$Root
$ IF F$TRNLNM("LT$DevRoot") .NES. ""
$ THEN DEFINE /NOLOG /PROCESS LTM$DevRoot 'F$TRNLNM("LT$DevRoot")'
$ ELSE DEFINE /NOLOG /PROCESS LTM$DevRoot 'F$TRNLNM("LT$Root")'
$      wso "%''Fac'-W-NO_DEVROOT, missing logical name [1mLT$DevRoot[0m"
$      wso "           -W-CAUTION, using LT$ROOT =",F$TRNLNM("LT$Root")
$      wso "           -W-CAUTION, check directories, use care..."
$ ENDIF
$ !
$ LTM$Database == "LT$Database"
$ LTM$DB       == F$TRNLNM(LTM$Database)
$ LTM$MDD      == "LTM$DevRoot:[common]"
$ LTM$Comment  == ""
$ LTM$Diffie   == ""
$ LTM$Loaded   == 0
$ LTM$Set      == 0
$ LTM$MsgFlag1 == "FALSE"
$ LTM$Setting  == 0
$ LTM$RelLevel == ""
$ !
$ IF F$TRNLNM("LT$ConfigLog") .EQS. ""  ! (should be defined by LT$Startup.com)
$ THEN DEFINE /PROCESS LT$ConfigLog LT$DevRoot:[common]LT$ConfigLog.data
$ ENDIF
$ !
$LP1:
$ IF P1 .EQS. ""
$ THEN READ sys$command P1 /END_OF_FILE=AllDone /PROMPT="Module(s): "
$      GOTO LP1
$ ENDIF
$ LTM$DoAll == ( P1 .EQS. "ALL" ) .OR. ( P1 .EQS. "*" )
$ !
$ LTM$AllArgs == P3 + P4 + P5 + P6 + P7 + P8
$ !
$ RLdef = F$CVTIME("","COMPARISON","DATE") - "-" - "-"
$ IF P2 .NES. ""
$ THEN IF F$EXTRACT(0,1,P2) .EQS. "/"
$      THEN Q = F$EXTRACT(1,3,P2)  ! process /SET or /LOAD
$           IF Q .EQS. "SET"
$           THEN LTM$Setting == 1
$                P = "set"
$           ENDIF
$           IF Q .EQS. "LOA"
$           THEN P = "load"
$           ENDIF
$LP2:
$           IF ( Q .EQS. "SET" ) .OR. ( Q .EQS. "LOA" )
$           THEN RelLev = F$ELEMENT(1,"=",P2)
$                IF ( RelLev .EQS. "=" ) .OR. ( RelLev .EQS. "" )
$                THEN READ sys$command RelLev /END_OF_FILE=AllDone -
                        /PROMPT="Module level to [4m''P'[0m (''RLdef'): "
$                     RelLev = F$PARSE(RelLev,RLdef,,"NAME","SYNTAX_ONLY")
$                     IF RelLev .EQS. "*"
$                     THEN IF Q .EQS. "LOA"
$                          THEN RelLev = ""
$                          ELSE wso "%''Fac'-W-MISSING_VALUE, you must provide a valid release-level"
$                               GOTO LP2
$                          ENDIF
$                     ENDIF
$                ENDIF
$                LTM$RelLevel == F$EDIT(RelLev,"UPCASE,COLLAPSE")
$           ELSE ! if neither /SET nor /LOAD, then P2 is some other qualifier,
$                LTM$AllArgs == P2 + LTM$AllArgs  ! so graft onto All-Args...
$           ENDIF
$      ELSE LTM$RelLevel == F$EDIT(P2,"UPCASE,COLLAPSE") ! ModuleLevel (no "/")
$      ENDIF
$ ENDIF
$ IF Ver -
  THEN wso F$FAO("%!AS-I-ECHO, LTM$Setting == !SL, LTM$RelLevel == ""!AS""", -
                  Fac, LTM$Setting, LTM$RelLevel )
$ !
$ ! Parse remaining qualifiers:  /SHOW /COMMENT /DIFFIE /VERSION
$ ! ... /SHOW
$ IF F$LOCATE("/SHO",LTM$AllArgs) .LT. F$LENGTH(LTM$AllArgs)
$ THEN CALL ShowModules
$      GOTO AllDone
$ ENDIF
$ ! ... /COMMENT="comment text"
$ CALL Qualifier "COMMENT"  "LTM$Comment"
$ LTM$Comment == LTM$Comment - """" - """"  !strip any quotes
$ ! ... /DIFFIE=DiffieFilename or /DIFFIE=(DiffieFN1,DiffieFN2,...)
$ CALL Qualifier "DIFFIE"   "LTM$Diffie"
$ ! ... /VERSIONS=SQLvers# or /VERSIONS=(SQLvers#,PREvers#,POSTvers#)
$ LTM$Versions == ""
$ LTM$V0 == ""
$ LTM$V1 == ""
$ LTM$V2 == ""
$ CALL Qualifier "VERSIONS" "LTM$Versions" "LTM$V0" "LTM$V1" "LTM$V2"
$ IF LTM$V0 .NES. "" THEN LTM$V0 == LTM$V0 - ";"  !strip optional ";NN"
$ IF LTM$V1 .NES. "" THEN LTM$V1 == LTM$V1 - ";" - ","
$ IF LTM$V2 .NES. "" THEN LTM$V2 == LTM$V2 - ";" - ","
$ !
$ IF Ver
$ THEN SHOW SYMBOL LTM$Comment
$      SHOW SYMBOL LTM$Diffie
$      SHOW SYMBOL LTM$Versions
$      SHOW SYMBOL LTM$V0
$      SHOW SYMBOL LTM$V1
$      SHOW SYMBOL LTM$V2
$ ENDIF
$ !
$ ! More than one or all modules specified? ...then can't use /VERSIONS:
$ IF ( LTM$DoAll .OR. ( F$LOCATE(",",P1) .LT. F$LENGTH(P1) ) ) -
  .AND. ( LTM$Versions .NES. "" )
$ THEN wso "%''Fac'-E-CLI_QUALERR, cannot use /VERSIONS with ALL, * or multiple modules"
$      wso "           -I-ONE_MODULE,  use this qualifier only with one module at a time"
$      GOTO AllDone
$ ENDIF
$ !
$ IF .NOT. LTM$Setting
$ THEN ! Check that we're not asking for /DIFFIE on a (re)load operation:
$      IF LTM$Diffie .NES. ""
$      THEN wso "%''Fac'-E-QUALERR, cannot use /DIFFIE with a load operation"
$           GOTO AllDone
$      ENDIF
$      SDB = "site$utils:show_database.com"
$      IF F$SEARCH(SDB) .NES. ""
$      THEN @'SDB'
$      ELSE SHOW LOGICAL /FULL 'LTM$Database'
$      ENDIF
$      wso ""
$      Util ASK "    Correct database" "" "Yes" "Z?"
$      IF .NOT. LTM$Answer THEN GOTO AllDone
$ ENDIF
$ !
$ ON ERROR THEN GOTO Done
! ==========================
$ Cmd =  "BRINGDOWN" -     ! This list is equivalent to "ALL";
      + "|COURTDESK" -
      + "|MERGE    " -     ! ...and due to inter-modular dependencies
      + "|IACCOUNTS" -
      + "|CALCULATE" -     ! ... IS SORTED IN THIS ORDER ON PURPOSE!
      + "|LOCKWORKS" -
      + "|DCLSYMBOL" -     ! ... In particular, DCLSYMBOL_MODULE and
      + "|FUNCTIONS"       !     FUNCTIONS_MODULE must be last-loaded.
! ==========================
$ !
$ IF LTM$DoAll
$ THEN j = 0
$      Modules = ""
$CL0:
$      M = F$EDIT(F$ELEMENT(j,"|",Cmd),"TRIM")
$      IF ( M .EQS. "|" ) .OR. ( M .EQS. "" ) THEN GOTO TheLoop
$      IF F$SEARCH("LTM$DevRoot:[common]''M'_module.sql") .NES. ""
$      THEN IF Modules .EQS. ""
$           THEN Modules = M
$           ELSE Modules = Modules + "," + M
$           ENDIF
$      ENDIF
$      j = j + 1
$      GOTO CL0
$ ELSE Cmd = Cmd          -  ! add these for user-testing only
           + "|PROCESS  " -  !  (but not part of ALL)
           + "|TEST     "
$      Modules = P1
$ ENDIF
$ !
$ !
$ ! --- Processing loop ---
$TheLoop:
$ j = 0
$PLoop:
$ M = F$ELEMENT(j,",",Modules)
$ IF ( M .EQS. "," ) .OR. ( M .EQS. "" )
$ THEN GOTO Done  ! end-of-loop
$ ELSE Util CMDPARSE "''M'" Answer "LOCKWORKS" "''Cmd'"
$      GOTO 'LTM$Answer'
$ ENDIF
$ !
$BRINGDOWN:
$ Mod = "Bringdown"
$ GOTO TheProcess
$ !
$CALCULATE:
$ Mod = "Calculate"
$ GOTO TheProcess
$ !
$COURTDESK:
$ Mod = "CourtDesk"
$ GOTO TheProcess
$ !
$DCLSYMBOL:                ! including .SQL_PREPROCESS and .SQL_POSTPROCESS
$ Mod = "DCLSymbol"
$ GOTO TheProcess
$ !
$FUNCTIONS:                ! including .SQL_PREPROCESS and .SQL_POSTPROCESS
$ Mod = "Functions"
$ GOTO TheProcess
$ !
$IACCOUNTS:
$ Mod = "IAccounts"
$ GOTO TheProcess
$ !
$LOCKWORKS:
$ Mod = "LockWorks"
$ GOTO TheProcess
$ !
$MERGE:
$ Mod = "Merge"
$ GOTO TheProcess
$ !
$PROCESS:
$ Mod = "Process"
$ GOTO TheProcess
$ !
$TEST:
$ Mod = "Test"
$ GOTO TheProcess
$ !
$TheProcess:
$ IF LTM$Setting
$ THEN CALL Coordinate "''Mod'"
$ ELSE CALL Do_Module  "''Mod'"
$ ENDIF
$ j = j + 1
$ GOTO PLoop
$ !
$ !
$Done:
$ SET NOON
$ ! Don't record comments when testing...
$ IF .NOT. Ver .AND. ( LTM$Comment .NES. "" ) -
  THEN UTIL LogEntry "LT$ConfigLog" "''LTM$Comment'" "COMMENT"
$ IF ( LTM$Set .GE. 1 ) .OR. ( LTM$Loaded .GE. 1 ) -
  THEN UTIL LogEntry "LT$ConfigLog" "" "SEPARATOR"
$ !
$ IF LTM$Setting
$ THEN IF ( LTM$Diffie .NES. "" ) .AND. ( LTM$RelLevel .NES. "" )
$      THEN CALL Diffies "''P1'"
$      ENDIF
$      IF Ver
$      THEN DIRECTORY /SIZE /DATE /PROTECTION *_module*.sql*;0,LT$ConfigLog
$      ENDIF
$ ELSE IF LTM$Loaded .GT. 0     ! Did we actually insert at least one module?
$      THEN CALL Rdb_Bugs  !  ...Apply LTM$DevRoot:[DATABASE]BUGS.SQL
$           ! Check date/time stamps on LOCKWORKS$SQL source & object files...
$           SrcDT = F$FILE_ATTRIBUTES("LTM$DevRoot:[common]lockworks$sql.sqlmod","CDT")
$           SrcDT = F$CVTIME(SrcDT,"COMPARISON")
$           IF F$SEARCH("LTM$DevRoot:[common]lockworks$sql.obj") .EQS. ""
$           THEN ObjDT = ""
$           ELSE ObjDT = F$FILE_ATTRIBUTES("LTM$DevRoot:[common]lockworks$sql.obj","CDT")
$                ObjDT = F$CVTIME(ObjDT,"COMPARISON")
$           ENDIF
$           ! Rebuild only if Object is older than Source (stale), or no Object file:
$           IF ObjDT .LES. SrcDT
$           THEN SQLMOD = "$sql$mod/ANSI_DATE/ANSI_PARAMETERS/CONNECT/NOLIST/NOEXTERNAL_GLOBAL"
$                wso "%''Fac'-I-RELINK, rebuilding LOCKWORKS$SQL.SQLMOD"
$                SQLMOD /OBJ=LTM$DevRoot:[common] LTM$DevRoot:[common]lockworks$sql.sqlmod
$                PURGE LTM$DevRoot:[common]lockworks$sql.obj
$           ENDIF
$      ENDIF
$      wso ""
$      wso F$FAO("%''Fac'-S-Done, !ZL Lock&Track Stored-SQL module!%S reloaded", LTM$Loaded)
$      wso ""
$      ! Conditionally show final/reminder messages:
$      IF LTM$MsgFlag1
$      THEN wso "%''Fac'-I-REMINDER, remember to re-apply ''LTM$Database' ACLs..."
$           wso ""
$      ENDIF
$ ENDIF
$ !
$AllDone:
$ IF F$TRNLNM("LTM$DevRoot","lnm$process") .NES. "" THEN DEASSIGN /PROCESS LTM$DevRoot
$ IF F$TYPE(Prv) .NES. "" THEN Prv = F$SETPRV(Prv)
$ Util EXIT LTM
$ EXIT
$ !
$ !
$Coordinate:  SUBROUTINE
$ ! P1 = short-name of module (e.g., LOCKWORKS, BRINGDOWN, etc.)
$ ON CONTROL_Y THEN EXIT %X2C
$ ON ERROR THEN EXIT $STATUS
$ !
$ IF LTM$RelLevel .EQS. ""
$ THEN wso "%''Fac'-F-BAD_RELLEVEL, bad or missing release level"
$      EXIT %X2C
$ ENDIF
$ !
$ Mod   = P1 + "_Module"
$ MFile = LTM$MDD + Mod + ".sql" + ";" + LTM$V0
$ !
$ IF F$SEARCH(MFile) .EQS. ""
$ THEN IF .NOT. LTM$DoAll  !only shout error if not "ALL" (explicit)
$      THEN wso "%''Fac'-W-FNF, no module source file to coordinate:"
$           wso F$FAO( "!18* [1m!AS[0m", MFile )
$      ENDIF
$ ELSE COPY = "COPY /PROT=(S:RWED,O:RWED,G,W) /NOLOG"
$      LFile = LTM$MDD + Mod + "$" + LTM$RelLevel + ".sql;"
$      MFPre = LTM$MDD + Mod + ".sql_PreProcess"  + ";" + LTM$V1
$      MFPst = LTM$MDD + Mod + ".sql_PostProcess" + ";" + LTM$V2
$      COPY 'MFile' 'LFile'
$      i = 1
$      IF F$SEARCH(MFPre) .NES. ""
$      THEN LFPre = LTM$MDD + Mod + "$" + LTM$RelLevel + ".sql_PreProcess;"
$           COPY 'MFPre' 'LFPre'
$           i = i + 1
$      ENDIF
$      IF F$SEARCH(MFPst) .NES. ""
$      THEN LFPst = LTM$MDD + Mod + "$" + LTM$RelLevel + ".sql_PostProcess;"
$           COPY 'MFPst' 'LFPst'
$           i = i + 1
$      ENDIF
$ !
$ !    Log-file entry:
$      IF LTM$Set .EQ. 0
$      THEN UTIL LogEntry "LT$ConfigLog" -
              "''F$FAO( "Set mod-level !AS", LTM$RelLevel )'" "TIMESTAMP"
$      ENDIF
$      IF LTM$Versions .NES. "" THEN Mod = Mod + ", file-version(s) " + LTM$Versions
$      UTIL LogEntry "LT$ConfigLog" "''Mod'" "DATA" "4"
$      LTM$Set == LTM$Set + 1
$ !
$      wso F$FAO("%!AS-S-COORDINATED, set [1m!AS[0m at module-level ""!AS"" (!SL file!%S)", -
                  Fac, P1, LTM$RelLevel, i )
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! Coordinate
$ !
$ !
$Do_Module:  SUBROUTINE
$ ! P1 = short-name of module (e.g., LOCKWORKS, BRINGDOWN, etc.)
$ ON CONTROL_Y THEN EXIT %X2C
$ ON ERROR THEN EXIT $STATUS
$ !
$ wf = "WRITE f"
$ IF LTM$RelLevel .NES. ""
$ THEN MFile = LTM$MDD + P1 + "_Module$" + LTM$RelLevel + ".sql" + ";" + LTM$V0
$      MFPre = LTM$MDD + P1 + "_Module$" + LTM$RelLevel + ".sql_PreProcess"  + ";" + LTM$V1
$      MFPst = LTM$MDD + P1 + "_Module$" + LTM$RelLevel + ".sql_PostProcess" + ";" + LTM$V2
$ ELSE MFile = LTM$MDD + P1 + "_Module.sql" + ";" + LTM$V0
$      MFPre = LTM$MDD + P1 + "_Module.sql_PreProcess"  + ";" + LTM$V1
$      MFPst = LTM$MDD + P1 + "_Module.sql_PostProcess" + ";" + LTM$V2
$ ENDIF
$ !
$ IF F$SEARCH(MFile) .EQS. ""
$ THEN wso "%''Fac'-W-FNF, no module source file to reload:"
$      wso F$FAO( "!18* [1m!AS[0m", MFile )
$ ELSE SFile = "sys$scratch:reload_" + P1 + "_module.sql"
$      OPEN /WRITE f 'SFile' /ERROR=Do_Mod_Err
$      wf "set noverify"
$      wf "attach 'filename ",LTM$database,"';"
$      PreF = F$SEARCH(MFPre)
$      IF PreF .NES. ""
$      THEN wf "print '%SQL-I-PREPROCESS, executing ''P1'_module pre-process';"
$           wf "@''PreF'"
$      ENDIF
$      wf "print '%SQL-I-DROP, dropping ''P1'_Module';"
$      wf "drop module ''P1'_Module;"
$      IF P1 .EQS. "DCLSymbol"
$      THEN ! Exceptions to clean up DCLSymbol_Module; these steps *must* be
$           !   done *after* dropping the module, not as a pre-process step:
$           wf "drop procedure LIB$GET_SYMBOL;"
$           wf "drop procedure LIB$DAY;"
$           wf "drop domain DCLSYMBOL_DATATYPE;"
$           wf "drop domain DCLSTRING_DATATYPE;"
$      ENDIF
$      wf "commit;"
$      wf "print '%SQL-I-CREATE, reloading ''P1'_Module';"
$      wf "@''MFile'"
$      PostF = F$SEARCH(MFPst)
$      IF PostF .NES. ""
$      THEN wf "print '%SQL-I-POSTPROCESS, executing ''P1'_module post-process';"
$           wf "@''PostF'"
$      ENDIF
$      wf "exit"
$      CLOSE f
$      wso ""
$      IF Ver
$      THEN wso "%''Fac'-I-TEST, dry-run ''P1'_Module into ''LTM$DB'"
$           TYPE /HEADER 'SFile'
$      ELSE wso "%''Fac'-I-RELOAD, loading ''P1'_Module into ''LTM$DB'"
$           DEFINE /USER_MODE sqlini nl:
$           sql @'SFile'
$           DELETE /NOLOG 'SFile';0
$ !         Log-file entry:
$           IF LTM$Loaded .EQ. 0
$           THEN UTIL LogEntry "LT$ConfigLog" -
                   "''F$FAO( "Loaded into !AS", LTM$DB )'" -
                   "TIMESTAMP"
$           ENDIF
$           IF LTM$Versions .NES. ""
$           THEN Mod = P1 + "_Module" + ", file-version(s) " + LTM$Versions
$           ELSE Mod = P1 + "_Module"
$           ENDIF
$           UTIL LogEntry "LT$ConfigLog" "''Mod'" "DATA" "4"
$           LTM$Loaded == LTM$Loaded + 1  !count this module as done...
$           ! Pre/Post processing usually means dropping/(re)building views,
$           !  so post a reminder message:
$           LTM$MsgFlag1 == "TRUE"
$      ENDIF
$ ENDIF
$ EXIT 1
$ !
$Do_Mod_Err:
$ Stat = $STATUS
$ wso "%''Fac'-E-OPENERR, cannot create file"
$ wso F$FAO( "!22* !AS", SFile )
$ EXIT Stat
$ ENDSUBROUTINE  ! Do_Module
$ !
$ !
$ !
$ShowModules:  SUBROUTINE
$ SET NOON
$ wf = "WRITE f"
$ SFile = "sys$scratch:show_modules.sql"
$ OPEN /WRITE f 'SFile' /ERROR=Do_Show_Err
$ wf "set noverify"
$ wf "attach 'filename ",LTM$database,"';"
$ wf "show module (description) *"
$ wf "exit"
$ CLOSE f
$ wso ""
$ DEFINE /USER_MODE sqlini nl:
$ sql @'SFile'
$ DELETE /NOLOG 'SFile';0
$ EXIT 1
$Do_Show_Err:
$ Stat = $STATUS
$ wso "%''Fac'-E-OPENERR, cannot create file"
$ wso F$FAO( "!22* !AS", SFile )
$ EXIT Stat
$ ENDSUBROUTINE  ! ShowModules
$ !
$Rdb_Bugs:  SUBROUTINE
$ !...Still coping with Rdb %ARITH-EXCEPTION bugs on date fields:
$ SET NOON
$ wf = "WRITE f"
$ SFile = "sys$scratch:rdb_bugs.sql"
$ OPEN /WRITE f 'SFile' /ERROR=Do_Bugs_Err
$ wf "set noverify"
$ wf "attach 'filename ",LTM$database,"';"
$ wf "@LTM$DevRoot:[database]bugs"
$ wf "exit"
$ CLOSE f
$ wso ""
$ DEFINE /USER_MODE sqlini nl:
$ sql @'SFile'
$ DELETE /NOLOG 'SFile';0
$ EXIT 1
$Do_Bugs_Err:
$ Stat = $STATUS
$ wso "%''Fac'-E-OPENERR, cannot create file"
$ wso F$FAO( "!22* !AS", SFile )
$ EXIT Stat
$ ENDSUBROUTINE  ! Rdb_Bugs
$ !
$ !
$Diffies:  SUBROUTINE
$ ! P1 = module list (as input from command line)
$ !
$ ON CONTROL_Y THEN EXIT %X2C
$ ON ERROR THEN EXIT $STATUS
$ !
$ IF ( F$SEARCH("site$utils:file$edit.com") .EQS. "" ) -
  .OR. ( F$SEARCH("site$utils:file$edit_findreplace.tpu") .EQS. "" )
$ THEN wso "%''Fac'-E-FNF, components SITE$UTILS:FILE$EDIT/FINDREPLACE not found"
$      wso "           -F-ABORT, /DIFFIE updates aborted"
$      EXIT %X2C
$ ELSE FIX = "@site$utils:file$edit FINDREPLACE"
$ ENDIF
$ wso "%''Fac'-I-NYI, /DIFFIE not yet implemented (''LTM$Diffie')"
$ SHOW SYMBOL P1
$ !
$ ! FIX file "_MODULE.SQL" "_MODULE$''LTM$RelLevel.SQL" "NOEXACT"
$ !
$ EXIT 1
$ ENDSUBROUTINE  ! Diffies
$ !
$ !
$Qualifier:  SUBROUTINE
$ ! P1 = qualifier name
$ ! P2, P3, P4, P5 = global symbol(s) to set to qualifier's value
$ ! Also uses/requires global variable LTM$AllArgs (avoids quoting problems)
$ !
$ ON CONTROL_Y THEN EXIT %X2C
$ ON ERROR THEN EXIT $STATUS
$ !
$ j = 1
$ P1 = F$EXTRACT(0,3,P1)
$ IF F$LOCATE("/''P1'",LTM$AllArgs) .LT. F$LENGTH(LTM$AllArgs)
$ THEN ! find and parse "this" qualifier:
$Q0:
$      C = F$ELEMENT(j,"/",LTM$AllArgs)
$      IF ( C .EQS. "/" ) .OR. ( C .EQS. "" ) THEN GOTO Q1
$      IF F$EXTRACT(0,3,C) .EQS. F$EXTRACT(0,3,P1)
$      THEN V = F$ELEMENT(1,"=",C) - "(" - ")"
$           IF P2 .NES. "" THEN 'P2' == V
$           IF P3 .NES. "" THEN 'P3' == F$ELEMENT(0,",",V)
$           IF P4 .NES. "" THEN 'P4' == F$ELEMENT(1,",",V)
$           IF P5 .NES. "" THEN 'P5' == F$ELEMENT(2,",",V)
$           GOTO Q1
$      ENDIF
$      j = j + 1
$      GOTO Q0
$ ENDIF
$Q1:
$ EXIT 1
$ ENDSUBROUTINE  ! Qualifier
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ SET NOON
$ TYPE /PAGE sys$input

  [4mLT$MODULES.COM[0m

  This command procedure facilitates the disciplined (re)loading of Lock&Track
  stored-SQL modules (routines and functions) into a Lock&Track Offender Data-
  base (development, production or other).  It also supports the establishment
  of a known-good "level" of modules as a specially named release.

  All operations are logged into a Configuration-Management file designated by
  the logical name LT$ConfigLog.  This is just a text file which can be TYPEd
  edited and/or PRINTed at any time.

  use: $ [1m@LT$MODULES ModuleName[0m[[1m,ModuleName,...[0m]       -
                         [ [1m/SHOW[0m                       -
                           | [1mModuleLevel_to_load[0m       -
                           | [1m/LOAD=ModuleLevel_to_load[0m -
                           | [1m/SET=ModuleLevel_to_set[0m ] -
                         [ [1m/COMMENT="comment text"[0m     -
                           | [1m/DIFFIE=DiffieFilename[0m    -
                           | [1m/VERSIONS=(v1,[0m[[1mv2,v3[0m][1m)[0m ]

  where:

    P1 is the [1mname of the module[0m, a comma-separated list of module names,
       or the keyword "[1mALL[0m" or a single wildcard "[1m*[0m" to process all existing
       modules for a given L&T project.  Currently, the following L&T project
       modules are supported, although one or more of these may not be present
       in a given project:

       [1mLOCKWORKS[0m  -- all
       [1mFUNCTIONS[0m  -- all
       [1mIACCOUNTS[0m  -- all
       [1mDCLSYMBOL[0m  -- all
       [1mMERGE[0m      -- all

       [1mCALCULATE[0m  -- currently SCS only, but may move to others
       [1mBRINGDOWN[0m  -- currently PPS only
       [1mCOURTDESK[0m  -- currently PPS only

       [1mPROCESS[0m    -- testing/prototyping for various projects
       [1mTEST[0m       -- testing/prototyping for various projects

       Note that currently only FUNCTIONS_MODULE and DCLSYMBOL_MODULE use
       .SQL_PREPROCESS and .SQL_POSTPROCESS files in the various Lock&Track
       projects.

    P2 is one of the following:

       [1m/SHOW[0m - displays the current modules loaded in the target database.
         Use this option to check the currently-loaded modules [4mbefore[0m you
         do a reload operation to verify the version(s) of the module(s)
         you may be replacing.  Use syntax:  $ [1m@LT$MODULES * /SHOW[0m

       [1mModuleLevel_to_load[0m - a string of characters which designates
         a specific release-level of modules to load or reload into
         the target database.

       [1m/LOAD=ModuleLevel_to_load[0m - same as specifying [1mModuleLevel[0m above,
         using the specific qualifier syntax.
       
         If [1m/LOAD[0m is specified without an argument (string of characters), 
         you will be prompted for that release-level, with a value based
         on today's date as the default response; just press <Return> or
         <Enter> to accept this default.  If you get this prompt and then
         decide that you want to load the base sources (not a Release
         Level file or file group), enter "*".

       [1m/SET=ModuleLevel_to_set[0m - again, a string of characters which
         designates a specific release-level of module(s) to establish
         at this point.

         If [1m/SET[0m is specified without an argument (string of characters), 
         you will be prompted for that release-level, with a value based
         on today's date as the default response; just press <Return> or
         <Enter> to accept this default.  You must provide a release-
         level string for the /SET operation.

         This operation copies one or more existing *_MODULE.SQL file(s),
         plus any accompanying *.SQL_PREPROCESS and/or *.SQL_POSTPROCESS
         files (if they exist for that module) to new files with names
         derived as *_MODULE$<ModuleLevel>.SQL* ...for example:

         LOCKWORKS_MODULE.SQL is copied to LOCKWORKS_MODULE$<ModuleLevel>.SQL

         while

         FUNCTIONS_MODULE.(SQL,SQL_PREPROCESS,SQL_POSTPROCESS) copy to
           FUNCTIONS_MODULE$<ModuleLevel>.SQL,
           FUNCTIONS_MODULE$<ModuleLevel>.SQL_PREPROCESS and
           FUNCTIONS_MODULE$<ModuleLevel>.SQL_POSTPROCESS

       Note that the ModuleLevel you specify as any of the above arguments
       must contain only characters which are legal for a standard VMS
       filename, e.g., only A..Z, 0..9, $ and _ are permitted.

       It is recommended that date-derived strings, such as "20010117",
       are used for ModuleLevel arguments; this is the form offered as
       the defaults in [1m/LOAD[0m and [1m/SET[0m prompting.

       Note that when a group of files are established as a release-level,
       each of these files is automatically edited/updated so that any
       internal references to other *_MODULE files are changed to
       *_MODULE$<ModuleLevel> for complete consistency within the group.
       This occurs only for/within the newly created *_MODULE$<ModuleLevel>
       files themselves; the original *_MODULE.* files are unchanged.
       See also the [1m/DIFFIE[0m qualifier below.

    P3 is any combination of the following:

       [1m/COMMENT[0m - permits the entry of a one-line textual comment
         into the Configuration Log file.  This is useful for documenting
         specific releases, establishing release-levels, etc.

       [1m/DIFFIE[0m - (Not Yet Implemented) «»

         Note: /DIFFIE can be used only with a /SET operation; it is ignored
         if used with /SHOW, and is rejected as an error if used with /LOAD.

       [1m/VERSIONS=(v1,[v2,v3])[0m - specifies the precise version(s) of the
         module file(s) you want to set or load; by default, the "top"
         (most recent) version(s) of the files are used.

         Note: /VERSIONS can be used only with one module at a time; it
         is rejected as an error if used with "ALL", "*" or a list of
         more than one module.

         The version numbers "v1", "v2" and "v3" can be specified either
         as a pure integer, e.g., "7" or "100", or with a leading semi-
         colon, ";7" or ";100".  Since explicit version numbers are logged
         to the Configuration Log file, semicolons help with readability.

         The first number "v1" always designates the version of the main
         *_MODULE.SQL file; the second "v2" value designates the version
         of the *_MODULE.SQL_PREPROCESS file; and the third "v3" value
         designates the version of the *_MODULE.SQL_POSTPROCESS file.


  [4mExamples[0m:

  $ [1mmod*ules == "@lt$active:LT$Modules.com"[0m  ! typically defined for you
                                             !  by RAPT_TOOLS.COM

  $ [1mmodule * /SHOW[0m    ! Displays the version/description information
                      !   associated with each module loaded in the
                      !   current database.

  $ [1mmodule LOCK[0m       ! (Re)Loads LT$DevRoot:[common]Lockworks_Module.sql
                      !   into the target L&T database as defined by
                      !   your current definition of the logical name
                      !   LT$Database.  This command procedure displays
                      !   the current translation of LT$Database and
                      !   prompts you for an affirmative answer that
                      !   this is the correct database.  Answer "Yes"
                      !   to proceed (load the module), or "No" to
                      !   quit (abort).
                      !
                      ! Note that you need specify only the first few
                      !   few (unique) letters of the module's filename.

  $ [1mmodule LOCKWORKS /SET="20010117"[0m
                      ! Creates (establishes) a "known-good release"
                      !   module-level for LockWorks_Module.sql.

  $ [1mmodule FUNC /SET="20010117"[0m
                      ! Creates (establishes) a "known-good release"
                      !   module-level for Functions_Module, including
                      !   the *.sql, *.sql_PreProcess and *.sql_PostProcess
                      !   files.

  $ [1mmodule FUNC /LOAD="20010117"[0m
                      ! (Re)Loads the Functions_Module file at release-
                      !   level "20010117" (17-JAN-2001), if it exists:
                      !   LT$DevRoot:[common]Functions_Module$20010117.sql,
                      !   Functions_Module$20010117.sql_PreProcess and
                      !   Functions_Module$20010117.sql_PostProcess

  $ [1mmod FUNC 20010117[0m ! (Re)Loads the Functions_Module, same as the
                      !   previous example (shorthand form).

  $ [1mmodule lockworks /SET=ABC /VERSION=100[0m
                      ! Sets (establishes) LockWorks_Module.sql;100
                      !  as Lockworks_Module$ABC.sql

  $ [1mmod DCL /LOAD=ABC /VERS=(14,3,2) /COMMENT="Revert to prior release"[0m
                      ! Attempts to (re)load these module components:
                      !   DCLSymbol_Module.sql;14
                      !   DCLSymbol_Module.sql_PreProcess;3 and
                      !   DCLSymbol_Module.sql_PostProcess;2
                      !   and enters a comment in the Configuration Log


  $ [1mTYPE /PAGE LT$ConfigLog[0m  ! Examine the Configuration Log file

  The project's Configuration-Management Log file can be located as follows:

$ !
$ SHOW TRANSLATION LT$ConfigLog
$ wso ""
$ GOTO AllDone
