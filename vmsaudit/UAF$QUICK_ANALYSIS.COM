$ ! UAF$QUICK_ANALYSIS.COM                                         'F$VERIFY(0)'
$ !
$ ! Copyright © 2014-2015 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ wso = "WRITE sys$output"
$ !
$ ! Input file must be a UAF> LIST /BRIEF output...
$ IF P1 .EQS. "" THEN P1 = "[]SYSUAF.LIS"
$ !
$ IF F$SEARCH(P1) .NES. ""
$ THEN
$      ! if SEARCH /STATISTICS=SYMBOLS doesn't work 'cause wrong version of VMS (<v8.3),
$      !  then just exit as quietly as possible...
$      ON WARNING THEN EXIT %X1
$      SEARCH$RECORDS_SEARCHED = ""
$      SEARCH$RECORDS_MATCHED  = ""
$      ! (Note use of subprocess PIPE ...  >NLA0: 2>NLA0: to suppress SYS$OUTPUT and SYS$ERROR noise)
$      PIPE SEARCH /STATISTICS=SYMBOLS 'P1' " ALL " >NLA0: 2>NLA0:
$      TotalUsers  = F$INTEGER(SEARCH$RECORDS_SEARCHED) - 2  ! Minus the headers, how many users?
$      PrivdUsers  = F$INTEGER(SEARCH$RECORDS_MATCHED)
$      PIPE SEARCH /STATISTICS=SYMBOLS 'P1' "DISUSER" >NLA0: 2>NLA0:
$      DisUsers    = F$INTEGER(SEARCH$RECORDS_MATCHED)
$      PIPE SEARCH /STATISTICS=SYMBOLS 'P1' " ALL ","DISUSER" /MATCH=AND >NLA0: 2>NLA0:
$      DisPrvUsers = F$INTEGER(SEARCH$RECORDS_MATCHED)
$      wso ""
$      wso "User Account File (UAF) Summary:"
$      wso F$FAO( "  Total user accounts: !4SL        Total privileged accounts: !4SL", -
                  TotalUsers, PrivdUsers )
$      wso F$FAO( "   Disuser'd accounts: !4SL    Disuser'd privileged accounts: !4SL", -
                  DisUsers, DisPrvUsers )
$      wso ""
$ ELSE wso "%UAF$QUICK_ANALYSIS-E-FNF, file ''P1' not found"
$      wso "  Input must be a UAF> LIST /BRIEF output file..."
$ ENDIF
$ !
$ EXIT 1
