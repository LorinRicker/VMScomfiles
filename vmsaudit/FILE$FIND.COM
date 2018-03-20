$ ! FILE$FIND.COM --                                               'F$VERIFY(0)'
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
$ !   Performs a comprehensive audit of a VMS (OpenVMS) System using
$ !   administrative (system management) level commands and utilties.
$ !   Outputs report to a file (for review, analysis and archival) or
$ !   directly to screen (for development checkout).
$ !
$ ! usage:  @FILE$FIND [ VERSIONS (D) | SIZE              -
$ !                      | AGED | BEFORE | SINCE | AFTER  -
$ !                      | MOVE | NOBACKUP | VERLIMIT     -
$ !                      | BIGDIRS | FILECOUNT |          -
$ !                      | HELP ]                         -
$ !                    [ disk_device[,...] ]              -
$ !                    [ scan_parameter ]                 -
$ !                    [ NOTYPE ]
$ !
$ ! where: P1 -- Scan/search action: VERSIONS, SIZE,
$ !                                  AGED or BEFORE,
$ !                                  SINCE or AFTER,
$ !                                  MOVE, NOBACKUP,
$ !                                  VERLIMIT, BIGDIRS,
$ !                                  FILECOUNT,
$ !                                  HELP
$ !        P2 -- Disk device list to scan for files over the specified
$ !              or default version limit; default is SYS$SYSDEVICE;
$ !              specify more than one device as a comma-separated list:
$ !              e.g.: "DISK$DATA1,DSA200:,SYS$SYSDEVICE"
$ !        P3 -- for VERSIONS:       The minimum file version to list
$ !                  SIZE:           The minimum file size to list, in blocks
$ !                  BIGDIRS:        The threshold size for "big" directories
$ !                  AGED or BEFORE: Files created before this date/time
$ !                  AFTER or SINCE: Files created after this date/time
$ !        P4 -- NOTYPE: just scan & create output file, don't TYPE/PAGE it
$ !
$ScanFILECOUNT:  SUBROUTINE
$ ! P1 = Disk device to scan
$ ! P2 = (unused)
$ ! P3 = (unused)
$ ! P4 = Nodename
$ !
$ ON CONTROL_Y THEN GOSUB FCCtrl_Y
$ dev         = P1
$ node        = P4
$ streamid    = 1
$ fcount      = 0
$ outfspec    = "''DD'''Fac'_FILECOUNT_''dev'.REPORT"
$ !
$ wso ""
$ wso F$FAO( "%!AS-I-WAIT, file-count scan of !AS::!AS!/  to !AS ...", -
              Fac, node, dev, outfspec )
$ DEFINE sys$output 'outfspec'
$ ON ERROR THEN GOTO SFCDone
$ !
$SFCLoop:
$ f = F$SEARCH( "''dev':[*...]*.*;*", streamid )
$ IF ( f .EQS. "" ) THEN GOTO SFCEndLoop
$ fcount = fcount + 1
$ GOTO SFCLoop
$SFCEndLoop:
$ !
$ maxfiles = F$GETDVI( dev, "MAXFILES" )
$ fcpercent = F$STRING( ( fcount * 100 ) / maxfiles )
$ DCL$CALL Thousands FF$FCount "''fcount'"
$ DCL$CALL Thousands FF$MaxFiles "''F$STRING( maxfiles )'"
$ msg  = F$FAO( "%!AS-I-COUNT,", Fac )
$ msgL = F$LENGTH( msg ) + 1
$ wso ""
$ wso F$FAO( "!AS counted !AS files", msg, FF$FCount )
$ wso F$FAO( "!#* MaxFiles for !AS is !AS", -
             msgL, dev, FF$MaxFiles )
$ wso F$FAO( "!#* current file-count is ~!AS% of the maximum allowed", -
             msgL, fcpercent )
$ wso ""
$ !
$SFCDone:
$ DEASSIGN sys$output
$ CALL Report "''outfspec'" "''typereport'"
$ EXIT 1
$ !
$FCCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! ScanFILECOUNT
$ !
$ScanBIGDIRS: SUBROUTINE
$ ! P1 = Disk device to scan
$ ! P2 = .DIR-size threshold
$ ! P3 = (unused)
$ ! P4 = Nodename
$ !
$ ON CONTROL_Y THEN GOTO SBD_CtrlY
$ !
$ dev         = P1
$ threshold   = F$INTEGER( P2 )
$ node        = P4
$ streamid    = 1
$ fcount      = 0
$ outfspec    = "''DD'''Fac'_BIGDIRS_''dev'.REPORT"
$ !
$ wso ""
$ wso F$FAO( "%!AS-I-WAIT, !AS big-directories scan of !AS::!AS!/  threshold: !ZL!/  to !AS ...", -
              Fac, attr, node, dev, threshold, outfspec )
