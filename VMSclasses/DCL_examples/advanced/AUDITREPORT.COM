$ ! AUDITREPORT.COM --                                             'F$VERIFY(0)'
$ !
$ ! use:  $ @AUDITREPORT
$ !  or:  $ @AUDITREPORT [startdate] [username[,username...]]
$ !  or:  $ @AUDITREPORT [ SUBMIT [foruser] [date+time] ]
$ !  or:  $ @AUDITREPORT [ HELP [CONFIGURATION | DISTRIBUTION] | ? ]
$ !
$ ! Audit/detect changes made to VMS User Authorization Database --
$ !   Reports "AUTHORIZATION" events in VMS Security Audit Journal,
$ !   and requires that the "AUTHORIZATION" event class be enabled
$ !   as an /AUDIT event (enabling this class for /ALARM is optional).
$ !
$ ! Copyright © 2016 by Dan Fleury and Lorin Ricker.  All rights reserved,
$ ! with acceptance, use, modification and/or distribution permissions as
$ ! granted and controlled by and under the GPL described herein.
$ !
$ ! This program (software) is Free Software, licensed under the terms and
$ ! conditions of the GNU General Public License Version 3 as published by
$ ! the Free Software Foundation: http://www.gnu.org/copyleft/gpl.txt,
$ ! which is hereby incorporated into this software and is a non-severable
$ ! part thereof.  You have specific rights and obligations under this GPL
$ ! which are binding if and when you accept, use, modify and/or distribute
$ ! this software program (source code file) and/or derivatives thereof.
$ !
$ ! 23-Oct-2016 -- Provide "$STARTUP$" as command-line parameter to
$ !                force the use of config-file (AUDITREPORT.CONFIG)
$ !                values for batch submission.  LMR
$ ! 19-Oct-2016 -- If no audit events to report, create an "no events"
$ !                report as an official placeholder to send.  LMR
$ ! 04-Oct-2016 -- Minor tweaks to track ReportDate and mail $STATUS
$ !                in AUDIREPORT.LOG file.  LMR
$ ! August 2016 -- DLF & LMR/PARSEC
$ !
$ !
$ ! -----------------------
$GenAuditReport: SUBROUTINE
$ ! P1 : report scope (/FULL or /BRIEF)
$ ! P2 : event type
$ ! P3 : event selection
$ ! P4 : since datetime
$ ! P5 : output report filespec
$ ! P6 : VMS Security Audit Journal filespec
$ !
$ ON ERROR THEN GOTO ARErr
$ privs = F$SETPRV(requiredprivs)
$ IF .NOT. F$PRIVILEGE("SECURITY") THEN EXIT %x2934  ! operation requires SECURITY privilege
$ wso F$FAO( "%!AS-I-SINCE, reporting Audit Events since ""!AS""", -
              Fac, P4 )
$ ANALYZE /AUDIT 'P1' /EVENT=('P2') 'P3' /SINCE="''P4'" -
    /OUTPUT='P5' 'P6'
