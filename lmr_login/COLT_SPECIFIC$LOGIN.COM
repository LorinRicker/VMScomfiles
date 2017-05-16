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
$MAIN:
$ SET NOON
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ !
$ ! ----------------------------------------------------------------------
$ ReLogin = ( F$EXTRACT( 0, 2, P1 ) .EQS. "RE" )  !REDEFINE, REFRESH, RE-whatever
$ ! By convention/intent, DCL$SUBROUTINE_LIBRARY is here:
$ IF ( F$TYPE( DCL$CALL ) .EQS. "" ) .OR. ( ReLogin )
$ THEN @lmr$login:DCL$SUBROUTINE_LIBRARY Setup FALSE
$ ENDIF
$ ! ----------------------------------------------------------------------
$ !
$ Proc = F$ENVIRONMENT("PROCEDURE")
$ FS   = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY") + F$PARSE(Proc,,,"TYPE","SYNTAX_ONLY")
$ !
$ PURGE /KEEP=3 sys$login:*.log  !DECW$SM.LOG, etc.
$ !
$Done:
$ EXIT