$ DEFINE sys$output 'outfspec'
$ ON ERROR THEN GOTO SBDDone
$ !
$SBDLoop:
$ f = F$SEARCH( "''dev':[*...]*.DIR;1", streamid )
$ IF ( f .EQS. "" ) THEN GOTO SBDEndLoop
$ fsize = F$FILE_ATTRIBUTE( f, "EOF" )
$ IF ( fsize .GE. threshold )
$ THEN wso F$FAO( "!AS directory is big/exceeds-threshold, size: !ZL", f, fsize )
$      fcount = fcount + 1
$ ENDIF
$ GOTO SBDLoop
$SBDEndLoop:
$ !
$ wso ""
$ wso F$FAO( "%!AS-I-COUNT, found !ZL qualifying file!%S", Fac, fcount )
$ wso ""
$ !
$SBDDone:
$ DEASSIGN sys$output
$ CALL Report "''outfspec'" "''typereport'"
$ EXIT 1
$ !
$SBD_CtrlY:
$ EXIT %X2C
$ ENDSUBROUTINE  ! ScanBIGDIRS
$ !
$ !
$ !
$ScanFILEATTR: SUBROUTINE
$ ! P1 = Disk device to scan
$ ! P2 = Datetime since/after
$ ! P3 = (unused)
$ ! P4 = Nodename
$ ! P5 = File attribute
$ !
$ ON CONTROL_Y THEN GOTO SFA_CtrlY
$ !
$ dev         = P1
$ node        = P4
$ attr        = P5
$ streamid    = 1
$ fcount      = 0
$ outfspec    = "''DD'''Fac'_''attr'_''dev'.REPORT"
$ !
$ wso ""
$ wso F$FAO( "%!AS-I-WAIT, !AS file attribute scan of !AS::!AS!/  to !AS ...", -
              Fac, attr, node, dev, outfspec )
$ DEFINE sys$output 'outfspec'
$ ON ERROR THEN GOTO SFADone
$ !
$SFALoop:
$ f = F$SEARCH( "''dev':[*...]*.*;0", streamid )
$ IF ( f .EQS. "" ) THEN GOTO SFAEndLoop
$ fattr = F$STRING( F$FILE_ATTRIBUTE( f, attr ) )
$ GOTO sfa_'attr'
$sfa_VERLIMIT:
$ IF ( fattr .NES. "32767" )    ! "32767" means no version limit set, don't report those
$ THEN wso F$FAO( "!AS has version-limit !AS", f, fattr )
$      fcount = fcount + 1
$ ENDIF
$ GOTO SFALoop
$sfa_MOVE:
$ IF ( .NOT. Fattr )  ! "TRUE" means file is movable, defraggable, don't report those
$ THEN wso F$FAO( "!AS is set NO!AS", f, attr )
$      fcount = fcount + 1
$ ENDIF
$ GOTO SFALoop
$sfa_NOBACKUP:
$ IF ( fattr )        ! "TRUE" means file is set /NOBACKUP, report these
$ THEN wso F$FAO( "!AS is set !AS", f, attr )
$      fcount = fcount + 1
$ ENDIF
$ GOTO SFALoop
$SFAEndLoop:
$ !
$ wso ""
$ wso F$FAO( "%!AS-I-COUNT, found !ZL qualifying file!%S", Fac, fcount )
$ wso ""
$ !
$SFADone:
$ DEASSIGN sys$output
$ CALL Report "''outfspec'" "''typereport'"
$ EXIT 1
$ !
$SFA_CtrlY:
$ EXIT %X2C
$ ENDSUBROUTINE  ! ScanFILEATTR
$ !
$ !
$ !
$ScanSINCE: SUBROUTINE
$ ! P1 = Disk device to scan
$ ! P2 = Datetime since/after
$ ! P3 = (unused)
$ ! P4 = Nodename
$ !
$ ON CONTROL_Y THEN GOTO SA_CtrlY
$ !
$ dev         = P1
$ node        = P4
$ outfspec    = "''DD'''Fac'''FF$Cmd'_''node'_''dev'.REPORT"
$ !
$ wso F$FAO( "%!AS-I-WAIT, directory of !AS::!AS to !AS ...", -
              Fac, node, dev, outfspec )
