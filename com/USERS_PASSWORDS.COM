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
$ !  usage:
$ !    $ @USERS_PASSWORDS [ NN[-DAYS]
$ !                       | NN-WEEKS
$ !                       | NN-MONTHS
$ !                       | NN-QUARTERS
$ !                       | NN-YEARS
$ !                       | SUBMIT
$ !                       | HELP | ? ] [ pwd-minimum-chars ] [ CSVfile ]
$ !
$ !
$ ! -----------------------
$GenReport: SUBROUTINE
$ ! P1 : Reporting time-interval
$ ! P2 : Password minimum character length
$ ! P3 : CSV filespec
$ ! P4 : Text report filespec
$ !
$ ON ERROR THEN GOTO GRerr
$ requiredprivs = F$SETPRV( "SECURITY,SYSPRV" )
$ IF .NOT. F$PRIVILEGE("SECURITY") THEN EXIT %x2934  ! operation requires SECURITY privilege
$ wso F$FAO( "%!AS-I-SINCE, reporting current Password Violations in SYSUAF", Fac )
$ !
$ ! Modify this filter to modify which SYSUAF record/lines are filtered
$ !   into the processing loop (watch the double-quoting!):
$ SearchFilter = """Username:"",""Pwdlifetime:"",""Pwdminimum:"",""Last Login:"",""Flags:"""
$ !
$ LegalUnits   = ",DA,WE,MO,QU,YE,"  ! DAYS, WEEKS, MONTHS, QUARTERS, YEARS
$ !
$ sysuaflis = "[]SYSUAF.LIS"
$ shortlist = "[]SYSUAF_SHORT.LIS"
$ !
$ IF ( .NOT. CFG$CSVoutput ) THEN CFG$CSVoutput = ( P3 .NES. "" )
$ IF ( CFG$CSVoutput )
$ THEN ! Generating a Comma-Separated Value (CSV) output file:
$      defcsv  = RptDir + Fac + "_" + ThisNode + ".CSV"
$      ThisReport == F$PARSE( P3, defcsv )
$      wserr F$FAO( "%!AS-I-CSV_OUTPUT, comma-sep output file: !AS", Fac, ThisReport )
$      DEFINE /PROCESS /NOLOG sys$output "''ThisReport'"
$      Hdr = "Username,Owner,Pwd-Lifetime,Pwd-Minimum-Len,Last-Login"
$      IF ( CFG$IncludeFlags ) THEN Hdr = Hdr + ",Flags"
$      wso Hdr
$ ELSE wserr F$FAO( "%!AS-I-TEXT_OUTPUT, text output file: !AS", Fac, P4 )
$      DEFINE /PROCESS /NOLOG sys$output "''P4'"
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
$      EXIT %X2C
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
$ ! Suppress the SEARCH output-footer stats, but retain the "good stuff" with /OUTPUT= --:
$ DEFINE /NOLOG /USER_MODE sys$output NLA0:
$ DEFINE /NOLOG /USER_MODE sys$error  NLA0:
$ SEARCH /OUTPUT='shortlist' 'sysuaflis' 'SearchFilter' /MATCH=OR /EXACT /STATISTICS=SYMBOLS
$ UI$search_records_matched == SEARCH$RECORDS_MATCHED 
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
$ THEN ! Generating a Comma-Separated Value (CSV) output file:
$      CSVmsg = """''uname'"",""''owner'"",""''pwdlifetime'"",""''pwdminimum'"",""''lastlogin'"""
$      IF ( CFG$IncludeFlags ) THEN CSVmsg = CSVmsg + ",""''flags'"""
$      wso CSVmsg
$ ELSE ! Generating a standard, printable or terminal-display report:
$      wso Msg0
$ ENDIF
$ GOTO Loop
$LoopDone:
$ !
$ wso ""
$ Msg = F$FAO( "%!AS-I-SUMMARY,", Fac )
$ MsgL = F$LENGTH( Msg )
$ wso F$FAO( "!AS !3UL user account!%S violate !AS password lifetime", Msg, Count$VioLif, CFG$PwdLifeTime )
$ wso F$FAO( "!#* !3UL user account!%S violate !AS-character password minimum", MsgL+1, Count$VioMin, CFG$PwdMinimum  )
$ wso F$FAO( "!#* !3UL total users reported", MsgL+1, Count$Total )
$ !
$GRerr:
$ DEASSIGN /PROCESS sys$output
$ IF ( .NOT. Debug )
$ THEN IF ( F$SEARCH( sysuaflis ) .NES. "" ) THEN DELETE /NOLOG 'sysuaflis';*
$      IF ( F$SEARCH( shortlist ) .NES. "" ) THEN DELETE /NOLOG 'shortlist';*
$ ENDIF
$ IF ( F$TYPE( requiredprivs ) .EQS. "STRING" ) THEN requiredprivs = F$SETPRV( requiredprivs )
$ EXIT 1
$ ENDSUBROUTINE  ! GenReport
$ !
$ !
$ ! -----------------------
$EMailIt:  SUBROUTINE
$ ! P1 : Number (string) of search records matched to produce this report
$ ! P2 : Subject-line text
$ ! P3 : Facility name
$ ! P4 : Name of this node
$ ! P5 : Report filename
$ ! P6 : Report date
$ ! P7 : Email Message filename
$ !
$ ON CONTROL_Y THEN GOSUB EMICtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ fspec = F$PARSE( P5, , , , "SYNTAX_ONLY" ) - F$PARSE( P5, , , "VERSION", "SYNTAX_ONLY" )
$ !
$ recmatched = F$INTEGER( P1 )
$ IF ( recmatched .GT. 0 )
$ THEN subjline = P2
$ ELSE subjline = F$FAO( "%!AS-I-NOVIOLATIONS, system !AS, no violations found for this report period", -
                         Fac, P4 )
