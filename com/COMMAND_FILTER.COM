$ ! COMMAND_FILTER.COM --                                          'F$VERIFY(0)'
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
$ !  @command_filter "Command" "SearchText" [Match] [Window] [Format] [TempFile]
$ !                                          OR      (1)      PASSALL
$ !                                          AND     (n)      NONULLS
$ !                                          NOR     (m,n)    DUMP
$ !                                          NAND
$ !
$ ON ERROR     THEN GOTO Done
$ ON CONTROL_Y THEN GOTO Done
$ IF P1 .EQS. ""
$ THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="    Command: "
$ ENDIF
$ IF P2 .EQS. ""
$ THEN READ sys$command P2 /END_OF_FILE=Done /PROMPT="Search text: "
$ ENDIF
$ IF P3 .EQS. "" THEN P3 = "OR"
$ IF P4 .EQS. ""
$ THEN P4 = "(1)"
$ ELSE P4 = P4 -"(" - ")"
$      P4 = "(" + P4 + ")"
$ ENDIF
$ IF P5 .EQS. "" THEN P5 = "PASSALL"
$ IF P6 .EQS. "" THEN P6 = "sys$scratch:command_filter.temporary_output"
$ !
$ DEFINE /USER_MODE sys$output 'P6'
$ 'P1'
$ IF $STATUS
$ THEN SEARCH 'P6' 'P2' /MATCH='P3' /WINDOW='P4' /FORMAT='P5'
$ ENDIF
$ !
$Done:
$ IF F$SEARCH(P6) .NES. "" THEN DELETE /NOLOG 'P6';*
$ EXIT