$ DIRECTORY 'dev':[000000...]*.* -
    /SINCE="''P2'" -
    /SIZE=ALL /OUTPUT='outfspec' -
    /WIDTH=(SIZE=18,FILENAME=60) -
    /COLUMN=1 /DATE /HEADER /NOTRAILER 
$ !
$ CALL Report "''outfspec'" "''typereport'"
$ EXIT 1
$ !
$SA_CtrlY:
$ EXIT %X2C
$ ENDSUBROUTINE  ! ScanSINCE
$ !
$ !
$ !
$ScanBEFORE: SUBROUTINE
$ ! P1 = Disk device to scan
$ ! P2 = Datetime before
$ ! P3 = (unused)
$ ! P4 = Nodename
$ !
$ ON CONTROL_Y THEN GOTO SB_CtrlY
$ !
$ dev         = P1
$ node        = P4
$ outfspec    = "''DD'''Fac'''FF$Cmd'_''node'_''dev'.REPORT"
$ !
$ wso F$FAO( "%!AS-I-WAIT, directory of !AS::!AS to !AS ...", -
              Fac, node, dev, outfspec )
$ DIRECTORY 'dev':[000000...]*.* -
    /BEFORE="''P2'" -
    /SIZE=ALL /OUTPUT='outfspec' -
    /WIDTH=(SIZE=18,FILENAME=60) -
    /COLUMN=1 /DATE /HEADER /NOTRAILER 
$ !
$ CALL Report "''outfspec'" "''typereport'"
$ EXIT 1
$ !
$SB_CtrlY:
$ EXIT %X2C
$ ENDSUBROUTINE  ! ScanBEFORE
$ !
$ !
$ !
$ScanSIZE: SUBROUTINE
$ ! P1 = Disk device to scan
$ ! P2 = File minimum size
$ ! P3 = (unused)
$ ! P4 = Nodename
$ !
$ ON CONTROL_Y THEN GOTO SS_CtrlY
$ !
$ dev         = P1
$ node        = P4
$ fileminsize = F$INTEGER( P2 )
$ outfspec    = "''DD'''Fac'''FF$Cmd'_''node'_''dev'.REPORT"
$ !
$ wso F$FAO( "%!AS-I-WAIT, directory of !AS::!AS to !AS ...", -
              Fac, node, dev, outfspec )
$ DIRECTORY 'dev':[000000...]*.* -
    /SELECT=SIZE=MINIMUM='fileminsize' -
    /SIZE=ALL /OUTPUT='outfspec' -
    /WIDTH=(SIZE=18,FILENAME=60) -
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
$ ! P4 = Nodename
$ !
$ ON CONTROL_Y THEN GOTO SV_CtrlY
$ !
$ dev            = P1
$ node           = P4
$ FMVtmp         = P2
$ FileMinVersion = F$INTEGER( P2 )
$ tmpfspec       = F$EDIT( P3, "UPCASE" )
$ outfspec       = "''DD'''Fac'''FF$Cmd'_''node'_''dev'.REPORT"
$ !
$ wso F$FAO( "%!AS-I-WAIT, directory of !AS::!AS to !AS ...", -
              Fac, node, dev, outfspec )
$ VMSver = F$EDIT(F$GETSYI("VERSION"),"TRIM")
$ now  = F$TIME()
$ nowl = F$LENGTH( now )
$ !
$ IF ( VMSver .GES. "V8.3" )
$ THEN ! Let DIRECTORY do the version selection...
$      DIRECTORY 'dev':[000000...]*.*   -
         /OUTPUT='tmpfspec'             -
         /COLUMN=1 /NOHEADER /NOTRAILER -
         /SELECT=VERSION=MINIMUM='FileMinVersion'
$ !
$ ELSE ! Report selected versions into tmp-report file, let
$      !   the following tmp-report-scan sort it out...
$      IF ( VMSver .GES. "V7.1" )
$      THEN CONTINUE
$SV0:
$           fmvlen = F$LENGTH( FMVtmp ) - 1
$           IF ( fmvlen .GT. 0 ) .AND. ( F$EXTRACT( fmvlen, 1, FMVtmp ) .EQS. "0" )
$           THEN ! Trim trailing zeros "0" from FMVtmp (equivalent to div-10)
$                !   until there are no more...
$                FMVtmp = F$EXTRACT( 0, fmvlen, FMVtmp )
$                GOTO SV0
$           ENDIF
$           ! This PIPE is much faster than just dumping all versions into
$           !   one big DIR-output file; the resulting temp-file will be
$           !   much smaller, and therefore much faster to search...
$           FMVtmp = ";" + FMVtmp
$           PIPE DIRECTORY 'dev':[000000...]*.* -
                 /COLUMN=1 /NOHEADER /NOTRAILER -
                 | SEARCH sys$pipe "''FMVtmp'"  -
                 | CREATE 'tmpfspec'
