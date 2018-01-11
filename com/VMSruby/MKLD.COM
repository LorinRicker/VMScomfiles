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
$ ! use: @MKLD [ ldDisk ] [ ldUnit ] [ ldVolLbl ] [ [/]SYSTEM ]
$ !
$ ON CONTROL THEN GOSUB CtrlY
$ ON ERROR THEN EXIT %X2C
$ !
$ wso = "WRITE sys$output"
$ Verbose = F$TRNLNM( "TOOLS$DEBUG" )
$ !
$ proc = F$ENVIRONMENT( "PROCEDURE" )
$ Fac  = F$PARSE( proc, , , "NAME", "SYNTAX_ONLY" )
$ !
$ IF ( P4 .NES. "" )
$ THEN P4 = P4 - "/"  ! "/SYSTEM" --> "SYSTEM"
$      SysMount = F$EXTRACT( 0, 3, P4 ) .EQS. "SYS"
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
$ IF ( P1 .NES. "" )
$ THEN answer = "''P1'"
$ ELSE READ sys$command answer /END_OF_FILE=Done -
         /PROMPT="LDA disk filename [''defldDisk']: "
$ ENDIF
$ ldDisk = F$PARSE( answer, defldDisk, ldDir ) - ";"
$ IF ( P2 .NES. "" )
$ THEN answer = "''P2'"
$ ELSE READ sys$command answer /END_OF_FILE=Done -
         /PROMPT="LDA unit [''defldUnit']: "
$ ENDIF
$ ldUnit = F$PARSE( answer, defldUnit, , "DEVICE", "SYNTAX_ONLY" )
$ defldVolLbl = F$PARSE( ldDisk, , , "NAME", "SYNTAX_ONLY" )
$ IF ( P3 .NES. "" )
$ THEN answer = "''P3'"
$ ELSE READ sys$command answer /END_OF_FILE=Done -
         /PROMPT="Volume label for ''ldUnit' [''defldVolLbl']: "
$ ENDIF
$ ldVolLbl = F$PARSE( answer, defldVolLbl, , "NAME", "SYNTAX_ONLY" )
$ ldLNM    = "LDISK$" + ldVolLbl
$ !
$ IF ( F$SEARCH( ldDisk ) .EQS. "" )
$ THEN ! LD-disk file doesn't yet exist, so create it:
$      READ sys$command answer /END_OF_FILE=Done -
         /PROMPT="Size in blocks for ''ldUnit' [''defdevsize']: "
$      DevSize = F$PARSE( answer, defdevsize, , "NAME", "SYNTAX_ONLY" )
$      IF Verbose THEN wso "%''Fac'-I-ECHO, $ LD CREATE /SIZE=''DevSize' /CONTIGUOUS /LOG ''ldDisk'"
$      LD CREATE /SIZE='DevSize' /CONTIGUOUS /LOG 'ldDisk'
$      IniDisk = "TRUE"  ! ...will need to INIT it too
$ ELSE IniDisk = "FALSE"
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
$ IF ( .NOT. F$GETDVI( ldUnit, "MNT" ) )
$ THEN IF ( SysMount )
$      THEN Qual  = "/SYSTEM"
$           DQual = Qual + "/EXECUTIVE_MODE"
$           prv = F$SETPRV( "CMEXEC,SYSNAM,SYSPRV,VOLPRO" )
$      ELSE Qual  = ""
$           DQual = "/JOB"
$      ENDIF
$      IF Verbose THEN wso "%''Fac'-I-ECHO, $ MOUNT /NOASSIST''Qual' ''alloc'''ldUnit' ''ldVolLbl' ''ldLNM'"
$      MOUNT /NOASSIST 'Qual' 'alloc''ldUnit' 'ldVolLbl' 'ldLNM'
$      IF Verbose THEN wso "%''Fac'-I-ECHO, $ DEFINE /JOB /NOLOG LDFILE$''ldVolLbl' ''ldDisk'"
$      DEFINE /JOB /NOLOG LDFILE$'ldVolLbl' 'ldDisk'
$      IF ( SysMount ) THEN DQual = Qual
$      SHOW LOGICAL 'DQual' /FULL *DISK$'ldVolLbl'
$      SHOW LOGICAL /JOB /FULL LDFILE$*
$      SHOW LOGICAL /JOB /FULL LDISKS
$      IF ( SysMount ) THEN prv = F$SETPRV( prv )
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
