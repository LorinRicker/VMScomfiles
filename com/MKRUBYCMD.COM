$ ! MKRUBYCMD.COM                                                  'F$VERIFY(0)'
$ !
$ ! Copyright © 2016 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ! P1 : name of global command symbol to define
$ ! P2 : filespec of Ruby script to invoke by global command symbol
$ ! P3 : if truthy, then show the global command symbol
$ !
$ ON ERROR THEN GOTO Done
$ !
$ Proc = F$ENVIRONMENT("PROCEDURE")
$ Fac  = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ !
$ wserr = "WRITE sys$error"
$ !
$ IF ( F$SEARCH( P2 ) .NES. "" )
$ THEN IF ( F$TYPE(ruby) .EQS. "STRING" )
$      THEN 'P1' == "''ruby' 'P2'"
$      ELSE wserr "%''Fac'-E-NO_RUBY, Ruby is not installed or set-up on this system"
$      ENDIF
$ ELSE wserr "%''Fac'-E-FNF, cannot find Ruby script ""''P2'"""
$      GOTO Done
$ ENDIF
$ !
$ IF P3 THEN IF ( F$TYPE('P2') .EQS. "STRING" ) THEN SHOW SYMBOL /GLOBAL 'P2'
$ !
$Done:
$ EXIT 1  ! 'F$VERIFY(0)'
