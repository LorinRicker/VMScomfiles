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
$ ! use: @DISK$CLONE SourceDisk VolumeLabel TargetDisk1[,TargetDisk2]... [/LOG]
$ !
$ ON CONTROL THEN GOSUB CtrlY
$ ON ERROR THEN EXIT %X2C
$ !
$ wso = "WRITE sys$output"
$ Verbose = F$TRNLNM( "TOOLS$DEBUG" )
$ COLON   = ":"
$ COMMA   = ","
$ HYPHEN  = "-"
$ SLASH   = "/"
$ hline   = F$FAO( "!72*-" )
$ !
$ Self = F$ENVIRONMENT( "PROCEDURE" )
$ Fac  = F$PARSE( Self, , , "NAME", "SYNTAX_ONLY" )
$ self = Self - F$PARSE( Self, , , "VERSION" )
$ !
$ p1val = P1 - HYPHEN - HYPHEN - SLASH
$ p1val = F$EXTRACT( 0, 1, F$EDIT( p1val, "UPCASE,COLLAPSE" ) )
$ IF ( p1val .EQS. "H" ) .OR. ( p1val .EQS. "?" ) THEN GOTO Help
$ !
$ reqdclslversion = "02.05.01"
$dclslvercheck:
$ dclslversion = F$TRNLNM( "DCL$SLversion" )
$ IF ( dclslversion .NES. "" )
$ THEN IF ( dclslversion .LTS. reqdclslversion )
$      THEN wso "%''Fac'-E-WRONGVER, this procedure requires DCL$SUBROUTINE_LIBRARY.COM v''reqdclslversion'"
$           EXIT %X2C
$      ELSE GOTO clone1continue
$      ENDIF
$ ELSE wso "%''Fac'-E-NOLIB, this procedure requires DCL$SUBROUTINE_LIBRARY.COM"
$      dclslcomf = "lmr$login:DCL$SUBROUTINE_LIBRARY.COM"
$      @'dclslcomf' Setup TRUE
$      IF $STATUS
$      THEN GOTO dclslvercheck
$      ELSE EXIT %X2C
$      ENDIF
$ ENDIF
$clone1continue:
$ !
$ ! If "I" (the executing process) am top/parent process,
$ ! launch Self as a subprocess;
$ ! else, "I" am the subprocess... get to work!
$ IF ( P4 .EQS. "/LOG" )
$ THEN sdisk = F$EDIT( P1, "UPCASE,COLLAPSE" ) - COLON
$      vLbl  = F$EDIT( P2, "UPCASE,COLLAPSE" )
$      LogFile = F$FAO( "/OUTPUT=LOGS:!AS_!AS_!AS.LOG", -
                        Fac, sdisk, vlbl )
$ ELSE LogFile = ""
$ ENDIF
$ DCL$CALL AmI_Subprocess
$ IF ( IAm$Subprocess )
$ THEN GOTO clone2continue
$ ELSE IF ( LogFile .NES. "" )
$      THEN msg = LogFile - "/OUTPUT="
$           wso F$FAO( "%!AS-I-OUTPUT_LOG, output logfile is !AS", -
                       Fac, msg )
$      ENDIF
$      SPAWN /NOWAIT /NOTIFY /INPUT=NLA0: 'LogFile' -
          'Self' "''P1'" "''P2'" "''P3'"
$ ENDIF
$ !
$clone2continue:
$ prv = F$SETPRV( "BYPASS,CMEXEC,SYSNAM,SYSPRV,VOLPRO" )
$ !
$ VolLbl  = F$EDIT( P2, "UPCASE,COLLAPSE" )
$ SrcDisk = F$EDIT( P1, "UPCASE,COLLAPSE" ) - COLON
$ Src_is_VolShadow = ( F$LOCATE( "DSA", SrcDisk ) .LT. F$LENGTH( SrcDisk ) )
$ ! Some sanity checks --
$ IF ( .NOT. F$GETDVI( SrcDisk, "EXISTS" ) )
$ THEN wso F$FAO( "%!AS-F-NOSUCHDEV, source disk device !AS does not exist", -
                   Fac, SrcDisk )
