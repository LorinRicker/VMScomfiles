$ ! LOGOUT.COM -- cleans up user's directory before LOGOUT
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1995-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !     @LOGOUT [PWNS] [n]      P:      Purge  (P2 is versions to keep)
$ !                             W:      cleanup [.scratch] Wastebasket
$ !                             N:      cleanup Netserver.log
$ !                             S:      Shutdown in progress
$ !                             Q:      Don't announce actions (Quiet)
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ IF F$GETJPI("","PID") .NES. F$GETJPI("","MASTER_PID") THEN GOTO Brief
$ Opt = F$EDIT(P1,"UPCASE,COLLAPSE")
$ Len = F$LENGTH(Opt)
$ IF Len .EQ. 0 THEN GOTO Brief
$ Verbose = F$LOCATE("Q",Opt) .EQ. Len -     ! Announce if "Q" is not present
            .OR. F$TRNLNM("Tools$Debug")
$ !
$Purge:
$ IF F$LOCATE("P",Opt) .EQ. Len THEN GOTO Wastebasket
$ IF F$TYPE(P2) .EQS. "INTEGER" THEN P2 = 1
$ UTIL_PURGE = %X08038353
$ IF Verbose THEN WRITE sys$output F$FAO(F$MESSAGE(UTIL_PURGE),"[...]*.*")
$ SET DEFAULT SYS$LOGIN
$ PURGE /KEEP='P2' [...]*.*
$ !
$Wastebasket:
$ User = F$EDIT(F$GETJPI("","USERNAME"),"TRIM")
$ IF F$LOCATE("W",Opt) .EQ. Len THEN GOTO NetServer
$ SDir = "[" + User + ".SCRATCH]"
$ IF F$PARSE("sys$scratch",,,"DIRECTORY") .NES. SDir THEN GOTO NetServer
$ Context = ""
$ Count = 0
$W0:
$ PID = F$PID(Context)
$ IF PID .NES. ""
$ THEN IF (F$GETJPI(PID,"USERNAME") .EQS. User) .AND.   -
          (F$GETJPI(PID,"MODE") .EQS. "INTERACTIVE")    -
       THEN Count = Count + 1
$      IF Count .GT. 1 THEN GOTO NetServer
$      GOTO W0
$ ENDIF
$ UTIL_CLEANUP = %X0803832B
$ ! Hide file-access-conflict errors on F$FILE_ATTRIBUTE tests:
$ DEFINE /PROCESS /NOLOG sys$output nl:
$ DEFINE /PROCESS /NOLOG sys$error  nl:
$ NLog = "sys$scratch:*.*;*"
$ IF Verbose THEN WRITE sys$output F$FAO(F$MESSAGE(UTIL_CLEANUP),NLog)
$ IF F$SEARCH(NLog) .NES. "" THEN  DELETE 'NLog' /EXCLUDE=(*.tjl,*.tpu*)
$ ! Conditional cleanup of TPU work-files older than a couple of days ago:
$ DaysAgo = F$CVTIME("TODAY-2-00:00:00.00","COMPARISON")
$W1:
$ TFil = F$SEARCH("sys$scratch:*.tjl;*")
$ IF TFil .EQS. "" THEN GOTO W2
$ TCD = F$CVTIME(F$FILE_ATTRIBUTES(TFil,"CDT"),"COMPARISON")
$ IF TCD .LES. DaysAgo
$ THEN IF Verbose THEN WRITE sys$output F$FAO(F$MESSAGE(UTIL_CLEANUP),TFil)
$      DELETE 'TFil'
$ ENDIF
$ GOTO W1
$W2:
$ TFil = F$SEARCH("sys$scratch:*.tpu$*;*")
$ IF TFil .EQS. "" THEN GOTO W3
$ TCD = F$CVTIME(F$FILE_ATTRIBUTES(TFil,"CDT"),"COMPARISON")
$ IF TCD .LES. DaysAgo
$ THEN IF Verbose THEN WRITE sys$output F$FAO(F$MESSAGE(UTIL_CLEANUP),TFil)
$      DELETE 'TFil'
$ ENDIF
$ GOTO W2
$W3:
$ IF F$TRNLNM("sys$output","lnm$process") .EQS. "_NLA0:" THEN DEASSIGN /PROCESS sys$output
$ IF F$TRNLNM("sys$error","lnm$process")  .EQS. "_NLA0:" THEN DEASSIGN /PROCESS sys$error
$ !
$NetServer:
$ IF F$LOCATE("N",Opt) .EQ. Len THEN GOTO Shutdown
$ UTIL_CLEANUP = %X0803832B
$ NLog = "sys$login:netserver.log;*"
$N0:
$ NFil = F$SEARCH(NLog)
$ IF NFil .NES. ""
$ THEN OPEN N-Tmp 'NFil' /ERROR=N0
$      CLOSE N-Tmp
$      IF Verbose
$      THEN WRITE sys$output F$FAO(F$MESSAGE(UTIL_CLEANUP),NLog)
$           Verbose = "FALSE"
$      ENDIF
$      DELETE 'NFil'
$      GOTO N0
$ ENDIF
$ !
$Shutdown:
$ IF F$LOCATE("S",Opt) .LT. Len THEN EXIT
$ !
$Brief:
$ LOGOUT = "LOGOUT"
$ LOGOUT
$ !
$Done:
$ WRITE sys$output "%LOGOUT-W-ABORT, logout aborted by user or error"
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
