$ ! SCRWIDTH.COM -- set screen width or page length                'F$VERIFY(0)'
$ !
$ ! Copyright © 1999-2016 by Lorin Ricker.  All rights reserved, with acceptance,
$ ! use, modification and/or distribution permissions as granted and controlled
$ ! by and under the GPL described herein.
$ !
$ ! This program (software) is Free Software, licensed under the terms and
$ ! conditions of the GNU General Public License Version 3 as published by
$ ! the Free Software Foundation: http://www.gnu.org/copyleft/gpl.txt,
$ ! which is hereby incorporated into this software and is a non-severable
$ ! part thereof.  You have specific rights and obligations under this GPL
$ ! which are binding if and when you accept, use, modify and/or distribute
$ ! this software program (source code file) and/or derivatives thereof.
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
