$ ! BELL.COM --                                                    'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1986-2000 by Evans & Ricker, Inc.  All rights reserved.
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
$ ELSE IF F$EXTRACT(0,1,P2) .EQS. "P"
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
