$ ! VAST_09_MIXCLU.COM --                                         'F$VERIFY(0)'
$ !
$ !  use: @VAST_09_MIXCLU
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
$ MajorStep = "9"
$ MajorName = "Mixed Cluster -- Sanity Checks"
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
$ BPSection = "SYS:2.33-34,SYS:15.10"
$ AUD$BPSections == BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Does this VMSCluster boot both Alpha and Itanium systems
  into the cluster without problems (mixed cluster)?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptLong'" -
    "Mixed cluster (Alpha & Itanium)" -  ! short description
    "''WSOmark'Are all mixed cluster systems booting in okay?"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "b"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:3.9,SYS:3.10"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ appdisk = "APPLICATION"
$ prodisk = "PRODUCT"
$ IF AUD$Arch .EQS. "IA64"
$ THEN appdisk = "I" + appdisk
$      prodisk = "I" + prodisk
$ ENDIF
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep)
$ TYPE SYS$INPUT
  Are key shared support disks available to each node?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Key shared support disks accessible" -  ! short description
    "SHOW DEVICE DISK$''appdisk'" -
    "SHOW DEVICE DISK$''prodisk'" -
    "SHOW DEVICE DISK$TOOLS" -
    "SHOW DEVICE DISK$USER"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "c"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.39,RDBA:1.2,RDBA3.3,RDBA:6.3,RDBA:9.3,RDBA:12.3"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the application database accessible to each node?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Database accessible" -  ! short description
    "RMU /SHOW SYSTEM"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "d"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:1.2,SYS:1.3"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ UAFdd = F$PARSE("SYSUAF","SYS$COMMON:[SYSEXE].DAT",,,"SYNTAX_ONLY")
$ UAFdd = F$PARSE(UAFdd,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(UAFdd,,,"DIRECTORY","SYNTAX_ONLY")
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are the Common User and Network Authorization (UAF) files
  available to each node?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Common UAF/Network Authorization files" -  ! short description
    "SHOW LOGICAL /SYSTEM SYSUAF" -
    "SHOW LOGICAL /SYSTEM RIGHTSLIST" -
    "SHOW LOGICAL /SYSTEM *PROXY" -
    "AUD$DIRF ''UAFdd'SYSUAF.DAT;,RIGHTSLIST.DAT;,*PROXY.DAT;"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "e"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:15.10"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Sanity check: SHOW CLUSTER

$ IF F$SEARCH("''AUD$PathAccDQ'SHOW_CLUSTER$INIT.INI") .NES. "" -
  THEN DEFINE /NOLOG /PROCESS /SUPERVISOR SHOW_CLUSTER$INIT "''AUD$PathAccDQ'SHOW_CLUSTER$INIT.INI"
$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Sanity check: SHOW CLUSTER" -  ! short description
    "SHOW LOGICAL /PROCESS SHOW_CLUSTER$INIT" -
    "SHOW CLUSTER"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "f"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Sanity check: SHOW SYSTEM

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Sanity check: SHOW SYSTEM" -  ! short description
    "PIPE SHOW SYSTEM | AUD$TYPE"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "g"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Sanity check: SHOW DEVICE D /MOUNTED

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Sanity check: SHOW DEVICE D /MOUNTED" -  ! short description
    "PIPE SHOW DEVICE D /MOUNTED | AUD$TYPE"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "h"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Sanity check: SHOW MEMORY

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Sanity check: SHOW MEMORY" -  ! short description
    "PIPE SHOW MEMORY | AUD$TYPE"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "i"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:1.6,SYS:2.18,SYS:4.3,SYS:7.3,SYS:10.3,SYS:13.3,A:p106-107"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Sanity check: SHOW QUEUE /BATCH /ALL

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Sanity check: SHOW QUEUE /BATCH /ALL" -  ! short description
    "PIPE SHOW QUEUE /BATCH /ALL | AUD$TYPE"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "j"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Sanity check: SHOW ACCOUNTING

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Sanity check: SHOW ACCOUNTING" -  ! short description
    "SHOW ACCOUNTING"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "k"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Sanity check: INSTALL LIST

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Sanity check: INSTALL LIST" -  ! short description
    "PIPE INSTALL LIST | AUD$TYPE"
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
