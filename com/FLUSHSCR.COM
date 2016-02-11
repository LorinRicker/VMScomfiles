$ ! FLUSHSCR.COM --                                                'F$VERIFY(0)'
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
$ !  flushes all files in SYS$SCRATCH, with a safety valve
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ TPU$Files = "*.tpu$*;*,*.tjl;*"
$ !
$ IF P1 .EQS. "" THEN P1 = "sys$scratch"
$ P1 = P1 - ":"
$ !
$ DEFINE /USER_MODE lib$dt_format lib$date_format_008,lib$time_format_005
$ DIRECTORY 'P1' /WIDTH=(FILENAME=28,SIZE=5,OWNER=10) -
    /EXCLUDE=('TPU$Files') /SIZE /OWNER /PROTECTION /DATE
$ IF F$LOCATE("%RMS-W-FNF",F$MESSAGE($STATUS)) .EQ. 0 THEN EXIT
$ !
$ P0 = "Flush ''P1' (" + F$TRNLNM(P1) + ") <y/[1mN[0m>?  "
$ READ /END_OF_FILE=Done /PROMPT="''P0'" sys$command Answer
$ !
$ IF F$PARSE(Answer,"No",,"NAME","SYNTAX_ONLY") -
  THEN DELETE /NOCONFIRM 'P1':*.*;* /EXCLUDE=('TPU$Files')
$ !
$Done:
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
