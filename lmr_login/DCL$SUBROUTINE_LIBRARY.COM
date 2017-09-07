$ ! DCL$SUBROUTINE_LIBRARY.COM --                                  'F$VERIFY(0)'
$ !
$ ! Copyright © 2012-2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ dcl$slversion   = "01.13.01"         ! maintain with edits
$ dcl$sldatestamp = "07-SEP-2017"
$ dcl$lastversion = F$TRNLNM( "DCL$SLversion" )
$ IF ( F$TRNLNM( "DCL$SLversion" ) .EQS. "" ) -
  .OR. ( F$LOCATE( dcl$slversion, dcl$lastversion ) .GE. F$LENGTH( dcl$lastversion ) )
$ THEN DEFINE /PROCESS /NOLOG DCL$SLversion "v''dcl$slversion' (''dcl$sldatestamp')"
$ ENDIF
$ !
$ ! Need some help?
$ p1param = F$EDIT( P1, "UPCASE,TRIM" ) - "-" - "-"  ! strip any leading - or --
$ p1param = F$EXTRACT( 0, 4, p1param )
$ IF ( p1param .EQS. "HELP" ) .OR. ( P1 .EQS. "?" ) THEN GOTO Help
$ !
$ dcl$Verbose = F$TRNLNM( "TOOLS$DEBUG" )
$ !
$ wso        = "WRITE sys$output"
$ Fac        = "DCL$SUBROUTINE_LIBRARY"
$ BANG       = "!"
$ COLON      = ":"
$ COMMA      = ","
$ DASH       = "-"
$ DOLLAR     = "$"
$ DQUOTE     = """"
$ PLUS       = "+"
$ SPACE      = " "
$ UNDERSCORE = "_"
$ BREADCRUMB = "«" + "»"
$ DOCMARKER  = "$ !#! "
$ DOCMARKlen = F$LENGTH( DOCMARKER )
$ !
$ ! ----------------------------------------------------------------------
$ ! Update this list as new subroutines are added -- keep this sorted:
$ RegisteredRoutines = COMMA                                            -
                     +  "Alias,BatchAfterDate"                          -
                     +  ",CmdParse,CommandLine,DefineANSIdef"           -
                     + ",DefineClearscreen,DeleteGloSyms,DiscoverDisks" -
                     + ",LogRollover,MakeDir,PureDCL"                   -
                     + ",Thousands,ToolsDebug"
$ ! and with this group always last:
$ RegisteredRoutines = RegisteredRoutines                               -
                     + ",Setup,Doc,ShowRegisteredRoutines,Version"      -
                     + COMMA
$ ! ----------------------------------------------------------------------
$ ! ==========
$ IF DCL$Verbose
$ THEN wso F$FAO( "%!AS-I-RRLEN, RegisteredRoutine length = !SL", -
                  Fac, F$LENGTH( RegisteredRoutines ) )
$ ENDIF
$ ! ==========
$ !
$ ! Display library version:
$ IF ( p1param .EQS. "VERS" )
$ THEN CALL DCL$Version
$      EXIT 1  ! 'F$VERIFY(0)'
$ ENDIF
$ !
$ ! Show/display all Registered Routines --
$ IF ( p1param .EQS. "SHOW" ) .OR. ( p1param .EQS. "ROUT" )
$ THEN ! set-up for dcl$call DCL$ShowRegisteredRoutines
$      P1 = "ShowRegisteredRoutines"  ! call this routine
$      P2 = RegisteredRoutines
$      ! ...Fall-thru to call DCL$ShowRegisteredRoutines
$ ENDIF
$ !
$ ! Honor an obvious synonym for Documentation:
$ IF ( p1param .EQS. "API" ) THEN P1 = "DOC"
$ !
$ ! Used by DCL$Doc (and elsewhere?) --
$ isANSI = F$GETDVI( "sys$output", "TT_ANSICRT" )
$ IF ( isANSI )
$ THEN esc[0,8]= %X1B              ! 27 decimal, 033 octal - ESCape character
$         NORM = esc + "[0m"       ! Normal rendition
$         BOLD = esc + "[1m"       ! Bold
$        ULINE = esc + "[4m"       ! Underline
$ ELSE    NORM = ""
$         BOLD = ""
$        ULINE = ""
$ ENDIF
$ !
$ ! ==========
$ ! Dispatch:  P1 = Subroutine to call; P2..P8 are com-line parameters to pass --
$ !            Note that internal subroutine names are prefixed by "DCL$" to
$ !            limit conficts with external, non-library routines...
$ ! ==========
$ IF DCL$Verbose THEN ver = F$VERIFY(1)
$ CALL DCL$'P1' "''P2'" "''P3'" "''P4'" "''P5'" "''P6'" "''P7'" "''P8'"
$ ! ==========
$ stat = $STATUS
$ EXIT 'stat'  ! 'F$VERIFY(0)'
$ !
$ !
$ ! ================================================================================
$ ! Prototype:
$ !
$ !! $ !
$ !! $ ! ==========
$ !! $DCL$«»:  SUBROUTINE
$ !! $ !#! Doc : «»
$ !! $ !#!   Example:
$ !! $ !#!     $ DCL$CALL «»
$ !! $ !#!   P1 : «»
$ !! $ !
$ !! $ SET NOON
$ !! $ «»
$ !! $ EXIT 1
$ !! $ ENDSUBROUTINE  ! DCL$«»
$ !! $ ! ==========
$ !! $ !
$ !
$ ! ==========
$DCL$Alias:  SUBROUTINE
$ !#! Doc : Conditionally define a global symbol (alias command) P1 for invoking
$ !#!       the command file P2 (which must exist).
$ !#!   Example:
$ !#!     $ DCL$CALL Alias "dwho" "@cmd:dclwho" "SHOW USERS"
$ !#!   P1 : global command symbol for return value
$ !#!   P2 : command file
$ !#!   P3 : alternate command string
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
$DCL$BatchAfterDate:  SUBROUTINE
$ !#! Doc : Determine a "next-submit date", particularly for batch jobs
$ !#!       SUBMITted with /AFTER="''BATCH$SubmitAfter'" (but can also
$ !#!       be used with PRINT jobs, etc.)
$ !#!   Example:
$ !#!     $ DCL$CALL BatchAfterDate "BATCH$SubmitAfter" "30" "05:00" "SUNDAY:2"
$ !#!       ...would generate a date for "next month, the 2nd-Sunday-thereof, at 5am"
$ !#!   P1 : global command symbol for return value, default is BATCH$SubmitAfter
$ !#!   P2 : days-ago, controls daily/weekly or monthly scheduling:
$ !          if <28, daily/weekly schedule, else (>=28) monthly (default)
$ !#!   P3 : hour-to-run (default "00:00")
$ !#!   P4 : weekday to run: "SUNDAY" or "SUNDAY:1" for "1st-Sunday-of-Month",
$ !          "TUESDAY:3" for "3rd-Tuesday-of-Month", no default
$ !
$ ON CONTROL_Y THEN GOSUB BADCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ IF ( P1 .EQS. "" ) THEN P1 = "BATCH$SubmitAfter"
$ IF ( P2 .EQS. "" ) THEN P2 = "30"
$ IF ( P3 .EQS. "" ) THEN P3 = "00:00"
$ 'P1' == ""
$ shortmonth = 28  ! magic number
$ !
$ IF ( F$INTEGER( P2 ) .LT. shortmonth )
$ THEN ! doing Daily or Weekly scheduling...
$      NextBatchRun = "TODAY+" + P2 + "-" + P3 + ":00.00"
         ! "+1-xx:xx" = "TOMORROW" -- for test/eval
         ! "+7-xx:xx" = "Weekly/next week" -- for production
         ! VMS help: Whenever a plus sign (+) precedes the delta time,
         !           enclose the entire time spec in quotation marks.
$      GOTO AfterQual
$ ELSE ! doing Monthly reporting...
$      now = F$TIME()
$      nowday = F$CVTIME(now,"COMPARISON","DAY")
$      IF ( F$INTEGER(nowday) .LT. 16 )
$      THEN forward  = "32"
$           backward = "16"
$      ELSE forward  = "16"
$           backward = "32"
$      ENDIF
$      prevdate      = F$CVTIME("TODAY-''backward'-00:00","ABSOLUTE","DATE")
$      prevmonth     = F$CVTIME(prevdate,"ABSOLUTE","MONTH")
$      prevyear      = F$CVTIME(prevdate,"ABSOLUTE","YEAR")
$      nextdate      = F$CVTIME("TODAY+''forward'-00:00","ABSOLUTE","DATE")
$      nextmonth     = F$CVTIME(nextdate,"ABSOLUTE","MONTH")
$      nextyear      = F$CVTIME(nextdate,"ABSOLUTE","YEAR")
$      thedate       = 1
$      ReportDate    = F$STRING( thedate ) + DASH + prevmonth + DASH + prevyear
$      NextBatchDate = F$STRING( thedate ) + DASH + nextmonth + DASH + nextyear
$      NextBatchHour = P3 + ":00.00"
$      IF ( P4 .EQS. "" )
$      THEN ! Just set up default 1st-of-month...
$           NextBatchRun = NextBatchDate + PLUS + NextBatchHour
$      ELSE ! Figure out "Nth-*day-of-month" -- e.g., "SUNDAY:1" or "SUNDAY"
$           TargetDay = F$EDIT( F$ELEMENT( 0, COLON, P4 ), "TRIM,UPCASE" )
$           Nth = F$ELEMENT( 1, COLON, P4 )  ! ":N" may be missing...
$           IF ( Nth .EQS. COLON ) THEN Nth = "1"
$           Nth = F$INTEGER( Nth )
$           j   = 1
$FindingNth:
$           thisday = F$EDIT( F$CVTIME( NextBatchDate, , "WEEKDAY" ), "TRIM,UPCASE" )
$           IF ( thisday .EQS. TargetDay )
$           THEN IF ( j .EQ. Nth )
$                THEN ! Success: found the right Nth-Day-of-Month...
$                     NextBatchRun = NextBatchDate + PLUS + NextBatchHour
$                     GOTO AfterQual
$                ELSE j = j + 1
$                     GOTO TryNextDate
$                ENDIF
$           ELSE GOTO TryNextDate
$           ENDIF
$TryNextDate:
$           thedate = thedate + 1
$           IF ( thedate .LE. shortmonth )  ! sanity check...
$           THEN NextBatchDate = F$STRING( thedate ) + DASH + nextmonth + DASH + nextyear
$                GOTO FindingNth
$           ELSE wso F$FAO( "%!AS-F-CANNOT_HAPPEN, Find-Nth runaway-loop in batch report scheduling", Fac )
$                EXIT %X2C  ! ...abort!
$           ENDIF
$      ENDIF
$ ENDIF
$AfterQual:
$ 'P1' == "/AFTER=" + DQUOTE + NextBatchRun + DQUOTE
$ IF dcl$Verbose THEN SHOW SYMBOL /GLOBAL 'P1'
$ EXIT 1
$ !
$BADCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! DCL$BatchAfterDate
$ !
$ !
$ ! ==========
$DCL$CommandLine:  SUBROUTINE
$ !#! Doc : Set Parse-Style and Case-Lookup for this process.
$ !#!   Example:
$ !#!     $ DCL$CALL CommandLine [ keyword1 [ keyword2 ] ]
$ !#!     $ DCL$CALL CommandLine VMS    ! set TRADITIONAL parse-style and BLIND case-lookup
$ !#!     $ DCL$CALL CommandLine LINUX  ! set EXTENDED and BLIND
$ !#!     $ DCL$CALL CommandLine EXTENDED SENSITIVE  ! same as POSIX
$ !#!   P1 : Keywords for setting these process DCL command parse-style and case-lookups:
$ !#! &/or : T[RADITIONAL] - Full "normalization" of command, including auto-UPPERcasing
$ !#!   P2 :    of file specifications (anything not guarded in "double-quote marks").
$ !#!        E[XTENDED]    - Suppress "normalization" of command; in particular, leaves
$ !#!           file specifications in the lower/UPPER/Mixed-case as typed/entered.
$ !#!        B[LIND]       - Perform file lookups in case-insensitive (blind) mode, so
$ !#!           that "foo" matches "FOO", "foo", "Foo", "FoO", etc.
$ !#!        S[ENSITIVE]   - Perform file lookups with full case-sensitivity, or exact-
$ !#!           match, so that "foo" matches/finds only "foo", not "FOO", "Foo", etc.
$ !#!        D[EFAULT]
$ !#!        or V[MS]  = TRADITIONAL and BLIND
$ !#!        L[INUX]   = EXTENDED and BLIND
$ !#!        P[OSIX]   = EXTENDED and SENSITIVE
$ !#!        SHOW      = same as P3 below
$ !#!   P3 : SHOW, or any truthy or non-empty-string value will show/echo the set-results.
$ !
$ SET NOON
$ IF ( P1 .EQS. "" )  ! no parameters at all means SHOW...
$ THEN P3 = "SHOW"
$      GOTO DCL$CLshow
$ ENDIF
$ Q1 = ""
$ Q2 = ""
$  j = 1
$ CmdSet =  "TRADITIONAL|EXTENDED   |BLIND      |SENSITIVE  " -
         + "|DEFAULT    |VMS        |LINUX      |POSIX      " -
         + "|SHOW       "
$DCL$CLloop:
$ IF ( P'j' .NES. "" )
$ THEN cmd = P'j'
$      CALL DCL$CmdParse "''cmd'"  Cmd$Answer "VMS" "''CmdSet'"
$      GOTO DCL$CL_'Cmd$Answer'
$DCL$CL_TRADITIONAL:
$      Q1 = "TRADITIONAL"
$      GOTO DCL$CLcont
$DCL$CL_EXTENDED:
$      Q1 = "EXTENDED"
$      GOTO DCL$CLcont
$DCL$CL_BLIND:
$      Q2 = "BLIND"
$      GOTO DCL$CLcont
$DCL$CL_SENSITIVE:
$      Q2 = "SENSITIVE"
$      GOTO DCL$CLcont
$DCL$CL_DEFAULT:
$DCL$CL_VMS:
$      Q1 = "TRADITIONAL"
$      Q2 = "BLIND"
$      GOTO DCL$CLcont
$DCL$CL_LINUX:
$      Q1 = "EXTENDED"
$      Q2 = "BLIND"
$      GOTO DCL$CLcont
$DCL$CL_POSIX:
$      Q1 = "EXTENDED"
$      Q2 = "SENSITIVE"
$      GOTO DCL$CLcont
$DCL$CL_SHOW:
$      P3 = "SHOW"
$      GOTO DCL$CLcont
$DCL$CLcont:
$      IF ( j .GE. 2 )
$      THEN GOTO DCL$CLdo
$      ELSE j = j + 1
$           GOTO DCL$CLloop
$      ENDIF
$ ENDIF
$DCL$CLdo:
$ IF ( Q1 .NES. "" ) THEN Q1 = "/PARSE_STYLE=" + Q1
$ IF ( Q2 .NES. "" ) THEN Q2 = "/CASE_LOOKUP=" + Q2
$ SET PROCESS 'Q1' 'Q2'
$DCL$CLshow:
$ IF ( P1 .EQS. "" )
$ THEN wso "  usage: DCL$CALL CommandLine [ P1 ] [ P2 ] [ SHOW ]"
$      wso "  where: P1 - VMS | LINUX | POSIX"
$      WSO "                | TRADITIONAL | EXTENDED"
$      wso "         P2 - BLIND | SENSITIVE"
$ ENDIF
$ IF ( P3 .NES. "" ) -  ! e.g., SHOW
  THEN wso F$FAO( "%!AS-S-PROCESS, current command-line parsing: !AS, !AS", -
                  Fac, F$GETJPI("","PARSE_STYLE_PERM"), F$GETJPI("","CASE_LOOKUP_PERM") )
$Cleanup:
$ CALL DCL$DeleteGloSyms "Cmd$Answer"
$ EXIT 1
$ ENDSUBROUTINE  ! DCL$CommandLine
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$CmdParse: SUBROUTINE
$ !#! Doc : Attempts to match a command word (P1) against a list of possible command words (P4),
$ !#!       where P1 may be a uniquely-recognized abbreviation of any of the possible words;
$ !#!       returns result as a user-defined global symbol, or an error condition if no match.
$ !#!   Example:
$ !#!     $ DCL$CALL CmdParse "''P1'" File$Component "NAME" "NODE|DEV |DIR |NAME|TYPE|VERS|FULL"
$ !#!   P1 : (the user's) Command word to parse
$ !#!   P2 : Name of global symbol to receive answer (default is Cmd$Answer)
$ !#!   P3 : Default command (used if P1 is "")
$ !#!   P4 : Command-set ("C1|C2[|Cn...]") -- options must be same-length fields;
$ !#!        alternatively "@symbol" where "symbol" contains command-set (this
$ !#!        accommodates very long command-sets, >255 characters)
$ !#!   P5 : Command separator (default is vert-bar/pipe "|")
$ !#!   P6 : FALSE/TRUE flag to either return "" as failed-result (default is FALSE),
$ !#!        or to hard-stop-fail (TRUE)
$ !
$ SET NOON
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
$DCL$DefineANSIseq:  SUBROUTINE
$ !#! Doc : Define ANSI terminal color and rendition Escape Sequences
$ !#!       as DCL global symbols.
$ !#!   Example:
$ !#!     $ DCL$CALL DefineANSIseq
$ !#!   P1 : (none)
$ !
$ SET NOON
$ esc[0,8]== %X1B                   !  27 decimal,  033 octal - ESCape character
$ !
$ ! ANSI renditions:
$         NORM == esc + "[0m"       ! Normal rendition
$           NC == NORM              ! No Color
$         BOLD == esc + "[1m"       ! Bold
$        ULINE == esc + "[4m"       ! Underline
$    UNDERLINE == ULINE
$        BLINK == esc + "[5m"       ! "slow", use sparingly, if at all...!
$        REVRS == esc + "[7m"       ! Reverse or inverse
$      REVERSE == REVRS
$       NOECHO == esc + "[8m"       ! no echo
$      CONCEAL == NOECHO
$ !
$ ! Not widely (or ever) supported, here for reference/completeness:
$ !      FAINT == esc + "[2m"       ! faint (dim))
$ !     ITALIC == esc + "[3m"       ! italic
$ ! BLINKRAPID == esc + "[6m"       ! "rapid"
$ !   CROSSOUT == esc + "[9m"       ! characters "marked out"
$ !
$ ! ANSI foreground or "normal intensity" colors (forces normal background)):
$        BLACK == esc + "[0;30m"    ! normal black     [  0,  0,  0] \
$          RED == esc + "[0;31m"    ! normal red       [187,  0,  0] |
$        GREEN == esc + "[0;32m"    ! normal green     [  0,187,  0] | PuTTY
$        BROWN == esc + "[0;33m"    ! normal yellow    [187,187,  0] | RGB
$         BLUE == esc + "[0;34m"    ! normal blue      [  0,  0,187] | values
$       PURPLE == esc + "[0;35m"    ! normal magenta   [187,  0,187] |
$         CYAN == esc + "[0;36m"    ! normal cyan      [  0,187,187] |
$    LIGHTGRAY == esc + "[0;37m"    ! normal white     [187,187,187] /
$ !
$ ! Note: Specify background color before foreground color --
$ !       WRITE sys$output BLUE_BG + WHITE + "This is a test!" + NORM
$ !
$ ! ANSI background colors:
$     BLACK_BG == esc + "[0;40m"    ! normal black     [  0,  0,  0] \
$       RED_BG == esc + "[0;41m"    ! normal red       [187,  0,  0] |
$     GREEN_BG == esc + "[0;42m"    ! normal green     [  0,187,  0] | PuTTY
$     BROWN_BG == esc + "[0;43m"    ! normal yellow    [187,187,  0] | RGB
$      BLUE_BG == esc + "[0;44m"    ! normal blue      [  0,  0,187] | values
$    PURPLE_BG == esc + "[0;45m"    ! normal magenta   [187,  0,187] |
$      CYAN_BG == esc + "[0;46m"    ! normal cyan      [  0,187,187] |
$ LIGHTGRAY_BG == esc + "[0;47m"    ! normal white     [187,187,187] /
$ !
$ ! ANSI foreground or "bright intensity" colors (against reverse background)):
$     DARKGRAY == esc + "[1;30m"    ! bright black     [ 85, 85, 85] \
$     LIGHTRED == esc + "[1;31m"    ! bright red       [255, 85, 85] |
$   LIGHTGREEN == esc + "[1;32m"    ! bright green     [ 85,255, 85] | PuTTY
$       YELLOW == esc + "[1;33m"    ! bright yellow    [255,255, 85] | RGB
$    LIGHTBLUE == esc + "[1;34m"    ! bright blue      [ 85, 85,255] | values
$  LIGHTPURPLE == esc + "[1;35m"    ! bright magenta   [255, 85,255] |
$    LIGHTCYAN == esc + "[1;36m"    ! bright cyan      [ 85,255,255] |
$        WHITE == esc + "[1;37m"    ! bright white     [255,255,255] /
$ !
$ EXIT 1
$ ENDSUBROUTINE  ! DCL$DefineANSIseq
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$DefineClearscreen:  SUBROUTINE
$ !#! Doc : Define ANSI clear-screen escape sequences
$ !#!       and commands.
$ !#!   Example:
$ !#!     $ DCL$CALL DefineClearscreen
$ !#!   P1 : (none)
$ !
$ SET NOON
$ IF ( F$TYPE( esc ) .NES. "STRING" )
$ THEN esc[0,8]== %X1B              !  27 decimal,  033 octal - ESCape character
$ ENDIF
$ _bckscrL == esc + "[?5h"      ! set background light
$ _bckscrD == esc + "[?5l"      ! set background dark
$ _clrscr  == esc + "[m"  -     ! set rendition normal
            + esc + "[H"  -     ! cursor to 0,0
            + esc + "[2J"       ! clear entire screen
$ !
$ clr      == "WRITE sys$output _clrscr"
$ cls      == clr     ! alias
$ clrd     == "WRITE sys$output _bckscrL,_clrscr"
$ clsd     == clrd    ! alias
$ clrl     == "WRITE sys$output _bckscrD,_clrscr"
$ clsl     == clrl    ! alias
$ EXIT 1
$ ENDSUBROUTINE  ! DCL$DefineClearscreen
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$DeleteGloSyms:  SUBROUTINE
$ !#! Doc : Deletes global symbols from list P1; usually called by com-file's cleanup,
$ !#!       may be called more than once for separate lists.
$ !#!   Examples:
$ !#!     $ DCL$CALL DeleteGloSyms "Cmd$Answer,Cmd$Answer_Num,Func_Result"
$ !#!     $ DCL$CALL DeleteGloSyms "ThisNode,ThisReport,ThisMsg,Count$Dups"
$ !#!   P1 : Global symbols to delete, as a comma-separated list
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
$DCL$Doc:  SUBROUTINE
$ !#! Doc : Display programmer API documentation for DCL$Subroutine_Library
$ !#!   Example:
$ !#!     $ DCL$CALL Doc
$ !#!   P1 : (none)
$ !
$ SET NOON
$ indent = 4
$ ! These three assignments use string "+" so that
$ ! they don't match their own search/recognition --
$ begsubr    = SPACE + "SUBROUTINE"
$ endsubr    = SPACE + "ENDSUBROUTINE"
$ OPEN /READ /SHARE /ERROR=OpenError self DCL$SLself
$DCL$SDLoop:
$ READ /END_OF_FILE=DCL$SDcont self line
$ llen = F$LENGTH( line )
$ IF ( F$EDIT( line, "TRIM" ) .EQS. "" ) THEN GOTO DCL$SDLoop  ! skip any/all blank lines
$ IF ( F$LOCATE( endsubr, line ) .LT. llen ) THEN GOTO DCL$SDLoop
$ IF ( F$LOCATE( BREADCRUMB, line ) .LT. llen ) THEN GOTO DCL$SDLoop
$ IF ( F$LOCATE( begsubr, line ) .LT. llen )
$ THEN ! Display routine name first --
$      !  Strip colon, spaces and subroutine keyword
$      line   = line - COLON - begsubr
$      !  Strip leading "$" and all spaces
$      rrname = BOLD + F$EDIT( F$EXTRACT( 1, llen-1, line), "COLLAPSE" ) + NORM
$      wso ""
$      wso F$FAO( "!#* Registered Routine: !AS", indent, rrname )
$ ELSE IF ( F$LOCATE( DOCMARKER, line ) .EQ. 0 )
$      THEN ! an internal Documentation Line, print it,
$           !   but first trim off the DOCMARKER --
$           line = F$EXTRACT( DOCMARKlen, F$LENGTH(line)-DOCMARKlen, line )
$           wso F$FAO( "!#* !AS", indent, line )
$      ! ELSE !...an ordinary line of code/comment, skip it...
$      ENDIF
$ ENDIF
$ GOTO DCL$SDLoop
$DCL$SDcont:
$ wso ""
$ wso "[End API/Doc]"
$ wso ""
$ CLOSE /NOLOG self
$ EXIT 1
$OpenError:
$ wso F$FAO( "%!AS-E-FNF, cannot open self: !AS", -
             Fac, F$TRNLNM( "DCL$SLself", "LNM$PROCESS" ) )
$ EXIT %X10018292  ! FNF
$ ENDSUBROUTINE  ! DCL$Doc
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$DiscoverDisks:  SUBROUTINE
$ !#! Doc : Create, by discovery, a list (comma-separated string) of disks on this system,
$ !#!       suitable for F$ELEMENT(j,...)-looping through for caller processing.
$ !#!   Example:
$ !#!     $ DCL$CALL DiscoverDisks DD$Disks "AVL,MNT,SHDW_MEMBER"
$ !#!   P1 : Name of the user global symbol to receive the result-list, default "DCL$Disks"
$ !#!   P2 : Disk criteria list for inclusion in the result (comma-separated),
$ !#!        with a leading "!" on the criterion name for negation of that one
$ !#!        (e.g., "...,!MNT,..." means "not mounted").
$ !#!        Criteria include:
$ !#!        ALL (allocated?)              AVL (available/online?)       DMT (marked for dismount?),
$ !#!        EXISTS (device exists?)       FOD (file-oriented device?)   FOR (mounted foreign?),
$ !#!        SHDW_MEMBER (shadow-member?)  SWL (software write-locked?)
$ !#!        Only one of these criteria needs to be met (not all of them) for a disk
$ !#!        device to be included in the result list.
$ !#!        See 'DCL Dictionary', Lexicals, F$GETDVI for the complete list of
$ !#!        argument/items for this lexical function -- here using only the
$ !#!        "true/false" queries for disks (out of all the items possible).
$ !#!   P3 : List of device-types to ignore, default is "DQA,DQB,DAD,DNFS"
$ !
$ SET NOON
$ IF ( P1 .EQS. "" ) THEN P1 = "DCL$Disks"
$ IF ( F$TYPE( 'P1' ) .NES. "" ) THEN DELETE /SYMBOL /GLOBAL 'P1'
$ IF ( P2 .EQS. "" )
$ THEN P2 = "AVL,MNT,SHDW_MEMBER"
$ ELSE P2 = F$EDIT( P2, "COLLAPSE,UPCASE" )
$ ENDIF
$ IF ( P3 .EQS. "" )
$ THEN P3 = "DQA,DQB,DAD,DNFS"
$ ELSE P3 = F$EDIT( P3, "COLLAPSE,UPCASE" )
$ ENDIF
$ DDpayload = ""
$ alloclass = DOLLAR + F$STRING( F$GETSYI( "ALLOCLASS" ) ) + DOLLAR
$ !
$DCL$DDLoop:
$ dev = F$DEVICE( "*", "DISK" ) - UNDERSCORE
$ nakeddev = dev - "_" - alloclass - "''Node'$"           ! undecorate it...
$ nakedlen = F$LENGTH( nakeddev )
$ IF ( dev .EQS. "" ) THEN GOTO DCL$DDexit   ! done...
$ i = 0
$DCL$Inner1:
$ ignoredev = F$ELEMENT( i, COMMA, P3 )
$ IF ( ignoredev .EQS. COMMA ) THEN GOTO DCL$InnerCont1
$ IF ( F$LOCATE( ignoredev, nakeddev ) .LT. nakedlen ) THEN GOTO DCL$DDLoop
$ i = i + 1
$ GOTO DCL$Inner1
$DCL$InnerCont1:
$ j = 0
$DCL$Inner2:
$ criterion = F$ELEMENT( j, COMMA, P2 )
$ IF ( criterion .EQS. COMMA ) THEN GOTO DCL$DDLoop
$ IF dcl$Verbose THEN wso ">>> j: ""''j'""   dev: ""''dev'""   criterion: ""''criterion'"""
$ IF ( F$EXTRACT( 0, 1, criterion ) .EQS. BANG )
$ THEN ! Negate this criterion
$      criterion = criterion - BANG
$      IF ( F$GETDVI( dev, criterion ) )
$      THEN ! remove it if it got added...
$           target = COMMA + dev
$           IF ( F$LOCATE( target, DDpayload ) .LT. F$LENGTH( DDpayload ) ) -
              THEN DDpayload = DDpayload - target
