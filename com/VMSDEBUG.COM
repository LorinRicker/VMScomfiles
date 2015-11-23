$ ! VMSDEBUG.COM --                                                'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1998-1999 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ! use: @VMSDEBUG [ Node_number ] [ Yes | No (Default) ]
$ !
$ SET NOON
$ DDomain = "10.0.0."  ! MAGNUM, using DHCP
$ DNode   = "193"
$ !
$ IF P1 .EQS. ""
$ THEN READ sys$command Domain /END_OF_FILE=Done /PROMPT="Domain <''DDomain'>: "
$      READ sys$command Node   /END_OF_FILE=Done /PROMPT="Node <''DNode'>: "
$      IF Domain .EQS. "" THEN Domain = DDomain
$      IF Node   .EQS. "" THEN Node   = DNode
$ ELSE Node = P1
$      Domain = DDomain
$ ENDIF
$ !
$ DEFINE /JOB /NOLOG dbg$decw$display "''Domain'''Node':0.0"
$ IF P1 .NES. "" THEN SHOW LOGICAL /JOB dbg$decw$display
$ !
$ Answer = F$PARSE(P2,"No",,"NAME","SYNTAX_ONLY")
$ IF Answer
$ THEN VDebug == "$sys$share:debugshr"
$      DEFINE /USER_MODE sys$input sys$command
$      VDebug
$      SHOW /SYMBOL /GLOBAL VDebug
$ ENDIF
$ !
$Done:
$ EXIT
