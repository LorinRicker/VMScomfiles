$ ! DISKWWID$REPORT.COM --                                         'F$VERIFY(0)'
$ !
$ ! Copyright © 2018 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ !  Create spreadsheet inventories (CSV) of all disks
$ !
$ !  use: @DISKWWID$REPORT [disk[,disk]...]
$ !
$ !       If P1 is a comma-separated list of disk names, then only these devices
$ !       are checked, otherwise all physical (non-DSA) devices are checked
$ !
$ !  Run this com-file without /OUTPUT=filespec to see the report on your terminal;
$ !  use /OUTPUT=filespec to save the report to a comma-separated report file which
$ !  can be imported into an Excel/Calc spreadsheet.
$ !
$ !
$ ! === MAIN ===
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO DP$Exit
$ !
$ VMS$ver  = F$EDIT(F$GETSYI("VERSION"),"TRIM")
$ minVMS80 = ( VMS$ver .GES. "V8.0" ) 
$ !
$ DD$Disks  == ""
$ wso        = "WRITE sys$output"
$ Fac        = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ Node       = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ COMMA      = ","
$ DOLLAR     = "$"
$ SLASH      = "/"
$ UNDERSCORE = "_"
$ !
$ alloclass = DOLLAR + F$STRING( F$GETSYI( "ALLOCLASS" ) ) + DOLLAR
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
$ ELSE DCL$CALL DiscoverDisks DD$Disks "MNT,SHDW_MEMBER"
$ ENDIF
$PCont2:
$ !
$ devfldlen = 16
$ headfill  = 72
$ !
$ headln = F$FAO( "-- Device WWIDs & Paths !#*-", headfill )
$ !
$ wso F$FAO( "%!AS-I-WWID-FIBRE, Disk Device WWIDs and Fibre Channel info on !AS", Fac, Node )
$ wso ""
$ wso headln
$ !
$ loopcnt = 0
$ devcnt  = 0
$DP$Loop1:
$ dev = F$ELEMENT( loopcnt, COMMA, DD$Disks )
$ IF ( dev .EQS. COMMA ) .OR. ( dev .EQS. "" ) THEN GOTO DP$Done1
$ loopcnt = loopcnt + 1
$ !
$ devl     = F$LENGTH( dev )
$ nakeddev = dev - UNDERSCORE - alloclass - "''Node'$"           ! undecorate it...
$ devtype  = F$EXTRACT( 0, 3, nakeddev )
$ IF F$GETDVI( dev, "MNT" ) .AND. ( devtype .NES. "DSA" )  ! must be mounted, but not DSAnnn:
$ THEN devcnt = devcnt + 1
$      ! Full accounting for a mounted disk:
$      volnam = F$GETDVI( dev, "VOLNAM" )
$      devlnm = F$TRNLNM( "DISK$''volnam'", "LNM$SYSTEM" )
$      IF ( devlnm .NES. "" )
$      THEN devlnm = "DISK$''volnam'"
$      ELSE devlnm = volnam
$      ENDIF
$      IF minVMS80
$      THEN ! these $GETDVI item-codes weren't available pre-V8.x:
$      ENDIF
$      shadow = "Just a disk"
$      IF ( F$GETDVI( dev, "SHDW_MASTER" ) )
$      THEN shadow = "Virt/Shadow Set"
$      ELSE IF ( F$GETDVI( dev, "SHDW_MEMBER" ) )
$           THEN shadow   = "member of " + F$GETDVI( dev, "SHDW_MASTER_NAME" ) - UNDERSCORE
$           ELSE shadow   = "just a disk"
$           ENDIF
$           wwid   = F$GETDVI( dev, "WWID" )
$      ENDIF
$ !
$      wso F$FAO( "!3SL.!#* !AS !18AS !AS", devcnt, devfldlen-devl, dev, devlnm, shadow )
$      IF ( wwid .EQS. "" )
$      THEN IF ( F$LOCATE( "LDA", nakeddev) .LT. F$LENGTH( nakeddev ) )
$           THEN wwid = "file-backed disk (LD)"
$           ELSE wwid = "locally-attached"
$           ENDIF
$      ELSE wwid = "WWID: " + wwid
$      ENDIF
$      wso F$FAO( "!#* !AS", 12, wwid)
$ ENDIF
$ GOTO DP$Loop1
$ !
$DP$Done1:
$DP$Loop2:
$ busdev = F$DEVICE( "*", "BUS", , 2 ) - UNDERSCORE
$ IF ( busdev .EQS. "" ) THEN GOTO DP$Done2
$ IF ( F$EXTRACT( 0, 2, busdev ) .NES. "FG" ) THEN GOTO DP$Loop2
$ fcnode = F$GETDVI( busdev, "FC_NODE_NAME" )
$ fcport = F$GETDVI( busdev, "FC_PORT_NAME" )
$ IF ( fcport .EQS. fcnode )
$ THEN fcport = ""  ! collapse duplicate info
$      sep    = ""
$ ELSE sep    = SLASH
$ ENDIF
$ IF ( fcnode .NES. "" )
$ THEN wso F$FAO( "!#* !AS Fibre-Channel node/port: !AS !AS !AS", -
                   6, busdev, fcnode, sep , fcport )
$ ENDIF
$ GOTO DP$Loop2
$DP$Done2:
$ !
$ wso F$FAO( "!#*-", F$LENGTH( headln ) )
$ wso ""
$ !
$DP$Exit:
$ DCL$CALL DeleteGloSyms "DD$Disks"
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
