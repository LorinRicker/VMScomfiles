$ ! PARSE.COM -- a simple command-word parser for DCL com-files    'F$VERIFY(0)'
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
$ ! P1 : command word
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ ! Examples to test:
$ CALL Parse "''P1'" Parse$Cmd "NAME" "NODE|DEV |DIR |NAME|TYPE|VERS|FULL"
$ WRITE sys$output "Command word: ""''Parse$Cmd'"""
$ !
$ !CALL FileParse sys$login:login.com FParse$Spec FULL !or ALL or "" (null)
$ !CALL FileParse sys$login:login.com FParse$Spec NODE DEV DIR NAME TYPE VER
$ CALL FileParse sys$login:login.com;* FParse$Spec 'Parse$Cmd'
$ WRITE sys$output "File parsed: ""''FParse$Spec'"""
$ GOTO Done
$ !
$ ! Some more sample calls:
$ !
$ CALL Parse "''P1'" Parse$Cmd "OPT1" "OPT1|OPT2|OPT3"
$ Boolean = ( Parse$Cmd .EQS. "OPT1" )
$ !
$ CALL Parse "''P1'" Parse$Cmd "A1" "A1      |B2B     |C3CC    |D4DDD   "
$ GOTO 'Parse$Cmd'
$ !
$Done:
$ IF F$TYPE(Parse$Cmd) .NES. "" THEN DELETE /SYMBOL /GLOBAL Parse$Cmd
$ IF F$TYPE(FParse$Spec) .NES. "" THEN DELETE /SYMBOL /GLOBAL FParse$Spec
$ EXIT
$ !
$ !
$Parse: SUBROUTINE
$ ! P1: command to parse
$ ! P2: global symbol to receive answer
$ ! P3: default command
$ ! P4: command set ("C1|C2[|Cn...]") -- options must be same-length fields
$ ! P5: command separator
$ IF P1 .EQS. "" THEN P1 = P3
$ IF P2 .EQS. "" THEN P2 = "Parse$Cmd"
$ IF P5 .EQS. "" THEN P5 = "|"
$ P4 = F$EDIT(P4,"UPCASE")
$ S  = F$LOCATE(P5,P4) + 1               !Determine field length
$ P4 = P5 + P4                           !Add separator to front of list...
$ T  = P5 + F$EDIT(P1,"COLLAPSE,UPCASE") !...and to target
$ L  = F$LOCATE( F$EDIT(T,"COLLAPSE,UPCASE"), P4 )      !Test substring
$ IF ( L .LT. F$LENGTH(P4) ) .AND. ( L-(L/S)*S .EQ. 0 ) !Found?
$ THEN L = ( ( L + 1 ) / S ) + 1                        !Calculate offset
$      'P2' == F$EDIT( F$ELEMENT(L,P5,P4), "COLLAPSE" )
$      EXIT 1
$ ELSE 'P2' == "$Err$"
$      WRITE sys$output "\''P1'\ (expecting: ''F$EDIT(P4,"COLLAPSE")')"
$      EXIT 229522  !%DCL-E-IVVERB, unrecognized command verb
$ ENDIF
$ ENDSUBROUTINE
$ !
$FileParse:  SUBROUTINE
$ ! P1:     filespec to parse
$ ! P2:     global symbol to receive answer
$ ! P3..P7: field(s) to return
$ IF P2 .EQS. "" THEN P2 = "FParse$File"
$ Nd = F$PARSE(P1,,, "NODE",      "SYNTAX_ONLY")
$ Dv = F$PARSE(P1,,, "DEVICE",    "SYNTAX_ONLY")
$ Dr = F$PARSE(P1,,, "DIRECTORY", "SYNTAX_ONLY")
$ Na = F$PARSE(P1,,, "NAME",      "SYNTAX_ONLY")
$ Ty = F$PARSE(P1,,, "TYPE",      "SYNTAX_ONLY")
$ Vr = F$PARSE(P1,,, "VERSION",   "SYNTAX_ONLY")
$ P3 = F$EDIT(P3,"COLLAPSE,UPCASE")
$ IF ( P3 .EQS. "" ) .OR. ( P3 .EQS. "ALL" ) .OR. ( P3 .EQS. "FULL" )
$ THEN FP = Nd + Dv + Dr + Na + Ty + Vr
$ ELSE F  = "," + P3 + "," + P4 + "," + P5 + "," + P6 + "," + P7 + "," + P8
$      F  = F$EDIT(F,"COLLAPSE,UPCASE")
$      FL = F$LENGTH(F)
$      FP = ""
$      IF ( F$LOCATE(",NOD",F) .LT. FL ) THEN FP = FP + Nd
$      IF ( F$LOCATE(",DEV",F) .LT. FL ) THEN FP = FP + Dv
$      IF ( F$LOCATE(",DIR",F) .LT. FL ) THEN FP = FP + Dr
$      IF ( F$LOCATE(",NAM",F) .LT. FL ) THEN FP = FP + Na
$      IF ( F$LOCATE(",TYP",F) .LT. FL ) THEN FP = FP + Ty
$      IF ( F$LOCATE(",VER",F) .LT. FL ) THEN FP = FP + Vr
$ ENDIF
$ 'P2' == FP
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Ctrl_Y:
$ RETURN %X2C
