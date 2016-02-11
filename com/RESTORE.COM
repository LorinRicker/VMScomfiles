$ ! RESTORE.COM
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
$ Rbf  = "DISK$RDB_BCK1:[NTS_DB_RESTORE]nts$1999-02-23.rbf"
$ Rbr  = "DISK$RDB_BCK1:[NTS_DB_RESTORE]nts$database.rbr"
$ DD   = "DISK$DB1:[L_RICKER.NTS]"
$ Root = "nts$database"
$ sql  = "$sys$system:sql$"
$ !
$ DEFINE /NOLOG /PROCESS DB$rbr 'Rbr'
$ SHOW LOGICAL DB$rbr
$ DEFINE /NOLOG /PROCESS NTS$Database 'DD''Root'
$ SHOW LOGICAL NTS$Database
$ !
$ !'F$VERIFY(1,1)'
$ RMU /RESTORE /NEW_VERSION /NOCDD_INTEGRATE /NOAFTER_JOURNAL -
      /DIRECTORY='DD' /ROOT='DD''Root' /NOLOG -
      'Rbf'
$ !
$ sql
DISCONNECT ALL;
EXPORT DATABASE FILENAME NTS$Database INTO DB$rbr WITH EXTENSIONS;
EXIT
$ !'F$VERIFY(0,0)'
$ !
$ EXIT
