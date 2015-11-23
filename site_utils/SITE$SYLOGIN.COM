$ ! SITE$SYLOGIN.COM -- system-wide login procedure Site customizations
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1999-1998 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ Ver = 'F$VERIFY(0)'
$ SET NOON
$ IF P1 .EQS. "" THEN P1 = F$MODE()
$ GOTO 'P1'
$ !
$SETUP:
$ ! System Manager's overrides for smsk$* logical names:
$!DEFINE /JOB   smsk$cls        LIGHT           !LIGHT/DARK
$!DEFINE /JOB   smsk$keypad     APPLICATION     !APPLICATION/NUMERIC
$ GOTO DONE
$ !
$INTERACTIVE:
$ ! create global DCL symbols for all users:
$ GOTO DONE
$ !
$BATCH:
$ GOTO DONE
$ !
$NETWORK:
$OTHER:
$DONE:
$ EXIT (%X10000000 .OR. $STATUS) + 0 * F$VERIFY(Ver)
