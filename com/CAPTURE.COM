$ ! CAPTURE.COM -- captures output to file
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
$ IF p1 .EQS. "" -
  THEN  READ /END_OF_FILE=Done /PROMPT="Command? " sys$command p1
$ IF p2 .EQS. "" -
  THEN  READ /END_OF_FILE=Done /PROMPT="Capture file? " sys$command p2
$ IF p2 .EQS. "" THEN p2 = "sys$scratch:capture.tmp"
$ DEFINE /USER_MODE sys$error  'p2'
$ DEFINE /USER_MODE sys$output 'p2'
$ DEFINE /USER_MODE sys$input sys$command
$ 'p1'
$ IF p3 .NES. "" THEN TYPE /PAGE 'p2'
$Done:
$ EXIT
