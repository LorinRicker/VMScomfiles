$ ! VAST_01_VMS.COM --                                            'F$VERIFY(0)'
$ !
$ !  use: @VAST_01_VMS
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
$ MajorStep = "1"
$ MajorName = "VMS -- Installation and Functional Checks"
$ MajorCat  = "VMS"
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
$ BPSection = "SYS:2.24"
$ AUD$BPSections == BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is this system's cluster-root SYS$SPECIFIC (SYS$SYSDEVICE:[SYSn.])
  built correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptLong'" -
    "SYS$SPECIFIC built correctly" -  ! short description
    "SHOW LOGICAL /SYSTEM SYS$SPECIFIC" -
    "AUD$DIRF SYS$SPECIFIC:[SYSEXE]*.PAR;,*.DAT;"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "b"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:3.2,SYS:3.4"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are BOOT_OPTIONS set correctly for this system?

  Note: [4mThis step applies only to IA64 Blade systems[0m (not Alphas).

        On IA64 systems, the command procedure SYS$MANAGER:BOOT_OPTIONS.COM
        will be executed so that you can confirm the boot options by using
        Menu Choices ([5m2[0m) and ([5mD[0m)([5m2[0m) to [1mDISPLAY[0m both the "EFI Boot Options
        list" and the "EFI VMS_DUMP_DEV_ Options list".  Use Menu Choice ([5mE[0m)
        to [4mexit[0m from BOOT_OPTIONS...

$ IF AUD$Arch .NES. "IA64"
$ THEN tprompt = SkipFlag
$      syncprompt = F$FAO( "!AS system, skipping BOOT_OPTIONS... !AS", AUD$Arch, PromptSync )
$ ELSE tprompt = PromptShort
$      syncprompt = F$FAO( "!AS system, proceeding with BOOT_OPTIONS... !AS", AUD$Arch, PromptSync )
$ ENDIF
$ READ sys$command junk /END_OF_FILE=Done /PROMPT="''syncprompt'"
$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''tprompt'" -
    "BOOT_OPTIONS set correctly" -  ! short description
    "CALL BootOptions"              !was: "@sys$manager:boot_options"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "c"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:3.2,SYS:3.4-6"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Have you done at least one VMS Conversational Boot to examine
  SYSGEN parameters at the SYSBOOT> prompt during the bootstrap
  process?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "VMS Conversational boot" -  ! short description
    "''WSOmark'At least one VMS Conversational Boot?"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "d"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.22"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Common VMS SYSDUMP disk initialized and built correctly?

  In the directory listings that follow, the File_Ids (FIDs) for the
  SYSDUMP-COMMON.DMP and the sys-specific SYSDUMP.DMP must match...

$ SHOW LOGICAL /PROCESS AUD$IDOSD
$ topsys = F$TRNLNM("SYS$TOPSYS","LNM$SYSTEM")
$ vcsdmp = "AUD$IDOSD:[VMS$COMMON.SYSEXE]SYSDUMP-COMMON.DMP"
$ spcdmp = "AUD$IDOSD:[''topsys'.SYSEXE]SYSDUMP.DMP"
$ vcsdmp_fid = F$FILE_ATTRIBUTES(vcsdmp,"FID")
$ spcdmp_fid = F$FILE_ATTRIBUTES(spcdmp,"FID")
$ IF vcsdmp_fid .EQS. spcdmp_fid
$ THEN fidcomp = "SYSDUMP.DMP configured correctly, FIDs match..."
$ ELSE fidcomp = "SYSDUMP.DMP incorrectly configured, FIDs do not match!"
$ ENDIF
$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Common VMS SYSDUMP disk" -  ! short description
    "AUD$DIRF AUD$IDOSD:[000000]*.DIR" -
    "AUD$DIRFID ''vcsdmp'" -
    "AUD$DIRFID ''spcdmp'" -
    "''WSOmark'''fidcomp'"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "e"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Have you done at least one Test Crash to validate that this
  system's VMS memory dump goes to the Common SYSDUMP file?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "VMS Crash Test" -  ! short description
    "''WSOmark'At least one VMS Crash Test?"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "f"
$ DTSonly   = VBAR + ""
$ BPSection = "SAN/SYS:1.6,SYS:2.20"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the Shared Page/Swap disk DISK$IPAGESWAPn mounted correctly?

$ SHOW LOGICAL /PROCESS AUD$IPAGESWAP
$ psdisk = F$TRNLNM("AUD$IPAGESWAP","LNM$PROCESS",0)
$ IF psdisk .NES. ""
$ THEN c1 = "SHOW DEVICE ''psdisk'"
$ ELSE c1 = "''WSOmark'No Page/Swap disk configured yet"
$ ENDIF
$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "VMS Page/Swap Disk mounted" -  ! short description
    "''c1'"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "g"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.22,SYS:2.23"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the Shared Page/Swap disk DISK$PAGESWAPn correctly configured?

  Verify that the correct PAGEFILE.SYS is used as this system's
  sole Page/Swap file...

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "VMS Page/Swap Disk configuration" -  ! short description
    "AUD$DIRF ''psdisk':[''AUD$Node']*.SYS" -
    "SHOW MEMORY /FILES"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "h"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.23"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Have the system-specific VMS page and swap files been renamed
  and deleted after a reboot to reclaim that disk space?

$ vmspagfil = F$SEARCH("SYS$SPECIFIC:[SYSEXE]*PAGEFILE*.*")
$ vmsswpfil = F$SEARCH("SYS$SPECIFIC:[SYSEXE]*SWAPFILE*.*")
$ IF ( vmspagfil .EQS. "" ) .AND. ( vmsswpfil .EQS. "" )
$ THEN h1 = "''WSOmark'Sys-specific Page/Swap filespace has been reclaimed"
$ ELSE h1 = "AUD$DIRF SYS$SPECIFIC:[SYSEXE]*PAGEFILE*.*;*,*SWAPFILE*.*;*"
$ ENDIF
$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "VMS sys-specific Page/Swap files reclaimed" -  ! short description
    "''h1'"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "i"
$ DTSonly   = VBAR + ""
$ BPSection = "SAN/SYS:1.6,SYS:2.8,SYS:3.9"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are the Foundation Disks (DISK$IAPPLICATION, DISK$IPRODUCT)
  mounted and correctly configured?

$ IF F$TRNLNM("DISK$IAPPLICATION") .NES. ""
$ THEN i2 = "AUD$DIRF DISK$IAPPLICATION:[000000]*.DIR"
$ ELSE i2 = "''WSOmark'No Appliction disk configured yet"
$ ENDIF
$ IF F$TRNLNM("DISK$IPRODUCT") .NES. ""
$ THEN i3 = "AUD$DIRF DISK$IPRODUCT:[000000]*.DIR"
$ ELSE i3 = "''WSOmark'No Product disk configured yet"
$ ENDIF
$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "VMS Foundation Disks" -  ! short description
    "''i2'" -
    "''i3'"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "j"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.14,SYS:2.24,SYS:2.25,SYS:2.37"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are the SCSNODE, SCSSYSTEMID and ALLOCLASS values correct
  for this cluster-node system?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "SCSNODE, SYSSYSTEMID, ALLOCLASS values" -  ! short description
    "CALL ShowParameter SYSGEN SCSNODE """"== ''AUD$Node'""""" -
    "CALL ShowParameter SYSGEN SCSSYSTEMID """"~ (DECnet_Area * 1024) + DECnet_Addr""""" -
    "CALL ShowParameter SYSGEN ALLOCLASS"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "k"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.24,SYS:2.37"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are the VOTES and EXPECTED_VOTES values correct for this cluster-node
  system, and are MODPARAMS.DAT and DTV_CLUSTER_PARAMS.DAT set up right?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "EXPECTED/VOTES, MODPARAMS.DAT & DTV_CLUSTER_PARAMS.DAT" -  ! short description
    "AUD$DIRF SYS$COMMON:[SYSEXE]DTV_CLUSTER_PARAMS.DAT;0" -
    "TYPE SYS$SPECIFIC:[SYSEXE]MODPARAMS.DAT" -
    "CALL ShowParameter SYSGEN VOTES """"= 1""""" -
    "CALL ShowParameter SYSGEN EXPECTED_VOTES """"~ #nodes-in-cluster"""""
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "l"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.32"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are the Cluster Alias, Group and Password all set properly?
  (Note: cannot show the Cluster Password...)

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Cluster Alias & Group" -  ! short description
    "AUD$SYSMAN CONFIGURATION SHOW CLUSTER_AUTHORIZATION"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "m"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.34"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are the LANCP Ethernet Devices correctly defined and configured?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "LANCP Ethernet Device configuration" -  ! short description
    "PIPE SHOW SYSTEM | AUD$SEARCH LANACP" -
    "AUD$LANCP SHOW DEVICE LLA0 /CHAR" -
    "AUD$LANCP SHOW DEVICE
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "n"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:1.10,SYS:2.11,SYS:2.36"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is DECnet address and area defined correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "DECnet configuration" -  ! short description
    "PRODUCT SHOW PRODUCT DECNET*" -
    "PIPE SHOW SYSTEM | AUD$SEARCH NET$,REMACP /MATCH=OR" -
    "SHOW NETWORK"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "o"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:1.10,SYS:2.10,SYS:2.35"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Are TCP/IP IP-address, name and subnet mask defined correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "TCP/IP basic configuration" -  ! short description
    "PRODUCT SHOW PRODUCT TCPIP*" -
    "TCPIP SHOW VERSION" -
    "SHOW NETWORK"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "p"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.35,SYS:2.36"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is this system/node accessible to DECnet & TCP/IP, specifically
  SET HOST, telnet, ssh, COPY over DECnet, COPY/FTP and ftp?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "DECnet & TCP/IP accessibility" -  ! short description
    "''WSOmark'Have you verified all DECnet and TCP/IP accessibilities?"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "q"
$ DTSonly   = VBAR + ""
$ BPSection = "SYS:2.19"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the Hyperthreading command symbol available in SYSTEM's
  login command file?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "Hyperthreading command symbol" -  ! short description
    "SEARCH SYS$MANAGER:LOGIN.COM hypert,hthread /MATCH=OR"
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
