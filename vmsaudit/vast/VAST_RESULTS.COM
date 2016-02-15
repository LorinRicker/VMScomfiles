$ ! VAST_RESULTS.COM --                                           'F$VERIFY(0)'
$ !
$ !  Report the results for this (sub)checklist --
$ !     @VAST_RESULTS
$ !
$ ! Copyright (C) 2012-2013 Lorin Ricker <lorin@rickernet.us>
$ ! Version: 2.0, 05/17/2013
$ !
$ ! This program is free software, under the terms and conditions of the
$ ! GNU General Public License published by the Free Software Foundation.
$ !
$ ! ======== SYS$OUTPUT Report Output Routines ========
$ ! --------
$WOUTtop:  SUBROUTINE
$ wso F$FAO( "!/  Results for Checklist Step !AS on system !AS!/!AS", -
             MajorStep, AUD$Node, HRul )
$ EXIT 1
$ ENDSUBROUTINE  ! WOUTtop
$ ! --------
$ !
$ ! --------
$WOUTdata:  SUBROUTINE
$ ! P1 : AUD$MaxDescrL (passed as a string)
$ ! P2 : step
$ ! P3 : description
$ ! P4 : result (of test)
$ maxdl = F$INTEGER(P1)
$ wso F$FAO( "!4* !AS: !#AS - !AS", P2, maxdl, P3, P4 )
$ EXIT 1
$ ENDSUBROUTINE  ! WOUTdata
$ ! --------
$ !
$ ! --------
$WOUTsummary:  SUBROUTINE
$ ! P1 : Fac
$ ! P2 : AUD$Node
$ ! P3 : PassFail
$ ! P4 : MajorStep
$ ! P5 : MajorName
$ EXIT 1
$ wso F$FAO( "!AS", HRul )
$ wso F$FAO( "%!AS-I-SUMMARY, system !AS [4m!AS[0m for Checklist !AS. !AS", -
             P1, P2, P3, P4, P5 )
$ wso F$FAO( "!AS!/", HRul )
$ ENDSUBROUTINE  ! WOUTsummary
$ ! --------
$ !
$WOUTnyi:  SUBROUTINE
$ wso P1
$ EXIT 1
$ ENDSUBROUTINE  ! WOUTnyi
$ ! --------
$ !
$ !
$ ! ======== CSV-File Report Output Routines ========
$ ! --------
$WCSVtop:  SUBROUTINE
$ ! This report-top uses (mostly) global symbols "AUD$*"
$ wcsvf "''SEP'VMS System Audit Checklist"  ! Report title in column-2
$ wcsvf F$FAO( "!2(AS)", SEP, AUD$Banner )
$ wcsvf F$FAO( "!3(AS)", "System", SEP, AUD$Node )
$ wcsvf F$FAO( "!3(AS) at !AS", -
               "Audited on", SEP, AUD$Today, AUD$Started )
$ wcsvf F$FAO( "!3(AS) (as user !AS)", -
               "Audited by", SEP, AUD$Auditors, AUD$UName )
$ nclen = F$LENGTH(AUD$NoComment)
$ IF F$EXTRACT(0,nclen,AUD$Comment1) .NES. AUD$NoComment -
  THEN wcsvf F$FAO( "!2(AS)", SEP, AUD$Comment1 )
$ IF F$EXTRACT(0,nclen,AUD$Comment2) .NES. AUD$NoComment -
  THEN wcsvf F$FAO( "!2(AS)", SEP, AUD$Comment2 )
$ wcsvf ""   ! write separate record; F$FAO's "!/" produces literal "<CR><LF>" chars
$ wcsvf F$FAO( "!3(AS)", "Build Plan", SEP, AUD$BPTitle )
$ wcsvf F$FAO( "!2(AS)", SEP, AUD$BPSubTitle )
$ wcsvf F$FAO( "!2(AS)", SEP, AUD$BPURLTitle )
$ wcsvf F$FAO( "!2(AS)", SEP, AUD$BPURL )
$ wcsvf ""   ! write separate record; F$FAO's "!/" produces literal "<CR><LF>" chars
$ wcsvf F$FAO( "!7(AS)", -
               "Step", SEP, "Description", SEP, "Accept/Reject", SEP, "BP Section" )
