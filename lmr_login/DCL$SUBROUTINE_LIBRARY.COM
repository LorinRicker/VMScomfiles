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
$ dcl$slversion   = "01.00.07"         ! maintain with edits
$ dcl$sldatestamp = "16-MAY-2017"
$ dcl$lastversion = F$TRNLNM( "DCL$SLversion" )
$ IF ( F$TRNLNM( "DCL$SLversion" ) .EQS. "" ) -
  .OR. ( F$LOCATE( dcl$slversion, dcl$lastversion ) .GE. F$LENGTH( dcl$lastversion ) )
$ THEN DEFINE /PROCESS /NOLOG DCL$SLversion "v''dcl$slversion' (''dcl$sldatestamp')"
$ ENDIF
$ !
$ ! Need some help?
$ p1param = F$EXTRACT( 0, 4, F$EDIT(P1,"UPCASE,TRIM") ) - "-" - "-"  ! strip any leading - or --
$ IF ( p1param .EQS. "HELP" ) .OR. ( P1 .EQS. "?" ) THEN GOTO Help
$ !
$ dcl$Verbose = F$TRNLNM( "TOOLS$DEBUG" )
$ !
$ wso        = "WRITE sys$output"
$ Fac        = "DCL$SUBROUTINE_LIBRARY"
$ COMMA      = ","
$ BANG       = "!"
$ UNDERSCORE = "_"
$ !
$ ! ----------------------------------------------------------------------
$ ! Update this list as new subroutines are added -- keep this sorted:
$ RegisteredRoutines = ",Alias,CmdParse,DeleteGloSyms,DiscoverDisks" -
                     + ",MakeDir,PureDCL,ToolsDebug,Setup" -
                     + ",«»" -
                     + COMMA
