$ ! VAST_SYSTEM.COM --                                            'F$VERIFY(0)'
$ !
$ !  use: @VAST_SYSTEM [ start_at_checklist_N ]
$ !
$ !  A wrapper for execution of all VAST_*_*.COM scripts...
$ !
$ ! Copyright (C) 2012-2013 Lorin Ricker <lorin@rickernet.us>
$ ! Version: 2.0, 05/17/2013
$ !
$ ! This program is free software, under the terms and conditions of the
$ ! GNU General Public License published by the Free Software Foundation.
$ !
$ ! -----
$ReadComment:  SUBROUTINE
$ ! P1 : Comment #
$ ! P2 : Maximum comment length (string)
$ comlen = F$INTEGER(P2)
$ wso F$FAO( "!/Enter Comment#!AS (of 2, maximum of !SL characters each) --", P1, comlen )
$ wso F$FAO( "!1AS:[                                                ]", P1 )
$ READ sys$command cstring /END_OF_FILE=RCDone /PROMPT=" : "
$ IF cstring .NES. ""
$ THEN AUD$Comment'P1' == cstring
$ ELSE AUD$Comment'P1' == F$FAO( "!AS !1AS. No comment", AUD$NoComment, P1 )
$ ENDIF
$ IF Debugging THEN wserr F$FAO( "  Comment!1AS: `!#AS`", P1, comlen, AUD$Comment'P1' )
$ EXIT 1
$ !
$RCDone:
$ EXIT %X2C
$ ENDSUBROUTINE  ! ReadComment
$ !
$ ! -----
$TryNetworkTime:  SUBROUTINE
$ ! Because all DTS Test/Release systems use "fake time" to control various aspects of
$ ! application/environment testing (that is, the VMS time is *never* the correct "real"
$ ! time), this routine reaches out to a DECnet task object, using a non-privileged proxy
$ ! (no embedded password!) to get the "real/true" network clock time from a reference node
$ ! (e.g., MCCS00, which lives in Suwanee, Georgia, but carries a MST7/MDT6 Mountain/Colorado
$ ! timezone!).
$ !
$ !  P1 : remote system providing the task=task_showtime object
$ !  P2 : hour-adjustment between domestic timezones, e.g., Eastern to Mountain
$ !
$ ON CONTROL_Y THEN GOSUB TNTCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ IF P1 .EQS. ""
$ THEN P1 = "MCCS00"
$      P2 = ""  ! no TZ-offset
$ ENDIF
$ !
$ wso F$FAO( "!/%!AS-I-GETNETTIME, fetching network time from !AS...", Fac, P1 )
$ timetmp = "SYS$DISK:[]AUD$time_temp.tmp"
$ !
$ taskline = "''P1'""''AUD$ROproxy'""::""task=task_showtime"""
$ TYPE /OUTPUT='timetmp' 'taskline'
$ OPEN /READ /ERROR=TNTOpenErr tmp 'timetmp'
$ READ /END_OF_FILE=TNTclose tmp line   ! need first line only...
$ IF Debugging THEN wserr F$FAO( "%!AS-I-NETTIME, task_showtime: ""!AS""", Fac, line )
$ line = F$EDIT(line,"TRIM")  ! remove leading space for " 1-JAN-..." etc.
$ VMStoday = F$EDIT(F$ELEMENT(0,BANG,line),"TRIM")
$ today    = F$FAO( "!AS!AS!AS!AS!AS", -
                    F$CVTIME(VMStoday,"COMPARISON","MONTH"), -
                    SLASH, F$CVTIME(VMStoday,"COMPARISON","DAY"), -
                    SLASH, F$CVTIME(VMStoday,"COMPARISON","YEAR") )
