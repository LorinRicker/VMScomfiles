$ ! ERROR_CODE.COM --                                              'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1994-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  use: @ERROR_CODE [%X]nnn [message_filespec] [LOG|LIST|VERBOSE]
$ !
$ !   P1: error/status code, in decimal or hex
$ !   P2: alternate message file to search
$ !   P3: verbose flag
$ !
$ ON CONTROL_Y THEN GOTO Done
$ IF P1 .EQS. "" -
  THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="Error code (%X if Hex): "
$ FT = F$EXTRACT(0,1,P2)
$ IF ( FT .EQS. "-" ) .OR. ( FT .EQS. "/" )  !"/Qualifier" as P2?
$ THEN FT = P2                               !  ...Swap P2 & P3
$      P2 = P3
$      P3 = FT
$ ENDIF
$ IF P2 .EQS. "" THEN P2 = "SYS$MESSAGE:*.EXE"
$ FT = F$PARSE(P2,,,"TYPE","SYNTAX_ONLY")
$ IF FT .EQS. "." THEN P2 = P2 + ".EXE"
$ P3 = F$EDIT(P3,"COLLAPSE,UPCASE") - "-" - "/"
$ P3 = F$EXTRACT(0,1,P3)
$ Verbose = ( P3 .EQS. "L" ) .OR. ( P3 .EQS. "V" ) .OR. F$TRNLNM("TOOLS$Debug")
$ !
$ ! First check the "background" VMS environment before looking in files:
$ A = F$MESSAGE('P1')
$ IF F$LOCATE("NOMSG",A) .LT. F$LENGTH(A) THEN GOTO Search
$ A = "  « " + A + "  »"
$ WRITE sys$output "VMS error code ""''P1'"" is"
$ WRITE /SYMBOL sys$output A
$ WRITE sys$output ""
$ SET MESSAGE /DELETE      !don't leave user in last set message-file
$ EXIT  !...because we found it
$ !
$Search:
$ Found = "FALSE"
$ IF .NOT. Verbose THEN WRITE sys$output "Searching ''P2'..."
$ !
$Loop:
$ ON CONTROL_Y THEN EXIT
$ ON ERROR THEN CONTINUE
$ ON SEVERE_ERROR THEN CONTINUE
$ File = F$SEARCH(P2,0)
$ IF File .EQS. "" THEN GOTO LoopEnd
$ SET MESSAGE 'File'
$ IF $STATUS
$ THEN IF Verbose THEN WRITE sys$output "Checking ",File
$ ELSE WRITE sys$output "SET MESSAGE failed for ",File
$      WRITE sys$output " (may not be a message-file)"
$      GOTO Loop
$ ENDIF
$ A = F$MESSAGE('P1')
$ IF F$LOCATE("NOMSG",A) .LT. F$LENGTH(A) THEN GOTO Loop
$ Found = "TRUE"
$ A = "  « " + A + "  »"
$ WRITE sys$output "Found error code ""''P1'"" in file ",File
$ WRITE /SYMBOL sys$output A
$ WRITE sys$output ""
$ GOTO Loop
$ !
$LoopEnd:
$ SET MESSAGE /DELETE      !don't leave user in last set message-file
$ IF Found THEN EXIT
$ IF Verbose
$ THEN WRITE sys$output ""
$      WRITE sys$output "No such error code ""''P1"" found."
$      WRITE sys$output "  Last library searched returned:"
$      WRITE sys$output ""
$      WRITE /SYMBOL sys$output A
$ ELSE WRITE sys$output "No such error code found in ''P2' files"
$ ENDIF
$ !
$Done:
$ EXIT
