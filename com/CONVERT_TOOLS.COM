$ ! CONVERT_TOOLS.COM -- assistance with file CONVERT              'F$VERIFY(0)'
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
$ !  use: @CONVERT_TOOLS {Convert|Edit|Fdl} DataFile [FdlFile] [PAD([%b]NN)]
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR     THEN GOTO Done
$ IF P1 .EQS. ""
$ THEN WRITE sys$error "%CONVERT_TOOLS-I, use: @CONVERT_TOOLS {Convert|Edit|Fdl} DataFile [FdlFile] [PAD([%b]NN)]"
$      EXIT
$ ENDIF
$ P1 = P1 - "-"
$ IF P2 .NES. "" THEN GOTO L1
$L0:
$ READ /END_OF_FILE=Done /PROMPT="Data file: " sys$command P2
$ IF P2 .EQS. "" THEN GOTO L0
$L1:
$ Data = F$PARSE(P2,".dat") - ";"
$ DD   = F$PARSE(P2,"sys$disk",,"DEVICE") + F$PARSE(P2,"[]",,"DIRECTORY")
$ Name = F$PARSE(P2,,,"NAME")
$ IF P3 .NES. ""
$ THEN Fdl = F$PARSE(P3,"sys$disk:[].fdl",Name,,"SYNTAX_ONLY")
$ ELSE Fdl = F$PARSE(Name,"sys$disk:[].fdl",,,"SYNTAX_ONLY")
$ ENDIF
$ Fdl = F$ELEMENT(0,";",Fdl)  !remove ;version
$ pad = F$EDIT(P4,"COLLAPSE,UPCASE") - "PAD(" - ")"
$ GOTO 'F$EXTRACT(0,1,P1)'$
$ !
$C$:   !Convert
$ answer = "Yes"
$ GOTO C1
$E$:   !Edit
$ DEFINE /USER_MODE sys$input sys$command
$ KED /NOSYMBOL 'Data'
$ GOTO C0
$F$:   !Fdl-analysis
$ ANALYZE /RMS /FDL /OUT='Fdl' 'Data'
$ DEFINE /USER_MODE sys$input sys$command
$ KED /NOSYMBOL 'Fdl'
$ !!!PURGE 'Fdl'
$C0:
$ READ /END_OF_FILE=Done /PROMPT="Convert ''Data' <Y>? " sys$command answer
$ answer = F$PARSE(answer,"Yes",,"NAME","SYNTAX_ONLY")
$C1:
$ IF (pad .NES. "") .AND. (F$EXTRACT(0,1,P4) .NES. "%") -
  THEN  pad = "/PAD=%D" + pad
$ IF answer THEN CONVERT /FDL='Fdl' 'pad' 'Data' 'Data'
$ !
$Done:
$ EXIT $STATUS
$Ctrl_Y:
$ RETURN %X0000002C
