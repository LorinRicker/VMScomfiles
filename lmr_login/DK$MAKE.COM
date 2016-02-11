$ ! DK$MAKE.COM  -- reconstruct personal DK$* keys and help-files,
$ !                 putting outputs in their proper use-dir's.
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
$ SET MESSAGE site$utils:util_messages
$ IF F$MODE() .EQS. "BATCH" THEN SET DEFAULT [l_ricker.$login]
$ !
$ IF ( P1 .EQS. "ALL" ) .OR. ( P1 .EQS. "" )
$ THEN CALL DCL
$      CALL MAIL
$      CALL DEBUG
$      CALL KERMIT
$ ELSE CALL 'P1'
$ EXIT
$ !
$DCL:  SUBROUTINE
$ SET NOON
$ @site$utils:dk$define_keys DCL SHOW NOSHIFT_KEY
$ CALL Cvt dk$dcl_keypad.show
$ @site$utils:dk$define_keys DCL
$ CALL Cvt dk$dcl_keypad.gold
$ CALL Cvt dk$dcl.com
$ EXIT
$ ENDSUBROUTINE
$ !
$MAIL:  SUBROUTINE
$ SET NOON
$ @site$utils:dk$define_keys MAIL
$ CALL Cvt dk$mail_keypad.gold
$ CALL Cvt dk$mail.com
$ EXIT
$ ENDSUBROUTINE
$ !
$DEBUG:  SUBROUTINE
$ SET NOON
$ @site$utils:dk$define_keys DEBUG BLUE NOSHIFT_KEY
$ CALL Cvt dk$debug_keypad.gold
$ @site$utils:dk$define_keys DEBUG GOLD NOSHIFT_KEY
$ CALL Cvt dk$debug_keypad.blue
$ CALL Cvt dk$debug.com
$ EXIT
$ ENDSUBROUTINE
$ !
$KERMIT:  SUBROUTINE
$ SET NOON
$ SET DEFAULT [l_ricker.$com]
$ @site$utils:dk$define_keys KERMIT
$ RENAME dk$kermit.lis kermit.load
$ RENAME dk$kermit_keypad.lis kermit_keypad.load
$ DELETE dk$kermit_keypad.*;*
$ EXIT
$ ENDSUBROUTINE
$ !
$Cvt:  SUBROUTINE
$ CONVERT /FDL=sys$input 'p1' 'p1'
FILE
	BEST_TRY_CONTIGUOUS	no
	ORGANIZATION		sequential

RECORD
	BLOCK_SPAN		yes
	CARRIAGE_CONTROL	carriage_return
	FORMAT			variable
$ !
$ PURGE 'p1'
$ EXIT
$ ENDSUBROUTINE
