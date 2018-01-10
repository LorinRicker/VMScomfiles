$ ! MKLD.COM                                                       ! 'F$VERIFY(1)'
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
$ ! use: @MKLD [ ldDisk ] [ ldUnit ] [ DevSize ] [ ldLogical ]
$ !
$ ON CONTROL THEN GOSUB CtrlY
$ ON ERROR THEN EXIT %X2C
$ !
$ UName      = F$EDIT( F$GETJPI( "", "USERNAME" ), "TRIM,LOWERCASE" )
$ ldSubDir   = "LDISKS"
$ ldDir      = "[''UName'.''ldSubDir']"
$ IF ( F$SEARCH( "[''UName']''ldSubDir'.DIR" ) .EQS. "" )
$ THEN CREATE /DIRECTORY /LOG ['UName'.'ldSubDir'] /OWNER='UName'
$ ENDIF
$ ldDisks    = ldDir + "*.DSK"
$ defldDisk  = F$SEARCH( ldDisks )  ! use first LDdisk-file found as a default, or...
$ IF ( defldDisk .EQS. "" ) THEN defldDisk = "[''UName'.LDisks]RUBY$MINE.DSK"
$ defldDisk = F$PARSE( defldDisk, ".DSK", , "NAME" ) + F$PARSE( defldDisk, ".DSK", , "TYPE" )
$ !
$ defldUnit  = "$254$LDA1000:"
$ defDevSize = "16000"
$ defldLNM   = "LDISK$mydisk"
$ defldVol   = "mydisk"
$ !
$ IF ( P1 .NES. "" )
$ THEN ldDisk = "''P1'"
$ ELSE READ sys$command answer /END_OF_FILE=Done -
         /PROMPT="LDA disk filename [''defldDisk']: "
$      ldDisk = F$PARSE( answer, defldDisk, ldDir ) - ";"
$ ENDIF
$ IF ( P2 .NES. "" )
$ THEN ldUnit = "''P2'"
$ ELSE READ sys$command answer /END_OF_FILE=Done -
         /PROMPT="LDA unit [''defldUnit']: "
$      ldUnit = F$PARSE( answer, defldUnit, , "DEVICE", "SYNTAX_ONLY" )
$ ENDIF
$ IF ( P3 .NES. "" )
$ THEN DevSize = "''P3'"
$ ELSE READ sys$command answer /END_OF_FILE=Done -
         /PROMPT="Size in blocks for ''ldUnit' [''defdevsize']: "
$      DevSize = F$PARSE( answer, defdevsize, , "NAME", "SYNTAX_ONLY" )
$ ENDIF
$ IF ( P4 .NES. "" )
$ THEN ldLNM = "''P4'"
$ ELSE READ sys$command answer /END_OF_FILE=Done -
         /PROMPT="Logical name for ''ldUnit' [''defldLNM']: "
$      ldLNM = F$PARSE( answer, defldLNM, , "NAME", "SYNTAX_ONLY" )
$ ENDIF
$ !
$ IF ( F$SEARCH( ldDisk ) .EQS. "" )
$ THEN ! LD-disk file doesn't yet exist, so create it:
$      LD CREATE /SIZE='DevSize' /CONTIGUOUS /LOG 'ldDisk'
$      IniDisk = "TRUE"  ! ...will need to INIT it too
$ ELSE IniDisk = "FALSE"
$ ENDIF
$ !
$ IF ( .NOT. F$GETDVI( ldunit, "EXISTS" ) )
$ THEN ! Make it an LDAxxx: unit, if not yet connected:
$      LD CONNECT 'ldDisk' 'ldUnit' 'ldLNM'
$ ENDIF
$ !
$ ! Logical Disk is initialized "only once":
$ IF ( IniDisk )
$ THEN ! Initialize only if just now created:
$      ! (Manually re-INIT the LDAxxx: if ODS-2 is wanted, not ODS-5.)
$      INITIALIZE 'ldUnit' /STRUCTURE=5 'ldVol'
$ ENDIF
$ !
$ IF ( .NOT. F$GETDVI( ldUnit, "MNT" ) )
$ THEN prv = F$SETPRV( "SYSPRV,SYSNAM,VOLPRO" )
$      MOUNT /NOASSIST 'ldUnit' 'ldVol' 'ldLNM'
$      DEFINE /PROCESS /NOLOG LDDISK$'ldVol' sys$login_device:'ldDisk'
$      SHOW LOGICAL /FULL *DISK$'ldVol'
$      prv = F$SETPRV( prv )
$ ENDIF
$ !
$ IF ( IniDisk )
$ THEN TYPE /PAGE sys$input
  Once mounted, Logical Disk internal directory(ies) need be created once:
  e.g.:  $ CREATE /DIRECTORY /LOG /OWNER=[LRICKER] LDISK$mydisk:[dir]  !... etc.

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
