$ ! MAKE.COM --  Build an application -- v3.1                      'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1990-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  use:  @MAKE make_filespec [-options]
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ M$vfyi = F$ENVIRONMENT("VERIFY_IMAGE")
$ M$vfyp = F$ENVIRONMENT("VERIFY_PROCEDURE")
$ M$ver  = 'F$VERIFY(0,0)'
$ M$Arch = F$GETSYI("ARCH_NAME")
$ M$Lev  = 0
$ IF F$LOCATE("-",P1) .NE. 0 THEN GOTO Q0
$ T1 = P1
$ P1 = P2
$ P2 = T1
$Q0:
$ M$Switches = P2
$ M$A = 0                    ! Always ( ignore dependencies )
$ M$X = 0                    ! Debug flag
$ M$H = 0                    ! Help
$ M$L = 0                    ! Log
$ M$M = 0                    ! Display Modification dates
$ M$P = 0                    ! Create map file
$ M$S = 0                    ! Make only Strong dependencies
$ M$T = 0                    ! Link with traceback information
$ M$W = 0                    ! Wait for a job
$ M$V = 0                    ! Verify
$ IF F$LOCATE("-",P2) .NE. 0 THEN GOTO Q2
$ L = F$LENGTH(P2)
$ Q = 0
$Q1:
$ Q = Q + 1
$ IF Q .GE. L THEN GOTO Q2
$ M$'F$EXTRACT(Q,1,P2)' = 1
$ GOTO Q1
$ !
$Q2:
$ IF M$H THEN GOTO Help
$L0:
$ IF P1 .NES. "" THEN GOTO L1
$ READ /END_OF_FILE=Done /PROMPT="Make file: " sys$command P1
$ GOTO L0
$L1:
$ M$ShowTime = ( F$SEARCH("site$utils:dc$datecalc.exe") .NES. "" )
$ IF M$W .AND. (P4 .NES. "")
$ THEN SET NOON
$      SYNCHRONIZE /ENTRY='P4'                    ! Wait
$      SET ON
$ ENDIF
$ IF M$L THEN M$V = 1                             ! Log implies Verify
$ IF M$S THEN M$A = 1                             ! Strong implies Always
$ IF M$V .AND. M$ShowTime THEN Time_0 = F$TIME()  ! Capture elapsed start time
$ IF P3 .EQS. "" THEN P3 = "17-NOV-1858"
$ FILNOTFND   = %X0803896A
$ I_FILNOTFND = FILNOTFND .AND. %XFFFFFFF8 .OR. %X3 !make error into info
$ IF .NOT. M$L THEN GOTO M1
$ M$Dev = F$PARSE(P1,"sys$scratch",,"DEVICE","SYNTAX_ONLY")
$ M$Dir = F$PARSE(P1,"sys$scratch",,"DIRECTORY","SYNTAX_ONLY")
$ M$Nam = F$PARSE(P1,,,"NAME","SYNTAX_ONLY")
$ M$Log = M$Dev + M$Dir + M$Nam + ".log;"
$ OPEN /WRITE /SHARE=READ make-log 'M$Log'
$ DEFINE sys$output make-log
$ GOTO M2
$M1:
$ OPEN make-log sys$output
$M2:
$ M$MFil = F$PARSE(P1,,,"TYPE")
$ IF M$MFil .EQS. "." THEN P1 = P1 + ".mak"
$ M$MFil = F$SEARCH(P1)
$ IF M$MFil .EQS. "" THEN CALL Signal 'FILNOTFND' 'P1'
$ OPEN make-mak'M$Lev' 'M$MFil'
$ M$Dev = F$PARSE(M$MFil,,,"DEVICE","SYNTAX_ONLY")
$ M$Dir = F$PARSE(M$MFil,,,"DIRECTORY","SYNTAX_ONLY")
$ M$DoCmd = 1
$ M$TTim  = ""
$ M$IDT   = "$site$utils:Library_IDT"
$ !
$Read_Rec:
$ READ /END=Done make-mak'M$Lev' M$Rec
$ M$Rec = F$EDIT(M$Rec,"TRIM")
$ IF F$EXTRACT(0,1,M$Rec) .EQS. "$" THEN GOTO Command
$ M$Rec = F$EDIT(M$Rec,"UNCOMMENT")
$ IF M$Rec .EQS. "" THEN GOTO Read_Rec
$ IF F$LOCATE("=",M$Rec) .LT. F$LENGTH(M$Rec) THEN GOTO Target_File
$ IF F$EXTRACT(0,1,M$Rec) .EQS. "#"
$ THEN M$Lev = M$Lev + 1
$      OPEN make-mak'M$Lev' 'F$ELEMENT(1,"#",M$Rec)'
$      M$DoCmd = 1
$      GOTO Read_Rec
$ ENDIF
$ GOTO Depend_File
$ !
$Target_File:
$ M$DoCmd = 0
$ M$Strong = (F$LOCATE("=",M$Rec) .EQ. F$LOCATE("==",M$Rec))
$ M$Fil = F$EDIT(F$ELEMENT(0,"=",M$Rec),"TRIM")
$ IF M$Strong
$ THEN M$Rec = F$EDIT(F$ELEMENT(2,"=",M$Rec),"TRIM")
$ ELSE M$Rec = F$EDIT(F$ELEMENT(1,"=",M$Rec),"TRIM")
$ ENDIF
$ IF M$Fil .EQS. ""
$ THEN M$TFil = ""
$      M$TTim = F$CVTIME(P3)
$      GOTO Depend_File
$ ENDIF
$ IF F$LOCATE("/",M$Fil) .NE. F$LENGTH(M$Fil)
$ THEN M$TFil = F$EDIT(F$ELEMENT(1,"/",M$Fil),"TRIM")
$      M$TTim = F$SEARCH(F$EDIT(F$ELEMENT(0,"/",M$Fil),"TRIM"))
$      IF M$TTim .NES. ""
$      THEN M$IDT IDT 'M$TTim'/MODULE='M$TFil'/SYMBOL=M$TTim
$           IF (M$TTim .EQS. "") .AND. (M$M) THEN CALL Signal 'I_FILNOTFND' 'M$Fil'
$      ELSE CALL Signal 'FILNOTFND' 'M$Fil'
$      ENDIF
$ ELSE M$TFil = F$SEARCH(M$Fil)
$      IF M$TFil .EQS. ""
$      THEN M$TTim = ""
$           IF M$M THEN CALL Signal 'I_FILNOTFND' 'M$Fil'
$      ELSE M$TTim = F$FILE_ATTRIBUTES(M$TFil,"RDT")
$      ENDIF
$ ENDIF
$ IF M$TTim .EQS. ""
$ THEN M$DoCmd = (.NOT. M$S) .OR. M$Strong
$      GOTO Read_Rec
$ ENDIF
$ IF M$M THEN WRITE make-log F$FAO("Modified: !AS, !AS",M$TTim,M$TFil)
$ M$TTim = F$CVTIME(M$TTim)
$ !
$Depend_File:
$ IF (M$TTim .EQS. "") .OR. M$DoCmd THEN GOTO Read_Rec
$ M$Elem = -1
$D1:
$ M$Elem = M$Elem + 1
$ M$Fil = F$ELEMENT(M$Elem,",",M$Rec)
$ IF M$Fil .EQS. "," THEN GOTO Read_Rec
$ IF M$Fil .EQS. ""  THEN GOTO D1
$ IF M$S .AND. (.NOT. M$Strong) THEN GOTO Read_Rec
$ IF M$A
$ THEN M$DTim = F$TIME()
$ ELSE IF F$LOCATE("/",M$Fil) .NE. F$LENGTH(M$Fil)
$      THEN M$DFil = F$EDIT(F$ELEMENT(1,"/",M$Fil),"TRIM")
$           M$DTim = F$EDIT(F$ELEMENT(0,"/",M$Fil),"TRIM")
$           M$IDT IDT 'M$DTim'/MODULE='M$DFil'/SYMBOL=M$DTim
$           IF M$DTim .EQS. "" THEN CALL Signal 'FILNOTFND' 'M$Fil'
$      ELSE M$DFil = F$SEARCH(M$Fil)
$           IF M$DFil .EQS. "" THEN CALL Signal 'FILNOTFND' 'M$Fil'
$           M$DTim = F$FILE_ATTRIBUTES(M$DFil,"RDT")
$      ENDIF
$ ENDIF
$ IF M$M THEN WRITE make-log F$FAO("Modified: !AS, !AS",M$DTim,M$DFil)
$ IF (M$TTim .GTS. F$CVTIME(M$DTim)) .AND. (.NOT. M$A) THEN GOTO D1
$ M$DoCmd = ((.NOT. M$S) .AND. (M$TTim .LES. F$CVTIME(M$DTim))) .OR. M$Strong
$ GOTO Read_Rec
$ !
$Command:
$ IF .NOT. M$DoCmd THEN GOTO Read_Rec
$ M$ver = F$VERIFY(M$V)
'M$Rec'
$ M$ver = 'F$VERIFY(M$ver)'
$ GOTO Read_Rec
$ !
$Help:
$ DEFINE /USER_MODE sys$input sys$command
$ HELP MAKE
$ !
$Done: IF F$TYPE(M$vfyp) .NES. "" THEN M$ver = 'F$VERIFY(M$vfyp,M$vfyi)'
$ M$Status = $STATUS
$ IF F$TYPE(M$Lev) .NES. ""
$ THEN IF M$Lev .GT. 0
$      THEN CLOSE make-mak'M$Lev'
$           M$Lev = M$Lev - 1
$           M$ver  = 'F$VERIFY(0,0)'
$           GOTO Read_Rec
$      ENDIF
$ ENDIF
$ SET NOON
$ IF F$TRNLNM("make-mak''M$Lev'") .NES. "" THEN CLOSE make-mak'M$Lev'
$ IF F$TRNLNM("make-log") .NES. "" THEN CLOSE make-log
$ IF ( F$TYPE(Time_0) .NES. "" ) .AND. M$ShowTime
$ THEN Days = "$site$utils:dc$datecalc"
$      Days "''Time_0'" /DELTA /SYMBOL=Time_0 /SCOPE=LOCAL
$      WRITE sys$output F$FAO("%MAKE-I-ELAPSED, build time was !AS",TIME_0)
$ ENDIF
$ EXIT (M$Status .OR. %X10000000)
$ !
$Ctrl_Y:
$ RETURN %X0000002C
$ !
$Signal: SUBROUTINE
$ M$Msg = F$FAO(F$MESSAGE(P1),P2,P3,P4,P5,P6,P7,P8)
$ WRITE sys$error M$Msg
$ IF M$L THEN WRITE make-log M$Msg
$ EXIT (%X10000000 .OR. 'P1')
