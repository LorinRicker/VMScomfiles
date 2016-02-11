$ ! FOPEN_READ.COM
$ !
$ ON WARNING THEN PIPE WRITE SYS$ERROR "Oops, I screwed up" ; EXIT %X2C
$ on control_y then goto L1
$ !
$ OPEN /READ /ERROR=Oops f 'P1'
$ !
$ i = 0
$L0:
$ READ /END_OF_FILE=L1 f line
$ i = i + 1
$ WRITE SYS$OUTPUT "line ''i': ''line'"
$ GOTO L0
$ !
$L1:
$ CLOSE f
$ EXIT 1
$ !
$Oops:
$ WRITE SYS$ERROR "%FOPEN_READ-E-FNF, could not open file"
$ EXIT %X2C