$      EXIT %X2C
$ ENDIF
$ IF ( F$GETDVI( SrcDisk, "VOLNAM" ) .NES. VolLbl )
$ THEN wso F$FAO( "%!AS-F-WRONGVOLLBL, specified volume lable !AS does not match !AS", -
                   Fac, VolLbl, SrcDisk )
$      EXIT %X2C
$ ENDIF
$ !
$ IF ( F$TRNLNM( SrcDisk ) .EQS. "" ) THEN SrcDisk = SrcDisk + COLON
$ TarDisk = F$EDIT( P3, "UPCASE,COLLAPSE" )
$ j = 1
$ tdisks = ""
$loop1:
$ TarDisk'j' = F$ELEMENT( j-1, COMMA, P3 )
$ IF ( TarDisk'j' .EQS. COMMA ) THEN GOTO loop1end
$ TarDisk'j' = TarDisk'j' - COLON
$ IF ( F$TRNLNM( TarDisk ) .EQS. "" ) THEN TarDisk = TarDisk + COLON
$ ! Sanity check --
$ IF ( F$GETDVI( TarDisk'j', "EXISTS" ) )
$ THEN IF ( tdisks .NES. "" )
$      THEN tdisks = tdisks + COMMA + TarDisk'j'
$      ELSE tdisks = TarDisk'j'
$      ENDIF
$ ELSE wso F$FAO( "%!AS-F-NOSUCHDEV, target disk device !AS does not exist", -
                   Fac, TarDisk'j' )
$      EXIT %X2C
$ ENDIF
$ j = j + 1
$ GOTO loop1
$loop1end:
$ !
$ IF F$GETDVI( SrcDisk, "ODS5" )
$ THEN ODSn = "5"
$ ELSE ODSn = "2"
$ ENDIF
$ ClustSize = F$STRING( F$GETDVI( SrcDisk, "CLUSTER" ) )
$ !
$ SET NOON  ! don't let BACKUP errors/status abort...
$ StartTime = F$TIME()
$ wso ""
$ wso hline
$ wso F$FAO( "%!AS-I-START, disk clone !AS -> !AS started at !AS", -
             Fac, SrcDisk, TarDisk, -
             F$CVTIME( StartTime, "ABSOLUTE", "TIME" ) )
