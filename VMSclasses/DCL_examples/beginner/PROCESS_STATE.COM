$ ! PROCESS_STATE.COM --                                           ! 'F$VERIFY(0)'
$ !
$ ! Copyright © 2016 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ON ERROR THEN GOTO NoProc
$ !
$ IF ( P1 .EQS. "?" ) THEN GOTO Help
$ !
$ IF ( P1 .EQS. "SHOW" )
$ THEN P1 = ""
$      SHOW SYSTEM /PAGE=SAVE=4
$ ENDIF
$ !
$ IF ( P1 .EQS. "" )
$ THEN READ sys$command P1 /PROMPT="PID? " /END_OF_FILE=Done
$      IF ( P1 .EQS. "" ) THEN GOTO Done
$ ENDIF
$ !
$ prv = F$SETPRV( "WORLD" )
$ !
$ state = F$GETJPI( P1, "STATE" )
$ efwm  = F$GETJPI( P1, "EFWM" )
$ pname = F$GETJPI( P1, "PRCNAM" )
$ !
$ IF ( state .EQS. "MWAIT" )
$ THEN sts = "/RWAST/RWMBX/RWNPG/RWPFF/RWPAG/RWBRK/RWIMG/RWQUO/RWLCK/RWSWP" -
           + "/RWMPE/RWMPB/RWSCS/RWCLU/RWCAP/RWCSV/RWSNP/RWXFR/RWINS/RWEXH/"
$      state = state + " - " + F$ELEMENT( efwm, "/", sts )
$      IF ( state .EQS. "" ) .OR. ( state .EQS. "/" ) -
       THEN state = "MWAIT (other)" ! unrecognised EFWM value
$ ENDIF
$ !
$ WRITE sys$output "Process name: ''pname', PID: ''P1', state: ''state'"
$ !
$Done:
$ IF F$TYPE(prv) .EQS. "STRING" THEN prv = F$SETPRV( prv )
$ EXIT  ! 'F$VERIFY(0)'
$ !
$NoProc:
$ WRITE sys$error "%PROCESS_STATE-E-NOPROC, no such process ''P1'"
$ EXIT
$ !
$ !
$Help:
$ TYPE /PAGE sys$input
    [4mVMS Process States[0m

        CUR -- Current
        COM -- Computable                COMO -- Computable, outswapped
        LEF -- Local event flag wait     LEFO -- Local event flag wait, outswapped
        HIB -- Hibernating               HIBO -- Hibernating, outswapped
       SUSP -- Suspended                SUSPO -- Suspended, outswapped

        CEF -- Common event flag wait
        PFW -- Page fault wait
        FPG -- Free page wait
      COLPG -- Collided page wait
      PSXFR -- POSIX fork wait

      MWAIT -- Miscellaneous wait
      RWAST -- AST wait
      RWBRK -- Waiting for BROADCAST to finish
      RWCAP -- CPU capability required
      RWCLU -- Cluster transition wait
      RWCSV -- Cluster server
      RWIMG -- Image activation lock
      RWLCK -- Lock ID database
      RWMBX -- Mailbox full
      RWMPE -- Modified page list empty
      RWMPB -- Modified page writer busy
      RWNPG -- Nonpaged pool
      RWPAG -- Paged pool
      RWPFF -- Page file full
      RWQUO -- Pooled quota
      RWSCS -- SCS wait
      RWSWP -- Swapfile spacelist empty

$ EXIT  ! 'F$VERIFY(0)'
