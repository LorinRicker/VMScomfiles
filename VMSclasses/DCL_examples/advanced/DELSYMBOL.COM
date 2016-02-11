$ ! DELSYMBOL.COM  -- deletes global/local DCL symbols             'F$VERIFY(0)'
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
$ !   use: @DELSYMBOL symbol[,...]
$ !
$ !  Note: This procedure deletes /GLOBAL symbols only.  Symbols which are
$ !        declared as /LOCALs (eg. "$ x = 1") at the outermost level (at
$ !        the DCL $-prompt, which is level-0) cannot be deleted by a command
$ !        procedure, since the com-proc sees its own local symbols as being
$ !        at level-1 (and higher), and therefore cannot delete the level-0
$ !        symbols at all.  This is merely a DCL-shell limitation.
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ DS$K   == 0
$ k       = 0
$ Fac     = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ Verbose = F$TRNLNM("TOOLS$DEBUG")
$ DELETE  = "DELETE"
$ wso     = "WRITE sys$output"
$ !
$ i = 0
$Loop:
$ Symbol = F$ELEMENT(i,",",P1)
$ IF Symbol .EQS. "," THEN GOTO Done
$ SymL = F$LENGTH(Symbol)
$ IF ( F$LOCATE("*",Symbol) .LT. SymL ) -
  .OR. ( F$LOCATE("%",Symbol) .LT. SymL )
$ THEN CALL WildCard "''Symbol'"
$ ELSE IF F$TYPE('Symbol') .NES. ""
$      THEN IF Verbose THEN wso F$FAO("%!AS-I-DELETING, global symbol [1m!AS[0m",Fac,Symbol)
$           DELETE /SYMBOL /GLOBAL 'Symbol'
$           DS$K == 1
$      ELSE IF Verbose THEN wso F$FAO("%!AS-W-SNF, global symbol !AS not found",Fac,Symbol)
$      ENDIF
$ ENDIF
$ i = i + 1
$ k = k + DS$K
$ GOTO Loop
$ !
$ IF Verbose THEN wso F$FAO("%!AS-S-STATS, deleted !SL global symbol!%S",Fac,k)
$ !
$Done:
$ IF F$TYPE(DS$K) .NES. "" THEN DELETE /SYMBOL /GLOBAL DS$K
$ EXIT 1
$ !
$ !
$WildCard:  SUBROUTINE
$ ! P1: Symbol string (containing "*" and/or "%" wildcards)
$ ON ERROR THEN GOTO WC2
$ DS$K == 0
$ SymF  = "sys$scratch:delsym.lis"
$ CALL /OUTPUT='SymF' ShowSymbols "''P1'"
$ OPEN /READ F 'SymF'
$WC0:
$ READ/END_OF_FILE=WC1 F Rec
$ Sym = F$ELEMENT(0,"=",F$EDIT(Rec,"COLLAPSE")) - "*" !strip abbreviation-point
$ IF F$TYPE('Sym') .NES. ""
$ THEN IF Verbose
$      THEN wso F$FAO("%!AS-I-DELETING, global symbol [1m!AS[0m",Fac,Sym)
$      ENDIF
$      DELETE /SYMBOL /GLOBAL 'Sym'
$      DS$K == DS$K + 1
$ ELSE IF Verbose THEN wso F$FAO("%!AS-W-SNF, global symbol !AS not found",Fac,Sym)
$ ENDIF
$ GOTO WC0
$WC2:
$ wso F$FAO("%!AS-E-LASTREAD, record `!AS' from file !AS",Fac,Rec,SymF)
$WC1:
$ SET NOON
$ IF F$TRNLNM("F") .NES. "" THEN CLOSE F
$ IF F$SEARCH(SymF) .NES. "" THEN DELETE 'SymF';0
$ EXIT 1
$ ENDSUBROUTINE  ! WildCard
$ !
$ShowSymbols:  SUBROUTINE
$ ON CONTROL_Y THEN EXIT %X2C
$ ON WARNING THEN EXIT (%X2C .OR. %X10000000)
$ SHOW SYMBOL /GLOBAL 'P1'
$ ENDSUBROUTINE  ! ShowSymbols
$ !
$Ctrl_Y:
$ RETURN %X2C
