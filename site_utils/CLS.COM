$ ! CLS.COM -- Clear screen for VTX00 terminals                    'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1990-2002 by Evans & Ricker, Inc.  All rights reserved.
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
