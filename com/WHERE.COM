$ ! WHERE.COM --                                                   'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1996-1999 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ SET NOON
$ Last = "(no previous)"
$ IF F$TYPE(CZ) .EQS. "STRING" -
  THEN IF CZ .NES. "" THEN Last = "(prev: " + CZ + ")"
$ WRITE sys$output F$FAO("!AS!AS!6* !AS"    -
                         ,F$TRNLNM("SYS$NODE"),F$ENVIRONMENT("DEFAULT") -
                         ,Last)
$ EXIT
