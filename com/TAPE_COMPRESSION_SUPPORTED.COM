$ ! TAPE_COMPRESSION_SUPPORTED.COM -- 
$ !                                                                'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 2000 by Evans & Ricker, Inc.  All rights reserved.
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
