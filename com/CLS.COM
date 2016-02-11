$ ! CLS.COM -- Clear screen for VTX00 terminals                    'F$VERIFY(0)'
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
$ !  use:  @site$utils:CLS [ DARK | LIGHT (default) ]
$ !
$ !  Old VTxxx terminal standard ANSI-escape code for "light" means
$ !  "black characters on white background", and "dark" means "white
$ !  characters on black background".  However, most/all contemporary
$ !  PC terminal emulator products have implemented this "in reverse";
$ !  now we've got to test TT-type, and if it's a device likely to be
$ !  a PC/TermEmulator session, the ANSI escape codes are re-reversed
$ !  dark-to-light to make the original parameter symantics come out
$ !  correctly.
$ !
$ IF F$GETDVI("TT","TT_ANSICRT") THEN GOTO CRT
$ WRITE sys$output F$FAO("!2(/)!8*-!3(/)")     !hard-copy: simulate a page-break
$ EXIT ($STATUS .OR. %X10000000)
$ !
$CRT:
$ esc[0,32]=27
$ Val = P1
$ IF Val .EQS. "" THEN Val = F$TRNLNM("smsk$cls")
$ IF Val .EQS. "" THEN Val = "LIGHT"
$ !
$ !Re-reverse "dark/light" misinterpretation by PC terminal emulators:
$ TType  = F$GETDVI("TT","TT_PHYDEVNAM") - "_"
$ TType  = F$EXTRACT(0,3,TType)
$ EmType = ",TNA,FTA,"
$ TermEm = ( F$LOCATE(",''TType',",EmType) .LT. F$LENGTH(EmType) )
$ IF TermEm
$ THEN IF Val .EQS. "LIGHT"
$      THEN Val = "DARK"
$      ELSE Val = "LIGHT"
$      ENDIF
$ ENDIF
$ GOTO 'Val'
$ !
$DARK:
$ clr = esc + "[m" + esc + "[H" + esc + "[J" + esc + "[?5l"     !dark
$ WRITE sys$output clr
$ EXIT ($STATUS .OR. %X10000000)
$LIGHT:
$ clr = esc + "[m" + esc + "[H" + esc + "[J" + esc + "[?5h"     !light
$ WRITE sys$output clr
$ EXIT ($STATUS .OR. %X10000000)
