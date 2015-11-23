$ ! RQ$INTERACTIVE.COM - ReQueue commands for periodic execution   'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2003 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1988-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ @site$utils:utility START RQ 'F$ENVIRONMENT("PROCEDURE")' "" "''P1'"
$ !
$ Prv = F$SETPRV("CMKRNL")
$ IF F$TRNLNM("holiday") .EQS. ""    -
  THEN DEFINE /NOLOG holiday sys$disk:[]holiday,site$utils:holiday.dat
$ !
$ RQ$Verbose == F$TRNLNM("Tools$Debug")
$ IF RQ$Verbose THEN SHOW LOGICAL /FULL rq$package
$ !
$RQ_0:
$ SET ON
$ IF .NOT. RQ$Interactive THEN GOTO L2
$ TYPE sys$input
Execute on which days?

    1    Periodic
    2    Holidays
    3    n times
    4    Workdays
    5    Weekdays
    6    Weekends

$L2:
$ @site$utils:utility CHOOSE "Which days" "123456,PHNW56" "" Z
$ IF RQ$Choice .EQ. 0 THEN GOTO Done
$ CALL Day_'RQ$Choice'
$ IF RQ$Choice .EQ. 0 THEN GOTO RQ_0
$ Day = F$ELEMENT(RQ$Choice-1,",","Periodic,Holiday,Value,Workday" -
               + ",Monday,Tuesday,Wednesday,Thursday,Friday,Weekday" -
               + ",Saturday,Sunday,Weekend")
