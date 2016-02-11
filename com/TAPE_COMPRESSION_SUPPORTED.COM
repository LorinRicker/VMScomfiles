$ ! TAPE_COMPRESSION_SUPPORTED.COM -- 
$ !                                                                'F$VERIFY(0)'
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
$ SET NOON
$ wso = "WRITE sys$output"
$ !
$ Dev = F$PARSE(P1,,,"DEVICE")
$ !
$ Devdepend2 = F$GETDVI(Dev,"DEVDEPEND2")
$ CompressionSupported = %X00200000
$ CompressionEnabled   = %X00400000
$ !
$ IF (Devdepend2 .AND. CompressionSupported) .EQ. CompressionSupported
$ THEN wso "Compression supported on ''Dev'"
$ ELSE wso "Compression NOT supported on ''Dev'"
$ ENDIF
$ IF (Devdepend2 .AND. CompressionEnabled) .EQ. CompressionSupported
$ THEN wso "Compression enabled on ''Dev'"
$ ELSE wso "Compression disabled on ''Dev'"
$ ENDIF
$ !
$Done:
$ EXIT
