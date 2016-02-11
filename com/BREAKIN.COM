$ ! BREAKIN.COM -- show breakins, check the audit journal          'F$VERIFY(0)'
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
$ !  use: @BREAKIN [operation]
$ !
$ !  operation:  INTRUSION -- SHOW INTRUSION
$ !              RESET or
$ !              DELETE    -- DELETE /INTRUSION "..."
$ !              SHOW or
$ !              AUDIT     -- SHOW AUDIT LOG
$ !              NEW       -- Create new audit server journal file
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ prv = F$SETPRV("SYSPRV,SECURITY,CMKRNL")
$ Ver = F$TRNLNM("TOOLS$DEBUG")
$ wso = "WRITE sys$output"
$ NO_INTRUSION = %X107880BC  !%SHOW-F-NOINTRUDERS, no intrusion records match specification
$ !
$ IF P1 .EQS. "?" THEN GOTO Help
$ CALL Parse "''P1'" Parse$Cmd "INTRUSION" "INTRUSION|DELETE   |RESET    |AUDIT    |SHOW     |NEW      |HELP     "
$ GOTO 'Parse$Cmd'
$ !
$Reset:
$Delete:
$Intrusion:
$ SET NOON
$ wso ""
$ SHOW INTRUSION /TYPE=(ALL)
$ Stat = $STATUS
$ wso ""
$ !
$ ON ERROR THEN GOTO Done
$ IF (Parse$Cmd .EQS. "INTRUSION") .OR. (Stat .EQ. NO_INTRUSION) THEN GOTO Done
$ !
$ wso "Delete breakin record"
$ READ sys$command Victim /END_OF_FILE=Done /PROMPT="  for intruder source: "
$ DELETE /INTRUSION "''Victim'"
$ wso ""
$ GOTO Done
$ !
$New:
$ READ sys$command Answer /END_OF_FILE=Done -
    /PROMPT="Confirm creation of new Audit Server Journal file (Y/n): "
