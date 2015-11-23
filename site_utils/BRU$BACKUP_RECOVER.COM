$ ! BRU$BACKUP_RECOVER.COM
$ !
$ BRU$Version == "v2.02 (22-OCT-2003)"
$ BRU$Ver      = 'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2003 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1988-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  Parameters:
$ !    P1 : One or more of the following letters:
$ !         "B" - "Batch", submits a script-file to batch using RQ.
$ !         "L" - "Learn mode", records all interactive responses into a
$ !                script file for future re-use.
$ !         "N" - "No compaction/compression", disables tape-drive media
$ !               compaction (default is to use/enable compression).
$ !         "S" - "Slow", turns OFF all BRU options to optimize for speed.
$ !         "U" - "Unload", forces a tape unload upon dismount.
$ !
$ !  Logical names:
$ !    TAPE$BRU - BRU's "preferred" (default) tape drive.  If this logical
$ !               name is defined, it names the first tape drive to attempt
$ !               to allocate.
$ !
$ ON ERROR THEN EXIT 1
$ Util = "@site$utils:utility.com"
$ Util START BRU "''F$ENVIRONMENT("PROCEDURE")'" "V2003.02.03"
$ ! Require this minimum version of UTILITY.COM
$ !
$ ON CONTROL_Y THEN GOSUB Signal_Error
$ ON ERROR THEN GOTO Main_0
$ BRU$Privs     = F$SETPRV("READALL,SYSPRV,BYPASS,VOLPRO,LOG_IO,SYSNAM,OPER")
$ !
$ BRU$Verbose  == F$TRNLNM("Tools$Debug")
$ !
$ BRU$Device   == ""
$ BRU$User      = F$EDIT(F$GETJPI("","USERNAME"),"TRIM")
$ BRU$Options   = F$EDIT(P1,"COLLAPSE,UPCASE")
$ !
$ BRU$Node     == F$EDIT(F$GETSYI("NODENAME"),"TRIM,UPCASE")
$ BRU$Mode     == F$MODE()
$ BRU$NotiFile == ""
$ BRU$OpenNF   == 1
$ BRU$Weekday   = F$EDIT(F$CVTIME("",,"WEEKDAY"),"TRIM,UPCASE")
$ !
$ BRU$TapeCompaction == "TRUE"
$ !
$ wso = "WRITE sys$output"
$ wnf = "WRITE nf"
$ !
$ datecalc = "site$utils:dc$datecalc.exe"
$ IF F$SEARCH(datecalc) .NES. ""
$ THEN DateCalc = "$" + datecalc
$ ELSE DateCalc = ""
$ ENDIF
$ TotTime = F$TIME()
$ !
$ BRU$LearnMode = F$LOCATE("L",BRU$Options) .LT. F$LENGTH(BRU$Options)
$ IF .NOT. BRU$LearnMode THEN GOTO L1
$ Util ASK "Script filename" "" "BACKUP" "Z"
$ BRU$LearnFile = F$PARSE(BRU$Answer,"sys$disk:[].script")
$ OPEN /WRITE BRU$Learn-file 'BRU$LearnFile'
$ BRU$LearnFAO1 = "!ZL!49* !AS"
$ BRU$LearnFAO2 = "!50AS!AS"
$L1:
$ IF BRU$Interactive THEN @site$utils:cls
$Backup_0:
$Recover_0:
$List_0:
$ IF .NOT. BRU$Interactive THEN GOTO S1
$ wso "  Backup and Recover Utility - ",BRU$Version
$ TYPE sys$input

  1 -- Backup             : save files
  2 -- Recover            : recover files
  3 -- List               : list files in save sets

$S1:
$ Util CHOOSE "Enter your selection" "123,BRL"
$ IF BRU$LearnMode .AND. (BRU$Choice .GT. 0) -
  THEN WRITE BRU$Learn-file                  -
         F$FAO(BRU$LearnFAO1,BRU$Choice,"!BRU (B/R/L)")
$ GOTO Main_'BRU$Choice'
$ !
$Main_1:                        !Save files
$ SET ON
$ IF .NOT. BRU$Interactive THEN GOTO S2
$ TYPE sys$input
  Backup Options

  1 -- Disk               : backup an entire disk
  2 -- Incremental        : all new files
  3 -- File               : specific files

