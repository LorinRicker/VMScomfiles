$ ! RQ_SCRIPT.COM                                                  'F$VERIFY(0)'
$ !
$ !     This program is the confidential and proprietary product of
$ !     Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !     transfer of this program is strictly prohibited.
$ !
$ !     Copyright © 1995-1996 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ @site$utils:utility START RQS 'F$ENVIRONMENT("PROCEDURE")'
$ Script_File = ""
$L0:
$ IF P1 .EQS. ""
$    THEN @SITE$UTILS:UTILITY ASK "Name of RQ Script" "" "" Z
$         P1 = RQS$ANSWER
$ ENDIF
$ P1 = F$PARSE(P1,".script")
$ Script_File = F$SEARCH(P1)
$ IF Script_File .EQS. ""
$    THEN WRITE SYS$OUTPUT "RQ Script file not found ''P1'"
$    P1 = ""
$    goto L0
$ ENDIF
$ !
$ DEFINE /NOLOG rq$command 'Script_File'
$ IF F$TYPE(RQ) .EQS. "" THEN RQ = "@site$utils:rq$interactive"
$ RQ
$ !
$Done:
$ SET NOON
$ @site$utils:utility EXIT RQS
$ IF F$TRNLNM("rq$command") .NES. "" THEN DEASSIGN rq$command
$ EXIT 1
$ !
$Ctrl_Y:
$ RETURN %X0000002C
