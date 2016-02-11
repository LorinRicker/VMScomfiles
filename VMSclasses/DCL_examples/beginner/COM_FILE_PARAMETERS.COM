$ ! PARAMS.COM -- demonstrate parameters to com-procedure                  'F$VERIFY(0)'
$ !
$ WRITE SYS$OUTPUT "The value of P1 is: ""''p1'"""
$ WRITE SYS$OUTPUT "The value of P2 is: ""''p2'"""
$ WRITE SYS$OUTPUT "The value of P3 is: ""''p3'"""
$ !
$ EXIT 1
