$ ! FILE$MOVE.COM -- 
$ !                                                                'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1997-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  $ MOVE src1[,src2...] tar2 [/LOG]  !on same or different devices
$ !  $ MOVE @filelist [/LOG]            !lines of "src1[,src2...] tar2"
$ !
$MAIN:
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ Log = ""
$ wso = "WRITE sys$output"
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ DD  = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(DD,,,"NAME","SYNTAX_ONLY")
$ DD  = F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ !
$L1:
$ IF P1 .EQS. ""
$ THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="Source file-spec: "
$      IF P1 .EQS. "" THEN GOTO L1
$ ENDIF
$ IF F$EXTRACT(0,1,P1) .EQS. "@" THEN GOTO IndirectSpec
$ !
$ i = 1
$Q0:
$ IF i .GT. 3 THEN GOTO Q1
$ P'i' = F$EDIT(P'i',"COMPRESS,TRIM,UPCASE")
$ IF F$LOCATE("/LOG",P'i') .LT. F$LENGTH(P'i')
$ THEN P'i' = P'i' - "/LOG"
$      Log = "/LOG"
$ ENDIF
$ i = i + 1
$ GOTO Q0
$ !
$Q1:
$ IF ( P3 .NES. "" ) .AND. ( P2 .EQS. "" ) THEN P2 = P3   !swap
$L2:
$ IF P2 .EQS. ""
$ THEN READ sys$command P2 /END_OF_FILE=Done /PROMPT="Destination file-spec: "
$      IF P2 .EQS. "" THEN GOTO L2
$ ENDIF
$ !
$ CALL DirectSpec "''P1'" "''P2'"
$ GOTO Done
$ !
$IndirectSpec:
$ IF P2 .EQS. "/LOG" THEN Log = P2
$ Files = P1 - "@"
$ Files = F$PARSE(Files,".lis")
$ OPEN /READ /ERROR=FNF f 'Files'
$IS0:
$ READ /END_OF_FILE=IS1 f Fl
$ Fl = F$EDIT(Fl,"COMPRESS,UPCASE,UNCOMMENT")
$ IF Fl .EQS. "" THEN GOTO IS0                   !skip blank lines & comments
$!===============
$ CALL DirectSpec 'Fl'
$!===============
$ GOTO IS0
$ !
$IS1:
$ CLOSE f
$ !
$Done:
$ IF F$TYPE(MOVE$D1) .NES. "" THEN DELETE /SYMBOL /GLOBAL MOVE$D1
$ IF F$TYPE(MOVE$D2) .NES. "" THEN DELETE /SYMBOL /GLOBAL MOVE$D2
$ EXIT
$ !
$FNF:
$ wso "%''Fac'-E-FNF, cannot find @-list ''Files'"
$ wso ""
$ GOTO Done
$ !
$ !
$ !
$DirectSpec:  SUBROUTINE
$ ! P1 = filespec1
$ ! P2 = filespec2
$ ON CONTROL_Y THEN EXIT %X2C
$ i = 0
$ F0 = "sys$disk:[]"
$DS0:
$ Fl = F$ELEMENT(i,",",P1)
$ IF Fl .EQS. "," THEN EXIT 1                  !more files?
$ FS   = F$PARSE(Fl,F0,"*.*",,"SYNTAX_ONLY")   !expand w/sticky dev:[dir]
$ FLen = F$LENGTH(FS)
$ Wild = ( F$LOCATE("*",FS) .LT. FLen ) .OR. ( F$LOCATE("%",FS) .LT. FLen )
$ GotOne = 0
$DS1:
$ F0 = F$PARSE(Fl,F0,,"DEVICE","SYNTAX_ONLY") -  !save sticky dev:[dir]
     + F$PARSE(Fl,F0,,"DIRECTORY","SYNTAX_ONLY")
$ Fl = F$SEARCH(FS)
$ IF Fl .NES. ""
$ THEN CALL TheProcess "''Fl'" "''P2'"
$     !===============
$      IF Wild
$      THEN GotOne = 1
$           GOTO DS1       !next wildcard
$      ELSE i = i + 1
$           GOTO DS0       !next comma-element
$      ENDIF
$ ELSE IF .NOT. GotOne THEN wso "%''Fac'-E-FNF, cannot find ''FS'"
$      i = i + 1
$      GOTO DS0
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! DirectSpec
$ !
$PhysicalDevice:  SUBROUTINE
$ !Translates P1 iteratively to find the true/base physical device name
$ SET NOON
$ D0 = F$PARSE(P1,,,"DEVICE","SYNTAX_ONLY")
$ IF F$LOCATE(":",D0) .EQ. F$LENGTH(D0) THEN D0 = D0 - ":"
$L0:
$ D1 = F$TRNLNM(D0)
$ IF F$LOCATE(":",D1) .EQ. F$LENGTH(D1) THEN D1 = D1 - ":"
$ IF D1 .NES. ""
$ THEN D0 = D1
$      GOTO L0
$ ELSE 'P2' == D0
$      IF Verbose THEN SHOW SYMBOL 'P2'
$      EXIT 1
$ ENDIF
$ ENDSUBROUTINE  ! PhysicalDevice
$ !
$ !          ==========
$TheProcess: SUBROUTINE
$ ON CONTROL_Y THEN EXIT %X2C
$ P1 = F$EDIT(P1,"UPCASE")
$ P2 = F$EDIT(P2,"UPCASE")
$ CALL PhysicalDevice "''P1'" MOVE$D1
$ CALL PhysicalDevice "''P2'" MOVE$D2
$ !
$ IF MOVE$D1 .EQS. MOVE$D2     !same disk/device?
$ THEN RENAME 'P1' 'P2' 'Log'
$ ELSE P0 = P1 - F$PARSE(P1,,,"VERSION","SYNTAX_ONLY") - ";"
$      FN = F$PARSE(P1,,,"NAME","SYNTAX_ONLY") + F$PARSE(P1,,,"TYPE","SYNTAX_ONLY")
$      FSize = F$FILE_ATTRIBUTE(P1,"EOF")
$      IF FSize .GE. 50000    ! a "huge" file?
$      THEN wso "%''Fac'-I-COPYING, ''FN' is huge, please wait (a while)..."
$      ELSE IF FSize .GE. 5000    ! a "large" file?
$           THEN wso "%''Fac'-I-COPYING, ''FN' is large, please wait..."
$           ENDIF
$      ENDIF
$      COPY 'P0' 'P2' 'Log'
$      IF F$PARSE(P1,,,"VERSION","SYNTAX_ONLY") .EQS. ";"
$      THEN P0 = P1 - ";" + ";0"
$      ELSE P0 = P1
$      ENDIF
$      DELETE /NOLOG 'P0'
$      IF $STATUS .AND. ( Log .NES. "" )
$      THEN P0 = F$PARSE(P2,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(P2,,,"DIRECTORY","SYNTAX_ONLY")
$           wso "     -I-MOVED, ''P1' moved to ''P0'"
$      ENDIF
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! TheProcess
$ !
$Ctrl_Y:
$ RETURN %X2C
