$ ! TOOLS$DEBUG.COM --                                             'F$VERIFY(0)'
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
$ !  use:  @TOOLS$DEBUG [ ON|YES|1 | OFF|NO|0 | [NO]TELL_TO ] -
$ !                     [SYSTEM] [user[,...]]
$ !
$MAIN:
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ wso     = "WRITE sys$output"
$ !
$L1:
$ IF P1 .EQS. ""
$ THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="Tools debugging ([1mON[0m/OFF)? "
$      P1 = F$PARSE(P1,"ON",,"NAME","SYNTAX_ONLY")
$ ENDIF
$ Tell = F$EXTRACT(0,3,P1)
$ IF Tell .EQS. "TEL"
$ THEN P1 = "TELL_TO"
$ ELSE IF Tell .EQS. "NOT"  ! NOT[ELL_TO]
$      THEN P1 = "NOTELL"
$      ELSE IF ( P1 .EQS. "ON" ) .OR. ( F$EXTRACT(0,1,P1) .EQS. "Y" ) .OR. ( P1 .EQ. 1 )
$           THEN P1 = "TRUE"
$           ELSE P1 = "FALSE"
$           ENDIF
$      ENDIF
$ ENDIF
$ !
$ P2 = P2 - "/"
$ System = ( F$EXTRACT(0,3,P2) .EQS. "SYS" )
$ IF System
$ THEN Prv = F$SETPRV("CMKRNL,SYSNAM,SYSPRV")
$      Tbl   = "SYSTEM"
$      Users = F$EDIT(P3,"COLLAPSE,UPCASE")
$ ELSE Tbl   = "JOB"
$      Users = F$EDIT(P2,"COLLAPSE,UPCASE")
$ ENDIF
$ !
$ IF P1 .EQS. "TELL_TO"
$ THEN DEFINE /NOLOG /'Tbl' TOOLS$Tell_To "''Users'"
$      SHOW LOGICAL /FULL /'Tbl' TOOLS$Tell_To
$           wso "%TOOLS$DEBUG-I-ON, /''Tbl' logical TOOLS$TELL_TO is now ON"
$           IF F$LOCATE(",",Users) .LT. F$LENGTH(Users)
$           THEN Tmp = "users"
$           ELSE Tmp = "user"
$           ENDIF
$           wso F$FAO("!#* for !AS !AS", 19, Tmp, Users)
$ ELSE IF P1 .EQS. "NOTELL"
$      THEN DEASSIGN /'Tbl' TOOLS$Tell_To
$           wso "%TOOLS$DEBUG-I-OFF, /''Tbl' logical TOOLS$TELL_TO is now OFF"
$      ELSE IF P1
$           THEN DEFINE /NOLOG /'Tbl' TOOLS$Debug 'P1'
$                SET PREFIX "(!5%T) "     !augments SET VERIFY/F$VERIFY() display
$                SHOW LOGICAL /FULL /'Tbl' TOOLS$Debug
$                wso "%TOOLS$DEBUG-I-ON, /''Tbl' logical TOOLS$DEBUG is now ON"
$           ELSE IF F$TRNLNM("TOOLS$Debug","LNM$''Tbl'") .NES. "" THEN DEASSIGN /'Tbl' TOOLS$Debug
$                SET NOPREFIX
$                wso "%TOOLS$DEBUG-I-OFF, /''Tbl' logical TOOLS$DEBUG is now OFF"
$           ENDIF
$      ENDIF
$ ENDIF
$ !
$Done:
$ IF F$TYPE(Prv) .EQS. "STRING" THEN Prv = F$SETPRV(Prv)
$ EXIT
