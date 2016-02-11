$ ! FINITE.COM
$ !
$ if ( p1 .eqs. "" ) then read sys$command p1 /PROMPT="Enter limit: "
$ count = 0
$Loop:
$ if ( count .gt. F$INTEGER(p1) ) then goto Done
$ WRITE SYS$OUTPUT "Loop count = ''count'"
$ count = count + 1
$ GOTO LOOP
$ !
$Done:
$ EXIT
