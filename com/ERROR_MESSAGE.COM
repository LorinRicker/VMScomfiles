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
$TestCondCode:  SUBROUTINE
$ ! P1 : Condition Code (string)
$ ! P2 : Message file to search
$ ! P3 : Verbose flag
$ !
$ ON CONTROL_Y THEN GOSUB TCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ SET MESSAGE 'P2'
$ IF $STATUS
$ THEN IF P3 THEN wso "Checking ", P2
$ ELSE wso "%''Fac'-E-SETMSGFAIL, SET MESSAGE failed for ", P2
$      wso " (''P2' may not be a message-file)"
$      GOTO Loop
$ ENDIF
$ Msg = F$MESSAGE( 'P1' )
$ IF ( F$LOCATE( "NOMSG", Msg ) .LT. F$LENGTH( Msg ) )
$ THEN EM_Found == "FALSE"
$ ELSE EM_Found == "TRUE"
$ ENDIF
$ IF EM_Found
$ THEN Msg = "  « [1m" + Msg + "[0m  »"
$      wso "%''Fac'-S-FOUNDMSG, found error code ""''P1'"""
$      wso "    in Message File ", P2, ":"
$      wso /SYMBOL Msg
$      wso ""
$ ENDIF
$ EXIT 1
$ !
$TCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! TestCondCode
$ !
$ ! -- Main --
$ ON CONTROL_Y THEN GOTO Done
$ wso = "WRITE sys$output"
$ !
$ proc = F$ENVIRONMENT( "PROCEDURE" )
$ Fac  = F$PARSE( proc, , , "NAME", "SYNTAX_ONLY" )
$ !
$ P3 = F$EDIT( P3, "COLLAPSE,UPCASE" ) - "-" - "/"
$ P3 = F$EXTRACT(0,1,P3)
$ Verbose = ( P3 .EQS. "L" ) .OR. ( P3 .EQS. "V" ) .OR. F$TRNLNM( "TOOLS$Debug" )
$ !
$ IF P1 .EQS. "" -
  THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="Error code (%X if Hex): "
$ FT = F$EXTRACT( 0, 1, P2 )
$ IF ( FT .EQS. "-" ) .OR. ( FT .EQS. "/" )  !"/Qualifier" as P2?
$ THEN FT = P2                               !  ...Swap P2 & P3
$      P2 = P3
$      P3 = FT
$ ENDIF
$ !
$ IF ( P2 .EQS. "" )
$ THEN P2 = "SYS$MESSAGE:*.EXE"
$      SearchP2 = "TRUE"
$ ELSE SearchP2 = "FALSE"
$ ENDIF
$ P2 = F$PARSE( P2, "SYS$MESSAGE:.EXE" )
$ !
$ ! First check the "background" VMS environment before looking in files:
$ Msg = F$MESSAGE( 'P1' )
$ IF F$LOCATE( "NOMSG", MSG ) .LT. F$LENGTH( Msg ) THEN GOTO Search
$ Msg = "  « [1m" + Msg + "[0m  »"
$ wso "%''Fac'-S-FOUNDMSG, VMS error code ""''P1'"" is:"
$ wso /SYMBOL Msg
$ wso ""
$ EXIT 1  !...because we found it  'F$VERIFY(0)'
$ !
$Search:
$ Found = "FALSE"
$ IF .NOT. Verbose THEN wso "Searching ''P2'..."
$ !
$ ON CONTROL_Y THEN EXIT %X2C  ! 'F$VERIFY(0)'
$ ON ERROR THEN CONTINUE
$ !
$Loop:
$ File = F$SEARCH( P2, 0 )
$ !
$ IF ( File .EQS. "" ) THEN GOTO LoopEnd
$ ! Skip SYS$MESSAGE:TECOMSG.EXE as it's not a compliant message file:
$ IF ( F$PARSE( File, , , "NAME" ) .EQS. "TECOMSG" ) THEN GOTO Loop
$ !
$ CALL TestCondCode "''P1'" "''File'" "''Verbose'"
$ !
$ IF SearchP2 .AND. ( .NOT. EM_Found )
$ THEN GOTO Loop     ! more to search?...
$ ELSE GOTO LoopEnd  ! given one file to search...
$ ENDIF
$ !
$LoopEnd:
$ SET MESSAGE /DELETE        ! don't leave user in last set message-file
$ IF EM_Found THEN GOTO Done
$ !
$ IF Verbose
$ THEN wso ""
$      wso "No such error code ""''P1"" found."
$      wso "  Last library searched returned:"
$      wso /SYMBOL Msg
$ ELSE wso "No matching error code found in ''P2' files"
$ ENDIF
$ !
$Done:
$ IF ( F$TYPE( EM_Found ) .NES. "" ) THEN DELETE /SYMBOL /GLOBAL EM_Found
$ EXIT 1  ! 'F$VERIFY(0)'
$ !
