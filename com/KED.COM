$ ! KED.COM -- editor command file                                 'F$VERIFY(0)'
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
$ !  use:  @KED [ filename | com_symbol ] [ outfile ]
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ DEFINE = "DEFINE /NOLOG /USER_MODE"
$ wso    = "WRITE sys$output"
$ sym    = ""
$ out    = ""
$ Arch   = F$EDIT(F$GETSYI("ARCH_NAME"),"UPCASE,TRIM")
$ !
$ IF P2 .NES. ""
$ THEN P2 = F$PARSE(P2,P1)
$      out = "/OUTPUT=" + P2
$      wso "%KED-I,  output ''P2'"
$ ENDIF
$ !
$L0:
$ IF P1 .NES. "" THEN cf == P1
$ IF cf .NES. "" THEN GOTO L1
$ READ /END_OF_FILE=Done /PROMPT="   file: " sys$command P1
$ GOTO L0
$ !
$L1:
$ IF P1 .NES. ""
$ THEN IF F$PARSE(P1,,,"TYPE","SYNTAX_ONLY") .EQS. "."  !Looks like DCL symbol?
$      THEN sym = F$PARSE(P1,,,"NAME","SYNTAX_ONLY")
$           IF F$TYPE(&sym) .NES. "" THEN sym = &sym
$      ENDIF
$ ENDIF
$ !
$ ! Don't have Pascal/toolset to build full TTK/KED with CALL_USER callbacks,
$ ! so have to resort to a "pure-TPU" (slightly compromised) section file:
$ IF Arch .EQS. "IA64" THEN KED = "EDIT /TPU /SECTION=tpu$src:tpk.tpu$section"
$ !
$ pre = F$EXTRACT(0,1,sym)
$ IF (pre .NES. "@") .AND. (pre .NES. "$") THEN GOTO L2
$ sym = sym - pre  !edit a symbol-comfile reference
$ IF pre .EQS. "$"
$ THEN sym = F$PARSE(sym,"sys$disk:[].exe;")
$      wso "%KED-E, cannot edit an executable file: ''P1' = $''sym'"
$      GOSUB Ctrl_Y
$ ELSE sym = F$PARSE(sym,"com:.com;")
$      cf == sym - F$PARSE(sym,,,"VERSION","SYNTAX_ONLY")
$      wso "%KED-I, symbol ''P1' = @''cf'"
$ ENDIF
$ !
$L2:
$ IF P1 .EQS. "" THEN wso "%KED-I, editing ''cf'"
$ ! aliased/shared templates:
$ ext = F$PARSE(cf,,,"TYPE","SYNTAX_ONLY")
$ IF ext .EQS. ".LATEX" THEN DEFINE ked$template ked$utils:ked$TEX.template
$ IF ext .EQS. ".MAK"   THEN DEFINE ked$template ked$utils:ked$COM.template
$ SET NOON
$ DEFINE sys$input sys$command
$ KED 'out' 'cf'
$ !
$ IF P2 .NES. "" THEN cf == P2
$ c == F$PARSE(cf,,,"NAME","SYNTAX_ONLY")
$ !
$Done:
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
