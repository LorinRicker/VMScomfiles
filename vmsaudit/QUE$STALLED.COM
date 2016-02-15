$ ! QUE$STALLED.COM --                                             'F$VERIFY(0)'
$ !
$ ! Copyright © 2014 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ! Retrieves job-counts from batch/printer/device queues, as a means to
$ ! detect stalled jobs piled up over a threshold count.
$ !
$ !   use: $ @QUE$STALLED [ THRESHOLD ]
$ ! where: P1 is an integer (threshold) -- If the total number of queued jobs
$ !           in any queue is over this threshold, then that queue will be
$ !           reported.  If P1 is not specified, procedure looks for a global
$ !           symbol QUESTALL$THRESHOLD for this value; if that symbol is
$ !           is undefined, this procedure uses the value 100 as a default.
$ !        P2 if TRUE outputs an (optional) report header.
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ Proc  = F$ENVIRONMENT("PROCEDURE")
$ Fac   = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ Node  = F$GETSYI("NODENAME")
$ wso   = "WRITE sys$output"
$ wserr = "WRITE sys$error"
$ !
$ IF ( P1 .NES. "" )
$ THEN QUESTALL$THRESHOLD == F$INTEGER(P1)
$ ELSE IF F$TYPE( QUESTALL$THRESHOLD ) .EQS. ""
$      THEN QUESTALL$THRESHOLD == 100
$      ENDIF
$ ENDIF
$ !
$ Now = F$CVTIME("","ABSOLUTE","DATE") + " " -
      + F$CVTIME("","ABSOLUTE","HOUR") + ":" + F$CVTIME("","ABSOLUTE","MINUTE")
$ !
$ IF P2   ! optional mini-header:
$ THEN wso F$FAO( "%!AS-I-NODENAME, on node !AS --", Fac, Node )
$      wso F$FAO( "%!AS-I-QUE_EVAL, evaluating VMS Queues: job-counts exceeding threshold !ZL --", -
                  Fac, QUESTALL$THRESHOLD )
$      wso ""
$ ENDIF
$ !
$ jnk = F$GETQUI("CANCEL_OPERATION")  ! reset
$ QExThreshold = "FALSE"
$ !
$L0:
$ CurQ = F$GETQUI("DISPLAY_QUEUE","QUEUE_NAME","*","WILDCARD")
$ IF ( CurQ .EQS. "" ) THEN GOTO L1
$ ExecJC   = F$GETQUI("DISPLAY_QUEUE","EXECUTING_JOB_COUNT","*","FREEZE_CONTEXT")
$ PendJC   = F$GETQUI("DISPLAY_QUEUE","PENDING_JOB_COUNT","*","FREEZE_CONTEXT")
$ TimeJC   = F$GETQUI("DISPLAY_QUEUE","TIMED_RELEASE_JOB_COUNT","*","FREEZE_CONTEXT")
$ HoldJC   = F$GETQUI("DISPLAY_QUEUE","HOLDING_JOB_COUNT","*","FREEZE_CONTEXT")
$ RetaJC   = F$GETQUI("DISPLAY_QUEUE","RETAINED_JOB_COUNT","*","FREEZE_CONTEXT")
$ TotalJC  = ExecJC + PendJC + TimeJC + HoldJC + RetaJC
$ !
$ IF ( TotalJC .GT. QUESTALL$THRESHOLD )
$ THEN QExThreshold = "TRUE"
$      ind = 17
$      wso F$FAO( "%!AS-I-QUEJOBCOUNT, job in queue !AS at !AS:", -
                   Fac, CurQ, Now )
$      wso F$FAO( "!#* executing: !6<!SL!>   pending: !6<!SL!>   after: !6<!SL!>", -
                   F$LENGTH(Fac)+ind, ExecJC, PendJC, TimeJC )
$      wso F$FAO( "!#*   holding: !6<!SL!>  retained: !6<!SL!>", -
                   F$LENGTH(Fac)+ind, HoldJC, RetaJC )
$      wso F$FAO( "!#* Total: !7<!SL!>", F$LENGTH(Fac)+ind+4, TotalJC )
$      wso ""
$ ENDIF
$ GOTO L0
$L1:
$ !
$ jnk = F$GETQUI("CANCEL_OPERATION")  ! reset
$ !
$ IF P2 .AND ( .NOT. QExThreshold )
$ THEN wso F$FAO( "%!AS-I-QUE_OKAY, no VMS queue exceeded the job-count threshold !ZL.", -
                   Fac, QUESTALL$THRESHOLD )
$      wso ""
$ ENDIF
$ !
$ EXIT 1
$ !
$Ctrl_Y:
$ RETURN %X2C
