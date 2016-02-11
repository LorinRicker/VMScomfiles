$ ! PARSE2.COM -- a simple command-word parser for DCL com-files   'F$VERIFY(0)'
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
$ ! P1 : command word
$ !
$ @com:utility START parse
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ ! Examples to test:
$ @com:utility CmdParse "''P1'" Com "NAME" "NODE|DEV |DIR |NAME|TYPE|VERS|FULL"
$ WRITE sys$output "Command word: ""''Parse$Com'"""
$ !
$ !@com:utility FileParse sys$login:login.com Spec FULL !or ALL or "" (null)
$ !@com:utility FileParse sys$login:login.com Spec NODE DEV DIR NAME TYPE VER
$ @com:utility FileParse sys$login:login.com;* Spec 'Parse$Com'
$ WRITE sys$output "File parsed: ""''Parse$Spec'"""
$ GOTO Done
$ !
$ ! Some more sample calls:
$ !
$ @com:utility CmdParse "''P1'" Com "OPT1" "OPT1|OPT2|OPT3"
$ Boolean = ( Parse$Com .EQS. "OPT1" )
$ !
$ @com:utility CmdParse "''P1'" Com "A1" "A1      |B2B     |C3CC    |D4DDD   "
$ GOTO 'Parse$Com'
$ !
$Done:
$ @com:utility EXIT
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
