$ ! DIAL.COM -- DMG (dial) driven SET HOST/DTE 'F$VERIFY(0)'
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ @site$utils:utility START DIAL 'F$ENVIRONMENT("PROCEDURE")'
$ IF F$TRNLNM("dial$connected") .NES. "" THEN GOTO DIAL
$ !
$ DIAL$Phone  = F$EDIT(P1,"UPCASE,COMPRESS,TRIM")
$ DIAL$Modem  = F$EDIT(F$ELEMENT(0,",",P2),"UPCASE,COLLAPSE")
$ DIAL$Speed  = F$EDIT(F$ELEMENT(1,",",P2),"UPCASE,COLLAPSE")
$ DIAL$Bits   = F$EDIT(F$ELEMENT(2,",",P2),"UPCASE,COLLAPSE")
$ DIAL$Parity = F$EDIT(F$ELEMENT(3,",",P2),"UPCASE,COLLAPSE")
$ DIAL$Emul   = F$EDIT(F$ELEMENT(4,",",P2),"UPCASE,COLLAPSE")
$ DIAL$Dev    = F$EDIT(F$ELEMENT(5,",",P2),"UPCASE,COLLAPSE")
$ DIAL$Comm   = P3
$ DIAL$Pause  = P4
$ DIAL$Index  = 0
$ !
$ IF DIAL$Dev .EQS. "" THEN DIAL$Dev = "dial$device"
$ @site$utils:utility expand 'DIAL$Dev' Devices
$ IF DIAL$Devices .EQS. ""      -
  THEN @site$utils:utility SIGNAL 'UTIL_NODEVICE' 'DIAL$Dev'
$L0:
$ DIAL$Device = F$ELEMENT(DIAL$Index,",",DIAL$Devices)
$ IF DIAL$Device .EQS. ","
$ THEN @site$utils:utility SIGNAL 'UTIL_NODEVICE' 'DIAL$Dev'
$ ELSE IF F$GETDVI(DIAL$Device,"EXISTS")
$      THEN IF F$GETDVI(DIAL$Device,"TRM")
$           THEN ALLOCATE 'DIAL$Device'
$                IF $STATUS THEN GOTO L1
$           ENDIF
$      ENDIF
$ ENDIF
$ DIAL$Index = DIAL$Index + 1
$ GOTO L0
$ !
$L1:
$ WRITE sys$output DIAL$Comm
$ IF DIAL$Modem  .EQS. ""  THEN DIAL$Modem  = "HAYES"
$ IF DIAL$Speed  .EQS. ""  THEN DIAL$Speed  = "1200"
$ IF DIAL$Bits   .EQS. ""  THEN DIAL$Bits   = "8"
$ IF DIAL$Emul   .EQS. ""  THEN DIAL$Emul   = "S"
$ DIAL$BP = "/EIGHT_BIT"
$ IF DIAL$Bits   .NES. "8" THEN DIAL$BP    = "/NOEIGHT_BIT"
$ IF (DIAL$Parity .EQS. "") .OR. (DIAL$Parity .EQS. "N") THEN DIAL$Parity = "NONE"
$ IF (DIAL$Parity .EQS. "E") THEN DIAL$Parity = "EVEN"
$ IF (DIAL$Parity .EQS. "O") THEN DIAL$Parity = "ODD"
$ DIAL$BP = DIAL$BP + "/PARITY=" + DIAL$Parity
$ WRITE sys$output ""
$ WRITE sys$output ""
$ SET TERMINAL 'DIAL$BP' /SPEED='DIAL$Speed' -
       /NOECHO /NOLINE_EDIT /NOWRAP 'DIAL$Device'
$ Time_0 = F$TIME()
$ !
$ DIAL$Dial = ""
$ IF DIAL$Modem .NES. "NODIAL" .AND. DIAL$Phone .NES. ""        -
  THEN DIAL$Dial = "/NUMBER=""''DIAL$Phone'""/MODEM=''DIAL$Modem'"
