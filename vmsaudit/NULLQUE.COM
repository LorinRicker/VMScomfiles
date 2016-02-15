$ ! NULLQUE.COM --                                                 'F$VERIFY(0)'
$ !
$ ! Copyright © 2014 by The PARSEC Group.  All rights reserved.
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Proc  = F$ENVIRONMENT("PROCEDURE")
$ Fac   = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ !
$ Prv   = F$SETPRV("OPER,SYSNAM,SYSPRV,LOG_IO")
$ !
$ wso   = "WRITE sys$output"
$ wserr = "WRITE sys$error"
$ !
$ NQname = "NullQue"
$ !
$ ! Physical terminal, must be unused, to be dedicated to this purpose:
$ onterm = "TTA0:"
$ onnode = "CYCLOP"
$ !
$ Stat = 1
$ !
$ IF ( F$GETQUI("DISPLAY_QUEUE","QUEUE_NAME",NQname) .EQS. "" )
$ THEN SET TERMINAL 'onterm' /SPEED=38400 /PAGE=100 /WIDTH=200 /NOWRAP -
                /DEVICE=LN03 /LOWERCASE /NOBROADCAST /NOECHO /HARDCOPY -
                /NOTYPE_AHEAD /NOFORM /PASTHRU /PERMANENT
$      INITIALIZE /QUEUE 'NQname' /DEVICE=TERMINAL /OWNER=SYSTEM -
                  /NOENABLE_GENERIC -
                  /AUTOSTART_ON='onnode'::'onterm' /START
$      IF $STATUS -
       THEN wserr F$FAO( "%!AS-I-QUECREATE, queue !AS created successfully", -
                         Fac, NQname )
$ ENDIF
$ !
$P1Loop:
$ IF ( P1 .EQS. "" )
$ THEN READ sys$command P1 /END_OF_FILE=Done -
         /PROMPT="Name of Print Queue to redirect: "
$      GOTO P1Loop
$ ELSE Q2redirect = P1
$      GOTO P1Done
$ ENDIF
$P1Done:
$ !
$ IF ( F$GETQUI("DISPLAY_QUEUE","QUEUE_NAME",Q2redirect) .EQS. "" )
$ THEN wserr F$FAO( "%!AS-W-QUENOEXIST, printer queue !AS does not exist", -
                     Fac, Q2redirect )
$      EXIT %X2C  !...abort
$ ENDIF
$ !
$ ! Redirect the stalled/stopped queue to the new NullQue --
$ !   this allows a-gazillion pending (stale) print jobs
$ !   to process/"print" onto-the-floor...
$ IF .NOT. F$GETQUI("DISPLAY_QUEUE","QUEUE_STOPPED",Q2redirect)
$ THEN STOP /QUEUE /RESET 'Q2redirect'
$      i = 0
$Spin:
$      WAIT 00:00:01
$      i = i + 1
$      IF ( i .LE. 5 )  ! wait up to 5 seconds for queue to stop...
$      THEN IF F$GETQUI("DISPLAY_QUEUE","QUEUE_STOPPED",Q2redirect)
$           THEN GOTO AQ   !...good to go: assign the queue
$           ELSE GOTO Spin !...try up to 5 times
$           ENDIF
$      ELSE wserr F$FAO( "%!AS-E-QUENOTSTOP, queue !AS won't stop, check manually...", -
                          Fac, Q2redirect )
$           Stat = %X2C
$           GOTO Done
$      ENDIF
$ ENDIF
$ !
$AQ:
$ ASSIGN /QUEUE 'NQname' 'Q2redirect'
$ AStat = $STATUS
$ IF AStat
$ THEN wserr F$FAO( "%!AS-S-QUE_REDIRECT, queue !AS is redirected to !AS", -
                     Fac, Q2redirect, NQname )
$      START /QUEUE 'Q2redirect'   ! make sure stalled-que is started
$      Stat = $STATUS
$ ELSE wserr F$FAO( "%!AS-E-QUEFAIL, queue !AS did not redirect correctly", -
                     Fac, Q2redirect )
$      Stat = AStat
$ ENDIF
$ !
$Done:
$ SHOW QUEUE 'Q2redirect'    ! don't /FULL here, way too long!
$ SHOW QUEUE /FULL 'NQname'
$ !
$ IF F$TYPE(Prv) .EQS. "STRING" THEN Prv = F$SETPRV(Prv)
$ EXIT 'Stat'
$ !
$Ctrl_Y:
$ RETURN %X2C
