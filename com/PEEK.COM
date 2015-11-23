$ ! PEEK.COM -- peek at a VMS variable location (by system address)
$ IF P1 .EQS. "" -
  THEN  READ /END_OF_FILE=Done /PROMPT="Address (hex): " sys$command P1
$ P1 = F$EDIT(P1,"UPCASE,COLLAPSE")
$ IF F$EXTRACT(0,2,P1) .NES. "%X" THEN P1 = "%X" + P1
$ val = F$CVSI(0,16,F$FAO("!AD",4,'P1'))
$ WRITE sys$output F$FAO("%PEEK-I, Value at address (!AS): !ZW",P1,val)
$Done:
$ EXIT
