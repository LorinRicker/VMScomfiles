$ ! BEEP.COM -- 
$ !                                                                'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1997-1999 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ null[0,32]= %X00
$ bell[0,32]= %X07
$ WRITE sys$output bell
$ WAIT 00:00:00.25
$ WRITE sys$output bell, bell
$ WAIT 00:00:00.25
$ WRITE sys$output bell, bell, bell
$Done:
$ EXIT
