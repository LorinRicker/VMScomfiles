$ ! VAST_07_APPFC.COM --                                          'F$VERIFY(0)'
$ !
$ !  use: @VAST_07_APPFC
$ !
$ ! Copyright (C) 2012-2013 Lorin Ricker <lorin@rickernet.us>
$ ! Version: 2.0, 05/17/2013
$ !
$ ! This program is free software, under the terms and conditions of the
$ ! GNU General Public License published by the Free Software Foundation.
$ !
$ ! === Main ===
$Main:
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ GOSUB INCLUDE
$ Fac = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ !
$ ! --- --- --- ---
$ !
$ MajorStep = "7"
$ MajorName = "STMS -- Application Functional Checks"
$ MajorCat  = "APPLICATION"
$ !
$ Msg  = F$FAO( "%!AS-I-CHECKLIST, ", Fac )
$ MsgL = F$LENGTH(Msg)
$ wso F$FAO( "!/!AS!/!ASstarting", DHRul, Msg )
$ wso F$FAO( "!#* [1mChecklist !AS. !AS[0m", MsgL, MajorStep, MajorName )
$ wso F$FAO( "%!AS-I-COLLDATA, collecting audit data for system !AS!/!AS", Fac, AUD$Node, HRul )
$ !
$ MinorStep = "a"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:3.7,SYS/MW/BAPPs/RDBA:1.4(etc),A:p61"
$ AUD$BPSections == BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the Scheduler started and running correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptLong'" -
    "Scheduler started and running" -  ! short description
    "NDMUI SHOW VERSION" -
    "NDMUI SHOW SERVER"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "b"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:4.3-8"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are required Application Logical Names correctly defined?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Application Logical Names" -  ! short description
    "SHOW LOGICAL /SYSTEM DTV_*"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "c"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:4.3-8"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are required System and Support Logical Names correctly defined?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "System and Support Logical Names" -  ! short description
    "SHOW LOGICAL /SYSTEM DTVRM*"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "d"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS/MS/BAPPs/RDBA:1.4,2.4,3.4,4.1,5.7,6.4,7.1,8.7,9.4,10.1,11.7,12.4,13.1,14.7,15.11"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Has Green-Screen application access been checked and verified?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Green-Screen access" -  ! short description
    "''WSOmark'Have you checked and verified Green-Screen application access?"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "e"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS/MW/BAPPs:2.9,5.7,8.7,11.7,14.7,15.11"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Have the ET smoke-tests been done and verified?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "ET smoke-tests" -  ! short description
    "''WSOmark'Have you verified ET smoke-tests?"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "f"
$ DTSonly   = VBAR + ""
$ BPSection = "APPS:1.10,SYS:1.18,SYS:2.27,SYS/MW/BAPPs/RDBA:1.4(etc)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are the network connections to XREF up and verified?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "XREF network connections" -  ! short description
    "''WSOmark'Have you verified network connections to XREF?"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "g"
$ DTSonly   = VBAR + ""
$ BPSection = "A:p113"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are the correct Scheduler Tasks defined and in-queue?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Expected Scheduler Tasks defined" -  ! short description
    "''WSOmark'Are the expected Scheduler Tasks defined?"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "h"
$ DTSonly   = VBAR + ""
$ BPSection = "MW:1.12(etc)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are the expected Application Processes running correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Expected Application Processes running" -  ! short description
    "PIPE SHOW SYSTEM | AUD$SEARCH RDMS_,RDM_,ACMS /MATCH=OR" -
    "PIPE SHOW SYSTEM | AUD$SEARCH SUBR,""""||"""" /MATCH=OR" -
    "PIPE SHOW SYSTEM | AUD$SEARCH _WAIT /MATCH=OR"
$ !
$ ! --- --- --- ---
$ !
$Report:
$ @'AUD$PathAcc'VAST_RESULTS
$Done:
$ EXIT 1   !'F$VERIFY(0)'
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
$ ! end INCLUDE
$ ! --------
