$ ! WHAT_EDIT.COM --                                               'F$VERIFY(0)'
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
$ !    use: @WHAT_EDIT username
$ !
$ SET NOON
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$L0:
$ IF P1 .EQS. ""
$ THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="user: "
$      IF P1 .EQS. "" THEN GOTO L0
$ ENDIF
$ User = F$TRNLNM(P1)
$ IF User .NES. "" THEN P1 = User
$ !
$ i = 0
$L1:
$ D = F$TRNLNM("disks$mounted","lnm$system",i)
$ IF D .NES. ""
$ THEN D = D - ":" + ":"
$      IF F$SEARCH("''D'[000000]''P1'.DIR") .NES. ""
$      THEN Dev = D
$           GOTO L2
$      ELSE i = i + 1
$           GOTO L1
$      ENDIF
$ ELSE WRITE sys$output "%WHAT_EDIT-E-NO_USER_DIR, user directory [''P1'] not found (disks$mounted)"
$      EXIT 1
$ ENDIF
$ !
$L2:
$ TPUJou1 = Dev + "[" + P1 + ".scratch]*.tjl"
$ TPUJou2 = Dev + "[" + P1 + ".scratch]*.tpu$journal"
$ IF ( F$SEARCH(TPUJou1) .NES. "" ) .OR. ( F$SEARCH(TPUJou2) .NES. "" )
$ THEN DIRECTORY /WIDTH=(FILENAME=48,SIZE=3) /SIZE /DATE 'TPUJou1','TPUJou2'
$ ELSE WRITE sys$output "%WHAT_EDIT-I-NOTEDITING, ''P1' is not editing anything"
$ ENDIF
$ !
$Done:
$ EXIT 1
$ !
$Ctrl_Y:
$ RETURN %X2C
