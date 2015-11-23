$! RESET_BACKUP_SAVESET_ATTRIBUTES.COM
$!
$! P1  is the specification of the BACKUP saveset
$!
$! This procedure resets the record format and record
$! length attributes of a BACKUP saveset -- savesets 
$! can get "broken" during certain sorts of file
$! transfers -- such as FTP.  This procedure reads the
$! (undocumented) saveset record attributes directly
$! out of the target file.
$!
$! First render the saveset readable, and implicitly
$! check that the file exists.
$!
$ Set File -
    /Attributes=(RFM:FIX,MRS:512,LRL=512,ORG=SEQ,RAT=NONE) -
    'p1'
$
$ Open/Error=whoops/Read BckSaveset 'p1'
$ Read/Error=whoops/End=whoops BckSaveset Record
$ Close/Nolog BckSaveset
$
$! Find the blocksize from within the record...
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
