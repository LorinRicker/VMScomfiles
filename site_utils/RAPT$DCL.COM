$ ! RAPT$DCL.COM -- RAPT calls to DCL utilities
$ !                                                                'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1998 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ GOTO 'P1'
$ GOTO Done
$PASSWORD:
$ SET PASSWORD
'P2'
'P3'
'P3'
$ GOTO Done
$UUENCODE:
$ uu = "$ucx$uuencode"
$ uu 'P2' sys$output
$ GOTO Done
$UUDECODE:
$ uu = "$ucx$uudecode"
$ uu sys$command sys$scratch:'P2'
$ GOTO Done
$Done:
$ EXIT
