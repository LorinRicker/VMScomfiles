$ ! COMMON_LOGICALS.COM -- define common logical names             'F$VERIFY(0)'
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
$MAIN:
$ ON ERROR THEN EXIT %X2C
$ !
$ IF F$TYPE( Lbase ) .EQS. "" -
  THEN LBase = F$PARSE( "sys$login",,,"DEVICE","SYNTAX_ONLY" ) -
             + "[" + F$EDIT( F$GETJPI( "","USERNAME" ),"TRIM,UPCASE" )
$ Rooted = ".] /TRANSLATION_ATTRIBUTES=(CONCEALED,TERMINAL)"
$ LNode  = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ !
$ IF ( P1 .NES. "" )  ! one or more parameters given
$ THEN i = 1
$MLoop:
$      ! Run through P1...P8:
$      IF ( i .GE. 9 ) THEN EXIT 1
$      IF ( P'i' .EQS. "" ) THEN EXIT 1
$      arg = F$EDIT( P'i', "UPCASE,COLLAPSE")
$      IF ( arg .EQS. "MFD" )
$      THEN CALL DefMFD
$      ELSE CALL DefLnm "''arg'" "" "''LBase'"
$      i = i + 1
$      GOTO MLoop
$ ELSE ! Just do a known, predefined group
$      CALL DefMFD
$      CALL DefLnm "COM"  "" "''LBase'" ",SITE$UTILS"
$      CALL DefLnm "LOGS" "" "''LBase'" ""
$      CALL DefLnm "LIB"  "" "''LBase'" ""
$ ENDIF
$ !
$ !
$ !
$$DefMFD:  SUBROUTINE
$ ! Define both job-logical names and global symbols
$ ! for the Master File Directory (MFD) on _this_ disk:
$ SET NOON
$ DEFINE /JOB /NOLOG mfd  "[000000]"
$ DEFINE /JOB /NOLOG mfdr "[000000...]"
$ mfd  == "[000000]"
$ mfdr == "[000000...]"
$ EXIT 1
$ !
$ ENDSUBROUTINE  ! DefMFD
$ !
$DefLnm:  SUBROUTINE
$ ! Test subdirectory existence, create if needed --
$ ! then define a job-logical for that subdirectory:
$ ! P1 : Subdirectory name to detect, create if missing
$ ! P2 : Logical name to create for subdirectory;
$ !      use P1 if P2 is null
$ ! P3 : Root/base user directory, e.g. "SYS$LOGIN_DEVICE:[username";
$ !      use username as base directory name if P3 is null
$ ! P4 : Optional additional search-list elements ",dirspec[,...]";
$ !      ignored if null
$ !
$ ON CONTROL_Y THEN GOSUB DLNMCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ dirspec = "''P3']''P2'.DIR;1"
$ dir     = "''P3'.''P2']"
$ !
$ IF ( F$SEARCH( dirspec ) .EQS. "" )
$ THEN CREATE /DIRECTORY /OWNER=PARENT /PROTECTION=(S:RWE,O:RWE,G,W) /LOG 'dir'
$ ENDIF
$ !
$ DEFINE /JOB /NOLOG 'P2' "''dir'''P4'"
$ !
$ EXIT 1
$ !
$DLNMCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! DefLnm
$ !
