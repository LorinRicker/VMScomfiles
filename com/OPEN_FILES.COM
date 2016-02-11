$ ! OPEN_FILES.COM -- 
$ !                                                                'F$VERIFY(0)'
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
$ !  use:  @OPEN_FILES [Device] [Search_String [...] ]
$ !
$ Fac      = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ wso      = "WRITE sys$output"
$ OutF     = "sys$scratch:" + Fac + ".tmp0"
$ SeaF     = "sys$scratch:" + Fac + ".tmp1"
$ DefDev   = F$PARSE("sys$disk",,,"DEVICE","SYNTAX_ONLY")
$ DefUName = F$EDIT(F$GETJPI("","USERNAME"),"COMPRESS,TRIM,UPCASE")
$ DC$_DISK = 1
$ !
$ ! If P1 exists *and* is a disk-device, then check open-files on it;
$ ! otherwise, use the default device, and merge P1 into the search-string:
$ Dev = DefDev
$ IF P1 .EQS. ""
$ THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="Disk/device <''DefDev'>? "
$      IF P1 .EQS. "" THEN P1 = DefDev
$ ENDIF
$ IF F$GETDVI(P1,"EXISTS")
$ THEN IF F$GETDVI(P1,"DEVCLASS") .EQ. DC$_DISK
$      THEN Dev = P1
$      ELSE P2 = P1 + " " + P2
$      ENDIF
$ ELSE P2 = P1 + " " + P2
$ ENDIF
$ P2 = F$EDIT(P2,"TRIM")
$ IF P2 .EQS. ""
$ THEN READ sys$command P2 /END_OF_FILE=Done /PROMPT="Search string <''DefUName'>? "
$      IF P2 .EQS. ""
$      THEN SStr = DefUName
$      ELSE SStr = P2
$      ENDIF
$ ELSE SStr = P2 + " " + P3 + " " + P4 + " " -
            + P5 + " " + P6 + " " + P7 + " " + P8
$ ENDIF
$ !
$ wso ""
$ wso F$FAO("%!AS-I-DEVICE, open file report for device !AS",Fac,Dev)
$ SHOW DEVICE /FILES /OUTPUT='OutF' 'Dev'
$ IF P2 .EQS. "*"
$ THEN TYPE 'OutF'
$ ELSE SEARCH /OUTPUT='SeaF' 'OutF' 'SStr' /HIGHLIGHT=BOLD
$      TYPE 'SeaF'
$ ENDIF
$ !
$ IF F$SEARCH("site$utils:tail.exe") .NES. ""
$ THEN tail = "$site$utils:tail"
$      TAIL /NOOUTPUT /COUNT=LINES /SYMBOL=OFCount 'OutF'
$      OFCount = F$INTEGER(OFCount) - 2             !minus the two header lines
$      IF P2 .EQS. "*"
$      THEN wso F$FAO("%!AS-I-COUNT, there are !ZL open files on !AS",Fac,OFCount,Dev)
$      ELSE TAIL /NOOUTPUT /COUNT=LINES /SYMBOL=SFCount 'SeaF'
$           SFCount = F$INTEGER(SFCount)
$           wso F$FAO("%!AS-I-COUNT, there are !ZL open/matched file!%S (!ZL total) on !AS",Fac,SFCount,OFCount,Dev)
$           DELETE /SYMBOL /LOCAL SFCount
$      ENDIF
$      DELETE /SYMBOL /LOCAL OFCount
$ ENDIF
$ wso ""
$ !
$Done:
$ IF F$SEARCH(OutF) .NES. "" THEN DELETE /NOLOG 'OutF';*
$ IF F$SEARCH(SeaF) .NES. "" THEN DELETE /NOLOG 'SeaF';*
$ EXIT