$      ELSE ! for older VMS versions <V7.1, gotta do it slow:
$           DIRECTORY 'dev':[000000...]*.* -
              /OUTPUT='tmpfspec'           -
              /COLUMN=1 /NOHEADER /NOTRAILER
$      ENDIF
$ ENDIF
$ !
$ OPEN /READ  /ERROR=ReadErr  in  'tmpfspec'
$ OPEN /WRITE /ERROR=WriteErr out 'outfspec'
$ !
$ MaxFS  = ""
$ MaxV   = 0
$ fcount = 0
$ !
$ hdr  = F$FAO( "Disk Device !AS on node !AS", dev, node )
$ hdrl = F$LENGTH( hdr )
$ !
$ wso F$FAO( "%!AS-I-WAIT, scanning for file versions > ;!ZL ...", -
              Fac, FileMinVersion )
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
$ IF ( fvers .GE. FileMinVersion )
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
$      WRITE out F$FAO( "Total files found having version >= ;!ZL: !ZL", FileMinVersion, fcount )
$ ELSE WRITE out F$FAO( "!AS!#* !AS", hdr, 80 - hdrl - nowl, now )
$      WRITE out ""
$      WRITE out F$FAO( "No files found having version >= ;!ZL", FileMinVersion )
$ ENDIF
$ IF ( FF$Cmd .EQS. "VERSIONS" )
$ THEN WRITE out ""
$      WRITE out F$FAO( "!6* Maximum version found: ;!ZL", MaxV )
$      WRITE out F$FAO( "!19* for file: !AS", MaxFS )
$ ENDIF
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
$ ! P1 : TRUE to force TYPE /PAGE, otherwise plain old TYPE
$ IF P1
$ THEN typeit = "TYPE /PAGE"
$ ELSE typeit = "TYPE"
$ ENDIF
$ IF ( F$SEARCH("''P1';-1") .NES. "" ) THEN PURGE /NOLOG /KEEP=2 'P1'
$ IF P2 THEN typeit 'P1'
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
$ Node = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ !
$ reqdclslversion = "02.05.01"
$dclslvercheck:
$ dclslversion = F$TRNLNM( "DCL$SLversion" )
$ IF ( dclslversion .NES. "" )
$ THEN IF ( dclslversion .LTS. reqdclslversion )
$      THEN wso "%''Fac'-E-WRONGVER, this procedure requires DCL$SUBROUTINE_LIBRARY.COM v''reqdclslversion'"
$           EXIT %X2C
$      ELSE GOTO dclcontinue
$      ENDIF
$ ELSE wso "%''Fac'-E-NOLIB, this procedure requires DCL$SUBROUTINE_LIBRARY.COM"
$      dclslcomf = "lmr$login:DCL$SUBROUTINE_LIBRARY.COM"
$      @'dclslcomf' Setup TRUE
$      IF $STATUS
$      THEN GOTO dclslvercheck
$      ELSE EXIT %X2C
$      ENDIF
$ ENDIF
$dclcontinue:
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
$ CmdSet =  "VERSIONS |SIZE     |AGED     |BEFORE   |SINCE    |AFTER    " -
         + "|MOVE     |NOBACKUP |VERLIMIT |BIGDIRS  |FILECOUNT|HELP     "
