$ ! RAPTFLAGS.COM -- manage RAPT debug-flags logical name          'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2004 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1993-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ! P1: any combination of the RAPT/RMG flag values: [ flags[,output_file ] ]
$ !     or: [ flags ] [ output_file ]
$ !     "" means deassign the logical name.
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ wso = "WRITE sys$output"
$ !
$ F  = "RMG$DEBUG_FLAGS"
$ IF F$LOCATE("?",P1) .LT. F$LENGTH(P1) THEN GOTO Help
$ IF P1 .EQS. ""
$ THEN IF F$TRNLNM(F,"LNM$JOB") .NES. ""
$      THEN DEASSIGN /JOB 'F'
$      ENDIF
$ ELSE IF P2 .NES. "" THEN P1 = F$ELEMENT(0,",",P1) + "," + P2
$      DEFINE /JOB /NOLOG 'F' 'P1'
$      SHOW LOGICAL /FULL 'F'
$ ENDIF
$ !
$Done:
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$ !
$Help:
$ wso ""
$ wso "  Use: [1m@RAPTflags[0m [ [1mflags[0m[[1m,output_file[0m ] ]"
$ wso "   or: [1m@RAPTflags[0m [ [1mflags[0m ] [ [1moutput_file[0m ]"
$ wso ""
$ wso "       to define logical name [4m", F, "[0m"
$ wso ""
$ IF F$TRNLNM(F) .NES. "" THEN SHOW LOGICAL /FULL 'F'
$ wso ""
$ TYPE sys$input

  [4mflag[0m  [4mMeaning                                                     [0m
  "[1mB[0m":  Report all [1mB[0mucket names
  "[1mC[0m":  Report all [1mC[0mallback names
  "[1mD[0m":  Report [1mD[0matabase name and attributes
  "[1mF[0m":  Report [1mF[0mields and attributes
  "[1mG[0m":  Echo all [1mG[0mUI/client protocol commands
  "[1mI[0m":  Show [1mI/O[0m (SQL back-end) commands
  "[1mP[0m":  Report [1mP[0merformance timings (data operations & callbacks)
  "[1mQ[0m":  Ignore missing-[1mQ[0mualifier(s) for navigation
  "[1mR[0m":  Report all [1mR[0mesources
  "[1mS[0m":  Report [1mS[0mcreen characteristics
  "[1mT[0m":  Report [1mT[0mables and attributes
  "[1mV[0m":  Report [1mV[0malidation list names
  "[1mX[0m":  Do not e[1mX[0mecute SQL (back-end) commands
  "[1mY[0m":  Rollback transactions; don't commit any database changes.

  [1moutput_file[0m captures all messages appearing in the Message-Window.

$ EXIT
