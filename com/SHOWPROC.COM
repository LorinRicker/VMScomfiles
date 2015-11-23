$ ! SHOWPROC.COM -- SHOW PROCESS /CONTINUOUS                       'F$VERIFY(0)'
$ !
$ !  use: @showproc [pid] [ALL]
$ !
$ ON CONTROL THEN GOTO Done
$ ON ERROR   THEN GOTO Done
$ prv = F$SETPRV("CMKRNL,WORLD")
$L0:
$ IF P1 .EQS. ""
$ THEN who /NODE='F$EDIT(F$GETSYI("SCSNODE"),"TRIM")'
$      READ sys$command P1 /END_OF_FILE=Done -
           /PROMPT="PID of process to show: "
$      GOTO L0
$ ELSE GOTO L1
$ ENDIF
$L1:
$ IF P2 .NES. "ALL" THEN P2 = "CONTINUOUS"
$ DEFINE /USER_MODE sys$input sys$command
$ SHOW PROCESS /'P2' /ID='P1'
$Done:
$ prv = F$SETPRV(prv)
$ EXIT