$S2:
$ Util CHOOSE "Enter your selection" "123,DIF"
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO1,BRU$Choice,"!Backup Option (D/I/F)")
$ BRU$Method = BRU$Choice
$ GOTO Backup_'BRU$Choice'
$ !
$Backup_3:                      !Files
$ BRU$Disk = ""
$ Util ASK "Files (and qualifiers)" "" "[''BRU$User'...]*.*"
$ IF BRU$Answer .EQS. "" THEN GOTO Main_1
$ BRU$Files = F$EDIT(BRU$Answer,"COLLAPSE")
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO2,BRU$Files,"!Files (qualifiers)")
$ BRU$SaveSet = "F0"
$ GOTO B0
$ !
$Backup_1:                      !Image of a disk
$ GOSUB Disks
$ IF BRU$Choice .EQ. 0 THEN GOTO Main_1
$ BRU$Files = ""
$ IF BRU$Choice .LT. 10
$ THEN BRU$A[0,8] = 48 + BRU$Choice
$ ELSE BRU$A[0,8] = 55 + BRU$Choice
$ ENDIF
$ BRU$SaveSet = "D" + BRU$A
$ GOTO B0
$ !
$Backup_2:                      !Incremental
$ GOSUB Disks
$ IF BRU$Choice .EQ. 0 THEN GOTO Main_1
$ Util ASK "Files (and qualifiers)" "" "[*...]"
$ IF BRU$Answer .EQS. "" THEN GOTO Main_1
$ BRU$Files = F$EDIT(BRU$Answer,"COLLAPSE")
$ IF BRU$Choice .LT. 10
$ THEN BRU$A[0,8] = 48 + BRU$Choice
$ ELSE BRU$A[0,8] = 55 + BRU$Choice
$ ENDIF
$ BRU$SaveSet = "I" + BRU$A
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO2,BRU$Files,"!Files (qualifiers)")
$ !
$B0:
$ BRU$Save = F$CVTIME(,"ABSOLUTE","DATE")
$ IF F$LENGTH(BRU$Save) .LT. 11 THEN BRU$Save = "0" + BRU$Save
$ BRU$SaveSet = BRU$SaveSet + BRU$Save - "-" - "-20"  !was "-19" (millenium bug)
$ SET NOON
$ Util ASK "Save set name <''BRU$SaveSet'>" "" "" ZN
$ IF .NOT. $STATUS THEN GOTO Main_1
$ SET ON
$ IF BRU$Answer .NES. "" THEN BRU$SaveSet = BRU$Answer
$ BRU$Save = F$PARSE(BRU$SaveSet,"[]''BRU$SaveSet'",,"NAME","SYNTAX_ONLY") -
           + F$PARSE(BRU$SaveSet,".bck",,"TYPE","SYNTAX_ONLY")
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO2,BRU$Answer,"!Save set name")
$ Util ASK "Create listing" "" N
$ IF BRU$Answer .EQS. "" THEN GOTO Main_1
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO2,BRU$Answer,"!Create listing")
$ IF .NOT. BRU$Answer
$ THEN BRU$Listing = ""
$ ELSE BRU$Listing = F$PARSE(BRU$SaveSet,,,"NAME","SYNTAX_ONLY")
$      BRU$Listing = F$PARSE(BRU$Listing,"sys$scratch:.lis")
$      SET NOON
$      Util ASK "Listing file <''BRU$Listing'>" "" "" ZN
$      IF .NOT. $STATUS THEN GOTO Main_1
$      SET ON
$      IF BRU$Answer .NES. "" THEN BRU$Listing = F$PARSE(BRU$Answer,"sys$scratch:.lis")
$      IF BRU$LearnMode           -
       THEN WRITE BRU$Learn-file  -
              F$FAO(BRU$LearnFAO2,BRU$Answer,"!Listing file")
$      DEFINE /NOLOG BRU$Listing 'BRU$Listing'
$      BRU$Listing = "/LIST=''BRU$Listing'"
$ ENDIF
$ SET NOON
$ Util ASK "Post-processing" "" "" ZN
$ IF .NOT. $STATUS THEN GOTO Main_1
$ SET ON
$ BRU$Post = BRU$Answer
$ IF BRU$LearnMode              -
  THEN WRITE BRU$Learn-file     -
         F$FAO(BRU$LearnFAO2,BRU$Post,"!Post_processing")