$ started = F$EXTRACT(0,5,F$ELEMENT(1,SPC,line))  !just the HH:MM parts
$ IF P2 .NES. ""
$ THEN hour = F$ELEMENT(0,COLON,started)
$      minu = F$ELEMENT(1,COLON,started)
$      h = F$INTEGER(hour) + F$INTEGER(P2)
$      IF h .LT. 0
$      THEN h = h + 24
$      ELSE IF h .GE. 24
$           THEN h = h - 24
$           ENDIF
$      ENDIF
$      started = F$FAO( "!2ZL:!AS", h, minu )
$ ENDIF
$ AUD$Today     == today
$ AUD$Started   == started
$ AUD$TimeStamp == F$CVTIME(VMStoday,"COMPARISON","DATE") + SPC + started
$TNTclose:
$ IF F$TRNLNM("tmp") .NES. "" THEN CLOSE /DISPOSITION=DELETE tmp
$ EXIT 1
$ !
$TNTOpenErr:
$ wserr F$FAO( "%!AS-E-OPENERR, error opening !AS for reading network time", Fac, timetmp )
$ GOTO TNTclose
$ !
$TNTCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! TryNetworkTime
$ ! -----
$ !
$ ! -----
$ ! ===== Statistics =====
$InitStatCounters:  SUBROUTINE
$ ! Initialize statistics counters:
$ j = 0
$ ! Major Categories in alphabetical order, except TOTAL last!...
$ AUDIT$ajorCats == "ACMSGEN,APPLICATION,DECNET,HARDWARE,SOFTWARE,SYSGEN,TCPIP,VMS,TOTAL"
$INI0:
$ cat = F$ELEMENT(j,COMMA,AUDIT$MajorCats)
$ IF cat .EQS. COMMA THEN GOTO INI1
$ AUDIT$Cntr_'cat'_Accepts == 0
$ AUDIT$Cntr_'cat'_Rejects == 0
$ AUDIT$Cntr_'cat'_Skips   == 0
$ AUDIT$Cntr_'cat'_Tests   == 0
$ j = j + 1
$ GOTO INI0
$INI1:
$ EXIT 1
$ ENDSUBROUTINE  ! InitStatCounters
$ ! -----
$ !
$ !
$ ! === Main ===
$Main:
$ SET CONTROL=(Y,T)             ! might be running from /FLAGS=RESTRICTED account
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Debugging = F$TRNLNM("TOOLS$DEBUG")
$ !
$ Proc  = F$ENVIRONMENT("PROCEDURE")
$ Fac   = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ wso   = "WRITE sys$output"
$ wserr = "WRITE sys$error"
$ !
$ DQUOTE = """"
$ !
$ AUD$ROproxy == "DTSAUDITSYS"
$ AUD$Node    == F$EDIT(F$GETSYI("NODENAME"),"UPCASE,TRIM")
$ AUD$NodeAcc == F$PARSE(Proc,,,"NODE","SYNTAX_ONLY")  ! remote access string NODE"access"::
$ AUD$Dev     == F$PARSE(Proc,,,"DEVICE","SYNTAX_ONLY")
$ AUD$Dir     == F$PARSE(Proc,,,"DIRECTORY","SYNTAX_ONLY")
$ AUD$dd      == AUD$Dev + AUD$Dir
$ !
$ ! ===== Where are we executing from?... =====
$ ! If P1 is null, then we're doing a regular remote-execution audit (with all script and data
$ ! files on the sourcing remote node MCCS00).  If P1 is specified, then just execute a test
$ ! audit using locally-stored scripts on "this" node:
$ IF P1 .EQS. ""
$ THEN chklstno = "00"
$      AUD$RNode == F$ELEMENT(0,DQUOTE,AUD$NodeAcc)  ! remote nodename
$      AUD$ACStr == F$ELEMENT(1,DQUOTE,AUD$NodeAcc)  ! access control string
$      ! Manufacture double-DQUOTEd string for substitutions -- MCCS00"acc":: -> MCCS00""acc""::
$      AUD$NodeAccDQ == AUD$RNode + DQUOTE + DQUOTE + AUD$ACStr + DQUOTE + DQUOTE + "::"
$      IF Debugging THEN wserr F$FAO( "%!AS-I-REMOTE, executing scripts from !AS", Fac, AUD$RNode )
$ ELSE IF F$LENGTH(P1) .EQ. 1
$      THEN chklstno = "0" + P1
$      ELSE chklstno = P1
$      ENDIF
$      ! No access control string (or double-DQUOTE-ing) needed:
$      AUD$RNode     == AUD$Node  ! remote nodename
$      AUD$ACStr     == ""        ! access control string
$      AUD$NodeAcc   == AUD$Node + "::"
$      AUD$NodeAccDQ == AUD$NodeAcc
$      IF Debugging THEN wserr F$FAO( "%!AS-I-LOCAL, executing scripts from !AS", Fac, AUD$Node )
$ ENDIF
$ AUD$PathAcc     == AUD$NodeAcc + AUD$dd
$ AUD$PathAccDQ   == AUD$NodeAccDQ + AUD$dd
$ AUD$IncludeFile == AUD$PathAcc + "VAST_INCLUDE.COM"
$ !
$ IF Debugging THEN wserr F$FAO( "%!AS-I-INCLUDE, include file: !AS", Fac, AUD$IncludeFile )
$ GOSUB INCLUDE
$ !
$ CALL InitStatCounters
$ !
$ ! DTS type: compute cluster/node role; i.e., "R1BB10" is "BB", "R4FE11" is "FE"
$ IF ( F$EXTRACT(0,1,AUD$Node) .EQS. "R" ) -
  .AND. ( F$LOCATE(F$EXTRACT(1,1,AUD$Node),"12345") .LT. 5 )
$ THEN AUD$DTStype == F$EXTRACT(2,2,AUD$Node)
$ ELSE AUD$DTStype == SPLAT
$ ENDIF
$ ! Record stat is "VALID  " by default, but non-DTS systems generate test-records:
$ IF ( F$EXTRACT(0,1,AUD$Node) .NES. "R" ) .OR. Debugging
$ THEN AUD$RecStat == "TEST   "  ! fixed-length: 7 chars
$ ENDIF
$ !
$ AUD$Fac == Fac  ! save this top Fac name
$ !
$ ! ===== Banner =====
$ ! Edit/increment AUD$Version in VAST_INCLUDE.COM --
$ ClrScrn
$ indent = ( 80 - F$LENGTH(AUD$Banner) + 1 ) / 2
$ wso F$FAO( "!AS!/!#* [1m!AS[0m!/!AS", DHRul, indent, AUD$Banner, DHRul )
$ indent = ( 80 - F$LENGTH(AUD$BPTitle) + 1 ) / 2
$ wso F$FAO( "!#* !AS", indent, AUD$BPTitle )
$ indent = ( 80 - F$LENGTH(AUD$BPSubTitle) + 1 ) / 2
$ wso F$FAO( "!#* !AS!/!AS!/", indent, AUD$BPSubTitle, HRul )
$ ! =====
$ !
$ ! ===== Build Plan Docs =====
$ wso F$FAO( "!/%!AS-I-BUILDPLAN, reference: ""[1m!AS[0m""", Fac, AUD$BPURLTitle )
$ READ sys$command Answer /END_OF_FILE=Done -
    /PROMPT="Do you want to see URL/access to the Build Plan (yes/NO)? "
