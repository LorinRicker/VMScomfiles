$ ! ADDVALUES.COM -- adds some numbers
$ !
$ total = 0
$ IF ( P1 .NES. "" ) THEN total = total + P1
$ IF ( P2 .NES. "" ) THEN total = total + P2
$ IF ( P3 .NES. "" ) THEN total = total + P3
$ IF ( P4 .NES. "" ) THEN total = total + P4
$ IF ( P5 .NES. "" ) THEN total = total + P5
$ IF ( P6 .NES. "" ) THEN total = total + P6
$ IF ( P7 .NES. "" ) THEN total = total + P7
$ IF ( P8 .NES. "" ) THEN total = total + P8
$ WRITE SYS$OUTPUT "Grand total = ",total
$ EXIT
