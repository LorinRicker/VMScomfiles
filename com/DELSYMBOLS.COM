$ ! DELSYMBOLS.COM -- Deletes site-specific "garbage" symbols      'F$VERIFY(0)'
$ !
$ ! Copyright © 1999-2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ! P1: "YES" to re-define E&R/personal symbols
$ !
$ DEFINE = "DEFINE"
$ DEFINE /USER_MODE sys$output nl:
$ DEFINE /USER_MODE sys$error  nl:
$ DELETE /SYMBOL /GLOBAL /ALL
$ !
$ IF P1
$ THEN !! IF F$TRNLNM("mgr$login")             .NES. "" THEN @mgr$login
$      !! IF F$TRNLNM("site$sylogin")          .NES. "" THEN @site$sylogin
$      IF F$TRNLNM("sys$sylogin")           .NES. "" THEN @sys$sylogin
$      IF F$SEARCH("lmr$login:symbols.com") .NES. "" THEN @lmr$login:symbols
$      IF F$SEARCH("com:tpu.com")           .NES. "" THEN @com:tpu
$ ENDIF
$ EXIT
