$ ! MLOGIC.COM -- forms logical name from current directory or stack
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
$ !  usage:  @MLOGIC lnm
$ !
$ IF p1 .EQS. "" THEN EXIT
$ DEFINE /PROCESS /NOLOG 'p1' 'F$ENVIRONMENT("DEFAULT")'
$ WRITE sys$error -
    "%MLOGIC-I, process logical ""''p1'"" = ""''F$TRNLNM(p1,"LNM$PROCESS")'"""
$ EXIT