$ Day = F$EDIT(Day,"UPCASE")
$ IF Day .EQS. "VALUE" THEN Day = RQ$N_Times
$ RQ$Day == Day
$ !
$L3:
$ SET NOON
$ @site$utils:utility ASK "Time <NOW>" "" "" ZN
$ IF .NOT. $STATUS THEN GOTO RQ_0
$ Time = RQ$Answer
$ IF Time .EQS. "" THEN GOTO L4
$ Time = F$CVTIME(Time,"ABSOLUTE")
$ IF .NOT. $STATUS THEN GOTO L3
$L4:
$ RQ$Time == Time
$ SET ON
$ !
$ @site$utils:utility ASK "Increment" "" "1-00:00:00.00"
$ IF RQ$Answer .EQS. "" THEN GOTO RQ_0
$ Incr = RQ$Answer
$ IF F$CVTIME(Incr,"DELTA") .EQS. "0 00:00:00.00" THEN Incr = "1 00:00:00.00"
$ Incr = F$CVTIME(Incr,"DELTA","DAY") + "-" + F$CVTIME(Incr,"DELTA","TIME")
$ RQ$Incr == Incr
$ !
$ Default = "RQ$" + F$EDIT(F$GETJPI("","USERNAME"),"TRIM")
$ @site$utils:utility ASK "Job name" "" "''Default'" D
$ IF RQ$Answer .EQS. "" THEN GOTO RQ_0
$ RQ$Name == RQ$Answer
$ !
$ RQ$User == ""
$ IF F$TYPE(RQ$Command_String) .NES. ""
$ THEN Command = RQ$Command_String
$      GOTO Comm2
$ ENDIF
$ IF .NOT. F$PRIVILEGE("CMKRNL") THEN GOTO Comm
$ Self = F$EDIT(F$GETJPI("","USERNAME"),"TRIM")
$ @site$utils:utility ASK "For user" "" "''Self'" D
$ IF RQ$Answer .EQS. "" THEN GOTO RQ_0
$ User = RQ$Answer
$ IF User .EQS. Self THEN User = ""
$ IF User .NES. "" THEN User = "/USER=''User'"
$ RQ$User == User
$ !
$Comm:
$ SET NOON
$ @site$utils:utility ASK "Command" "" "" "ZP"
$ IF .NOT. $STATUS THEN GOTO RQ_0
$ SET ON
$ IF RQ$Answer .EQS. "" THEN GOTO Comm
$ Command = RQ$Answer
$ IF F$LOCATE("""",Command) .EQ. F$LENGTH(Command) THEN GOTO Comm1
$ IF .NOT. F$PRIVILEGE("CMKRNL") THEN GOTO Comm2
$ IF User .EQS. "" THEN GOTO Comm2
$ TYPE sys$input
        When submitting a command for another user, that command
        may not include quotes (").  You may create a command
        file which includes quotes and submit that for the user.
        For example:
                $ [4mCREATE XYZ.COM[0m
                [1m$ REPLY /TERMINAL=opa0: "Message text"[0m
                [1m^Z[0m
        and then submit the command @XYZ.COM with RQ.
$ GOTO Comm
$ !
$Comm2:
$ OPEN /WRITE rq-file sys$login:'RQ$Name'.temp_com
$ WRITE rq-file "$ ",Command
$ WRITE rq-file "$ DELETE 'F$ENVIRONMENT(""PROCEDURE"")'"
$ CLOSE rq-file
$ Command = "@" + F$SEARCH("sys$login:''RQ$Name'.temp_com")
$ !
$Comm1:
$ RQ$Command == Command
$Queue0:
$ Default = "SYS$BATCH /CHAR=TAPE_DRIVE"
$ @site$utils:utility ASK "Queue" "" "''Default'"
$ IF RQ$Answer .EQS. "" THEN GOTO RQ_0
$ RQ$System == RQ$Answer
$ @site$utils:rq$submit "''RQ$Command'"                      -
                        "''RQ$Day',''RQ$Time',''RQ$Incr'"    -
                        "''RQ$System',''RQ$Name',''RQ$User'" -
                        "TRUE"
$ IF F$TYPE(RQ$Command_String) .EQS. "" THEN GOTO RQ_0
$ !
$Done:
$ SET NOON
$ @site$utils:utility EXIT RQ
$ IF F$TYPE(Prv) .NES. "" THEN  Prv = F$SETPRV(Prv)
$ IF F$TRNLNM("rq-file") .NES. "" THEN CLOSE rq-file
$ IF F$TRNLNM("rq-holiday","lnm$process") .NES. "" THEN DEASSIGN /PROCESS rq-holiday
$ EXIT 1
$ !
$ !
$ !
$Day_1: SUBROUTINE
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Day_2: SUBROUTINE
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Day_3: SUBROUTINE
$ ON CONTROL_Y THEN EXIT %X0000002C
$ ON ERROR THEN EXIT 1
$Day_3_1:
$ @site$utils:utility ASK "How many times" "" "1" Z
$ IF F$TYPE(RQ$Answer) .NES. "INTEGER" THEN GOTO Day_3_1
$ IF RQ$Answer .LT. 0 THEN GOTO Day_3_1
$ IF RQ$Answer .EQ. 0 THEN RQ$Choice == 0
$ RQ$N_Times == RQ$Answer
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Day_4: SUBROUTINE
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Day_5: SUBROUTINE
$ ON CONTROL_Y THEN EXIT %X0000002C
$ ON ERROR THEN EXIT 1
$ IF .NOT. RQ$Interactive THEN GOTO L5
$ TYPE sys$input
    Which weekday?

    1    Monday
    2    Tuesday
    3    Wednesday
    4    Thursday
    5    Friday
    6    All weekdays

$L5:
$ @site$utils:utility CHOOSE "Weekday" "123456,MTW4FA" "" Z
$ RQ$Choice == RQ$Choice + 4
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Day_6: SUBROUTINE
$ ON CONTROL_Y THEN EXIT %X0000002C
$ ON ERROR THEN EXIT 1
$ IF .NOT. RQ$Interactive THEN GOTO L6
$ TYPE sys$input
    Which weekend day?

    1    Saturday
    2    Sunday
    3    Both weekend days

$L6:
$ @site$utils:utility CHOOSE "Weekend" "123,S2B" "" Z
$ RQ$Choice == RQ$Choice + 10
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Ctrl_Y:
$ RETURN %X0000002C