$ Util ASK "Post notification to" "" 'BRU$User'
$ IF BRU$Answer .EQS. "" THEN GOTO Main_1
$ BRU$Notify = BRU$Answer
$ IF BRU$LearnMode              -
  THEN WRITE BRU$Learn-file     -
         F$FAO(BRU$LearnFAO2,BRU$Notify,"!Post notification to")
$ CALL Ready "''BRU$Device'" "I"
$ IF BRU$Device .EQS. "" THEN GOTO Backup_0
$ BRU$Command_String =                                  -
       "@site$utils:bru$backup" +                       -
                " ""''BRU$Disk'''BRU$Files'""" +        -
                " ""''BRU$Device'""" +                  -
                " ""''BRU$Save'""" +                    -
                " ""''BRU$Method',''BRU$Listing'""" +   -
                " ""''BRU$Tape'""" +                    -
                " ""''BRU$Options',''BRU$Post'""" +     -
                " ""''BRU$Quals'"""
$ IF F$LOCATE("B",BRU$Options) .LT. F$LENGTH(BRU$Options)
$ THEN RQ$Command_String == BRU$Command_String
$      @site$utils:rq$interactive
$ ELSE 'BRU$Command_String'
$ ENDIF
$ GOTO Backup_0
$ !
$Main_2:                        !Recover files
$ SET ON
$ IF .NOT. BRU$Interactive THEN GOTO S3
$ TYPE sys$input
  Recover Options

  1 -- Disk               : recover all files from disk backups
  2 -- Incremental        : recover files from incremental backups
  3 -- File               : recover specific files

$S3:
$ Util CHOOSE "Enter your selection" "123,DIF"
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO1,BRU$Choice,"!Recover Option (D/I/F)")
$ BRU$Method = BRU$Choice
$ GOTO Recover_'BRU$Choice'
$ !
$Recover_1:                      !Image of a disk
$Recover_2:                      !Incremental
$ GOSUB Disks
$ IF BRU$Choice .EQ. 0 THEN GOTO Recover_0
$ BRU$Select = ""
$ BRU$Files = ""
$ GOTO X0
$ !
$Recover_3:                      !Files
$ BRU$Disk = ""
$ Util ASK "Select files" "" "[''BRU$User'...]*.*"
$ IF BRU$Answer .EQS. "" THEN GOTO Main_2
$ BRU$Select = "/SELECT=(" + F$EDIT(BRU$Answer,"COLLAPSE") + ")"
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO2,BRU$Answer,"!Select files")
$ Util ASK "Destination (and qualifiers)" "" "[*...]*.*"
$ IF BRU$Answer .EQS. "" THEN GOTO Main_2
$ BRU$Files = F$EDIT(BRU$Answer,"COLLAPSE")
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO2,BRU$Files,"!Destination (qualifiers)")
$ !
$X0:
$ Util ASK "Save set name"
$ IF BRU$Answer .EQS. "" THEN GOTO Main_2
$ BRU$Save = F$PARSE(BRU$Answer,"[]''BRU$Answer'",,"NAME","SYNTAX_ONLY") -
           + F$PARSE(BRU$Answer,".bck",,"TYPE","SYNTAX_ONLY")
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO2,BRU$Save,"!Save set name")
$ Util ASK "Post notification to" "" 'BRU$User'
$ IF BRU$Answer .EQS. "" THEN GOTO Main_2
$ BRU$Notify = BRU$Answer
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO2,BRU$Notify,"!Post notification to")
$X1:
$ CALL Ready "''BRU$Device'" "R"
$ IF BRU$Device .EQS. "" THEN GOTO Recover_0
$ BRU$Command_String =                                  -
       "@site$utils:bru$recover" +                      -
                " ""''BRU$Disk'''BRU$Files'""" +        -
                " ""''BRU$Device'""" +                  -
                " ""''BRU$Save'''BRU$Select'""" +       -
                " ""''BRU$Method'""" +                  -
                " ""''BRU$Tape'""" +                    -
                " ""''BRU$Options'""" +                 -
                " ""''BRU$Quals'"""
