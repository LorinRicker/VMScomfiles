$ ! SYMSUB.COM -- demonstrate symbol substitution                        'F$VERIFY(0)'
$ !
$ Symb = "XYZ"
$ !
$ WRITE SYS$OUTPUT "The value of Symb is: ""''Symb'"""
$ !
$ EXIT 1