$ !
$ j = 1
$loop2:
$ IF ( F$TYPE( TarDisk'j' ) .EQS. "" ) THEN GOTO loop2end
$ ! Initialize each/all of the target disks for this Volume Shadow Set --
$ ! This avoids the "wrong virtual unit" problem %MOUNT-F-WRONGVU ("device
$ ! is already a member of another virtual unit") ... see HELP/MESSAGE text
$ ! at the end of this file, especially the third reason/case.
$ tdisk = TarDisk'j'
$ wso F$FAO( "!AS-I-INIT, initializing !AS !AS /STRUCTURE=!AS /CLUSTER_SIZE=!AS", -
             Fac, tdisk, VolLbl, ODSn, ClustSize )
$ INITIALIZE 'tdisk' 'VolLbl' /STRUCTURE='ODSn' /CLUSTER_SIZE='ClustSize'
$ j = j + 1
$ GOTO loop2
$loop2end:
$ !
$ MOUNT /FOREIGN 'TarDisk1'  ! target of the clone...
$ !
$ wso ""
$ wso hline
$ wso F$FAO( "!AS-I-BACKUP, starting clone !AS -> !AS", -
             Fac, SrcDisk, TarDisk1 )
$ BACKUP 'SrcDisk' /IMAGE /IGNORE=INTERLOCK /PROGRESS=120 -
    'TarDisk1' /NOINITIALIZE  ! preserve larger size, etc.
$ !
$ DISMOUNT 'TarDisk1'
$ wso ""
$ wso F$FAO( "!AS-I-DISMOUNT, target !AS is dismounted, ready for checkout...", -
             Fac, TarDisk1 )
$ !
$ EndTime = F$TIME()
$ wso ""
$ wso hline
$ wso F$FAO( "%!AS-I-END, disk clone !AS -> !AS completed at !AS", -
             Fac, SrcDisk, TarDisk, -
             F$CVTIME( EndTime, "ABSOLUTE", "TIME" ) )
$ wso F$FAO( "%!AS-I-ELAPSED, elapsed time: !AS", -
             Fac, F$DELTA_TIME( StartTime, EndTime, "DCL" ) )
$ !
$ tdisk = TarDisk'j'
$ wso ""
$ wso hline
$ wso "Recommendation:  Manually do --"
$ wso "  a) Mount the just-cloned ''tdisk' process-private and write-only:"
$ wso "     $ MOUNT /NOWRITE ''tdisk' ''VolLbl'"
$ wso "     to check-out the integrity/completeness of the backup/clone operation."
$ IF Src_is_VolShadow
$ THEN wso "  and/or --"
$      wso "  b) Dismount the old Shadow-Set Volume from the cluster:"
$      wso "     $ DISMOUNT /CLUSTER ''SrcDisk'"
$      wso "     (Note: Any open files on that volume may prevent the dismount.)"
$      wso "     Then (re)mount the Shadow-Set cluster-wide using the newly-cloned"
$      wso "     ''tdisk' as the first member, plus any other shadow-set members"
$      wso "     to start the Copy/Merge operation for ''SrcDisk':"
$      wso "     $ MOUNT /CLUSTER /NOASSIST /NOREBUILD ''SrcDisk' /SHADOW=(''tdisks') ''VolLbl'"
$ ENDIF
$ wso hline
$ wso ""
$ !
$Done:
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

  use: $ @DISK$CLONE SourceDisk VolumeLabel TargetDisk1[,TargetDisk2]...

$ !
$ EXIT 1  ! 'F$VERIFY(0)'
$ !
$ !
$ !!  WRONGVU,  device is already a member of another virtual unit
$ !!
$ !!    Facility:     MOUNT, Mount Utility
$ !!
$ !!    Explanation:  This message can occur under any of the following conditions:
$ !!
$ !!    o A shadow set member (identified in an accompanying
$ !!      SHADOWFAIL message) is already mounted on another node
$ !!      in the cluster as a member of a different shadow set.
$ !!
$ !!    o The device is the target of a shadow set copy operation,
$ !!      and the copy operation has not yet started. In this case,
$ !!      the storage control block (SCB) of the copy target is not
$ !!      in the same location as it is on the master node. This
$ !!      causes MOUNT to read the wrong SCB and fail with this
$ !!      error.
$ !!    o The target of the shadow set copy operation is a new,
$ !!      uninitialized disk. This failure is commonly seen when a
$ !!      MOUNT/CLUSTER command is issued and one or more of the
$ !!      members is a new disk. The set is mounted successfully
$ !!      on the local node, but all of the remote nodes report a
$ !!      WRONGVU error.
$ !!
$ !!    User Action:
$ !!
$ !!    o For the first condition, specify a different member for the
$ !!      shadow set you are mounting, or specify the correct virtual
$ !!      unit for the member that is already mounted elsewhere.
$ !!
$ !!    o For the second condition, wait for the copy operation
$ !!      to proceed before attempting to remount this device, or
$ !!      initialize the copy target disk so that the SCB is in the
$ !!      same location as it is on the master member.
$ !!
$ !!    o For the third condition, OpenVMS recommends that all new
$ !!      disks be initialized prior to mounting them into a shadow
$ !!      set.
$ !!
