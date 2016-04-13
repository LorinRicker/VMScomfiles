$ ! DISKSPACE$REPORT.COM --                                        'F$VERIFY(0)'
$ !
$ ! Copyright © 2014-2016 by Lorin Ricker.  All rights reserved, with acceptance,
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
$DiskSpace:  SUBROUTINE
$ ON CONTROL_Y THEN GOSUB DSCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ mask       = %X7FFFFFFF
$ maskdiv100 = mask / 100
$ !
$ wso F$FAO( "Disk Space !#*=", 44 )
$DSpc0:
$ dsk = F$DEVICE( , "DISK" )
$ IF ( dsk .EQS. "" ) THEN GOTO DSpcEnd
$ IF ( .NOT. F$GETDVI( dsk, "MNT" ) )     -  ! not mounted?
  .OR. ( F$GETDVI( dsk, "FOR" ) )         -  ! mounted foreign?
  .OR. ( F$GETDVI( dsk, "SWL" ) )         -  ! software-locked?
  .OR. ( F$GETDVI( dsk, "SHDW_MEMBER" ) ) -  ! a shadow-set member (not the shadow-set itself)?
  THEN GOTO DSpc0
$ voln  = F$GETDVI( dsk, "VOLNAM" )
$ total = F$GETDVI( dsk, "MAXBLOCK" )
$ free  = F$GETDVI( dsk, "FREEBLOCKS" )
$ used  = total - free
$ dsk   = dsk - "_"  ! strip leading underscore
$ !
$DSrange:
$ IF ( free .LT. 0 ) .OR. ( used .LT. 0 ) .OR. ( total .LT. 0 )
$ THEN free  = ( free  / 2 ) .AND. mask
$      used  = ( used  / 2 ) .AND. mask
$      total = ( total / 2 ) .AND. mask
$ ENDIF
$ !
$ IF ( used .GT. maskdiv100 ) .OR. ( free .GT. maskdiv100 ) .OR. ( total .GT. maskdiv100 )
$ THEN free  = free  / 10
$      used  = used  / 10
$      total = total / 10
$      GOTO DSrange
$ ENDIF
$ !
$ freepct = ( free * 100 ) / total
$ usedpct = ( used * 100 ) / total
$ wso F$FAO( "  !20AS!12AS !2SL% free, !2SL% used", dsk, voln, freepct, usedpct )
$ GOTO DSpc0
$ !
$DSpcEnd:
$ wso F$FAO( "!#*=", 55 )
$ wso ""
$ EXIT 1
$ !
$DSCtrl_Y:
$ EXIT %X2C
$ ENDSUBROUTINE  ! DiskSpace
$ !
$ !
$Main:
$ CALL DiskSpace
$ EXIT 1
$ !