$           IF ( F$LOCATE( dev, DDpayload ) .LT. F$LENGTH( DDpayload ) ) -
              THEN DDpayload = DDpayload - dev
$           GOTO DCL$DDLoop  ! skip it...
$      ENDIF
$ ELSE ! Affirm this criterion
$      IF ( F$GETDVI( dev, criterion ) ) -  ! a required criteria, but not already in list...
         THEN IF ( F$LOCATE( dev, DDpayload ) .GE. F$LENGTH( DDpayload ) ) -
           THEN DDpayload = DDpayload + COMMA + dev
$ ENDIF
$ j = j + 1
$ GOTO DCL$Inner2
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
$DCL$LogRollover:  SUBROUTINE
$ !#! Doc : Roll-over (refresh) a VMS log or journal file
$ !#!   Example:
$ !#!     $ DCL$CALL LogRollover «»
$ !#!   P1 : Which log- or journal-file to turn over:
$ !#!          "OPERATOR  |SECURITY  |ERRORLOG  |ACCOUNTING"
$ !
$ SET NOON
$ «»
$DCL$LROperator:
$ LRprv = F$SETPRV( "OPER,SYSPRV" )
$ REPLY /ENABLE=CENTRAL
$ REPLY /LOG                 ! close old OPERATOR.LOG, open new one...
$ REPLY /DISABLE=CENTRAL
$ ! cleanup?
$ GOTO DCL$LRDone
$DCL$LRSecurity:
$ LRprv = F$SETPRV( "SYSPRV,SECURITY" )
$ SET AUDIT /SERVER=NEW_LOG  ! close old SECURITY.AUDIT$JOURNAL, open a new one...
$ ! cleanup?
$ GOTO DCL$LRDone
$DCL$LRErrorlog:
$ LRprv = F$SETPRV( "SYSPRV" )
$ RENAME /LOG SYS$ERRORLOG:ERRLOG.SYS SYS$ERRORLOG:*.SYS_OLD
$ ! cleanup?
$ GOTO DCL$LRDone
$DCL$LRAccounting:
$ LRprv = F$SETPRV( "OPER,SYSPRV" )
$ SET ACCOUNTING /NEW_FILE /LOG  ! close old ACCOUNTNG.DAT, open a new one...
$ ! cleanup?
$ GOTO DCL$LRDone
$DCL$LRDone:
$ IF ( F$TYPE( LRprv ) .NES. "" ) THEN LRprv = F$SETPRV( LRprv )
$ EXIT 1
$ ENDSUBROUTINE  ! DCL$LogRollover
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$MakeDir:  SUBROUTINE
$ !#! Doc : Make a subdirectory in/at the working directory or a specified
$ !#!       directory, if that subdirectory does not already exist; and
$ !#!       create a logical name for it.
$ !#!   Example:
$ !#!     $ DCL$CALL MakeDir TEST mytest sys$login
$ !#!   P1 : Name of temporary subdirectory (default is "TEMP")
$ !#!   P2 : Logical name for the full path to this subdirectory
$ !#!   P3 : Logical name for this fully-specified subdirectory
$ !
$ SET NOON
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
$ ENDSUBROUTINE  ! DCL$MakeDir
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$PureDCL:  SUBROUTINE
$ !#! Doc : Sanity check for a site-specific global symbol which appropriates
$ !#!       a DCL command verb, make it go away!...
$ !#!   Example:
$ !#!     $ DCL$CALL PureDCL
$ !#!   P1 : DCL command verbs (words) to decommission, as a comma-separated list
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
$ !#! Doc : Sets up all global symbols & logical names for
$ !#!       this DCL$SUBROUTINE_LIBRARY
$ !#!   Examples:
$ !#!     $ !#! This is the library-initialization, so must use full file-spec:
$ !#!     $ @dev:[dir]DCL$SUBROUTINE_LIBRARY Setup
$ !#!     $ @dev:[dir]DCL$SUBROUTINE_LIBRARY Setup TRUE
$ !#!   P1 : Verification (output-trace)
$ !
$ SET NOON
$ proc = F$ENVIRONMENT( "PROCEDURE" )
$ dd   = F$PARSE( proc, , , "DEVICE" ) + F$PARSE( proc, , , "DIRECTORY" )
$ fac  = F$PARSE( proc, , , "NAME" )
$ ext  = F$PARSE( proc, , , "TYPE" )
$ DEFINE /PROCESS /NOLOG DCL$SLhome 'dd'
$ DEFINE /PROCESS /NOLOG DCL$SLself 'dd''fac''ext'
$ DCL$CALL == "@DCL$SLhome:''fac'"
$ IF ( dcl$Verbose ) .OR. ( P1 ) THEN CALL DCL$Version
$ EXIT 1
$ ENDSUBROUTINE  ! DCL$Setup
$ ! ==========
$ !
$ ! ==========
$DCL$Version:  SUBROUTINE
$ !#! Doc : Display this DCL$SUBROUTINE_LIBRARY's version info
$ !#!   Example:
$ !#!     $ DCL$CALL Version
$ !#!   P1 : (none)
$ !
$ SET NOON
$ dashcount = 80
$ dashes = F$FAO( "!#*-", dashcount )
$ indent = 2
$ wso ""
$ wso dashes
$ wso F$FAO( "%!AS-I-SETUP, done for !AS...", fac, fac )
$ lnm = "DCL$SLversion"
$ wso F$FAO( "!#* ""!AS"" = ""!AS""", indent, lnm, F$TRNLNM(lnm,"LNM$PROCESS") )
$ lnm = "DCL$SLhome"
$ wso F$FAO( "!#* ""!AS"" = ""!AS""", indent, lnm, F$TRNLNM(lnm,"LNM$PROCESS") )
$ lnm = "DCL$SLself"
$ wso F$FAO( "!#* ""!AS"" = ""!AS""", indent, lnm, F$TRNLNM(lnm,"LNM$PROCESS") )
$ SHOW SYMBOL /GLOBAL DCL$CALL
$ wso dashes
$ wso ""
$ EXIT 1
$ ENDSUBROUTINE  ! DCL$Version
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$ShowRegisteredRoutines:  SUBROUTINE
$ !#! Doc : Show/list the Registered Routines in this DCL$Subroutine_Library
$ !#!   Example:
$ !#!     $ DCL$CALL ShowRegisteredRoutines ...
$ !#!   P1 : RegisteredRoutines
$ !
$ SET NOON
$ j = 0
$ count  = 0
$ indent = 4
$ wso ""
$ wso "  ''Fac'"
$   wso F$FAO( "!#* [4mRegistered Routines[0m", indent )
$DCL$ShowLoop:
$ rr = F$ELEMENT( j, COMMA, P1 )
$ IF ( rr .EQS. COMMA )
$ THEN wso ""
$      wso F$FAO( "!#* Total of !ZL routine!%S", indent, count )
$      wso ""
$      EXIT 1
$ ENDIF
$ j = j + 1
$ IF ( rr .NES. "" ) .AND. ( rr .NES. BREADCRUMB )
$ THEN wso F$FAO( "!#* !AS", indent, rr )
$      count = count + 1
$ ENDIF
$ GOTO DCL$ShowLoop
$ !
$ EXIT 1
$ ENDSUBROUTINE  ! DCL$ShowRegisteredRoutines
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$Thousands:  SUBROUTINE
$ !#! Doc : Adds "thousands-separators" into numeric strings,
$ !#!       e.g., "1234567890" becomes "1,234,567,890",
$ !#!   Example:
$ !#!     $ DCL$CALL Thousands [ separator-char ] [ group-count ]
$ !#!   P1 : Name of the user global symbol to receive the result-list, default "DCL$SepString"
$ !#!   P2 : Value (string) to be separated
$ !#!   P3 : Separator character, default "," (comma)
$ !#!   P4 : Stride, number of characters per separated group, default 3
$ !
$ SET NOON
$ IF ( P1 .EQS. "" ) THEN P1 = "DCL$SepString"
$ IF ( P3 .EQS. "" ) THEN P3 = COMMA
$ IF ( P4 .EQS. "" ) THEN P4 = 3
$ P2len = F$LENGTH( P2 )
$ IF ( P2len .LE. P4 )  ! degenerate case, don't add separators...
$ THEN concatenated = P2
$      GOTO DCL$ThDone
$ ENDIF
$ ! else...
$ j = 1
$DCL$ThLoop:
$ cut = P2Len - P4
$ ss'j' = F$EXTRACT( cut, P4, P2 )
$!! $ IF ( dcl$Verbose ) -
$!!   THEN wso F$FAO( "J:  ss!SL : !AS  cut:!SL  P2len:!SL", j, ss'j', cut, P2len )
$ IF ( cut .GT. P4 )
$ THEN P2 = F$EXTRACT( 0, cut, P2 )
$      P2len = F$LENGTH( P2 )
$      j = j + 1
$      GOTO DCL$ThLoop
$ ELSE j = j + 1
$      ss'j' = F$EXTRACT( 0, cut, P2 )
$!! $      IF ( dcl$Verbose ) -
$!!        THEN wso F$FAO( "J:  ss!SL : !AS  cut:!SL  P2len:!SL", j, ss'j', cut, P2len )
$      GOTO DCL$ThCont
$ ENDIF
$ !
$DCL$ThCont:
$ concatenated = ""
$ k = j
$DCL$ThConcat:
$ IF ( concatenated .NES. "" )
$ THEN concatenated = concatenated + P3 + ss'k'
$ ELSE concatenated = ss'k'
$ ENDIF
$!! $ IF ( dcl$Verbose ) -
$!!   THEN wso F$FAO( "K:  ss!SL : !AS  cut:!SL  P2len:!SL", k, ss'k', cut, P2len )
$ k = k - 1
$ IF ( k .GT. 0 ) THEN GOTO DCL$ThConcat
$ !
$DCL$ThDone:
$ 'P1' == concatenated
$ IF ( dcl$Verbose ) THEN SHOW SYMBOL /GLOBAL 'P1'
$ !
$ EXIT 1
$ ENDSUBROUTINE  ! DCL$Thousands
$ ! ==========
$ !
$ !
$ ! ==========
$DCL$ToolsDebug:  SUBROUTINE
$ !#! Doc : Turns on-or-off DCL com-file "verbosity" debugging.
$ !#!       This subroutine does not fully supersede TOOLS$DEBUG.COM --
$ !#!       Note that this implements only a portion of TOOLS$DEBUG.COM,
$ !#!       specifically control of logical name TOOLS$DEBUG itself.
$ !#!   Example:
$ !#!     $ DCL$CALL ToolsDebug ON TRUE
$ !#!     $ DCL$CALL ToolsDebug OFF
$ !#!   P1 : TRUE/ON/1 enables debugging, FALSE/OFF/0 disables
$ !#!   P2 : TRUE/YES/1 enables output verification of Tools$Debug state,
$ !#!        FALSE/NO/0 disables same
$ !
$ SET NOON
$ IF ( P1 .EQS. "ON" ) .OR. ( F$EXTRACT(0,1,P1) .EQS. "Y" ) .OR. ( P1 .EQ. 1 )
$ THEN P1 = "TRUE"
$ ELSE P1 = "FALSE"
$ ENDIF
$ IF ( P2 .EQS. "" ) THEN P2 = 0
$ IF P1
$ THEN DEFINE /NOLOG /PROCESS TOOLS$Debug 'P1'
$      SET PREFIX "(!8%T) "     !augments SET VERIFY/F$VERIFY() display - "(HH:MM:SS) "
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
$Help:                                                             !'F$VERIFY(0)'
$ TYPE /PAGE sys$input

  To setup:  $ [1m@dev:[dir.subdir]DCL$SUBROUTINE_LIBRARY SETUP[0m

  which defines all necessary symbols and logical names to
  use this DCL Subroutine Library.

  use:       $ [1mDCL$CALL [4mRoutineName[0m [ "P1" [ "P2" ] ... [ "P7" ] ]
   or:       $ [1mDCL$CALL[0m [ [1mHELP[0m | [1mSHOW[0m | [1mROUTINES[0m | [1mDOC[0m | [1mAPI[0m ]
   or:       $ [1mDCL$CALL /OUTPUT=filespec[0m [ [1mHELP[0m | [1mSHOW[0m | [1mROUTINES[0m | [1mDOC[0m | [1mAPI[0m ]

  where:
    [1mRoutineName[0m is the name of a callable Registered Routine provided by this
                DCL$SUBROUTINE_LIBRARY command script.  See $ DCL$CALL SHOW
                for a list of currently-available routines.

    [1mP1[0m .. [1mP7[0m    are command-line parameter values (usually best double-quoted
                as shown above, especially if MixedCase &/or contain spaces).

    [1m/OUTPUT=filespec[0m
                redirects all output to a text file.

    [1mHELP[0m        displays this help text.

    [1mSHOW[0m        displays a list of all currently-available Registered Routines.
    or [1mROUTINES[0m

    [1mDOC[0m         displays internal help on the purpose, use, parameters and
    or [1mAPI[0m      examples for each Registered Routine.

$ EXIT 1    ! 'F$VERIFY(0)'
$ !
