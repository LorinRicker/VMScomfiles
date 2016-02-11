$ ! CONVERT_STREAM.COM -- converts stream ASCII files (containing embedded
$ !                       <CR><LF>'s) to proper VMS text files.
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
$ IF P1 .EQS. "" THEN READ /END_OF_FILE=done -
                           /PROMPT="Filespec: " sys$command P1
$ IF P1 .EQS. "" THEN GOTO done
$ !
$Loop:
$ fn = F$SEARCH(P1)
$ IF fn .EQS. "" THEN GOTO done
$ Org = F$FILE_ATTRIBUTES(fn,"ORG")
$ IF Org .NES. "SEQ" THEN GOTO Loop  !File organization: Sequential
$ Rfm = F$FILE_ATTRIBUTES(fn,"RFM")
$ IF Rfm .NES. "FIX" THEN GOTO Loop  !Record format: Fixed 512 byte records
$ Rat = F$FILE_ATTRIBUTES(fn,"RAT")
$ IF Rat .NES. "" THEN GOTO Loop     !Record attributes: None
$ fn = fn - F$PARSE(fn,,,"VERSION","SYNTAX_ONLY")
$ WRITE sys$output "%CONVERT_STREAM-I, converting ''fn'"
$ Cvt /OUTPUT='fn' 'fn'
$ GOTO Loop
$done:
$ EXIT
