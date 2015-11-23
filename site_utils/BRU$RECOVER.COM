$ ! BRU$RECOVER.COM -- Recover files                               'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2003 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1988-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ! @bru$package:bru$recover            -
$ !     'BRU$Disk''BRU$Files'           -       !Output
$ !     'BRU$Device'                    -       !Input
$ !     'BRU$Save'                      -       !Save_Set
$ !     'BRU$Method'                    -       !1=DISK 2=INCREMENTAL 3=FILES
$ !     'BRU$Tape'                      -       !Input is tape (boolean)
$ !     'BRU$Options                    -       !Options
$ !     'BRU$Quals                              !Volume options
$ !
$ ON CONTROL_Y THEN GOSUB Signal_Error
$ ON ERROR     THEN GOTO  Done
$ !
$ BRU$Target   = P1
$ BRU$Device   = P2
$ BRU$Save     = P3
$ BRU$Method   = P4
$ BRU$Tape     = P5
$ BRU$Options  = P6
$ BRU$Quals    = P7
$ BRU$IQ       = "/SAVE_SET" + BRU$Quals        !Input Qualifiers
$ BRU$CQ       = "/IGNORE=(LABEL_PROCESSING)"   !Command Qualifiers
$ BRU$OQ       = "/OWNER=ORIGINAL"              !Output Qualifiers
$ !
$ IF BRU$Method .EQ. 2 -                        !Incremental restore
  THEN BRU$CQ = BRU$CQ + "/INCREMENTAL"
$ IF BRU$Method .EQ. 1 -                        !Image
  THEN BRU$CQ = BRU$CQ + "/IMAGE /RECORD"
$ !
$ IF BRU$Tape -
  THEN IF F$LOCATE("S",BRU$Options) .EQ. F$LENGTH(BRU$Options) -
       THEN BRU$IQ = BRU$IQ + "/BLOCK_SIZE=16384 /NOCRC"
$ BRU$Device0 = F$ELEMENT(0,",",BRU$Device)
$ BRU$Device1 = F$ELEMENT(1,",",BRU$Device)
$ IF BRU$Device1 .EQS. "," THEN BRU$Device1 = ""
$ BRU$Save = BRU$Device0 + BRU$Save
$ IF BRU$Device1 .NES. "" THEN BRU$Save = BRU$Save + "," + BRU$Device1
$ !
$ ALLOCATE /NOLOG 'BRU$Device0'
$ IF BRU$Device1 .NES. "" THEN ALLOCATE /NOLOG 'BRU$Device1'
$ IF (BRU$Method .NE. 1) THEN GOTO B1
$ IF F$GETDVI(BRU$Target,"FOR") THEN GOTO B1
$ IF F$GETDVI(BRU$Target,"MNT") THEN DISMOUNT /NOUNLOAD 'BRU$Target'
$ MOUNT /FOREIGN 'BRU$Target'  !Disks (image backup)
$ !
$B1:
$ IF BRU$Mode .EQS. "BATCH"
$ THEN BRU$CQ = BRU$CQ + "/ASSIST"
$ ELSE BRU$CQ = BRU$CQ + "/NOASSIST"
$ ENDIF
$ !
$ IF .NOT. BRU$Tape
$ THEN IF .NOT. F$GETDVI(BRU$Device0,"MNT")
$      THEN IF BRU$Verbose THEN CALL WrOut "%BRU-I-ECHO, $ [1mMOUNT /FOREIGN ''BRU$Device0'[0m"
$           MOUNT /FOREIGN 'BRU$Device0'
$      ENDIF
$      IF BRU$Device1 .NES. ""
$      THEN IF .NOT. F$GETDVI(BRU$Device1,"MNT")
$           THEN IF BRU$Verbose THEN CALL WrOut "%BRU-I-ECHO, $ [1mMOUNT /FOREIGN ''BRU$Device1'[0m"
$                MOUNT /FOREIGN 'BRU$Device1'
$           ENDIF
$      ENDIF
$ ENDIF
$ !
$ SET NOON
$ !
$ BRU$NotiFile == "sys$scratch:BRU$Recover_Notification.log"
$ IF BRU$OpenNF
$ THEN OPEN /WRITE /SHARE=READ nf 'BRU$NotiFile'
$      BRU$OpenNF    == 0   ! OPEN once only...
$      BRU$Iteration == 1
$      CALL WrOut "''F$FAO( "%BRU-I-NODE, file recovery on node !AS", BRU$Node )'"
$      CALL WrOut "''F$FAO("!70*-")'"
$ ENDIF
$ !
$ IF F$LOCATE("/",BRU$Target) .LT. F$LENGTH(BRU$Target)
$ THEN B$Tar = F$EDIT(F$ELEMENT(0,"/",BRU$Target),"TRIM")  !trim qualifiers
$ ELSE B$Tar = BRU$Target
$ ENDIF
$ CALL WrOut "''F$FAO( "%BRU-I-START!ZL, recovery of !AS to !AS", BRU$Iteration, BRU$Save, B$Tar )'"
$ CALL WrOut "''F$FAO( "!#* started !%D", 16, 0 )'"
$ Time0 = F$TIME()
$ !
$ IF BRU$Verbose
$ THEN CALL WrOut "%BRU-I-ECHO, $ [1mBACKUP ''BRU$CQ'[0m -"
$      CALL WrOut "                 [1m''BRU$Save'[0m -"
$      CALL WrOut "                 [1m''BRU$IQ'[0m -"
$      CALL WrOut "                 [1m''BRU$Target'[0m -"
$      CALL WrOut "                 [1m''BRU$OQ'[0m"
$ ENDIF
$ !
$ BACKUP 'BRU$CQ' -
    'BRU$Save''BRU$IQ' -
    'BRU$Target''BRU$OQ'
$ !
$ CALL WrOut "''F$FAO( "%BRU-I-DONE!2ZL,  recovery of !AS completed !%T", BRU$Iteration, B$Tar, 0 )'"
$ IF DateCalc .NES. ""
$ THEN DateCalc "''Time0'" /DELTA /SYMBOL=Time0 /SCOPE=LOCAL
$      Time0 = F$ELEMENT(0," ",Time0) -  ! strip "ss.cc"
             + " " + F$EXTRACT(0,5,F$ELEMENT(1," ",Time0))
$      CALL WrOut "''F$FAO( "%BRU-I-ELAPSED, this recovery took !AS (elapsed time)", Time0 )'"
$ ENDIF
$ CALL WrOut "''F$FAO("!70*-")'"
$ BRU$Iteration == BRU$Iteration + 1
$ !
$ BRU$Status = 1
$ GOTO D1
$ !
$Done:
$ BRU$Status = ($STATUS .OR. %X10000000)
$ SET NOON
$D1:
$ IF BRU$Method .EQ. 1 THEN CALL UnReady BRU$Target
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
$UnReady: SUBROUTINE
$ SET NOON
$ ON CONTROL_Y THEN EXIT %X0000002C
$ IF F$TYPE('P1') .EQS. "" THEN EXIT
$ IF 'P1' .EQS. "" THEN EXIT
$ IF .NOT. F$GETDVI('P1',"EXISTS") THEN EXIT
$ IF F$GETDVI('P1',"MNT") THEN DISMOUNT /NOUNLOAD '&P1'
$ IF F$GETDVI('P1',"ALL") THEN DEALLOCATE '&P1'
$ 'P1' == ""
$ ENDSUBROUTINE
$ !
$Signal_Error:
$ RETURN %X0000002C
