$ ! COMPARE_LOGINS.COM --                                          'F$VERIFY(0)'
$ !
$ ! Copyright © 2015-2016 by Lorin Ricker.  All rights reserved, with acceptance,
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
$CreateDiff: SUBROUTINE
$ ! P1 = generation#
$ ! P2 = output file name-prefix
$ !
$ PgWidth = F$INTEGER(F$GETDVI("TT","DEVBUFSIZ"))
$ comp = "DIFFERENCE /PARALLEL /WIDTH=''PgWidth'"
$ !
$ i = F$INTEGER(P1)
$ j = F$INTEGER(P1+1)
$ outf = "''P2'_''i'.TXT"
$ IF ( F$SEARCH(outf) .NES. "" ) THEN DELETE /NOLOG 'outf';*
$ comp /OUTPUT='outf'  -
    'DD''lgi'_'i'.COM  -
    'DD''lgi'_'j'.COM
$ !
$ EXIT 1
$ ENDSUBROUTINE  ! CreateDiff
$ !
$DisplayDiff: SUBROUTINE
$ ! P1 = generation#
$ !
$ wso ""
$ READ sys$command answer /PROMPT="Press <Enter> to display first comparison: "
$ TYPE /PAGE 'outfile'_'P1'.TXT'
$ EXIT 1
$ ENDSUBROUTINE  ! DisplayDiff
$ !
$ !
$Main:
$ ON ERROR THEN GOTO Cleanup
$ ON CONTROL_Y THEN GOTO Cleanup
$ !
$ wso   = "WRITE sys$output"
$ PDir  = F$ENVIRONMENT("DEFAULT")
$ Proc  = F$ENVIRONMENT("PROCEDURE")
$ Fac   = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ DD    = F$PARSE(Proc,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(Proc,,,"DIRECTORY","SYNTAX_ONLY")
$ !
$ lgi  = "LOGIN_EXAMPLE"
$ outfile = "''DD'''Fac'"
$ !
$ SET DEFAULT 'DD'
$ SHOW DEFAULT
$ !
$ CALL CreateDiff 0 "''outfile'" ! DIFF login_example0.com login_example1.com
$ CALL CreateDiff 1 "''outfile'" ! DIFF login_example1.com login_example2.com
$ CALL CreateDiff 2 "''outfile'" ! DIFF login_example2.com login_example3.com
$ !
$ wso "%''Fac'-I-DIFFS_CREATED, comparison files have been created..."
$ !
$ CALL DisplayDiff 0
$ CALL DisplayDiff 1
$ CALL DisplayDiff 2
$ !
$Cleanup:
$ SET DEFAULT 'PDir'
$ SHOW DEFAULT
$ !
$ EXIT    ! 'F$VERIFY(0)'
$ !
