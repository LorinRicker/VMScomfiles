$ ! VAST_02_SWPROD.COM --                                         'F$VERIFY(0)'
$ !
$ !  use: @VAST_02_SWPROD
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
$ MajorStep = "2"
$ MajorName = "Software Products -- Installation"
$ MajorCat  = "SOFTWARE"
$ !
$ Msg  = F$FAO( "%!AS-I-CHECKLIST, ", Fac )
$ MsgL = F$LENGTH(Msg)
$ wso F$FAO( "!/!AS!/!ASstarting", DHRul, Msg )
$ wso F$FAO( "!#* [1mChecklist !AS. !AS[0m", MsgL, MajorStep, MajorName )
$ wso F$FAO( "%!AS-I-COLLDATA, collecting audit data for system !AS!/!AS", Fac, AUD$Node, HRul )
$ !
$ MinorStep = "a"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.31"
$ AUD$BPSections == BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are VMS system & component mandatory updates and patches installed?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptLong'" -
    "VMS mandatory updates and patches" -  ! short description
    "PRODUCT SHOW PRODUCT"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "b"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:1.11"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are VMS Software Product Licenses (PAKs) installed and loaded?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "VMS Software Product Licenses" -  ! short description
    "SHOW LICENSE"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "c"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are other vendor Software Product Licenses (CA-Poly, JCC, NDM)
  installed?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Vendor Software Product Licenses" -  ! short description
    "''WSOmark'Have you confirmed these other vendor licenses?"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "d"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.39"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is Disk File Optimizer (DFG) installed, and
  has SETFILENOMOVE.COM been run on SYS$SYSDEVICE?

$ cfnomove = F$SEARCH("SYS$DISK:[CLUTOOLS...]CHECKFILENOMOVE.COM")
$ cfnomove = cfnomove - F$PARSE(cfnomove,,,"VERSION","SYNTAX_ONLY")
$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Disk File Optimizer (DFG) and SETFILENOMOVE.COM" -  ! short description
    "@''cfnomove'" -
    "PIPE SHOW SYSTEM | AUD$SEARCH DFG$" -
    "DEFRAG SHOW /STATISTICS /VOLUME SYS$SYSDEVICE"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "e"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.39"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is Oracle Rdb and SQL-Services installed?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Rdb and SQL-Services installation" -  ! short description
    "RMU /SHOW VERSION" -
    "PIPE SHOW SYSTEM | AUD$SEARCH RDM,RMU,SQL /MATCH=OR" -
    "AUD$DIRF SYS$SYSTEM:SQLSRV*.*;"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "f"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.39"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is ACMS installed?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "ACMS installation" -  ! short description
    "PIPE SHOW SYSTEM | AUD$SEARCH ACMS" -
    "PIPE ACMS /SHOW SYSTEM | TYPE sys$input" -  ! don't use AUD$TYPE (/PAGE) here
    "PIPE ACMS /SHOW SERVER | TYPE sys$input" -
    "PIPE ACMS /SHOW APPLICATION | TYPE sys$input"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "g"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.39"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is FORMS-RT installed?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "FORMS-RT installation" -  ! short description
    "AUD$DIRF SYS$LIBRARY:FORMS$*.*;" -
    "PIPE INSTALL LIST | AUD$SEARCH FORMS$"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "h"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.39"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are all CA-Poly products installed?

    Scheduler Agent
    Scheduler Manager
    Performance Manager Agent
    Performance Manager
    SNS Watchdog

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "CA-Poly products installation" -  ! short description
    "PIPE SHOW SYSTEM | AUD$SEARCH NSCHED,SCHED$ /MATCH=OR" -
    "PIPE SHOW SYSTEM | AUD$SEARCH SNS$WATCH"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "i"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.39"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is JCC LogMiner Loader installed?

$ jccroot = "JCC"
$ approot = "DISK$IAPPLICATION:[000000]"
$j0:
$ jcc = F$SEARCH("''approot'JCC_ROOT*.DIR")
$ IF jcc .EQS. "" THEN GOTO j1
$ jcc = F$PARSE(jcc,,,"NAME","SYNTAX_ONLY")
$ IF jccroot .LTS. jcc THEN jccroot = jcc  ! find latest/highest installed version
$ GOTO j0
$j1:
$ jccroot = "[" + jccroot + ".EXE]"
$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "JCC LogMiner Loader installation" -  ! short description
    "AUD$DIRF ''approot'JCC_ROOT*.DIR;" -
    "AUD$DIRB DISK$IAPPLICATION:''jccroot'JCC_LOGMINER*.EXE;0"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "j"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.39"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is Oracle Tuxedo installed?

$ tuxroot = "TUX"
$ prdroot = "DISK$IPRODUCT:[000000]"
$k0:
$ tux = F$SEARCH("''prdroot'TUXEDO*.DIR")
$ IF tux .EQS. "" THEN GOTO k1
$ tux = F$PARSE(tux,,,"NAME","SYNTAX_ONLY")
$ IF tuxroot .LTS. tux THEN tuxroot = tux  ! find latest/highest installed version
$ GOTO k0
$k1:
$ tuxroot = "[" + tuxroot + ".BIN]"
$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Tuxedo installation" -  ! short description
    "PRODUCT SHOW PRODUCT TUXEDO*" -
    "AUD$DIRF ''prdroot'TUXEDO*.DIR;" -
    "AUD$DIRB DISK$IPRODUCT:''tuxroot'TUX*.EXE;0"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "k"
$ DTSonly   = VBAR + ""
$ BPSection = "A:p129"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is NDM (Sterling SW Connect:Direct) installed?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "NDM installation" -  ! short description
    "AUD$DIRF DISK$IPRODUCT:[000000]NDM*.DIR;" -
    "AUD$DIRB DISK$IPRODUCT:[NDM]NDMUI.EXE;0,NDM_SMGR.EXE;0,NDM_SRV.EXE;0"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "l"
$ DTSonly   = VBAR + ""
$ BPSection = "A:p60"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is Availability Manager Collector installed?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "AVAIL_MAN_COLL installation" -  ! short description
    "PRODUCT SHOW PRODUCT AVAIL_MAN*" -
    "AUD$DIRF SYS$STARTUP:AMDS$STARTUP.COM;" -
    "AUD$DIRF SYS$LOADABLE_IMAGES:*RMDRIVER*.EXE;" -
    "SHOW LOGICAL /SYSTEM AMDS$SYSTEM"
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
