$ ! DCL$SUBROUTINE_LIBRARY.COM --                                  'F$VERIFY(0)'
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
$ ! Need some help?
$ p1param = F$EXTRACT( 0, 4, F$EDIT(P1,"UPCASE,TRIM") ) - "-" - "-"  ! strip any leading - or --
$ IF ( p1param .EQS. "HELP" ) .OR. ( P1 .EQS. "?" ) THEN GOTO Help
$ !
$ wso   = "WRITE sys$output"
$ Fac   = "DCL$SUBROUTINE_LIBRARY"
$ COMMA = ","
$ !
$ ! ==========
$ ! Update this list as new subroutines are added:
$ RegisteredRoutines = ",CmdParse,DeleteGlobalSymbols,MakeDir,ToolsDebug,Setup" -
                     + ",«»" -
                     + ",«»" -
                     + COMMA
$ ! ==========
$ RRlen    = F$LENGTH( RegisteredRoutines )
$ RegRouUC = F$EDIT( RegisteredRoutines, "UPCASE" )
$ ! ==========
$ !
$ ! Show/display all Registered Routines --
$ IF ( p1param .EQS. "SHOW" )
$ THEN j = 0
$      count  = 0
$      indent = 4
$      wso ""
$      wso "  ''Fac'"
$      wso F$FAO( "!#* [4mRegistered Routines[0m", indent )
$ShowLoop:
$      rr = F$ELEMENT( j, COMMA, RegisteredRoutines )
$      IF ( rr .EQS. COMMA )
$      THEN wso ""
$           wso F$FAO( "!#* Total of !ZL routine!%S", indent, count )
$           wso ""
$           EXIT 1
$      ENDIF
$      j = j + 1
$      IF ( rr .EQS. "" ) .OR. ( rr .EQS. "«»" )
$      THEN GOTO ShowLoop
$      ELSE wso F$FAO( "!#* !AS", indent, rr )
$           count = count + 1
$      ENDIF
$      GOTO ShowLoop
$ ENDIF
$ !
$ IF ( F$LOCATE( P1, RegRouUC ) .GE. RRlen )
$ THEN wso F$FAO( "%!AS-E-NOT_REGISTERED, !AS does not exist", Fac, P1 )
$      EXIT %X2C  ! abort...
$ ENDIF
$ !
$ ! ==========
$ ! Dispatch:  P1 = Subroutine to call; P2..P8 are general parameters to pass --
$ !            Note that internal subroutine names are prefixed by "DCL$" to
$ !            limit conficts with external, non-library routines...
$ ! ==========
$ CALL DCL$'P1' "''P2'" "''P3'" "''P4'" "''P5'" "''P6'" "''P7'" "''P8'"
$ ! ==========
$ stat = $STATUS
$ EXIT 'stat'  ! 'F$VERIFY(0)'
$ !
$ !
$ ! ==========
$DCL$CmdParse: SUBROUTINE
$ ! Doc : Attempts to match a command word (P1) against a list of possible command words (P4),
$ !       where P1 may be a uniquely-recognized abbreviation of any of the possible words;
$ !       returns result as a user-defined global symbol, or an error condition if no match.
$ !  Example:
$ !     $ DCL$CALL CmdParse "''P1'" File$Component "NAME" "NODE|DEV |DIR |NAME|TYPE|VERS|FULL"
$ !  P1 : command word to parse
$ !  P2 : global symbol to receive answer (default is Cmd$Answer)
$ !  P3 : default command
$ !  P4 : command-set ("C1|C2[|Cn...]") -- options must be same-length fields;
$ !       alternatively "@symbol" where "symbol" contains command-set (this
$ !       accommodates very long command-sets, >255 characters)
$ !  P5 : command separator (default is vert-bar/pipe "|")
$ !  P6 : FALSE/TRUE flag to either return "" as failed-result (default is FALSE),
$ !       or to hard-stop-fail (TRUE)
$ !
$ IF ( P1 .EQS. "" ) THEN P1 = P3
$ IF ( P2 .EQS. "" ) THEN P2 = "Cmd$Answer"
$ IF ( P5 .EQS. "" ) THEN P5 = "|"
$ IF ( P6 .EQS. "" ) THEN P6 = 0
$ IF F$EXTRACT(0,1,P4) .EQS. "@"
$ THEN sym = P4 - "@"
$      P4 = "''sym'"
$ ENDIF
$ P4 = F$EDIT(P4,"UPCASE")
$ S  = F$LOCATE(P5,P4) + 1               ! Determine field length
$ P4 = P5 + P4                           ! Add separator to front of list...
$ T  = P5 + F$EDIT(P1,"COLLAPSE,UPCASE") ! ...and to target
$ L  = F$LOCATE( F$EDIT(T,"COLLAPSE,UPCASE"), P4 )      ! Test substring
$ IF ( L .LT. F$LENGTH(P4) ) .AND. ( L-(L/S)*S .EQ. 0 ) ! Found?
$ THEN L = ( ( L + 1 ) / S ) + 1                        ! Calculate offset
$      ! Return both the full command and its element #:
$      'P2'     == F$EDIT( F$ELEMENT(L,P5,P4), "COLLAPSE" )
$      'P2'_Num == L  ! 1-based: 1=first command, 2=second, ...
$      EXIT 1
$ ELSE 'P2'     == ""
$      'P2'_Num == -1
$      WRITE sys$output "\''P1'\ (expecting: ''F$EDIT(P4,"COLLAPSE")')"
$      IF P6
$      THEN EXIT 1           ! return "" and -1 to indicate parse-fail
$      ELSE EXIT %X00038092  ! %DCL-E-IVVERB, unrecognized command verb (decimal 229522)
$      ENDIF
$ ENDIF
$ ENDSUBROUTINE  ! DCL$CmdParse
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$DeleteGlobalSymbols:  SUBROUTINE
$ ! Doc : Deletes global symbols from list P1; usually called by com-file's cleanup,
$ !       may be called more than once for separate lists.
$ !  Examples:
$ !     $ DCL$CALL DeleteGlobalSymbols "Cmd$Answer,Cmd$Answer_Num,Func_Result"
$ !     $ DCL$CALL DeleteGlobalSymbols "ThisNode,ThisReport,ThisMsg,Count$Dups"
$ !  P1 : comma-separated list of global symbols to delete
$ !
$ ON CONTROL_Y THEN GOSUB DGSCtrl_Y
$ ON ERROR THEN EXIT %X2C  ! abort...
$ ! Delete global symbols --
$ j = 0
$DSLoop:
$ sym = F$ELEMENT( j, COMMA, P1 )
$ IF ( sym .EQS. COMMA ) THEN GOTO DScont
$ IF ( F$TYPE( 'sym' ) .NES. "" ) THEN DELETE /SYMBOL /GLOBAL 'sym'
$ j = j + 1
$ GOTO DSLoop
$DSCont:
$ EXIT 1
$ !
$DGStrl_Y:
$ RETURN %X2C  ! abort...
$ ENDSUBROUTINE  ! DCL$DeleteGlobalSymbols
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$MakeDir:  SUBROUTINE
$ ! Doc : Make a subdirectory in/at the working directory or a specified
$ !       directory, if that subdirectory does not already exist; and
$ !       create a logical name for it.
$ !  Example:
$ !     $ DCL$CALL MakeDir TEST mytest sys$login
$ !  P1 : Name of temporary subdirectory (default is "TEMP")
$ !  P2 : Logical name for the full path to this subdirectory
$ !  P3 : Logical name for this fully-specified subdirectory
$ !
$ ON CONTROL_Y THEN GOSUB MTDCtrl_Y
$ ON ERROR THEN EXIT %X2C  ! abort...
$ ! 
$ IF ( P1 .EQS. "" ) THEN P1 = "TEMP"
$ IF ( P3 .NES. "" )
$ THEN path = F$TRNLNM( P3 ) - "]"
$ ELSE path = F$ENVIRONMENT( "DEFAULT" ) - "]"
$ ENDIF
$ IF ( F$SEARCH( "''P1'.DIR;1" ) .EQS. "" )
$ THEN CREATE /DIRECTORY 'logqual' 'path'.'P1']
$ ENDIF
$ DEFINE /PROCESS /NOLOG 'P2' 'path'.'P1']
$ EXIT 1
$ !
$MTDCtrl_Y:
$ RETURN %X2C  ! abort...
$ ENDSUBROUTINE  ! DCL$MakeDir
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$ToolsDebug:  SUBROUTINE
$ ! Doc : Turns on-or-off DCL com-file "verbosity" debugging.
$ !       This subroutine does not fully supercede TOOLS$DEBUG.COM --
$ !       Note that this implements only a portion of TOOLS$DEBUG.COM,
$ !       specifically control of logical name TOOLS$DEBUG itself.
$ !  Example:
$ !     $ DCL$CALL ToolsDebug ON TRUE
$ !     $ DCL$CALL ToolsDebug OFF
$ !  P1 : TRUE/ON/1 enables debugging, FALSE/OFF/0 disables
$ !  P2 : TRUE/YES/1 enables output verification of Tools$Debug state,
$ !       FALSE/NO/0 disables same
$ !
$ ON ERROR THEN EXIT %X2C  ! abort...
$ IF ( P1 .EQS. "ON" ) .OR. ( F$EXTRACT(0,1,P1) .EQS. "Y" ) .OR. ( P1 .EQ. 1 )
$ THEN P1 = "TRUE"
$ ELSE P1 = "FALSE"
$ ENDIF
$ IF ( P2 .EQS. "" ) THEN P2 = 0
$ IF P1
$ THEN DEFINE /NOLOG /PROCESS TOOLS$Debug 'P1'
$      SET PREFIX "(!5%T) "     !augments SET VERIFY/F$VERIFY() display
$      IF P2
$      THEN SHOW LOGICAL /PROCESS /FULL TOOLS$Debug
$           wso "%TOOLS$DEBUG-I-ON, /PROCESS logical TOOLS$DEBUG is now ON"
$      ENDIF
$ ELSE IF F$TRNLNM("TOOLS$Debug","LNM$PROCESS") .NES. "" THEN DEASSIGN /PROCESS TOOLS$Debug
$      SET NOPREFIX
$      IF P2
$      THEN wso "%TOOLS$DEBUG-I-OFF, /PROCESS logical TOOLS$DEBUG is now OFF"
$      ENDIF
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! DCL$ToolsDebug
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$Setup:  SUBROUTINE
$ ! Doc : Sets up all global symbols & logical names for
$ !       this DCL$SUBROUTINE_LIBRARY
$ !  Example:
$ !     $ ! This is the library-initialization, so must use full file-spec:
$ !     $ @dev:[dir]DCL$SUBROUTINE_LIBRARY Setup
$ !     $ @dev:[dir]DCL$SUBROUTINE_LIBRARY Setup TRUE
$ !  P1 : verification (output-trace)
$ !
$ proc = F$ENVIRONMENT( "PROCEDURE" )
$ dd   = F$PARSE( proc, , , "DEVICE" ) + F$PARSE( proc, , , "DIRECTORY" )
$ fac  = F$PARSE( proc, , , "NAME" )
$ DEFINE /PROCESS /NOLOG DCL$SLhome 'dd'
$ DCL$CALL == "@DCL$SLhome:''fac'"
$ IF ( F$TRNLNM( "TOOLS$DEBUG" ) ) .OR. ( P1 )
$ THEN dashcount = 70
$      dashes = F$FAO( "!#*-", dashcount )
$      wso ""
$      wso dashes
$      wso F$FAO( "%!AS-I-SETUP, done for !AS...", fac, fac )
$      SHOW LOGICAL /FULL /PROCESS DCL$SLhome
$      SHOW SYMBOL /GLOBAL DCL$CALL
$      wso dashes
$      wso ""
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! DCL$Setup
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$«»:  SUBROUTINE
$ ! Doc : «»
$ !  Example:
$ !     $ DCL$CALL «»
$ !  P1 : «»
$ !
$ ON CONTROL_Y THEN GOSUB «»Ctrl_Y
$ ON ERROR THEN EXIT %X2C  ! abort...
$ 
$ EXIT 1
$ !
$«»Ctrl_Y:
$ RETURN %X2C  ! abort...
$ ENDSUBROUTINE  ! DCL$«»
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$«»:  SUBROUTINE
$ ! Doc : «»
$ !  Example:
$ !     $ DCL$CALL «»
$ !  P1 : «»
$ !
$ ON CONTROL_Y THEN GOSUB «»Ctrl_Y
$ ON ERROR THEN EXIT %X2C  ! abort...
$ 
$ EXIT 1
$ !
$«»Ctrl_Y:
$ RETURN %X2C  ! abort...
$ ENDSUBROUTINE  ! DCL$«»
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$ !! $«»:  SUBROUTINE
$ !! $ ! Doc : «»
$ !! $ !  Example:
$ !! $ !     $ DCL$CALL «»
$ !! $ !  P1 : «»
$ !! $ !
$ !! $ ON CONTROL_Y THEN GOSUB «»Ctrl_Y
$ !! $ ON ERROR THEN EXIT %X2C  ! abort...
$ !! $
$ !! $ EXIT 1
$ !! $ !
$ !! $«»Ctrl_Y:
$ !! $ RETURN %X2C  ! abort...
$ !! $ ENDSUBROUTINE  ! DCL$«»
$ ! ==========
$ !
$ !
$Help:                                                             !'F$VERIFY(0)'
$ TYPE /PAGE sys$input

  To setup:  $ [1m@dev:[dir.subdir]DCL$SUBROUTINE_LIBRARY SETUP[0m
  
  which defines all necessary symbols and logical names to
  use this DCL Subroutine Library.
  
  Use:       $ [1mDCL$CALL [4mRoutineName[0m [ "P1" [ "P2" ] ... [ "P7" ] ]
  
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
