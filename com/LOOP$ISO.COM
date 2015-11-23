$ ! LOOP$ISO.COM                                                   'F$VERIFY(0)'
$ !
$ !  use: @LOOP$ISO filename.ISO [ DISMOUNT ]
$ !
$ wso = "WRITE sys$output"
$ Fac = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ prv = F$SETPRV("ALL")
$ !
$ ISOfile = F$PARSE(P1,"SYS$DISK:[].ISO")
$ !
$ IF P2 .EQS. "" THEN P2 = "MOUNT"
$ GOTO 'F$EXTRACT(0,3,P2)
$ !
$Mou:
$ IF .NOT. F$GETDVI("LD","EXISTS")      ! does an $a$LDA0 device exist?
$ THEN @sys$startup:LD$startup          ! ...no, then create it
$ ENDIF
$ baseLDev = F$GETDVI("LD","ALLDEVNAM") ! allocation-class device name
$ !
$ ! see $ LD HELP for documentation:
$ ! LD CONNECT creates DCL local symbol LD_UNIT, the unit number connected;
$ ! create global symbol Loop$ISO$LDev for persistence to DISMOUNT step...
$ LD CONNECT 'ISOfile' /SYMBOL
$ Loop$ISO$LDev == baseLDev - "0:" + "''LD_UNIT':"
$ wso "%''Fac'-I-LD_UNIT, using device ''Loop$ISO$LDev'"
$ !
$ MOUNT /OVERRIDE=IDENT 'Loop$ISO$LDev' 'ISOfile'
$ DIRECTORY /SIZE /DATE /PROTECTION 'Loop$ISO$LDev'[000000]
$ GOTO Done
$ !
$Dis:  ! Dismount
$ DISMOUNT /NOUNLOAD 'Loop$ISO$LDev'
$ LD DISCONNECT /LOG 'Loop$ISO$LDev'
$ DELETE /SYMBOL /GLOBAL Loop$ISO$LDev
$ GOTO Done
$ !
$Done:
$ prv = F$SETPRV(prv)
$ EXIT      !'F$VERIFY(0)'
