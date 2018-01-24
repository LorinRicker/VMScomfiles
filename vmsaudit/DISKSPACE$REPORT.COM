$ ! DISKSPACE$REPORT.COM --                                        'F$VERIFY(0)'
$ !
$ ! Copyright © 2014-2018 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ! === MAIN ===
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO DS$Done
$ !
$ DD$Disks  == ""
$ wso        = "WRITE sys$output"
$ Fac        = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ Node       = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ COMMA      = ","
$ DOLLAR     = "$"
$ UNDERSCORE = "_"
$ !
$ mask       = %X7FFFFFFF
$ maskdiv100 = mask / 100
$ !
$ IF ( P1 .NES. "" )
$ THEN j = 2
$PLoop1:
$      IF ( P'j' .NES. "" )
$      THEN P1 = P1 + COMMA + P'j'
$           j = j + 1
$           IF ( j .LE. 8 ) THEN GOTO PLoop1
$      ENDIF
$PCont1:
$      j = 0
$PLoop2:
$      dv = F$ELEMENT( j, COMMA, P1 )
$      IF ( dv .EQS. COMMA ) THEN GOTO PCont2
$      IF ( F$GETDVI( dv, "EXISTS" ) )
$      THEN IF ( DD$Disks .NES. "" )
$           THEN DD$Disks == DD$Disks + COMMA + dv
$           ELSE DD$Disks == dv
$           ENDIF
$      ELSE wso F$FAO( "%!AS-E-NOSUCHDEV, no such device '!AS'", Fac, dv )
$           EXIT 1  ! 'F$VERIFY(0)'
$      ENDIF
$      j = j + 1
$      GOTO PLoop2
$ ELSE DCL$CALL DiscoverDisks DD$Disks "MNT,!SHDW_MEMBER"
$ ENDIF
$PCont2:
$ !
$ devfldlen = 16
$ headfill  = 24
$ !
$ header = F$FAO( "!#* !AS",  -
                  devfldlen+headfill, -
                  "Free blocks             Used blocks       Total blocks" )
$ headln = F$FAO( "-- Disk Space !#*-", F$LENGTH( header ) - headfill + 12 )
$ !
$ wso F$FAO( "%!AS-I-SPACE, Disk Space on !AS", Fac, Node )
$ wso ""
$ wso header
$ wso headln
$ !
$ devcnt = 0
$DS$Loop:
$ dev = F$ELEMENT( devcnt, COMMA, DD$Disks )
$ IF ( dev .EQS. COMMA ) .OR. ( dev .EQS. "" ) THEN GOTO DS$Done
$ devcnt = devcnt + 1
$ !
$ volname  = F$GETDVI( dev, "VOLNAM" )
$ totalblks = F$GETDVI( dev, "MAXBLOCK" )
$ freeblks  = F$GETDVI( dev, "FREEBLOCKS" )
$ usedblks  = totalblks - freeblks
$ !
$ ! Use these temp-variables for scaling down into DCL's 32-bit integer range:
$ totaltmp  = totalblks
$ freetmp   = freeblks
$ usedtmp   = usedblks
$ !
$ dev   = dev - "_"  ! strip leading underscore
$ !
$DS$range:
$ IF ( freetmp .LT. 0 ) .OR. ( usedtmp .LT. 0 ) .OR. ( totaltmp .LT. 0 )
$ THEN freetmp  = ( freetmp  / 2 ) .AND. mask
$      usedtmp  = ( usedtmp  / 2 ) .AND. mask
$      totaltmp = ( totaltmp / 2 ) .AND. mask
$ ENDIF
$ !
$ IF ( usedtmp .GT. maskdiv100 ) .OR. ( freetmp .GT. maskdiv100 ) .OR. ( totaltmp .GT. maskdiv100 )
$ THEN freetmp  = freetmp  / 10
$      usedtmp  = usedtmp  / 10
$      totaltmp = totaltmp / 10
$      GOTO DS$range
$ ENDIF
$ !
$ freepct = ( freetmp * 100 ) / totaltmp
$ usedpct = ( usedtmp * 100 ) / totaltmp
$ !
$ devlen = F$LENGTH( dev )
$ fldlen = 16
$ ! Display the actual sizes, not the rescale temps:
$ DCL$CALL Thousands "DS$freeblks"  "''freeblks'"
$ freelen = F$LENGTH( DS$freeblks )
$ DCL$CALL Thousands "DS$usedblks"  "''usedblks'"
$ usedlen = F$LENGTH( DS$usedblks )
$ DCL$CALL Thousands "DS$totalblks" "''totalblks'"
$ totalen = F$LENGTH( DS$totalblks )
$ wso F$FAO( "!#* !AS !12AS !#* !AS !3UL% | !#* !AS !3UL% | !#* !AS |", -
             devfldlen-devlen, dev, volname, -
             fldlen-freelen, DS$freeblks, freepct, -
             fldlen-usedlen, DS$usedblks, usedpct, -
             fldlen-totalen, DS$totalblks )
$ GOTO DS$Loop
$ !
$DS$Done:
$ wso F$FAO( "!#*-", F$LENGTH( headln ) )
$ wso ""
$ !
$ DCL$CALL DeleteGloSyms "DD$Disks,DS$freeblks,DS$usedblks,DS$totalblks"
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$Ctrl_Y:
$ EXIT %X2C
$ !
