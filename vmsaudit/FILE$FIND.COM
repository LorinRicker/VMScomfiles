$ ! FILE$FIND.COM --                                               'F$VERIFY(0)'
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
$ ! usage:  @FILE$FIND [ disk_device[,...] ] -
$ !                    [ VERSION | SIZE ]    -
$ !                    [ minimum_size ]      -
$ !                    [ NOTYPE ]
$ !
$ ! where: P1 -- Disk device list to scan for files over the specified
$ !              or default version limit; default is SYS$SYSDEVICE;
$ !              specify more than one device as a comma-separated list:
$ !              e.g.: "DISK$DATA1,DSA200:,SYS$SYSDEVICE"
$ !        P2 -- Scan/search target: VERSIONS or SIZE (>= P3)
$ !        P3 -- VERSIONS: Minimum file version to list
$ !              SIZE:     Minimum file size to list, in blocks
$ !        P4 -- NOTYPE: just scan & create output file, don't TYPE/PAGE it
$ !
$Cmd$Parse: SUBROUTINE
$ ! P1: command to parse
$ ! P2: global symbol to receive answer
$ ! P3: default command
$ ! P4: command-set ("C1|C2[|Cn...]") -- options must be same-length fields
$ !     or "@symbol" where "symbol" contains command-set (this accommodates
$ !     very long command-sets, > 255 characters)
$ ! P5: command separator
$ IF P1 .EQS. "" THEN P1 = P3
$ IF P2 .EQS. "" THEN P2 = "Cmd"
$ IF P5 .EQS. "" THEN P5 = "|"
$ IF F$EXTRACT(0,1,P4) .EQS. "@"
$ THEN sym = P4 - "@"
$      P4 = 'sym'
$ ENDIF
$ P4 = F$EDIT(P4,"UPCASE")
$ S  = F$LOCATE(P5,P4) + 1               !Determine field length
$ P4 = P5 + P4                           !Add separator to front of list...
$ T  = P5 + F$EDIT(P1,"COLLAPSE,UPCASE") !...and to target
$ L  = F$LOCATE( F$EDIT(T,"COLLAPSE,UPCASE"), P4 )      !Test substring
$ IF ( L .LT. F$LENGTH(P4) ) .AND. ( L-(L/S)*S .EQ. 0 ) !Found?
$ THEN L = ( ( L + 1 ) / S ) + 1                        !Calculate offset
$      !Return both the full command and its element #:
$      'P2'     == F$EDIT( F$ELEMENT(L,P5,P4), "COLLAPSE" )
$      'P2'_Num == L  !1-based: 1=first command, 2=second, ...
$      EXIT 1
$ ELSE 'P2'     == "$Err$"
$      'P2'_Num == -1
$      WRITE sys$output "\''P1'\ (expecting: ''F$EDIT(P4,"COLLAPSE")')"
$      EXIT 229522  !%DCL-E-IVVERB, unrecognized command verb
$ ENDIF
$ ENDSUBROUTINE
$ !
$MakeDiskList: SUBROUTINE
$ ON ERROR THEN GOTO MDLEnd
$ FF$DiskList == ""
$MDL0:
$ dsk = F$DEVICE( , "DISK" )
$ IF ( dsk .EQS. "" ) THEN GOTO MDLEnd
$ IF ( .NOT. F$GETDVI( dsk, "MNT" ) )     -  ! not mounted?
  .OR. ( F$GETDVI( dsk, "FOR" ) )         -  ! mounted foreign?
  .OR. ( F$GETDVI( dsk, "SWL" ) )         -  ! software-locked?
  .OR. ( F$GETDVI( dsk, "SHDW_MEMBER" ) ) -  ! a shadow-set member (not the shadow-set itself)?
  THEN GOTO MDL0                             ! ... skip it
$ dsk = dsk - UNDERSCORE
$ IF ( FF$DiskList .NES. "" )
$ THEN FF$DiskList == FF$DiskList + COMMA + dsk
$ ELSE FF$DiskList == dsk
$ ENDIF
$ GOTO MDL0
$MDLEnd:
$ IF Verbose
$ THEN wso F$FAO( "%!AS-I-ECHO, FF$DiskList ==", Fac )
$      wso F$FAO( "  ""!AS""", FF$DiskList )
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! MakeDiskList
$ !
$ !
$ !
$ScanSIZE: SUBROUTINE
$ ! P1 = Disk device to scan
$ ! P2 = File minimum size
$ ! P3 = (unused)
$ !
$ ON ERROR THEN GOTO SS_CtrlY
$ ON CONTROL_Y THEN GOTO SS_CtrlY
$ !
$ dev         = P1
$ fileminsize = F$INTEGER( P2 )
$ outfspec    = "''DD'''Fac'''FF$Cmd'_''dev'.REPORT"
$ !
$ wso F$FAO( "%!AS-I-WAIT, directory of !AS to !AS ...", -
              Fac, dev, outfspec )
$ DIRECTORY 'dev':[000000...]*.*       -
    /SELECT=SIZE=MINIMUM='fileminsize' -
    /SIZE=ALL /OUTPUT='outfspec'       -
    /WIDTH=(SIZE=18,FILENAME=60)       -
    /COLUMN=1 /DATE /HEADER /NOTRAILER 
