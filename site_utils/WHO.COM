$ ! WHO.COM -- driver file for site$utils:who.exe       'F$VERIFY(0)'
$ !            located in the default decnet account
$ GOTO 'F$MODE()'
$ !
$INTERACTIVE:
$BATCH:
$OTHER:
$ ThisNode = F$TRNLNM("sys$node") - "::"
$ IF P1 .EQS. "" THEN WHO
$Loop:
$ IF P1 .EQS. "" THEN GOTO Done
$ Node = F$ELEMENT(0,",",P1)
$ P1 = P1 - Node - ","
$ Node = Node - "::"
$ IF Node .NES. ThisNode THEN GOTO L1
$ WHO  
$ GOTO Loop
$L1:
$ TYPE 'Node'"smsk$network"::"task=who"
$ GOTO Loop
$ !
$NETWORK:
$ WHO /OUTPUT=sys$net
$ GOTO DONE
$ !
$Done:
$ EXIT
