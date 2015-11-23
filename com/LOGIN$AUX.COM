$ ! LOGIN$AUX.COM --                                               'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2003 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ WRITE sys$output F$FAO("!80*-")
$ !
$ ! Edit here for common project setups, etc.:
$ ! ======================================================================
$ !!«» cd LT$DevTree [.LF]   !![.changes]
$ !!«» rdbflags xt
$ ! ======================================================================
$ !
$ WRITE sys$output F$FAO("!80*-!/")
$ !
$Done:
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
