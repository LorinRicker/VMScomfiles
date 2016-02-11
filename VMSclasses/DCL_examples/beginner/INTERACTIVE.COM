$ ! INTERACTIVE.COM --                                             'F$VERIFY(0)'
$ !
$ ! This command file counts the number of processes which are interactive.
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
$ SET NOON
$ Cnt = 0
$ prv = F$SETPRV("WORLD")
$ T = F$CONTEXT("PROCESS",Context,"MODE","INTERACTIVE","EQL")
$ T = F$CONTEXT("PROCESS",Context,"USERNAME","<login>","NEQ")
$I0:
$ PID = F$PID(Context)
$ IF PID .EQS. "" THEN GOTO I1
$ Cnt = Cnt + 1
$ GOTO I0
$ !
$I1:
$ prv = F$SETPRV(prv)
$ IF Cnt .GT. 0 THEN GOTO DONE
$ !
$! Command(s) to process data when there are no interactive users go here
$ !
$DONE:
$ WRITE SYS$OUTPUT Cnt," Interactive processes"
$ EXIT
