$ ! TESTLEN.COM --                 'F$VERIFY(0)'
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ wso = "WRITE sys$output"
$ !
$ OPEN /READ /ERROR=Oops tf TEST.TXT
$ !
$L0:
$ READ /END_OF_FILE=Done tf data
$ wso F$FAO( ">>> Length of data record: !SL", F$LENGTH(data) )
$ wso ">>> data: " + F$EXTRACT(0,50,data) + " ..."
$ GOTO L0
$ !
$Done:
$ IF F$TRNLNM("tf") .NES. "" THEN CLOSE tf
$ EXIT
$ !
$Oops:
$ wso "%TESTLEN-E-OPENERR, error opening TEST.TXT"
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
