$ ! AUDITREPORT.COM --                                             'F$VERIFY(0)'
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
$ ! August 2016 -- DLF & LMR/PARSEC
$ !
$ ! use:  $ @AUDITREPORT
$ !  or:  $ @AUDITREPORT [startdate] [username[,username...]]
$ !  or:  $ @AUDITREPORT [ SUBMIT | HELP | ? ]
$ !
$ ! -----------------------
$AudReport: SUBROUTINE
$ ! P1 : report scope (/FULL or /BRIEF)
$ ! P2 : event type
$ ! P3 : event selection
$ ! P4 : since datetime
$ ! P5 : output report filespec
$ ! P6 : VMS Security Audit Journal filespec
$ !
$ ON ERROR THEN GOTO ARErr
$ privs = F$SETPRV(reqprivs)
$ IF .NOT. F$PRIVILEGE("SECURITY") THEN EXIT %x2934  ! operation requires SECURITY privilege
$ ANALYZE /AUDIT 'P1' /EVENT=('P2') 'P3' /SINCE="''P4'" -
    /OUTPUT='P5' 'P6'
$ Stat = $STATUS
$ARErr:
$ IF ( F$TYPE(privs) .EQS. "STRING" ) THEN privs = F$SETPRV(privs)
$ EXIT 'Stat'
$ ENDSUBROUTINE  ! AudReport
$ ! -----------------------
$ !
$ !
$ ! -----------------------
$Main:
$ ON ERROR THEN GOTO Done
$ ON CONTROL THEN GOTO Done
$ !
$ ProcMode = F$MODE()
$ wso      = "WRITE sys$output"
$ ThisNode = F$EDIT(F$GETSYI("NODENAME"),"TRIM")
$ !
$ NextBatchRun  = """TOMORROW+05:00"""  ! VMS help: Whenever a plus sign (+) precedes the delta time,
$                                       !           enclose the entire time spec in quotation marks.
$ BatchReportTo = """lricker@parsec.com"",""dfleury@parsec.com"""  ! Each email-addr must be ""-quoted
$ !
$ reqprivs   = "SECURITY,SYSPRV"
$ SecJouFile = "SYS$MANAGER:SECURITY.AUDIT$JOURNAL"
$ !
$ Proc       = F$ENVIRONMENT("PROCEDURE")
$ Proc       = Proc - F$PARSE(Proc,,,"VERSION","SYNTAX_ONLY")
$ Fac        = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ RptDir     = F$PARSE(Proc,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(Proc,,,"DIRECTORY","SYNTAX_ONLY")
$ rptdstr    = RptDir + "AUDIT_" + F$CVTIME("","COMPARISON","DATE")
$ daysago    = "7"
$ !
$ FilterList = """privileges:"",""lifetime:"",""expiration:"",""flags:"""
$ !
$ IF ( F$EXTRACT(0,4,F$EDIT(P1,"UPCASE,TRIM")) .EQS. "HELP" ) .OR. ( P1 .EQS. "?" ) -
    THEN GOTO Help
$ IF ( F$EXTRACT(0,4,F$EDIT(P1,"UPCASE,TRIM")) .EQS. "SUBM" ) THEN GOTO SelfSubmit
$ GOTO 'ProcMode'
$ !
$INTERACTIVE:
$ IF ( P1 .EQS. "" )
$ THEN READ sys$command reportdate -
         /END_OF_FILE=Done /PROMPT="Starting date/time for this audit report: "
$      IF ( reportdate .EQS. "" ) THEN reportdate = "TODAY-''daysago'-00:00:00"
$ ELSE reportdate = P1
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
$ ThisReport = rptdstr + ".REPORT"
$ !
$ CALL AudReport "/FULL" "SYSUAF" "''select'" "''reportdate'" "''ThisReport'" "''SecJouFile'"
$ !
$ READ sys$command answer -
    /END_OF_FILE=Done /PROMPT="Display Summary or Full report ([1mSummary[0m/Full): "
$ answer = F$EXTRACT(0,1,F$PARSE(F$EDIT(answer,"TRIM,COLLAPSE,UPCASE"),"Summary",,"NAME","SYNTAX_ONLY"))
$ wso ""
$ wso "[4mSystem: ''ThisNode'[0m"
$ IF ( answer .EQS. "F" )
$ THEN TYPE /PAGE 'ThisReport'
$ ELSE SEARCH /PAGE=SAVE=5 /HIGHLIGHT /WINDOW=(12,4) 'ThisReport' 'FilterList'
$ ENDIF
$ !
$ GOTO Done
$ !
$BATCH:
$ TmpReport  = rptdstr + ".TMP"
$ ThisReport = rptdstr + ".BATCH"
$ !
$ CALL AudReport "/FULL" "SYSUAF" "" "TODAY-''daysago'-00:00:00" "''TmpReport'" "''SecJouFile'"
$ SEARCH /NOHIGHLIGHT /WINDOW=(12,5) /STATISTICS=SYMBOLS /OUTPUT='ThisReport' 'TmpReport' 'FilterList'
$ DELETE /LOG 'TmpReport';*
$ SHOW SYMBOL SEARCH$*
$ !
$ recmatched = F$INTEGER( SEARCH$RECORDS_MATCHED )
$ IF ( recmatched .EQS. "0" )
$ THEN subjline = F$FAO( "%!AS-I-NOEVENTS, system ''ThisNode', no relevant security events found for this report run")
$      MAIL NLA0: /SUBJECT="''subjline'" 'BatchReportTo'
$ ELSE subjline = F$FAO( "%!AS-I-VIOLATION, system ''ThisNode', !ZL possible violation!%S found to review --", -
                         Fac, recmatched )
$      MAIL 'ThisReport' /SUBJECT="''subjline'" 'BatchReportTo'
$ ENDIF
$ wso "%''Fac'-I-MAILED, mail subj: ''subjline'"
$ !
$SelfSubmit:
$ ! Must be (re)submitted by Security Officer user/account with SECURITY privilege authorized:
$ privs = F$SETPRV(reqprivs)
$ IF .NOT. F$PRIVILEGE("SECURITY") THEN EXIT %x2934  ! operation requires SECURITY privilege
$ SUBMIT /QUEUE=sys$batch /AFTER='NextBatchRun' /NONOTIFY /NOPRINT /LOG_FILE='RptDir' 'Proc'
$ IF ( F$TYPE(privs) .EQS. "STRING" ) THEN privs = F$SETPRV(privs)
$ !
$ GOTO Done
$ !
$Done:
$ IF ( F$SEARCH("''ThisReport;-1") .NES. "" )
$ THEN PURGE /NOLOG 'ThisReport'
$      RENAME /NOLOG 'ThisReport' *.*;1
$ ENDIF
$NETWORK:
$OTHER:
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$ !
$ ! -----------------------
$Help:
$ TYPE /PAGE sys$input
[4mAUDITREPORT.COM[0m

    use:  $ [1m@AUDITREPORT[0m
     or:  $ [1m@AUDITREPORT[0m [[1mstartdate[0m] [[1musername[0m[,[1musername[0m...]]
     or:  $ [1m@AUDITREPORT[0m [ [1mSUBMIT[0m | [1mHELP[0m | [1m?[0m ]

  This procedure generates a periodic Audit Report of any changes made to the system's
  User Authorization Database (including SYSUAF.DAT, RIGHTSLIST.DAT, and NET*PROXY.DAT)
  for system auditing and verification purposes.
  
  This procedure can be run interactively (from the command line), or may be submitted
  as a nightly-recurring batch job.  When this report is generated from a batch job,
  the report is emailed to the Security Officer.  When it is run interactively, the
  report output is simply displayed on-screen.
  
  The most common interactive use is to run this script with no parameters (as the first
  example above): the resulting report is for the "past week", that is, the start-date
  is seven (7) days prior to today.  In this case, prompts are offered for "Starting
  date/time of summary report: " and "Usernames to report (comma separated): " -- press
  <Enter> to either or both of these prompts to accept the defaults, or enter values for
  either, such as "10-AUG-2016" or "JDEMAND02,WETTY02".
  
  See the following parameters for more information:
  
  [4mCommand Line Parameter-1[0m:
  
  [1mstartdate[0m The starting date for which this current report is to be generated, in standard
            VMS date/time format, e.g.: "01-JAN-2016" or "18-jul-2016".
            
  [1mSUBMIT[0m    Submits the command procedure to the SYS$BATCH batch queue for nightly recurring
            report generation.  Use $ [1mSHOW QUEUE /BATCH /ALL SYS$BATCH[0m to review/check this
            recurring batch job.

  [1mHELP[0m      Displays this help text.
  or [1m?[0m

  [4mCommand Line Parameter-2[0m:
  
  [1musername[0m  Either a single username, or a comma-separated list of two or more usernames.
            These are used to select (filter) specific users to report.

$ !
$ EXIT 1
$ !
