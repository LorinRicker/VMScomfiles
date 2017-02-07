$ ! USERS_INACTIVE.COM --                                          'F$VERIFY(0)'
$ !
$ ! Copyright © 2016-2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ !    $ @USERS_INACTIVE [ NN[-DAYS]
$ !                      | NN-WEEKS
$ !                      | NN-MONTHS
$ !                      | NN-QUARTERS
$ !                      | NN-YEARS
$ !                      | HELP | ? ]
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Debug = F$TRNLNM("TOOLS$Debug")     !generic Tools debug flag
$ !
$ Proc   = F$ENVIRONMENT("PROCEDURE")
$ Proc   = Proc - F$PARSE(Proc,,,"VERSION","SYNTAX_ONLY")
$ Fac    = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ RptDir = F$PARSE(Proc,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(Proc,,,"DIRECTORY","SYNTAX_ONLY")
$ !
$ isANSI = F$GETDVI( "sys$output", "TT_ANSICRT" )
$ IF ( isANSI )
$ THEN esc[0,8]= %X1B              !  27 decimal,  033 octal - ESCape character
$         NORM = esc + "[0m"       ! Normal rendition
$         BOLD = esc + "[1m"       ! Bold
$        ULINE = esc + "[4m"       ! Underline
$ ELSE    NORM = ""
$         BOLD = ""
$        ULINE = ""
$ ENDIF
$ !
$ wso    = "WRITE sys$output"
$ SPC    = " "
$ COMMA  = ","
$ COLON  = ":"
$ DASH   = "-"
$ !
$ ! Modify this filter to modify which SYSUAF record/lines are filtered
$ !   into the processing loop (watch the double-quoting!):
$ SearchFilter = """Username:"",""Last Login:"",""Flags:"""
$ !
$ LegalUnits   = ",DA,WE,MO,QU,YE,"  ! DAYS, WEEKS, MONTHS, QUARTERS, YEARS
$ !
$ sysuaflis = "[]SYSUAF.LIS"
$ shortlist = "[]SYSUAF_SHORT.LIS"
$ !
$ IF ( P1 .EQS. "HELP" ) .OR. ( P1 .EQS. "?" ) THEN GOTO Help
$ !
$ ! ===========================================
$ ! Read/execute lines from configuration file:
$ config = RptDir + Fac + ".CONFIG"
$ IF ( F$SEARCH(config) .NES. "" )
$ THEN OPEN /READ /ERROR=FNFerror iuconfig 'config'
$IUCloop:
$      READ /END_OF_FILE=IUCdone iuconfig line
$      cmd = F$EDIT(line,"UNCOMMENT,COMPRESS")
$      IF ( cmd .NES. "" ) THEN 'cmd'  ! execute config-file lines directly...
$      GOTO IUCloop
$ ELSE GOTO FNFerror
$ ENDIF
$IUCdone:
$ CLOSE /NOLOG iuconfig
$ ! ===========================================
$ !
$ IF ( P1 .NES. "" ) THEN UI$NNago = P1
$ NNval = F$INTEGER( F$ELEMENT( 0, DASH, UI$NNago ) )
$ Units = F$EXTRACT( 0, 2, F$EDIT( F$ELEMENT( 1, DASH, UI$NNago ), "UPCASE" ) )
$ IF ( Units .EQS. DASH ) THEN Units = "DA"
$ IF ( F$LOCATE( ",''Units',", LegalUnits ) .LT. F$LENGTH( LegalUnits ) )
$ THEN GOTO 'Units'mult
$DAmult:
$      multiplier = 1
$      GOTO Mult
$WEmult:
$      multiplier = 7
$      GOTO Mult
$MOmult:
$      multiplier = 30
$      GOTO Mult
$QUmult:
$      multiplier = 91
$      GOTO Mult
$YEmult:
$      multiplier = 365
$      GOTO Mult
$Mult:
$      UI$DaysAgo = NNval * multiplier
$ ELSE wso F$FAO ( "%!AS-E-BAD_UNITS, unknown time-ago units: !AS", Fac, Units )
$      GOTO Done
$ ENDIF
$ !
$ IF Debug
$ THEN wso F$FAO( "%!AS-I-DEBUG, sys$output is ANSI-terminal: !AS", Fac, isANSI )
$      wso F$FAO( "%!AS-I-DEBUG, UI$NNago: !AS", Fac, UI$NNago )
$      wso F$FAO( "%!AS-I-DEBUG, !ZL (!AS) * !ZL = !ZL", -
                  Fac, NNval, Units, multiplier, UI$DaysAgo )
$      wso F$FAO( "%!AS-I-DEBUG, UI$DaysAgo: !ZL", Fac, UI$DaysAgo )
$ ENDIF
$ !
$ UI$Never = 0
$ UI$Aged  = 0
$ !
$ IF ( F$TRNLNM( "sysuaf", "LNM$SYSTEM" ) .EQS. "" )
$ THEN DEFINE /PROCESS /NOLOG sysuaf sys$system:sysuaf.dat
$ ENDIF
$ DEFINE /USER sys$output NLA0:  ! suppres the %UAF-I-LSTMSG1, writing listing file message
$ DEFINE /USER sys$error  NLA0:
$ MCR AUTHORIZE list /full *     ! creates SYSUAF.LIS in current working directory
$ !
$ SEARCH /OUTPUT='shortlist' 'sysuaflis' 'SearchFilter' /MATCH=OR /EXACT
$ !
$ OPEN /READ iuc 'shortlist'
$Loop:
$ READ /END_OF_FILE=LoopDone iuc line                              ! Username: ...
$ uname = F$ELEMENT( 1, SPC, line )
$ READ /END_OF_FILE=LoopDone iuc line                              ! Flags: ...
$ flags = F$EDIT( F$ELEMENT( 1, COLON, line ), "COMPRESS" )
$ READ /END_OF_FILE=LoopDone iuc line                              ! Last Login: ...
$ ! strip out all the labelling on this line, so all that's left is date-data or empty strings:
$ line = line - "Last Login:" - " (interactive)" - " (non-interactive)" - "(none)" - "(none)"
$ line = F$EDIT( line, "TRIM,COMPRESS ")
$ lastlogin  = F$EDIT( F$ELEMENT( 0, COMMA, line ), "TRIM" )       ! "<date> (interactive)"
$ lastnonint = F$EDIT( F$ELEMENT( 1, COMMA, line ), "TRIM" )       ! "<date> (non-interactive)"
$ !
$ ! Ignore users who are "Restricted", e.g., TCPIP$*, UCX$*, other system/detached accounts:
$ IF ( F$LOCATE( " Restricted", flags ) .LT. F$LENGTH( flags ) ) THEN GOTO Loop
$ !
$ Msg0 = "User " + uname
$ Msg1 = ""
$ Msg2 = ""
$ IF UI$IncludeFlags THEN Msg0 = Msg0 + " (''F$EDIT( flags, "TRIM" )')"
$ !
$ IF ( F$EDIT( lastlogin, "COLLAPSE" ) .EQS. "" )
$ THEN ! An "empty" lastlogin means that user has never logged in interactively
$      Msg1 = F$FAO( "!7* !AShas never logged-in!AS", ULINE, NORM )
$      ! Consider non-interactive login only when interactive login is never/"(none)":
$      IF ( F$EDIT( lastnonint, "COLLAPSE" ) .EQS. "" )
$      THEN ! An "empty" lastnonint means that user has never logged in non-interactively/batch
$           Msg2 = F$FAO( "!7* !AShas never logged-in noninteractive (batch)!AS", ULINE, NORM )
$           UI$Never = UI$Never + 1
$      ELSE ! Determine if this user has not logged-in within UI$DaysAgo days:
$           LLdelta = F$INTEGER( F$ELEMENT( 0, DASH, F$DELTA_TIME( lastnonint, F$TIME(), "DCL" ) ) )
$           IF ( LLdelta .GE. UI$DaysAgo )
$           THEN Msg2 = F$FAO( "!7* last non-interactive (batch) login was !AS, or !AS!ZL!AS days ago", -
                                lastnonint, BOLD, LLdelta, NORM )
$           ELSE GOTO Loop  ! nothing to report
$           ENDIF
$      ENDIF
$ ELSE ! Determine if this user has not logged-in within UI$DaysAgo days:
$      LLdelta = F$INTEGER( F$ELEMENT( 0, DASH, F$DELTA_TIME( lastlogin, F$TIME(), "DCL" ) ) )
$      IF ( LLdelta .GE. UI$DaysAgo )
$      THEN Msg1 = F$FAO( "!7* last interactive login was !AS, or !AS!ZL!AS days ago", -
                          lastlogin, BOLD, LLdelta, NORM )
$           UI$Aged = UI$Aged + 1
$      ELSE GOTO Loop  ! nothing to report
$      ENDIF
$ ENDIF
$ !
$ !! $ IF Debug
$ !! $ THEN wso F$FAO( "        username: ""!AS""", uname )
$ !! $      wso F$FAO( "           flags: ""!AS""", flags )
$ !! $      wso F$FAO( "      last login: ""!AS""", lastlogin )
$ !! $      wso F$FAO( "  last non-inter: ""!AS""", lastnonint )
$ !! $      wso ""
$ !! $ ENDIF
$ !
$ wso Msg0
$ IF ( Msg1 .NES. "" ) THEN wso Msg1
$ IF ( Msg2 .NES. "" ) THEN wso Msg2
$ GOTO Loop
$LoopDone:
$ !
$Done:
$ CLOSE /NOLOG iuc
$ !
$ wso ""
$ Msg = F$FAO( "%!AS-I-SUMMARY,", Fac )
$ MsgL = F$LENGTH( Msg )
$ wso F$FAO( "!AS !3UL user interactive logins exceed !ZL days (!AS) ago", Msg, UI$Aged, UI$DaysAgo, UI$NNago )
$ wso F$FAO( "!#* !3UL user!%S have never logged in, either interactive or non-interactive", MsgL+1, UI$Never )
$ wso F$FAO( "!#* !3UL total users", MsgL+1, UI$Aged + UI$Never )
$ !
$ IF ( .NOT. Debug )
$ THEN IF ( F$SEARCH( sysuaflis ) .NES. "" ) THEN DELETE /NOLOG 'sysuaflis';*
$      IF ( F$SEARCH( shortlist ) .NES. "" ) THEN DELETE /NOLOG 'shortlist';*
$ ENDIF
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$FNFerror:
$ wso F$FAO( "%!AS-E-FNF, cannot find/read configuration file !AS", -
             Fac, config )
$ EXIT %x2C    ! 'F$VERIFY(0)'
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  Reports inactive user accounts -- users who have not logged-in within
  the past "NN" days (or weeks, or months, or quarters, or years).

  usage:
    [1m@USERS_INACTIVE[0m [ [1mNN[0m[[1m-DAYS[0m]
                    | [1mNN-WEEKS[0m
                    | [1mNN-MONTHS[0m
                    | [1mNN-QUARTERS[0m
                    | [1mNN-YEARS[0m
                    | [1mHELP[0m | [1m?[0m ]

  where:

    [1mNN[0m    Report those VMS user accounts (usernames) which have not
          logged-in to the system since NN days (or weeks, or months,
          or quarters, or years) ago.

          If no value is given, then the value from the configuration
          file USERS_INACTIVE.CONFIG is used by default.

          Enter this value as NN-DAYS (an integer followed by "-DAYS"),
          or as NN, which is equivalent to NN-DAYS.

          For other intervals, use:

          NN-WEEKS    (results in NN *   7 days)
          NN-MONTHS   (results in NN *  30 days)
          NN-QUARTERS (results in NN *  91 days)
          NN-YEARS    (results in NN * 365 days)

    [1mHELP[0m  Displays this help text.
    or [1m?[0m

$ !
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
