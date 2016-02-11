$ ! FIND_RTL.COM -- Display a routine declaration                  'F$VERIFY(0)'
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
$ ! P1: name of System Service or RunTime Library routine to find & display
$ ! P2: output file (optional)
$ !
$ SET NOON
$ IF P1 .EQS. ""
$ THEN READ sys$command P1 /END_OF_FILE=Done -
           /PROMPT="RTL or SS routine: "
$ ENDIF
$ IF P1 .EQS. "" THEN GOTO Done
$ IF P2 .NES. "" THEN P2 = "/OUTPUT=" + P2
$ Fac = F$ELEMENT(0,"$",F$EDIT(P1,"UPCASE,COLLAPSE"))
$ IF ( Fac .EQS. "" ) .OR. ( Fac .EQS. "SYS" )
$ THEN Env = "starlet"
       IF ( Fac .EQS. "SYS" )
$      THEN P1  = "EXTERNAL(" + P1 + ")"
$      ELSE P1  = "FUNCTION " + P1
$      ENDIF
$ ELSE Env = "pascal$" + Fac + "_routines"
$      P1  = "FUNCTION " + P1
$ ENDIF
$ DEFINE RTLib sys$library,er$library,sys$disk:[]
$ EnvSrc = F$SEARCH("RTLib:''Env'.pas")
$ IF EnvSrc .NES. ""
$ THEN SLICE /EDIT=(TRIM)                       -  !DETAB when implemented
             /BETWEEN=("*''P1'*","*EXTERNAL;*") -
         'EnvSrc'  'P2'
$ ELSE WRITE sys$output "%FIND_RTL-E-NOSUCHFILE, no file ''Env'.PAS found"
$ ENDIF
$Done:
$ IF F$TRNLNM("RTLib","LNM$PROCESS") .NES. "" THEN DEASSIGN RTLib
$ EXIT