$ ! ----------------------------------------------------------------------
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
$ ! Dispatch:  P1 = Subroutine to call; P2..P8 are com-line parameters to pass --
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
$DCL$Alias:  SUBROUTINE
$ ! Doc : Conditionally define a global symbol (alias command) P1 for invoking
$ !       the command file P2 (which must exist).
$ !  Example:
$ !     $ DCL$CALL Alias "dwho" "@cmd:dclwho" "SHOW USERS"
$ ! P1 : command symbol
$ ! P2 : command file
$ ! P3 : alternate command string
$ !
$ SET NOON
$ IF F$LOCATE("*",P1) .LT. F$LENGTH(P1)
$ THEN AbbrSym = F$ELEMENT(0,"*",P1)
$ ELSE AbbrSym = P1
$ ENDIF
$ FullSym = P1 - "*"
$ IF ( F$TYPE( 'AbbrSym' ) .NES. "" )  !command symbol already exists?
$ THEN DELETE /SYMBOL /GLOBAL 'AbbrSym'
$ ENDIF
$ P2 = F$EDIT(P2,"UPCASE")
$ IF F$EXTRACT(0,1,P2) .EQS. "$" THEN P2 = P2 - "$" - ".EXE" + ".EXE"
$ IF F$EXTRACT(0,1,P2) .EQS. "@" THEN P2 = P2 - "@" - ".COM" + ".COM"
$ IF F$SEARCH(P2) .NES. ""
$ THEN IF F$PARSE(P2,,,"TYPE","SYNTAX_ONLY") .EQS. ".EXE"
$      THEN 'P1' == "$''P2'"
$      ELSE 'P1' == "@''P2'"
$      ENDIF
$      IF dcl$Verbose THEN SHOW SYMBOL /GLOBAL 'FullSym'
$ ELSE IF ( P3 .NES. "" )
$      THEN 'P1' == "''P3'"  ! alternate (default DCL) command
$      ELSE IF LMR$Unavailable .EQS. ""
$           THEN LMR$Unavailable == FullSym
$           ELSE LMR$Unavailable == LMR$Unavailable + ", " + FullSym
$           ENDIF
$      ENDIF
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! DCL$Alias
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
$ IF ( P6 .EQS. "" ) THEN P6 = "FALSE"
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
$      THEN EXIT %X00038092  ! %DCL-E-IVVERB, unrecognized command verb (decimal 229522);
$      ELSE EXIT 1           ! or return "" and -1 to indicate parse-fail
$      ENDIF
$ ENDIF
$ ENDSUBROUTINE  ! DCL$CmdParse
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$DeleteGloSyms:  SUBROUTINE
$ ! Doc : Deletes global symbols from list P1; usually called by com-file's cleanup,
$ !       may be called more than once for separate lists.
$ !  Examples:
$ !     $ DCL$CALL DeleteGloSyms "Cmd$Answer,Cmd$Answer_Num,Func_Result"
$ !     $ DCL$CALL DeleteGloSyms "ThisNode,ThisReport,ThisMsg,Count$Dups"
$ !  P1 : comma-separated list of global symbols to delete
$ !
$ SET NOON
$ dfn = "DEFINE /NOLOG /USER_MODE"
$ j = 0
$DCL$DGSLoop:
$ sym = F$ELEMENT( j, COMMA, P1 )
$ IF ( sym .EQS. COMMA ) THEN GOTO DCL$DGSexit
$ IF ( F$TYPE( 'sym' ) .NES. "" )
$ THEN IF dcl$Verbose THEN wso "%DCL$DELETEGLOSYMS-I-DELSYM, delete symbol ""''sym'"""
$      DELETE = "DELETE"
$      dfn sys$output NLA0:  ! suppress "undefined symbol" noise
$      dfn sys$error  NLA0:
$      DELETE /SYMBOL /GLOBAL 'sym'
$ ENDIF
$ j = j + 1
$ GOTO DCL$DGSLoop
$DCL$DGSexit:
$ EXIT 1
$ ENDSUBROUTINE  ! DCL$DeleteGloSyms
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$DiscoverDisks:  SUBROUTINE
$ ! Doc : Create, by discovery, a list (comma-separated string) of disks on this system,
$ !       suitable for F$ELEMENT(j,...)-looping through for caller processing.
$ !  Example:
$ !     $ DCL$CALL DiscoverDisks "SHDW_MEMBER,FOR,AVL,!MNT"
$ !  P1 : Name of the user global symbol to receive the result-list
$ !  P2 : Disk criteria list for inclusion in the result (comma-separated),
$ !       with a leading "!" on the criterion name for negation of that one
$ !       (e.g., "...,!MNT,..." means "not mounted").
$ !       Criteria include:
$ !       ALL (allocated), AVL (available/online), DMT (marked for dismount),
$ !       EXISTS (device exists), FOD (file-oriented device), FOR (mounted foreign),
$ !       SHDW_MEMBER (shadow-member device), SWL (software write-locked)
$ !       Only one of these criteria needs to be met (not all of them) for a disk
$ !       device to be included in the result list
$ !  P3 : TRUE (default) to filter out LDAxxx: (logical disk) devices,
$ !       FALSE to include them
$ !
$ SET NOON
$ IF ( P2 .EQS. "" ) THEN P2 = "AVL,MNT,SHDW_MEMBER"
$ IF ( P3 .EQS. "" ) THEN P3 = "TRUE"
$ DDpayload = ""
$DCL$DDLoop:
$ dev = F$DEVICE( "*", "DISK" ) - UNDERSCORE
$ IF ( dev .EQS. "" ) THEN GOTO DCL$DDexit   ! done...
$ IF P3 -
  THEN IF ( F$LOCATE( "LDA", dev ) .LT. F$LENGTH( dev ) ) -
       THEN GOTO DCL$DDLoop  ! skip this disk
