$ ! TEE.COM -- split input on SYS$PIPE to SYS$OUTPUT               'F$VERIFY(0)'
$ !            and another output (file)
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
$ !  usage: @TEE log-file
$ !
$ SET NOON
$ OPEN /WRITE /ERROR=oops teefile 'P1'
$loop:
$ READ /END_OF_FILE=done sys$pipe line
$ write sys$output line
$ write teefile    line
$ GOTO loop
$done:
$ CLOSE /NOLOG teefile
$ EXIT %X01
$oops:
$ WRITE sys$error "%TEE-E-OPENERR, cannot open ''P1'"
$ EXIT %X2C
