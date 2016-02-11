$ ! TESTLEN.COM --                                                 'F$VERIFY(0)'
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
$ wso = "WRITE sys$output"
$ !
$ OPEN /READ /ERROR=Oops tf TEST.TXT
$ !
$L0:
$ READ /END_OF_FILE=Done tf data
$ wso F$FAO( ">>> Length of data record: !SL", F$LENGTH(data) )
$ wso ">>> data: " + F$EXTRACT(0,50,data) + " ..."
$ GOTO L0
$ !
$Done:
$ IF F$TRNLNM("tf") .NES. "" THEN CLOSE tf
$ EXIT
$ !
$Oops:
$ wso "%TESTLEN-E-OPENERR, error opening TEST.TXT"
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
