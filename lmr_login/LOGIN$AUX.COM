$ ! LOGIN$AUX.COM --                                               'F$VERIFY(0)'
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
