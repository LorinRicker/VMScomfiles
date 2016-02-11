$ ! CMDPROMPT.COM --                                               ! 'F$VERIFY(0)'
$ !
$ ! Copyright © 2015-2016 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ! A sophisticated command prompt
$ !
$ ! usage: @CMDPROMPT [next_working_dir]
$ !
$ !! show symbol p1
$ !
$ IF ( P1 .NES. "" )
$ THEN SET DEFAULT 'P1'
$      WRITE SYS$OUTPUT ""
$ ENDIF
$ defstr = F$ENVIRONMENT("DEFAULT")
$ !! SHOW SYMBOL /LOCAL defstr
$ SET PROMPT="''defstr'$ "
$ !
$ EXIT    ! 'F$VERIFY(0)'
$ !