$ Answer = F$PARSE(Answer,"NO",,"NAME","SYNTAX_ONLY")
$ IF Answer
$ THEN wso F$FAO( "!/%!AS-I-URL, the link to the current Build Plan is:!/[4m!AS[0m!/", -
                  Fac, AUD$BPURL )
$ ENDIF
$ !
$ ! ===== Username & Auditors =====
$ Msg  = F$FAO( "%!AS-I-USERNAME, ", Fac )
$ MsgL = F$LENGTH(Msg)
$ wso F$FAO( "!ASyou are logged-in as user [4m!AS[0m", Msg, AUD$UName )
$ wso F$FAO( "!/Enter the name(s) of the individual(s) performing this audit --" )
$ wso F$FAO( "  (e.g., ""Jan Smith"" or ""Jan Smith, Sam Jones"") --" )
$ READ sys$command nstring /END_OF_FILE=Done -
    /PROMPT=": "
$ IF nstring .NES. ""
$ THEN AUD$Auditors == nstring
$ ELSE AUD$Auditors == AUD$UName
$ ENDIF
$ wso F$FAO( "!/!ASauditing as [4m!AS[0m", Msg, AUD$Auditors )
$ !
$ ! ===== Comments (1 & 2) =====
$ MaxCommentLen = 48  ! see VAST_STATS.COM, esp. STATS-DATA RECORD FORMAT at file-end...
$ CALL ReadComment "1" "''MaxCommentLen'"
$ CALL ReadComment "2" "''MaxCommentLen'"
$ !
$ ! ===== Audit Date/Time Stamp =====
$ ! Logged in as SYSTEM on a DTS cluster?
$ isDTSsys = ( F$EXTRACT(0,1,AUD$Node) .EQS. "R" )  ! R1SB? R2ET? ...etc.
$ IF isDTSsys
$ THEN ! Adjust HH:MM by two hours (timezones): Eastern to Mountain
$      CALL TryNetworkTime "MCCS00"
$ ENDIF
$ !
$ Msg  = F$FAO( "%!AS-I-TIMECHECK, ", Fac )
$ MsgL = F$LENGTH(Msg)
$ wso F$FAO( "!/!AS[1m!AS[0m shows the current system time as: [4m!AS !AS[0m", -
             Msg, AUD$Node, AUD$Today, AUD$Started )
