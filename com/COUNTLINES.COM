$ ! COUNTLINES.COM
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
$ !  P1:  Filespec of file-group to count, e.g., SITE$UTILS:*.COM
$ !
$CountLines:  SUBROUTINE
$ tail /count=lines /symbol=LCount 'P1' /OUTPUT=nl:
$ TCount == TCount + F$INTEGER(LCount)
$ IF Verbose .NES. "" THEN WRITE sys$output P1, ": ", LCount, " lines"
$ EXIT 1
$ ENDSUBROUTINE  ! CountLines
$ !
$MAIN:
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ TCount == 0
$ !
$L0:
$ F = F$SEARCH(P1)
$ IF F .EQS. "" THEN GOTO Done
$ CALL CountLines 'F'
$ GOTO L0
$ !
$Done:
$ WRITE sys$output ""
$ WRITE sys$output "Total lines in ''P1': ", TCount
$ EXIT