$ Answer = F$PARSE(Answer,"Yes",,"NAME","SYNTAX_ONLY")
$ IF Answer
$ THEN SET AUDIT /SERVER=NEW_LOG
$      IF $STATUS THEN wso "%BREAKIN-S-CREAUDJOU, new Audit Server Journal file created"
$      wso ""
$ ENDIF
$ DIRECTORY /SECURITY /SIZE sys$manager:security*.audit*
$ GOTO Done
$ !
$Show:
$Audit:
$ READ sys$command P1 /PROMPT="Show audit log since <yesterday>? " /END_OF_FILE=Done
$ P1 = F$PARSE(P1,"YESTERDAY",,"NAME","SYNTAX_ONLY")
$ READ sys$command P2 /PROMPT="Full or Brief <B>: " /END_OF_FILE=Done
$ P2 = F$PARSE(P2,"Brief",,"NAME","SYNTAX_ONLY")
$ IF F$EXTRACT(0,1,P2) .EQS. "B"
$ THEN P2 = "/BRIEF"
$ ELSE P2 = "/FULL /INTERACTIVE"
$ ENDIF
$ SET AUDIT /SERVER=FLUSH                  !force RMS/audit buffers to file
$ V  = F$EXTRACT(0,2,F$GETSYI("VERSION"))
$ GOTO 'V'
$ !
$V5:
$ AJou = "sys$manager:security_audit.audit$journal"
$ GOTO Audit
$V7:
$V6:
$ AJou = "sys$manager:security.audit$journal"
$Audit:
$ DEFINE /USER_MODE sys$input sys$command
$ ANALYZE /AUDIT /SINCE='P1' 'P2' 'AJou'
$ WRITE sys$output ""
$ GOTO Done
$ !
$Done:
$ prv = F$SETPRV(prv)
$ EXIT
$ !
$ !
$Parse: SUBROUTINE
$ ! P1: command to parse
$ ! P2: global symbol to receive answer
$ ! P3: default command
$ ! P4: command set ("C1|C2[|Cn...]") -- options must be same-length fields
$ ! P5: command separator
$ IF P1 .EQS. "" THEN P1 = P3
$ IF P2 .EQS. "" THEN P2 = "Parse$Cmd"
$ IF P5 .EQS. "" THEN P5 = "|"
$ P4 = F$EDIT(P4,"UPCASE")
$ S  = F$LOCATE(P5,P4) + 1               !Determine field length
$ P4 = P5 + P4                           !Add separator to front of list...
$ T  = P5 + F$EDIT(P1,"COLLAPSE,UPCASE") !...and to target
$ L  = F$LOCATE( F$EDIT(T,"COLLAPSE,UPCASE"), P4 )      !Test substring
$ IF ( L .LT. F$LENGTH(P4) ) .AND. ( L-(L/S)*S .EQ. 0 ) !Found?
$ THEN L = ( ( L + 1 ) / S ) + 1                        !Calculate offset
$      'P2' == F$EDIT( F$ELEMENT(L,P5,P4), "COLLAPSE" )
$      EXIT 1
$ ELSE 'P2' == "$Err$"
$      WRITE sys$output "\''P1'\ (expecting: ''F$EDIT(P4,"COLLAPSE")')"
$      EXIT 229522  !%DCL-E-IVVERB, unrecognized command verb
$ ENDIF
$ ENDSUBROUTINE
$ !
$FileParse:  SUBROUTINE
$ ! P1:     filespec to parse
$ ! P2:     global symbol to receive answer
$ ! P3..P7: field(s) to return
$ IF P2 .EQS. "" THEN P2 = "FParse$File"
$ Nd = F$PARSE(P1,,, "NODE",      "SYNTAX_ONLY")
$ Dv = F$PARSE(P1,,, "DEVICE",    "SYNTAX_ONLY")
$ Dr = F$PARSE(P1,,, "DIRECTORY", "SYNTAX_ONLY")
$ Na = F$PARSE(P1,,, "NAME",      "SYNTAX_ONLY")
$ Ty = F$PARSE(P1,,, "TYPE",      "SYNTAX_ONLY")
$ Vr = F$PARSE(P1,,, "VERSION",   "SYNTAX_ONLY")
$ P3 = F$EDIT(P3,"COLLAPSE,UPCASE")
$ IF ( P3 .EQS. "" ) .OR. ( P3 .EQS. "ALL" ) .OR. ( P3 .EQS. "FULL" )
$ THEN FP = Nd + Dv + Dr + Na + Ty + Vr
$ ELSE F  = "," + P3 + "," + P4 + "," + P5 + "," + P6 + "," + P7 + "," + P8
$      F  = F$EDIT(F,"COLLAPSE,UPCASE")
$      FL = F$LENGTH(F)
$      FP = ""
$      IF ( F$LOCATE(",NOD",F) .LT. FL ) THEN FP = FP + Nd
$      IF ( F$LOCATE(",DEV",F) .LT. FL ) THEN FP = FP + Dv
$      IF ( F$LOCATE(",DIR",F) .LT. FL ) THEN FP = FP + Dr
$      IF ( F$LOCATE(",NAM",F) .LT. FL ) THEN FP = FP + Na
$      IF ( F$LOCATE(",TYP",F) .LT. FL ) THEN FP = FP + Ty
$      IF ( F$LOCATE(",VER",F) .LT. FL ) THEN FP = FP + Vr
$ ENDIF
$ 'P2' == FP
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE sys$input /PAGE

  usage: [1m@BREAKIN [operation][0m

  where:

    [1moperation[0m is one of the following command arguments, which may be
      abbreviated to any minimally unique spelling:

        INTRUSION -- Performs a DCL [1mSHOW INTRUSION[0m command to show any
        (default)    suspect or actual break-in attempts in progress.
                     VMS will be taking break-in evasion actions for any
                     user or login device listed in this display.

        RESET or
        DELETE    -- Permits you to perform a [1mDELETE /INTRUSION "..."[0m
                     to reset (clear) any device or username which is
                     currently in break-in evasion status.  You will
                     be prompted for the intrusion record (username or
                     device name) to reset.

        SHOW or
        AUDIT     -- Performs a DCL [1mANALYZE /AUDIT[0m command to show recent
                     audit journal (log) entries.  You will be prompted
                     for the /SINCE date; default is /SINCE=YESTERDAY.

        NEW       -- Performs a DCL [1mSET AUDIT /SERVER=NEW_LOG[0m to create
                     a new audit server journal file, and displays a
                     directory listing of the new and old(er) files.

$ GOTO Done
$ !