$ IF isDTSsys THEN -
  wso F$FAO( "!#* but DTS Systems use ""fake time,"" not ""real"" date/time.", MsgL )
$ wso F$FAO( "!/Press <Enter> to accept the displayed system time above," )
$ READ sys$command tstring /END_OF_FILE=Done -
    /PROMPT="[4mor[0m enter today's actual date/time (""MM/DD/YYYY HH:MM""): "
$ IF tstring .NES. ""
$ THEN elem0 = F$ELEMENT(0,SPC,tstring)
$      elem1 = F$ELEMENT(1,SPC,tstring)
$      IF F$LOCATE(COLON,elem0) .LT. F$LENGTH(elem0)  ! ":" found?
$      THEN AUD$Started == elem0  !time
$           AUD$Today   == elem1  !date
$      ELSE AUD$Today   == elem0  !oops... swapped
$           AUD$Started == elem1
$      ENDIF
$      AUD$TimeStamp == F$ELEMENT(2,SLASH,AUD$Today) -
                      + DASH + F$ELEMENT(0,SLASH,AUD$Today) -
                      + DASH + F$ELEMENT(1,SLASH,AUD$Today) -
                      + SPC + AUD$Started
$ ! otherwise, just use AUD$Today and AUD$Started as calculated from F$TIME()...
$ ENDIF
$ wso F$FAO( "!/!ASusing DateTime-Stamp [4m!AS !AS[0m (!AS)", -
             Msg, AUD$Today, AUD$Started, AUD$TimeStamp )
$ !
$ IF chklstno .EQS. "00"
$ THEN wso F$FAO( "!/!AS!/%!AS-I-CHECKLIST, starting Full Checklist for !AS system !AS...!/!AS", -
                  DHRul, AUD$Fac, AUD$Arch, AUD$Node, DHRul )
$      AUD$GenRpts == 1
$ ELSE wso F$FAO( "!/!AS!/%!AS-I-CHECKLIST, starting at Checklist !AS for !AS system !AS...!/!AS", -
                  DHRul, AUD$Fac, chklstno, AUD$Arch, AUD$Node, DHRul )
