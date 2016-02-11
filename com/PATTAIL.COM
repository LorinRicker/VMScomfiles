$ ! PATTAIL.COM -- outputs last "N" lines of file from "Pattern"   'F$VERIFY(0)'
$ !
$ ! Copyright © 1999-2016 by Lorin Ricker.  All rights reserved, with acceptance,
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
