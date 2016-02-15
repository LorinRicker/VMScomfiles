$ ! QUICK_AUDIT.COM                                                'F$VERIFY(0)'
$ !
$ ! Copyright © 2014 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ! use: @QUICK_AUDIT  !...from a privileged account
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ SHOW USER /FULL
$ !
$ SHOW SYSTEM
$ !
$ SHOW MEMORY
$ !
$ SHOW ERROR
$ !
$ SHOW DEVICE   ! all
$ !
$ MCR NCP SHOW EXEC CHAR
$ !
$ UCX SHOW INTERFACE
$ UCX SHOW SERVICE
$ UCX SHOW DEVICE
$ !
$ SHOW QUEUE /ALL /FULL
$ !
$ MCR AUTHORIZE SHOW /BRIEF *
$ !
$ DIRECTORY /DATE /SIZE SYS$SYSTEM:AGEN$PARAMS.REPORT;*
$ !
$ MCR SYSGEN SHOW /ALL
$ MCR SYSGEN SHOW /SPECIAL
$ !
$Done:
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
