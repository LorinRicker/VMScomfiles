$ ! FILE$FINDVERSIONS.COM --                                       'F$VERIFY(0)'
$ !
$ ! Copyright © 2014-2016 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ !   Performs a comprehensive audit of a VMS (OpenVMS) System using
$ !   administrative (system management) level commands and utilties.
$ !   Outputs report to a file (for review, analysis and archival) or
$ !   directly to screen (for development checkout).
$ !
$ ! usage:  @FILE$FINDVERSIONS [ disk_device[,...] ] [ version_no ] [ NOTYPE ]
$ !
$ ! where: P1 -- Disk device list to scan for files over the specified
$ !              or default version limit; default is SYS$SYSDEVICE;
$ !              specify more than one device as a comma-separated list:
$ !              e.g.: "DISK$DATA1,DSA200:,SYS$SYSDEVICE"
$ !        P2 -- Version number limit, find file versions at
$ !              or greater than this one; default is ";32700"
$ !
$ScanDevice: SUBROUTINE
$ ! P1 = Disk device to scan
$ ! P2 = File version limit
$ ! P3 = Temporary/working file
$ !
$ ON ERROR THEN GOTO SD_CtrlY
$ ON CONTROL_Y THEN GOTO SD_CtrlY
$ !
$ dev      = P1
$ filemaxv = F$INTEGER( P2 )
$ tmpfspec = F$EDIT( P3, "UPCASE" )
$ outfspec = "''DD'''Fac'_''dev'.REPORT"
$ !
$ wso F$FAO( "%!AS-I-WAIT, directory of !AS to !AS ...", -
              Fac, dev, tmpfspec )
$ DIRECTORY /OUTPUT='tmpfspec' /COLUMN=1 /NOHEADER /NOTRAILER 'dev':[000000...]*.*;0
$ !
$ OPEN /READ  /ERROR=ReadErr  in  'tmpfspec'
$ OPEN /WRITE /ERROR=WriteErr out 'outfspec'
$ !
$ MaxFS  = ""
$ MaxV   = 0
$ fcount = 0
$ !
$ hdr  = F$FAO( "Disk Device !AS", dev )
$ hdrl = F$LENGTH( hdr )
$ now  = F$TIME()
$ nowl = F$LENGTH( now )
$ !
$ wso F$FAO( "%!AS-I-WAIT, scanning for file versions > ;!ZL ...", -
              Fac, filemaxv )
$ !
$SDLoop:
$ READ /END_OF_FILE=Cleanup in record
$ fvers = F$PARSE( record, , , "VERSION", "SYNTAX_ONLY") - SEMICOLON
$ fvers = F$INTEGER( fvers )
$ fs    = F$FAO( "!4* !AS!AS!AS!AS" -
                 , F$PARSE( record, , , "DIRECTORY", "SYNTAX_ONLY" ) -
                 , F$PARSE( record, , , "NAME", "SYNTAX_ONLY" )      -
                 , F$PARSE( record, , , "TYPE", "SYNTAX_ONLY" )      -
                 , F$PARSE( record, , , "VERSION", "SYNTAX_ONLY" ) )
$ IF ( fvers .GE. filemaxv )
$ THEN IF ( fcount .EQ. 0 )
$      THEN ! write this output file's header information...
$           WRITE out ""
$           WRITE out F$FAO( "!AS!#* !AS", hdr, 80 - hdrl - nowl, now )
$           WRITE out ""
$      ENDIF
$      WRITE out fs
$      fcount = fcount + 1
$ ENDIF
$ IF ( fvers .GT. MaxV )
$ THEN MaxV  = fvers
$      MaxFS = F$EDIT( fs, "TRIM" )
$ ENDIF
$ GOTO SDLoop
$ !
$Cleanup:
$ elapsed = F$DELTA_TIME( now, F$TIME(), "ASCTIM" )
$ ! write output file's trailer information and close it...
$ IF ( fcount .GT. 0 )
$ THEN WRITE out ""
$      WRITE out F$FAO( "Total files found having version >= ;!ZL: !ZL", filemaxv, fcount )
$ ELSE WRITE out F$FAO( "!AS!#* !AS", hdr, 80 - hdrl - nowl, now )
$      WRITE out ""
$      WRITE out F$FAO( "No files found having version >= ;!ZL", filemaxv )
$ ENDIF
$ WRITE out ""
$ WRITE out F$FAO( "!6* Maximum version found: ;!ZL", MaxV )
$ WRITE out F$FAO( "!19* for file: !AS", MaxFS )
$ WRITE out ""
$ WRITE out F$FAO( "%!AS-I-ELAPSED_TIME, !AS", Fac, elapsed )
$ WRITE out ""
$ !
$ CLOSE out
$ CLOSE in
$ IF ( F$SEARCH("''outfspec';-1") .NES. "" ) THEN PURGE /NOLOG /KEEP=2 'outfspec'
$ IF typereport THEN TYPE /PAGE 'outfspec'
$ EXIT 1
$ !
$ReadErr:
$ wso "%''Fac'-E-OPENIN, error opening input file ''tmpfspec'"
$ EXIT %X2C
$WriteErr:
$ wso "%''Fac'-E-OPENOUT, error opening output file ''outfspec'"
$ EXIT %X2C
$SD_CtrlY:
$ EXIT %X2C
$ ENDSUBROUTINE  ! ScanDevice
$ !
$ !
$ !
$Main:
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOTO Done
$ !
$ Proc = F$ENVIRONMENT("PROCEDURE")
$ Fac  = F$PARSE( Proc, , , "NAME", "SYNTAX_ONLY" )
$ DD   = F$PARSE( Proc, , , "DEVICE", "SYNTAX_ONLY" ) -
       + F$PARSE( Proc, , , "DIRECTORY", "SYNTAX_ONLY" )
$ !
$ tmpfspec = "sys$scratch:" + Fac + ".tmp"
$ !
$ COMMA     = ","
$ COLON     = ":"
$ SEMICOLON = ";"
$ wso       = "WRITE sys$output"
$ !
$ DIRECTORY = "DIRECTORY"  ! override any global symbol...
$ !
$ ! Principle of Least Privilege:
$ Prv = F$SETPRV("READALL")
$ !
$ IF ( P1 .NES. "" )
$ THEN Devices = P1
$ ELSE Devices = "SYS$SYSDEVICE"
$ ENDIF
$ !
$ IF ( P2 .NES. "" )
$ THEN filevmax = P2
$ ELSE filevmax = ";32700"
$ ENDIF
$ filevmax = filevmax - SEMICOLON
$ !
$ typereport = ( F$EXTRACT(0,4,P3) .NES. "NOTY" )
$ !
$ devcount = 0
$ !
$Loop0:
$ dev = F$ELEMENT( devcount, COMMA, Devices )
$ IF ( dev .EQS. COMMA ) THEN GOTO Done
$ dev = F$EDIT( dev, "TRIM,UPCASE" ) - COLON
$ CALL ScanDevice "''dev'" "''filevmax'" "''tmpfspec'"
$ devcount = devcount + 1
$ GOTO Loop0
$ !
$Done:
$ SET NOON
$ ! cleanup
$ IF ( F$SEARCH(tmpfspec) .NES. "" ) THEN DELETE /NOLOG 'tmpfspec';*
$ !
$ ! Principle of Least Privilege:
$ IF ( F$TYPE(Prv) .EQS. "STRING" ) THEN Prv = F$SETPRV(Prv)
$ !
$ EXIT 1   ! 'F$VERIFY(0)'
$ !
