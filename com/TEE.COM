$ ! TEE.COM -- split input on SYS$PIPE to SYS$OUTPUT               'F$VERIFY(0)'
$ !            and another output (file)
$ !
$ !  usage: @TEE log-file
$ !
$ SET NOON
$ OPEN /WRITE /ERROR=oops teefile 'P1'
$loop:
$ READ /END_OF_FILE=done sys$pipe line
$ write sys$output line
$ write teefile    line
$ GOTO loop
$done:
$ CLOSE /NOLOG teefile
$ EXIT %X01
$oops:
$ WRITE sys$error "%TEE-E-OPENERR, cannot open ''P1'"
$ EXIT %X2C
