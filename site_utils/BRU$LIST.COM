$ ! BRU$LIST.COM --                                                'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2003 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1988-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ! @bru$package:bru$list       -
$ !    'BRU$Choice'             -
$ !    'BRU$Device'             -
$ !    'BRU$Tape'               -
$ !    'BRU$Save'               -
$ !    'BRU$Quals'              -
$ !    'BRU$Listing'
$ !
$ ON CONTROL_Y THEN GOSUB Signal_Error
$ ON WARNING THEN GOTO Done
$ !
$ BRU$Choice  = P1
$ BRU$Device  = P2
$ BRU$Tape    = P3
$ BRU$Save    = P4
$ BRU$Quals   = P5
$ BRU$Listing = P6
$ !
$ BRU$Device0 = F$ELEMENT(0,",",BRU$Device)
$ BRU$Device1 = F$ELEMENT(1,",",BRU$Device)
$ IF BRU$Device1 .EQS. "," THEN BRU$Device1 = ""
$ GOTO LIST_'BRU$Choice'
$ !
$LIST_1:
$ BRU$Files = ""
$ IF .NOT. BRU$Tape THEN BRU$Files = "[000000]*.bck"
$ DIRECTORY = "DIRECTORY"
$ IF F$GETDVI(BRU$Device0,"MNT") THEN DISMOUNT /NOUNLOAD 'BRU$Device0'
$ IF BRU$Verbose THEN CALL WrOut "%BRU-I-ECHO, $ [1mMOUNT /NOASSIST /NOWRITE /OVERRIDE=IDENTIFICATION ''BRU$Device0'[0m"
$ MOUNT /NOASSIST /NOWRITE /OVERRIDE=IDENTIFICATION 'BRU$Device0'
$ IF BRU$Verbose
$ THEN CALL WrOut "%BRU-I-ECHO, $ [1mDIRECTORY ''BRU$Device0'''BRU$Files' /SIZE /DATE[0m -"
$      CALL WrOut "                 [1m/OUTPUT=''BRU$Listing'[0m"
$ ENDIF
$ DIRECTORY 'BRU$Device0''BRU$Files' /SIZE /DATE /OUTPUT='BRU$Listing' 
$ IF BRU$Verbose THEN CALL WrOut "%BRU-I-ECHO, $ [1mDISMOUNT /NOUNLOAD ''BRU$Device0'[0m"
$ DISMOUNT /NOUNLOAD 'BRU$Device0'
$ IF BRU$Device1 .NES. "" THEN CALL WrOut F$FAO(F$MESSAGE(%X08038640)) !UTIL_DEV2
$ GOTO L0
$ !
$LIST_2:
$ BRU$SaveSet = F$PARSE(BRU$Save,,,"NAME","SYNTAX_ONLY") -
              + F$PARSE(BRU$Save,".bck",,"TYPE","SYNTAX_ONLY")
$ BRU$SaveSet = BRU$Device0 + BRU$SaveSet
$ IF BRU$Device1 .NES. "" THEN BRU$SaveSet = BRU$SaveSet + "," + BRU$Device1
$ IF BRU$Mode .EQS. "BATCH"
$ THEN BRU$Assist = "/ASSIST"
$ ELSE BRU$Assist = "/NOASSIST"
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
$ IF BRU$Verbose
$ THEN CALL WrOut "%BRU-I-ECHO, $ [1mBACKUP ''BRU$Assist'[0m -"
$      CALL WrOut "                 [1m/IGNORE=(LABEL_PROCESSING)[0m -"
$      CALL WrOut "                 [1m/LIST=''BRU$Listing'[0m -"
$      CALL WrOut "                 [1m''BRU$SaveSet' /SAVE_SET[0m -"
$      CALL WrOut "                 [1m''BRU$Quals'[0m"
$ ENDIF
$ !
$ SET NOON
$ BACKUP 'BRU$Assist' /IGNORE=(LABEL_PROCESSING) -
    /LIST='BRU$Listing' 'BRU$SaveSet' /SAVE_SET 'BRU$Quals'
$L0:
$ IF (BRU$Interactive) .AND. (F$SEARCH(BRU$Listing) .NES. "")
$ THEN TYPE /PAGE 'BRU$Listing'
$      Util ASK "To continue, press" "" "RETURN"
$ ENDIF
$ BRU$Status = 1
$ GOTO L2
$ !
$Done:
$ BRU$Status = ($STATUS .OR. %X10000000)
$ SET NOON
$L2:
$ EXIT BRU$Status
$ !
$Signal_Error:
$ RETURN %X0000002C
$ !
$WrOut:  SUBROUTINE
$ SET NOON
$ IF F$TRNLNM("nf","lnm$process") .NES. "" THEN wnf P1
$ wso P1
$ EXIT 1
$ ENDSUBROUTINE  ! WrOut
