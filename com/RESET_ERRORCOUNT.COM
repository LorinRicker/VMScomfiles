$ ! RESET_ERRORCOUNT.COM --                                        'F$VERIFY(0)'
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
$ !  useage:
$ !    $ @RESET_ERRORCOUNT [ --[NO]CONFIRM ]  ! --CONFIRM is default
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Debug = F$TRNLNM("TOOLS$Debug")     !generic Tools debug flag
$ !
$ resetcount = 0
$ Prv        = "CMKRNL,DIAGNOSE,PHY_IO" 
$ !
$ Proc   = F$ENVIRONMENT("PROCEDURE")
$ Proc   = Proc - F$PARSE(Proc,,,"VERSION","SYNTAX_ONLY")
$ Fac    = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ DD     = F$PARSE(Proc,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(Proc,,,"DIRECTORY","SYNTAX_ONLY")
$ Node   = F$EDIT( F$GETSYI( "NODENAME" ), "COLLAPSE" )
$ !
$ SPC    = " "
$ DASH   = "-"
$ !
$ wso    = "WRITE sys$output"
$ !
$ P1 = F$EDIT( P1, "TRIM,UPCASE" ) - DASH - DASH
$ IF ( F$EXTRACT( 0, 1, P1 ) .EQS. "H" ) .OR. ( F$EXTRACT( 0, 1, P1 ) .EQS. "?" ) -
  THEN GOTO Help
$ confirm = ( P1 .EQS. "" ) .OR. ( F$EXTRACT( 0, 4, P1 ) .EQS. "CONF" )
$ !
$ IF Debug
$ THEN erroutf = "''DD'''Fac'.TMP"
$      outqual = "/OUTPUT=NLA0:"  ! discard the SHOW ERROR output for this case...
$      wso F$FAO( "%!AS-I-TEST_DATA, using test data file !AS", Fac, erroutf )
$ ELSE erroutf = "SYS$SCRATCH:''Fac'.TMP"
$      outqual = "/OUTPUT=''erroutf'"
$ ENDIF
$ !
$ SHOW ERROR 'outqual'
$ !
$ OPEN ef 'erroutf' /READ /ERROR=FNFerror
$ READ ef Rec /END_OF_FILE=Done       ! discard header-line "Device ... Error Count"
$ ! or it contains "%SHOW-S-NOERRORS, no device errors found", so done...
$ IF ( F$LOCATE( "NOERRORS", Rec ) .LT. F$LENGTH( Rec ) ) THEN GOTO Done
$ !
$ Prv = F$SETPRV( Prv )
$ !
$Loop:
$ READ ef Rec /END_OF_FILE=LoopDone
$ Dev = F$ELEMENT( 0, SPC, Rec )
$ IF ( Dev .EQS. "" ) THEN GOTO LoopDone
$ Okay = "YES"
$ IF confirm
$ THEN READ sys$command answer /PROMPT="Reset error count for ''Dev' [Yes/[1mNo[0m]? "
$      Okay = F$PARSE( answer, "NO", , "NAME", "SYNTAX_ONLY" )
$ ENDIF
$ IF confirm
$ THEN IF Okay
$      THEN IF Debug
$           THEN wso F$FAO( "%!AS-I-ECHO, $ SET DEVICE /RESET=ERROR_COUNT !AS", Fac, Dev )
$           ELSE SET DEVICE /RESET=ERROR_COUNT 'Dev'
$                resetcount = resetcount + 1
$           ENDIF
$      ENDIF
$ ELSE IF Debug
$      THEN wso F$FAO( "%!AS-I-ECHO, $ SET DEVICE /RESET=ERROR_COUNT !AS", Fac, Dev )
$      ELSE SET DEVICE /RESET=ERROR_COUNT 'Dev'
$           resetcount = resetcount + 1
$      ENDIF
$ ENDIF
$ GOTO Loop
$LoopDone:
$ !
$Done:
$ CLOSE /NOLOG ef
$ IF .NOT. Debug
$ THEN IF ( F$SEARCH( erroutf ) .NES. "" ) THEN DELETE /NOLOG 'erroutf';*
$ ENDIF
$ IF ( F$TYPE( Prv ) .EQS. "STRING" ) THEN Prv = F$SETPRV(Prv)
$ wso F$FAO( "%!AS-I-COUNT, reset !ZL devices", Fac, resetcount )
$ EXIT 1  ! 'F$VERIFY(0)'
$ !
$FNFerror:
$ wse F$FAO( "%!AS-E-FNF, file not found: !AS", Fac, erroutf )
$ GOTO Done
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  Clears the Error Count for all devices currently with non-zero counts.

  usage:
    [1m@RESET_ERRORCOUNT[0m [ [1m--CONFIRM [0m(D) | [1m--NOCONFIRM[0m ]
                    | [ [1m--HELP[0m ] | [ [1m-?[0m ]

  where:

    --NOCONFIRM  Resets the error count for each device with a non-zero
          current error count.

    --CONFIRM  (default) Prompts for Yes/No permission before resetting
          the device's error count.  Resets that device's error count
          only if you respond "y[es]" for that device.

   --HELP or -?  Prints this help text.

$ !
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
