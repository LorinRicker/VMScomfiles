$ ! USERS_PASSWORDS.COM --                                         'F$VERIFY(0)'
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
$ !    $ @USERS_PASSWORDS [ NN[-DAYS]
$ !                       | NN-WEEKS
$ !                       | NN-MONTHS
$ !                       | NN-QUARTERS
$ !                       | NN-YEARS
$ !                       | HELP | ? ] [ pwd-minimum-chars ] [ CSVfile ]
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
$ Node   = F$EDIT( F$GETSYI( "NODENAME" ), "COLLAPSE" )
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
$ wserr  = "WRITE sys$error"
$ SPC    = " "
$ COMMA  = ","
$ COLON  = ":"
$ DASH   = "-"
$ NONE   = "(none)"
$ MAXINT = "4294967296"
$ !
$ ! Modify this filter to modify which SYSUAF record/lines are filtered
$ !   into the processing loop (watch the double-quoting!):
$ SearchFilter = """Username:"",""Pwdlifetime:"",""Pwdminimum:"",""Last Login:"",""Flags:"""
$ !
$ LegalUnits   = ",DA,WE,MO,QU,YE,"  ! DAYS, WEEKS, MONTHS, QUARTERS, YEARS
$ !
$ sysuaflis = "[]SYSUAF.LIS"
$ shortlist = "[]SYSUAF_SHORT.LIS"
$ CSVfile   = ""
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
$ IF ( .NOT. CFG$CSVoutput ) THEN CFG$CSVoutput = ( P3 .NES. "" )
$ IF ( CFG$CSVoutput )
$ THEN defcsv  = RptDir + Fac + "_" + Node + ".CSV"
$      CSVfile = F$PARSE( P3, defcsv )
$      wserr F$FAO( "%!AS-I-CSV_OUTPUT, comma-sep output file: !AS", Fac, CSVfile )
$      DEFINE /PROCESS /NOLOG sys$output "''CSVfile'"
$      Hdr = "Username,Owner,Pwd-Lifetime,Pwd-Minimum-Len,Last-Login"
$      IF ( CFG$IncludeFlags ) THEN Hdr = Hdr + ",Flags"
$      wso Hdr
$ ENDIF
$ !
$ IF ( P2 .NES. "" ) THEN CFG$PwdMinimum  = P2
$ IF ( P1 .NES. "" ) THEN CFG$PwdLifeTime = P1
$ NNval = F$INTEGER( F$ELEMENT( 0, DASH, CFG$PwdLifeTime ) )
$ Units = F$EXTRACT( 0, 2, F$EDIT( F$ELEMENT( 1, DASH, CFG$PwdLifeTime ), "UPCASE" ) )
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
$      REQ$PwdLifeTime = NNval * multiplier
$ ELSE wso F$FAO ( "%!AS-E-BAD_UNITS, unknown time-ago units: !AS", Fac, Units )
$      GOTO Done
$ ENDIF
$ !
$ IF Debug
$ THEN wserr F$FAO( "%!AS-I-DEBUG, sys$output is ANSI-terminal: !AS", Fac, isANSI )
$      wserr F$FAO( "%!AS-I-DEBUG, CFG$PwdLifeTime: !AS", Fac, CFG$PwdLifeTime )
$      wserr F$FAO( "%!AS-I-DEBUG, !ZL (!AS) * !ZL = !ZL", -
                  Fac, NNval, Units, multiplier, REQ$PwdLifeTime )
