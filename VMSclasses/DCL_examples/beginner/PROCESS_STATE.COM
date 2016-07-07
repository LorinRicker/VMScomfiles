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
$ IF ( P1 .EQS. "" )
$ THEN READ sys$command P1 /PROMPT="PID? " /END_OF_FILE=Done
$      IF ( P1 .EQS. "" ) THEN GOTO Done
$ ENDIF
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
$ EXIT
$ !
$NoProc:
$ WRITE sys$error "%PROCESS_STATE-E-NOPROC, no such process ''P1'"
$ EXIT
