$ ! FIRST.COM -- Our first class example                                  'F$VERIFY(0)'
$ !
$ ! use:  @FIRST
$ !
$ cls = "TYPE /PAGE=CLEAR_SCREEN NLA0:"
$ wso = "WRITE SYS$OUTPUT"
$ !
$ cls
$ show user
$ !
$ wso ""
$ SHOW SYSTEM /NOPROCESS /FULL
$ !
$ wso ""
$ !
$ EXIT 1
