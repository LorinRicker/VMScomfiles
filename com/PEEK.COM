$ ! PEEK.COM -- peek at a VMS variable location (by system address)
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
$ IF P1 .EQS. "" -
  THEN  READ /END_OF_FILE=Done /PROMPT="Address (hex): " sys$command P1
$ P1 = F$EDIT(P1,"UPCASE,COLLAPSE")
$ IF F$EXTRACT(0,2,P1) .NES. "%X" THEN P1 = "%X" + P1
$ val = F$CVSI(0,16,F$FAO("!AD",4,'P1'))
$ WRITE sys$output F$FAO("%PEEK-I, Value at address (!AS): !ZW",P1,val)
$ !
$Done:
$ EXIT
$ !
