$ ! SCRWIDTH.COM -- set screen width or page length                'F$VERIFY(0)'
$ !
$ SET NOON
$ IF F$EXTRACT(0,1,P1) .EQS. "P"  !"Pnn"?
$ THEN Qual = "/PAGE=" + F$EXTRACT(1,F$LENGTH(P1)-1,P1)
$ ELSE Qual = "132"
$      IF ( P1 .EQS. "" )
$      THEN IF ( F$GETDVI("sys$command","DEVBUFSIZ") .GT. 80 ) THEN Qual = "80"
$      ELSE IF F$INTEGER(P1) .LE. 80 THEN Qual = "80"
$      ENDIF
$      Qual = "/WIDTH=" + Qual
$ ENDIF
$ DEFINE /USER_MODE sys$output sys$command
$ SET TERMINAL 'Qual'
$ IF F$EXTRACT(1,2,F$TRNLNM("sys$command")) .EQS. "FT"  !DECW$ term only
$ THEN esc[0,32]= %X1B
$      R[0,1]:= 'esc'
$      R[1,2]:= "c"
$      WRITE sys$output R
$ ENDIF
$ EXIT
