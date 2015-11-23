$ ! WHAT_EDIT.COM --                                               'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1998-2001 by Evans & Ricker, Inc.  All rights reserved.
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
