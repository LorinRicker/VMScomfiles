$ ! COLT_SPECIFIC$LOGIN.COM --                                     'F$VERIFY(0)'
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
$CDefine:  SUBROUTINE
$ IF F$LOCATE("*",P1) .LT. F$LENGTH(P1)
$ THEN AbbrSym = F$ELEMENT(0,"*",P1)
$ ELSE AbbrSym = P1
$ ENDIF
$ FullSym = P1 - "*"
$ IF F$TYPE('AbbrSym') .EQS. "STRING"  !command symbol already exists?
$ THEN IF Redefine
$      THEN DELETE /SYMBOL /GLOBAL 'AbbrSym'
$           GOTO CDef1
$      ELSE IF Verbose THEN wso "%SYMBOLS-W-NOREDEFINE, command symbol ""''P1'"" already exists"
$           EXIT 1
$      ENDIF
$ ENDIF
$CDef1:
$ P2 = F$EDIT(P2,"UPCASE")
$ IF F$EXTRACT(0,1,P2) .EQS. "$" THEN P2 = P2 - "$" - ".EXE" + ".EXE"
$ IF F$EXTRACT(0,1,P2) .EQS. "@" THEN P2 = P2 - "@" - ".COM" + ".COM"
$ IF F$SEARCH(P2) .NES. ""
$ THEN IF F$PARSE(P2,,,"TYPE","SYNTAX_ONLY") .EQS. ".EXE"
$      THEN 'P1' == "$''P2'"
$      ELSE 'P1' == "@''P2'"
$      ENDIF
$      IF Verbose THEN SHOW SYMBOL /GLOBAL 'FullSym'
$ ELSE IF LMR$Unavailable .EQS. ""
$      THEN LMR$Unavailable == FullSym
$      ELSE LMR$Unavailable == LMR$Unavailable + ", " + FullSym
$      ENDIF
$      IF Verbose THEN SHOW SYMBOL /LOCAL P1
$      IF Verbose THEN SHOW SYMBOL /LOCAL P2
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! CDefine
$ !
$ !
$MAIN:
$ SET NOON
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ Redefine = ( F$EXTRACT(0,2,P1) .EQS. "RE" )  !REDEFINE, REFRESH, RE-whatever
$ Proc = F$ENVIRONMENT("PROCEDURE")
$ FS   = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY") + F$PARSE(Proc,,,"TYPE","SYNTAX_ONLY")
$ !
$ PURGE /KEEP=3 sys$login:*.log  !DECW$SM.LOG, etc.
$ !
$Done:
$ EXIT
