$ ! BOOTTIME.COM -- display system re-boot time                    'F$VERIFY(0)'
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
$ Cluster = "Node "
$ IF F$GETSYI("CLUSTER_MEMBER") THEN cluster = "VMScluster member "
$ Node = F$GETSYI("NODENAME")
$ BootTime = F$GETSYI("BOOTTIME")
$ Dc = "site$utils:dc$datecalc.exe"
$ UpTime = ""
$ IF F$SEARCH(Dc) .NES. ""
$ THEN Days = "$" + Dc
$      Days "''BootTime'" /DELTA /SYMBOL=UpTime /SCOPE=LOCAL
$ ENDIF
$ DaysUp = F$INTEGER(F$ELEMENT(0," ",UpTime))
$ HMTime = F$ELEMENT(1," ",UpTime)
$ HrsUp  = F$INTEGER(F$ELEMENT(0,":",HMTime))
$ MinsUp = F$INTEGER(F$ELEMENT(1,":",HMTime))
$ WRITE sys$output "%BOOTTIME-I, ''cluster'''node' rebooted at ''boottime'."
$ IF UpTime .NES. "" -
  THEN WRITE sys$output F$FAO("!13* Up-time is [1m!ZL day!%S, !ZL hour!%S, !ZL minute!%S[0m (!AS)", DaysUp, HrsUp, MinsUp, UpTime)
$ !
$ EXIT
