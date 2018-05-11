$ ! BELL.COM --                                                    'F$VERIFY(0)'
$ !
$ ! Copyright © 2015-2016 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ !  use:  @BELL [ number-of-bells ] [ interval-between | PROGRESSIVE ]
$ !
$ !
$ ON CONTROL THEN GOTO Done
$ ON ERROR THEN GOTO Done
$ !
$ bel[0,7]= 7
$ wso = "WRITE sys$output"
$ Progressive = "FALSE"
$ !
$ IF P1 .EQS. "" THEN P1 = 3
$ IF P2 .EQS. ""
$ THEN P2 = "00.25"
$ ELSE IF F$EXTRACT(0,1,F$EDIT(P2,"TRIM,UPCASE")) .EQS. "P"
$      THEN Progressive = "TRUE"
$      ELSE IF F$INTEGER(P2) .LT. 10 THEN P2 = "0" + P2
$      ENDIF
$ ENDIF
$ !
$ i = 1
$Loop:
$ IF i .GT. P1 THEN GOTO Done
$ IF i .GT. 1  THEN WAIT 00:00:'P2'
$ wso bel + " Ding!"
$ IF Progressive
$ THEN P2 = F$STRING(i-1) + ".25"
$      IF i .LT. 10 THEN P2 = "0" + P2
$ ENDIF
$ i = i + 1
$ GOTO Loop
$ !
$Done:
$ EXIT
