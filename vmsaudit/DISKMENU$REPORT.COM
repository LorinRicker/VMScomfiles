$ ! DISKMENU$REPORT.COM --                                         'F$VERIFY(0)'
$ !
$ ! Copyright © 2014-2018 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ typeit = "TYPE /PAGE"
$PromptLoop:
$ IF ( P1 .NES. "" )
$ THEN choice = F$EXTRACT( 0, 1, P1 )
$ ELSE typeit sys$input  ! "here-doc" with clearscreen

    [4mDisk Information Reports[0m

    ([1m1[0m) [1mA[0mll       -- all reports
    ([1m2[0m) [1mD[0misks     -- show mounted disk volumes
    ([1m3[0m) [1mI[0mnventory -- display disk inventory & characteristics
    ([1m4[0m) [1mL[0mimits    -- display disk size limits
    ([1m5[0m) [1mS[0mpace     -- display volume space free, used & total
    ([1m6[0m) [1mV[0molShadow -- display shadow volume set characteristics
    ([1m7[0m) [1mP[0mrogress  -- show all shadow volumes merge progress


$      READ sys$command P1 /PROMPT="Display [5/S]? " /END_OF_FILE=DMR$Done
$      P1 = F$EDIT( P1, "TRIM,UPCASE" )
$      IF ( P1 .EQS. "" ) THEN P1 = "Space"
$      choice = F$EXTRACT( 0, 1, P1 )
$ ENDIF
$ ON WARNING THEN GOTO ChoiceError
$ IF ( choice .EQS. "A" ) .OR. ( choice .EQS. "1" )
$ THEN DoAllReports = "TRUE"
$      GOTO DMR$2
$ ELSE DoAllReports = "FALSE"
$      GOTO DMR$'choice'
$ ENDIF
$ !
$DMR$2:
$DMR$D:
$ SHOW DEVICE D /MOUNTED
$ IF DoAllReports
$ THEN wso ""
$ ELSE GOTO DMR$Cont
$ ENDIF
$ !
$DMR$3:
$DMR$I:
$ @'DD'diskinventory$report
$ IF .NOT. DoAllReports THEN GOTO DMR$Cont
$ !
$DMR$4:
$DMR$L:
$ @'DD'disklimits$report
$ IF .NOT. DoAllReports THEN GOTO DMR$Cont
$ !
$DMR$5:
$DMR$S:
$ @'DD'diskspace$report
$ IF .NOT. DoAllReports THEN GOTO DMR$Cont
$ !
$DMR$6:
$DMR$V:
$ @'DD'diskvolshadow$report
$ IF .NOT. DoAllReports THEN GOTO DMR$Cont
$ !
$DMR$7:
$DMR$P:
$ IF DoAllReports THEN GOTO DMR$Cont
$ dcf = "COM:DO_CONTINUOUS.COM"
$ IF ( F$SEARCH(dcf) .NES. "" )
$ THEN @'dcf' -D:15 SHOW SHADOW /ACTIVE
$ ELSE SHOW SHADOW /ACTIVE
$ ENDIF
$ !
$DMR$Cont:
$ wso ""
$ P1 = ""
$ IF ( .NOT. DoAllReports )
$ THEN READ sys$command P1 /PROMPT="<Enter> returns to menu, <Ctrl/Z> to exit..." /END_OF_FILE=DMR$Done
$      GOTO PromptLoop
$ ELSE EXIT 1  ! 'F$VERIFY(0)'
$ ENDIF
$ !
$DMR$Done:
$ DCL$CALL DeleteGloSyms "DD$Disks"
$ EXIT 1  ! 'F$VERIFY(0)'
$ !
$ChoiceError:
$ wso F$FAO( "%!AS-E-BAD_CHOICE, no such option [4m!AS[0m, reenter...", Fac, choice )
$ P1 = ""
$ DoAllReports = "TRUE"
$ typeit       = "TYPE"
$ GOTO PromptLoop
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
