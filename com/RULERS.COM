$ ! RULERS.COM                                                     'F$VERIFY(0)'
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
$ PgSize  = F$INTEGER(F$GETDVI("TT","TT_PAGE")) - 3
$ PgWidth = F$INTEGER(F$GETDVI("TT","DEVBUFSIZ")) - 4
$ vcount = 0
$VLoop:
$ vcount = vcount + 1
$ tick = F$FAO( "!2UL", vcount )
$ digit = F$EXTRACT(1,1,tick)
$ IF ( digit .EQS. "5" ) THEN tick = tick + " -"
$ IF ( digit .EQS. "0" ) THEN tick = tick + " --"
$ WRITE sys$output tick
$ IF ( vcount .LT. PgSize ) THEN GOTO VLoop
$ !
$ vcount = vcount + 1
$ hcount = 0
$ hdigit = 5
$ hruler = ""
$ htickr = "    "
$ digit  = F$STRING( F$LENGTH(htickr) + 1 )
$HLoop:
$ hruler = hruler + digit
$ IF ( hdigit .GE. 10 ) THEN hdigit = 0
$ IF ( digit .EQS. "0" )
$ THEN htickr = htickr + "|"
$ ELSE htickr = htickr + " "
$ ENDIF
$ hdigit = hdigit + 1
$ digit = F$EXTRACT(1,1,F$FAO( "!2UL", hdigit ))
$ hcount = hcount + 1
$ IF ( hcount .LT. PgWidth ) THEN GOTO HLoop
$ !
$ hruler = F$FAO( "!2UL -!AS", vcount, hruler )
$ WRITE sys$output hruler
$ WRITE sys$output htickr
$ EXIT
