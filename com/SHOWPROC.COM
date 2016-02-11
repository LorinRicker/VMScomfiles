$ ! SHOWPROC.COM -- SHOW PROCESS /CONTINUOUS                       'F$VERIFY(0)'
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
$ !  use: @showproc [pid] [ALL]
$ !
$ ON CONTROL THEN GOTO Done
$ ON ERROR   THEN GOTO Done
$ prv = F$SETPRV("CMKRNL,WORLD")
$L0:
$ IF P1 .EQS. ""
$ THEN who /NODE='F$EDIT(F$GETSYI("SCSNODE"),"TRIM")'
$      READ sys$command P1 /END_OF_FILE=Done -
           /PROMPT="PID of process to show: "
$      GOTO L0
$ ELSE GOTO L1
$ ENDIF
$L1:
$ IF P2 .NES. "ALL" THEN P2 = "CONTINUOUS"
$ DEFINE /USER_MODE sys$input sys$command
$ SHOW PROCESS /'P2' /ID='P1'
$Done:
$ prv = F$SETPRV(prv)
$ EXIT