$ EXIT 1
$ ENDSUBROUTINE  ! WCSVtop
$ ! --------
$ !
$ ! --------
$WCSVpar:  SUBROUTINE
$ ! P1 : MajorStep
$ ! P2 : MajorName
$ wcsvf ""       ! write separate record; F$FAO's "!/" produces literal "<CR><LF>" chars
$ Msg = F$FAO( "Checklist !AS.", P1 )
$ wcsvf F$FAO( "!3(AS)", Msg, SEP, P2 )
$ EXIT 1
$ ENDSUBROUTINE  ! WCSVpar
$ ! --------
$ !
$ ! --------
$WCSVdata:  SUBROUTINE
$ ! P1 : step
$ ! P2 : description
$ ! P3 : result (of test)
$ ! P4 : bpsect (build plan section)
$ wcsvf F$FAO( "!7(AS)", P1, SEP, P2, SEP, P3, SEP, P4 )
$ EXIT 1
$ ENDSUBROUTINE  ! WCSVdata
$ ! --------
$ !
$ ! --------
$WCSVsummary:  SUBROUTINE
$ ! P1 : Fac
$ ! P2 : PassFail
$ ! P3 : MajorStep
$ ! P4 : MajorName
$ wcsvf F$FAO( "!AS%!AS-I-SUMMARY, !AS for Checklist !AS. !AS", -
                SEP, P1, P2, P3, P4 )
$ !             ^-- Put this summary in 2nd-column of spreadsheet
$ EXIT 1
$ ENDSUBROUTINE  ! WCSVsummary
$ ! --------
$ !
$ ! --------
$WCSVnyi:  SUBROUTINE
$ wcsvf ""       ! write separate record; F$FAO's "!/" produces literal "<CR><LF>" chars
$ wcsvf F$FAO( "!2(AS)", SEP, P1 )  !...into 2nd-column
$ EXIT 1
$ ENDSUBROUTINE  ! WCSVnyi
$ ! --------
$ !
$ !
$ ! ======== HTML-File Report Output Routines ========
$ ! --------
$AugmentAuthors:  SUBROUTINE
$ ! P1 : author name
$ alen = F$LENGTH(AUD$Authors)
$ IF F$LOCATE(P1,AUD$Authors) .GE. alen
$ THEN AUD$Authors == AUD$Authors + ", " + P1
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! AugmentAuthors
$ ! --------
$ !
$ ! --------
$WHTMLtop:  SUBROUTINE
$ ! This report-top uses (mostly) global symbols "AUD$*"
$ !
$ whtmlf "<!DOCTYPE html>"
$ whtmlf "<html xmlns=""http://www.w3.org/1999/xhtml"" lang=""en"">
$ whtmlf "<head>"
$ whtmlf "<meta http-equiv=""content-type"" content=""text/html;charset=""UTF-8"" />"
$ ! Easter Egg: Augment *metadata* for each report with names of ASS contributors/developers, too:
$ AUD$Authors == AUD$Auditors
$ CALL AugmentAuthors "Lorin Ricker"
$ CALL AugmentAuthors "Tom Griesan"
$ CALL AugmentAuthors "John Apps"
$ CALL AugmentAuthors "Rick Williams"
$ whtmlf F$FAO( "<meta name=""author"" content=""!AS"" />", AUD$Authors )
$ whtmlf F$FAO( "<meta name=""description"" content=""DTV/DTS VMS Audit System Report for !AS, on !AS at !AS"" />", -
                AUD$Node, AUD$Today, AUD$Started )
$ whtmlf F$FAO( "<meta name=""keywords"" content=""!AS, !AS, !AS, !AS, !AS, !AS, !AS"" />", -
                "Audit", "System", "Report", "VMS", "DTS", AUD$Node, AUD$Arch )
$ !
$ ! Add-in a CSS style-sheet spec:
$ whtmlf "<style type=""text/css"">
$ whtmlf "body {"
$ whtmlf "  background:#FFFFFF;"
$ whtmlf "  margin:0px;"
$ whtmlf "  padding:10px 80px;"
$ whtmlf "  font:x-small Arial;"
$ whtmlf "  text-align:left;"
$ whtmlf "  color:black;"
$ whtmlf "  color:#000000;"
$ whtmlf "  font-size:11pt;"
$ whtmlf "  }"
$ whtmlf "hr {"
$ whtmlf "  border: 1;"
$ whtmlf "  height: 1px;"
$ whtmlf "  width: 100%;"
$ whtmlf "  color: #000000;"             ! Some browsers respond to hr's "color"...
$ whtmlf "  background-color: #000000;"  ! while others respond to "background-color"!
$ whtmlf "  }"
$ whtmlf "</style>"
$ whtmlf "<title>DTV/DTS VMS System Audit</title>"
$ whtmlf "</head>"
$ whtmlf ""
$ !
$ ! Open the body section...
$ whtmlf "<body>"
$ whtmlf "<h1>VMS System Audit Checklist</h1>"
$ whtmlf F$FAO( "<h2>!AS</h2>", AUD$Banner )
$ whtmlf "<table border=""0"" cellspacing=""1"" cellpadding=""0"">"
$ whtmlf F$FAO( "<tr><td align=""right"">!AS</td><td><font size=""+1""><b>!AS</b></font></td></tr>", -
                "System&nbsp;", AUD$Node )