$ IF F$LOCATE("B",BRU$Options) .LT. F$LENGTH(BRU$Options)
$ THEN RQ$Command_String == BRU$Command_String
$      @site$utils:rq$interactive
$      GOTO Recover_0
$ ELSE 'BRU$Command_String'
$ ENDIF
$ IF .NOT. BRU$Interactive THEN GOTO Recover_0
$ IF BRU$Method .NE. 1 THEN GOTO X2
$ Util ASK "Proceed with INCREMENTAL recover" "" Y
$ IF .NOT. BRU$Answer THEN GOTO Recover_0
$ BRU$Method = 2
$ MOUNT /OVERRIDE=ID 'BRU$Disk'
$X2:
$ IF BRU$Method .NE. 2 THEN GOTO Recover_0
$ Util ASK "Next save set name"
$ IF BRU$Answer .EQS. "" THEN GOTO Recover_0
$ BRU$Save = F$PARSE(BRU$Answer,"[]''BRU$Answer'",,"NAME","SYNTAX_ONLY") -
           + F$PARSE(BRU$Answer,".bck",,"TYPE","SYNTAX_ONLY")
$ GOTO X1
$ !
$Main_3:                        !List
$ SET ON
$ IF .NOT. BRU$Interactive THEN GOTO S4
$ TYPE sys$input
  List Backup Volumes

  1 -- Directory          : directory of save sets
  2 -- Files              : files in save sets

$S4:
$ Util CHOOSE "Enter your selection" "12,DF"
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO1,BRU$Choice,"!List Backup Volumes (D/F)")
$ GOTO List_'BRU$Choice'
$ !
$List_1:                        !Directory
$ BRU$Save = ""
$ BRU$Listing = F$PARSE("bru$list","sys$scratch:.lis")
$ SET NOON
$ Util ASK "Listing file <''BRU$Listing'>" "" "" ZN
$ IF .NOT. $STATUS THEN GOTO Main_3
$ SET ON
$ IF BRU$Answer .NES. "" THEN BRU$Listing = F$PARSE(BRU$Answer,"sys$scratch:.lis")
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO2,BRU$Answer,"!Listing file")
$ DEFINE /NOLOG BRU$Listing 'BRU$Listing'
$ CALL Ready "''BRU$Device'"
$L0:
$ IF BRU$Device .EQS. "" THEN GOTO List_0
$ BRU$Command_String =                                  -
       "@site$utils:bru$list" +                         -
                " ""''BRU$Choice'""" +                  -
                " ""''BRU$Device'""" +                  -
                " ""''BRU$Tape'""" +                    -
                " ""''BRU$Save'""" +                    -
                " ""''BRU$Quals'""" +                   -
                " ""''BRU$Listing'"""
$ IF F$LOCATE("B",BRU$Options) .LT. F$LENGTH(BRU$Options)
$ THEN RQ$Command_String == BRU$Command_String
$      @site$utils:rq$interactive
$ ELSE 'BRU$Command_String'
$ ENDIF
$ GOTO List_0
$ !
$List_2:                        !Files
$ IF F$TYPE(BRU$Save) .EQS. "" THEN BRU$Save = ""
$ Util ASK "Save set name" "" 'BRU$Save'
$ IF BRU$Answer .EQS. "" THEN GOTO Main_3
$ BRU$Save = BRU$Answer
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO2,BRU$Save,"!Save set name")
$ BRU$Listing = F$PARSE(BRU$Save,"sys$scratch:.lis")
$ SET NOON
$ Util ASK "Listing file <''BRU$Listing'>" "" "" ZN
$ IF .NOT. $STATUS THEN GOTO Main_3
$ SET ON
$ IF BRU$Answer .NES. "" THEN BRU$Listing = F$PARSE(BRU$Answer,"sys$scratch:.lis")
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO2,BRU$Answer,"!Listing file")
$ DEFINE /NOLOG BRU$Listing 'BRU$Listing'
$ CALL Ready "''BRU$Device'" "R"
$ GOTO L0
$ !
$Done:
$Main_0:
$ BRU$Status = $STATUS
$ SET NOON
$ IF BRU$NotiFile .NES. ""
$ THEN IF F$SEARCH(BRU$NotiFile) .NES. ""
$      THEN IF DateCalc .NES. ""
$           THEN DateCalc "''TotTime'" /DELTA /SYMBOL=TotTime /SCOPE=LOCAL
$                TotTime = F$ELEMENT(0," ",TotTime) -  ! strip ".cc"
                         + " " + F$EXTRACT(0,8,F$ELEMENT(1," ",TotTime))
