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
$ !  use: @DISKINVENTORY$REPORT [/OUTPUT=DI$<ClusterAlias>.csv] [disk[,disk]...]
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
$ DI$Disks == ""
$ wso       = "WRITE sys$output"
$ Fac       = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ Node      = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ Clu       = F$EXTRACT(0,4,Node)
$ COMMA     = ","
$ DOLLAR    = "$"
$ !
$ wso F$FAO( "%!AS-I-DISKS, disks on !AS", Fac, Node )
$ !
$ alloclass = DOLLAR + F$STRING( F$GETSYI( "ALLOCLASS" ) ) + DOLLAR
$ !
$ IF ( P1 .NES. "" )
$ THEN DI$Disks == P1
$ ELSE DCL$CALL DiscoverDisks DI$Disks "MNT,SHDW_MEMBER"
$ ENDIF
$ !
$ devcnt = 0
$DI$Loop:
$ dev = F$ELEMENT( devcnt, COMMA, DI$Disks )
$ IF ( dev .EQS. COMMA ) .OR. ( dev .EQS. "" ) THEN GOTO DI$Done
$ devcnt = devcnt + 1
$ !
$ nakeddev = dev - "_" - alloclass - "''Node'$"           ! undecorate it...
$ IF F$GETDVI( dev, "MNT" )
$ THEN ! Full accounting for a mounted disk:
$ ELSE ! The disk is online, but not currently mounted...
$      IF F$GETDVI( dev, "AVL" )
$      THEN
$      ELSE
$      ENDIF
$ ENDIF
$ wso F$FAO( "!3SL. disk: !AS", devcnt, dev )
$ GOTO DI$Loop
$ !
$DI$Done:
$ DCL$CALL DeleteGloSyms "DI$Disks"
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$Ctrl_Y:
$ RETURN %X2C