$ whtmlf F$FAO( "<tr><td align=""right"">!AS</td><td>!AS at !AS</td></tr>", -
                "Audited on&nbsp;", AUD$Today, AUD$Started )
$ whtmlf F$FAO( "<tr><td align=""right"">!AS</td><td>!AS (as user !AS)</td></tr>", -
                "Audited by&nbsp;", AUD$Auditors, AUD$UName )
$ nclen = F$LENGTH(AUD$NoComment)
$ IF F$EXTRACT(0,nclen,AUD$Comment1) .NES. AUD$NoComment -
  THEN whtmlf F$FAO( "<tr><td>!AS</td><td>!AS</td></tr>", -
                     "&nbsp;", AUD$Comment1 )
$ IF F$EXTRACT(0,nclen,AUD$Comment2) .NES. AUD$NoComment -
  THEN whtmlf F$FAO( "<tr><td>!AS</td><td>!AS</td></tr>", -
                     "&nbsp;", AUD$Comment2 )
$ whtmlf F$FAO( "<tr><td align=""right"">!AS</td><td><em>!AS</em></td></tr>", -
                "Build Plan:&nbsp;", AUD$BPTitle )
$ whtmlf F$FAO( "<tr><td>!AS</td><td><em>!AS</em></td></tr>", -
                "&nbsp;", AUD$BPSubTitle )
$ whtmlf F$FAO( "<tr><td>!AS</td><td><a href=""!AS"">!AS</a></td></tr>", -
                "&nbsp;", AUD$BPURL, AUD$BPURLTitle )
$ whtmlf "</table>"
$ whtmlf ""
$ !!«» whtmlf "<br/>"
$ whtmlf "<hr />"
$ whtmlf ""
$ !
$ ! This opens the table for the test/step results...
$ whtmlf "<table border=""0"" cellspacing=""3"" cellpadding=""0"">"
$ whtmlf F$FAO( "<tr><th align=""left""><em>!AS</em> <th align=""left""><em>!AS</em> <th align=""left""><em>!AS</em> <th align=""left""><em>!AS</em> </th></tr>", -
                "Step", "Description", "Accept/Reject", "BP Section" )
$ EXIT 1
$ ENDSUBROUTINE  ! WHTMLtop
$ ! --------
$ !
$ ! --------
$WHTMLpar:  SUBROUTINE
$ ! P1 : MajorStep
$ ! P2 : MajorName
$ whtmlf ""
$ whtmlf "<tr><td colspan=""4"">&nbsp;</td></tr>"  ! separator-gap
$ whtmlf F$FAO( "<tr><td>!AS</td> <td colspan=""4""><b>Checklist !AS. !AS</b></td></tr>", -
                "&nbsp;", P1, P2 )
$ EXIT 1
$ ENDSUBROUTINE  ! WHTMLpar
$ ! --------
$ !
$ ! --------
$WHTMLdata:  SUBROUTINE
$ ! P1 : step
$ ! P2 : description
$ ! P3 : result (of test)
$ ! P4 : bpsect (build plan section)
$ w1 = "width=""5%"" align=""right"""
$ w2 = "width=""65%"""
$ w3 = "width=""10%"""
$ w4 = "width=""20%"""
$ rescolor = ltyellow  ! for everything except ACCEPT and REJECT
$ testres  = F$EDIT(P3,"UPCASE,TRIM")
$ IF testres .EQS. "REJECT"
$ THEN rescolor = ltred
$ ELSE IF testres .EQS. "ACCEPT"
$      THEN rescolor = ltgreen
$      ENDIF
$ ENDIF
$ result = F$FAO( "<td bgcolor=""!AS"" align=""center"" !AS><b>!AS</b></td>", -
                  rescolor, w3, P3 )
$ whtmlf F$FAO( "<tr><td !AS>!AS</td> <td !AS>!AS</td>", -
                w1, P1, w2, P2 )
