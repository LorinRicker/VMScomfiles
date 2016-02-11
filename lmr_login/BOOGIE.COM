$ ! BOOGIE.COM --                                                  'F$VERIFY(0)'
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
$ ON CONTROL_Y THEN GOTO Quit
$ Fac = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ Debugging = F$TRNLNM("TOOLS$DEBUG","LNM$JOB")
$ wso = "WRITE sys$output"
$ !
$ Dev   = F$PARSE("sys$login",,,"DEVICE","SYNTAX_ONLY")
$ Dir   = F$PARSE("sys$login",,,"DIRECTORY","SYNTAX_ONLY")
$ RDir  = Dir - "]"
$ stash = "SS_Stash"
$ !
$ categories = "ESSENTIAL,FULL"
$ exclusions = ""
$ defexclusn = "''RDir'...]*.bck;*,*.log;*,*.*_old*;*,decw*.*;*" -
             + ",''RDir'.$decw$...]*.*;*,''RDir'.dt...]*.*;*" -
             + ",''RDir'.stash...]*.*;*,''RDir'.scratch...]*.*;*" -
             + ",''RDir'.ssh2...]*.*;*,''RDir'.''stash'...]*.*;*"
$ !
$L1:
$ IF P1 .EQS. ""
$ THEN defop = "Save"
$      READ /END_OF_FILE=quit /PROMPT="Op ([1mS[0mave|Restore): " sys$command ans
$      op = F$PARSE(ans,defop,,"NAME","SYNTAX_ONLY")
$ ELSE op = F$EXTRACT(0,1,P1)
$ ENDIF
$ op = F$EXTRACT(0,1,F$EDIT(op,"UPCASE"))
$ !
$L2:
$ IF P2 .EQS. ""
$ THEN READ /END_OF_FILE=quit /PROMPT="save-set: " sys$command ans
$ ELSE ans = P2
$ ENDIF
$ IF ans .EQS. "" THEN GOTO L2
$ sset = F$PARSE(ans,"''Dev'''RDir'.''stash'].bck",,,"SYNTAX_ONLY")
$ !
$ GOTO 'op'$
$ !
$R$:  ! Restore
$ IF Debugging
$ THEN wso "%''Fac'-I-ECHO, $ BACKUP ''sset' /SAVE_SET ''Dev'''RDir'...] /OWNER=PARENT"
$ ELSE BACKUP 'sset' /SAVE_SET 'Dev''RDir'...] /OWNER=PARENT
$ ENDIF
$ GOTO quit
$ !
$S$:  ! Save
$ wso "Exclusion categories: ''categories'"
$L3:
$ IF P3 .EQS. ""
$ THEN READ /END_OF_FILE=quit /PROMPT="category: " sys$command ans
$ ELSE ans = P3
$ ENDIF
$ exc = F$EXTRACT(0,1,F$PARSE(ans,"FULL",,"NAME","SYNTAX_ONLY"))
$ GOTO 'exc'$
$ !
$E$:  ! ESSENTIAL
$ exclusions = "''RDir'.vms_conversions...],''RDir'.lists...]" -
             + ",''RDir'.E$R...]*.*;*,''RDir'.SMART...]*.*;*,''RDir'.spell...]*.*;*" -
             + ","
$ GOTO DoSave
$ !
$F$:  ! FULL
$ exclusions = ""
$ GOTO DoSave
$ !
$DoSave:
$ ldset = F$PARSE(sset,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(sset,,,"DIRECTORY","SYNTAX_ONLY")
$ lset  = F$PARSE(sset,ldset,,,"SYNTAX_ONLY") - ".BCK" - ";"
$ IF Debugging
$ THEN wso "%''Fac'-I-ECHO, $ BACKUP /IGNORE=INTERLOCK ''Dev'''RDir'...]*.*;0 -"
$      wso "                    ''sset' /SAVE_SET -"
$      wso "                    /LIST=''lset'.lis -"
$      wso "                    /EXCLUDE=( ''exclusions' -"
$      wso "                               ''defexclusn' )"
$ ELSE BACKUP /IGNORE=INTERLOCK 'Dev''RDir'...]*.*;0 -
    'sset' /SAVE_SET -
    /LIST='lset'.lis -
    /EXCLUDE=( 'exclusions' -
               'defexclusn' )
$ DIRECTORY /SIZE /DATE /PROT 'lset'.*
$ ENDIF
$ GOTO quit
$ !
$quit:
$ EXIT