$                TotTime = TotTime - "0 "  ! if no days, drop that field
$                ElapsedTime = "- elapsed time: " + TotTime
$                Msg = F$FAO( "%BRU-S-SUMMARY, job completed at !%T !AS ", -
                              0, ElapsedTime )
$           ELSE ElapsedTime = F$FAO( "- completed at !%T", 0 )
$                Msg = F$FAO( "%BRU-S-COMPLETED, job done !AS", ElapsedTime )
$           ENDIF
$           CALL WrOut "''Msg'"
$           IF BRU$Mode .EQS. "BATCH"
$           THEN LogFSpec = ""
$                JobName  = F$GETQUI( "DISPLAY_ENTRY", "JOB_NAME", , "THIS_JOB" )
$                IF F$GETQUI( "DISPLAY_ENTRY", "JOB_LOG_NULL", , "THIS_JOB" )
$                THEN LogFSpec = "<none>"
$                ELSE LogFSpec = F$GETQUI( "DISPLAY_ENTRY", "LOG_SPECIFICATION", , "THIS_JOB" )
$                     LogFSpec = "MGR$BACKUP:" -
                               + F$PARSE(LogFSpec,,,"NAME","SYNTAX_ONLY") -
                               + ".LOG" + F$PARSE(LogFSpec,,,"VERSION","SYNTAX_ONLY")
$                ENDIF
$                CALL WrOut "''F$FAO( "%BRU-S-LOGFILE, !AS log: !AS", JobName, LogFSpec )'"
$           ENDIF
$           CALL WrOut "''F$FAO("!70*-")'"
$           IF F$TRNLNM("nf","lnm$process") .NES. "" THEN CLOSE nf
$           IF BRU$Mode .EQS. "BATCH"
$           THEN MAIL 'BRU$NotiFile' 'BRU$Notify' -
                   /SUBJECT="%BRU ''BRU$Weekday'/''JobName' batch job ''ElapsedTime'"
$           ENDIF
$      ENDIF
$ ENDIF
$ IF F$TRNLNM("BRU$Learn-file") .NES. "" THEN CLOSE BRU$Learn-file
$ IF F$TYPE(BRU$Tape) .EQS. "" THEN GOTO Main_0_1
$ IF (F$LOCATE("U",BRU$Options) .NE. F$LENGTH(BRU$Options)) .AND. BRU$Tape
$ THEN BRU$Dismount = "/UNLOAD"
$ ELSE BRU$Dismount = "/NOUNLOAD"
$ ENDIF
$ CALL UnReady BRU$Device0 'BRU$Dismount'
$ CALL UnReady BRU$Device1 'BRU$Dismount'
$Main_0_1:
$ IF F$TRNLNM("BRU$Listing","lnm$process") .NES. "" THEN DEASSIGN /PROCESS BRU$Listing
$ IF F$TRNLNM("nf","lnm$process") .NES. "" THEN CLOSE nf
$ IF BRU$NotiFile .NES. "" -
  THEN IF F$SEARCH("''BRU$NotiFile';-12") .NES. "" -
       THEN PURGE /KEEP=12 /NOLOG 'BRU$NotiFile'
$ BRU$Privs = F$SETPRV(BRU$Privs)
$ Util EXIT BRU
$ EXIT (BRU$Status .OR. %X10000000) + 0 * 'F$VERIFY(BRU$Ver)'
$ !
$ !
$ !
$WrOut:  SUBROUTINE
$ SET NOON
$ IF F$TRNLNM("nf","lnm$process") .NES. "" THEN wnf P1
$ wso P1
$ EXIT 1
$ ENDSUBROUTINE  ! WrOut
$ !
$Disks:                         !Select which disk
$ IF BRU$script_input
$ THEN BRU$Choice == 0
$      Util ASK "Which disk" "" 'BRU$Disk'
$      IF BRU$Answer .EQS. "" THEN GOTO D3
$      BRU$Disk    = F$ELEMENT(0,",",BRU$Answer)
$      BRU$Choice == F$ELEMENT(1,",",BRU$Answer)
$      GOTO D3
$ ENDIF
$ BRU$Opts = ""
$ BRU$D = 1
$ IF .NOT. BRU$Interactive THEN GOTO D2
$ wso "Disk Options"
$ wso ""
$D2:
$ BRU$Disk = F$TRNLNM("disks$backup",,BRU$D-1)
$ IF BRU$Disk .EQS. "" THEN GOTO D1
$ IF .NOT. F$GETDVI(BRU$Disk,"EXISTS") THEN GOTO D0
$ IF BRU$D .LT. 10
$ THEN BRU$A[0,8] = 48 + BRU$D
$ ELSE BRU$A[0,8] = 55 + BRU$D
$ ENDIF
$ BRU$Unit_'BRU$A' = F$GETDVI(BRU$Disk,"DEVNAM")
$ IF BRU$Interactive    -
  THEN wso BRU$A," -- ",BRU$Disk," (",BRU$Unit_'BRU$A',")"
