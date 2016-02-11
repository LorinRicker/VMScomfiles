$ ! SYNCH_CLUSTER_TIME.COM --                                      'F$VERIFY(0)'
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
$ !  use: @SYNCH_CLUSTER_TIME [date/time]
$ !   P1: date/time to synch (optional)
$ !
$ SET NOON
$ IF P1 .EQS. "" THEN P1 = F$TIME()
$ wf = "WRITE f"
$ sf = "sys$scratch:synch_time.com"
$ OPEN /WRITE f 'sf'
$ wf "$ MCR SYSMAN"
$ wf "SET ENVIRONMENT /CLUSTER"
$ wf "SET PROFILE /PRIVILEGE=(OPER,LOG_IO,SYSLCK)"
$ wf "CONFIGURATION SET TIME ""''P1'"""
$ wf "CONFIGURATION SHOW TIME"
$ wf "EXIT"
$ CLOSE f
$ @'sf'
$ DELETE /NOLOG 'sf';0
$Done:
$ EXIT
