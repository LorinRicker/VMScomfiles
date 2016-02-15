$ ! VAST_10_DECNET.COM --                                         'F$VERIFY(0)'
$ !
$ !  use: @VAST_10_DECNET
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
$ MajorStep = "10"
$ MajorName = "DECnet -- Core Checks"
$ MajorCat  = "DECNET"
$ !
$ wso F$FAO( "!/!AS!/%!AS-I-CHECKLIST, starting Checklist !AS", HRul, Fac, MajorStep )
$ wso F$FAO( "%!AS-I-COLLDATA, collecting audit data for system !AS!/!AS", Fac, AUD$Node, HRul )
$ !
$ DECnetVersion = F$GETSYI("DECNET_VERSION")  ! Phase IV coughs up exactly "00040000",
$ dnv = F$INTEGER(DECnetVersion)              !  while Phase V produces >= "0005xx00"
$ dnvstring = F$EXTRACT(3,1,DECnetVersion) -
            + DOT + F$EXTRACT(4,2,DECnetVersion)
$ !
$ MinorStep = "a"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:1.10,SYS:2.11,SYS:2.36"
$ AUD$BPSections == BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the DECnet version correct?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptLong'" -
    "DECnet version" -  ! short description
    "WRITE sys$output F$FAO( """"!/  DECnet for OpenVMS Version !AS!/"""", """"''dnvstring'"""" )"
$ !
$ ! ---
$ ! === Split here between DECnet Phase IV and Phase V analysis... ===
$ IF dnv .GE. 50000 THEN GOTO PhaseV
$ !
$ ! ===== DECnet Phase IV =====
$PhaseIV:
$ NCP = "$SYS$SYSTEM:NCP"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "b"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the DECnet Phase IV Executor configured correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "DECnet Phase IV Executor" -  ! short description
    "NCP SHOW EXECUTOR CHARACTERISTICS"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "c"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the DECnet Phase IV Known Nodes database configured correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "DECnet Phase IV Known Nodes database" -  ! short description
    "PIPE NCP LIST KNOWN NODES | AUD$TYPE" -
    "PIPE NCP SHOW KNOWN NODES | AUD$TYPE"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "d"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the DECnet Phase IV Known Objects database configured correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "DECnet Phase IV Known Objects database" -  ! short description
    "PIPE NCP LIST KNOWN OBJECTS | AUD$TYPE" -
    "PIPE NCP SHOW KNOWN OBJECTS | AUD$TYPE"
$ !
$ ! =========
$ GOTO Report
$ ! =========
$ !
$ !
$ ! ===== DECnet Phase V =====
$PhaseV:
$ NCL = "$SYS$SYSTEM:NCL"
$ !
$ ! ---
$ MinorStep = "b"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the DECnet Phase V Executor configured correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptLong'" -
    "DECnet Phase V Executor" -  ! short description
    "NCL SHOW ALL IDENTIFIERS" -
    "NCL SHOW SESSION CONTROL ALL STATUS" -
    "NCL SHOW ROUTING ALL CHARACTERISTICS" -
    "NCL SHOW ROUTING CIRCUIT CSMACD-0 ALL"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "c"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the DECnet Phase V Known Nodes database configured correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "DECnet Phase V Known Nodes database" -  ! short description
    "NCL SHOW ROUTING CIRCUIT CSMACD-0 ADJACENCY *"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "d"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the DECnet Phase V Known Objects database configured correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "DECnet Phase V Known Objects database" -  ! short description
    "NCL SHOW SESSION CONTROL APPLICATION * NAME"
$ !
$ ! =========
$ GOTO Report
$ ! =========
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