$      wserr F$FAO( "%!AS-I-DEBUG, REQ$PwdLifeTime: !ZL", Fac, REQ$PwdLifeTime )
$ ENDIF
$ !
$ Count$Total  = 0
$ Count$VioLif = 0
$ Count$VioMin = 0
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
$ READ /END_OF_FILE=LoopDone iuc line                              ! Username: Uname     Owner: Fname Lname
$ uname = F$ELEMENT( 1, SPC, line )
$ owner = F$EDIT( F$ELEMENT( 2, COLON, line ), "TRIM,COMPRESS" )
$ READ /END_OF_FILE=LoopDone iuc line                              ! Flags: ...
$ flags = F$EDIT( F$ELEMENT( 1, COLON, line ), "TRIM,COMPRESS" )
$ READ /END_OF_FILE=LoopDone iuc line                              ! Pwdminimum: ...
$ line = F$EDIT( line, "COMPRESS" )
$ IF ( F$ELEMENT( 1, SPC, line ) .EQS. NONE )
$ THEN pwdminimum  = F$ELEMENT( 3, SPC, line )
$ ELSE pwdminimum  = F$ELEMENT( 4, SPC, line )
$ ENDIF
$ READ /END_OF_FILE=LoopDone iuc line                              ! Pwdlifetime: ...
$ pwdlifetime = F$ELEMENT( 1, SPC, F$EDIT( line, "COMPRESS" ) )
$ IF ( pwdlifetime .EQS. NONE ) THEN pwdlifetime = MAXINT
$ READ /END_OF_FILE=LoopDone iuc line                              ! Last Login: ...
$ line = F$EDIT( line, "COMPRESS" )
$ tmp  = F$ELEMENT( 3, SPC, line )
$ IF ( F$EXTRACT( 0, 1, tmp ) .NES. "(" )
$ THEN tmp = F$EXTRACT( 0, 17, tmp )
$ ELSE tmp = ""
$ ENDIF
$ lastlogin = F$ELEMENT( 2, SPC, line ) + SPC + tmp - COMMA
$ !
$ ! Ignore users who are "Restricted", e.g., TCPIP$*, UCX$*, other system/detached accounts:
$ IF ( F$LOCATE( " Restricted", flags ) .LT. F$LENGTH( flags ) ) THEN GOTO Loop
$ !
$ Msg0 = F$FAO( "!12AS: !16AS -", uname, owner )
$ !
$ msglif = ""
$ msgmin = ""
$ msglgi = ""
$ IF ( F$INTEGER( REQ$PwdLifeTime ) .EQ. F$INTEGER( pwdlifetime ) )
$ THEN VIO$pwdlifetime = 0
$ ELSE VIO$pwdlifetime = 1
$      IF ( pwdlifetime .EQS. MAXINT ) THEN pwdlifetime = NONE
$      msglif = F$FAO( " lifetime: !6AS", pwdlifetime )
$      Count$VioLif = Count$VioLif + 1
$ ENDIF
$ IF ( F$INTEGER( CFG$PwdMinimum ) .LE. F$INTEGER( pwdminimum ) )
$ THEN VIO$pwdminimum = 0
$ ELSE VIO$pwdminimum = 1
$      msgmin = F$FAO( " minimum: !2AS", pwdminimum )
$      Count$VioMin = Count$VioMin + 1
$ ENDIF
$ !
$ IF ( VIO$pwdlifetime ) .OR. ( VIO$pwdminimum )
$ THEN msglgi = F$FAO( " last-login: !17AS", lastlogin )
$      Msg0 = Msg0 + F$FAO( " !ASViolation!AS - !AS!AS!AS", BOLD, NORM, msglif, msgmin, msglgi )
$      IF ( CFG$IncludeFlags ) THEN Msg0 = Msg0 + " [''flags']"
$      Count$Total = Count$Total + 1
$ ELSE GOTO Loop  ! nothing to report
$ ENDIF
$ !
$ IF Debug
$ THEN wserr F$FAO( "    username: ""!AS""", uname )
$      wserr F$FAO( "       flags: ""!AS""", flags )
$      wserr F$FAO( "pwd lifetime: ""!AS""", pwdlifetime )
$      wserr F$FAO( " pwd minimum: ""!AS""", pwdminimum )
$      wserr F$FAO( "  last login: ""!AS""", lastlogin )
$      wserr ""
$ ENDIF
$ !
$ IF ( CFG$CSVoutput )
$ THEN CSVmsg = """''uname'"",""''owner'"",""''pwdlifetime'"",""''pwdminimum'"",""''lastlogin'"""
$      IF ( CFG$IncludeFlags ) THEN CSVmsg = CSVmsg + ",""''flags'"""
$      wso CSVmsg
$ ELSE wso Msg0
$ ENDIF
$ GOTO Loop
$LoopDone:
$ !
$Done:
$ CLOSE /NOLOG iuc
$ !
$ IF ( CFG$CSVoutput ) THEN DEASSIGN /PROCESS sys$output
$ !
$ wso ""
$ Msg = F$FAO( "%!AS-I-SUMMARY,", Fac )
$ MsgL = F$LENGTH( Msg )
$ wso F$FAO( "!AS !3UL user account!%S violate !AS password lifetime", Msg, Count$VioLif, CFG$PwdLifeTime )
$ wso F$FAO( "!#* !3UL user account!%S violate !AS-character password minimum", MsgL+1, Count$VioMin, CFG$PwdMinimum  )
$ wso F$FAO( "!#* !3UL total users reported", MsgL+1, Count$Total )
$ !
$ ! === Optional Special Function process(es) invocation, ===
$ ! ===   up to five (5) special function com-files:      ===
$ i = 1
$SFLoop:
$ IF ( F$TYPE( CFG$SpecFunc'i' ) .NES. "STRING" ) THEN GOTO Cleanup
$ IF ( i .GT. 5 ) THEN GOTO Cleanup  ! hard limit...
$ IF ( CFG$SpecFunc'i' .NES. "" )
$ THEN specfunc = F$TRNLNM( CFG$SpecFunc'i' )
$      IF ( specfunc .EQS. "" ) THEN specfunc = F$PARSE( CFG$SpecFunc'i', "''RptDir'.COM" )
$      IF ( F$SEARCH( specfunc ) .NES. "" )
$      THEN IF Debug THEN wserr F$FAO( "%!AS-I-INVOKE, $ @!AS", Fac, specfunc )
$           @'specfunc'
$      ELSE wserr F$FAO( "%!AS-E-FNF, CFG$SpecFunc!1ZL file not found: !AS", -
                         Fac, i, specfunc )