$ whtmlf F$FAO( "  !AS", result )
$ whtmlf F$FAO( "  <td !AS>!AS</td> </tr>", w4, P4 )
$ EXIT 1
$ ENDSUBROUTINE  ! WHTMLdata
$ ! --------
$ !
$ ! --------
$WHTMLsummary:  SUBROUTINE
$ ! P1 : Fac
$ ! P2 : PassFail
$ ! P3 : MajorStep
$ ! P4 : MajorName
$ rescolor = white  ! for everything except PASS and FAIL
$ testres  = F$EXTRACT(0,4,F$EDIT(P2,"UPCASE,TRIM"))
$ IF testres .EQS. "FAIL"
$ THEN rescolor = ltred
$ ELSE IF testres .EQS. "PASS"
$      THEN rescolor = ltgreen
$      ENDIF
$ ENDIF
$ msg = F$FAO( "%!AS-I-SUMMARY, !AS for Checklist !AS. !AS", -
               P1, P2, P3, P4 )
$ whtmlf F$FAO( "<tr><td></td> <td colspan=""3"" bgcolor=""!AS"">!AS</td></tr>", -
                rescolor, msg )
$ EXIT 1
$ ENDSUBROUTINE  ! WHTMLsummary
$ ! --------
$ !
$ ! --------
$WHTMLnyi:  SUBROUTINE
$ whtmlf ""
$ whtmlf "<tr><td colspan=""4"">&nbsp;</td></tr>"  ! separator-gap
$ whtmlf F$FAO( "<tr><td></td> <td colspan=""3"" bgcolor=""!AS"">!AS</td>", -
                ltyellow, P1 )