$ IF F$TRNLNM("dial$manual") THEN DIAL$Dial = ""
$ SET NOON
$ IF DIAL$Dial .EQS. ""
$ THEN WRITE sys$output "Establish connection manually (",DIAL$Phone,")"
$ ELSE MODEM 'DIAL$Device' 'DIAL$Dial'
$ ENDIF
$ IF $STATUS
$ THEN SET PROCESS /PRIORITY=3
$      DEFINE /USER_MODE sys$input sys$command
$      IF DIAL$Emul .EQS. "S"
$      THEN SET HOST /DTE 'DIAL$BP' 'DIAL$Device' /LOG=sys$scratch:dial.log /ERROR=EXIT
$      ELSE DEFINE /USER_MODE ker$comm 'DIAL$Device'
$!          DEFINE /USER_MODE vmskermit site$utils:kermit_connect.ker
$           RUN site$utils:kermit
$      ENDIF
$ ENDIF
$ IF $STATUS
$ THEN DEFINE dial$connected 'DIAL$Device','DIAL$Emul'
$      SET ON
$ ELSE DIAL$Attempted = "TRUE"
$      GOTO Done
$ ENDIF
$ !
$DIAL:
$ TYPE sys$input
  Dialout Options

    1       Kermit
    2       DCL
    3       Reconnect


$ @site$utils:utility CHOOSE "Option" "123,KDR" "R" "Z"
$ GOTO DIAL_'DIAL$Choice'
$ !
$DIAL_1:                ! Kermit
$ DIAL$Connected = F$TRNLNM("dial$connected")
$ DIAL$Emul = F$TRNLNM("dial$connected",,1)
$ DEFINE /USER_MODE ker$comm 'DIAL$Connected'
$ DEFINE /USER_MODE sys$input sys$command
$ RUN site$utils:kermit
$ GOTO DIAL
$ !
$DIAL_2:                ! Exit to DCL leaving connection open
$ SET NOON
$ @site$utils:utility EXIT DIAL
$ dial    == "@''F$ENVIRONMENT("PROCEDURE")'"
$ lo*gout == dial
$ EXIT
$ !
$DIAL_3:                ! Reestablish connection
$ DIAL$Connected = F$TRNLNM("dial$connected")
$ DIAL$Emul = F$TRNLNM("dial$connected",,1)
$ DEFINE /USER_MODE sys$input sys$command
$ IF DIAL$Emul .EQS. "S"
$ THEN SET HOST /DTE 'DIAL$Connected' /LOG=sys$scratch:dial.log /ERROR=EXIT
$ ELSE DEFINE /USER_MODE ker$comm 'DIAL$Connected'
$      RUN site$utils:kermit
$ ENDIF
$ GOTO DIAL
$ !
$Done:                  ! Exit and disconnect
$ DIAL$Status = $STATUS
$ SET NOON
$ IF F$TYPE(DIAL$Attempted) .NES. "" THEN MODEM 'DIAL$Device' /CONSUME
$ DIAL$Connected = F$TRNLNM("dial$connected")
$ IF DIAL$Connected .EQS. "" THEN GOTO D0
$ IF (F$EXTRACT(0,3,M$Dev) .NES. "LTA")
$ THEN SET TERMINAL 'DIAL$Connected' /NOMODEM
$      SET TERMINAL 'DIAL$Connected' /MODEM
$ ENDIF
$ IF F$GETDVI(DIAL$Connected,"ALL") THEN DEALLOCATE 'DIAL$Connected'
$ DEASSIGN dial$connected
$D0:
$ IF F$TYPE(Time_0) .EQS. "" THEN GOTO D1
$ !!!!«» RUN site$utils:time  !calculate approximate telephone connect time
$ Days = "$site$utils:dc$datecalc"
$ Days "''Time_0'" /DELTA /SYMBOL=Time_0 /SCOPE=LOCAL
$ WRITE sys$error F$FAO(F$MESSAGE(UTIL_CONNECT),Time_0)
$D1:
$ IF DIAL$Pause THEN @site$utils:utility ASK "Press" "" "RETURN"
$ IF F$GETJPI("","PID") .EQS. F$GETJPI("","MASTER_PID")         -
  THEN  EXIT (DIAL$Status .OR. %X10000000)
$ LOGOUT = "LOGOUT"
$ LOGOUT
$ !
$Ctrl_Y:
$ RETURN %X0000002C
