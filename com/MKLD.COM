$ ! MKLD.COM                                                       ! 'F$VERIFY(0)'
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
$ ! use: @MKLD [ CREATE | MOUNT (D) | HELP ] -
$ !            [ ldDisk ] [ ldUnit ] [ ldVolLbl ] [ [/]SYSTEM ]
$ !
$ ON CONTROL THEN GOSUB CtrlY
$ ON ERROR THEN EXIT %X2C
$ !
$ wso = "WRITE sys$output"
$ Verbose = F$TRNLNM( "TOOLS$DEBUG" )
$ COLON     = ":"
$ HYPHEN    = "-"
$ SEMICOLON = ";"
$ SLASH     = "/"
$ !
$ IF ( F$TYPE( DCL$CALL ) .EQS. "" )
$ THEN @lmr$login:DCL$SUBROUTINE_LIBRARY Setup TRUE
$ ENDIF
$ !
$ proc = F$ENVIRONMENT( "PROCEDURE" )
$ Fac  = F$PARSE( proc, , , "NAME", "SYNTAX_ONLY" )
$ !
$ p1val = P1 - HYPHEN - HYPHEN - SLASH
$ p1val = F$EXTRACT( 0, 1, F$EDIT( p1val, "UPCASE,COLLAPSE" ) )
$ CmdSet = "CREATE|MOUNT "
$ DCL$CALL CmdParse "''p1val'" mkld$Cmd "MOUNT" "''CmdSet'"
$ CreateIt = ( mkld$Cmd .EQS. "CREATE" )
$ MountIt  = ( mkld$Cmd .EQS. "CREATE" ) .OR. ( mkld$Cmd .EQS. "MOUNT" )
$ IF ( p1val .EQS. "H" ) .OR. ( p1val .EQS. "?" ) THEN GOTO Help
$ !
$ IF ( P5 .NES. "" )
$ THEN P5 = P5 - SLASH  ! "/SYSTEM" --> "SYSTEM"
$      SysMount = F$EXTRACT( 0, 3, P5 ) .EQS. "SYS"
$ ELSE SysMount = "FALSE"
$ ENDIF
$ !
$ thisDisk   = F$TRNLNM("SYS$LOGIN_DEVICE")
$ UName      = F$EDIT( F$GETJPI( "", "USERNAME" ), "TRIM,LOWERCASE" )
$ ldSubDir   = "LDISKS"
$ ldDir      = "[''UName'.''ldSubDir']"
$ IF ( F$SEARCH( "[''UName']''ldSubDir'.DIR" ) .EQS. "" )
$ THEN CREATE /DIRECTORY /LOG ['UName'.'ldSubDir'] /OWNER='UName'
$ ENDIF
$ DEFINE /JOB /NOLOG 'ldSubDir' 'thisDisk'['UName'.'ldSubDir']
$ ldDisks    = ldDir + "*.DSK"
$ defldDisk  = F$SEARCH( ldDisks )  ! use first LDdisk-file found as a default, or...
$ IF ( defldDisk .EQS. "" ) THEN defldDisk = "[''UName'.LDisks]RUBY$MINE.DSK"
$ defldDisk = F$PARSE( defldDisk, ".DSK", , "NAME" ) + F$PARSE( defldDisk, ".DSK", , "TYPE" )
$ !
$ alloc       = "$254$"    ! for CLASS8 system, CLASS cluster
$ defldUnit   = "LDA1000:"
$ defDevSize  = "16000"
$ !
$ IF ( P2 .NES. "" )
$ THEN answer = "''P2'"
$ ELSE READ sys$command answer /END_OF_FILE=Done -
         /PROMPT="Filename for Logical Disk (LDA) [''defldDisk']: "
$ ENDIF
$ ldDisk = F$PARSE( answer, defldDisk, ldDir ) - SEMICOLON
$ !
$ IF ( P3 .NES. "" )
$ THEN answer = "''P3'"
$ ELSE READ sys$command answer /END_OF_FILE=Done -
         /PROMPT="LDA unit [''defldUnit']: "
$ ENDIF
$ IF ( answer .NES. "" )
$ THEN IF ( F$EXTRACT( 0, 3, F$EDIT( answer, "COLLAPSE,UPCASE" ) ) .NES. "LDA" )
$      THEN answer = "LDA" + answer - COLON + COLON
$      ENDIF
$ ENDIF
$ ldUnit = F$PARSE( answer, defldUnit, , "DEVICE", "SYNTAX_ONLY" )
$ defldVolLbl = F$PARSE( ldDisk, , , "NAME", "SYNTAX_ONLY" )
$ !
$ IF ( P4 .NES. "" )
$ THEN answer = "''P4'"
$ ELSE READ sys$command answer /END_OF_FILE=Done -
         /PROMPT="Volume label for ''ldUnit' [''defldVolLbl']: "
$ ENDIF
$ ldVolLbl = F$PARSE( answer, defldVolLbl, , "NAME", "SYNTAX_ONLY" )
$ ldLNM    = "LDISK$" + ldVolLbl
$ !
$ IniDisk = "FALSE"
$ IF ( CreateIt )
$ THEN IF ( F$SEARCH( ldDisk ) .EQS. "" )
$      THEN ! LD-disk file doesn't yet exist, so create it:
$           READ sys$command answer /END_OF_FILE=Done -
              /PROMPT="Size in blocks for ''ldUnit' [''defdevsize']: "
