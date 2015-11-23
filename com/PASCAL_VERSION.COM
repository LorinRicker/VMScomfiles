$ ! PASCAL_VERSION.COM -- 
$ !                                                                'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1999 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ Lst = "sys$scratch:pas_listing.tmp"
$ PASCAL /NOOBJECT /LISTING='Lst' sys$input
PROGRAM X;
BEGIN
END.
$ !
$ SEARCH 'Lst' "Pascal V"
$ !
$Done:
$ EXIT