$      ENDIF
$ ENDIF
$ i = i + 1
$ GOTO SFLoop
$ !
$Cleanup:
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

  Reports user accounts which violate password lifetime or minimum
  character length requirements.

  usage:
    [1m@USERS_PASSWORDS[0m [ [1mNN[0m[[1m-DAYS[0m]
                     | [1mNN-WEEKS[0m
                     | [1mNN-MONTHS[0m
                     | [1mNN-QUARTERS[0m
                     | [1mNN-YEARS[0m
                     | [1mHELP[0m | [1m?[0m ] [ [1mpwd-minimum-chars[0m ] [ [1mCSVfile[0m ]

  where:

    [1mNN[0m    Report those VMS user accounts (usernames) which violate either
          of the required password lifetime (expiration) or the password
          length requirements.

          If no value is given, then the value from the configuration
          file USERS_PASSWORDS.CONFIG is used by default.

          Enter the [1mP1[0m value as NN-DAYS (an integer followed by "-DAYS"),
          or as NN, which is equivalent to NN-DAYS.

          For other intervals, use:

          NN-WEEKS    (results in NN *   7 days)
          NN-MONTHS   (results in NN *  30 days)
          NN-QUARTERS (results in NN *  91 days)
          NN-YEARS    (results in NN * 365 days)

    [1mP2[0m    The minimum password length in characters.

    [1mP3[0m    If present, names and enables output to a spreadsheet comma-separated
          value (CSV) file.

    [1mHELP[0m  Displays this help text.
    or [1m?[0m

$ !
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
