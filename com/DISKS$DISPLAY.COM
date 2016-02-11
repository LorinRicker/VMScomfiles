$ ! DISKS$DISPLAY.COM --                                           'F$VERIFY(0)'
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
$ Prv = F$SETPRV("SYSNAM,CMKRNL,SYSPRV")
$ DEFINE /NOLOG /JOB disks$display -
    sys$sysdevice,sys$user1,sys$user2,sys$user3,sys$user4,sys$user5,-
    disk$alphavmsjt,disk$alphavmstj,-
    disk$altpagja,disk$altpagjb,disk$applocj,disk$syslocj,-
    disk$ltdbB,disk$ltdbC,disk$ltdbD,disk$ltdbE,-
    disk$user0,disk$user1,disk$user2,disk$user3,disk$user4,-
    disk$user5,disk$user6,disk$user8,disk$user9,disk$usera
$ Prv = F$SETPRV(Prv)
$ !
$ IF F$TYPE(disks) .EQS. "" THEN disk*s == "@site$utils:diskspace.com"
$ !
$ EXIT
