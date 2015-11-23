$ ! ZIPS.COM --                                                    !'F$VERIFY(0)'
$ !
$ ! Conditionally build DCL symbols for any *ZIP*.EXE utilities found in SYS$SYSTEM
$ !
$L0:
$ zp = F$SEARCH("sys$system:*zip*.exe")
$ IF zp .EQS. "" THEN GOTO Done
$ zp  = zp - F$PARSE(zp,,,"VERSION","SYNTAX_ONLY")
$ zpn = F$PARSE(zp,,,"NAME","SYNTAX_ONLY")
$ ! Define a global symbol:
$ 'zpn' == "$''zp'"
$ GOTO L0
$ !
$Done:
$ EXIT  !'F$VERIFY(0)'
