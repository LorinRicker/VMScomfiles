$ ! PATTAIL.COM -- outputs last "N" lines of file from "Pattern"   'F$VERIFY(0)'
$ !
$ !  @ptail File "SearchText" [Match] [Format]
$ !                            OR      PASSALL
$ !                            AND     NONULLS
$ !                            NOR     DUMP
$ !                            NAND
$ !
$ ON ERROR     THEN GOTO Done
$ ON CONTROL_Y THEN GOTO Done
$ IF P1 .EQS. ""
$ THEN READ sys$command P2 /END_OF_FILE=Done /PROMPT="   File: "
$ ENDIF
$ IF P2 .EQS. ""
$ THEN READ sys$command P2 /END_OF_FILE=Done /PROMPT="Pattern: "
$ ENDIF
$ IF P3 .EQS. "" THEN P3 = "OR"
$ IF P4 .EQS. "" THEN P4 = "PASSALL"
$ IF P5 .NES. ""
$ THEN DEFINE /USER_MODE sys$output 'P5'
$      Head = "/NOHEADING"
$ ELSE Head = ""
$ ENDIF
$ !
$ SEARCH 'P1' 'P2' 'Head'/MATCH='P3' /FORMAT='P4' /REMAINING
$Done:
$ EXIT