$ BRU$Opts = BRU$Opts + BRU$A
$D0:
$ IF BRU$D .LT. 35
$ THEN BRU$D = BRU$D + 1
$      GOTO D2
$ ENDIF
$D1:
$ IF BRU$Interactive THEN wso ""
$ IF BRU$Opts .EQS. ""
$ THEN Util ASK "Which disk" "" "sys$sysdevice"
$      IF BRU$Choice .EQ. 0 THEN GOTO D3
$      IF F$GETDVI(BRU$Answer,"EXISTS")
$      THEN BRU$Disk = F$GETDVI(BRU$Answer,"DEVNAM")
$           BRU$Choice == 1
$      ELSE GOTO D1
$      ENDIF
$ ELSE Util CHOOSE "Which disk" 'BRU$Opts'
$      IF BRU$Choice .EQ. 0 THEN GOTO D3
$      IF BRU$Choice .LT. 10
$      THEN BRU$A[0,8] = 48 + BRU$Choice
$      ELSE BRU$A[0,8] = 55 + BRU$Choice
$      ENDIF
$      BRU$Disk = BRU$Unit_'BRU$A'
$ ENDIF
$ IF BRU$LearnMode              -
  THEN WRITE BRU$Learn-file F$FAO(BRU$LearnFAO2,"''BRU$Disk',''BRU$Choice'","!Which Disk")
