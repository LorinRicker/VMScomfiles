$ ! This command file counts the number of processes which are interactive.
$
$ SET NOON
$ Cnt = 0
$ prv = F$SETPRV("WORLD")
$ T = F$CONTEXT("PROCESS",Context,"MODE","INTERACTIVE","EQL")
$ T = F$CONTEXT("PROCESS",Context,"USERNAME","<login>","NEQ")
$I0:
$ PID = F$PID(Context)
$ IF PID .EQS. "" THEN GOTO I1
$ Cnt = Cnt + 1
$ GOTO I0
$
$I1:
$ prv = F$SETPRV(prv)
$ IF Cnt .GT. 0 THEN GOTO DONE
$
$! Command(s) to process data when there are no interactive users go here
$
$DONE:
$ WRITE SYS$OUTPUT Cnt," Interactive processes"
$ EXIT
