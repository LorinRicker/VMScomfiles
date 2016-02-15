$ ! VAST_06_START.COM --                                          'F$VERIFY(0)'
$ !
$ !  use: @VAST_06_START
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
$ MajorStep = "6"
$ MajorName = "VMS -- System Startup and Shutdown Command-Files"
$ MajorCat  = "VMS"
$ !
$ Msg  = F$FAO( "%!AS-I-CHECKLIST, ", Fac )
$ MsgL = F$LENGTH(Msg)
$ wso F$FAO( "!/!AS!/!ASstarting", DHRul, Msg )
$ wso F$FAO( "!#* [1mChecklist !AS. !AS[0m", MsgL, MajorStep, MajorName )
$ wso F$FAO( "%!AS-I-COLLDATA, collecting audit data for system !AS!/!AS", Fac, AUD$Node, HRul )
$ !
$ MinorStep = "a"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.40"
$ AUD$BPSections == BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is SYSMAN STARTUP file list in order, matching Production?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptLong'" -
    "SYSMAN STARTUP file list" -  ! short description
    "AUD$SYSMAN STARTUP SHOW FILE *"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "b"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.15,SYS:2.17,SYS:3.9-10,SYS:15.8"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are all required edits to SYSTARTUP_VMS.COM done?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "SYSTARTUP_VMS.COM ready" -  ! short description
    "TYPE /PAGE=SAVE=10 SYS$STARTUP:SYSTARTUP_VMS.COM"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "c"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.15,SYS:2.41"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are all required edits to SYSHUTDWN.COM done?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "SYSHUTDWN.COM ready" -  ! short description
    "TYPE /PAGE=SAVE=10 SYS$STARTUP:SYSHUTDWN.COM"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "d"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.40,SYS:1.3(p28),A:pp60-61,67,69,72-73,82-83,99-100,108,122-123,126,129-130"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are all Layered Product-specific startup and shutdown
  command files in-place and ready?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Layered Product startup/shutdown command files" -  ! short description
    "AUD$DIRF SYS$STARTUP:RMONST*72.COM;" -
    "AUD$DIRF SYS$STARTUP:DFG$S*.COM;" -
    "AUD$DIRF SYS$STARTUP:ACMS$S*_MONITOR.COM;" -
    "AUD$DIRF SYS$STARTUP:FORMS$S*.COM;"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "e"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:4.1-4.13,A:p128"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are all STMS and supporting application startup and shutdown
  command files in-place and ready?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "STMS startup/shutdown command files" -  ! short description
    "AUD$DIRF SYS$STARTUP:DBS$APPLICATION_S*.COM;"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "f"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:15.10"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Have clean command-file startups been observed and confirmed
  for system reboots?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Clean system startups on reboot" -  ! short description
    "''WSOmark'Have you observed and confirmed a Clean System Startup?"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "g"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:15.10"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Have clean command-file shutdowns been observed and confirmed
  for system shutdowns?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Clean system shutdowns" -  ! short description
    "''WSOmark'Have you observed and confirmed a Clean System Shutdown?"
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