$D3:
$ RETURN
$ !
$Ready: SUBROUTINE              !Make the backup device ready
$ ON CONTROL_Y THEN EXIT %X00000002C
$ ON ERROR THEN EXIT ($STATUS .OR. %X10000000)
$ !
$R0:
$ SET ON
$ BRU$Quals   == ""
$ BRU$Device0 == ""
$ BRU$Device1 == ""
$ BRU$Device  == P1
$ IF BRU$Device .EQS. ""
$ THEN SET NOON
$      ! "TAPE$BRU" is logical name for the preferred (default) BRU tape-drive,
$      ! otherwise, allocate next-available drive (in this order):
$      ALLOCATE TAPE$BRU,MK,MU,MF,MS,MT BRU$Tape_Device /NOLOG
$      IF $STATUS
$      THEN BRU$Device == F$TRNLNM("BRU$Tape_Device")
$           DEALLOCATE BRU$Tape_Device
$           DEASSIGN BRU$Tape_Device
$      ENDIF
$      SET ON
$ ENDIF
$ Util ASK "Backup device" "" 'BRU$Device'
$ IF BRU$Answer .EQS. "" THEN GOTO R3
$ BRU$Device == BRU$Answer
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO2,BRU$Device,"!Backup device")
$ SET NOON
$ BRU$Device0 == F$GETDVI(F$ELEMENT(0,",",BRU$Answer),"DEVNAM")
$ IF .NOT. $STATUS THEN GOTO R0
$ BRU$Device1 == F$ELEMENT(1,",",BRU$Answer)
$ IF BRU$Device1 .EQS. "," THEN BRU$Device1 == ""
$ IF BRU$Device1 .NES. ""  THEN BRU$Device1 == F$GETDVI(BRU$Device1,"DEVNAM")
$ IF .NOT. $STATUS THEN GOTO R0
$ BRU$Device == BRU$Device0
$ IF BRU$Device1 .NES. "" THEN BRU$Device == BRU$Device + "," + BRU$Device1
$ BRU$Tape == F$GETDVI(BRU$Device0,"SQD")
$ SET ON
$ !
$ IF (.NOT. BRU$Tape) .OR. (F$LOCATE("R",P2) .EQ. F$LENGTH(P2)) THEN GOTO R1
$ Util ASK "Rewind ''BRU$Device'" "" "Y"
$ IF BRU$Answer .EQS. "" THEN GOTO R3
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO2,BRU$Answer,"!Rewind")
$ IF BRU$Answer THEN BRU$Quals == "/REWIND"
$ !
$R1:
$ IF F$LOCATE("I",P2) .EQ. F$LENGTH(P2) THEN GOTO R2
$ Util ASK "Initialize ''BRU$Device'" "" "N"
$ IF BRU$Answer .EQS. "" THEN GOTO R3
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO2,BRU$Answer,"!Initialize")
$ IF .NOT. BRU$Answer THEN GOTO R2
$ SET NOON
$ IF BRU$Tape
$ THEN Devdepend2 = F$GETDVI(BRU$Device,"DEVDEPEND2")
$      CompressionSupported = %X00200000
$      ! If this tape drive supports compaction/compression, and it's not
$      ! being explicitly disabled (P1 contains "N"), then enable it:
$      BRU$TapeCompaction == ( Devdepend2 .AND. CompressionSupported ) .EQ. CompressionSupported 
$      IF ( BRU$TapeCompaction )
$      THEN IF BRU$Verbose THEN CALL WrOut "%BRU-I-COMPACTION, tape drive supports compaction"
$           IF ( F$LOCATE("N",BRU$Options) .LT. F$LENGTH(BRU$Options) )
$           THEN BRU$Quals == "/REWIND"  !"N" = No compaction
$           ELSE BRU$Quals == "/REWIND /MEDIA_FORMAT=COMPACTION"
$           ENDIF
$      ELSE IF BRU$Verbose THEN CALL WrOut "%BRU-I-NOCOMPACTION, tape drive does not support compaction"
$           BRU$Quals == "/REWIND"
$      ENDIF
$      ! Check if tape is (archaic) reel-to-reel type, and it's not
$      ! being explicitly disabled (P1 contains "N"), then enable high-density:
$      ReelToReel = ",MT,MS,MF,"
$      MediaName  = "," + F$EXTRACT(0,2,F$GETDVI(BRU$Device0,"MEDIA_NAME")) + ","
$      IF ( F$LOCATE(MediaName,ReelToReel) .LT. F$LENGTH(ReelToReel) ) -
       .AND. ( F$LOCATE("N",BRU$Options) .EQ. F$LENGTH(BRU$Options) )
$      THEN BRU$Quals == BRU$Quals + " /DENSITY=6250"
$      ENDIF
$ ELSE BRU$Quals == "/INITIALIZE"
$ ENDIF
$ IF BRU$Verbose THEN CALL WrOut "%BRU-I-ECHO, tape qualifiers: ''BRU$Quals'"
$ SET ON
$ !
$R2:
$ Util ASK "When ''BRU$Device' is ready, press" "" "Return"
$ IF BRU$LearnMode           -
  THEN WRITE BRU$Learn-file  -
         F$FAO(BRU$LearnFAO2,"","!press <Return> when ready")
$R3:
$ IF BRU$Answer .EQS. "" THEN BRU$Device == ""
$ EXIT
$ ENDSUBROUTINE
$ !
$UnReady: SUBROUTINE
$ SET NOON
$ ON CONTROL_Y THEN EXIT %X0000002C
$ IF F$TYPE('P1') .EQS. "" THEN EXIT
$ Dv = 'P1'
$ IF 'P1' .EQS. "" THEN EXIT
$ IF .NOT. F$GETDVI('P1',"EXISTS") THEN EXIT
$ IF F$GETDVI('P1',"MNT")
$ THEN IF BRU$Verbose THEN CALL WrOut "%BRU-I-ECHO, $ [1mDISMOUNT ''P2' ''Dv'[0m"
$      DISMOUNT 'P2' '&P1'
$ ENDIF
$ IF F$GETDVI('P1',"ALL")
$ THEN IF F$GETDVI('P1',"PID") .EQS. F$GETJPI("","PID")
$      THEN IF BRU$Verbose THEN CALL WrOut "%BRU-I-ECHO, $ [1mDEALLOCATE ''Dv'[0m"
$           DEALLOCATE '&P1'
$      ENDIF
$ ENDIF
$ 'P1' == ""
$ ENDSUBROUTINE
$ !
$Signal_Error:
$ RETURN %X2C
