$ ! VAST_00_HW.COM --                                             'F$VERIFY(0)'
$ !
$ !  use: @VAST_00_HW
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
$ MajorStep = "0"
$ MajorName = "Hardware -- Configuration for Cluster"
$ MajorCat  = "HARDWARE"
$ !
$ Msg  = F$FAO( "%!AS-I-CHECKLIST, ", Fac )
$ MsgL = F$LENGTH(Msg)
$ wso F$FAO( "!/!AS!/!ASstarting", DHRul, Msg )
$ wso F$FAO( "!#* [1mChecklist !AS. !AS[0m", MsgL, MajorStep, MajorName )
$ wso F$FAO( "%!AS-I-COLLDATA, collecting audit data for system !AS!/!AS", Fac, AUD$Node, HRul )
$ !
$ DoShared FindIDOSD     ! build AUD$IDOSD, RMS-search-list logical for DISK$IDOSD*
$ DoShared FindPageSwap  ! build AUD$PAGESWAP, RMS-search-list logical for DISK$PAGESWAP*
$ !
$ MinorStep = "a"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:1.1"
$ AUD$BPSections == BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Verify the correct number of multi-CPUs and physical memory.

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptLong'" -
    "Check CPUs and Memory" -  ! short description
    "SHOW CPU" -
    "SHOW MEMORY /PHYSICAL"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "b"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:1.1"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the system console line operational (have you logged in via console)?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "System console line working" -  ! short description
    "''WSOmark'Have you (or are you now) logged in on this system's console line?"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "c"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:1.1"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are the Network InterConnections properly configured for this system?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "NIC configurations" -  ! short description
    "''WSOmark'Are NICs properly configured?"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "d"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:1.6"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are the VMS System SYS$SYSDEVICE) and Support Disks
  (DISK$IDOSD and DISK$IPAGESWAPn) mounted?

$ SHOW LOGICAL /PROCESS AUD$IDOSD
$ SHOW LOGICAL /PROCESS AUD$IPAGESWAP
$ psdisk = F$TRNLNM("AUD$IPAGESWAP","LNM$PROCESS",0)
$ IF psdisk .NES. ""
$ THEN c1 = "SHOW DEVICE ''psdisk'"
$ ELSE c1 = "''WSOmark'No Page/Swap disk configured yet"
$ ENDIF
$ IF F$TRNLNM("AUD$IDOSD") .NES. ""
$ THEN c2 = "SHOW DEVICE ''F$TRNLNM("AUD$IDOSD","LNM$PROCESS",0)'"
$ ELSE c2 = "''WSOmark'No Common SysDump disk configured yet"
$ ENDIF
$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "VMS System Disks" -  ! short description
    "SHOW DEVICE SYS$SYSDEVICE" -
    "''c1'" -
    "''c2'"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "e"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:1.6"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are the Foundation Disks (DISK$IAPPLICATION, DISK$IPRODUCT)
  mounted and correctly configured?

$ IF F$TRNLNM("DISK$IAPPLICATION") .NES. ""
$ THEN d2 = "SHOW DEVICE DISK$IAPPLICATION"
$ ELSE d2 = "''WSOmark'No Appliction disk configured yet"
$ ENDIF
$ IF F$TRNLNM("DISK$IPRODUCT") .NES. ""
$ THEN d3 = "SHOW DEVICE DISK$IPRODUCT"
$ ELSE d3 = "''WSOmark'No Product disk configured yet"
$ ENDIF
$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "VMS Foundation Disks" -  ! short description
    "''d2'" -
    "''d3'"
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