$ Stat = $STATUS
$ARErr:
$ IF ( F$TYPE(privs) .EQS. "STRING" ) THEN privs = F$SETPRV(privs)
$ EXIT 'Stat'
$ ENDSUBROUTINE  ! GenAuditReport
$ !
$AttachMIME:  SUBROUTINE
$ ! P1 : Audit Email-Msg filespec
$ ! P2 : Audit Report filespec
$ ! P2 : Subject line
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
$ArchivePastReports:  SUBROUTINE
$ archive = "AR$REPORTS"
$ ! If there is more than one report, push 'em all into archive sub-dir:
$ IF ( F$SEARCH( "SECAUDIT$Top:''P1';-1" ) .NES. "" )
$ THEN RENAME /LOG SECAUDIT$Top:'P1';* SECAUDIT$ROOT:['archive']*.*;*
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! ArchivePastReports
$ !
$ArchivePreviousReport:  SUBROUTINE
$ archive = "AR$REPORTS"
$ ! Push previous report into archive:
$ IF ( F$SEARCH( "SECAUDIT$Top:''P1';-1" ) .NES. "" )
$ THEN RENAME /LOG SECAUDIT$Top:'P1';-1 SECAUDIT$ROOT:['archive']*.*
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! ArchivePreviousReport
$ !
$ ! -----------------------
$ !
$ !
$ ! -----------------------
$Main:
$ ON ERROR THEN GOTO Done
$ ON CONTROL THEN GOTO Done
$ !
$ ProcMode = F$MODE()
$ ThisNode = F$EDIT(F$GETSYI("NODENAME"),"TRIM")
$ ThisUser = F$EDIT(F$GETJPI("","USERNAME"),"TRIM")
$ !
$ wso      = "WRITE sys$output"
$ DQUOTE   = """"
$ !
$ requiredprivs = "SECURITY,SYSPRV"
$ submitprivs   = "IMPERSONATE,CMKRNL"
$ !
$ Proc       = F$ENVIRONMENT("PROCEDURE")
$ Proc       = Proc - F$PARSE(Proc,,,"VERSION","SYNTAX_ONLY")
$ Fac        = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ RptDir     = F$PARSE(Proc,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(Proc,,,"DIRECTORY","SYNTAX_ONLY")
$ rptdstr    = RptDir + "AUDIT_" + F$CVTIME("","COMPARISON","DATE")
$ ThisReport = rptdstr + ".REPORT"
$ TmpReport  = rptdstr + ".TMP"
$ ThisMsg    = RptDir + F$PARSE(ThisReport,,,"NAME","SYNTAX_ONLY") + ".MSG"
$ !
$ CALL ArchivePastReports "''ThisReport'"
$ CALL ArchivePastReports "''ThisMsg'"
$ !
$ ! ===========================================
$ ! Read/execute lines from configuration file:
$ config = RptDir + Fac + ".CONFIG"
$ IF ( F$SEARCH(config) .NES. "" )
$ THEN OPEN /READ /ERROR=FNFerror arc 'config'
$ARCloop:
$      READ /END_OF_FILE=ARCdone arc line
$      cmd = F$EDIT(line,"UNCOMMENT,COMPRESS")
$      IF ( cmd .NES. "" ) THEN 'cmd'  ! execute config-file lines directly...
$      GOTO ARCloop
$ ELSE GOTO FNFerror
$ ENDIF
$ARCdone:
$ CLOSE /NOLOG arc
$ ! ===========================================
$ !
$ after   = ""
$ IF ( F$INTEGER(AR$DaysAgo) .LT. 28 )
$ THEN ! doing Daily or Weekly reporting...
$      NextBatchRun = "TODAY+" + AR$DaysAgo + "-" + AR$HourRun + ":00.00"
         ! "+1-xx:xx" = "TOMORROW" -- for test/eval
         ! "+7-xx:xx" = "Weekly/next week" -- for production
         ! VMS help: Whenever a plus sign (+) precedes the delta time,
         !           enclose the entire time spec in quotation marks.
$      after = "/AFTER=" + DQUOTE + NextBatchRun + DQUOTE
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
$      NextBatchRun = "1-" + nextmonth + "-" + nextyear + "+" + AR$HourRun + ":00.00"
$      after = "/AFTER=" + DQUOTE + NextBatchRun + DQUOTE
$ ENDIF
$ !
$ IF ( F$EXTRACT(0,4,F$EDIT(P1,"UPCASE,TRIM")) .EQS. "HELP" ) .OR. ( P1 .EQS. "?" ) -
    THEN GOTO Help
$ IF ( F$EXTRACT(0,4,F$EDIT(P1,"UPCASE,TRIM")) .EQS. "SUBM" ) THEN GOTO Submit
$ GOTO 'ProcMode'
$ !
$INTERACTIVE:
$ IF ( P1 .EQS. "" )
$ THEN READ sys$command ReportDate -
         /END_OF_FILE=Done /PROMPT="Starting date/time for this audit report: "
$      IF ( ReportDate .EQS. "" ) THEN ReportDate = "TODAY-''AR$DaysAgo'-00:00:00"
$ ELSE ReportDate = P1
$ ENDIF
$ !
$ IF ( P2 .EQS. "" )
$ THEN READ sys$command users  -
         /END_OF_FILE=Done /PROMPT="Select usernames (comma-separated): "
$      IF ( users .EQS. "" )
$      THEN select = ""
$      ELSE select = "/SELECT=(USER=" + user + ")"
$      ENDIF
$ ELSE select = "/SELECT=(USER=" + P2 + ")"
$ ENDIF
$ !
$ CALL GenAuditReport "/FULL" "''AR$Events'" "''select'" "''ReportDate'" "''ThisReport'" "''AR$SecJouFile'"
$ CALL ArchivePreviousReport "''ThisReport'"
$ !
$ READ sys$command answer -
    /END_OF_FILE=Done /PROMPT="Display Summary or Full report ([1mSummary[0m/Full): "
$ answer = F$EXTRACT(0,1,F$PARSE(F$EDIT(answer,"TRIM,COLLAPSE,UPCASE"),"Summary",,"NAME","SYNTAX_ONLY"))
$ wso ""
$ wso "[4mSystem: ''ThisNode'[0m"
$ IF ( answer .EQS. "F" )
$ THEN TYPE /PAGE 'ThisReport'
$ ELSE SEARCH /PAGE=SAVE=5 /HIGHLIGHT /WINDOW=(12,4) 'ThisReport' 'AR$FilterList'
$ ENDIF
$ !
$ GOTO Done
$ !
$ !
$BATCH:
$ DEFINE /NOLOG /PROCESS ARDlist "''RptDir'AuditReport.distr"
$ !
$ CALL GenAuditReport "/FULL" "''AR$Events'" "" "''ReportDate'" "''TmpReport'" "''AR$SecJouFile'"
$ CALL ArchivePreviousReport "''ThisReport'"
$ !
$ SEARCH /NOHIGHLIGHT /WINDOW=(12,5) /STATISTICS=SYMBOLS /OUTPUT='ThisReport' 'TmpReport' 'AR$FilterList'
$ SHOW SYMBOL SEARCH$*
$ IF ( F$SEARCH(TmpReport) .NES. "" ) THEN DELETE /NOLOG 'TmpReport';*
$ !
$ recmatched = F$INTEGER( SEARCH$RECORDS_MATCHED )
$ IF ( recmatched .EQ. 0 )
$ THEN subjline = F$FAO( "%!AS-I-NOEVENTS, system !AS, no relevant security events found for this report run", -
                         Fac, ThisNode )
$      OPEN /WRITE erf 'ThisReport'
$      WRITE erf subjline
$      WRITE erf ""
$      WRITE erf "Report period: ''ReportDate' to ''F$CVTIME(F$TIME(),"ABSOLUTE","DATE")'"
$      WRITE erf ""
$      CLOSE erf
$      PURGE /NOLOG 'ThisReport'
$ ELSE subjline = F$FAO( "%!AS-I-VIOLATION, system !AS, !ZL possible violation!%S found to review", -
                         Fac, ThisNode, recmatched )
$ ENDIF
$ !
$ CALL AttachMIME "''ThisMsg'" "''ThisReport'" "''subjline'"
$ ! ThisMsg now has attachment ThisReport:
$ MAIL 'ThisMsg' /SUBJECT="''subjline'" "@ARDlist"
$ MailStat = $STATUS
$ msg1 = F$FAO( "%!AS-I-MAILED, report attached:", Fac )
$ msg2 = "subject line:"
$ indL = F$LENGTH( msg1 ) - F$LENGTH( msg2 )
$ wso F$FAO( "!AS !AS", msg1, ThisReport )
$ wso F$FAO( "!#* !AS !AS", indL, msg2, subjline )
$ wso ""
$ wso F$FAO( "%!AS-I-STATUS, mail-report status code: !ZL", -
             Fac, MailStat )
$ wso F$FAO( "%!AS-I-STATUS, !AS", -
             Fac, F$MESSAGE( MailStat ) )
$ wso ""
$ CALL ArchivePreviousReport "''ThisMsg'"
$ !
$ !
$Submit:
$ notify  = ""
$ foruser = ""
$ IF ( ProcMode .EQS. "INTERACTIVE" )
$ THEN notify = "/NOTIFY"
$      IF ( P2 .EQS. "$STARTUP$" )
$      THEN submitfor = AR$SubmitForDef
$      ELSE IF ( P2 .NES. "" )
$           THEN submitfor = P2
$           ELSE READ sys$command answer /PROMPT="Submit for user [''AR$SubmitForDef']: " /END_OF_FILE=Done
$                submitfor = F$PARSE(answer,AR$SubmitForDef,,"NAME","SYNTAX_ONLY")
$           ENDIF
$           IF ( P3 .EQS. "" )
$           THEN after = ""
$           ELSE after = "/AFTER=" + DQUOTE + P3 + DQUOTE
$           ENDIF
$      ENDIF
$      IF ( F$EXTRACT(0,5,ThisUser) .EQS. F$EXTRACT(0,5,submitfor) )
$      THEN ! submitting job for self:
$           foruser = ""
$      ELSE ! submitting for another user; must be (re)submitted by a privileged
$           ! user/account with IMPERSONATE/DETACH and CMKRNL privilege:
$           privs = F$SETPRV(submitprivs)
$           IF F$PRIVILEGE("IMPERSONATE") .AND. F$PRIVILEGE("CMKRNL")
$           THEN foruser = "/USER=''submitfor'"
$           ELSE ! no priv: IMPERSONATE or DETACH
$                wso "%''Fac'-E-NOPRIV, must have IMPERSONATE/DETACH and CMKRNL to submit for another user"
$                GOTO NoSubmit
$           ENDIF
$      ENDIF
$ ELSE notify = ""
$ ENDIF
$ !
$ submit = ""  ! don't use the process's global symbol/alias...
$ SUBMIT 'Proc' 'notify' 'foruser' 'after' -
    /LOG_FILE='RptDir' /QUEUE=sys$batch /NOPRINT
$ !
$NoSubmit:
$ IF ( F$TYPE(privs) .EQS. "STRING" ) THEN privs = F$SETPRV(privs)
$ !
$ GOTO Done
$ !
$Done:
$ IF ( F$SEARCH("''ThisMsg';-1") .NES. "" )
$ THEN PURGE /NOLOG 'ThisMsg'
$      RENAME /NOLOG 'ThisMsg' *.*;1
$ ENDIF
$ IF ( F$SEARCH("''ThisReport';-1") .NES. "" )
$ THEN PURGE /NOLOG 'ThisReport'
$      RENAME /NOLOG 'ThisReport' *.*;1
$ ENDIF
$NETWORK:
$OTHER:
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$FNFerror:
$ wso F$FAO( "%!AS-E-FNF, cannot find/read configuration file !AS", -
             Fac, config )
$ EXIT %x2C    ! 'F$VERIFY(0)'
$ !
$ !
$ ! -----------------------
$Help:                                                             !'F$VERIFY(0)'
$ IF ( F$EXTRACT(0,4,F$EDIT(P2,"UPCASE")) .EQS. "CONF" ) THEN GOTO HelpConfig
$ IF ( F$EXTRACT(0,4,F$EDIT(P2,"UPCASE")) .EQS. "DIST" ) THEN GOTO HelpDistr
$ TYPE /PAGE sys$input
[4mAUDITREPORT.COM[0m

    use:  $ [1m@AUDITREPORT[0m
     or:  $ [1m@AUDITREPORT[0m [[1mstartdate[0m] [[1musername[0m[,[1musername[0m...]]
     or:  $ [1m@AUDITREPORT[0m [ [1mSUBMIT[0m [[1mforuser[0m] [[1mdate+time[0m] ]
     or:  $ [1m@AUDITREPORT[0m [ [1mHELP[0m [[1mCONFIGURATION[0m | [1mDISTRIBUTION[0m] | [1m?[0m ]

  This procedure generates a periodic Audit Report of any changes made
  to the system's User Authorization Database (including SYSUAF.DAT,
  RIGHTSLIST.DAT, and NET*PROXY.DAT) for system auditing and verification
  purposes.

  This procedure can be run interactively (from the command line), or
  may be submitted as a nightly-recurring batch job.  When this report
  is generated from a batch job, the report is emailed to the Security
  Officer.  When it is run interactively, the report output is simply
  displayed on-screen.

  The most common use is to run this script with no parameters (as the
  first command example above): the resulting report is for the "past
  report period" (daily or weekly).  In this case, prompts are offered
  for "Starting date/time of summary report:" and "Usernames to report
  (comma separated):" -- press <Enter> to either or both of these prompts
  to accept the defaults, or enter values for either, such as "27-AUG-2016"
  or "WSMITH,SJONES,JDOE".

  See the following parameters for more information:

  [4mCommand Line Parameter-1[0m:

  [1mstartdate[0m The starting date for which this current report is to be
            generated, in standard VMS date format, e.g.: "01-JAN-2016"
            or "18-jul-2016".  If this parameter is missing on the command
            line, you will be prompted for a value.  If you enter do not
            enter a value for this prompt (just hit <Enter>), the report
            will be generated for the default reporting period (which is
            configured in the AUDITREPORT.CONFIG file).

  [1mSUBMIT[0m    Submits the command procedure to the SYS$BATCH batch queue for
            nightly recurring report generation.  You can use
                $ [1mSHOW QUEUE /BATCH /ALL SYS$BATCH[0m
            to review/check this recurring batch job.

  [1mHELP[0m      Displays this help text.  See also CONFIGURATION below.
  or [1m?[0m

  [4mCommand Line Parameter-2[0m:

  [1musername[0m  Either a single username, or a comma-separated list of two
            or more usernames.  These are used to select (filter) specific
            users to report.  If this parameter is missing on the command
            line, you will be prompted for a value.  If you do not enter
            a value for this prompt (just hit <Enter>), the report will be
            generated for all/any users.

  [1mforuser[0m   The username of a valid VMS user account under which this
            procedure is to run as a batch job.  You (the process
            submitting this batch job for another user) must have the
            IMPERSONATE (or DETACH) privilege authorized or defaulted
            for your account.

  [1m$STARTUP$[0m This literal value means that the values for AR$SubmitForDef,
            AR$DaysAgo and AR$HourRun from the current AUDITREPORT.CONFIG
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
$ TYPE /PAGE 'RptDir''Fac'.CONFIG_TEMPLATE
$ TYPE sys$input
  ----------

  The Configuration File provides a system- or site-specific means to
  provide specific values for the following five procedural internal
  variables (local symbols):

  AR$FilterList -- A comma-separated list of search-text target phrases
        which are to be searched/found in the output of the ANALYZE /AUDIT
        output report.  Note that each individual element of this comma-
        separated list of search targets must be double-quoted themselves
        -- follow this sample closely.

  AR$Events -- The Audit Events to report in the ANALYZE /AUDIT command,
       provides the events to the /EVENT_TYPE=(...) selection.

  AR$SecJouFile -- The full file specification of the Security Audit
       Journal File for this system (may be relocated from the "standard"
       SYS$MANAGER:SECURITY.AUDIT$JOURNAL file location).

  AR$SubmitForDef -- The username (e.g., LRICKER) of the user account which
       will be the default username (string) offered by the prompt for
       submitting this batch job.

  AR$DaysAgo -- Specifies the report period (span of days) for which the
       Audit Report is to be generated, that is: "1" means report for the
       past day, "7" means report for the past week, and "30" (or any value
       greater than 28) means report for the past month.
       [4mAlso[0m implies that the report will resubmit itself for daily, weekly
       or monthly (on the 1st) runs.

  AR$HourRun -- The hour-of-day at which future scheduled batch runs of this
       procedure are to occur; e.g., "05:00" for five AM, etc.

$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$ !
$HelpDistr:
$ TYPE /PAGE 'RptDir''Fac'.DISTR_TEMPLATE
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
