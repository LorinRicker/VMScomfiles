$ ! DISKLIMITS$REPORT.COM --                                        'F$VERIFY(0)'
$ !
$ ! Copyright © 2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ !  use: @DISKLIMITS$REPORT [disk[,disk]...]
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
$ VMS$ver  = F$EDIT(F$GETSYI("VERSION"),"TRIM")
$ minVMS73 = ( VMS$ver .GES. "V7.3" ) 
$ !
$ DL$Disks  == ""
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
$ THEN DL$Disks == P1
$ ELSE DCL$CALL DiscoverDisks DL$Disks "MNT,!SHDW_MEMBER"
$ ENDIF
$ !
$ devfldlen = 16
$ headfill  = 14
$ fldlen    = 18
$ clufldlen = 7
$ !
$ header = F$FAO( "!#* !AS !AS",  -
                  devfldlen+5, "cluster      maximum files    expansion limit", -
                  "  logical vol size       total blocks" )
$ headln = F$FAO( "-- Disk Limits !#*-", F$LENGTH( header ) - headfill )
$ !
$ wso F$FAO( "%!AS-I-LIMITS, Disk Limits on !AS", Fac, Node )
$ wso ""
$ wso header
$ wso headln
$ !
$ devcnt = 0
$DL$Loop:
$ dev = F$ELEMENT( devcnt, COMMA, DL$Disks )
$ IF ( dev .EQS. COMMA ) .OR. ( dev .EQS. "" ) THEN GOTO DL$Done
$ devcnt = devcnt + 1
$ !
$ nakeddev = dev - UNDERSCORE - alloclass - "''Node'$"           ! undecorate it...
$ IF F$GETDVI( dev, "MNT" )
$ THEN ! Full accounting for a mounted disk:
$      volnam = F$GETDVI( dev, "VOLNAM" )
$      cluster  = F$STRING( F$GETDVI( dev, "CLUSTER" ) )
$      cluslen  = F$LENGTH( cluster )
$      maxfiles = F$STRING( F$GETDVI( dev, "MAXFILES" ) )
$      maxblks  = F$STRING( F$GETDVI( dev, "MAXBLOCK" ) )
$      IF minVMS73
$      THEN ! these $GETDVI item-codes weren't available pre-V7.3:
$           expsize  = F$STRING( F$GETDVI( dev, "EXPSIZE" ) )
$           volsize  = F$STRING( F$GETDVI( dev, "VOLSIZE" ) )
$      ELSE expsize  = "n/a"
$           volsize  = "n/a"
$      ENDIF
$ ELSE ! The disk is online, but not currently mounted...
$      IF F$GETDVI( dev, "AVL" )
$      THEN cluster  = ""
$           maxfiles = ""
$           maxblks  = ""
$           expsize  = ""
$           volsize  = ""
$      ELSE !
$      ENDIF
$ ENDIF
$ !
$ DCL$CALL Thousands DL$expsize  "''expsize'"
$ DCL$CALL Thousands DL$maxfiles "''maxfiles'"
$ DCL$CALL Thousands DL$volsize  "''volsize'"
$ DCL$CALL Thousands DL$maxblks  "''maxblks'"
$ cluslen  = F$LENGTH( cluster )
$ maxflen  = F$LENGTH( DL$maxfiles )
$ expslen  = F$LENGTH( DL$expsize )
$ maxblen  = F$LENGTH( DL$maxblks )
$ volslen  = F$LENGTH( DL$volsize )
$ devl = F$LENGTH( dev )
$ wso F$FAO( "!3SL.!#* !AS !#* !AS !#* !AS !#* !AS !#* !AS !#* !AS", -
             devcnt, devfldlen-devl, dev, -
             clufldlen-cluslen, cluster,  -
             fldlen-maxflen, DL$maxfiles, -
             fldlen-expslen, DL$expsize,  -
             fldlen-volslen, DL$volsize,  -
             fldlen-maxblen, DL$maxblks )
$ GOTO DL$Loop
$ !
$DL$Done:
$ wso F$FAO( "!#*-", F$LENGTH( headln ) )
$ wso ""
$ !
$ DCL$CALL DeleteGloSyms "DL$Disks,DL$expsize,DL$maxfiles,DL$volsize,DL$maxblks"
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
