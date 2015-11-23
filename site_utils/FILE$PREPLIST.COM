$ ! FILE$PREPLIST.COM -- Prepare a list of files for processing    'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1996-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ! use: @FILE$PrepList ListName Files[,...] [Qualifiers] [Exclusions] [GloSym]
$ !
$ !      /CONFIRM can be added anywhere on command line
$ !         after P1 to force prompt-dialog
$ !
$ !  P1: Name for indirect @-list (container file)
$ !  P2: Files to process (comma-separated list)
$ !  P3: Directory qualifier(s)
$ !  P4: Exclusion files (comma-separated list)
$ !  P5: Global-symbol-name to return name of list-file
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ MaxI  = 6   !number of parameters in use (plus one)
$ P0    = ""  !(dummy parameter)
$ XFile = ""
$ Files = ""
$ Quals = ""
$ Exclu = ""
$ !
$ ! /C[onfirm] appears anywhere in command?
$ I = MaxI
$L0:
$ Confirm = ( F$EXTRACT(0,2,P'I') .EQS. "/C" )
$ IF Confirm
$ THEN CONTINUE
$L1:   IF I .GT. MaxI THEN GOTO Prompts
$      J = I + 1
$      P'I' = P'J'
$      I = I + 1
$      GOTO L1
$ ELSE IF I .LT. 1 THEN GOTO Prompts
$      I = I - 1
$      GOTO L0
$ ENDIF
$ !
$Prompts:
$ IF P1 .EQS. "" THEN P1 = "sys$scratch:file$list.lis"
$ IF Confirm -
  THEN READ sys$command XFile /END_OF_FILE=Done /PROMPT="Indirect @-list <''P1'>: "
$ XFile = F$PARSE(XFile,P1,"sys$disk:[]file$list.lis",,"SYNTAX_ONLY")
$ XFile = XFile - F$PARSE(XFile,,,"VERSION","SYNTAX_ONLY")
$ !
$Prompt2:
$ IF P2 .EQS. "" THEN P2 = "*.*;0"
$ IF Confirm -
  THEN READ sys$command Files /END_OF_FILE=Done /PROMPT="Files to process <''P2'>: "
$ Files = F$EDIT(Files,"COLLAPSE,UPCASE")
$ IF F$EXTRACT(0,1,Files) .EQS. "+"       !user adds to default file-list?
$ THEN Files = Files - "+"
$      IF P2 .NES. "" THEN Files = P2 + "," + Files
$ ELSE IF Files .EQS. "" THEN Files = P2  !user just accepts default-list
$ ENDIF
$ !
$Prompt3:
$ IF Confirm -
  THEN READ sys$command Quals /END_OF_FILE=Prompt4 /PROMPT="Qualifiers <''P3'>: "
$ IF Quals .EQS. "" THEN Quals = P3
$ !
$Prompt4:
$ IF Confirm -
  THEN READ sys$command FL /END_OF_FILE=D0 /PROMPT="Exclude <''P4'>: "
$ FL = F$EDIT(FL,"COLLAPSE,UPCASE")
$ IF ( FL .EQS. "" ) .AND. ( P4 .EQS. "" ) THEN GOTO D0
$ IF F$EXTRACT(0,1,FL) .EQS. "+"        !user adds to default exclusion-list?
$ THEN FL = FL - "+"
$      IF P4 .NES. ""
$      THEN Exclu = "/EXCLUDE=(" + P4 + "," + FL + ")"
$      ELSE Exclu = "/EXCLUDE=(" + FL + ")"
$      ENDIF
$ ELSE IF FL .EQS. ""
$      THEN Exclu = "/EXCLUDE=(" + P4 + ")"
$      ELSE Exclu = "/EXCLUDE=(" + FL + ")"
$      ENDIF
$ ENDIF
$ !
$D0:
$ SET NOON  ! forgive "-RMS-E-DNF, directory not found", etc.
$ DIRECTORY /OUT='XFile' /NOHEAD /NOTRAIL /COLUMN=1 'Files' 'Quals' 'Exclu'
$ IF $STATUS .AND. ( P5 .NES. "" ) THEN 'P5' == XFile
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ READ sys$command answer /END_OF_FILE=Done /PROMPT="Edit ''XFile' <Y>: "
$ answer = F$PARSE(answer,"Y",,"NAME","SYNTAX_ONLY")
$ IF answer
$ THEN DEFINE /USER_MODE sys$input sys$command
$      KED /NOSYMBOLS 'XFile'
$      PURGE /NOLOG 'XFile'
$ ENDIF
$ !
$Done:
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
