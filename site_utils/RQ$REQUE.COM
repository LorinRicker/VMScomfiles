$ ! RQ$REQUE.COM - Foundation command file for periodic batch execution 'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2003 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1988-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ! P1 = <command>
$ ! P2 = <day>,<time>,<increment>
$ ! P3 = <system>,<job_name>,<user>
$ !
$ SET NOON
$ RQ$Verbose == F$TRNLNM("Tools$Debug")
$ !
$ WRITE sys$output "command: ",P1
$ 'P1'
$ @site$utils:rq$submit "''P1'" "''P2'" "''P3'"
$ !
$ IF F$MODE() .EQS. "BATCH" -
  THEN IF F$TYPE(RQ$Verbose) .NES. "" -
       THEN DELETE /SYMBOL /GLOBAL RQ$Verbose
$ EXIT
