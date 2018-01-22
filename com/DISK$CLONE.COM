$ ! DISK$CLONE.COM                                                 ! 'F$VERIFY(0)'
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
$ ! use: @DISK$CLONE SourceDisk VolumeLabel TargetDisk
$ !
$ ON CONTROL THEN GOSUB CtrlY
$ ON ERROR THEN EXIT %X2C
$ !
$ wso = "WRITE sys$output"
$ Verbose = F$TRNLNM( "TOOLS$DEBUG" )
$ COLON   = ":"
$ HYPHEN  = "-"
$ SLASH   = "/"
$ !
$ proc = F$ENVIRONMENT( "PROCEDURE" )
$ Fac  = F$PARSE( proc, , , "NAME", "SYNTAX_ONLY" )
$ !
$ p1val = P1 - HYPHEN - HYPHEN - SLASH
$ p1val = F$EXTRACT( 0, 1, F$EDIT( p1val, "UPCASE,COLLAPSE" ) )
$ IF ( p1val .EQS. "H" ) .OR. ( p1val .EQS. "?" ) THEN GOTO Help
$ !
$ prv = F$SETPRV( "BYPASS,CMEXEC,SYSNAM,SYSPRV,VOLPRO" )
$ !
$ VolLbl  = F$EDIT( P2, "UPCASE,COLLAPSE" )
$ SrcDisk = F$EDIT( P1, "UPCASE,COLLAPSE" ) - COLON
$ IF ( F$TRNLNM( SrcDisk ) .EQS. "" ) THEN SrcDisk = SrcDisk + COLON
$ TarDisk = F$EDIT( P3, "UPCASE,COLLAPSE" ) - COLON
$ IF ( F$TRNLNM( TarDisk ) .EQS. "" ) THEN TarDisk = TarDisk + COLON
$ !
$ ! Some sanity checks --
$ IF ( .NOT. F$GETDVI( SrcDisk, "EXISTS" ) )
$ THEN wso F$FAO( "%!AS-F-NOSUCHDEV, source disk device !AS does not exist", -
                   Fac, SrcDisk )
$      EXIT %X2C
$ ENDIF
$ IF ( .NOT. F$GETDVI( TarDisk, "EXISTS" ) )
$ THEN wso F$FAO( "%!AS-F-NOSUCHDEV, target disk device !AS does not exist", -
                   Fac, TarDisk )
$      EXIT %X2C
$ ENDIF
$ IF ( F$GETDVI( SrcDisk, "VOLNAM" ) .NES. VolLbl )
$ THEN wso F$FAO( "%!AS-F-WRONGVOLLBL, specified volume lable !AS does not match !AS", -
                   Fac, VolLbl, SrcDisk )
$      EXIT %X2C
$ ENDIF
$ !
$ IF F$GETDVI( SrcDisk, "ODS5" )
$ THEN ODSn = "5"
$ ELSE ODSn = "2"
$ ENDIF
$ ClustSize = F$STRING( F$GETDVI( SrcDisk, "CLUSTER" ) )
$ !
$ SET NOON  ! don't let BACKUP errors/status abort...
$ StartTime = F$TIME()
$ wso F$FAO( "%!AS-I-START, disk clone !AS -> !AS started at !AS", -
             Fac, SrcDisk, TarDisk, -
             F$CVTIME( StartTime, "ABSOLUTE", "TIME" ) )
$ wso F$FAO( "!AS-I-INIT, initializing !AS !AS /STRUCTURE=!AS /CLUSTER_SIZE=!AS", -
             Fac, TarDisk, VolLbl, ODSn, ClustSize )
$ INITIALIZE 'TarDisk' 'VolLbl' /STRUCTURE='ODSn' /CLUSTER_SIZE='ClustSize'
$ !
$ MOUNT /FOREIGN 'TarDisk'
$ !
$ wso ""
$ wso F$FAO( "!AS-I-BACKUP, starting clone !AS -> !AS", -
             Fac, SrcDisk, TarDisk )
$ BACKUP 'SrcDisk' /IMAGE /IGNORE=INTERLOCK /PROGRESS=120 -
    'TarDisk' /NOINITIALIZE  ! preserve larger size, etc.
$ !
$ DISMOUNT 'TarDisk'
$ wso ""
$ wso F$FAO( "!AS-I-DISMOUNT, target !AS is dismounted, ready for checkout...", -
             Fac, TarDisk )
$ !
$ EndTime = F$TIME()
$ wso ""
$ wso F$FAO( "%!AS-I-END, disk clone !AS -> !AS completed at !AS", -
             Fac, SrcDisk, TarDisk, -
             F$CVTIME( EndTime, "ABSOLUTE", "TIME" ) )
$ wso F$FAO( "%!AS-I-ELAPSED, elapsed time: !AS", -
             Fac, F$DELTA_TIME( StartTime, EndTime, "DCL" ) )
$ !

$ IF ( F$TYPE( prv ) .NES. "" ) THEN prv = F$SETPRV( prv )
$ EXIT 1  ! 'F$VERIFY(0)'
$ !
$CtrlY:
$ RETURN %X2C
$ !
$Help:
$ TYPE /PAGE sys$input

  DISK$CLONE.COM is a script which copies/clones one source disk (device)
  to another target disk, using BACKUP /IMAGE /NOINITIALIZE.

  The target disk is pre-initialized to have its own, typically larger,
  disk geometry and characteristics, but inherits the source disks's
  ODS-2/5 structure, cluster-size and volume label.

  use: $ [1m@DISK$CLONE SourceDisk VolumeLabel TargetDisk[0m

$ !
$ EXIT 1  ! 'F$VERIFY(0)'
$ !
