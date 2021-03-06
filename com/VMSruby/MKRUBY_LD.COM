$ ! MKRUBY_LD.COM                                                  ! 'F$VERIFY(0)'
$ !
$ ! Copyright � 2017-2018 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ! use: @MKRUBY_LD [ ldunit ] [ username ] 
$ !
$ ON CONTROL THEN GOSUB CtrlY
$ ON ERROR THEN EXIT %X2C
$ !
$ IF ( P1 .NES. "" )
$ THEN rubyldunit = "''P1'"
$ ELSE rubyldunit = "LDA1024:"
$      alloc      = "$254$"
$ ENDIF
$ IF ( P2 .NES. "" )
$ THEN UName = "''P2'"
$ ELSE UName = F$EDIT( F$GETJPI( "", "USERNAME" ), "TRIM,LOWERCASE" )
$ ENDIF
$ !
$ ldev        = F$TRNLNM( "SYS$LOGIN_DEVICE", "LNM$JOB" )
$ rubydisk    = ldev + "[''UName'.RUBY]RUBY$MINE.DSK"
$ rubydsize   = "32000"
$ rubyldlnm   = "LDISK$RUBY"
$ rubyldvol   = "RUBYMINE"
$ rubydisklnm = "DISK$RUBY"
$ rubyminedir = "''rubydisklnm':[''UName'.ruby]"
$ rubyminelib = "''rubydisklnm':[''UName'.ruby.lib]"
$ !
$ IF ( F$SEARCH( rubydisk ) .EQS. "" ) -
  THEN LD CREATE /SIZE='rubydsize' /CONTIGUOUS /LOG 'rubydisk'
$ !
$ IF ( .NOT. F$GETDVI( rubyldunit, "EXISTS" ) ) -
  THEN LD CONNECT 'rubydisk' 'rubyldunit' 'rubyldlnm'
$ !
$ ! Logical Disk is initialized "only once":
$ ! INITIALIZE 'alloc''rubyldunit' /STRUCTURE=5 'rubyldvol'
$ !
$ IF ( .NOT. F$GETDVI( rubyldunit, "MNT" ) )
$ THEN prv = F$SETPRV( "SYSPRV,SYSNAM,VOLPRO" )
$      MOUNT /SYSTEM /NOASSIST 'alloc''rubyldunit' 'rubyldvol' 'rubydisklnm'
$      prv = F$SETPRV( prv )
$ ENDIF
$ !
$ ! Once mounted, Logical Disk internal directory(ies) need be created once:
$ ! CREATE /DIRECTORY /LOG /OWNER=['UName'] 'rubyminedir'
$ !
$ ! Perform any file/dir protection-mask adjustments manually...
$ ! Copy *.rb files to target directories manually...
$ !
$ DEFINE /JOB /NOLOG 'rubyldlnm' 'rubydisk'
$ SHOW LOGICAL /FULL *RUBY*
$ !
$Done:
$ EXIT 1  ! 'F$VERIFY(0)'
$ !
$CtrlY:
$ RETURN %X2C
$ !
