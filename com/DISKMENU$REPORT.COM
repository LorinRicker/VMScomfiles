$ ! DISKMENU$REPORT.COM --                                         'F$VERIFY(0)'
$ !
$ ! Copyright © 2014-2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ! use:  $ @DISKMENU$REPORT [ menu_choice ]
$ !
$ ! === MAIN ===
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO DMR$Done
$ !
$ wso  = "WRITE sys$output"
$ Proc = F$ENVIRONMENT( "PROCEDURE" )
$ Fac  = F$PARSE( Proc, , , "NAME" )
$ DD   = F$PARSEC( Proc, , , "DEVICE" ) + F$PARSE( Proc, , , "DIRECTORY" )
$ Node = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ !
$ P1 = F$EDIT( P1, "TRIM,UPCASE" )
$PromptLoop:
$ IF ( P1 .NES. "" )
$ THEN choice = F$EXTRACT( 0, 1, P1 )
$ ELSE TYPE /PAGE sys$input  ! "here-doc" with clearscreen

    [4mDisk Information Reports[0m

    ([1m1[0m) [1mD[0misks     -- show mounted devices/disks
    ([1m2[0m) [1mI[0mnventory -- display disk inventory & characteristics
    ([1m3[0m) [1mS[0mpace     -- display disk space free, used & total


$      READ sys$command P1 /PROMPT="Display [1/D]? " /END_OF_FILE=DMR$Done
$      P1 = F$EDIT( P1, "TRIM,UPCASE" )
$      IF ( P1 .EQS. "" ) THEN P1 = "Disks"
$      choice = F$EXTRACT( 0, 1, P1 )
$ ENDIF
$ ON WARNING THEN GOTO ChoiceError
$ GOTO DMR$'choice'
$ !
$DMR$1:
$DMR$D:
$ SHOW DEVICE D /MOUNTED
$ GOTO DMR$Cont
$ !
$DMR$2:
$DMR$I:
$ @'DD'diskinventory$report
$ GOTO DMR$Cont
$ !
$DMR$3:
$DMR$S:
$ @'DD'diskspace$report
$ GOTO DMR$Cont
$ !
$DMR$Cont:
$ wso ""
$DMR$Done:
$ DCL$CALL DeleteGloSyms "DI$Disks"
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$ChoiceError:
$ wso F$FAO( "%!AS-E-BAD_CHOICE, no such option [4m!AS[0m, reenter...", Fac, choice )
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