$ EXIT 1
$ ENDSUBROUTINE  ! WHTMLnyi
$ ! --------
$ !
$ !
$ ! --------
$AccumulateStat:  SUBROUTINE
$ ! P1 : test result
$ ! P2 : major category
$ IF P1 .EQS. Accept THEN AUDIT$Cntr_'P2'_Accepts == AUDIT$Cntr_'P2'_Accepts + 1
$ IF P1 .EQS. Reject THEN AUDIT$Cntr_'P2'_Rejects == AUDIT$Cntr_'P2'_Rejects + 1
$ IF P1 .EQS. Skip   THEN AUDIT$Cntr_'P2'_Skips   == AUDIT$Cntr_'P2'_Skips + 1
$ AUDIT$Cntr_'P2'_Tests == AUDIT$Cntr_'P2'_Tests + 1
$ EXIT 1
$ ENDSUBROUTINE  ! AccumulateStat
$ ! --------
$ !
$ ! === Main ===
$Main:
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ IF Debugging
$ THEN wserr F$FAO( "!/%!AS-I-REMEXE, remote execution from !AS", Fac, AUD$NodeAcc )
$      wserr F$FAO( "%!AS-I-REPORTS, writing report files...!/", Fac )
$ ENDIF
$ !
$ IF F$TYPE(AUD$WriteRpts) .EQS. "" THEN AUD$WriteRpts == 0     ! assume "nope" to begin with...
$ !
$ SubDirName = "REPORTS"
$ IF AUD$GenRpts         ! okay to generate CSV-report file(s)?
$ THEN ! DoShared creates global symbol AUD$RptDir
$      DoShared CheckAndCreateSubDir "''SubDirName'"
$      AUD$WriteRpts == $STATUS
$ ENDIF
$ !
$ atReportTop = ( F$INTEGER(MajorStep) .EQ. 0 )
$ !
$ IF ( F$TYPE(AUD$CSVname) .EQS. "" ) .OR. ( F$TYPE(AUD$HTMLname) .EQS. "" )
$ THEN mon = F$ELEMENT(0,SLASH,AUD$Today)
$      day = F$ELEMENT(1,SLASH,AUD$Today)
$      yr  = F$ELEMENT(2,SLASH,AUD$Today)
$      rfname  = "AUDITREPORT$" + yr + DASH + mon + DASH + day + DASH + AUD$Node
$      CSVname  = rfname + ".CSV"
$      HTMLname = rfname + ".HTML"
$      ! FileSpecDQ creates four global symbols: 'P3', 'P3'DQ, 'P4' and 'P4'DQ
$      DoShared FileSpecDQ "''SubDirName'" "''CSVname'"  "AUD$RptDir" "AUD$CSVname"
$      DoShared FileSpecDQ "''SubDirName'" "''HTMLname'" "AUD$RptDir" "AUD$HTMLname"
$ ENDIF
$ !
$ IF AUD$WriteRpts
$ THEN IF atReportTop
$      THEN OPEN /WRITE /ERROR=OpenWrtErr csvf 'AUD$CSVname'   !new file...
$           statusCSVf = $STATUS
$           OPEN /WRITE /ERROR=OpenWrtErr htmlf 'AUD$HTMLname'
$           statusHTMLf = $STATUS
$      ELSE OPEN /APPEND /ERROR=OpenAppErr csvf 'AUD$CSVname'  !append existing...
$           statusCSVf = $STATUS
$           OPEN /APPEND /ERROR=OpenAppErr htmlf 'AUD$HTMLname'
$           statusHTMLf = $STATUS
$      ENDIF
$ ENDIF
$ !
$ SET NOON
$ ClrScrn
$ !
$ ! AUD$Results is the global result string:
$ IF AUD$Results .NES. ""  ! If no results, checklist is NYI...
$ THEN CALL WOUTtop        ! otherwise, report:
$      IF AUD$WriteRpts
$      THEN IF atReportTop
$           THEN CALL WCSVtop
$                CALL WHTMLtop
$           ENDIF
$           CALL WCSVpar  "''MajorStep'" "''MajorName'"
$           CALL WHTMLpar "''MajorStep'" "''MajorName'"
$      ENDIF
$      RejectCnt = 0
$      j = 0
$DL0:
$      result = F$ELEMENT(j,SEP,AUD$Results)
$      IF result .EQS. SEP THEN GOTO DL1
$      bpsect = F$ELEMENT(j,SEP,AUD$BPSections)
$      step   = F$ELEMENT(0,BSLASH,result)
$      descr  = F$ELEMENT(1,BSLASH,result)
$      result = F$ELEMENT(2,BSLASH,result)
$ !
$      CALL AccumulateStat "''result'" "TOTAL"
$      CALL AccumulateStat "''result'" "''MajorCat'"
$      IF result .EQS. Reject THEN RejectCnt = RejectCnt + 1
$ !
$      IF AUD$MaxDescrL .LT. 16 THEN AUD$MaxDescrL == 16
$      CALL WOUTdata "''AUD$MaxDescrL'" "''step'" "''descr'" "''result'"
$      IF AUD$WriteRpts
$      THEN CALL WCSVdata  "''step'" "''descr'" "''result'" "''bpsect'"
$           CALL WHTMLdata "''step'" "''descr'" "''result'" "''bpsect'"
$      ENDIF
$      j = j + 1
$      GOTO DL0
$DL1:
$      IF RejectCnt .EQ. 0
$      THEN PassFail = "PASSES all tests"
$      ELSE PassFail = F$FAO( "FAILS !SL test!%S", RejectCnt )
$      ENDIF
$      CALL WOUTsummary "''Fac'" "''AUD$Node'" "''PassFail'" "''MajorStep'" "''MajorName'"
$      IF AUD$WriteRpts
$      THEN CALL WCSVsummary  "''Fac'" "''PassFail'" "''MajorStep'" "''MajorName'"
$           CALL WHTMLsummary "''Fac'" "''PassFail'" "''MajorStep'" "''MajorName'"
$      ENDIF
$ ELSE ! No results -- this checklist is NYI (not yet implemented)...
$      Msg = F$FAO( "%!AS-W-NYI, no results for Checklist !AS. !AS (not yet implemented)", -
                    Fac, MajorStep, MajorName )
$      CALL WOUTnyi "''Msg'"
$      IF AUD$WriteRpts
$      THEN CALL WCSVnyi  "''Msg'"
$           CALL WHTMLnyi "''Msg'"
$      ENDIF
$ ENDIF
$ !
$Done:
$ IF F$TYPE(statusCSVf) .NES. ""
$ THEN CLOSE csvf
$      DELETE /SYMBOL /LOCAL statusCSVf
$      PURGE /NOLOG /KEEP=2 'AUD$CSVname'
$ ENDIF
$ IF F$TYPE(statusHTMLf) .NES. ""
$ THEN CLOSE htmlf  !...don't purge yet!
$      DELETE /SYMBOL /LOCAL statusHTMLf
$ ENDIF
$ EXIT %X1
$ !
$OpenWrtErr:
$ wserr F$FAO( "%!AS-F-OPENWRITERR, cannot open ""!AS"" for writing (step !AS)", -
               Fac, rfname, MajorStep )
$ EXIT %X2C
$ !
$OpenAppErr:
$ wserr F$FAO( "%!AS-F-OPENAPPNDERR, cannot open ""!AS"" for appending (step !AS)", -
               Fac, rfname, MajorStep )
$ EXIT %X2C
$ !
$Ctrl_Y:
$ RETURN %X2C