$ !
$ DCL$CALL CmdParse "''P1'" "FF$Cmd" "VERSIONS" "''CmdSet'" "" "TRUE"
$ IF ( FF$Cmd .EQS. "HELP"  ) THEN GOTO Help$
$ IF ( FF$Cmd .EQS. "AGED"  ) THEN FF$Cmd == "BEFORE"
$ IF ( FF$Cmd .EQS. "AFTER" ) THEN FF$Cmd == "SINCE"
$ ! Scanning for a file attribute?
$ IF ( FF$Cmd .EQS. "MOVE" ) .OR. ( FF$Cmd .EQS. "NOBACKUP" ) .OR. ( FF$Cmd .EQS. "VERLIMIT" )
$ THEN attr = FF$Cmd
$      FF$Cmd = "FILEATTR"
$ ELSE attr = ""
$ ENDIF
$ !
$ IF ( P2 .NES. "" )
$ THEN FF$DiskList == P2
$ ELSE CALL DCL$CALL DiscoverDisks FF$DiskList "MNT"
$      wso F$FAO( "%!AS-I-ALLDISKS, scanning !AS", Fac, FF$DiskList )
$ ENDIF
$ !
$ tmpfspec   = "sys$scratch:" + Fac + FF$Cmd + ".tmp"
$ !
$ IF ( P3 .NES. "" )
$ THEN defvalue = P3
$      defvalue = defvalue - SEMICOLON
$ ELSE GOTO def_'FF$Cmd'
$def_VERSIONS:
$      defvalue = "32700"  ! without the semicolon
$      GOTO defdone
$def_SIZE:
$      defvalue = "10000"
$      GOTO defdone
$def_BEFORE:
$      defvalue = "1-JAN"
$      GOTO defdone
$def_SINCE:
$      defvalue = "1-JAN"
$      GOTO defdone
$def_BIGDIRS:
$      defvalue = "500"
$      GOTO defdone
$def_FILECOUNT:
$def_FILEATTR:
$      defvalue = ""
$      GOTO defdone
$ ENDIF
$ !
$defdone:
$ !
$ typereport = ( F$EXTRACT(0,4,P4) .NES. "NOTY" )  ! NOTYPE
$ !
$ devcount = 0
$ !
$Loop0:
$ ! especially for $STATUS=%x1001C04A, -F-VOLINV, volume is not sofware enabled:
$ ON ERROR THEN GOTO L0err
$ dev = F$ELEMENT( devcount, COMMA, FF$DiskList )
$ IF ( dev .EQS. COMMA ) THEN GOTO Done
$ dev = F$EDIT( dev, "TRIM,UPCASE" ) - COLON
$ IF .NOT. Verbose
$ THEN CALL Scan'FF$Cmd' "''dev'" "''defvalue'" "''tmpfspec'" "''Node'" "''attr'"
$ ELSE wso F$FAO( "%!AS-I-ECHO, CALL Scan''FF$Cmd' ""!AS"" ""!AS"" ""!AS"" ""!AS""", -
                  Fac, dev, defvalue, tmpfspec, Node, attr )
$ ENDIF
$L0err:
$ devcount = devcount + 1
$ GOTO Loop0
$ !
$Done:
$ SET NOON
$ ! cleanup
$ DCL$CALL DeleteGloSyms "FF$Cmd,FF$Cmd_Num,FF$DiskList,FF$FCount,FF$MaxFiles"
$ IF ( F$TYPE(tmpfspec) .NES. "" ) -
  THEN IF ( tmpfspec .NES. "" ) -
       THEN IF ( F$SEARCH(tmpfspec)  .NES. "" ) THEN DELETE /NOLOG 'tmpfspec';*
$ !
$ ! Principle of Least Privilege:
$ IF ( F$TYPE(Prv) .EQS. "STRING" ) THEN Prv = F$SETPRV(Prv)
$ !
$ EXIT 1   ! 'F$VERIFY(0)'
$ !
$ !
$Help$:
$ TYPE /PAGE sys$input

  use:  @FILE$FIND [ VERSIONS (D) | SIZE
                     | AGED | BEFORE | SINCE | AFTER
                     | MOVE | NOBACKUP | VERLIMIT
                     | BIGDIRS | FILECOUNT |
                     | HELP ]
                   [ disk_device[,...] ]
                   [ scan_parameter ]
                   [ NOTYPE ]

  where: P1 -- Scan/search action: VERSIONS, SIZE,
                                   AGED or BEFORE,
                                   SINCE or AFTER,
                                   MOVE, NOBACKUP or VERLIMIT,
                                   BIGDIRS, FILECOUNT,
                                   HELP

         P2 -- Disk device list to scan for files over the specified
               or default version limit; default is SYS$SYSDEVICE;
               specify more than one device as a comma-separated list:
               e.g.: "DISK$DATA1,DSA200:,SYS$SYSDEVICE"

         P3 -- for VERSIONS:       The minimum file version to list --
                                   default: ;32700
                   SIZE:           The minimum file size to list, in blocks --
                                   default: 10000
                   AGED or BEFORE: Files created before this date/time --
                                   default: 1-JAN-<current_year>
                   AFTER or SINCE: Files created after this date/time --
                                   default: 1-JAN-<current_year>
                   BIGDIRS:        The threshold size for "big" directories --
                                   default: 50
                   MOVE, NOBACKUP, Scan-parameter not used, can be any value,
                   VERLIMIT        including "" or "DUMMY", etc.

         P4 -- NOTYPE: just scan & create output file, don't TYPE/PAGE it

$ GOTO Done
