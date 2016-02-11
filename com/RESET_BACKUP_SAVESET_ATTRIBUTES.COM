$ ! RESET_BACKUP_SAVESET_ATTRIBUTES.COM
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
$ ! P1  is the specification of the BACKUP saveset
$ !
$ ! This procedure resets the record format and record
$ ! length attributes of a BACKUP saveset -- savesets 
$ ! can get "broken" during certain sorts of file
$ ! transfers -- such as FTP.  This procedure reads the
$ ! (undocumented) saveset record attributes directly
$ ! out of the target file.
$ !
$ ! First render the saveset readable, and implicitly
$ ! check that the file exists.
$ !
$ Set File -
    /Attributes=(RFM:FIX,MRS:512,LRL=512,ORG=SEQ,RAT=NONE) -
    'p1'
$
$ Open/Error=whoops/Read BckSaveset 'p1'
$ Read/Error=whoops/End=whoops BckSaveset Record
$ Close/Nolog BckSaveset
$
$ ! Find the blocksize from within the record...
$
$ BlockSize = 0
$ BBH_L_BLOCKSIZE = %x28*8
$ BlockSize = F$CVUI(BBH_L_BLOCKSIZE, 32, Record)
$ If BlockSize .lt. 2048 .or. BlockSize .gt. 65535
$ Then
$   Write sys$output "Unexpected block size"
$   Goto whoops
$ Else
$   Set File /Attributes=(RFM:FIX,LRL='BlockSize', -
       MRS='BlockSize',RAT=none) -
       'p1'
$ endif
$ exit
$WHOOPS:
$ Write sys$output "Error"
$ exit
