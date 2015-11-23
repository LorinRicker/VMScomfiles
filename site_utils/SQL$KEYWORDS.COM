$ ! SQL$KEYWORDS.COM -- Check if "word" is SQL keyword             'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2004 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1995-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ SET NOON
$ Sep = ","
$ IF P2 .NES. "" THEN P1 = P1 + Sep + P2
$ IF P3 .NES. "" THEN P1 = P1 + Sep + P3
$ IF P4 .NES. "" THEN P1 = P1 + Sep + P4
$ IF P5 .NES. "" THEN P1 = P1 + Sep + P5
$ IF P6 .NES. "" THEN P1 = P1 + Sep + P6
$ IF P7 .NES. "" THEN P1 = P1 + Sep + P7
$ IF P8 .NES. "" THEN P1 = P1 + Sep + P8
$ IF P1 .EQS. "" -
  THEN READ sys$command P1 /END_OF_FILE=Done -
         /PROMPT="SQL keyword? "
$ IF P1 .NES. ""
$ THEN DataFile = "site$utils:sql$keywords.dat"
$      i   = 0
$      P1 = F$EDIT(P1,"COLLAPSE,UPCASE")
$   L0:
$      Word = F$ELEMENT(i,Sep,P1)
$      IF Word .NES. Sep
$      THEN IF Word .NES. ""
$           THEN SEARCH 'DataFile' " ''Word' " /HIGHLIGHT=BOLD
$                IF $SEVERITY .EQ. 1         ! %SEARCH-I-NOMATCHES = SEVERITY 3
$                THEN WRITE sys$output "   ""[1m''Word'[0m"" is an SQL keyword"
$                ELSE WRITE sys$output "   ""''Word'"" is not an SQL keyword"
$                ENDIF
$           ENDIF
$           i = i + 1
$           GOTO L0
$      ELSE GOTO Done
$      ENDIF
$ ENDIF
$Done:
$ EXIT
