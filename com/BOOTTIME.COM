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
$ SET NOON
$ !
$ wso = "WRITE sys$output"
$ !
$ isANSI = F$GETDVI( "sys$output", "TT_ANSICRT" )
$ IF ( isANSI )
$ THEN esc[0,8]= %X1B              !  27 decimal,  033 octal - ESCape character
$         NORM = esc + "[0m"       ! Normal rendition
$         BOLD = esc + "[1m"       ! Bold
$ ELSE    NORM = ""
$         BOLD = ""
$ ENDIF
$ !
$ Node    = F$GETSYI("NODENAME")
$ Cluster = "Node "
$ IF F$GETSYI("CLUSTER_MEMBER") THEN cluster = "VMScluster member "
$ !
$ BootTime = F$EDIT(F$GETSYI("BOOTTIME"),"TRIM")
$ UpTime   = F$EDIT( F$DELTA_TIME( BootTime, F$TIME(), "ASCTIM" ), "TRIM" )
$ !
$ wso "%BOOTTIME-I-REBOOT, ''Cluster'''Node' rebooted on ''BOLD'''BootTime'''NORM'"
$ wso "         -I-UPTIME, Uptime is ''BOLD'''UpTime'''NORM'"
$ !
$ EXIT 1   !'F$VERIFY(0)'
$ !
