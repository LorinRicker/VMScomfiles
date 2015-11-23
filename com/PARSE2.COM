$ ! PARSE2.COM -- a simple command-word parser for DCL com-files   'F$VERIFY(0)'
$ !
$ ! P1 : command word
$ !
$ @com:utility START parse
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ ! Examples to test:
$ @com:utility CmdParse "''P1'" Com "NAME" "NODE|DEV |DIR |NAME|TYPE|VERS|FULL"
$ WRITE sys$output "Command word: ""''Parse$Com'"""
$ !
$ !@com:utility FileParse sys$login:login.com Spec FULL !or ALL or "" (null)
$ !@com:utility FileParse sys$login:login.com Spec NODE DEV DIR NAME TYPE VER
$ @com:utility FileParse sys$login:login.com;* Spec 'Parse$Com'
$ WRITE sys$output "File parsed: ""''Parse$Spec'"""
$ GOTO Done
$ !
$ ! Some more sample calls:
$ !
$ @com:utility CmdParse "''P1'" Com "OPT1" "OPT1|OPT2|OPT3"
$ Boolean = ( Parse$Com .EQS. "OPT1" )
$ !
$ @com:utility CmdParse "''P1'" Com "A1" "A1      |B2B     |C3CC    |D4DDD   "
$ GOTO 'Parse$Com'
$ !
$Done:
$ @com:utility EXIT
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
