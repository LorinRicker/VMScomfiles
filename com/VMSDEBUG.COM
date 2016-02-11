$ ! VMSDEBUG.COM --                                                'F$VERIFY(0)'
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
