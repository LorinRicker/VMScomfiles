$ ! DISKINVENTORY$REPORT.COM --                                    'F$VERIFY(0)'
$ !
$ ! Copyright © 1999-2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ !  use: @DISKINVENTORY$REPORT [disk[,disk]...]
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
$ ON ERROR THEN GOTO Done
$ !
$ DI$Disks  == ""
$ wso        = "WRITE sys$output"
$ Fac        = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ Node       = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ COMMA      = ","
$ DOLLAR     = "$"
$ UNDERSCORE = "_"
$ !
$ alloclass = DOLLAR + F$STRING( F$GETSYI( "ALLOCLASS" ) ) + DOLLAR
$ !
$ IF ( P1 .NES. "" )
$ THEN DI$Disks == P1
$ ELSE DCL$CALL DiscoverDisks DI$Disks "MNT,SHDW_MEMBER"
$ ENDIF
$ !
$ devfldlen = 16
$ headfill  = 22
$ !
$ header = F$FAO( "!#* !AS !18AS !18AS  !7AS     !9AS !20AS",  -
                  devfldlen+5, "ODS", "logical", "vol-shadow", -
                  "cluster", "maxfiles", "characteristics" )
$ headln = F$FAO( "-- Disk Inventory !#*-", F$LENGTH( header ) - headfill )
$ !
$ wso F$FAO( "%!AS-I-DISKS, disks on !AS", Fac, Node )
$ wso ""
$ wso header
$ wso headln
$ !
$ devcnt = 0
$DI$Loop:
$ dev = F$ELEMENT( devcnt, COMMA, DI$Disks )
$ IF ( dev .EQS. COMMA ) .OR. ( dev .EQS. "" ) THEN GOTO DI$Done
$ devcnt = devcnt + 1
$ !
$ nakeddev = dev - UNDERSCORE - alloclass - "''Node'$"           ! undecorate it...
$ IF F$GETDVI( dev, "MNT" )
$ THEN ! Full accounting for a mounted disk:
$      IF F$GETDVI( dev, "ODS5" )
$      THEN odslvl = " :5"
$      ELSE odslvl = "2: "
$      ENDIF
$      volnam = F$GETDVI( dev, "VOLNAM" )
$      devlnm = F$TRNLNM( "DISK$''volnam'", "LNM$SYSTEM" )
$      IF ( devlnm .NES. "" )
$      THEN devlnm = "DISK$''volnam'"
$      ELSE devlnm = volnam
$      ENDIF
$      cluster  = F$STRING( F$GETDVI( dev, "CLUSTER" ) )
$      cluslen  = F$LENGTH( cluster )
$      maxfiles = F$STRING( F$GETDVI( dev, "MAXFILES" ) )
$      maxflen  = F$LENGTH( maxfiles )
$      IF ( .NOT. F$GETDVI( dev, "NOHIGHWATER" ) )
$      THEN char = "hi-H2O"
$      ELSE char = ""
$      ENDIF
$      IF ( F$GETDVI( dev, "ERASE_ON_DELETE" ) )
$      THEN eod = "erase-on-del"
$           IF ( char .EQS. "" )
$           THEN char = eod
$           ELSE char = char + COMMA + eod
$           ENDIF
$      ENDIF
$      shadow = ""
$      IF ( F$GETDVI( dev, "SHDW_MASTER" ) )
$      THEN shadow = "VolShadow Master"
$      ELSE IF ( F$GETDVI( dev, "SHDW_MEMBER" ) )
$           THEN shadow   = "member of " + F$GETDVI( dev, "SHDW_MASTER_NAME" ) - UNDERSCORE
$                cluster  = ""
$                cluslen  = 0
$                maxfiles = ""
$                maxflen  = 0
$                char     = ""
$           ENDIF
$      ENDIF
$ ELSE ! The disk is online, but not currently mounted...
$      IF F$GETDVI( dev, "AVL" )
$      THEN odslvl   = "online"
$           devlnm   = ""
$           shadow   = ""
$           cluster  = ""
$           cluslen  = 0
$           maxfiles = ""
$           maxflen  = 0
$           char     = ""
$      ELSE !
$      ENDIF
$ ENDIF
$ devl = F$LENGTH( dev )
$ wso F$FAO( "!3SL.!#* !AS !AS !18AS !18AS  !#* !AS !#* !AS  !20AS", -
             devcnt, devfldlen-devl, dev, odslvl, devlnm, shadow, -
             7-cluslen, cluster, 12-maxflen, maxfiles, char )
$ GOTO DI$Loop
$ !
$DI$Done:
$ wso F$FAO( "!#*-", F$LENGTH( headln ) )
$ wso ""
$ !
$ DCL$CALL DeleteGloSyms "DI$Disks"
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
