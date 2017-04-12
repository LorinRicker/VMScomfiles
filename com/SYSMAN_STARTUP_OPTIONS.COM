$ ! SYSMAN_STARTUP_OPTIONS.COM --                                  'F$VERIFY(0)'
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
$ !
$ !  Configures a VMS system for startup logging into SYS$SYSTEM:STARTUP.LOG
$ !
$ !  Usage:  $ @SYSMAN_STARTUP_OPTIONS [ SHOW (D) | SET | VERSIONLIMIT ]
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Proc   = F$ENVIRONMENT("PROCEDURE")
$ Proc   = Proc - F$PARSE(Proc,,,"VERSION","SYNTAX_ONLY")
$ Fac    = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ !
$ VMSStartupLog = "SYS$SPECIFIC:[SYSEXE]STARTUP.LOG"  ! Node-specific
$ !
$ VersLimit = "10"  ! Edit this value for a different version_limit on VMSStartupLog
$ !
$ IF ( P1 .EQS. "" ) THEN P1 = "SHOW"
$ options = ",SHO,SET,VER,"
$ optL    = F$LENGTH( options )
$ P1      = F$EXTRACT( 0, 3, F$EDIT( P1, "UPCASE,TRIM") )
$ IF ( F$LOCATE( ",''P1',", options ) .LT. optL )
$ THEN setopt = ( P1 .EQS. "SET" )
$      shoopt = ( P1 .EQS. "SHO" ) .OR. setopt
$      veropt = ( P1 .EQS. "VER" ) .OR. setopt
$ ELSE wso "%''Fac'-F-UNKNOWN, bad/unknown command option: ''P1'"
$      EXIT %x2C
$ ENDIF
$ !
$ prv = F$SETPRV("SYSPRV")
$ !
$ IF shoopt
$ THEN wso ""
$      wso "%''Fac'-I-SHOW, showing current configuration:"
$      MCR SYSMAN   
! Don't set CLUSTERWIDE environment, just do this for CURRENT NODE, repeat as needed.

! === Show Current Startup ====================
PARAMETER USE CURRENT
PARAMETER SHOW STARTUP_P2
STARTUP SHOW OPTIONS

exit
$ ENDIF  ! shoopt
$ !
$ IF setopt
$ THEN wso ""
$      wso "%''Fac'-I-SET, setting log-file configuration:"
$      MCR SYSMAN   
! Don't set CLUSTERWIDE environment, just do this for CURRENT NODE, repeat as needed.

! === Set Startup and Confirm  ====================
STARTUP SET OPTIONS /VERIFY=PARTIAL /OUTPUT=FILE /CHECKPOINTING

PARAMETER USE CURRENT
PARAMETER SHOW STARTUP_P2
STARTUP SHOW OPTIONS

exit
$ ENDIF  ! setopt
$ !
$ IF veropt
$ THEN wso ""
$      wso "%''Fac'-I-LOGFILE, setting /VERSION_LIMIT=''VersLimit' on ''VMSStartupLog'"
$      IF ( F$SEARCH(VMSStartupLog) .EQS. "" )  ! First-version exists?
$      THEN CREATE /NOLOG 'VMSStartupLog'       ! No? touch it, create empty file...
$      ENDIF
$      ! Initialize file STARTUP.LOG to attach /VERSION_LIMIT to...
$      IF ( F$SEARCH("''VMSStartupLog';-1") .NES. "" )
$      THEN PURGE /KEEP='VersLimit' /NOLOG 'VMSStartupLog'
$      ENDIF
$      SET FILE /VERSION_LIMIT='VersLimit' /NOLOG 'VMSStartupLog'
$ ENDIF
$ !
$Done:
$ SET NOON
$ IF ( F$TYPE(prv) .EQS. "STRING" ) THEN prv = F$SETPRV(prv)
$ EXIT  ! 'F$VERIFY(0)'
$ !
$Ctrl_Y:
$ RETURN %X2C