<<<<<<< HEAD
$      OPEN /WRITE /ERROR=EMIerror emf 'fspec'
=======
$      OPEN /WRITE /ERROR=EMIerror emf 'P5'
>>>>>>> bd45700215a33876b5112b5b37da87d895c7536c
$      WRITE emf subjline
$      WRITE emf ""
$      WRITE emf "Report period: ''P6' to ''F$CVTIME(F$TIME(),"ABSOLUTE","DATE")'"
$      WRITE emf ""
$      CLOSE emf
<<<<<<< HEAD
$      PURGE /NOLOG 'fspec'
=======
$      PURGE /NOLOG 'P5'
>>>>>>> bd45700215a33876b5112b5b37da87d895c7536c
$ ENDIF
$ !
$ CALL AttachMIME "''P7'" "''P5'" "''subjline'"
$ ! P7-ThisMsg now has attachment P5-ThisReport:
$ MAIL 'P7' /SUBJECT="''subjline'" "@UPwdList"
$ MailStat = $STATUS
$ msg1 = F$FAO( "%!AS-I-MAILED, report attached:", Fac )
$ msg2 = "subject line:"
<<<<<<< HEAD
$ indL = F$LENGTH( msg1 ) - F$LENGTH( msg2 ) - 3
=======
$ indL = F$LENGTH( msg1 ) - F$LENGTH( msg2 )
>>>>>>> bd45700215a33876b5112b5b37da87d895c7536c
$ wso F$FAO( "!AS !AS", msg1, P5 )
$ wso F$FAO( "!#* !AS !AS", indL, msg2, subjline )
$ wso ""
$ wso F$FAO( "%!AS-I-STATUS, mail-report status code: !ZL", -
             Fac, MailStat )
$ wso F$FAO( "%!AS-I-STATUS, !AS", -
             Fac, F$MESSAGE( MailStat ) )
