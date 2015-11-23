$ ! SETTIME.COM -- sets/shows system time
$ !
$ ver = 'F$VERIFY(0)'
$ IF p1 .EQS. "" -
  THEN  GOTO done
$ IF p2 .NES. "" -
  THEN  p1 = p1 + ":" + p2  !glue "dd-mmm-yyyy" to "hh:mm:ss.ff" with ":"
$ prv = F$SETPRV("LOG_IO")
$ SET TIME='p1'
$ prv = F$SETPRV(prv)
$done:
$ SHOW DAYTIME
$ EXIT %X10000001 + ( 0 * 'F$VERIFY(ver)' )
$ !