$      AUD$GenRpts == 0
$ ENDIF
$ !
$ ! ===== Audit-SubChecklist processing loop =====
$AS0:
$ Comf = F$SEARCH("''AUD$NodeAccDQ'VAST_%%_*.COM;0")
$ IF Comf .EQS. "" THEN GOTO AS1
$ Comfn = F$PARSE(Comf,,,"NAME","SYNTAX_ONLY")
$ cfno  = F$ELEMENT(0,UNDERL,F$ELEMENT(1,DOLLAR,Comfn))
$ IF cfno .LTS. chklstno THEN GOTO AS0  ! Skip-to/Start at requested checklist-#
$ IF Debugging THEN wserr F$FAO( "%!AS-I-REMEXE, executing !AS", Fac, Comf )
$ !
$ READ sys$command junk /END_OF_FILE=Done -
    /PROMPT="Press [1m<Enter>[0m when ready to execute Checklist ''Comfn': "
$ !
$ @'Comf'
$ wso F$FAO( "!AS!/", DHRul )
$ !
$ GOTO AS0
$ ! ==============================================
$ !
$AS1:
$ IF AUD$WriteRpts
$ THEN OPEN /APPEND /ERROR=OpenAppErr htmlf 'AUD$HTMLname'  !...one last time
$      statusHTMLf = $STATUS
$      whtmlf ""
$      whtmlf "</table>"    ! finalize closing tags...
$      whtmlf "</body>"
$      whtmlf "</html>"
$      IF F$TYPE(statusHTMLf) .NES. ""
$      THEN CLOSE htmlf
$           DELETE /SYMBOL /LOCAL statusHTMLf
$      ENDIF
$      PURGE /NOLOG /KEEP=2 'AUD$HTMLname'
$ ENDIF
$ !
$Done:
$ ON CONTROL THEN GOTO AllDone
$ ON ERROR THEN GOTO AllDone
$ indent = ( 80 - F$LENGTH(AUD$Banner) + 1 ) / 2
$ wso F$FAO( "!AS!/!#* [1m!AS[0m", DHRul, indent, AUD$Banner )
$ sumtitle = "Reports and Summary Files"
$ indent = ( 80 - F$LENGTH(sumtitle) + 1 ) / 2
$ wso F$FAO( "!#* !AS!/!AS", indent, sumtitle, DHRul )
$ !
$ @'AUD$NodeAcc'VAST_PUBLISH "''AUD$HTMLnameDQ'" "«?website?»"
$ @'AUD$NodeAcc'VAST_PUBLISH "''AUD$CSVnameDQ'"  "«?sharepoint?»"
$ !
$ @'AUD$NodeAcc'VAST_STATS
$ !
$AllDone:
$ SET NOON
$ finaltitle = F$FAO( "Audit System run for !AS complete", AUD$Node )
$ indent = ( 80 - F$LENGTH(finaltitle) + 1 ) / 2
$ wso F$FAO( "!/!#* !AS!/!AS!/!/", indent, finaltitle, DHRul )
$ !
$ @'AUD$NodeAcc'VAST_CLEANEXIT
$ !
$ EXIT %X1
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ ! ====================================================
$ ! (See VAST_INCLUDE.COM file for purpose/comments...)
$INCLUDE:
$ OPEN /READ InclF 'AUD$IncludeFile'
$INCL0:
$ READ /END_OF_FILE=INCLDONE InclF IncLine
$ IncLine = F$EDIT(IncLine,"UNCOMMENT,COMPRESS")
$ IF F$EXTRACT(0,2,IncLine) .EQS. "$ " -
  THEN IncLine = F$EDIT(F$EXTRACT(2,F$LENGTH(IncLine)-2,IncLine),"TRIM")
$ IF IncLine .EQS. "" THEN GOTO INCL0
$ 'IncLine'
$ IF Debugging THEN wserr F$FAO( "$ [1m!AS[0m", IncLine )
$ GOTO INCL0
$INCLDONE:
$ CLOSE InclF
$ RETURN 1
$ ! end INCLUDE
$ ! --------