$           DevSize = F$PARSE( answer, defdevsize, , "NAME", "SYNTAX_ONLY" )
$           IF Verbose THEN wso "%''Fac'-I-ECHO, $ LD CREATE /SIZE=''DevSize' /CONTIGUOUS /LOG ''ldDisk'"
$           LD CREATE /SIZE='DevSize' /CONTIGUOUS /LOG 'ldDisk'
$           IniDisk = "TRUE"  ! ...will need to INIT it too
$      ENDIF
$ ENDIF
$ !
$ IF ( .NOT. F$GETDVI( ldUnit, "EXISTS" ) )
$ THEN ! Make it an LDAxxx: unit, if not yet connected:
$      IF Verbose THEN wso "%''Fac'-I-ECHO, $ LD CONNECT ''ldDisk' ''ldUnit' ''ldLNM'"
$      LD CONNECT 'ldDisk' 'ldUnit' 'ldLNM'
$ ENDIF
$ !
$ ! Logical Disk is initialized "only once":
$ IF ( IniDisk )
$ THEN ! Initialize only if just now created:
$      ! (Manually re-INIT the LDAxxx: if ODS-2 is wanted, not ODS-5.)
$      IF Verbose THEN wso "%''Fac'-I-ECHO, $ INITIALIZE /STRUCTURE=5 ''alloc'''ldUnit' ''ldVolLbl'"
$      INITIALIZE /STRUCTURE=5 'alloc''ldUnit' 'ldVolLbl'
$ ENDIF
$ !
$ IF ( MountIt )
$ THEN IF ( .NOT. F$GETDVI( ldUnit, "MNT" ) )
$      THEN IF ( SysMount )
$           THEN Qual  = "/SYSTEM"
$                DefQual = Qual + "/EXECUTIVE_MODE"
$                prv = F$SETPRV( "CMEXEC,SYSNAM,SYSPRV,VOLPRO" )
$           ELSE Qual  = ""
$                DefQual = "/JOB"
$           ENDIF
$           wso "%''Fac'-I-ECHO, $ MOUNT /NOASSIST''Qual' ''alloc'''ldUnit' ''ldVolLbl' ''ldLNM'"
$           MOUNT /NOASSIST 'Qual' 'alloc''ldUnit' 'ldVolLbl' 'ldLNM'
$           IF Verbose THEN wso "%''Fac'-I-ECHO, $ DEFINE /JOB /NOLOG LDFILE$''ldVolLbl' ''ldDisk'"
$           DEFINE /JOB /NOLOG LDFILE$'ldVolLbl' 'ldDisk'
$           IF ( SysMount ) THEN DefQual = Qual
$           SHOW LOGICAL 'DefQual' /FULL *DISK$'ldVolLbl'
$           SHOW LOGICAL /JOB /FULL LDFILE$*
$           SHOW LOGICAL /JOB /FULL LDISKS
$           IF ( SysMount ) THEN prv = F$SETPRV( prv )
$      ENDIF
$ ENDIF
$ !
$ IF ( IniDisk )
$ THEN TYPE sys$input

  The LD logical disk has been created and initialized ODS-5, and mounted,
  but no directories yet exist.

  Once mounted, Logical Disk internal directory(ies) need be created once:
    $ CREATE /DIRECTORY /LOG /OWNER=[LRICKER] LDISK$mydisk:[dir]  !... etc.

  Perform any directory and/or file protection-mask adjustments manually...

$ !
$ ENDIF
$ !
$Done:
$ EXIT 1  ! 'F$VERIFY(0)'
$ !
$CtrlY:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  MKLD.COM is a script which conditionally creates, connects, initializes
  and mounts Logical Disks -- files which have an internal ODS-5 file
  system which function as file-based disk volumes, managed with the free-
  ware LD utility and logical disk driver.

  use:  $ [1m@MKLD[0m [ [1mCREATE[0m | [1mMOUNT[0m (D) | [1mHELP[0m ] -
                [ [1mldDisk[0m ] [ [1mldUnit[0m ] [ [1mldVolLbl[0m ] [ [[1m/[0m][1mSYSTEM[0m ]

  where:

  [1mCREATE[0m --  Forces a new (or new version of) Logical Disk to be created.
             A created Logical Disk will be mounted (and /SYSTEM if this
             qualifier is specified).
  [1mMOUNT[0m --   Mounts a Logical Disk, presuming that it's been created; this
             command does not create a Logical Disk if it doesn't exist.
  [1mHELP[0m --    This help text.

  [1mldDisk[0m --  The filename of the logical disk file to be managed.
             This filename is assumed (by convention) to have a
             file type of .DSK, and is assumed to be found in a
             user-private subdirectory [<username>.LDISKS] (which
             is created as a courtesy).

             If this logical disk file does not exist, it is created,
             LD-connected, initialized with an ODS-5 file system (and
             volume id), and mounted.

             If this logical disk already exists, it will be LD-connected
             (if necessary), is assumed to be initialized with a file
             system, and then is mounted.

  [1mldUnit[0m --  The physical device name for the logical disk, in the
             form LDAxxxx:, where "xxxx" is the unit number for
             that logical disk -- This is chosen in the range
             1..9999, and once chosen, is usually treated as the
             "assigned" or conventional unit number for that logical
             disk.  This script also prepends the allocation class
             "$254$" to this physical device name, e.g. $254$LDA1024:

  [1mldVolLbl[0m -- The logical disk's Volume Id (string) which is determined
             and assigned when the logical disk is INITIALIZEd (as an
             ODS-5 structure by default).

  [1m/SYSTEM[0m -- An option which mounts the logical disk volume system-wide,
             and requires CMEXEC, SYSNAM, SYSPRV and VOLPRO privileges.

  Values for any missing, required command-line arguments will be prompted.

$ !
$ EXIT 1  ! 'F$VERIFY(0)'
$ !
