$ ! BOOTTIME.COM -- display system re-boot time                    'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1985-1999 by Evans & Ricker, Inc.  All rights reserved.
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
