$ ! WHAT_ODS.COM -- Determines ODS-X structure of a disk           'F$VERIFY(0)'
$ !
$ ! Copyright © 2016 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ IF ( P1 .EQS. "" )
$ THEN READ sys$command dev /PROMPT="Disk device? " /END_OF_FILE=Done
$      IF ( dev .EQS. "" ) THEN GOTO Done
$ ELSE dev = P1
$ ENDIF
$ DeviceType = F$GETDVI( dev, "ACPTYPE" )
$ IF ( DeviceType .EQS. "F11V5" )
$ THEN DeviceType = "ODS-5"
$ ELSE IF ( DeviceType .EQS. "F11V2" )
$      THEN DeviceType = "ODS-2"
$      ELSE DeviceType = "unknown"
$      ENDIF
$ ENDIF
$ WRITE sys$output "On-Disk Structure for disk ''dev': ''DeviceType'"
$ !
$Done:
$ EXIT