$ !
$ CALL Report "''outfspec'" "''typereport'"
$ EXIT 1
$ !
$SS_CtrlY:
$ EXIT %X2C
$ ENDSUBROUTINE  ! ScanSIZE
$ !
$ !
$ !
$ScanVERSIONS: SUBROUTINE
$ ! P1 = Disk device to scan
$ ! P2 = File minimum version limit
$ ! P3 = Temporary/working filespec
$ !
$ ON ERROR THEN GOTO SV_CtrlY
$ ON CONTROL_Y THEN GOTO SV_CtrlY
$ !
$ dev            = P1
$ fileminversion = F$INTEGER( P2 )
$ tmpfspec       = F$EDIT( P3, "UPCASE" )
$ outfspec       = "''DD'''Fac'''FF$Cmd'_''dev'.REPORT"
$ !
$ wso F$FAO( "%!AS-I-WAIT, directory of !AS to !AS ...", -
              Fac, dev, tmpfspec )
$ DIRECTORY 'dev':[000000...]*.*             -
    /SELECT=VERSION=MINIMUM='fileminversion' -
    /OUTPUT='tmpfspec'                       -
    /COLUMN=1 /DATE /NOHEADER /NOTRAILER 
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
              Fac, fileminversion )
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
$ IF ( fvers .GE. fileminversion )
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
$      WRITE out F$FAO( "Total files found having version >= ;!ZL: !ZL", fileminversion, fcount )
$ ELSE WRITE out F$FAO( "!AS!#* !AS", hdr, 80 - hdrl - nowl, now )
$      WRITE out ""
$      WRITE out F$FAO( "No files found having version >= ;!ZL", fileminversion )
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
$ CALL Report "''outfspec'" "''typereport'"
$ EXIT 1
$ !
$ReadErr:
$ wso "%''Fac'-E-OPENIN, error opening input file ''tmpfspec'"
$ EXIT %X2C
$WriteErr:
$ wso "%''Fac'-E-OPENOUT, error opening output file ''outfspec'"
$ EXIT %X2C
$SV_CtrlY:
$ EXIT %X2C
$ ENDSUBROUTINE  ! ScanVERSIONS
$ !
$Report: SUBROUTINE
$ IF ( F$SEARCH("''P1';-1") .NES. "" ) THEN PURGE /NOLOG /KEEP=2 'P1'
$ IF P2 THEN TYPE /PAGE 'P1'
$ EXIT 1
$ ENDSUBROUTINE  ! Report
$ !
$ !
$ !
$Main:
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOTO Done
$ !
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ !
$ Proc = F$ENVIRONMENT("PROCEDURE")
$ Fac  = F$PARSE( Proc, , , "NAME", "SYNTAX_ONLY" )
$ DD   = F$PARSE( Proc, , , "DEVICE", "SYNTAX_ONLY" ) -
       + F$PARSE( Proc, , , "DIRECTORY", "SYNTAX_ONLY" )
$ !
$ COMMA      = ","
$ COLON      = ":"
$ SEMICOLON  = ";"
$ UNDERSCORE = "_"
$ wso        = "WRITE sys$output"
$ !
$ DIRECTORY  = "DIRECTORY"  ! override any global symbol...
$ !
$ ! Principle of Least Privilege:
$ Prv = F$SETPRV("READALL")
$ !
$ IF ( P1 .NES. "" )
$ THEN FF$DiskList == P1
$ ELSE CALL MakeDiskList
$      wso F$FAO( "%!AS-I-ALLDISKS, scanning !AS", Fac, FF$DiskList )
$ ENDIF
$ !
$ CALL Cmd$Parse "''P2'" "FF$Cmd" "VERSIONS" "VERSIONS|SIZE    "
$ !
$ tmpfspec   = "sys$scratch:" + Fac + FF$Cmd + ".tmp"
$ IF ( P3 .NES. "" )
$ THEN fileminimum = P3
$ ELSE IF ( FF$Cmd .EQS. "VERSIONS" )
$      THEN fileminimum = ";32700"    ! default for VERSIONS
$      ELSE fileminimum = "10000"     ! default for SIZE
$      ENDIF
$ ENDIF
$ fileminimum = fileminimum - SEMICOLON
$ !
$ typereport = ( F$EXTRACT(0,4,P4) .NES. "NOTY" )
$ !
$ devcount = 0
$ !
$Loop0:
$ dev = F$ELEMENT( devcount, COMMA, FF$DiskList )
$ IF ( dev .EQS. COMMA ) THEN GOTO Done
$ dev = F$EDIT( dev, "TRIM,UPCASE" ) - COLON
$ IF .NOT. Verbose
$ THEN CALL Scan'FF$Cmd' "''dev'" "''fileminimum'" "''tmpfspec'"
$ ELSE wso F$FAO( "%!AS-I-ECHO, CALL Scan''FF$Cmd' ""!AS"" ""!AS""", -
                  Fac, dev, fileminimum, tmpfspec )
$ ENDIF
$ devcount = devcount + 1
$ GOTO Loop0
$ !
$Done:
$ SET NOON
$ ! cleanup
$ IF ( F$TYPE(FF$Cmd)      .NES. "" ) THEN DELETE /SYMBOL /GLOBAL FF$Cmd
$ IF ( F$TYPE(FF$DiskList) .NES. "" ) THEN DELETE /SYMBOL /GLOBAL FF$DiskList
$ IF ( tmpfspec .NES. "" ) -
  THEN IF ( F$SEARCH(tmpfspec)  .NES. "" ) THEN DELETE /NOLOG 'tmpfspec';*
$ !
$ ! Principle of Least Privilege:
$ IF ( F$TYPE(Prv) .EQS. "STRING" ) THEN Prv = F$SETPRV(Prv)
$ !
$ EXIT 1   ! 'F$VERIFY(0)'
$ !
