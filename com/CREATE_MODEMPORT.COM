$ ! CREATE_MODEMPORT.COM --                                        'F$VERIFY(0)'
$ !
$ !  P1: Logical name for device (optional)
$ !  P2: Service name (optional)
$ !  P3: LAT device name
$ !  P4: Terminal server node name
$ !  P5: Port name
$ !
$ SET NOON
$ Prv = F$SETPRV("CMKRNL,LOG_IO,SYSNAM,SYSPRV")
$ IF P1 .NES. ""
$ THEN P1 = "/LOGICAL=(NAME=" + P1 + ",TABLE=system,MODE=executive)"
$ ENDIF
$ IF P2 .NES. ""
$ THEN P2 = "/SERVICE=" + P2
$ ENDIF
$ IF P3 .EQS. ""
$ THEN D = "LTA7777:"
$      READ sys$command Dev /END_OF_FILE=Done -
         /PROMPT="LAT device name <''D'>: "
$      IF Dev .EQS. "" THEN Dev = D
$ ELSE Dev = P3
$ ENDIF
$ IF P4 .EQS. ""
$ THEN D = "LAT_08002BB158C0"
$      READ sys$command TS /END_OF_FILE=Done -
         /PROMPT="Terminal server node name <''D'>: "
$      IF TS .EQS. "" THEN TS = D
$ ELSE TS = P4
$ ENDIF
$ IF P5 .EQS. ""
$ THEN D = "PORT_2"
$      READ sys$command Port /END_OF_FILE=Done -
         /PROMPT="Terminal server port name <''D'>: "
$      IF Port .EQS. "" THEN Port = D
$ ELSE Port = P5
$ ENDIF
$ !
$ IF .NOT. F$GETDVI(Dev,"EXISTS")
$ THEN LCP CREATE PORT 'Dev' /APPLICATION 'P1' /LOG
$      LCP    SET PORT 'Dev' /APPLICATION 'P2' /NODE='TS' /PORT='Port'
$ ENDIF
$ !
$ DEFINE /JOB /NOLOG Dial$Device 'Dev'
$ !
$Done:
$ Prv = F$SETPRV(Prv)
$ EXIT
