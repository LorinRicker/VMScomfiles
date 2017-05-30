$ ! DISKSPACE$REPORT.COM --                                        'F$VERIFY(0)'
$ !
$ ! Copyright © 2014-2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ON ERROR THEN GOTO Done
$ !
$ DS$Disks  == ""
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
$ THEN DS$Disks == P1
$ ELSE DCL$CALL DiscoverDisks DS$Disks "MNT,!SHDW_MEMBER"
$ ENDIF
$ show symbol /global DS$Disks
$ !
$ devfldlen = 16
$ headfill  = 14
$ !
$ header = F$FAO( "!#* !AS !#* !AS !#* !AS",  -
                  devfldlen*2, "free", devfldlen, "used", devfldlen, "total" )
$ headln = F$FAO( "-- Disk Space !#*-", F$LENGTH( header ) - headfill )
$ !
$ wso F$FAO( "%!AS-I-DISKS, disks on !AS", Fac, Node )
$ wso ""
$ wso header
$ wso headln
$ !
$ devcnt = 0
$DS$Loop:
$ dev = F$ELEMENT( devcnt, COMMA, DS$Disks )
$ IF ( dev .EQS. COMMA ) .OR. ( dev .EQS. "" ) THEN GOTO DS$Done
$ devcnt = devcnt + 1
$ !
$ volname  = F$GETDVI( dev, "VOLNAM" )
$ totalblks = F$GETDVI( dev, "MAXBLOCK" )
$ freeblks  = F$GETDVI( dev, "FREEBLOCKS" )
$ usedblks  = totalblks - freeblks
$ dev   = dev - "_"  ! strip leading underscore
$ !
$DS$range:
$ IF ( freeblks .LT. 0 ) .OR. ( usedblks .LT. 0 ) .OR. ( totalblks .LT. 0 )
$ THEN freeblks  = ( freeblks  / 2 ) .AND. mask
$      usedblks  = ( usedblks  / 2 ) .AND. mask
$      totalblks = ( totalblks / 2 ) .AND. mask
$ ENDIF
$ !
$ IF ( usedblks .GT. maskdiv100 ) .OR. ( freeblks .GT. maskdiv100 ) .OR. ( totalblks .GT. maskdiv100 )
$ THEN freeblks  = freeblks  / 10
$      usedblks  = usedblks  / 10
$      totalblks = totalblks / 10
$      GOTO DS$range
$ ENDIF
$ !
$ freepct = ( freeblks * 100 ) / totalblks
$ usedpct = ( usedblks * 100 ) / totalblks
$ wso F$FAO( "  !20AS!12AS !3SL% free, !3SL% used", dev, volname, freepct, usedpct )
$ GOTO DS$Loop
$ !
$DS$Done:
$ wso F$FAO( "!#*-", F$LENGTH( headln ) )
$ wso ""
$ !
$ DCL$CALL DeleteGloSyms "DS$Disks"
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$Ctrl_Y:
$ EXIT %X2C
$ !
