$ ! KED$STARTUP.COM -- KED text editor startup                     'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2004 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1987-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ SET NOON
$ !
$ lnmtable = "/" + F$PARSE(P1,"SYSTEM",,"NAME","SYNTAX_ONLY")
$ DEFINE = "DEFINE ''lnmtable' /EXECUTIVE_MODE /NOLOG"
$ !
$ kedsec = "site$utils:ked.tpu$section"
$ kedexe = "site$utils:ked.exe"
$ kedshr = "site$utils:ked$share.exe"
$ DEFINE ked$section  'kedsec'
$ DEFINE tpu$calluser 'kedshr'
$ DEFINE ked$utils    site$utils
$ DEFINE ked$help     site$root:[help]ked
$ !
$ IF lnmtable .NES. "/SYSTEM" THEN GOTO Done  ! don't install known images if not /SYSTEM
$ IF F$SEARCH(kedsec) .NES. ""
$ THEN IF F$FILE_ATTRIBUTES(kedsec,"KNOWN")
$      THEN INSTALL REPLACE 'kedsec'
$      ELSE INSTALL CREATE 'kedsec' /OPEN /SHAREABLE
$      ENDIF
$ ENDIF
$ IF F$SEARCH(kedexe) .NES. ""
$ THEN IF F$FILE_ATTRIBUTES(kedexe,"KNOWN")
$      THEN INSTALL REPLACE 'kedexe'
$      ELSE INSTALL CREATE 'kedexe' /OPEN /HEADER_RESIDENT
$      ENDIF
$ ENDIF
$ IF F$SEARCH(kedshr) .NES. ""
$ THEN IF F$FILE_ATTRIBUTES(kedshr,"KNOWN")
$      THEN INSTALL REPLACE 'kedshr'
$      ELSE INSTALL CREATE 'kedshr' /OPEN /SHAREABLE
$      ENDIF
$ ENDIF
$ !
$Done:
$ EXIT
