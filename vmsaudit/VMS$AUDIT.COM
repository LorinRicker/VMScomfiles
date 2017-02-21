$ ! VMS$AUDIT.COM --                                               'F$VERIFY(0)'
$ !
$ VA$ProcVersion = "V2.10-01 (21-Feb-2017)"
$ VA$Copyright   = "Copyright © 2014-2017"
$ !
$ ! Copyright © 2014-2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ !  use:  $ @VMS$AUDIT [ BRIEF (D) | EXTENDED
$ !                       | QUICK   | CLUSTER | REMOTE
$ !                       | TYPE    | EDIT
$ !                       | BACKUP  | RESTORE
$ !                       | ZIP     | UNZIP
$ !                       | FTP     | CLEANUP | HELP ]
$ !                     [ VMS$AUDITCONFIG_filespec ]
$ !
$ ! See HELP$: label and help-text for full details.
$ !
$ !
$ ! ========================
$ ! Release History:
$ !  21-FEB-2017 : Use non-searc-list logical CMD rather than COM.
$ !  20-FEB-2017 : Add RESET_ERRORCOUNT.(COM,TMP) to VMS$AUDIT.(BCK,ZIP) archives.
$ !  10-FEB-2017 : Add USERS_INACTIVE.(COM,CONFIG) and USERS_PASSWORDS.(COM,CONFIG)
$ !                to VMS$AUDIT.(BCK,ZIP) archives.
$ !  03-FEB-2017 : Add command alias TYR*EPORT to type "this" report to terminal.
$ !                Also add [.DFU]dfu*.* to saveset and zip.
$ !                Update copyright year.
$ !  02-SEP-2016 : Add SET PROFILE /PRIVILEGES=() to V$SYSMAN invocation, as
$ !                required privileges (e.g. SECURITY) were not being set for
$ !                cluster-wide operations.
$ !  22-AUG-2016 : In Quick_Report, moved the SHOW INTRUSION command into the
$ !                SYSMAN command group, as it really should be done for all
$ !                VMScluster nodes.
$ !  18-AUG-2016 : Add /NOREPLACE /LOG, remove /NEW_FILES on the Restore: BACKUP
$ !                operation.  Also, reformatted Help text to fit 80-columns.
$ !  05-AUG-2016 : Hoist local symbol VMSver to global symbol VMS$ver, including
$ !                Done-cleanup, for VMS version comparisons. Added \-quoted-output
$ !                of this string to Report Header for visibility.
$ !                Also conditionalize use of V$*QStalled (PIPE) commands correctly
$ !                in Quick_Report.
$ !                Also change backup and zip file lists to ship/archive only the
$ !                VMS$AUDIT_TEMPLATE.CONFIG (and not VMS$AUDIT_LRICKER.CONFIG)
$ !                so that in-use config-files are not accidentally overwritten
$ !                in the field.
$ !  05-AUG-2016 : Given comments-in-scripts issues for old versions of SYSMAN,
$ !                just inline the scripted commands as here-doc input. Simpler.
$ !                Fixes in Quick_Report, also remove the VMS$AUDIT_CLUSTER.SYSMAN*
$ !                script files from backup saveset and zip archives; also remove
$ !                QUICK_AUDIT.COM from same, it was just a placeholder.
$ !  04-AUG-2016 : Wow. Old VMS versions (<V7.1) of SYSMAN don't even accept
$ !                internal comment lines in the VMS$AUDIT_CLUSTER.SYSMAN_NOPIPE
$ !                script.  Take 'em out (including copyright) of Quick_Report.
$ !  20-JUL-2016 : Fixed a conditional-PIPE use that had been missed (for
$ !                V${Bat,Dev}QStalled commands).
$ !                Also, submit FILE$FIND VERSIONS iff VMS >= v7.1 (because
$ !                this com-file also uses PIPE).
$ !  18-JUL-2016 : Add FILE$FIND VERSIONS back into the mix, submitted as
$ !                a batch job, but only if the VMS$AUDIT configuration
$ !                file specifies non-null values for VA$FFV_Permitted
$ !                and VA$FFV_Disks.
$ !  15-JUL-2016 : This really needs a proper command/parameter parser,
$ !                so install Rick-&-Lorin's old standard Parse routine.
$ !                Also, thoroughly revise this procedure's command-line
$ !                structure: simplify it from 3 parameters to 2, one action
$ !                and the optional config-filespec.
$ !                Also, make the Quick Report (QUICK, CLUSTER, REMOTE) work right.
$ !                Also, rip out that kludge code for spawning and spinlocking on
$ !                FILE$FIND.COM -- better to submit this kind of thing as a batch
$ !                job, and look for its report-output later.
$ !                *** to-do:  Determine a better way/place to invoke 
$ !                ***         FILE$FIND.COM (versions) as a batch job...
$ !  14-JUL-2016 : Separated V$QStalled into V$BatQStalled and V$DevQStalled.
$ !                Also PIPE through sys$pipe rather than sys$input (idiom change).
$ !                Invent new "cluster quick check" report option.
$ !   1-JUN-2016 : Improve Ctrl/Y trap at SpinLock loop, so we can just
$ !                jump to the Rev$ label if user wants to abort
$ !                the Spawn_FFV at that point.
$ !                Also, PreClean FILE$FINDVERSIONS*.REPORT files, and
$ !                list directory outputs for all new report files created
$ !                this pass (at label Rev$).
$ !  21-APR-2016 : Check VMS version for ANALYZE /ERROR /EVL TRANSLATE;
$ !                fallback to ANALYZE /ERROR for < V7.3.
$ !  21-APR-2016 : Trim blanks from F$GETSYI("VERSION").  Also, reorder
$ !                archives file-lists.
$ !  15-APR-2016 : Add new FILE$FIND.COM (based on FILE$FINDVERSIONS.COM,
$ !                but now also handles scanning for large size files) to
$ !                the backup saveset and zip archive. The earlier
$ !                FILE$FINDVERSIONS.COM is now retired/deprecated, as
$ !                FILE$FIND.COM does all...
$ !                Also minor mods to subroutine Spawn_FFV for this change.
$ !  12-APR-2016 : Added V$QStalled command (pipe to search for
$ !                stalled, stopped or paused queues).
$ !  12-APR-2016 : Fixed a nasty little integer overflow bug in
$ !                DiskSpace routine, and now have moved that
$ !                subroutine into separate file DISKSPACE$REPORT.COM
$ !                so that it can be used independently of VMS$AUDIT.
$ !  12-APR-2016 : Re-order "SHOW MEMORY /FILES" to proximity of
$ !                "DIRECTORY SYS$SYSTEM:*FILES.SYS" for easier
$ !                summary reporting.
$ !  11-APR-2016 : Bug: Missed one ".VERSION_REPORT" into ".REPORT",
$ !                now fixed.
$ !  15-MAR-2016 : Add PARSEC_AUTOGEN.COM to saveset and zip file lists,
$ !                just so that this tool's available.
$ !  03-MAR-2016 : Enable (stich-in) invocation of FILE$FINDVERSIONS.COM --
$ !                always run on a stand-alone VMS system; check configuration
$ !                parameter VA$FFV_Permitted for VMScluster nodes (the node
$ !                must be named in the config-parameter in order to run; this
$ !                limits a run to one/single cluster member; only need one).
$ !                Also uses VA$FFV_Disks to name the disks to be checked
$ !                (comma-separated list of disk/device names), and
$ !                VA$FFV_Version as the max-version to search/report.
$ !  16-FEB-2016 : Swap P2 and P3, make the EXTENDED report option the second
$ !                parameter (more frequent, convenient to use).
$ !                Make VA$FullRpt logic actually work (bug).
$ !  15-FEB-2016 : Add P3 parameter to make certain EXTENDED report components
$ !                optional; other minor tweaks.
$ !  15-JAN-2016 : Add parameters for FTP/Edit/Type to VMS$AUDIT.CONFIG file;
$ !                see VMS$AUDIT_LRICKER.CONFIG and VMS$AUDIT_TEMPLATE.CONFIG
$ !                as exemplars. Also renamed local symbol User to VA$User.
$ !  11-JAN-2016 : Deprecate (remove) the UAF$(QUICK|DETAILED)_ANALYSIS.COM
$ !                invocations -- do these manually as-needed from here on.
$ !                Also some re-orderings of tests and outputs.
$ !                Invented VMS$AUDITCONFIG logical (VMS$AUDIT.CONFIG file)
$ !                and read-mechanism if such file exists; if it does not,
$ !                fallback is to prompt user for VA$User (full name) and
$ !                name of report.
$ !  03-AUG-2015 : Add DIRECTORY SYS$ERRORLOG:ERRLOG.* file check.
$ !  16-JUN-2015 : Summarize sys-errorlog for past 30 days (RSM).
$ !                Remove audit-summary for SYSUAF events.
$ !                Reordered a few report entries; bug fixes.
$ !  29-MAY-2015 : Tweaks to error handling in UAF$QUICK_ANALYSIS.COM
$ !                and UAF$DETAILED_ANALYSIS.COM.
$ !  12-MAY-2015 : Corrected ANALYZE /AUDIT /SELECT=(SYSTEM=name=''P4')
$ !                typo (was /SELECT=(SYSTEM=NODE=''P4)) -- bug!
$ !                Also enhance report disposition with FTP.
$ !  21-APR-2015 : Corrected VMS version check to > v8.3 for use of
$ !                SEARCH /STATISTICS=SYMBOL.
$ !                Also found/fixed a label spelling error, 'pssdict'
$ !                for 'passdict', in UAF$DETAILED_ANALYSIS.COM.
$ !  20-MAR-2015 : Add progress report (wserr) to track ANALYZE /AUDIT
$ !                on really big Security Audit Journal files; these
$ !                can take several minutes (each) to complete on
$ !                production systems which do not manage Audit Journals
$ !                effectively. Also, add /SELECT=SYSTEM=NODE= to constrain
$ !                ANALYZE /AUDIT to *this* node.
$ !  17-MAR-2015 : Add SHOW INTRUSION and ANALYZE /AUDIT /SUMMARY, with
$ !                AnalyzeAudit and FindSAJournal routines.
$ !  16-MAR-2015 : Add UAF$DETAILED_ANALYSIS.COM to Backup and Zip lists.
$ !                Also added invocation of UAF$DETAILED_ANALYSIS.COM
$ !                following generation of SYSUAF /FULL listing.
$ !                Also added DiskSpace display (after SHOW DEV D /MOUNTED).
$ !  12-MAR-2015 : DEASSIGN did not support /[NO]LOG until VMS v7.4,
$ !                so invent V$DEASSIGN to conditionalize.
$ !                Also conditionalize UAF$QUICK_ANALYSIS.COM, as it
$ !                uses both PIPE and SEARCH /STATISTICS=SYMBOL too.
$ !                Fixed one VMSver comparison bug.
$ !  10-MAR-2015 : UTC$TIME_SETUP.COM is intransigent about handling
$ !                redirected SYS$OUTPUT, so kludges are necessary.
$ !                Also now doing PreCleaner of last-run reports;
$ !                full suppression of AUTHORIZE "%UAF-I-LSTMSG" noise.
$ !                Also produces a summary quick-list of report files.
$ !  09-MAR-2015 : Added call to UTC$TIME_SETUP SHOW to check/confirm
$ !                AUTO_DLIGHT_SAV sysgen parameter and timezone logicals.
$ !                Also added display of F$GETSYI("BOOTTIME").
$ !                Also conditionalize use of PIPE command (VMS >= v7.1 only);
$ !                this currently impacts NetInstalled (only), thus limiting
$ !                network detail reporting to >= VMS v7.1.
$ !  12-DEC-2014 : Official re-release, version# updated.
$ !  12-NOV-2014 : Reorganized steps to promote selected summaries to
$ !                the top/front of the report.
$ !  02-SEP-2014 : Added UAF$QUICK_ANALYSIS.COM to report total users,
$ !                total priv'd users, disuser'd users and disuser'd
$ !                priv'd users.
$ !  17-Jul-2014 : Added displays for system's STARTUP command files.
$ !                Improved display of SYSGEN parameters.
$ !                Added dir-listing of LMF$*.LDB files.
$ !  16-Jul-2014 : Correct syntax for NCL's version of "SHOW KNOWN NODES" -->
$ !                "SHOW NODE 0 ROUTING CIRCUIT CSMA-CD ADJACENSY * ALL STATUS".
$ !                Also reordered the NCP and NCL commands for DECnet IV and V.
$ !  24-Jun-2014 : Add AuditStep "TYPE SYS$UPDATE:VMSINSTAL.HISTORY".
$ !                Some file-purge cleanup for BACKUP and ZIP.
$ !  23-Jun-2014 : Add AuditStep "SHOW ERRORS" (lost-in-shuffle!).
$ !                Improve rename-filespec for each SYSUAF.LIS
$ !                to include nodename.
$ !  19-Jun-2014 : Refinements to reporting the SYSUAF, in
$ !                particular, write LIST /FULL and /BRIEF
$ !                reports out to separate .LIS files rather
$ !                than into the main .REPORT; easier to
$ !                search/count/process that way.
$ !  18-Jun-2014 : Add a SHOW QUEUE /FULL step just before
$ !                the QUE$STALLED.COM check; re-ordered the
$ !                VI.a. & g. steps for clarity in review;
$ !                removed ":SS" from VA$TimeStamp (too fussy);
$ !                added BACKUP and RESTORE functions (similar
$ !                to ZIP and UNZIP)
$ !  17-Jun-2014 : Autodetect installed network products,
$ !                don't prompt for them; add Multinet stub;
$ !                cannot auto-drive BOOT_OPTIONS.COM for
$ !                VMS versions < v8.4 (!)
$ !  16-Jun-2014 : Bug fixes; improved ON SEVERE_ERROR handling
$ !                for the Target Command; handle zip/unzip better;
$ !                created/added QUE$STALLED.COM to detect Queues
$ !                with excessive jobs (usually stalled)
$ !  29-May-2014 : Baseline functionality in place
$ !  28-May-2014 : Proof-of-concept; core functions working
$ ! ========================
$ !
$ !
$ !
$AnalyzeAudit:  SUBROUTINE
$ ! P1 = Security Audit Journal filespec (discovered by FindSAJournal)
$ ! P2 = ANALYZE /AUDIT event type
$ ! P3 = Summary type (plot,count)
$ ! P4 = Date for /SINCE
$ ! P5 : Nodename
$ ON CONTROL_Y THEN GOSUB AACtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ AnAudit  = "ANALYZE /AUDIT ''P1' /EVENT_TYPE=(''P2') /SUMMARY=(''P3') /NOINTERACTIVE " -
           + "/SINCE=''P4' /SELECT=(SYSTEM=name=''P5')"
$ AnAtitle = "ANALYZE /AUDIT /EVENT_TYPE=(''P2') /SINCE=''P4'"
$ now      = F$CVTIME("","ABSOLUTE","TIME")
$ wserr F$FAO( "%!AS-I-PROGRESS, [!AS] !AS...", -
               Fac, F$CVTIME("","ABSOLUTE","TIME"), AnAtitle )
$ CALL AuditStep "''AnAudit'" "NOPAGE" "''AnAtitle'"
$ EXIT 1
$ !
$AACtrl_Y:
$ EXIT %X2C
$ ENDSUBROUTINE  ! AnAudit
$ !
$FindSAJournal:  SUBROUTINE
$ ON CONTROL_Y THEN GOSUB FSAJCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ VA$SAJournal == "SYS$MANAGER:SECURITY.AUDIT$JOURNAL"  ! init: best guess...
$ vlist  = "\Destination\Monitoring\"
$ vlistl = F$LENGTH( vlist )
$ jtmp = "SYS$SCRATCH:VMS$AUDIT_SAJ.TMP"
$ SHOW AUDIT /JOURNAL /OUTPUT='jtmp'
$ OPEN /READ /ERROR=FSAJCtrl_Y fj 'jtmp'
$FSAJ0:
$ READ /END_OF_FILE=FSAJ1 fj rec
$ rec = F$EDIT( rec, "TRIM,COMPRESS" ) - ":"
$ tag = F$ELEMENT( 0, " ", rec )
$ val = F$ELEMENT( 1, " ", rec )
$ IF ( F$LOCATE( "\''tag'\", vlist ) .GE. vlistl ) THEN GOTO FSAJ0  ! skip...
$ GOTO FSAJ$'tag'
$FSAJ$Destination:
$ sajou = F$EDIT( val, "COLLAPSE" )  ! provisional... is it also enabled?
$ GOTO FSAJ0
$FSAJ$Monitoring:
$ IF ( val .NES. "enabled" )
$ THEN GOTO FSAJ0                    ! keep looking...
$ ELSE VA$SAJournal == sajou         ! got it
$      GOTO FSAJ1                    !  ...done
$ ENDIF
$FSAJ1:
$ CLOSE /NOLOG fj
$ DELETE /NOLOG 'jtmp';*
$ wso "%''Fac'-I-USING_JOURNAL, VA$SAJournal == ''VA$SAJournal'"
$ EXIT 1
$ !
$FSAJCtrl_Y:
$ EXIT %X2C
$ ENDSUBROUTINE  ! FindSAJournal
$ !
$TimeStamp:  SUBROUTINE
$ ! P1 : timestamp to format (empty "" means "NOW")
$ !
$ ON CONTROL_Y THEN GOSUB TSCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ VA$TimeStamp == "at "  + F$CVTIME(P1,"ABSOLUTE","HOUR")    -
                + ":"    + F$CVTIME(P1,"ABSOLUTE","MINUTE")  -
                + " on " + F$CVTIME(P1,"ABSOLUTE","WEEKDAY") -
                + ", "   + F$CVTIME(P1,"ABSOLUTE","DATE")
$ EXIT 1
$TSCtrl_Y:
$ EXIT %X2C
$ ENDSUBROUTINE  ! TimeStamp
$ !
$NetInstalled:  SUBROUTINE
$ ! P1 : network to detect
$ !      Note: PIPE was added in VMS v7.1 --
$ Sym = P1 - "/"  ! cleanout any punctuation, e.g., "TCP/IP" -> "TCPIP"
$ !
$ PIPE SHOW NET | SEARCH sys$pipe "''P1'" /NOOUTPUT /NOWARNINGS ; netstatus = ( $STATUS .EQS. "%X10000001" )
$ VA$'Sym'Inst == netstatus
$ !! show symbol VA$'Sym'Inst
$ EXIT 1
$ ENDSUBROUTINE  ! NetInstalled
$ !
$CenterLine:  SUBROUTINE
$ ! P1 : text to center
$ !
$ ON CONTROL_Y THEN GOSUB CLCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ P1L = F$LENGTH(P1)
$ Indent = ( VA$PgWi - P1L ) / 2
$ wso F$FAO( "!#* !AS", Indent, P1 )
$ EXIT 1
$CLCtrl_Y:
$ EXIT %X2C
$ ENDSUBROUTINE  ! CenterLine
$ !
$ReportHeader:  SUBROUTINE
$ ! P1 : Facility name
$ ! P2 : Procedure filespec
$ ! P3 : Procedure version
$ ! P4 : Nodename
$ ! P5 : Report date (started)
$ ! P6 : Username (report generator)
$ ! P7 : CLUSTER report-notation
$ !
$ ON CONTROL_Y THEN GOSUB RHCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ wso F$FAO( "!#*=", VA$PgWi )
$ wso ""
$ msg = F$FAO( "!AS -- VMS/OpenVMS Audit Report -- The PARSEC Group", P1 )
$ CALL CenterLine "''msg'"
$ msg = F$FAO( "!AS", P2 )
$ CALL CenterLine "''msg'"
$ msg = F$FAO( "!AS", P3 )
$ CALL CenterLine "''msg'"
$ msg = F$FAO( "Report run on system/node !AS", P4 )
$ CALL CenterLine "''msg'"
$ msg = F$FAO( "VMS version string \!AS\", VMS$ver )
$ CALL CenterLine "''msg'"
$ IF ( P7 .EQS. "CLUSTER" ) THEN CALL CenterLine "and for this VMScluster"
$ msg = F$FAO( "!AS", P5 )
$ CALL CenterLine "''msg'"
$ msg = F$FAO( "by !AS (login: !AS)", P6, F$EDIT(F$GETJPI("","USERNAME"),"TRIM") )
$ CALL CenterLine "''msg'"
$ msg = "''VA$Copyright' by The PARSEC Group.  All rights reserved."
$ CALL CenterLine "''msg'"
$ wso ""
$ wso F$FAO( "!#*=", VA$PgWi )
$ wso ""
$ wso ""
$ EXIT 1
$RHCtrl_Y:
$ EXIT %X2C
$ ENDSUBROUTINE  ! ReportHeader
$ !
$ReportFooter:  SUBROUTINE
$ ! P1 : Facility name
$ ! P2 : Nodename
$ ! P3 : Report date (ended)
$ ! P4 : CLUSTER report-notation
$ !
$ ON CONTROL_Y THEN GOSUB RFCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ wso ""
$ wso VA$DblDashes
$ wso ""
$ msg = F$FAO( "!AS -- End of VMS/OpenVMS Audit Report -- The PARSEC Group", P1 )
$ CALL CenterLine "''msg'"
$ msg = F$FAO( "for system/node !AS", P2 )
$ CALL CenterLine "''msg'"
$ IF ( P4 .EQS. "CLUSTER" ) THEN CALL CenterLine "and for this VMScluster"
$ msg = F$FAO( "!AS", P3 )
$ CALL CenterLine "''msg'"
$ wso ""
$ wso VA$DblDashes
$ EXIT 1
$RFCtrl_Y:
$ EXIT %X2C
$ ENDSUBROUTINE  ! ReportFooter
$ !
$ !
$ !
$Paginate:  SUBROUTINE
$ ! P1 : "NOPAGE" to suppress pagination <FF>
$ !
$ ON CONTROL_Y THEN GOSUB PgCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ IF OutToFile
$ THEN IF ( F$EDIT(F$EXTRACT(0,3,P1),"UPCASE") .EQS. "NOP" )
$      THEN wso ""
$           VA$PgStr == ""
$      ELSE wso ""     ! form-feed, eject page, format and count it
$           VA$PgStr == F$FAO( "page !SL", VA$PgNo )
$           VA$PgNo  == VA$PgNo + 1
$      ENDIF
$ ELSE wso ""
$      VA$PgStr == ""
$ ENDIF
$ EXIT 1
$PgCtrl_Y:
$ EXIT %X2C
$ ENDSUBROUTINE  ! Paginate
$ !
$Header:  SUBROUTINE
$ ! P1: Command text to display in header box
$ ! P2: "NOPAGE" to suppress pagination <FF>
$ !
$ ON CONTROL_Y THEN GOSUB HdrCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ P1L = F$LENGTH(P1)
$ IF ( VA$PgWi .GT. P1L )
$ THEN LPadP1 = ( VA$PgWi - P1L ) / 2
$ ELSE LPadP1 = 1
$ ENDIF
$ CALL TimeStamp ""   ! global VA$TimeStamp
$ TSL = F$LENGTH(VA$TimeStamp)
$ LPadNow = ( VA$PgWi - TSL ) / 2
$ RPadNow = LPadNow
$ IF ( (LPadNow * 2) .LT. (VA$PgWi - TSL) ) THEN RPadNow = RPadNow + 1
$ CALL Paginate "''P2'"
$ wso VA$Dashes
$ wso ""
$ IF OutToFile
$ THEN wso F$FAO( "!#* !AS", LPadP1, P1 )
$ ELSE wso F$FAO( "!#* [4m!AS[0m", LPadP1, P1 )
$ ENDIF
$ wso ""
$ wso F$FAO( "!#* !AS", LPadNow, VA$TimeStamp )
$ IF ( VA$PgStr .NES. "" )
$ THEN wso F$FAO( "!#* !AS", VA$PgWi - F$LENGTH(VA$PgStr) - 1, VA$PgStr )
$ ELSE wso ""
$ ENDIF
$ wso VA$Dashes
$ wso ""
$ wso ""
$ EXIT 1
$HdrCtrl_Y:
$ EXIT %X2C
$ ENDSUBROUTINE  ! Header
$ !
$Footer:  SUBROUTINE
$ ! (no parameters)
$ ON CONTROL_Y THEN GOSUB FtrCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ wso ""
$ wso VA$DblDashes
$ wso ""
$ wso ""
$ EXIT 1
$FtrCtrl_Y:
$ EXIT %X2C
$ ENDSUBROUTINE  ! Footer
$ !
$UAFsetup:  SUBROUTINE
$ ! P1 : Command
$ IF ( F$TRNLNM("SYSUAF","LNM$SYSTEM") .EQS. "" )
$ THEN DEFINE /PROCESS /NOLOG sysuaf     SYS$SYSTEM:SYSUAF.DAT
$      DEFINE /PROCESS /NOLOG rightslist SYS$SYSTEM:RIGHTSLIST.DAT
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! UAFsetup
$ !
$UAFteardown:  SUBROUTINE
$ ! P1 : Command
$ IF ( F$TRNLNM("SYSUAF","LNM$PROCESS") .NES. "" )
$ THEN V$DEASSIGN /PROCESS sysuaf
$      V$DEASSIGN /PROCESS rightslist
$ ENDIF
$ IF ( F$SEARCH("[]SYSUAF.LIS") .NES. "" )
$ THEN ! AUTHORIZE is simplistic about naming LIST files, so fix:
$      IF ( F$LOCATE("/FULL",P1) .LT. F$LENGTH(P1) )
$      THEN ! post AUTH LIST /FULL: detailed analysis
$           RENAME /NOLOG []SYSUAF.LIS 'VA$UAFfull'
$!! deprecated: UAF$DETAILED_ANALYSIS.COM
$!! $           @'DD'UAF$DETAILED_ANALYSIS 'VA$UAFfull'
$      ELSE ! post AUTH LIST /BRIEF: quick analysis
$           RENAME /NOLOG []SYSUAF.LIS 'VA$UAFbrief'
$!! deprecated: UAF$QUICK_ANALYSIS.COM
$!! $           ! Not very modular, but let's do some account analysis here, too:
$!! $           IF ( VMS$ver .GES. "V8.3" ) ! PIPE command in >= VMS v7.1 ...
$!! $                                       ! and SEARCH /STATISTICS=SYMBOL in >= v8.3-1H1
$!! $           THEN @'DD'UAF$QUICK_ANALYSIS 'VA$UAFbrief'
$!! $           ELSE wserr F$FAO( "%!AS-W-OLDVMS, PIPE &/or SEARCH/STAT=SYMBOL unavailable (pre-v!AS)", Fac, "7.1/8.3-1H1" )
$!! $                wserr "-W-NOTRUN, cannot execute @UAF$QUICK_ANALYSIS"
$!! $           ENDIF
$      ENDIF
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! UAFteardown
$ !
$ !
$ !
$AuditStep:  SUBROUTINE
$ ! P1: Command to execute (and put in Header)
$ ! P2: "NOPAGE" to suppress pagination <FF>
$ ! P3: Alternate text for Header (defaults to P1)
$ !
$ ON CONTROL_Y THEN GOSUB ASCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ UAFlag = F$EXTRACT(0,6,P1) .EQS. "V$AUTH"
$ IF ( P3 .EQS. "" ) THEN P3 = P1
$ CALL Header "''P3'" "''P2'"
$ IF Debugging THEN wserr "%''Fac'-I-PROGRESS, ''P3'..."
$ IF OutToFile
$ THEN wso "$ ''P3'"
$ ELSE wso "$ [1m''P3'[0m"
$ ENDIF
$ ON SEVERE_ERROR THEN CONTINUE  ! never say die!
$ IF UAFlag
$ THEN CALL UAFsetup "''P1'"
$      ! and suppress the "%UAF-I-LSTMSG*" noise from AUTHORIZE:
$      DEFINE /USER_MODE sys$output nla0:
$      DEFINE /USER_MODE sys$error  nla0:
$ ENDIF
$ ! ---------
$ 'P1'
$ ! ---------
$ IF UAFlag THEN CALL UAFteardown "''P1'"
$ ON ERROR THEN EXIT %X2C
$ CALL Footer
$ IF ( .NOT. OutToFile )  ! reporting to terminal, interactive...
$ THEN wso ""
$      READ sys$command junk /END_OF_FILE=ASDone -
         /PROMPT="[1m<Ctrl/Z> to quit, <Enter> to continue:[0m "
$ ENDIF
$ EXIT 1
$ASDone:
$ EXIT %X2C
$ASCtrl_Y:
$ EXIT %X2C
$ ENDSUBROUTINE  ! AuditStep
$ !
$PreCleaner:  SUBROUTINE
$ ! P1 : Filespec to clean
$ ON CONTROL_Y THEN GOSUB PClCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ d = DD - "]"
$ IF F$SEARCH("''DD'REPORTS.DIR") .EQS. "" THEN CREATE /DIRECTORY /NOLOG 'd'.REPORTS]
$ IF F$SEARCH(P1) .NES. ""
$ THEN IF F$SEARCH("''P1';-1") .NES. "" THEN PURGE /NOLOG 'P1'
$      RENAME /NOLOG 'P1' 'd'.REPORTS]
$ ENDIF
$ EXIT 1
$ !
$PClCtrl_Y:
$ EXIT %X2C
$ ENDSUBROUTINE  ! PreCleaner
$ !
$Cleaner:  SUBROUTINE
$ ! P1 : Filespec to clean
$ ! P2 : Plug-in name
$ ! P3 : Plug-in filespec
$ !
$ ON CONTROL_Y THEN GOSUB ClCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ IF Debugging THEN wserr "%''Fac'-I-PROGRESS, cleaning ''P3' with ''P2'..."
$ ! Suppress TPU's naturally noisey output --
$ DEFINE /USER_MODE /NOLOG sys$error  nl:
$ DEFINE /USER_MODE /NOLOG sys$output nl:
$ !
$ EDIT /TPU /NODISPLAY /NOSECTION /NOJOURNAL -
    /COMMAND='P3' 'P1'
$ Stat = $STATUS
$ !
$ IF Stat .AND. ( .NOT. Debugging )
$ THEN vn  = F$PARSE(P1,,,"VERSION") - ";"
$      vno = F$INTEGER(vn) - 1
$      PURGE /NOLOG /SINCE=TODAY 'P1'
$      RENAME /NOLOG 'P1' *.*;'vno'
$ ENDIF
$ EXIT 1
$ !
$ClCtrl_Y:
$ EXIT %X2C
$ ENDSUBROUTINE  ! Cleaner
$ !
$ !
$ !
$Quick_Report: SUBROUTINE
$ ! P1 : CLUSTER | REMOTE | QUICK
$ ! P2 : SYSMAN nodes to engage (VA$SysmanNodes)
$ !
$ ON CONTROL_Y THEN GOSUB CRCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ GOTO QR'P1'
$QRCLUSTER:
$ wserr F$FAO( "%!AS-I-NODES, Quick Report for VMScluster...", Fac )
$ env = "/CLUSTER"
$ GOTO QR0
$QRREMOTE:
$ IF ( P2 .EQS. "" ) THEN GOTO QRQUICK  ! empty VA$SysmanNodes list?
$ wserr F$FAO( "%!AS-I-NODES, Quick Report for remote node(s) !AS...", Fac, VA$SysmanNodes )
$ env = "/NODE=(''P2')"
$ GOTO QR0
$QRQUICK:
$ wserr F$FAO( "%!AS-I-NODES, Quick Report for local node !AS...", Fac, Node )
$ env = "/NODE=(''Node')"
$ !
$QR0:
$ CALL ReportHeader "''Fac'" "''Proc'" "''VA$ProcVersion'" "''Node'" "''VA$TimeStamp'" "''VA$User'" "''P1'"
$ !
$ ! Generate a quick-check report for the cluster --
$ !   First are per-node items thru SYSMAN /CLUSTER:
$ IF ( VMS$ver .LES. "V7.0" )
$ THEN ! ---- V6.X up to V7.0 ----
$      ! ---- keep it simple  ----
$ ! ================================================
$      'V$SYSMAN' SET ENVIRONMENT 'env'
SET PROFILE /PRIVILEGES=(SYSNAM,SYSPRV,SECURITY,VOLPRO,OPER)
CONFIGURATION SHOW TIME

DO SHOW SYSTEM /HEADER /NOPROCESS /GRAND_TOTAL
   
DO SHOW NETWORK

DO SHOW ERROR

DO SHOW MEMORY /FILES
DO SHOW MEMORY /PHYSICAL /CACHE
DO SHOW MEMORY /SLOTS /POOL

DO SHOW INTRUSION

EXIT
$ ! ================================================
$ ELSE ! ---- V7.1 and beyond ----
$      ! ---- get fancier     ----
$ ! ================================================
$      'V$SYSMAN' SET ENVIRONMENT 'env'
SET PROFILE /PRIVILEGES=(SYSNAM,SYSPRV,SECURITY,VOLPRO,OPER)
CONFIGURATION SHOW TIME

DO PIPE SHOW SYSTEM /HEADER /NOPROCESS /GRAND_TOTAL -
   ; WRITE sys$output F$FAO("%VMS$AUDIT-I-REBOOT, last reboot on !AS!/", F$GETSYI("BOOTTIME"))
   
DO PIPE SHOW NETWORK -
   ; WRITE sys$output F$FAO("============!/")

DO PIPE SHOW ERROR -
   ; WRITE sys$output F$FAO("============!/")

DO SHOW MEMORY /FILES
DO SHOW MEMORY /PHYSICAL /CACHE
DO PIPE SHOW MEMORY /SLOTS /POOL -
   ; WRITE sys$output F$FAO("============!/")

DO PIPE SHOW INTRUSION -
   ; WRITE sys$output F$FAO("============!/")

EXIT
$ ! ================================================
$ ENDIF
$ !
$ !   Then several items which are done once for whole cluster:
$ IF F$TYPE( QUESTALL$THRESHOLD ) .EQS. "" THEN QUESTALL$THRESHOLD == 500
$ CALL AuditStep "@''DD'QUE$STALLED ''QUESTALL$THRESHOLD' TRUE" "" "@''DD'QUE$STALLED ''QUESTALL$THRESHOLD'"
$ IF ( VMS$ver .GES. "V7.1" )
$ THEN CALL AuditStep "V$BatQStalled" "NOPAGE" "''V$BatQStalled'"
$      CALL AuditStep "V$DevQStalled" "NOPAGE" "''V$DevQStalled'"
$ ENDIF
$ !
$ CALL AuditStep "@''DD'DISKSPACE$REPORT"
$ CALL AuditStep "SHOW DEVICE D /MOUNTED"
$ !
$ CALL TimeStamp ""   ! global VA$TimeStamp
$ CALL ReportFooter "''Fac'" "''Node'" "''VA$TimeStamp'" "''P1'"
$ !
$ EXIT 1
$ !
$CRCtrl_Y:
$ EXIT %X2C
$ ENDSUBROUTINE  !Quick_Report
$ !
$ !
$ !
$Parse: SUBROUTINE
$ ! P1: command to parse
$ ! P2: global symbol to receive answer
$ ! P3: default command
$ ! P4: command set ("C1|C2[|Cn...]") -- options must be same-length fields
$ ! P5: command separator
$ IF P1 .EQS. "" THEN P1 = P3
$ IF P2 .EQS. "" THEN P2 = "Parse$Cmd"
$ IF P5 .EQS. "" THEN P5 = "|"
$ P4 = F$EDIT(P4,"UPCASE")
$ S  = F$LOCATE(P5,P4) + 1               !Determine field length
$ P4 = P5 + P4                           !Add separator to front of list...
$ T  = P5 + F$EDIT(P1,"COLLAPSE,UPCASE") !...and to target
$ L  = F$LOCATE( F$EDIT(T,"COLLAPSE,UPCASE"), P4 )      !Test substring
$ IF ( L .LT. F$LENGTH(P4) ) .AND. ( L-(L/S)*S .EQ. 0 ) !Found?
$ THEN L = ( ( L + 1 ) / S ) + 1                        !Calculate offset
$      'P2' == F$EDIT( F$ELEMENT(L,P5,P4), "COLLAPSE" )
$      EXIT 1
$ ELSE 'P2' == "$Err$"
$      wso "\''P1'\ (expecting: ''F$EDIT(P4,"COLLAPSE")')"
$      EXIT 229522  !%DCL-E-IVVERB, unrecognized command verb
$ ENDIF
$ ENDSUBROUTINE  ! Parse
$ !
$ !
$ ! ========================
$MAIN:                                                           ! 'F$VERIFY(0)'
$ SET CONTROL=(Y,T)
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ VMS$ver == F$EDIT(F$GETSYI("VERSION"),"TRIM")
$ !
$ Proc   = F$ENVIRONMENT("PROCEDURE")
$ Fac    = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ Dir    = F$PARSE(Proc,,,"DIRECTORY","SYNTAX_ONLY")
$ Dev    = F$PARSE(Proc,,,"DEVICE","SYNTAX_ONLY")
$ DD     = Dev + Dir
$ Node   = F$GETSYI("NODENAME")
$ !
$ Debugging = F$TRNLNM("TOOLS$DEBUG")
$ !
$ VA$FullRpt  = "FALSE"  ! initial, can be overridden by VMS$AUDITCONFIG configuration file,
$ !                      ! or "FULL" on the command line
$ VA$QuickRpt = ""
$ !
$ V$AUTH     = "MCR AUTHORIZE"
$ V$LANCP    = "MCR LANCP"
$ V$SYSGEN   = "MCR SYSGEN"
$ V$SYSMAN   = "MCR SYSMAN"
$ V$UTCTIME  = "@SYS$MANAGER:UTC$TIME_SETUP SHOW"
$ V$IFCONFIG = "$SYS$SYSTEM:TCPIP$IFCONFIG"
$ V$NCP      = "MCR NCP"
$ V$NCL      = "MCR NCL"
$ V$DIR      = "DIRECTORY /SIZE /OWNER /DATE /PROTECTION /WIDTH=(FILENAME=20,SIZE=9,OWNER=16)"
$ V$Star     = "*"
$ !
$ VA$FFVreports  = "''DD'FILE$FINDVERSIONS_*.REPORT"
$ VA$FFV_BQue    = "sys$batch"  ! may be overridden by
$ VA$FFV_Version = ";32760"     !   VMS$AUDITCONFIG file
$ !
$ V$BatQStalled  = "PIPE SHOW QUEUE /BATCH /ALL  | SEARCH sys$pipe stopped,stalled,paused"
$ V$DevQStalled  = "PIPE SHOW QUEUE /DEVICE /ALL | SEARCH sys$pipe stopped,stalled,paused"
$ !
$ V$BckSSN   = Fac
$ V$BckList  = "''Fac'.com;" -
             + ",''Fac'_template.config;" -
             + ",''Fac'_boot_options.answers;" -
             + ",''Fac'_*.tpu;" -
             + ",file$find.com;" -
             + ",diskspace$report.com;" -
             + ",que$stalled.com;" -
             + ",uaf$detailed_analysis.com;" -
             + ",uaf$quick_analysis.com;" -
             + ",parsec_autogen.com;" -
             + ",cmd:USERS_*.CO*;" -         ! USERS_(INACTIVE,PASSWORDS).(COM,CONFIG)
             + ",cmd:RESET_ERRORCOUNT.*;" -  ! RESET_ERRORCOUNT.(COM,TMP)
             + ",[.DFU]*.*;"
$ V$ZipArc   = "''Fac'.zip"
$ V$ZipList  = "''Fac'.com" -
             + " ''Fac'_template.config" -
             + " ''Fac'_boot_options.answers" -
             + " ''Fac'_*.tpu" -
             + " file$find.com" -
             + " diskspace$report.com" -
             + " que$stalled.com" -
             + " uaf$detailed_analysis.com" -
             + " uaf$quick_analysis.com" -
             + " parsec_autogen.com" -
             + " cmd:USERS_*.CO*" -         ! USERS_(INACTIVE,PASSWORDS).(COM,CONFIG)
             + " cmd:RESET_ERRORCOUNT.*" -  ! RESET_ERRORCOUNT.(COM,TMP)
             + " [.DFU]*.*"
$ !
$ ! Calculate the first of last month (approx):
$ ago = "-30-"
$ FirstofLastMonth = "1-" -
                   + F$CVTIME( ago, "ABSOLUTE", "MONTH" ) -
                   + "-" + F$CVTIME( ago, "ABSOLUTE", "YEAR" )
$ !
$ IF ( VMS$ver .GES. "V7.4" )
$ THEN V$DEASSIGN = "DEASSIGN /NOLOG"
$ ELSE V$DEASSIGN = "DEASSIGN"  ! /[NO]LOG wasn't implemented prior to 7.4
$ ENDIF
$ !
$ VA$UAFfull      = "''DD'''Fac'_''Node'_SYSUAF_FULL.LIS"
$ VA$UAFbrief     = "''DD'''Fac'_''Node'_SYSUAF_BRIEF.LIS"
$ VA$UTCreport    = "''DD'''Fac'_''Node'_utctime.lis"
$ VA$ClusterMbr   = F$GETSYI("CLUSTER_MEMBER")
$ !
$ ! Default individual node(s) for SYSMAN:
$ VA$SysmanNodes = ""
$ !
$ ! Default targets for FTP file transfer of reports:
$ VA$FTPurl   = "class8.parsec.com"
$ VA$FTPuser  = "lricker"
$ !
$ wso   = "WRITE sys$output"
$ wserr = "WRITE sys$error"
$ !
$ OutToFile = "FALSE"
$ !
$ VA$PgNo      ==  1
$ VA$PgWi      == 78
$ VA$Dashes    == F$FAO( "!#*-", VA$PgWi )
$ VA$DblDashes == F$FAO( "!#*=", VA$PgWi )
$ !
$ !
$ ! ========================
$ ! The default report/output filespec --
$ VA$AuditReport == F$PARSE("''Fac'_''Node'","''Dev'''Dir'.REPORT",,,"SYNTAX_ONLY") - ";"
$ !
$ ! ========================
$ ! Parse the command-line parameters --
$ IF ( P1 .EQS. "?" ) THEN P1 = "HELP"
$ CmdSet = "BRIEF  |" -
         + "FULL   |" -
         + "QUICK  |" -
         + "CLUSTER|" -
         + "REMOTE |" -
         + "TYPE   |" -
         + "EDIT   |" -
         + "BACKUP |" -
         + "RESTORE|" -
         + "ZIP    |" -
         + "UNZIP  |" -
         + "FTP    |" -
         + "CLEANUP|" -
         + "HELP   "
$ CALL Parse "''P1'" Cmd "BRIEF" "''CmdSet'"
$ GOTO 'Cmd'$
$ !
$ ! ========================
$FULL$:  ! Full report
$ VA$FullRpt = "TRUE"
$ GOTO GENERATE$  ! continue with reporting...
$ !
$ ! ========================
$CLUSTER$:
$ VA$AuditReport == F$PARSE("''Fac'_CLUSTER","''Dev'''Dir'.REPORT",,,"SYNTAX_ONLY") - ";"
$ GOTO QUICK$
$REMOTE$:
$ VA$AuditReport == F$PARSE("''Fac'_REMOTE","''Dev'''Dir'.REPORT",,,"SYNTAX_ONLY") - ";"
$QUICK$:
$ VA$QuickRpt = Cmd  ! "QUICK", "CLUSTER" or "REMOTE"
$ GOTO GENERATE$
$ !
$ ! ========================
$BRIEF$:
$GENERATE$:   ! Generate the Audit Report
$ !
$ ! ========================
$ ! Define a global command symbol, just for convenience:
$ IF ( F$TYPE(vmsaudit) .EQS. "" )
$ THEN vmsau*dit == "@''DD'''Fac'"
$      SHOW SYMBOL /GLOBAL vmsaudit
$ ENDIF
$ ! and, if P2 is provided, (re)define the logical name VMS$AUDITCONFIG:
$ IF ( P2 .NES. "" )
$ THEN conf = F$PARSE( P2, "''DD'.CONFIG" )
$      conf = F$SEARCH( conf )
$      IF ( conf .NES. "" )
$      THEN conf = conf- F$PARSE( conf, , , "VERSION", "SYNTAX_ONLY" ) - ";"
$           DEFINE /NOLOG VMS$AUDITCONFIG 'conf'
$           SHOW LOGICAL /FULL VMS$AUDITCONFIG
$      ENDIF
$ ENDIF
$ !
$ ! ========================
$ ! clean up last set of report-files, purge and rename to [.REPORTS] --
$ Call PreCleaner 'VA$AuditReport'
$ Call PreCleaner 'VA$UAFfull'
$ Call PreCleaner 'VA$UAFbrief'
$ Call PreCleaner 'VA$UTCreport'
$ Call PreCleaner 'VA$FFVreports'
$ !
$ CALL TimeStamp ""   ! global VA$TimeStamp
$ !
$ ! ========================
$ ! Process the contents of the VMS$AUDIT Configuration File (VMS$AUDITCONFIG) --
$ ! VMS$AUDITCONFIG is expected to be a process (per-user) logical name,
$ ! or given as P2, but have reasonable fallback default behavior, too:
$ config = F$PARSE("VMS$AUDITCONFIG",P2,"''Dev'''Dir'VMS$AUDIT.CONFIG",,"SYNTAX_ONLY")
$ IF ( F$SEARCH(config) .NES. "" )
$ THEN VA$ConfigFile == config - F$PARSE(config,,,"VERSION","SYNTAX_ONLY")
$ ELSE VA$ConfigFile == ""
$ ENDIF
$ !
$ IF ( VA$ConfigFile .NES. "" )
$ THEN wso F$FAO( "%!AS-I-CONFIG, reading configuration file !AS", Fac, VA$ConfigFile )
$      OPEN /READ /ERROR=VACerror vac 'VA$ConfigFile'
$vacloop:
$      READ /END_OF_FILE=vacloopdone vac line
$      cmd = F$EDIT(line,"UNCOMMENT,COMPRESS")
$      IF ( cmd .NES. "" ) THEN 'cmd'  ! execute config-file lines directly...
$      GOTO vacloop
$vacloopdone:
$ !! $      show symbol /local VA$User
$ !! $      show symbol /local VA$SysmanNodes
$ !! $      show symbol /local VA$Disposition
$ !! $      show symbol /local VA$FTPurl
$ !! $      show symbol /local VA$FTPuser
$ !! $      READ sys$command dummy /PROMPT="<Enter> or <Ctrl/Z>: " /END_OF_FILE=Done
$      ! VMS$AUDIT_*.CONFIG file may either redefine VA$AuditReport, or
$      !   it may just leave the above-calculated value alone...
$      ! In either case, output is redirected here:
$      wso F$FAO( "%!AS-I-OUTPUT, output redirected to !AS", Fac, VA$AuditReport )
$      DEFINE /NOLOG /PROCESS sys$output 'VA$AuditReport'
$      OutToFile = "TRUE"
$      GOTO vaccontinue
$ ELSE wserr F$FAO( "!/%!AS-I-START, [4mVMS Audit Report[0m !AS starting at [1m!AS[0m...!/", Fac, VA$ProcVersion, VA$TimeStamp )
$      READ sys$command VA$User /END_OF_FILE=Done /PROMPT="Enter your full name: "
$      VA$User = F$EDIT(VA$User,"TRIM,COMPRESS")
$ !
$      deffile = VA$AuditReport
$      wso ""
$      wso "  Choices for output file --"
$      wso "    Terminal display: [1m''V$Star'[0m"
$      wso "    [4m''deffile'[0m: <Enter>"
$      wso "    Other file: filename"
$      wso ""
$      READ sys$command Answer /END_OF_FILE=Done /PROMPT="Report output file: "
$      Answer = F$PARSE(Answer,deffile,,"NAME","SYNTAX_ONLY")
$      IF Debugging THEN wserr "%''Fac'-I-OUTFILE, output file: ""''Answer'"""
$      IF ( Answer .NES. V$Star )
$      THEN Answer = F$PARSE(Answer,deffile,,,"SYNTAX_ONLY") - ";"
$           DEFINE /NOLOG /PROCESS sys$output 'Answer'
$           OutToFile = "TRUE"
$           VA$AuditReport == Answer    ! Save output filespec as a global symbol, don't delete it on exit...
$      ! else display just goes to terminal...
$      ENDIF
$ ENDIF
$vaccontinue:
$ CLOSE /NOLOG vac
$ !
$ ! FILE$FIND.COM (versions) is submitted to batch if/only-if
$ !   the VMS$AUDITCONFIG file provides non-null values for
$ !   VA$FFV_Permitted and VA$FFV_Disks:
$ IF ( F$TYPE(VA$FFV_Permitted) .EQS. "STRING" ) .AND. ( F$TYPE(VA$FFV_Disks) .EQS. "STRING" )
$ THEN IF ( VMS$ver .GES. "V7.1" ) .AND. ( VA$FFV_Permitted .NES. "" ) .AND. ( VA$FFV_Disks .NES. "" )
$      THEN ffvnodes = ",''VA$FFV_Permitted',"
$           IF ( F$LOCATE( ",''Node',", ffvnodes ) .LTS. F$LENGTH( ffvnodes ) )
$           THEN SUBMIT /QUEUE='VA$FFV_BQue' /NOTIFY /NOPRINT /KEEP /LOG='DD'FILE$FIND_'Node'.LOG -
                   /PARAMETERS=( "VERSIONS", "''VA$FFV_Disks'", "''VA$FFV_Version'", "NOTYPE" )   -
                   'DD'FILE$FIND
$                VA$FFV_BatchEntry == $ENTRY
$                VA$FFV_BatchQueue == F$EDIT( VA$FFV_BQue, "UPCASE" )
$                wserr F$FAO( "%!AS-S-SUBMITTED, ""FILE$FIND VERSIONS"" submitted on !AS, entry !AS", -
                               Fac, VA$FFV_BatchQueue, VA$FFV_BatchEntry )
$           ENDIF
$      ENDIF
$ ENDIF
$ !
$ ! ========================
$NeedPrv$:
$ NeedPrv = "SYSNAM,SYSPRV,SECURITY,CMKRNL,VOLPRO,BYPASS,OPER"
$ prv = F$SETPRV(NeedPrv)
$ IF .NOT. F$PRIVILEGE(NeedPrv)
$ THEN wso F$FAO( "%!AS-E-INSUFFPRV, requires !AS", Fac, NeedPrv )
$      GOTO Done
$ ENDIF
$ !
$ !
$ ! ========================
$ ! Check for a form of sysman-quick report, do it --
$ IF ( VA$QuickRpt .NES. "" )
$ THEN CALL Quick_Report "''VA$QuickRpt'" "''VA$SysmanNodes'"
$      GOTO CLEAN$
$ ENDIF
$ !
$ ! ========================
$ ! Full Report starts here --
$ !
$ CALL ReportHeader "''Fac'" "''Proc'" "''VA$ProcVersion'" "''Node'" "''VA$TimeStamp'" "''VA$User'" ""
$ !
$ IF ( VMS$ver .GES. "V7.1" )       ! PIPE command in VMS v7.1 and higher...
$ THEN CALL NetInstalled "DECnet"
$      CALL NetInstalled "TCP/IP"
$      CALL NetInstalled "Multinet"
$ ELSE VA$DECnetInst   == "FALSE"   ! ...get no network report details for VMS < v7.1
$      VA$TCPIPInst    == "FALSE"
$      VA$MultinetInst == "FALSE"
$ ENDIF
$ !
$ ! ========================
$ ! I. System Summaries:
$ CALL AuditStep "SHOW SYSTEM /HEADER /NOPROCESS /GRAND_TOTAL" "NOPAGE"
$ wso ""
$ wso F$FAO("!/%!AS-I-REBOOTED, last reboot on !AS", Fac, F$GETSYI("BOOTTIME") )
$ !
$ CALL AuditStep "SHOW NETWORK" "NOPAGE"
$ !
$ ! Special: Review all batch/device/printer/symbiont queues for job-counts exceeding threshold:
$ IF F$TYPE( QUESTALL$THRESHOLD ) .EQS. "" THEN QUESTALL$THRESHOLD == 500
$ CALL AuditStep "@''DD'QUE$STALLED ''QUESTALL$THRESHOLD' TRUE" "" "@''DD'QUE$STALLED ''QUESTALL$THRESHOLD'"
$ IF ( VMS$ver .GES. "V7.1" )
$ THEN CALL AuditStep "V$BatQStalled" "NOPAGE" "''V$BatQStalled'"
$      CALL AuditStep "V$DevQStalled" "NOPAGE" "''V$DevQStalled'"
$ ELSE wserr F$FAO( "%!AS-W-OLDVMS, PIPE unavailable (pre-v!AS)", Fac, "7.1" )
$      wserr "-W-NOTRUN, cannot execute V${Bat,Dev}QStalled commands"
$ ENDIF
$ !
$ CALL AuditStep "@''DD'DISKSPACE$REPORT"
$ !
$ CALL AuditStep "SHOW ERROR"
$ CALL AuditStep "V$DIR SYS$ERRORLOG:ERRLOG.SYS,SYS$ERRORLOG:ERRLOG.OLD*" -
    "NOPAGE" "DIRECTORY SYS$ERRORLOG:ERRLOG.SYS,SYS$ERRORLOG:ERRLOG.OLD*"
$ !
$ IF ( VMS$ver .GES. "V7.3" )
$ THEN elv = "/ELV TRANSLATE "
$ ELSE elv = ""
$ ENDIF
$ CALL AuditStep "ANALYZE /ERROR ''elv'/SUMMARY /SINCE=''FirstofLastMonth' SYS$ERRORLOG:ERRLOG.SYS" -
    "NOPAGE" "ANALYZE /ERROR ''elv'/SUMMARY /SINCE=''FirstofLastMonth'"
$ !
$ CALL AuditStep "SHOW CLUSTER"
$ !
$ CALL AuditStep "SHOW MEMORY /FILES"
$ !
$ CALL AuditStep "V$DIR SYS$SYSTEM:*FILE.SYS;*,*DUMP*.DMP;*" "NOPAGE" "DIRECTORY SYS$SYSTEM:*FILE.SYS,*DUMP*.DMP"
$ !
$ ! System Auditing --
$ CALL AuditStep "SHOW INTRUSION"
$ CALL AuditStep "SHOW AUDIT /ALL" "NOPAGE"
$ CALL FindSAJournal  ! sets global VA$SAJournal
$ !
$ wso ""
$ CALL AnalyzeAudit "''VA$SAJournal'" "BREAKIN" "PLOT"  "''FirstofLastMonth'" "''Node'"
$ CALL AnalyzeAudit "''VA$SAJournal'" "LOGFAIL" "PLOT"  "''FirstofLastMonth'" "''Node'"
$ !! CALL AnalyzeAudit "''VA$SAJournal'" "SYSUAF"  "PLOT"  "''FirstofLastMonth'" "''Node'"
$ CALL AnalyzeAudit "''VA$SAJournal'" "ALL"     "COUNT" "''FirstofLastMonth'" "''Node'"
$ !
$ ! System License Database --
$ CALL AuditStep "V$DIR SYS$SYSTEM:LMF$*.LDB" "NOPAGE" "DIRECTORY SYS$SYSTEM:LMF$*.LDB"
$ !
$ ! User Authorization File/Database --
$ IF ( F$TRNLNM("SYSUAF","LNM$SYSTEM_DIRECTORY") .NES. "" )
$ THEN CALL AuditStep "SHOW LOGICAL /FULL SYSUAF"          ""
$      CALL AuditStep "SHOW LOGICAL /FULL RIGHTSLIST"      "NOPAGE"
$      CALL AuditStep "SHOW LOGICAL /FULL NETPROXY"        "NOPAGE"
$      CALL AuditStep "SHOW LOGICAL /FULL NET$PROXY"       "NOPAGE"
$      CALL AuditStep "SHOW LOGICAL /FULL VMSMAIL_PROFILE" "NOPAGE"
$      CALL AuditStep "V$DIR SYSUAF,RIGHTSLIST"            "NOPAGE" "DIRECTORY SYSUAF,RIGHTSLIST"
$ ELSE CALL AuditStep "V$DIR SYS$SYSTEM:SYSUAF.DAT;*,RIGHTSLIST.DAT;*" "" "DIRECTORY SYS$SYSTEM:SYSUAF,RIGHTSLIST"
$ ENDIF
$ !
$ IF VA$FullRpt
$ THEN CALL AuditStep "V$AUTH LIST * /BRIEF" "NOPAGE" "AUTH LIST * /BRIEF"
$      CALL AuditStep "V$AUTH LIST * /FULL"  ""       "AUTH LIST * /FULL"
$ ENDIF
$ !
$ ! ========================
$ ! II. System Configuration -- Hardware, Storage, Cluster and Shadowing/Controller
$ CALL AuditStep "SHOW DEVICE D /MOUNTED"
$ !
$ CALL AuditStep "SHOW CPU /FULL"
$ CALL AuditStep "SHOW MEMORY /FULL"
$ !
$ ! VI.i. System Disk Protection
$ IF VA$FullRpt THEN Call AuditStep "SHOW DEVICE sys$sysdevice /FULL"
$ !
$ ! II. System Configuration -- Hardware, Storage, Cluster and Shadowing/Controller
$ IF VA$FullRpt THEN CALL AuditStep "SHOW DEVICE"
$ !
$ IF VA$FullRpt
$ THEN ! Full disk-device reports
$Dsk0:
$      dsk = F$DEVICE("*","DISK","GENERIC_DK",0)
$      IF ( dsk .EQS. "" ) THEN GOTO Dsk1  ! done...
$      dskL = F$LENGTH(dsk)
$           ! What other disk-types to exclude here???...
$      IF    ( F$LOCATE("DQ",dsk) .GE. dskL ) -   ! not an optical disk (CD,DVD)...
       .AND. ( F$LOCATE("DN",dsk) .GE. dskL )     ! and not a foreign/network disk...
$      THEN IF ( F$GETDVI(dsk,"MNT") )            ! and it's mounted?
$           THEN CALL AuditStep "SHOW DEVICE ''dsk' /FULL" "NOPAGE"
$           ENDIF
$      ENDIF
$      GOTO Dsk0
$ ENDIF
$Dsk1:
$ !
$ ! ========================
$ ! II.a & b. -- Review of Startup & Shutdown Command Procedures is manual, using a text editor...
$ !
$ IF VA$FullRpt
$ THEN ! II.c -- And display the SYSMAN startup/shutdown groups
$      CALL AuditStep "V$SYSMAN STARTUP SHOW FILE /FULL" ""       "SYSMAN STARTUP SHOW FILE /FULL"
$      CALL AuditStep "V$SYSGEN SHOW /STARTUP"           "NOPAGE" "SYSGEN SHOW /STARTUP"
$      CALL AuditStep "V$DIR SYS$STARTUP:SY*.COM;"       "NOPAGE" "DIRECTORY SYS$STARTUP:SY*.COM;""
$ ENDIF
$ !
$ ! ========================
$ IF VA$FullRpt
$ THEN ! III. OpenVMS -- Version & Patch Levels
$      CALL AuditStep "SHOW SYSTEM /HEADER /NOPROCESS"
$ !
$ ! VMS version must be >= v8.4 to auto-drive BOOT_OPTIONS.COM with an Answer File! --
$      IF ( F$GETSYI("ARCH_NAME") .EQS. "IA64" ) .AND. ( VMS$ver .GES. "v8.4" )
$      THEN ! Answer-file: B 2 (display boot options), D 2 (display device options), E (exit) --
$           AnsFile = "VMS$AUDIT_BOOT_OPTIONS.ANSWERS"
$           CALL AuditStep "@SYS$MANAGER:BOOT_OPTIONS ''Dev'''Dir'''AnsFile'" -
              "NOPAGE" "@BOOT_OPTIONS ''AnsFile'"
$      ENDIF
$ ENDIF
$ !
$ ! ========================
$ IF VA$FullRpt
$ THEN ! IV. Product Review -- Layered Product Licensing, versions/patches
$      CALL AuditStep "V$DIR SYS$SYSTEM:LMF$*.LDB" "" "DIRECTORY SYS$SYSTEM:LMF$*.LDB"
$      CALL AuditStep "SHOW LICENSE" "NOPAGE"
$      CALL AuditStep "SHOW LICENSE /USAGE"
$      CALL AuditStep "PRODUCT SHOW PRODUCT /FULL"
$      CALL AuditStep "PRODUCT SHOW HISTORY /FULL"
$      CALL AuditStep "TYPE SYS$UPDATE:VMSINSTAL.HISTORY"
$ ENDIF
$ !
$ ! IV.d. Application Review -- manual audit, conversations with on-site dev/user/mgmt team
$ !
$ IF VA$FullRpt THEN CALL AuditStep "SHOW QUEUE /FULL *"
$ !
$ ! ========================
$ !
$ ! V. Backup -- manual audit, conversations with on-site dev/mgmt team
$ !
$ ! ========================
$ !
$ ! VI.b. & k. Security -- Audit and Accounting Files
$ CALL AuditStep "SHOW AUDIT"
$ CALL AuditStep "V$DIR SYS$MANAGER:SECURITY*.AUDIT$JOURNAL;*" "NOPAGE" "DIRECTORY SYS$MANAGER:SECURITY*.AUDIT$JOURNAL;*"
$ !
$ ! VI.c. & j. Security -- Accounting
$ CALL AuditStep "SHOW ACCOUNTING"
$ CALL AuditStep "V$DIR SYS$MANAGER:ACCOUNTNG*.DAT;*" "NOPAGE" "DIRECTORY SYS$MANAGER:ACCOUNTNG*.DAT;*"
$ !
$ IF VA$FullRpt
$ THEN ! VI.d. Other System (parameters)
$      CALL AuditStep "V$SYSGEN SHOW /SYS"               ""       "SYSGEN SHOW /SYS"
$      CALL AuditStep "V$SYSGEN SHOW /CLUSTER"           "NOPAGE" "SYSGEN SHOW /CLUSTER"
$      CALL AuditStep "V$SYSGEN SHOW SCS*"               "NOPAGE" "SYSGEN SHOW SCS*"
$      CALL AuditStep "V$SYSGEN SHOW /MAJOR"             "NOPAGE" "SYSGEN SHOW /MAJOR"
$      CALL AuditStep "V$SYSGEN SHOW NISCS*"             "NOPAGE" "SYSGEN SHOW NISCS*"
$      CALL AuditStep "V$SYSGEN SHOW LGI*"               ""       "SYSGEN SHOW LGI*"   ! "/LGI" gets an extra <FF> in wrong place...
$      CALL AuditStep "V$SYSGEN SHOW RMS*"               "NOPAGE" "SYSGEN SHOW RMS*"
$      CALL AuditStep "V$SYSGEN SHOW UAFALTERNATE"       "NOPAGE" "SYSGEN SHOW UAFALTERNATE"
$ ENDIF
$ !
$ IF VA$FullRpt
$ THEN ! Show Daylight/Standard time-change settings:
$      CALL AuditStep "V$SYSGEN SHOW AUTO_DLIGHT_SAV" "" "SYSGEN SHOW AUTO_DLIGHT_SAV"
$      ! Don't actually invoke UTC$TIME_SETUP.COM in the AuditStep, as its SYS$OUTPUT redirection
$      !  handling is intransigent!  Instead, SPAWN it so that output can be captured in file; the
$      !  call to AuditStep just plants another header-line in the top-level report file:
$      CALL AuditStep "!«!»''V$UTCTIME'" "NOPAGE" "''V$UTCTIME'"
$      SPAWN /NOLOG /NOWAIT /OUTPUT='VA$UTCreport' 'V$UTCTIME'
$ ENDIF
$ !
$ ! VI.e. & f. Facility and Policy Audits -- manual audit, conversations with on-site team
$ !
$ ! VI.h. ACL Utilization -- manual audit, conversations with on-site team
$ !
$ ! ========================
$ !
$ ! VII. Network
$ CALL AuditStep "SHOW NETWORK"
$ !
$ CALL AuditStep "V$LANCP SHOW DEVICE"                  ""       "LANCP SHOW DEVICE"
$ CALL AuditStep "V$LANCP SHOW CONFIGURATION"           "NOPAGE" "LANCP SHOW CONFIGURATION"
$ CALL AuditStep "V$LANCP SHOW DEVICE /CHARACTERISTICS" "NOPAGE" "LANCP SHOW DEVICE /CHARACTERISTICS"
$ !
$!! $ wserr ""
$!! $ READ sys$command Answer /END_OF_FILE=Done -
$!!     /PROMPT="Perform TCP/IP Audit Steps (is TCP/IP networking installed & configured) [Y/n]? "
$!! $ Answer = F$PARSE(Answer,"Yes",,"NAME","SYNTAX_ONLY")
$!! $ IF Answer
$ IF VA$FullRpt .AND. VA$TCPIPInst
$ THEN ! VII.a. & c. Network -- IP & DNS (BIND) Configurations
$      CALL AuditStep "TCPIP SHOW VERSION"
$      CALL AuditStep "TCPIP SHOW CONFIGURATION NAME_SERVICE"           "NOPAGE" "BIND (DNS) Configuration"
$      CALL AuditStep "TCPIP SHOW NAME_SERVICE"                         "NOPAGE"
$      CALL AuditStep "TCPIP SHOW CONFIGURATION COMMUNICATION"          "NOPAGE"
$      CALL AuditStep "TCPIP SHOW COMMUNICATION"                        "NOPAGE"
$      CALL AuditStep "TCPIP SHOW CONFIGURATION ENABLE SERVICE"         "NOPAGE"
$      CALL AuditStep "TCPIP SHOW CONFIGURATION ENABLE SERVICE /COMMON" "NOPAGE"
$      CALL AuditStep "TCPIP SHOW SERVICE /FULL /PERMANENT"             "NOPAGE"
$      CALL AuditStep "TCPIP SHOW SERVICE /FULL"                        "NOPAGE"
$      CALL AuditStep "TCPIP SHOW INTERFACE"                            "NOPAGE"
$      CALL AuditStep "V$IFCONFIG -a"                                   "NOPAGE" "IFCONFIG -a"
$      CALL AuditStep "TCPIP SHOW HOST /LOCAL"                          "NOPAGE"
$      CALL AuditStep "TCPIP SHOW ROUTE /PERMANENT"                     "NOPAGE"
$      CALL AuditStep "TCPIP SHOW ROUTE"                                "NOPAGE"
$      CALL AuditStep "TCPIP SHOW PROXY /PERMANENT"                     "NOPAGE"
$      CALL AuditStep "SHOW LOGICAL /SYSTEM /FULL TCPIP$*"              "NOPAGE"
$ ENDIF
$ !
$!! $ wserr ""
$!! $ READ sys$command Answer /END_OF_FILE=Done -
$!!     /PROMPT="Perform DECnet Audit Steps (is DECnet networking installed & configured) [Y/n]? "
$!! $ Answer = F$PARSE(Answer,"Yes",,"NAME","SYNTAX_ONLY")
$!! $ IF Answer
$ IF VA$FullRpt .AND. VA$DECnetInst
$ THEN ! VII.b. Network -- DECnet Configuration
$      DECnetVers = F$GETSYI("DECNET_VERSION")
$      dnv        = F$INTEGER(DECnetVers)
$      dnvstr     = F$EXTRACT(3,1,DECnetVers) + "." + F$EXTRACT(4,2,DECnetVers)
$      VA$DECnet  == F$FAO( "DECnet for OpenVMS Version !AS", dnvstr )
$      CALL AuditStep "WRITE sys$output VA$DECnet"  "" "''VA$DECnet'"
$      IF ( dnv .GE. 50000 ) THEN GOTO PhaseV
$PhaseIV:
$      CALL AuditStep "V$NCP SHOW EXECUTOR CHARACTERISTICS" "NOPAGE" "NCP SHOW EXECUTOR CHARACTERISTICS"
$      CALL AuditStep "V$NCP SHOW KNOWN NODES"              "NOPAGE" "NCP SHOW KNOWN NODES"
$      CALL AuditStep "V$NCP LIST KNOWN NODES"              "NOPAGE" "NCP LIST KNOWN NODES"
$      CALL AuditStep "V$NCP SHOW KNOWN OBJECTS"            "NOPAGE" "NCP SHOW KNOWN OBJECTS"
$      CALL AuditStep "V$NCP LIST KNOWN OBJECTS"            "NOPAGE" "NCP LIST KNOWN OBJECTS"
$      GOTO DNDone
$PhaseV:
$      CALL AuditStep "V$NCL SHOW NODE 0 ROUTING CIRCUIT CSMACD-0 ADJACENCY * ALL STATUS" -
                        "NOPAGE" "NCL SHOW NODE 0 ROUTING CIRCUIT CSMACD-0 ADJACENCY * ALL STATUS"
$      CALL AuditStep "V$NCL SHOW ROUTING CIRCUIT CSMACD-0 ALL"       "NOPAGE" "NCL SHOW ROUTING CIRCUIT CSMACD-0 ALL"
$      CALL AuditStep "V$NCL SHOW ALL IDENTIFIERS"                    "NOPAGE" "NCL SHOW ALL IDENTIFIERS"
$      CALL AuditStep "V$NCL SHOW SESSION CONTROL ALL STATUS"         "NOPAGE" "NCL SHOW SESSION CONTROL ALL STATUS"
$      CALL AuditStep "V$NCL SHOW ROUTING ALL CHARACTERISTICS"        "NOPAGE" "NCL SHOW ROUTING ALL CHARACTERISTICS"
$      CALL AuditStep "V$NCL SHOW SESSION CONTROL APPLICATION * NAME" "NOPAGE" "NCL SHOW SESSION CONTROL APPLICATION * NAME"
$DNDone:
$      CONTINUE
$ ENDIF
$ !
$ IF VA$FullRpt .AND. VA$MultinetInst
$ THEN ! VII.b. Network -- Multinet Configuration
$      ! «» CALL AuditStep "V$MNET SHOW «»" "«»" "MULTINET SHOW «»"
$ ENDIF
$ !
$ ! VII.d. & e. Security Policy & Network Topology (printout)) -- manual audit, conversations with on-site network team
$ !
$ ! ========================
$ !
$ ! VIII.a. Other: Monitoring Utilities -- manual audit, conversations with on-site network team
$ !
$ ! ========================
$ ! Done...
$ CALL TimeStamp ""   ! global VA$TimeStamp
$ CALL ReportFooter "''Fac'" "''Node'" "''VA$TimeStamp'" ""
$ !
$ ! ...and fall-through to Clean-up Report:
$ !
$ !
$ ! ========================
$CLEAN$:  ! Clean-up Report...
$ ! Convert embedded <CR><LF> to new-lines, then trim-trailing...
$ IF OutToFile
$ THEN V$DEASSIGN /PROCESS sys$output
$      CleanCRLF = "REPLACECRLF"
$      CleanTrim = "TRIMTRAIL"
$      fsCRLF    = F$PARSE("''Fac'_''CleanCRLF'","''DD'.TPU",,,"SYNTAX_ONLY")
$      fsTrim    = F$PARSE("''Fac'_''CleanTrim'","''DD'.TPU",,,"SYNTAX_ONLY")
$      IF ( F$SEARCH(fsTrim) .EQS. "" ) .OR. ( F$SEARCH(fsCRLF) .EQS. "" )
$      THEN msg = "%!AS-E-FNF, missing one or both report cleaning components:!/" -
                + "!#* !AS &/or !AS"
$           wserr F$FAO( msg, Fac, 18, CleanTrim, CleanCRLF )
$           GOTO Done
$      ELSE ! <CR><LF> -> newlines first, then trim trailing...
$           CALL Cleaner "''VA$AuditReport'" "''CleanCRLF'" "''fsCRLF'"
$           CALL Cleaner "''VA$AuditReport'" "''CleanTrim'" "''fsTrim'"
$      ENDIF
$ ENDIF
$ !
$ GOTO REVIEW$
$ !
$ !
$ ! ========================
$BACKUP$:
$ BACKUP /LIST='V$BckSSN' /NOCRC /GROUP_SIZE=0 /INTERCHANGE -
    'V$BckList' 'V$BckSSN'.BCK /SAVE_SET
$ TYPE 'V$BckSSN'.LIS
$ PURGE /NOLOG 'V$BckSSN'.BCK,.LIS
$ DIRECTORY /SIZE /DATE /PROT 'V$BckSSN'
$ GOTO Done
$ !
$RESTORE$:
$ V$BckSSN = V$BckSSN + ".BCK"
$ IF ( F$SEARCH("''V$BckSSN'") .NES. "" )
$ THEN BACKUP /LOG 'V$BckSSN' /SAVE_SET []*.* /NOREPLACE /LOG
$ ELSE wserr F$FAO( "%!AS-E-FNF, cannot find file !AS", V$BckSSN )
$ ENDIF
$ GOTO Done
$ !
$ ! ========================
$ !
$ZIP$:    ! Zip the VMS$AUDIT files into the archive 'V$ZipArc'
$ IF F$TYPE(zip) .NES. "STRING"
$ THEN DEFINE /PROCESS /NOLOG ZDIR 'DD',SYS$SYSTEM
$      zipexe = F$SEARCH("ZDIR:ZIP.EXE")
$      IF ( zipexe .NES. "" )
$      THEN zip == "$''zipexe'"
$           GOTO GoodZip
$      ELSE wserr F$FAO( "%!AS-E-FNF, zip utility !AS is not available", Fac, "ZIP.EXE" )
$           GOTO Done
$      ENDIF
$ ELSE GOTO GoodZip
$ ENDIF
$GoodZip:
$ IF ( F$SEARCH(V$ZipArc) .NES. "" ) THEN RENAME 'V$ZipArc' 'V$ZipArc'_OLD
$ zip -v 'V$ZipArc' 'V$ZipList'
$ IF ( F$SEARCH("''V$ZipArc'_OLD;-1") .NES. "" ) THEN PURGE /NOLOG 'V$ZipArc'_OLD
$ GOTO Done
$ !
$UNZIP$:    ! UnZip the archive 'V$ZipArc' into the current directory
$ IF F$TYPE(unzip) .NES. "STRING"
$ THEN DEFINE /PROCESS /NOLOG ZDIR 'DD',SYS$SYSTEM
$      unzipexe = F$SEARCH("ZDIR:UNZIP.EXE")
$      IF ( unzipexe .NES. "" )
$      THEN unzip == "$''unzipexe'"
$           GOTO GoodUnZip
$      ELSE wserr F$FAO( "%!AS-E-FNF, unzip utility !AS is not available", Fac, "UNZIP.EXE" )
$           GOTO Done
$      ENDIF
$ ELSE GOTO GoodUnZip
$ ENDIF
$GoodUnZip:
$ DEFINE /USER_MODE sys$input sys$command   ! unzip goes interactive...
$ unzip 'V$ZipArc'
$ GOTO Done
$ !
$ !
$ ! ========================
$REVIEW$:   ! Review the Audit Report File
$ IF OutToFile THEN V$DEASSIGN /PROCESS sys$output
$ tyr*eport == "TYPE ''VA$AuditReport'"  ! handy for reviewing "this" report again
$ SHOW SYMBOL /GLOBAL tyreport
$ !
$ msg = "=== " + Fac + " reports "
$ len = VA$PgWi - F$LENGTH( msg )
$ wso F$FAO( "!/!AS !#*=", msg, len )
$ V$DIR /SINCE /SIZE=ALL 'VA$AuditReport';0
$ IF ( F$SEARCH(VA$FFVreports) .NES. "" ) THEN V$DIR /SINCE /SIZE=ALL 'VA$FFVreports';0
$ IF ( F$SEARCH(VA$UAFfull)    .NES. "" ) THEN V$DIR /SINCE /SIZE=ALL 'VA$UAFfull';0
$ IF ( F$SEARCH(VA$UAFbrief)   .NES. "" ) THEN V$DIR /SINCE /SIZE=ALL 'VA$UAFbrief';0
$ IF ( F$SEARCH(VA$UTCreport)  .NES. "" ) THEN V$DIR /SINCE /SIZE=ALL 'VA$UTCreport';0
$ IF ( VA$ConfigFile .EQS. "" )
$ THEN wso ""
$      Rfile = F$PARSE(VA$AuditReport,,,"NAME","SYNTAX_ONLY") + F$PARSE(VA$AuditReport,,,"TYPE","SYNTAX_ONLY")
$      READ sys$command Answer /END_OF_FILE=Done -
         /PROMPT="''Rfile' -- FTP, Type or Edit it [F/t/e]? "
$      VA$Disposition = F$PARSE(Answer,"FTP",,"NAME","SYNTAX_ONLY")
$ ! ELSE : using VA$Disposition from VMS$AUDIT_*.CONFIG file
$ ENDIF
$ GOTO 'F$EXTRACT(0,1,VA$Disposition)'$
$ !
$F$:    ! FTP Audit Report File to home-base (PARSEC)
$FTP$:
$ DEFINE /USER_MODE sys$input sys$command
$ FTP 'VA$FTPurl' /USER='VA$FTPuser'
$ GOTO Done
$T$:    ! Type/display Audit Report File
$TYPE$:
$ IF OutToFile THEN V$DEASSIGN /PROCESS sys$output
$ DEFINE /USER_MODE sys$input sys$command
$ TYPE /PAGE=SAVE=5 'VA$AuditReport'
$ GOTO Done
$ !
$E$:    ! Edit Audit Report File
$EDIT$:
$ IF OutToFile THEN V$DEASSIGN /PROCESS sys$output
$ IF F$TYPE(ked) .EQS. "STRING" THEN edit = "@com:ked.com"  !(LMR tweak, all others use EDIT /EVE)
$ DEFINE /USER_MODE sys$input sys$command
$ EDIT 'VA$AuditReport'
$ GOTO Done
$ !
$ !
$ ! ========================
$Done:
$ wso ""
$ wso F$FAO( "%!AS-I-DONE, cleanup...", Fac )
$ wso ""
$DoneQuiet:
$ SET NOON
$ !
$ IF OutToFile THEN V$DEASSIGN /PROCESS sys$output
$ !
$ IF F$TYPE(prv)             .NES. "" THEN prv = F$SETPRV(prv)
$ IF F$TYPE(VA$SAJournal)    .NES. "" THEN DELETE /SYMBOL /GLOBAL VA$SAJournal
$ IF F$TYPE(VA$DECnetInst)   .NES. "" THEN DELETE /SYMBOL /GLOBAL VA$DECnetInst
$ IF F$TYPE(VA$TCPIPInst)    .NES. "" THEN DELETE /SYMBOL /GLOBAL VA$TCPIPInst
$ IF F$TYPE(VA$MultinetInst) .NES. "" THEN DELETE /SYMBOL /GLOBAL VA$MultinetInst
$ IF F$TYPE(VA$PgNo)         .NES. "" THEN DELETE /SYMBOL /GLOBAL VA$PgNo
$ IF F$TYPE(VA$PgWi)         .NES. "" THEN DELETE /SYMBOL /GLOBAL VA$PgWi
$ IF F$TYPE(VA$PgStr)        .NES. "" THEN DELETE /SYMBOL /GLOBAL VA$PgStr
$ IF F$TYPE(VA$TimeStamp)    .NES. "" THEN DELETE /SYMBOL /GLOBAL VA$TimeStamp
$ IF F$TYPE(VA$DECnet)       .NES. "" THEN DELETE /SYMBOL /GLOBAL VA$DECnet
$ IF F$TYPE(VA$Dashes)       .NES. "" THEN DELETE /SYMBOL /GLOBAL VA$Dashes
$ IF F$TYPE(VA$DblDashes)    .NES. "" THEN DELETE /SYMBOL /GLOBAL VA$DblDashes
$ IF F$TYPE(VMS$ver)         .NES. "" THEN DELETE /SYMBOL /GLOBAL VMS$ver
$ ! Note: Do *not* delete global symbols VMSAU*DIT, VA$AuditReport or VA$ConfigFile --
$ !       once defined, used as user-login conveniences.
$ EXIT 1  ! 'F$VERIFY(0)'
$ !
$VACerror:
$ CLOSE /NOLOG vac
$ werr F$FAO( "%!AS-E-FNF, file not found: !AS", Fac, VA$ConfigFile )
$ EXIT %X2C  ! 'F$VERIFY(0)'
$ !
$Ctrl_Y:
$ EXIT %X2C  ! 'F$VERIFY(0)'
$ !
$ !
$ ! ========================
$H$:
$HELP$:
$ TYPE /PAGE sys$input
  use:  $ [1m@VMS$AUDIT [ BRIEF (D) | EXTENDED 
                       | QUICK   | CLUSTER | REMOTE
                       | TYPE    | EDIT
                       | BACKUP  | RESTORE
                       | ZIP     | UNZIP
                       | FTP     | CLEANUP | HELP ]
                     [ VMS$AUDITCONFIG_filespec ][0m

  where: [1mP1[0m -- Audit action, see below.

         [1mP2[0m -- File-spec for the VMS$AUDIT configuration file, which defaults
               to the logical name "VMS$AUDITCONFIG".

        [1mBRIEF[0m    -- Generates the VMS$AUDIT Brief Report.
        [1mFULL[0m     -- Generates the VMS$AUDIT Full Report, which contains all
                    of the Brief Report, plus: brief and full listings of the
                    SYSUAF; SHOW DEVICE and SHOW DEVICE /FULL Disk; Startup
                    command file directories and SYSMAN STARTUP SHOW FILE;
                    BOOT_OPTIONS output for Integrity; SHOW LICENSE and
                    PRODUCT SHOW PRODUCT/HISTORY; SHOW QUEUE /FULL; selected
                    SYSGEN SHOW *; UTC Time-Change report; networks: TCP/IP
                    or MultiNet configuration information (if available);
                    and DECnet configuration information (if available).

        [1mQUICK[0m    -- Generates a Quick Report for the current system/node.
        [1mCLUSTER[0m  -- Generates a Quick Report for the entire VMScluster.
        [1mREMOTE[0m   -- Generates a Quick Report for a remote system/node.

        [1mTYPE[0m     -- Reviews the current Audit Report File using the
                    TYPE /PAGE command, with the ability to scroll
                    back/forward several pages at a time.

        [1mEDIT[0m     -- Reviews the current Audit Report File using your
                    favorite VMS text editor, such as EVE, KED, EDT,
                    etc.  The file is opened in RW (read/write) mode,
                    so you can modify the Report if you want; change
                    the editor's file buffer mode to RO (read only),
                    and/or exit correctly if you don't want to change
                    the file accidentally.

        [1mBACKUP[0m   -- Backup and restore will save or restore all file
        [1mRESTORE[0m     components to/from a saveset called VMS$AUDIT.BCK.

        [1mZIP[0m      -- If the utilities ZIP.EXE and UNZIP.EXE are available
        [1mUNZIP[0m       on the system (unsupported, but often found in the
                    SYS$SYSTEM directory), these command options will
                    zip/unzip all VMS$AUDIT file components into a
                    VMS$AUDIT.ZIP archive into/from the current directory.

        [1mFTP[0m      -- Autoconnects an FTP session for a remote FTP-server
                    and username (user's login password must always be
                    manually entered).  The FTP-server URL and username
                    can be set in the VMS$AUDITCONFIG configuration file.

        [1mCLEANUP[0m  -- Certain of the system administration DCL commands used
                    togenerate the Audit Report File embed literal <CR><LF>
                    and trailing-space characters, which can be confuse the
                    displaywhen the Report is opened in a text editor.  This
                    CLEANUP step uses two TPU command scripts, REPLACECRLF
                    and TRIMTRAIL, to replace any <CR><LF> characters with
                    newline and to trim any trailing spaces from all lines.
                    This step is idempotent (can be run multiple times).

        [1mHELP (?)[0m -- Displays this help text.  "HELP" and "?" are equivalent.
        
  [4mDescription[0m:  [1mVMS$AUDIT.COM[0m is an Audit Report Generator for VMS (OpenVMS).
  It provides convenient reporting consistency when auditing multiple systems
  and sites, generating a standardized, paginated and labeled report format
  for review and analysis.  It provides the following functions:
  
    a) Generate an Audit Report, either to file or to the user's terminal.
    b) Review an Audit Report, using either the TYPE /PAGE facility or the
       user's favorite text editor (EVE, KED, etc.).

  [4mInstallation[0m: This is a very compact suite of files, with no "software
  to install" (e.g., PRODUCT or VMSINSTAL).  The files are: VMS$AUDIT.COM
  (this command file), QUE$STALLED.COM (checks VMS queues for job-counts in
  excess of a threshold), VMS$AUDIT_{REPLACECRLF,TRIMTRAIL}.TPU (the two TPU
  cleanup scripts), and VMS$AUDIT_BOOT_OPTIONS.ANSWERS (a text-answer file).

  All VMS$AUDIT files can be backed-up into a BACKUP save-set, VMS$AUDIT.BCK,
  or zipped into an archive, VMS$AUDIT.ZIP, either of which can be FTP'd (scp,
  etc.) in binary mode, and restored into an appropriate directory on a target
  VMS system.  Other than the actual Audit Report File(s), VMS$AUDIT leaves no
  file-litter (temp-files) behind, and the Report File itself is created by
  default into the directory from which VMS$AUDIT is run (invoked).  It is
  self-contained and tidy.

  [4mUse[0m: You must either be logged-in as SYSTEM, or have the following privileges
  authorized for your VMS account:
    [1mSETPRV[0m [4mor[0m [1mSYSNAM, SYSPRV, SECURITY, CMKRNL, BYPASS, VOLPRO, OPER[0m

  When generating an Audit Report, you are first prompted for your full name,
  which is used in the Report's header information for accountability.  Next,
  you are asked for the Report's filename; the default is
      [1mVMS$AUDIT_<nodename>.REPORT[0m
  Alternatively, you may display the Report directly on-screen (in this case,
  no Report File is saved), which is useful for debugging the command file
  itself.
  
$ GOTO DoneQuiet
$ !
