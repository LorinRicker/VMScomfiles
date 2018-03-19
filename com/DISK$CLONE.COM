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
$ ! use: @DISK$CLONE SourceDisk VolumeLabel TargetDisk1[,TargetDisk2]... -
$ !        [ [/VERBOSE] [/LOG] [/DRYRUN] [[/BATCH] [/SUBMIT]] ]
$ !
$ !  or: @DISK$CLONE /HELP
$ !
$ !      /HELP, /VERBOSE, /LOG, /DRYRUN, /BATCH, /SUBMIT can also be:
$ !        --help, --verbose, --dryrun, --log, --batch, --submit,
$ !        or -help or help, etc.
$ !
$DiskReport:  SUBROUTINE
$ dev = P1
$ IF ( minVMS73 )
$ THEN cluster  = F$STRING( F$GETDVI( dev, "CLUSTER" ) )
$      cluslen  = F$LENGTH( cluster )
$      maxfiles = F$FAO( "!UL", F$GETDVI( dev, "MAXFILES" ) )
$      maxblks  = F$FAO( "!UL", F$GETDVI( dev, "MAXBLOCK" ) )
$      expsize  = F$FAO( "!UL", F$GETDVI( dev, "EXPSIZE" ) )
$      volsize  = F$FAO( "!UL", F$GETDVI( dev, "VOLSIZE" ) )
$      DCL$CALL Thousands DL$maxfiles "''maxfiles'"
$      DCL$CALL Thousands DL$maxblks  "''maxblks'"
$      DCL$CALL Thousands DL$expsize  "''expsize'"
$      DCL$CALL Thousands DL$volsize  "''volsize'"
$      maxflen = F$LENGTH( DL$maxfiles )
$      maxblen = F$LENGTH( DL$maxblks )
$      volslen = F$LENGTH( DL$volsize )
$      expslen = F$LENGTH( DL$expsize )
$      ! Write a tight little report:
$      fldlen = 15
$      wso hline
$      wso ""
$      wso "Target/Clone Disk ''dev' after INITIALIZE:"
$      line = F$FAO( "         Cluster size: !AS", cluster )
$      wso line
$      line = F$FAO( "        Maximum files: !#* !AS    Total blocks: !#* !AS", -
                     fldlen-maxflen, DL$maxfiles, fldlen-maxblen, DL$maxblks )
$      wso line
$      line = F$FAO( "  Logical volume size: !#* !AS  Expansion size: !#* !AS", -
                     fldlen-volslen, DL$volsize, fldlen-expslen, DL$expsize )
$      wso line
$      wso hline
$      wso ""
$ ELSE ! Uglier, but gets the available info displayed:
$      SHOW DEVICE /FULL 'firstdisk'
$      wso hline
$      wso ""
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! DiskReport
$ !
$ !
$Main:
$ ON CONTROL THEN GOSUB CtrlY
$ ON ERROR THEN EXIT %X2C
$ !
$ VMS$ver  = F$EDIT(F$GETSYI("VERSION"),"TRIM")
$ minVMS73 = ( VMS$ver .GES. "V7.3" ) 
$ !
$ Verbose  = F$TRNLNM( "TOOLS$DEBUG" )
$ DryRun   = 0
$ Logging  = 0
$ !
$ wso      = "WRITE sys$output"
$ COLON    = ":"
$ COMMA    = ","
$ HYPHEN   = "-"
$ SLASH    = "/"
$ SPACE    = " "
$ hline    = F$FAO( "!80*-" )
$ !
$ ProgInt  = "60"  ! show BACKUP /PROGRESS every N-seconds
$ !
$ ProcMode = F$MODE()
$ Self     = F$ENVIRONMENT( "PROCEDURE" )
$ Fac      = F$PARSE( Self, , , "NAME", "SYNTAX_ONLY" )
$ Self     = Self - F$PARSE( Self, , , "VERSION" )
$ !
$ ! Any qual/option can appear as /QUAL, --option, -option or option ...
$ p1val = P1 - SLASH - HYPHEN - HYPHEN
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
$ IF ( F$TRNLNM( "logs" ) .EQS. "" ) THEN DEFINE /JOB /NOLOG logs sys$disk:[]
$ !
$ ! Any qual/option can appear as /QUAL, --option, -option or option ...
$ Quals = ( P4 - SLASH - HYPHEN - HYPHEN ) + SPACE -
        + ( P5 - SLASH - HYPHEN - HYPHEN ) + SPACE -
        + ( P6 - SLASH - HYPHEN - HYPHEN )
