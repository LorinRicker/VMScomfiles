$ ! LOGOUT.COM -- logout with cleanups...
$ !
$ ! Copyright © 1999-2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ !  use:  @LOGOUT [ Shutdown | Keep | Nodelete ]
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ wso = "WRITE sys$output"
$ Prv = F$SETPRV("NOSYSPRV,NOBYPASS")
$ P1  = P1 - "-"  !Strip any leading hyphen
$ P1  = F$EDIT(F$EXTRACT(0,1,P1),"UPCASE")
$ UTIL_CLEANUP = %X0803832B
$ UTIL_PURGE   = %X08038353
$ !
$ Base = F$EDIT(F$TRNLNM("sys$login"),"UPCASE") - "]"
$ SubProcess   = ( F$GETJPI("","PID") .NES. F$GETJPI("","MASTER_PID") )
$ WrongScratch = ( F$EDIT(F$TRNLNM("sys$scratch"),"UPCASE") .NES. "''Base'.SYS$SCRATCH]" )
$ NoDelScratch = ( P1 .EQS. "K" ) .OR. ( P1 .EQS. "N" )
$ !
$ Verbose = F$TRNLNM("Tools$Debug")
$ !
$ IF SubProcess .OR. WrongScratch .OR. NoDelScratch THEN GOTO L1  !skip cleanups
$ !
$ wso ""
$ wso "%LOGOUT-I, cleanup..."
$ DEFINE /NOLOG sys$error  nla0:
$ DEFINE /NOLOG sys$output nla0:
$ PURGE /NOLOG sys$login:TCPIP*.log,NET*.log /KEEP=2
$ !!DELETE /NOCONFIRM /NOLOG sys$login:netserver.log;*
$ DELETE /NOCONFIRM /NOLOG sys$scratch:*.*;* /EXCLUDE=(*.tjl,*.tpu$*)
$ DEASSIGN sys$error
$ DEASSIGN sys$output
$ !
$ ! Conditional cleanup of TPU work-files older than a couple of days ago:
$ DaysAgo = F$CVTIME("TODAY-2-00:00:00.00","COMPARISON")
$W1:
$ TCD  = F$CVTIME("TODAY","COMPARISON")
$ TFil = F$SEARCH("sys$scratch:*.tjl;*")
$ IF TFil .EQS. "" THEN GOTO W2
$ TCD = F$CVTIME(F$FILE_ATTRIBUTES(TFil,"CDT"),"COMPARISON")
$ IF TCD .LES. DaysAgo
$ THEN IF Verbose THEN WRITE sys$output F$FAO(F$MESSAGE(UTIL_CLEANUP),TFil)
$      DELETE 'TFil'
$ ENDIF
$ GOTO W1
$W2:
$ TCD  = F$CVTIME("TODAY","COMPARISON")
$ TFil = F$SEARCH("sys$scratch:*.tpu$*;*")
$ IF TFil .EQS. "" THEN GOTO L1
$ TCD = F$CVTIME(F$FILE_ATTRIBUTES(TFil,"CDT"),"COMPARISON")
$ IF TCD .LES. DaysAgo
$ THEN IF Verbose THEN WRITE sys$output F$FAO(F$MESSAGE(UTIL_CLEANUP),TFil)
$      DELETE 'TFil'
$ ENDIF
$ GOTO W2
$ !
$L1:
$ wso ""
$ IF P1 .EQS. "S" THEN EXIT
$ !
$ IF F$GETDVI("TT","TT_DIALUP")
$ THEN LOGOUT = "LOGOUT /FULL /HANGUP"  ! Modem? yes, guarantee disconnection
$ ELSE LOGOUT = "LOGOUT /BRIEF"         ! no, simple logout
$ ENDIF
$ !
$ IF Verbose
$ THEN wso "%LOGOUT-W-EXIT, LOGOUT aborted by logical Tools$Debug (exit instead)"
$      EXIT
$ ELSE LOGOUT
$ ENDIF
$ !
$Done:
$ wso "%LOGOUT-W-ABORT, LOGOUT aborted by user or error"
$ !
$Ctrl_Y:
$ RETURN %X2C
