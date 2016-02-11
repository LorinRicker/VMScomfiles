$ ! CREATE_USER_ACCOUNT.COM -- Create user account
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
$ prv = F$SETPRV("SYSNAM,SYSPRV,CMKRNL")
$ !
$ IF F$TRNLNM("sysuaf") .EQS. ""
$ THEN DEFINE /SYSTEM /EXEC sysuaf     sys$system:sysuaf.dat
$      DEFINE /SYSTEM /EXEC rightslist sys$system:rightslist.dat
$ ENDIF
$ SHOW LOGICAL sysuaf
$ SHOW LOGICAL rightslist
$ !
$ UNm  = "Ricker"
$ Own  = "Lorin Ricker"
$ Acc  = "SYSMGR"
$ Dev  = "sys$sysdevice"
$ Dir  = "ricker"
$ UDir = Dev + ":[" + Dir + "]"
$ uic  = "[20,32]"
$ pwd  = "NEWUSER"
$ dprv = "NETMBX,TMPMBX,OPER,SYSPRV,SETPRV"
$ !
$ wf = "WRITE f"
$ TmpFile = "[]cua_temp.com"
$ OPEN /WRITE /ERROR=Oops f 'TmpFile'
$ !
$ wf "$ MCR AUTHORIZE                                              !'F$VERIFY(1)'"
$ wf ""
$ wf "ADD ''UNm' /ACCOUNT=""''Acc'"" -"
$ wf "  /OWNER=""''Own'"" /UIC=''uic' -"
$ wf "  /DEVICE=''Dev' /DIRECTORY=[''Dir'] -"
$ wf "  /FLAG=NODISUSER /PASSWORD=''pwd' -"
$ wf "  /PWDLIFETIME=0-00:00 /NOPWDEXPIRED -"
$ wf "  /FILLM=300 /BIOLM=2048 /DIOLM=2048 -"
$ wf "  /ASTLM=1024 /TQELM=1024 /ENQLM=8192 -"
$ wf "  /BYTLM=256000 /JTQUOTA=8192 /PGFLQUO=700000 -"
$ wf "  /WSDEF=8192 /WSQUO=16384 /WSEXTENT=32768 -"
$ wf "  /PRIV=(''dprv') -"
$ wf "  /DEFPRIV=(''dprv')"
$ wf ""
$ wf "SHOW /FULL ''UNm'"
$ wf "$ !"
$ wf "$ IF F$SEARCH(""''UDir'"") .EQS. """" "
$ wf "$ THEN CREATE /DIRECTORY /LOG ''UDir' /OWNER=''uic'"
$ wf "$ ENDIF"
$ wf "$ !"
$ wf "$ DELETE /LOG ''TmpFile';*"
$ wf "$ EXIT                                                       !'F$VERIFY(0)'"
$ ! 
$ CLOSE f
$ ! 
$ @'TmpFile'
$ ! 
$Quit:
$ prv = F$SETPRV(prv)
$ EXIT
$ !
$Oops:
$ WRITE sys$error "%CUA-W-OOPS, could not OPEN/WRITE ''TmpFile' in current directory"
$ GOTO Quit
