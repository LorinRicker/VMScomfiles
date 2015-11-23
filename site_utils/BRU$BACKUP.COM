$ ! BRU$BACKUP.COM -- Save files                                   'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2003 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1988-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ! @bru$package:bru$backup             -
$ !     "''BRU$Disk'''BRU$Files'"       -
$ !     "''BRU$Device'"                 -
$ !     "''BRU$Save'"                   -
$ !     "''BRU$Method',''BRU$Listing'"  -
$ !     "''BRU$Tape'"                   -
$ !     "''BRU$Options',''BRU$Post'"    -
$ !     "''BRU$Quals'"
$ !
$ ON CONTROL_Y THEN GOSUB Signal_Error
$ ON ERROR     THEN GOTO  Done
$ !
$ BRU$Source   = P1
$ BRU$Device   = P2
$ BRU$Save     = P3
$ BRU$SaveFN   = F$PARSE(P3,,,"NAME","SYNTAX_ONLY")
$ BRU$Method   = F$ELEMENT(0,",",P4)
$ BRU$Listing  = F$ELEMENT(1,",",P4)
$ BRU$Tape     = P5
$ BRU$Options  = F$ELEMENT(0,",",P6)
$ BRU$Post     = F$ELEMENT(1,",",P6)
$ BRU$Quals    = P7
$ BRU$IQ       = "/RECORD /FAST"                         !Input Qualifiers
$ BRU$CQ       = BRU$Listing  -                          !Command Qualifiers
                 + "/NOALIAS" -
                 + "/IGNORE=(INTERLOCK,LABEL_PROCESSING)"
$ !
$ IF BRU$Listing .NES. ""
$ THEN IF F$TRNLNM("BRU$Listing") .EQS. ""
$      THEN BRU$List_Temp = BRU$Listing - "/LIST="
$           DEFINE /NOLOG BRU$Listing 'BRU$List_Temp'
$      ENDIF
$ ENDIF
$ !
$ BRU$OQ       = "/SAVE_SET" + BRU$Quals                 !Output Qualifiers
$ BRU$Device0  = F$ELEMENT(0,",",BRU$Device)
$ BRU$Device1  = F$ELEMENT(1,",",BRU$Device)
$ IF BRU$Device1 .EQS. "," THEN BRU$Device1 = ""
$ BRU$Save = BRU$Device0 + BRU$Save
$ IF BRU$Device1 .NES. "" THEN BRU$Save = BRU$Save + "," + BRU$Device1
$ !
$ IF BRU$Method .EQ. 3 -                        !Files
  THEN BRU$IQ = ""
$ IF BRU$Method .EQ. 2 -                        !Incremental backup
  THEN BRU$IQ = BRU$IQ + "/SINCE=BACKUP"
$ IF BRU$Method .EQ. 1 -                        !Image
  THEN BRU$CQ = BRU$CQ + "/IMAGE"
$ !
$ IF BRU$Tape
$ THEN BRU$CQ = BRU$CQ + "/VERIFY"
$      IF F$LOCATE("S",BRU$Options) .EQ. F$LENGTH(BRU$Options) -
       THEN BRU$OQ = BRU$OQ + "/BLOCK_SIZE=16384 /NOCRC"
$ ENDIF
$ !
$ IF .NOT. F$GETDVI(BRU$Device0,"ALL") THEN ALLOCATE /NOLOG 'BRU$Device0'
$ IF BRU$Device1 .NES. "" -
  THEN IF .NOT. F$GETDVI(BRU$Device1,"ALL") THEN ALLOCATE /NOLOG 'BRU$Device1'
