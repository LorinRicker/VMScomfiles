$ ! TEE.COM -- split input from SYS$PIPE to SYS$OUTPUT             'F$VERIFY(0)'
$ !            and another output (file)
$ !
$ ! Copyright © 1999-2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ !  Usage: @TEE teefile
$ !  In pipes:
$ !    $ PIPE show system | @com:tee logs:capture_sys.lis | search sys$pipe RWAST
$ !  or:
$ !    $ PIPE show system | search sys$pipe RWAST | @com:tee logs:capture_RWAST.lis
$ !
$ SET NOON
$ OPEN /WRITE /ERROR=Oops teefile 'P1'
$Loop:
$ READ /END_OF_FILE=Done sys$pipe line
$ WRITE sys$output line
$ WRITE teefile    line
$ GOTO Loop
$Done:
$ CLOSE /NOLOG teefile
$ EXIT %X01  !'F$VERIFY(0)'
$Oops:
$ WRITE sys$error "%TEE-E-OPENERR, cannot open ''P1'"
$ EXIT %X2C  !'F$VERIFY(0)'
$ !
