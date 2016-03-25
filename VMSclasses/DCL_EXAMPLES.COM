$ ! DCL_EXAMPLES.COM					               'F$VERIFY(0)'
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
$ ! Display the equivalence strings for the four process-permanent logical names;
$ ! this can be executed interactively or from a batch job:
$ !
$ ! use:  $ @DCL_EXAMPLES [UNZIP]    ! unzips the archive into the current directory
$ !
$ !  or:  $ @DCL_EXAMPLES ZIP        ! zips up the current directory tree into a
$ !                                  ! new archive DCL_EXAMPLES.ZIP
$ !
$ ! First, define ZIP and/or UNZIP foreign command symbols if either does not exist:
$ IF ( F$TYPE( zip ) .NES. "STRING" ) .OR. ( F$TYPE( unzip ) .NES. "STRING" )
$ THEN
$L0:
$      zp = F$SEARCH("sys$system:*zip*.exe")
$      IF zp .EQS. "" THEN GOTO L0Done
$      zp  = zp - F$PARSE(zp,,,"VERSION","SYNTAX_ONLY")
$      zpn = F$PARSE(zp,,,"NAME","SYNTAX_ONLY")
$      ! Define a global symbol:
$      'zpn' == "$''zp'"
$      GOTO L0
$L0Done:
$ ENDIF
$ !
$ archive = "[]DCL_EXAMPLES.ZIP"
$ flist   = "[.*...]README*.TXT [.*...]*.COM"
$ !
$ IF ( P1 .EQS. "" ) THEN P1 = "UNZIP"
$ GOTO 'P1'
$ !
$ZIP:
$ IF ( F$SEARCH(archive) .NES. "" ) THEN DELETE /LOG 'archive';*
$ zip 'archive' 'flist'
$ GOTO Done
$ !
$LIST:
$ unzip -l 'archive'
$ GOTO Done
$ !
$UNZIP:
$ unzip -l 'archive'
$ READ SYS$COMMAND answer /END_OF_FILE=Done /PROMPT="Unzip this archive ''archive' [y/N]? "
$ answer = F$PARSE( answer, "NO", , , "SYNTAX_ONLY" )
$ IF answer THEN unzip 'archive'
$ GOTO Done
$ !
$Done:
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
