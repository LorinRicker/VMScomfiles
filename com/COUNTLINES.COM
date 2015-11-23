$ ! COUNTLINES.COM
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1997-1999 by Evans & Ricker, Inc.  All rights reserved.
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
