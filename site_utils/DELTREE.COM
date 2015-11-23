$ ! DELTREE.COM - delete a complete directory tree                 'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1990-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  usage:  $ @deltree [.DIRNAME] [-LHCDE]
$ !
$ !  p1 = name of root of tree to delete
$ !  p2 = Log directory deletions as they occur
$ !       Help on usage
$ !       Confirm directory deletions
$ !       Draw the tree only (don't delete)
$ !       Erase disk-storage on delete (/ERASE)
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ IF F$LOCATE("-",P1) .NE. 0 THEN GOTO Q0
$ T1 = P1
$ P1 = P2
$ P2 = T1
$Q0:
$ DT$C = "F"                    ! Confirm
$ DT$D = "F"                    ! Draw only
$ DT$E = "F"                    ! Erase
$ DT$H = "F"                    ! Help
$ DT$L = "F"                    ! Log
$ IF F$LOCATE("-",P2) .NE. 0 THEN GOTO Q2
$ L = F$LENGTH(P2)
$ Q = 0
$Q1:
$ Q = Q + 1
$ IF Q .GE. L THEN GOTO Q2
$ DT$'F$EXTRACT(Q,1,P2)' = "T"
$ GOTO Q1
$ !
$Q2:
$ Default = F$ENVIRONMENT("DEFAULT")
$ IF DT$H THEN GOTO Help
$ DELETE = "DELETE"
$ Prompt = "delete"
$ IF DT$D THEN Prompt = "draw"
$ IF DT$D THEN DT$L = "T"       !Draw implies Log
$ DT$Erase = "/NOERASE"
$ IF DT$E THEN DT$Erase = "/ERASE"
$ ON WARNING THEN GOTO Done
$ !
$L0:
$ IF P1 .NES. "" THEN GOTO L1
$ READ /END_OF_FILE=Done /PROMPT="Directory to ''Prompt' <''Default'>: " -
    SYS$COMMAND Target
$ IF Target .EQS. "" THEN Target = Default
$ P1 = Target
$ !
$L1:
$ Dir = F$PARSE(P1,"sys$disk:[]")
$ IF F$PARSE(Dir,,,"NAME","SYNTAX_ONLY") .NES. "" THEN GOTO Help
$ IF Dir .EQS. "" THEN GOTO NoDir
$ Dir = F$PARSE(P1,"sys$disk:[]",,"DIRECTORY","SYNTAX_ONLY")
$ IF Dir .EQS. "[000000]" THEN GOTO Mfd
$ Dir = F$PARSE(P1,"sys$disk:[]",,"DEVICE","SYNTAX_ONLY") + Dir
$ SET DEFAULT 'Dir'
$ IF .NOT. DT$C THEN GOTO Q4
$ READ /END=Done /PROMPT="Really ''Prompt' directory ''Dir' [YNRQ]<N>? "  -
        sys$command DT$Confirm
$ DT$Confirm = F$EDIT(F$EXTRACT(0,1,DT$Confirm),"UPCASE")
$ IF DT$Confirm .NES. "R" THEN GOTO C1
$ P2 = P2 - "C"
$ DT$Confirm = "Y"
$C1:
$ IF DT$Confirm .NES. "Q" THEN GOTO C2
$ UTILQUIT = %X0803897A
$ CALL Signal 'UTILQUIT'
$C2:
$ IF .NOT. DT$Confirm THEN GOTO Done
$Q4:
$ IF .NOT. DT$L THEN GOTO L2
$ Depth = 2 * F$ENVIRONMENT("DEPTH")
$ Erase = ""
$ IF DT$E .AND. ( Depth .LE. 2 ) THEN Erase = "  (erasing all files...)"
$ IF DT$E .AND. DT$L THEN DT$Erase = DT$Erase + "/LOG"
$ WRITE sys$output F$FAO("!''Depth'* !AS!AS", Dir, Erase)
$ !
$L2:
$ File = F$SEARCH("SMSK$DO_NOT_DELETE_THIS_DIRECTORY.")
$ IF File .NES. "" THEN GOTO Dnd
$ File = F$SEARCH("*.DIR;1",1)
$ IF File .EQS. "" THEN GOTO L3
$ @'F$ENVIRONMENT("PROCEDURE")' -       !Invoke DELTREE for subdirectory
        [.'F$PARSE(File,,,"NAME","SYNTAX_ONLY")'] "''P2'"
$ GOTO L2
$ !
$L3:
$ IF DT$D THEN GOTO Done
$ !Delete all files in (sub)directory:
$ File = "*.*;*"
$ IF F$SEARCH("*.*;*") .NES. "" THEN DELETE 'File' 'DT$Erase'
$ !
$ !Delete (sub)directory itself; first determine its filename:
$ File = ( F$DIRECTORY() - "]" - ">" )                               -
       - ( F$PARSE("[-]",,,"DIRECTORY","SYNTAX_ONLY" ) - "]" - ">" ) -
       - "." - "["
$ File = "[-]" + File + ".DIR;0"
$ IF F$PARSE(File,,,"DIRECTORY","SYNTAX_ONLY") -
   + F$PARSE(File,,,"NAME","SYNTAX_ONLY")      -
   + F$PARSE(File,,,"TYPE","SYNTAX_ONLY") .EQS. "[000000]000000.DIR" -
  THEN  GOTO Mfd        !don't harm the MFD
$ SET FILE /PROTECTION=(SYSTEM:RWED,OWNER:RWED) 'File'
$ DELETE 'File' 'DT$Erase'
$ GOTO Done
$ !
$Help:
$ DEFINE /USER_MODE sys$input sys$command
$ HELP DELTREE
$ !
$Done:
$ Status = $STATUS
$ SET DEFAULT 'Default'
$ DEFDIR = %X08038323
$ IF F$ENVIRONMENT("DEPTH") .EQ. 1      -
  THEN  IF F$TYPE(DT$L) .NES. ""        -
        THEN  IF DT$L                   -
              THEN  IF .NOT. DT$D       -
                    THEN  WRITE sys$error F$FAO(F$MESSAGE(DEFDIR),Default)
$ EXIT (Status .OR. %X10000000)
$ !
$Mfd:
$ File = [000000]
$Dnd:
$ DELMFD = %X0803898A
$ CALL Signal 'DELMFD' 'File'
$ !
$NoDir:
$ DIRNOTFND = %X08038992
$ CALL Signal 'DIRNOTFND' 'P1'
$ !
$Ctrl_Y:
$ RETURN %X0000002C
$ !
$Signal:        SUBROUTINE
$ DT$msg = F$MESSAGE(P1)
$ IF F$LOCATE("NOMSG",DT$msg) .LT. F$LENGTH(DT$msg)     -
  THEN SET MESSAGE site$utils:util_messages
$ WRITE sys$error F$FAO(F$MESSAGE(P1),P2,P3,P4,P5,P6,P7,P8)
$ EXIT (%X10000000 .OR. 'P1')
$ ENDSUBROUTINE