$ Quals = F$EDIT( Quals, "UPCASE" )
$ Qlen = F$LENGTH( Quals )
$ !
$ Verbose = ( F$LOCATE( "VER", Quals ) .LT. Qlen )
$ DryRun  = ( F$LOCATE( "DRY", Quals ) .LT. Qlen )
$ IF ( F$LOCATE( "LOG", Quals ) .LT. Qlen ) .OR. ( Verbose )
$ THEN Logging = 1
$      sdisk = F$EDIT( P1, "UPCASE,COLLAPSE" ) - COLON
$      vLbl  = F$EDIT( P2, "UPCASE,COLLAPSE" )
$      LogFile = F$FAO( "LOGS:!AS_!AS.LOG", Fac, vlbl )
$ ELSE Logging = 0
$      LogFile = ""
$ ENDIF
$ !
$ GOTO 'ProcMode'
$ !
$ !
$INTERACTIVE:
$ ! May need command alias(es):
$ f = "COM:DO_CONTINUOUS.COM"
$ IF ( F$SEARCH( f ) .NES. "" ) THEN docont == "@''f'"
$ !
$ SelfSubmit = ( F$LOCATE( "BAT", Quals ) .LT. Qlen ) -
          .OR. ( F$LOCATE( "SUB", Quals ) .LT. Qlen )
$ IF ( SelfSubmit )
$ THEN SUBMIT = "SUBMIT /NOTIFY /KEEP /NOPRINT /LOG=''LogFile'"
$      SUBMIT 'Self' /PARAMETERS=("''P1'","''P2'","''P3'","''P4'","''P5'","''P6'","''P7'","''P8'")
$      DCentry = $ENTRY
$      IF ( F$TYPE( docont ) .EQS. "STRING" )
$      THEN WatchDC == "@com:do_continuous -d:60 ""pipe TYPE /TAIL ''LogFile' ; SHOW ENTRY /FULL ''DCentry'"""
$      ELSE WatchDC == "pipe TYPE /TAIL ''LogFile' ; SHOW ENTRY /FULL ''DCentry'"
$      ENDIF
$      wso ""
$      wso "%''Fac'-I-USE, to monitor clone/copy progress, use:"
$      wso "      $ [1m''WatchDC'[0m"
$      EXIT 1
$ ENDIF
$ !
$OTHER:  ! the subprocess vectors here...
$ ! If "I" (the executing process) am top/parent process,
$ ! launch Self as a subprocess;
$ ! else, "I" am the subprocess... get to work!
$ !
$ DCL$CALL AmI_Subprocess  ! 'F$VERIFY(0)'
$ IF ( IAm$Subprocess )
$ THEN GOTO clone2continue
$ ELSE IF ( LogFile .NES. "" )
$      THEN wso F$FAO( "%!AS-I-OUTPUT_LOG, output logfile is !AS", Fac, LogFile )
$      ENDIF
$      wso ""
$      wso hline
$      fork = "SPAWN /NOWAIT /NOTIFY /INPUT=NLA0: "
$      fork @'Self' /OUTPUT='LogFile' "''P1'" "''P2'" "''P3'" "''P4'" "''P5'" "''P6'" "''P7'" "''P8'"
$      EXIT 1
$ ENDIF
$ !
$BATCH:
$ ! If "I" am executing in batch, just get to work...
$ !
$clone2continue:
$ ON ERROR THEN EXIT %X2C
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
$ procpid  = F$GETJPI( "", "PID" )
$ procname = "DC$''SrcDisk'" - "DISK$"
$ procname = F$EXTRACT( 0, 15, procname )  ! process name <= 15 characters
$ SET PROCESS /NAME="''procname'"  ! okay for both subprocess and batch process...
$ WRITE sys$error "%''Fac'-I-IDENT, process name: ''procname', PID: ''procpid', ''ProcMode' mode"
$ SHOW PROCESS /SUBPROCESS
$ !
$ SrcDisk = SrcDisk - COLON
$ SrcDiskLNM = F$TRNLNM( SrcDisk )
$ SrcDisk = SrcDisk + COLON
$ IF ( SrcDiskLNM .NES. "" ) THEN SrcDisk = SrcDiskLNM - COLON + COLON
$ IF ( Verbose )
$ THEN wso ""
$      wso "     SrcDisk = ",SrcDisk
$      wso "  SrcDiskLNM = ",SrcDiskLNM
$ ENDIF
$ !
$ TarDisk = F$EDIT( P3, "UPCASE,COLLAPSE" )
$ j = 1
$ TDisks = ""
$loop1:
$ TarDisk'j' = F$ELEMENT( j-1, COMMA, P3 )
$ IF ( TarDisk'j' .EQS. COMMA ) THEN GOTO loop1end
$ IF ( F$TRNLNM( TarDisk'j' ) .EQS. "" ) THEN TarDisk'j' = TarDisk'j' - COLON
$ ! Sanity check --
$ IF ( F$GETDVI( TarDisk'j', "EXISTS" ) )
$ THEN TarDisk'j' = TarDisk'j' + COLON
$      IF ( TDisks .NES. "" )
$      THEN TDisks = TDisks + COMMA + TarDisk'j'
$      ELSE TDisks = TarDisk'j'
$      ENDIF
$ ELSE wso F$FAO( "%!AS-F-NOSUCHDEV, target disk device !AS does not exist", -
                   Fac, TarDisk'j' )
