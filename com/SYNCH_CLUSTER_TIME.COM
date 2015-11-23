$ ! SYNCH_CLUSTER_TIME.COM --                                      'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1995-1999 by Evans & Ricker, Inc.  All rights reserved.
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
