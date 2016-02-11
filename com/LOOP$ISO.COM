$ ! LOOP$ISO.COM                                                   'F$VERIFY(0)'
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
