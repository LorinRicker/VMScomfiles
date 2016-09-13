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
$ wserr    = "WRITE sys$error"
$ SLASH    = "/"
$ DOT      = "."
$ COLON    = ":"
$ LBRACKET = "["
$ RBRACKET = "]"
$ !
$ IF ( F$SEARCH( P2 ) .NES. "" )
$ THEN IF ( F$TYPE(ruby) .EQS. "STRING" )
$      THEN ! Convert LNAME:prog.rb and/or DEV:[DIR.SUB]prog.rb into *nix-PATH style
$           ! /DEV/DIR/SUB/prog.rb, translating LNAME logical as needed:
$           Rdev = F$PARSE(P2,,,"DEVICE","SYNTAX_ONLY") - COLON
$           Rdir = F$PARSE(P2,,,"DIRECTORY","SYNTAX_ONLY") - LBRACKET - RBRACKET - LBRACKET - RBRACKET
$           i = 0
$           Rpath = ""
$L0:
$           elem = F$ELEMENT(i,DOT,Rdir)
$           IF ( elem .EQS. DOT ) THEN GOTO L0cont
$           IF ( elem .NES. ""  ) THEN Rpath = Rpath + SLASH + elem
$           i = i + 1
$           GOTO L0
$L0cont:
$           Rscriptname = F$PARSE(P2,,,"NAME","SYNTAX_ONLY")
$           Rscripttype = F$PARSE(P2,,,"TYPE","SYNTAX_ONLY")
$           Rscript = SLASH + Rdev + Rpath + SLASH + Rscriptname + Rscripttype
$           ! Define a global command symbol for this Ruby script:
$           'P1' == "''ruby' ''Rscript'"
$      ELSE wserr "%''Fac'-E-NO_RUBY, Ruby is not installed or set-up on this system"
$      ENDIF
$ ELSE wserr "%''Fac'-E-FNF, cannot find Ruby script ""''P2'"""
$      GOTO Done
$ ENDIF
$ !
$ P1 = P1 - "*"
$ IF "''P3'" THEN IF ( F$TYPE('P1') .EQS. "STRING" ) THEN SHOW SYMBOL /GLOBAL 'P1'
$ !
$Done:
$ EXIT 1  ! 'F$VERIFY(0)'
