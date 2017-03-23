$ ! CHECK_SYSGEN_LGI.COM --                                        'F$VERIFY(0)'
$ !
$ ! Copyright © 2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ say  = "WRITE sys$output"
$ node = F$GETSYI("NODENAME")
$ fn   = "CHECK_SYSGEN_LGI"
$ fext = ".REPORT"
$ fspec = "[]" + fn + fext
$ !
$ Target_LGI_BRK_LIM = "3"  ! VWR's Security Policy requirement
$ !
$ DEFINE /NOLOG sys$output 'fspec'
$ !
$ say "System ''node': Parameter LGI_BRK_LIM should be ''Target_LGI_BRK_LIM' ..."
$ say ""
$ Active_LGI_BRK_LIM = F$GETSYI("LGI_BRK_LIM")
$ say "Active LGI_BRK_LIM is: ''Active_LGI_BRK_LIM'"
$ IF ( Active_LGI_BRK_LIM .EQ. Target_LGI_BRK_LIM )
$ THEN say "Parameter is compliant."
$ ELSE say "Parameter is NOT compliant!"
$ ENDIF
$ !
$ MCR SYSGEN
USE ACTIVE
SHOW /LGI
USE CURRENT
SHOW /LGI
EXIT
$ !
$ say ""
$ !
$ DEASSIGN sys$output
$ TYPE 'fspec'
$ !
$ EXIT 1
$ !
