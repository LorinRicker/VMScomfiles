$ ! ASKFILES.COM
$ !
$ ! Copyright © 2014-2016 by Lorin Ricker.  All rights reserved, with acceptance,
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
$AskFile: SUBROUTINE
$ ! P1 = type of file we want
$ ! P2 = extension for file we want
$ !
$ READ sys$command FN /PROMPT="Filename for ''P1' (''P2'): "
$ FileSpec == FN
$ ENDSUBROUTINE  ! AskFile
$ !
$ProcessFile: SUBROUTINE
$ ! P1 = filename to process
$ ext = F$PARSE(P1,,,"TYPE","SYNTAX_ONLY")
$ WRITE sys$output "filename ''P1' of type ''ext' was passed as parameter-1..."
$ IF ext .EQS. ".DAT"
$ THEN WRITE sys$output "...we'll process a data (''ext') file here"
$ ELSE WRITE sys$output "...we'll process a text (''ext' or other) file here"
$ ENDIF
$ ENDSUBROUTINE  ! ProcessFile
$ !
$ ! Mainline routine:
$ ON CONTROL_Y THEN GOTO Cleanup
$ !
$ CALL AskFile "data" ".DAT"
$ CALL ProcessFile "''FileSpec'"
$ !
$ CALL AskFile "text" ".TXT"
$ CALL ProcessFile "''FileSpec'"
$ !
$Cleanup:
$ IF F$TYPE(FileSpec) .NES. "" THEN DELETE /SYMBOL /GLOBAL FileSpec
$ !
$ EXIT
