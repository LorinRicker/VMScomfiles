$ ! COUNT_TAILCOUNT.COM                                            'F$VERIFY(0)'
$ !
$ ! Copyright � 1999-2016 by Lorin Ricker.  All rights reserved, with acceptance,
$ ! use, modification and/or distribution permissions as granted and controlled
$ ! by and under the GPL described herein.
$ !
$ ! This program (software) is Free Software, licensed under the terms and
$ ! conditions of the GNU General Public License Version 3 as published by
$ ! the Free Software Foundation: http://www.gnu.org/copyleft/gpl.txt,
$ ! which is hereby incorporated into this software and is a non-severable
$ ! part thereof.  You have specific rights and obligations under this GPL
$ ! which are binding if and when you accept, use, modify and/or distribute
$ ! this software program (source code file) and/or derivatives thereof.
$ !
$ !   use: @COUNT file[,file...] [count-item[,count-item]...]
$ !
$ ! where: 
$ !    P1 : Filespec of file-group to count, e.g., SITE$UTILS:*.COM
$ !    P2 : Count-item is a comma-separated list of
$ !           LINES (default), WORDS, CHARACTERS, ALL, PERFILE
$ !
$TailCount:  SUBROUTINE
$ ! P1 = filespec
$ ! P2 = filename (short)
$ ! P3 = what to count
$ !
$ ON CONTROL_Y THEN GOSUB TCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ IF P3 .EQS. "" THEN P3 = "LINES"
$ CCount = 0
$ WCount = 0
$ LCount = 0
$ !
$ TAIL /COUNT=('P3') /SYMBOL=TCount 'P1' /OUTPUT=nl:
$ IF Verbose THEN wso F$FAO( "%!AS-I-DEBUG, symbol-value: !AS", Fac, TCount )
$ TCount = F$EDIT(TCount,"COLLAPSE")
$ kl = "C,W,L"
$ j  = 0
$T0:
$ val = F$ELEMENT(j,COMMA,TCount)
$ IF val .EQS. COMMA THEN GOTO T1
$ k = F$EXTRACT(0,1,F$ELEMENT(j,COMMA,P3))
$ 'k'Count = F$INTEGER(val)
$ j = j + 1
$ GOTO T0
$T1:
$ LineCount == LineCount + LCount
$ WordCount == WordCount + WCount
$ CharCount == CharCount + CCount
$ !
$ IF PerFile THEN CALL PerFileReport "''P1'" "''CCount'" "''WCount'" "''LCount'"
$ !
$ EXIT 1
$ !
$TCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! TailCount
$ !
$DCLCount:  SUBROUTINE
$ ! P1 = filespec
$ ! P2 = filename (short)
$ !
$ ON CONTROL_Y THEN GOSUB DCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ OPEN /READ /ERROR=OpenErr tfile 'P1'
$ CCount = 0
$ WCount = 0
$ LCount = 0
$ !
$D0:
$ READ /END_OF_FILE=D1 tfile tline
$ IF CountLines
$ THEN LCount = LCount + 1
$ ENDIF
$ IF CountWords
$ THEN ! split line into words on spaces, count 'em
$      compressed = F$EDIT(tline,"TRIM,COMPRESS")
$      IF compressed .EQS. "" THEN GOTO W1  ! nothing to count...
$      j = 0
$W0:   ! there's at least one word on this line
$      word = F$ELEMENT(j,SPC,compressed)
$      IF word .EQS. SPC THEN GOTO W1
$      WCount = WCount + 1
$      j = j + 1
$      GOTO W0
$W1:
$ ENDIF
$ IF CountChars
$ THEN CCount = CCount + F$LENGTH(tline)
$ ENDIF
$ GOTO D0
$ !
$D1:
$ LineCount == LineCount + LCount
$ WordCount == WordCount + WCount
$ CharCount == CharCount + CCount
$ !
$ IF PerFile THEN CALL PerFileReport "''P1'" "''CCount'" "''WCount'" "''LCount'"
$ !
$D2:
$ IF F$TRNLNM("tfile") .NES. "" THEN CLOSE tfile
$ !
$ EXIT 1
$ !
$OpenErr:
$ wso F$FAO( "%!AS-E-OPENERR, error opening file !AS", Fac, P1 )
$ GOTO D2
$ !
$DCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! DCLCount
$ !
$PerFileReport:  SUBROUTINE
$ msg = F$FAO( "%!AS-I-PER_FILE, ", Fac )
$ indent = F$LENGTH(msg)
$ wso F$FAO( "!AS!AS:", msg, P1 )
$ IF CountChars THEN wso F$FAO( "!#* !9SL character!%S", indent, F$INTEGER(P2) )
$ IF CountWords THEN wso F$FAO( "!#* !9SL word!%S",      indent, F$INTEGER(P3) )
$ IF CountLines THEN wso F$FAO( "!#* !9SL line!%S",      indent, F$INTEGER(P4) )
$ EXIT 1
$ ENDSUBROUTINE  ! PerFileReport
$ !
$ !
$ ! === Main ===
$MAIN:
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ !
$ Fac   = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ wso   = "WRITE sys$output"
$ SPC   = " "
$ COMMA = ","
$ PList = ""
$ !
$ CountChars = "FALSE"
$ CountWords = "FALSE"
$ CountLines = "FALSE"
$ PerFile    = "FALSE"
$ GoodTail   = "FALSE"
$ !
$ CharCount == 0  ! limits at 32-bit signed integer (2,147,483,647 or %X7FFFFFFF)
$ WordCount == 0
$ LineCount == 0
$ !
$ IF P2 .NES. ""
$ THEN P2List = F$EDIT(P2,"TRIM,COLLAPSE,UPCASE")
$      IF F$EXTRACT(0,1,P2List) .NES. COMMA THEN P2List = COMMA + P2LIST
$      IF F$EXTRACT(F$LENGTH(P2List),1,P2List) .NES. COMMA THEN P2List = P2LIST + COMMA
$      P2ListL = F$LENGTH(P2List)
$      IF F$LOCATE(",C",P2List) .LT. P2ListL
$      THEN CountChars = "TRUE"
$           PList = "CHAR"
$      ENDIF
$      IF F$LOCATE(",W",P2List) .LT. P2ListL
$      THEN CountWords = "TRUE"
$           IF PList .NES. ""
$           THEN PList = PList + ",WORD"
$           ELSE PList = "WORD"
$           ENDIF
$      ENDIF
$      IF F$LOCATE(",L",P2List) .LT. P2ListL
$      THEN CountLines = "TRUE"
$           IF PList .NES. ""
$           THEN PList = PList + ",LINE"
$           ELSE PList = "LINE"
$           ENDIF
$      ENDIF
$      IF F$LOCATE(",A",P2List) .LT. P2ListL  ! All...
$      THEN CountLines = "TRUE"
$           CountWords = "TRUE"
$           CountChars = "TRUE"
$           PList = "CHAR,WORD,LINE"
$      ENDIF
$      IF F$LOCATE(",P",P2List) .LT. P2ListL THEN PerFile = "TRUE"
$ ENDIF
$ IF PList .EQS. ""    ! have to count something, so count lines by default...
$ THEN PList = "LINE"
$      CountLines = "TRUE"
$ ENDIF
$ !
$ ! see if TAIL exists and works
$ IF F$TYPE(TAIL) .NES. ""
$ THEN TAIL /OUTPUT=nl: /COUNT=LINES /SYMBOL=JunkCount nl:
$      IF $STATUS .EQS. "%X00000001" THEN GoodTail = "TRUE"
$ ELSE GoodTail = "FALSE"
$ ENDIF
$ !
$ ! Why two count-methods?  Executable image TAIL.EXE is always faster than
$ ! parsing a file with DCL, but TAIL's not available on every system, so...
$ ! There's also a difference in word-counts: the DCL method parses words by
$ ! splitting on collapsed white-space (spaces), while TAIL recognizes words
$ ! separated by white-space (spaces & tabs) and punctuation (,;?!-. etc.)...
$ IF GoodTail
$ THEN Routine = "TAILCount"
$ ELSE Routine = "DCLCount"
$ ENDIF
$ IF Verbose THEN wso F$FAO( "%!AS-I-DEBUG, using routine !AS", Fac, Routine )
$ !
$ P1L  = F$LENGTH(P1)
$ Fcnt = 0
$ !
$CountEm:
$ IF ( F$LOCATE("*",P1) .LT. P1L ) .OR. ( F$LOCATE("%",P1) .LT. P1L )
$ THEN F = F$SEARCH(P1,1)
$ ELSE F = F$PARSE(P1,,,,"SYNTAX_ONLY")
$      Fcnt = Fcnt + 1
$      IF Fcnt .GT. 1 THEN F = ""
$ ENDIF
$ IF ( F .EQS. "" ) THEN GOTO Report
$ FS = F$PARSE(F,,,"NAME","SYNTAX_ONLY") + F$PARSE(F,,,"TYPE","SYNTAX_ONLY")
$ CALL 'Routine' "''F'" "''FS'" "''PList'"
$ GOTO CountEm
$ !
$Report:
$ msg = F$FAO( "%!AS-I-TOTAL, ", Fac )
$ indent = F$LENGTH(msg)
$ wso F$FAO( "!/!AStotals for !AS", msg, P1 )
$ IF CountChars THEN wso F$FAO( "!#* !9SL character!%S", indent, CharCount )
$ IF CountWords THEN wso F$FAO( "!#* !9SL word!%S",      indent, WordCount )
$ IF CountLines THEN wso F$FAO( "!#* !9SL line!%S",      indent, LineCount )
$ !
$ IF F$TYPE(LineCount) .NES. "" THEN DELETE /SYMBOL /GLOBAL LineCount
$ IF F$TYPE(WordCount) .NES. "" THEN DELETE /SYMBOL /GLOBAL WordCount
$ IF F$TYPE(CharCount) .NES. "" THEN DELETE /SYMBOL /GLOBAL CharCount
$ !
$ EXIT   !'F$VERIFY(0)'
$ !
$Ctrl_Y:
$ RETURN %X2C