$ wso ""
$ EXIT 1
$ !
$EMIerror:
$ wso "%''Fac'-E-OPENERR, cannot open temp-file ''P5'"
$ EXIT %x2C
$EMICtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! EMailIt
$ !
$ ! -----------------------
$AttachMIME:  SUBROUTINE
$ ! P1 : Email Message filename
$ ! P2 : Report filespec
$ ! P2 : Subject-line text
$ !
$ ON ERROR THEN EXIT %x2C
$ IF ( F$TYPE(mime) .NES. "STRING" ) THEN mime = "$sys$system:mime"
$ !
$ TempF = RptDir + F$PARSE(P1,,,"NAME","SYNTAX_ONLY") + ".COMTMP"
$ !
$ OPEN /WRITE /ERROR=AMerror tmp 'TempF'
$ wtmp = "WRITE tmp"
$ wtmp "$ ! ''TempF' --       !'F$VERIFY(0)'"
$ wtmp "$ CREATE /OWNER=PARENT /PROT=(O:RWED) ''ThisMsg'"
$ wtmp P3    ! use the subject line as message-body
$ wtmp "$ ! [EOD]"
$ wtmp "$ DEFINE /USER_MODE sys$output NLA0:"
$ wtmp "$ DEFINE /USER_MODE sys$error  NLA0:"
$ wtmp "$ mime"
$ wtmp "open /draft ''ThisMsg'"
$ wtmp "add /text ''P2'"        ! attach the Audit Report file
$ wtmp "save"
$ wtmp "exit"
$ wtmp "$ ! [EOD]"
$ wtmp "$ EXIT 1"
$ CLOSE tmp
$ !
$ @'TempF'
$ IF ( F$SEARCH(TempF) .NES. "" ) THEN DELETE /NOLOG 'TempF';*
$ !
$ EXIT 1
$AMerror:
$ wso "%''Fac'-E-OPENERR, cannot open temp-file ''TempF'"
$ EXIT %x2C
$ ENDSUBROUTINE  ! AttachMIME
$ !
$ ! -----------------------
$ArchiveReports:  SUBROUTINE
$ ! P1 : Report filename to archive
$ archive = "AR$REPORTS"
$ fspec = F$PARSE( P1, , , , "SYNTAX_ONLY" ) - F$PARSE( P1, , , "VERSION", "SYNTAX_ONLY" )
$ IF ( F$TRNLNM( "SECAUDIT$Top" ) .NES. "" ) .AND. ( F$TRNLNM( "SECAUDIT$Root" ) .NES. "" )
$ THEN ! If there is more than one report, push 'em all into archive sub-dir:
$ARloop:
$      IF ( F$SEARCH( "''fspec';-1" ) .NES. "" )
$      THEN RENAME /LOG 'fspec';-1 SECAUDIT$ROOT:['archive']*.*;*
$           GOTO ARloop
$      ENDIF
$ ELSE IF Debug THEN wserr "%''Fac'-E-NO_LOGICALS, no logical names SECAUDIT$*"
$      PURGE /SINCE /NOLOG 'fspec'
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! ArchiveReports
$ !
$ ! -----------------------
$SelfSubmit:  SUBROUTINE
$ ! P1 = Filespec for this procedure (command file)
$ ! P2 = Report directory
$ ! P3 = Process mode (BATCH or INTERACTIVE)
$ ! P4 = calculated next-submit-after-time (BATCH, recurring)
$ ! The following P5 & P6 are used only if submitting from command line (INTERACTIVE mode):
$ ! P5 = special tag "$STARTUP$", or username to submit for
$ ! P6 = specific submit-after-time
$ !
$ ON CONTROL_Y THEN GOSUB SSCtrl_Y
$ ON ERROR THEN GOTO NoSubmit
$ !
$ Proc     = P1
$ RptDir   = P2
$ ProcMode = P3
$ After    = P4
$ notify   = ""
$ foruser  = ""
$ !
$ IF ( ProcMode .EQS. "INTERACTIVE" )
$ THEN ! INTERACTIVE mode -- set-up, and possibly prompt for, various parameters...
$      notify = "/NOTIFY"
$      IF ( P5 .EQS. "$STARTUP$" )
$      THEN submitfor = CFG$SubmitForDef
$      ELSE IF ( P5 .NES. "" )
$           THEN submitfor = P5
$           ELSE READ sys$command answer /PROMPT="Submit for user [''CFG$SubmitForDef']: " /END_OF_FILE=Done
$                submitfor = F$PARSE(answer,CFG$SubmitForDef,,"NAME","SYNTAX_ONLY")
$           ENDIF
$           IF ( P6 .EQS. "" )
$           THEN After = ""
$           ELSE After = "/AFTER=" + DQUOTE + P6 + DQUOTE
$           ENDIF
$      ENDIF
$      IF ( F$EXTRACT(0,5,ThisUser) .EQS. F$EXTRACT(0,5,submitfor) )
$      THEN ! submitting job for self:
$           foruser = ""
$      ELSE ! submitting for another user; must be (re)submitted by a privileged
$           ! user/account with IMPERSONATE/DETACH and CMKRNL privilege:
$           submitprivs = F$SETPRV( "IMPERSONATE,CMKRNL" )
$           IF F$PRIVILEGE("IMPERSONATE") .AND. F$PRIVILEGE("CMKRNL")
$           THEN foruser = "/USER=''submitfor'"
$           ELSE ! no priv: IMPERSONATE or DETACH
$                wso "%''Fac'-E-NOPRIV, must have IMPERSONATE/DETACH and CMKRNL to submit for another user"
$                GOTO NoSubmit
$           ENDIF
$      ENDIF
$ ELSE ! BATCH mode, so just resubmit self...
$      notify = ""
$ ENDIF
$ !
$ SUBMIT = ""  ! don't use any process global symbol/alias...
$ IF ( After .NES. "" )
$ THEN After = "/AFTER=" + DQUOTE + After + DQUOTE
$ ENDIF
$ SUBMIT 'Proc' 'notify' 'foruser' 'After' -
    /LOG_FILE='RptDir' /QUEUE=sys$batch /NOPRINT