$      EXIT %X2C
$ ENDIF
$ j = j + 1
$ GOTO loop1
$loop1end:
$ tdcount = j - 1
$ IF ( Verbose ) THEN wso "      TDisks = ",TDisks
$ !
$ IF F$GETDVI( SrcDisk, "ODS5" )
$ THEN ODSn = "5"
$ ELSE ODSn = "2"
$ ENDIF
$ ClustSize = F$STRING( F$GETDVI( SrcDisk, "CLUSTER" ) )
$ !
$ StartTime = F$TIME()
$ wso ""
$ wso hline
$ wso F$FAO( "%!AS-I-START, disk clone !AS -> !AS started at !AS", -
             Fac, SrcDisk, TarDisk, -
             F$CVTIME( StartTime, "ABSOLUTE", "TIME" ) )
$ !
$ j = 1
$loop2:
$ IF ( F$TYPE( TarDisk'j' ) .EQS. COMMA ) THEN GOTO loop2end
$ IF ( .NOT. F$GETDVI( TarDisk'j', "EXISTS" ) ) THEN GOTO loop2end
$ ! Initialize each/all of the target disks for this Volume Shadow Set --
$ ! This avoids the "wrong virtual unit" problem %MOUNT-F-WRONGVU ("device
$ ! is already a member of another virtual unit") ... see HELP/MESSAGE text
$ ! at the end of this file, especially the third reason/case.
$ tdisk = TarDisk'j'
$ wso F$FAO( "%!AS-I-INIT, initializing !AS !AS /STRUCTURE=!AS /CLUSTER_SIZE=!AS", -
             Fac, tdisk, VolLbl, ODSn, ClustSize )
$ IF ( DryRun )
$ THEN wso ""
$      wso "%''Fac'-I-ECHO, ..."
$      wso "  $ INITIALIZE ''tdisk' ''VolLbl' /STRUCTURE=''ODSn' /CLUSTER_SIZE=''ClustSize'"
$ ELSE INITIALIZE 'tdisk' 'VolLbl' /STRUCTURE='ODSn' /CLUSTER_SIZE='ClustSize'
$ ENDIF
$ j = j + 1
$ GOTO loop2
$loop2end:
$ !
$ IF ( DryRun )
$ THEN wso ""
$      wso "%''Fac'-I-ECHO, ..."
$      wso "  $ MOUNT /NOWRITE ''TarDisk1' ''VolLbl'"
$      wso "  $ CALL DiskReport ""''TarDisk'"""  !...generates mini-report
$      wso "  $ DISMOUNT ''TarDisk1'"
$ ELSE ! private-mount the first TarDisk, display its characteristics (expanded):
$      IF ( .NOT. F$GETDVI( TarDisk1, "MNT" ) )
$      THEN DEFINE /USER sys$output nla0:
$           DEFINE /USER sys$error  nla0:
$           MOUNT /NOWRITE 'TarDisk1' 'VolLbl'
$      ENDIF
$      CALL DiskReport "''TarDisk1'"
$      IF ( F$GETDVI( TarDisk1, "MNT" ) ) THEN DISMOUNT 'TarDisk1'
$ ENDIF
$ !
$ SET NOON  ! don't let BACKUP errors/status abort...
$ wso ""
$ wso hline
$ wso F$FAO( "%!AS-I-BACKUP, starting clone !AS -> !AS", -
             Fac, SrcDisk, TarDisk1 )
$ IF ( DryRun )
$ THEN wso "%''Fac'-I-ECHO, ..."
$      wso "  $ MOUNT /FOREIGN ''TarDisk1'"
$      wso "  $ BACKUP ''SrcDisk' /IMAGE /IGNORE=INTERLOCK /PROGRESS=''ProgInt' -"
$      wso "      ''TarDisk' /NOINITIALIZE  ! preserve larger size, etc."
$      wso "  $ DISMOUNT ''TarDisk1'"
$ ELSE ! The clone/copy, for real...
$      DEFINE /USER sys$output nla0:
$      DEFINE /USER sys$error  nla0:
$      MOUNT /FOREIGN 'TarDisk1'
$      !
$      BACKUP 'SrcDisk' /IMAGE /IGNORE=INTERLOCK /PROGRESS='ProgInt' -
         'TarDisk1' /NOINITIALIZE  ! preserve larger size, etc.
$      !
$      IF ( F$GETDVI( TarDisk1, "MNT" ) ) THEN DISMOUNT 'TarDisk1'
$      wso ""
$      wso F$FAO( "%!AS-I-DISMOUNT, target !AS is dismounted, ready for checkout...", -
                  Fac, TarDisk1 )
$ ENDIF
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
$ IF ( .NOT. DryRun )
$ THEN wso ""
$      wso hline
$      wso "Recommendation:  Manually do --"
$      wso "  a) Mount the just-cloned ''TarDisk1' process-private and write-only:"
$      wso "     $ MOUNT /NOWRITE ''TarDisk1' ''VolLbl'"
$      wso "     to check-out the integrity/completeness of the backup/clone operation."
$      IF Src_is_VolShadow .OR. ( tdcount .GT. 1 )
$      THEN IF ( Src_is_VolShadow )
$           THEN sdisk = SrcDisk
$           ELSE sdisk = "DSAxxx:"  ! as an example...
$           ENDIF
$           wso "  and/or --"
$           wso "  b) Dismount the old Shadow-Set Volume from the cluster:"
$           wso "     $ DISMOUNT /CLUSTER ''sdisk'"
$           wso "         Note: Any open files on this volume may prevent the dismount."
$           wso "     Then (re)mount the Shadow-Set cluster-wide using the newly-cloned"
$           wso "     ''TarDisk1' as the first member, plus any other shadow-set members,"
$           wso "     to Copy/Merge operation for ''sdisk' --"
$           wso "     $ MOUNT /CLUSTER /NOASSIST /NOREBUILD ''sdisk' /SHADOW=(''TDisks') ''VolLbl'"
$      ENDIF
$      wso hline
$      wso ""
$ ENDIF
$ !
$Done:
$NETWORK:
$ DCL$CALL DeleteGloSyms "DL$expsize,DL$maxfiles,DL$volsize,DL$maxblks"
$ IF ( F$TYPE( prv ) .NES. "" ) THEN prv = F$SETPRV( prv )
$ EXIT 1  ! 'F$VERIFY(0)'
$ !
$CtrlY:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  DISK$CLONE.COM is a script which copies/clones one source disk (device)
  to another target disk, using BACKUP /IMAGE /NOINITIALIZE.

  The target disk is pre-initialized to have its own, typically larger,
  disk geometry and characteristics, but inherits the source disks's
  ODS-2/5 structure, cluster-size and volume label.

  use:
    $ @DISK$CLONE SourceDisk VolumeLabel TargetDisk1[,TargetDisk2]... -
           [ [/VERBOSE] [/LOG] [/DRYRUN] [[/BATCH] [/SUBMIT]] ]

     or:

    $ @DISK$CLONE /HELP

         /HELP, /VERBOSE, /LOG, /DRYRUN, /BATCH, /SUBMIT can also be:
           --help, --verbose, --dryrun, --log, --batch, --submit,
           or -help or help, etc.

  where:

  SourceDisk  (P1) -- The source-disk (volume) to copy/clone to target(s).
               This volume may be either a VMS Shadow-Set Volume (DSA2:)
               or a "just-a-disk" non-shadowed volume ($1$DGA24: or DKA1:).

  VolumeLabel (P2) -- The volume label of the SourceDisk, which will be
               used to identify the cloned target disk(s).

  TargetDisk1 (P3) -- One or more target disks; if more than one target
  TargetDisk2  disk, then specify as a comma-separated list ($1$DGA24:
  TargetDiskN  or $1$DGA24:,$1$DGA224: or $1$DGA24:,$1$DGA224:,$1$DGA424:).
               Each of these target disks will be initialized to set their
               capacities (available disk blocks) to the maximum(s) avail-
               able, but will also receive the source disk's /STRUCTURE
               (either ODS-5 or ODS-2), /CLUSTER_SIZE and volume label.

  /LOG      -- Option to redirect clone operations (subprocess) output to
               a log-file (rather than to the user's terminal); if used,
               this qualifier creates the log-file in the user's LOGS:
               subdirectory (via logical name LOGS), with filename
               "DISK$CLONE_<srcdisk>_<vollabel>.LOG".

  /DRYRUN   -- Causes this command procedure to display all copy/clone
               commands (including target disk initialization, mounts
               and dismounts) without actually executing them -- for
               evaluation purposes only.

  /SUBMIT   -- (Re)Submits this command procedure to the default batch
  or /BATCH    queue where the copy/clone BACKUP operation can run
               unattended.

  /HELP     -- Displays this text.

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
