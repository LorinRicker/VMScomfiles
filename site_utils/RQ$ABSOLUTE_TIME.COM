$ ! RQ$ABSOLUTE_TIME.COM                                           'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2003 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1988-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ! P1 = <day>,<time>,<increment>
$ ! P2 = "TRUE" means "no increment", otherwise use <increment>
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Day          = F$EDIT(F$ELEMENT(0,",",P1),"UPCASE,TRIM")
$ RQ$A_Time   == F$ELEMENT(1,",",P1)
$ Increment    = F$ELEMENT(2,",",P1)
$ IF P2
$ THEN I = "0-00:00:00.00"
$ ELSE I = Increment
$ ENDIF
$ RQ$Abs_Date == Day
$ RQ$Reque    == "YES"
$ Days         = " SUN SAT FRI THU WED TUE MON SUN SAT FRI THU WED TUE"
$ !
$ IF F$INTEGER("0"+RQ$Abs_Date) .GT.  0 THEN Day = "VALUE"
$ IF F$LOCATE(F$EXTRACT(0,3,RQ$Abs_Date),Days) .LT. 28 THEN Day = "xxxday"
$ IF ( Day .EQS. "HOLIDAY" ) .OR. ( Day .EQS. "WORKDAY" ) -
  THEN OPEN rq-holiday holiday
$ RQ$Start = F$CVTIME("")
$ !
$L0:
$ CALL 'Day' "''I'"
$ IF F$CVTIME(RQ$Abs_Time) .GES. RQ$Start THEN GOTO Done
$L1:
$ RQ$Abs_Time == F$CVTIME("''RQ$Abs_Time'+''Increment'","ABSOLUTE")
$ IF F$CVTIME(RQ$Abs_Time) .LTS. RQ$Start THEN GOTO L1
$ I = "0-00:00:00.00"
$ RQ$A_Time == RQ$Abs_Time
$ GOTO L0
$ !
$Done:
$ Status = $STATUS
$ SET NOON
$ IF F$TRNLNM("rq-holiday","lnm$process") .NES. "" THEN DEASSIGN /PROCESS rq-holiday
$ EXIT (Status .OR. %X10000000)
$ !
$ !
$ !
$Periodic: SUBROUTINE
$ ON CONTROL_Y THEN EXIT %X0000002C
$ ON ERROR THEN EXIT $STATUS
$ IF RQ$A_Time .EQS. ""
$ THEN RQ$Abs_Time == F$CVTIME("","ABSOLUTE")
$ ELSE RQ$Abs_Time == F$CVTIME("''RQ$A_Time'+''P1'","ABSOLUTE")
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Workday: SUBROUTINE
$ ON CONTROL_Y THEN EXIT %X0000002C
$ ON ERROR THEN EXIT $STATUS
$L3:
$ CALL Weekday "''P1'"
$ RQ$A_Time == RQ$Abs_Time
$ READ /ERROR=L4 /MATCH=EQ /NOLOCK /KEY='F$CVTIME(RQ$A_Time,,"DATE")' -
        rq-holiday Delta
$ RQ$A_Time == F$CVTIME("''RQ$A_Time'+1-","ABSOLUTE")
$ P1 = "0-00:00:00.00"
$ GOTO L3
$L4:
$ RQ$Abs_Time == RQ$A_Time
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Weekend: SUBROUTINE
$ ON CONTROL_Y THEN EXIT %X0000002C
$ ON ERROR THEN EXIT $STATUS
$ Days = " FRI THU WED TUE MON SUN SAT"
$ IF RQ$A_Time .EQS. ""
$ THEN Next = ""
$ ELSE Next = "''RQ$A_Time'+''P1'"
$ ENDIF
$ W = F$EDIT(F$EXTRACT(0,3,F$CVTIME(Next,,"WEEKDAY")),"UPCASE")
$ Delta = 1 + ((F$LOCATE(W,Days) - 1) / 4)
$ IF Delta .LE. 5 THEN Next = "''F$CVTIME(Next,"ABSOLUTE")'+''Delta'-"
$ RQ$Abs_Time == F$CVTIME(Next,"ABSOLUTE")
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Weekday: SUBROUTINE
$ ON CONTROL_Y THEN EXIT %X0000002C
$ ON ERROR THEN EXIT $STATUS
$ Days = " SUN SAT FRI THU WED TUE MON"
$ IF RQ$A_Time .EQS. ""
$ THEN Next = ""
$ ELSE Next = "''RQ$A_Time'+''P1'"
$ ENDIF
$ W = F$EDIT(F$EXTRACT(0,3,F$CVTIME(Next,,"WEEKDAY")),"UPCASE")
$ Delta = 1 + ((F$LOCATE(W,Days) - 1) / 4)
$ IF Delta .LE. 2 THEN Next = "''F$CVTIME(Next,"ABSOLUTE")'+''Delta'-"
$ RQ$Abs_Time == F$CVTIME(Next,"ABSOLUTE")
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Holiday: SUBROUTINE
$ ON CONTROL_Y THEN EXIT %X0000002C
$ ON ERROR THEN EXIT $STATUS
$ IF RQ$A_Time .EQS. ""
$ THEN Next = ""
$ ELSE Next = "''RQ$A_Time'+''P1'"
$ ENDIF
$ READ /ERROR=L5 /MATCH=GE /NOLOCK /KEY='F$CVTIME(Next,,"DATE")' -
      rq-holiday Date
$ Date = F$EXTRACT(10,11,Date)
$ Time = F$CVTIME(Next,,"TIME")
$ RQ$A_Time == F$CVTIME("''Date'+''Time'","ABSOLUTE")
$L5:
$ RQ$Abs_Time == RQ$A_Time
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Value: SUBROUTINE
$ ON CONTROL_Y THEN EXIT %X0000002C
$ ON ERROR THEN EXIT $STATUS
$ RQ$Abs_Date == F$INTEGER(RQ$Abs_Date)
$ RQ$Abs_Date == RQ$Abs_Date - 1
$ IF RQ$Abs_Date .LE. 0 THEN RQ$Reque == "NO"
$ IF RQ$A_Time .EQS. ""
$ THEN Next = ""
$ ELSE Next = "''RQ$A_Time'+''P1'"
$ ENDIF
$ RQ$Abs_Time == F$CVTIME(Next,"ABSOLUTE")
$ EXIT 1
$ ENDSUBROUTINE
$ !
$xxxday: SUBROUTINE
$ ON CONTROL_Y THEN EXIT %X0000002C
$ ON ERROR THEN EXIT $STATUS
$ IF RQ$A_Time .EQS. ""
$ THEN Next = ""
$ ELSE Next = "''RQ$A_Time'+''P1'"
$ ENDIF
$ Next = F$CVTIME(Next,"ABSOLUTE")
$ D = F$LOCATE(F$EXTRACT(0,3,RQ$Abs_Date),Days)
$ IF D .LT. 0 THEN D = D + 28
$ W = F$EDIT(F$EXTRACT(0,3,F$CVTIME(Next,,"WEEKDAY")),"UPCASE")
$ Delta = F$LOCATE(W,F$EXTRACT(D,28,Days))/4
$ RQ$Abs_Time == F$CVTIME("''Next'+''Delta'-","ABSOLUTE")
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Ctrl_Y:
$ RETURN %X0000002C