$ !
$NoSubmit:
$ IF ( F$TYPE( submitprivs ) .EQS. "STRING" ) THEN submitprivs = F$SETPRV( submitprivs )
$ EXIT 1
$ !
$SSCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! SelfSubmit
$ !
$ !
$ ! -----------------------
$Main:
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Debug = F$TRNLNM("TOOLS$Debug")     !generic Tools debug flag
$ !
$ ProcMode    = F$MODE()
$ ThisUser    = F$EDIT(F$GETJPI("","USERNAME"),"TRIM")
$ ThisNode   == F$EDIT(F$GETSYI("NODENAME"),"TRIM")
$ !
$ Proc        = F$ENVIRONMENT("PROCEDURE")
$ Proc        = Proc - F$PARSE(Proc,,,"VERSION","SYNTAX_ONLY")
$ Fac         = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ RptDir      = F$PARSE(Proc,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(Proc,,,"DIRECTORY","SYNTAX_ONLY")
$ rptdstr     = RptDir + Fac + "_" + F$CVTIME("","COMPARISON","DATE")
$ ThisReport == rptdstr + ".REPORT"
$ ThisMsg    == rptdstr + ".MSG"
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
$ wso     = "WRITE sys$output"
$ wserr   = "WRITE sys$error"
$ SPC     = " "
$ COMMA   = ","
$ COLON   = ":"
$ DASH    = "-"
$ VERTBAR = "|"
$ DQUOTE  = """"
$ NONE    = "(none)"
$ MAXINT  = "4294967296"
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
$ IF ( F$INTEGER(CFG$DaysAgo) .LT. 28 )
$ THEN ! doing Daily or Weekly reporting...
$      NextBatchRun = "TODAY+" + CFG$DaysAgo + "-" + CFG$HourRun + ":00.00"
$ !      "+1-xx:xx" = "TOMORROW" -- for test/eval
$ !      "+7-xx:xx" = "Weekly/next week" -- for production
$ !      VMS help: Whenever a plus sign (+) precedes the delta time,
$ !                enclose the entire time spec in quotation marks.
$ ELSE ! doing Monthly reporting...
$      now = F$TIME()
$      nowday = F$CVTIME(now,"COMPARISON","DAY")
$      IF ( F$INTEGER(nowday) .LT. 16 )
$      THEN forward  = "32"
$           backward = "16"
$      ELSE forward  = "16"
$           backward = "32"
$      ENDIF
$      prevdate     = F$CVTIME("TODAY-''backward'-00:00","ABSOLUTE","DATE")
$      prevmonth    = F$CVTIME(prevdate,"ABSOLUTE","MONTH")
$      prevyear     = F$CVTIME(prevdate,"ABSOLUTE","YEAR")
$      nextdate     = F$CVTIME("TODAY+''forward'-00:00","ABSOLUTE","DATE")
$      nextmonth    = F$CVTIME(nextdate,"ABSOLUTE","MONTH")
$      nextyear     = F$CVTIME(nextdate,"ABSOLUTE","YEAR")
$      ReportDate   = "1-" + prevmonth + "-" + prevyear
$      NextBatchRun = "1-" + nextmonth + "-" + nextyear + "+" + CFG$HourRun + ":00.00"
$      IF ( Debug ) THEN wserr "Next Batch Run: ""''NexBatchRun'"""
$ ENDIF
$ !
$ IF ( F$EXTRACT(0,4,F$EDIT(P1,"UPCASE,TRIM")) .EQS. "HELP" ) .OR. ( P1 .EQS. "?" ) -
    THEN GOTO Help
$ !
$ DEFINE /NOLOG /PROCESS UPwdList "''RptDir'''Fac'.distr"
$ !
<<<<<<< HEAD
$ IF ( F$EXTRACT(0,4,F$EDIT(P1,"UPCASE,TRIM")) .EQS. "SUBM" )
$ THEN CALL SelfSubmit "''Proc'" "''RptDir'" "''ProcMode'" "''NextBatchRun'" "''P2'" "''P3'"
$      GOTO Done
$ ENDIF
$ !
=======
$ IF ( F$EXTRACT(0,4,F$EDIT(P1,"UPCASE,TRIM")) .EQS. "SUBM" ) THEN GOTO Submit
>>>>>>> bd45700215a33876b5112b5b37da87d895c7536c
$ GOTO 'ProcMode'
$ !
$ !
$INTERACTIVE:
$ CALL GenReport "''P1'" "''P2'" "''P3'" "''ThisReport'"
$ CALL ArchiveReports "''ThisReport'"
$ CALL ArchiveReports "''ThisMsg'"
$ !
$ READ sys$command answer -
    /END_OF_FILE=Done /PROMPT="Display report (Yes/no)? "
$ type_it = F$EXTRACT(0,1,F$PARSE(F$EDIT(answer,"TRIM,COLLAPSE,UPCASE"),"Yes",,"NAME","SYNTAX_ONLY"))
$ IF ( type_it .EQS. "Y" )
$ THEN wso ""
$      wso "[4mSystem: ''ThisNode'[0m"
$      TYPE /PAGE 'ThisReport'
$ ENDIF
$ !
$ GOTO SpecialFunctions
$ !
$BATCH:
$ type_it = "No"
$ CALL GenReport "''P1'" "''P2'" "''P3'" "''ThisReport'"
$ subjline = F$FAO( "%!AS-I-VIOLATION, system !AS, !ZL possible violation!%S found to review", -
                      Fac, ThisNode, F$INTEGER( UI$search_records_matched ) )
$ CALL EMailIt "''UI$search_records_matched'" "''subjline'" -
         "''Fac'" "''ThisNode'" "''ThisReport'" "''ReportDate'" "''ThisMsg'"
$ CALL ArchiveReports "''ThisReport'"
<<<<<<< HEAD
$ CALL ArchiveReports "''ThisMsg'"
$ !
$ ! ReQueue self for next periodic run:
=======
$ subjline = F$FAO( "%!AS-I-VIOLATION, system !AS, !ZL possible violation!%S found to review", -
                      Fac, ThisNode, UI$search_records_matched )
$ CALL EMailIt "''UI$search_records_matched'" "''subjline'" -
         "''Fac'" "''ThisNode'" "''ThisReport'" "''ReportDate'" "''ThisMsg'"
$ !
$ !
$Submit:
$ type_it = "No"
>>>>>>> bd45700215a33876b5112b5b37da87d895c7536c
$ CALL SelfSubmit "''Proc'" "''RptDir'" "''ProcMode'" "''NextBatchRun'" "''P2'" "''P3'"
$ !
$ !
$SpecialFunctions:
$ !
$ ! ---------------------------------------------------------
$ ! *** Optional Special Function process(es) invocation, ***
$ ! ***   up to five (5) special function com-files:      ***
$ i = 1
$SFLoop:
$ ! If the special function com-file returns ThisReport global symbol
$ ! with non-null content, then email that report:
$ ThisReport == ""
$ ThisMsg    == ""
$ IF ( F$TYPE( CFG$SpecFunc'i' ) .NES. "STRING" ) THEN GOTO Cleanup
$ IF ( i .GT. 5 ) THEN GOTO Cleanup  ! hard limit...
$ IF ( CFG$SpecFunc'i' .NES. "" )
$ THEN sf0 = F$ELEMENT( 0, VERTBAR, CFG$SpecFunc'i' )  ! com-file to invoke
$      sf1 = F$ELEMENT( 1, VERTBAR, CFG$SpecFunc'i' )  ! parameter string(s) for com-file
$      sf2 = F$ELEMENT( 2, VERTBAR, CFG$SpecFunc'i' )  ! F$FAO lex-function for email-rpt subject-line
$      specfunc = F$TRNLNM( sf0 )
$      IF ( specfunc .EQS. "" ) THEN specfunc = F$PARSE( sf0, "''RptDir'.COM" )
$      IF ( F$SEARCH( specfunc ) .NES. "" )
$      THEN IF Debug THEN wserr F$FAO( "%!AS-I-INVOKE, $ @!AS", Fac, specfunc )
$           @'specfunc' 'sf1'
$           ! ThisReport non-null?  Email the report:
$           IF ( ThisReport .NES. "" )
$           THEN IF ( ProcMode .EQS. "BATCH" )
$                THEN ! email the Msg-report
$                     rfn = F$PARSE( ThisReport, , , "NAME", "SYNTAX_ONLY" )
$                     ThisMsg == F$PARSE( rfn, "''RptDir'.MSG" )
$                     ! sf2 contains an F$FAO() lex-function
$                     subjline = 'sf2'
$                     CALL EMailIt "1" "''subjline'" -
                         "''Fac'" "''ThisNode'" "''ThisReport'" "" "''ThisMsg'"
<<<<<<< HEAD
$                     CALL ArchiveReports "''ThisReport'"
$                     CALL ArchiveReports "''ThisMsg'"
=======
>>>>>>> bd45700215a33876b5112b5b37da87d895c7536c
$                ELSE IF ( type_it .EQS. "Y" ) THEN TYPE /PAGE 'ThisReport'
$                ENDIF
$           ENDIF
$      ELSE wserr F$FAO( "%!AS-E-FNF, CFG$SpecFunc!1ZL file not found: !AS", -
                         Fac, i, specfunc )
$      ENDIF
$ ENDIF
$ i = i + 1
$ GOTO SFLoop
$ ! ---------------------------------------------------------
$ !
$ !
$Cleanup:
$Done:
$ SET NOON
$ CLOSE /NOLOG iuc
$ IF ( .NOT. Debug ) THEN IF ( F$TYPE(UI$search_records_matched) .EQS. "STRING" ) -
  THEN DELETE /SYMBOL /GLOBAL UI$search_records_matched
$ IF ( F$TYPE(ThisNode)   .EQS. "STRING" ) THEN DELETE /SYMBOL /GLOBAL ThisNode
$ IF ( F$TYPE(ThisReport) .EQS. "STRING" ) THEN DELETE /SYMBOL /GLOBAL ThisReport
$ IF ( F$TYPE(ThisMsg)    .EQS. "STRING" ) THEN DELETE /SYMBOL /GLOBAL ThisMsg
<<<<<<< HEAD
$ IF ( F$TRNLNM( "UPwdList", "LNM$PROCESS" ) .NES. "" ) THEN DEASSIGN /PROCESS UPwdList
=======
>>>>>>> bd45700215a33876b5112b5b37da87d895c7536c
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$FNFerror:
$ wso F$FAO( "%!AS-E-FNF, cannot find/read configuration file !AS", -
             Fac, config )
$ GOTO CleanUp
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:                                                             !'F$VERIFY(0)'
$ IF ( F$EXTRACT(0,4,F$EDIT(P2,"UPCASE")) .EQS. "CONF" ) THEN GOTO HelpConfig
$ IF ( F$EXTRACT(0,4,F$EDIT(P2,"UPCASE")) .EQS. "DIST" ) THEN GOTO HelpDistr
$ TYPE /PAGE sys$input

  Reports user accounts which violate password lifetime or minimum
  character length requirements.

  usage:
    [1m@USERS_PASSWORDS[0m [ [1mNN[0m[[1m-DAYS[0m]
                     | [1mNN-WEEKS[0m
                     | [1mNN-MONTHS[0m
                     | [1mNN-QUARTERS[0m
                     | [1mNN-YEARS[0m
                     | [1mSUBMIT[0m [[1mforuser[0m] [[1mdate+time[0m]
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

  [1mSUBMIT[0m    Submits the command procedure to the SYS$BATCH batch queue for
            recurring report generation, using either or both the [1mforuser[0m and/or
            [1mdate+time[0m parameters following [1mSUBMIT[0m.
            If P2 is the literal string "[1m$STARTUP$[0m", then the variables from
            the configuration file to specify batch username (CFG$SubmitForDef),
            resubmission period (CFG$DaysAgo) and hour to run (CFG$HourRun).  This
            is how this AUDITREPORT command procedure is resubmitted from the
            Security Startup command file SECAUDIT$TOP:SECAUDIT$STARTUP.COM:
                $ [1m@SECAUDIT$Top:USERS_PASSWORDS SUBMIT [4m$STARTUP$[0m
            Thus, the above command can be used directly from the command line's
            $-prompt to resubmit this script for the next regular monthly run.
            You can use:
                $ [1mSHOW QUEUE /BATCH /ALL SYS$BATCH[0m
            to review/check this recurring batch job.

    [1mHELP[0m  Displays this help text.
    or [1m?[0m

  [4mCommand Line Parameter-2[0m:

  [1mforuser[0m   The username of a valid VMS user account under which this
            procedure is to run as a batch job.  You (the process
            submitting this batch job for another user) must have the
            IMPERSONATE (or DETACH) privilege authorized or defaulted
            for your account.

  [1m$STARTUP$[0m This literal value means that the values for CFG$SubmitForDef,
            CFG$DaysAgo and CFG$HourRun from the current USERS_PASSWORDS.CONFIG
            file are used (rather than values on the command line).

  [1mCONF[0m[[1mIGURATION[0m]  Help on the the Configuration File.

  [1mDIST[0m[[1mRIBUTION[0m]   Help on the Email Distribution File.

  [4mCommand Line Parameter-3[0m:

  [1mdate+time[0m If ommitted, the batch job will be submitted for immediate
            execution; otherwise, the batch job will be submitted for
            execution on the date and time specified, e.g.: "TOMORROW+05:00"
            (tomorrow at 5:00am), or "27-AUG-2016+06:00" (6:00am on the 27th
            of August).  Be certain to include [4mdouble-quote marks[0m around this
            parameter on the command line, as indicated in the samples.

$ !
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$ !
$HelpConfig:
$ TYPE 'RptDir''Fac'.CONFIG
$ TYPE sys$input
  ----------

  The Configuration File provides a system- or site-specific means to
  provide specific values for the following five procedural internal
  variables (local symbols):

  CFG$IncludeFlags -- If "TRUE", forces the output/display of SYSUAF user-account
       records to include the "Flags" field; this field is omitted if this value
       is "FALSE".

  CFG$PwdLifeTime -- Specifies the Security Policy Password Lifetime, against which
       individual SYSUAF user-account records are compared for violations.

  CFG$PwdMinimum -- Specifies the Security Policy Password Minimum Length, against
       which individual SYSUAF user-account records are compared for violations.

  CFG$CSVoutput -- If "TRUE", forces output to be formatted as "Comma-Separated
       Value" (CSV), appropriate for importing into an Excel or Calc spreadsheet.
       If "FALSE", forces output to "human readable" format, which then can be
       optionally displayed on the user's terminal screen, or printed.

  CFG$SubmitForDef -- The username (e.g., LRICKER) of the user account which
       will be the default username (string) offered by the prompt for
       submitting this batch job.

  CFG$DaysAgo -- Specifies the report period (span of days) for which the
       Audit Report is to be generated, that is: "1" means report for the
       past day, "7" means report for the past week, and "30" (or any value
       greater than 28) means report for the past month.
       [4mAlso[0m implies that the report will resubmit itself for daily, weekly
       or monthly (on the 1st) runs.

  CFG$HourRun -- The hour-of-day at which future scheduled batch runs of this
       procedure are to occur; e.g., "05:10" for five-ten AM, etc.

  CFG$SpecFunc«N» -- Up to five of these Special Function symbols, where
       «N» is an integer from 1...5.  Specifies the name, a set of com-file
       parameters, and an F$FAO string for an email subject line.

$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$ !
$HelpDistr:
$ TYPE 'RptDir''Fac'.DISTR
$ TYPE sys$input
  ----------

  The EMail Distribution File provides a system- or site-specific means
  to send Audit Report email output to specific users.  It is a simple
  list of email addresses, one per line, as shown above.

  Since general Internet-style email addresses are permitted, and likely
  prevalent, be sure to surround each email address with double-quotes,
  as shown above.

$ EXIT 1    ! 'F$VERIFY(0)'
$ !
