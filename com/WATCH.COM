$ ! WATCH.COM -- turn on and off SET WATCH FILE (unsupported DCL)
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
$ !    P1 can be any of the following:
$ !             ALL
$ !             ATTACHED
$ !             ATTRIBUTES
$ !             CONTROL_FUNCTIONS
$ !             DIRECTORY_OPERATIONS
$ !             DUMP
$ !             MAJOR_FUNCTIONS
$ !             QUOTA_OPERATIONS
$ !             NONE (to stop SET WATCH)
$ !    
$ IF P1 .EQS. "" THEN P1 = "NONE"
$ prv = F$SETPRV("CMEXEC")
$ SET WATCH FILE /CLASS='P1'
$ prv = F$SETPRV(prv)
$ EXIT
