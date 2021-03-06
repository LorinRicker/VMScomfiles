$ ! SETTIME.COM -- sets/shows system time
$ !
$ ! Copyright � 1999-2016 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ver = 'F$VERIFY(0)'
$ IF p1 .EQS. "" -
  THEN  GOTO done
$ IF p2 .NES. "" -
  THEN  p1 = p1 + ":" + p2  !glue "dd-mmm-yyyy" to "hh:mm:ss.ff" with ":"
$ prv = F$SETPRV("LOG_IO")
$ SET TIME='p1'
$ prv = F$SETPRV(prv)
$done:
$ SHOW DAYTIME
$ EXIT %X10000001 + ( 0 * 'F$VERIFY(ver)' )
$ !