$ j = 0
$ rejected = 0
$DCL$Inner:
$ criterion = F$ELEMENT( j, COMMA, P2 )
$ IF ( criterion .EQS. COMMA ) THEN GOTO DCL$DDLoop
$ IF dcl$Verbose THEN wso ">>> j: ""''j'""   dev: ""''dev'""   criterion: ""''criterion'"""
$ IF ( F$EXTRACT( 0, 1, criterion ) .EQS. BANG )
$ THEN ! Negate this criterion
$      criterion = criterion - BANG
$      IF ( .NOT. F$GETDVI( dev, "''criterion'" ) ) THEN GOTO DCL$Accum
$ ELSE ! Affirm this criterion
$      IF ( F$GETDVI( dev, "''criterion'" ) ) THEN GOTO DCL$Accum
$ ENDIF
$ j = j + 1
$ GOTO DCL$Inner
$DCL$Accum:
$ ! Accumulate the payload:
$ DDpayload = DDpayload + COMMA + dev
$ GOTO DCL$DDLoop
$ !
$DCL$DDexit:
$ DDlen = F$LENGTH( DDpayload )
$ ! Assign payload to the global variable, but strip the leading ","
$ IF ( DDpayload .NES. "" )
$ THEN 'P1' == F$EXTRACT( 1, DDlen, DDpayload )
$ ELSE 'P1' == ""
$ ENDIF
$ IF dcl$Verbose THEN wso F$FAO( "%DCL$DISCOVERDISKS-I-ECHO, ''P1' == ""!AS""", -
                                  'P1' )
$ EXIT 1
$ ENDSUBROUTINE  ! DCL$DiscoverDisks
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
$ ON CONTROL_Y THEN GOSUB DCL$MTDCtrl_Y
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
$DCL$MTDCtrl_Y:
$ RETURN %X2C  ! abort...
$ ENDSUBROUTINE  ! DCL$MakeDir
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$PureDCL:  SUBROUTINE
$ ! Doc : Sanity check for a site-specific global symbol which appropriates
$ !       a DCL command verb, make it go away!...
$ !  Example:
$ !     $ DCL$CALL PureDCL
$ !  P1 : comma-separated list of DCL command verbs (words) to decommission
$ !
$ SET NOON
$ dfn = "DEFINE /NOLOG /USER_MODE"
$ j = 0
$DCL$PDLoop:
$ sym = F$ELEMENT( j, COMMA, P1 )
$ IF ( sym .EQS. COMMA ) THEN GOTO DCL$PDexit
$ IF ( F$TYPE( 'sym' ) .NES. "" )
$ THEN IF dcl$Verbose THEN wso "%DCL$PureDCL-I-DELSYM, purifying command verb ""''sym'"" (delete symbol)"
$      DELETE = "DELETE"
$      dfn sys$output NLA0:  ! suppress "undefined symbol" noise
$      dfn sys$error  NLA0:
$      DELETE /SYMBOL /GLOBAL 'sym'
$ ENDIF
$ j = j + 1
$ GOTO DCL$PDLoop
$DCL$PDexit:
$ EXIT 1
$ ENDSUBROUTINE  ! DCL$PureDCL
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
$ IF ( dcl$Verbose ) .OR. ( P1 )
$ THEN dashcount = 80
$      dashes = F$FAO( "!#*-", dashcount )
$      wso ""
$      wso dashes
$      wso F$FAO( "%!AS-I-SETUP, done for !AS...", fac, fac )
$      SHOW LOGICAL /PROCESS DCL$SLversion
$      SHOW LOGICAL /PROCESS DCL$SLhome
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
$ SET NOON
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
$ ! Prototype:
$ ! ==========
$ !! DCL$ $«»:  SUBROUTINE
$ !! $ ! Doc : «»
$ !! $ !  Example:
$ !! $ !     $ DCL$CALL «»
$ !! $ !  P1 : «»
$ !! $ !
$ !! $ ON CONTROL_Y THEN GOSUB DCL$«»Ctrl_Y
$ !! $ ON ERROR THEN EXIT %X2C  ! abort...
$ !! $
$ !! $ EXIT 1
$ !! $ !
$ !! $DCL$«»Ctrl_Y:
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
