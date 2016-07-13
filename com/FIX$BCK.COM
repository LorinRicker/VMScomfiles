$ ! FIX$BCK.COM                                                    'F$VERIFY(0)'
$ !
$ ! Copyright © 1999-2016 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ! P1: specification of the BACKUP saveset
$ !
$ ! This procedure resets the record format and record length attributes
$ ! of a BACKUP saveset -- savesets can get "broken" during certain sorts
$ ! of file transfers -- such as FTP in ascii/text mode.
$ ! This procedure reads the (undocumented) saveset record attributes directly
$ ! out of the target file, calculates a better block/record size, and fixes-up
$ ! the saveset accordingly.
$ !
$ ON ERROR THEN EXIT %X2C
$ ON CONTROL_Y THEN EXIT %X2C
$ !
$ P1 = F$PARSE(P1,"sys$disk:[].bck")
$ !
$ ! First render the saveset readable, and implicitly check that the file exists:
$ SET FILE /ATTRIBUTES=(RFM:FIX,MRS:512,LRL=512,ORG=SEQ,RAT=NONE) 'P1'
$
$ OPEN /ERROR=whoops /READ bss 'P1'
$ Read /ERROR=whoops /END_OF_FILE=whoops bss Record
$ CLOSE /NOLOG bss
$
$ ! Find the blocksize from within the record:
$ BlockSize = 0
$ BBH_L_BLOCKSIZE = %x28*8
$ BlockSize = F$CVUI(BBH_L_BLOCKSIZE, 32, Record)
$ IF ( BlockSize .GE. 2048 ) .AND. ( BlockSize .LE. 65535 )
$ THEN SET FILE /ATTRIBUTES=(RFM:FIX,LRL='BlockSize',MRS='BlockSize',RAT=NONE) 'P1'
$      BACKUP 'P1' /SAVE_SET /LIST
$ ELSE WRITE sys$error "%FIX$BCK-E-BADBLKSIZE, unexpected block size ''BlockSize"
$ ENDIF
$ EXIT  !'F$VERIFY(0)'
$ !
$whoops:
$ WRITE sys$error "%FIX$BCK-E-WHOOPS, error reading record-size of ''P1'"
$ EXIT  !'F$VERIFY(0)'
$ !
