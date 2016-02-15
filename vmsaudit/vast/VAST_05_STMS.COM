$ ! VAST_05_STMS.COM --                                           'F$VERIFY(0)'
$ !
$ !  use: @VAST_05_STMS
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
$ MajorStep = "5"
$ MajorName = "STMS -- Application Software"
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
$ BPSection = "SYS:4.10"
$ AUD$BPSections == BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Has the correct version of STMS application software
  for this Release/Test cluster-system been installed?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptLong'" -
    "STMS correct version for this system" -  ! short description
    "SHOW LOGICAL /SYSTEM STMS_REVISION_LEVEL"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "b"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:4.1,SYS:4.2,SYS:4.7"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Do all STMS application components start-up correctly at reboot?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "STMS application startup" -  ! short description
    "PIPE SHOW SYSTEM | AUD$SEARCH SUBR,_WAIT,CIP_,MIP_,PIP_,CIR_,GIP_,SPUD_ /MATCH=OR"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "c"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.41"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Does STMS shutdown correctly with SYS$STARTUP:DBS$APPLICATION_SHUTDOWN.COM?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "STMS application shutdown" -  ! short description
    "''WSOmark'Have you confirmed that STMS shuts-down correctly?"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "d"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:4.2,SYS:4.7"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are STMS database disks mounted properly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "STMS database disks" -  ! short description
    "PIPE SHOW DEVICE D /MOUNTED | AUD$SEARCH RDB,AIJ,AJB,RUJ,LOGS,MINER /MATCH=OR"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "e"
$ DTSonly   = VBAR + ""
$ BPSection = "SAN:3.1"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are STMS application disks mounted properly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "STMS application disks" -  ! short description
    "PIPE SHOW DEVICE D /MOUNTED | AUD$SEARCH APPWRK,DBX,_DB,_SHD,SHDATA,LOGFILES /MATCH=OR"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "f"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:4.3,SYS:4.5,SYS:4.6,SYS:4.8"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are the DTV_* logical names defined properly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "DTV_* logical names" -  ! short description
    "SHOW LOGICAL /SYSTEM DTV_EXE" -
    "SHOW LOGICAL /SYSTEM DTV_DAT_COMMON" -
    "SHOW LOGICAL /SYSTEM DTV_SCHED_SCRIPTS" -
    "CALL CountLNMItems DTV_*"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "g"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are the DTVRM_* logical names defined properly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "DTVRM_* logical names" -  ! short description
    "SHOW LOGICAL /SYSTEM DTVRM_TOP" -
    "SHOW LOGICAL /SYSTEM DTVRM_ROOT" -
    "SHOW LOGICAL /SYSTEM DTVRM_EXE" -
    "CALL CountLNMItems DTVRM_*"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "h"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are the *_GROUP and *_NODES logical names defined properly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "*_GROUP and *_NODES logical names" -  ! short description
    "SHOW LOGICAL /SYSTEM D*_GROUP" -      !just a selection to show...
    "SHOW LOGICAL /SYSTEM D*_NODES" -
    "CALL CountLNMItems *_GROUP" -
    "CALL CountLNMItems *_NODES"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "i"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.26-.30"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are STMS application proxies defined correctly
  (Billing, XRef, Reporting, PRC, MCC)?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "STMS application proxies?" -  ! short description
    "''WSOmark'Have you confirmed the STMS application proxies?"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "j"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:4.4,SYS:4.10"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are all STMS application directory and file ownerships,
  protections and ACLs set correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "STMS directory & file ownership, etc." -  ! short description
    "''WSOmark'Have you confirmed STMS directory/file ownerships, protections, ACLs?"
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