$ !
$ IF BRU$Mode .EQS. "BATCH"
$ THEN BRU$CQ = BRU$CQ + "/ASSIST"
$ ELSE BRU$CQ = BRU$CQ + "/NOASSIST"
$ ENDIF
$ !
$ BRU$NotiFile == "sys$scratch:BRU$Backup_Notification.log"
$ IF BRU$OpenNF
$ THEN OPEN /WRITE /SHARE=READ nf 'BRU$NotiFile'
$      BRU$OpenNF    == 0   ! OPEN once only...
$      BRU$Iteration == 1
$      CALL WrOut "''F$FAO( "%BRU-I-NODE, file backup on node !AS", BRU$Node )'"
$      CALL WrOut "''F$FAO("!70*-")'"
$ ENDIF
$ !
$ IF BRU$Tape
$ THEN IF F$LOCATE("/MEDIA",BRU$Quals) .LT. F$LENGTH(BRU$Quals)
$      THEN IF F$GETDVI(BRU$Device0,"MNT") THEN DISMOUNT /NOUNLOAD 'BRU$Device0'
$           ! To achieve tape-device compaction/compression,
$           ! must initialize and mount the tape "manually":
$           IF BRU$TapeCompaction
$           THEN BRU$Compact = "/MEDIA_FORMAT=COMPACTION"
$           ELSE BRU$Compact = ""
$           ENDIF
$           BRU$TapeLabel = F$EXTRACT(0,6,BRU$SaveFN)
$           CALL WrOut "''F$FAO( "%BRU-I-INIT, initializing media !AS, label !AS", BRU$Device0, BRU$TapeLabel )'"
$           IF BRU$Verbose
$           THEN CALL WrOut "%BRU-I-ECHO, $ [1mINITIALIZE ''BRU$Compact' ''BRU$Device0' ''BRU$TapeLabel'[0m"
$                CALL WrOut "%BRU-I-ECHO, $ [1mMOUNT /FOREIGN ''BRU$Compact' ''BRU$Device0'[0m"
$           ENDIF
$           INITIALIZE 'BRU$Compact' 'BRU$Device0' 'BRU$TapeLabel'
$           MOUNT /FOREIGN 'BRU$Compact' 'BRU$Device0'
$      ENDIF
$ ELSE IF .NOT. F$GETDVI(BRU$Device0,"MNT") THEN MOUNT /FOREIGN 'BRU$Device0'
$      IF BRU$Device1 .NES. "" -
       THEN IF .NOT. F$GETDVI(BRU$Device1,"MNT") -
            THEN MOUNT /FOREIGN 'BRU$Device1'
$ ENDIF
$ !
$ SET NOON
$ BRU$BPrivs = F$SETPRV("READALL,SYSPRV,BYPASS,VOLPRO,LOG_IO,SYSNAM,OPER")
$ !
$ IF F$LOCATE("/",BRU$Source) .LT. F$LENGTH(BRU$Source)
$ THEN B$Src = F$EDIT(F$ELEMENT(0,"/",BRU$Source),"TRIM")  !trim qualifiers
$ ELSE B$Src = BRU$Source
$ ENDIF
$ CALL WrOut "''F$FAO( "%BRU-I-START!2ZL, backup of !AS to !AS", BRU$Iteration, B$Src, BRU$Save )'"
$ CALL WrOut "''F$FAO( "!#* started !%D", 16, 0 )'"
$ Time0 = F$TIME()
$ !
$ IF BRU$Verbose
$ THEN CALL WrOut "%BRU-I-ECHO, $ [1mBACKUP ''BRU$CQ'[0m -"
$      CALL WrOut "                 [1m''BRU$Source'[0m -"
$      CALL WrOut "                 [1m''BRU$IQ'[0m -"
$      CALL WrOut "                 [1m''BRU$Save'[0m -"
$      CALL WrOut "                 [1m''BRU$OQ'[0m"
$ ENDIF
$ BACKUP 'BRU$CQ' -
         'BRU$Source''BRU$IQ' -
         'BRU$Save''BRU$OQ'
$ !
$ IF BRU$Post .NES. ""
$ THEN CALL WrOut "%BRU-I-POST, post processing: ''BRU$Post'"
$      'BRU$Post'
$ ENDIF
$ !
$ CALL WrOut "''F$FAO( "%BRU-I-DONE!2ZL,  backup of !AS completed !%T", BRU$Iteration, B$Src, 0 )'"
$ IF DateCalc .NES. ""
$ THEN DateCalc "''Time0'" /DELTA /SYMBOL=Time0 /SCOPE=LOCAL
$      Time0 = F$ELEMENT(0," ",Time0) -  ! strip ".cc"
             + " " + F$EXTRACT(0,8,F$ELEMENT(1," ",Time0))
$      Time0 = Time0 - "0 "  ! if no days, drop that field
$      CALL WrOut "''F$FAO( "%BRU-I-ELAPSED, this backup took !AS (elapsed time)", Time0 )'"
$ ENDIF
$ B$List = F$TRNLNM("BRU$Listing")
$ IF B$List .NES. "" -
  THEN CALL WrOut "''F$FAO( "%BRU-I-LISTING, !AS list file: !AS", BRU$SaveFN, B$List )'"
$ CALL WrOut "''F$FAO("!70*-")'"
$ BRU$Iteration == BRU$Iteration + 1
$ !
$ BRU$Status = 1
$ GOTO D1
$ !
$Done:
$ IF BRU$Notifile .NES. "" -
  THEN IF F$SEARCH(BRU$Notifile) .NES. "" -
       THEN DELETE /NOLOG 'BRU$Notifile';*
$ BRU$Status = ($STATUS .OR. %X10000000)
$ SET NOON
$D1:
$ IF F$TYPE(BRU$BPrivs) .NES. "" THEN BRU$BPrivs = F$SETPRV(BRU$BPrivs)
$ EXIT BRU$Status
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
$Signal_Error:
$ RETURN %X0000002C
