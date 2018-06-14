$ ! ERROR_MESSAGE.COM --                                           'F$VERIFY(0)'
$ !
$ ! Copyright © 1994-2018 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ! Copyright © 2002 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1994-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  use: @ERROR_MESSAGE [%X]nnn [message_filespec] [LOG|LIST|VERBOSE]
$ !
$ !   P1: error/status code, in decimal or hex
$ !   P2: alternate message file to search
$ !   P3: verbose flag
$ !
$ ON CONTROL_Y THEN GOTO Done
$ wso = "WRITE sys$output"
$ !
$ IF P1 .EQS. "" -
  THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="Error code (%X if Hex): "
$ FT = F$EXTRACT( 0, 1, P2 )
$ IF ( FT .EQS. "-" ) .OR. ( FT .EQS. "/" )  !"/Qualifier" as P2?
$ THEN FT = P2                               !  ...Swap P2 & P3
$      P2 = P3
$      P3 = FT
$ ENDIF
$ IF P2 .EQS. "" THEN P2 = "SYS$MESSAGE:*.EXE"
$ FT = F$PARSE( P2, , , "TYPE", "SYNTAX_ONLY" )
$ IF FT .EQS. "." THEN P2 = P2 + ".EXE"
$ P3 = F$EDIT( P3, "COLLAPSE,UPCASE" ) - "-" - "/"
$ P3 = F$EXTRACT(0,1,P3)
$ Verbose = ( P3 .EQS. "L" ) .OR. ( P3 .EQS. "V" ) .OR. F$TRNLNM( "TOOLS$Debug" )
$ !
$ ! First check the "background" VMS environment before looking in files:
$ A = F$MESSAGE( 'P1' )
$ IF F$LOCATE( "NOMSG",A ) .LT. F$LENGTH( A ) THEN GOTO Search
$ A = "  « " + A + "  »"
$ wso "VMS error code ""''P1'"" is"
$ wso /SYMBOL A
$ wso ""
$ SET MESSAGE /DELETE      !don't leave user in last set message-file
$ EXIT 1  !...because we found it  'F$VERIFY(0)'
$ !
$Search:
$ Found = "FALSE"
$ IF .NOT. Verbose THEN wso "Searching ''P2'..."
$ !
$Loop:
$ ON CONTROL_Y THEN EXIT %X2C  ! 'F$VERIFY(0)'
$ ON ERROR THEN CONTINUE
$ !
$ File = F$SEARCH( P2, 0 )
$ IF File .EQS. "" THEN GOTO LoopEnd
$ SET MESSAGE 'File'
$ IF $STATUS
$ THEN IF Verbose THEN wso "Checking ",File
$ ELSE wso "SET MESSAGE failed for ",File
$      wso " (may not be a message-file)"
$      GOTO Loop
$ ENDIF
$ A = F$MESSAGE( 'P1' )
$ IF F$LOCATE( "NOMSG", A ) .LT. F$LENGTH( A ) THEN GOTO Loop
$ Found = "TRUE"
$ A = "  « " + A + "  »"
$ wso "Found error code ""''P1'"" in file ",File
$ wso /SYMBOL A
$ wso ""
$ GOTO Loop
$ !
$LoopEnd:
$ SET MESSAGE /DELETE      !don't leave user in last set message-file
$ IF Found THEN EXIT 1  ! 'F$VERIFY(0)'
$ !
$ IF Verbose
$ THEN wso ""
$      wso "No such error code ""''P1"" found."
$      wso "  Last library searched returned:"
$      wso ""
$      wso /SYMBOL A
$ ELSE wso "No such error code found in ''P2' files"
$ ENDIF
$ !
$Done:
$ EXIT 1  ! 'F$VERIFY(0)'
$ !
