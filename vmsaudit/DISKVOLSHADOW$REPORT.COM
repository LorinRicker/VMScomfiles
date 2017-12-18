$ ! DISKVOLSHADOW$REPORT.COM --                                    'F$VERIFY(0)'
$ !
$ ! Copyright © 2017-2018 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ !  use: @DISKVOLSHADOW$REPORT [disk[,disk]...]
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
$ ON ERROR THEN GOTO DI$Done
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
$ UNDERSCORE = "_"
$ PERCENT    = "%"
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
$ headfill  = 20
$ !
$ header = F$FAO( "!#* !22AS !18AS !48AS",  -
                  devfldlen+5, "logical", "vol-shadow", -
                  "attributes" )
$ headln = F$FAO( "-- Volumes !#*-", F$LENGTH( header ) - headfill )
$ !
$ wso F$FAO( "%!AS-I-VOLSHADOW, Shadow Set Volume Attributes on !AS", Fac, Node )
$ wso ""
$ wso header
$ wso headln
$ !
$ devcnt = 0
$DI$Loop:
$ dev = F$ELEMENT( devcnt, COMMA, DD$Disks )
$ IF ( dev .EQS. COMMA ) .OR. ( dev .EQS. "" ) THEN GOTO DI$Done
$ devcnt = devcnt + 1
$ !
$ nakeddev = dev - UNDERSCORE - alloclass - "''Node'$"           ! undecorate it...
$ IF F$GETDVI( dev, "MNT" )
$ THEN ! Full accounting for a mounted disk:
$      volnam = F$GETDVI( dev, "VOLNAM" )
$      devlnm = F$TRNLNM( "DISK$''volnam'", "LNM$SYSTEM" )
$      IF ( devlnm .NES. "" )
$      THEN devlnm = "DISK$''volnam'"
$      ELSE devlnm = volnam
$      ENDIF
$      attr = ""
$      shadow = "Just a disk"
$      IF ( F$GETDVI( dev, "SHDW_MASTER" ) )
$      THEN shadow   = "Virt/Shadow Set"
$           master   = F$GETDVI( dev, "SHDW_MASTER_MBR" ) - UNDERSCORE
$           mbrcount = F$STRING( F$GETDVI( dev, "SHDW_MBR_COUNT" ) ) -
                     + " of " + F$STRING( F$GETDVI( dev, "SHDW_DEVICE_COUNT" ) )
$           IF ( F$GETDVI( dev, "SHDW_MINIMERGE_ENABLE" ) )
$           THEN hbmm = " HBMM"
$           ELSE hbmm = ""
$           ENDIF
$           attr = "members " + mbrcount + COMMA + " master " + master + " " + hbmm
$      ELSE IF ( F$GETDVI( dev, "SHDW_MEMBER" ) )
$           THEN shadow   = "member of " + F$GETDVI( dev, "SHDW_MASTER_NAME" ) - UNDERSCORE
$                master   = ""
$                mbrsite  = F$GETDVI( dev, "SHDW_SITE" )
$                IF ( mbrsite .GT. 0 )
$                THEN mbrsite = ", site " + F$STRING( mbrsite )
$                ELSE mbrsite = ""
$                ENDIF
$                copypct  = F$GETDVI( dev, "SHDW_MBR_COPY_DONE" )
$                IF ( copypct .EQ. 100 )
$                THEN copypct = F$STRING( copypct ) + PERCENT
$                ELSE copypct = "copy/merging: " + F$STRING( copypct ) + PERCENT -
                              + " on " + F$GETDVI( dev, "SHDW_COPIER_NODE" )
$                ENDIF
$                attr = copypct + " merged" + mbrsite
$           ENDIF
$      ENDIF
$ ELSE ! The disk is online, but not currently mounted...
$      IF F$GETDVI( dev, "AVL" )
$      THEN odslvl   = "online"
$           devlnm   = ""
$           shadow   = ""
$           attr     = ""
$      ENDIF
$ ENDIF
$ !
$ DCL$CALL Thousands DI$maxfiles "''maxfiles'"
$ maxflen  = F$LENGTH( DI$maxfiles )
$ devl = F$LENGTH( dev )
$ wso F$FAO( "!3SL.!#* !AS !22AS !18AS !48AS", -
             devcnt, devfldlen-devl, dev, devlnm, -
             shadow, attr )
$ GOTO DI$Loop
$ !
$DI$Done:
$ wso F$FAO( "!#*-", F$LENGTH( headln ) )
$ wso ""
$ !
$ DCL$CALL DeleteGloSyms "DD$Disks,DI$maxfiles"
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
