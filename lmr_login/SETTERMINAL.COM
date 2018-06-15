$ ! SETTERMINAL.COM --                                             'F$VERIFY(0)'
$ !
$ ! Copyright © 1986-2018 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ SET TERMINAL /INQUIRE   ! this reads/sets the page-&-width sizes
$ TermType = "VT500"
$ PgLength = F$GETDVI("TT","TT_PAGE")
$ PgWidth  = F$GETDVI("TT","DEVBUFSIZ")
$ ! SET TERMINAL: Setting page /WIDTH= clears the screen...
$ !               and getting /PAGE= and /WIDTH= right is order-dependent,
$ !               these must precede /DEVICE= !! -- so... in exactly this order:
$ SET TERMINAL /PAGE='PgLength' /WIDTH='PgWidth' /DEVICE='TermType' -
   /INSERT /BROADCAST /TYPE_AHEAD /ALTYPEAHD /APPLICATION_KEYPAD
$ !
$ ! Convenience symbols:
$ colN == "SET TERMINAL /WIDTH=80"
$ colW == "SET TERMINAL /WIDTH=132"
$ !
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
