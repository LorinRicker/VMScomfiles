$ ! DELSYMBOL.COM  -- deletes global/local DCL symbols             'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1989-2001 by Evans & Ricker, Inc.  All rights reserved.
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
