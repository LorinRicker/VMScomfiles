$ ! VAST_12_SYSGEN.COM --                                         'F$VERIFY(0)'
$ !
$ !  use: @VAST_12_SYSGEN
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
$ MajorStep = "12"
$ MajorName = "SYSGEN -- Critical Parameter Checks"
$ MajorCat  = "SYSGEN"
$ !
$ wso F$FAO( "!/!AS!/%!AS-I-CHECKLIST, starting Checklist !AS", HRul, Fac, MajorStep )
$ wso F$FAO( "%!AS-I-COLLDATA, collecting audit data for system !AS!/!AS", Fac, AUD$Node, HRul )
$ !
$ MinorStep = "a"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == BPSection
$ SGpar = "LOCKIDTBL"
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the SYSGEN parameter LOCKIDTBL set correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptLong'" -
    "SYSGEN parameter: ''SGpar'" -  ! short description
    "CALL ShowParameter SYSGEN ''SGpar' """"== 3,300,000"""""
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "b"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ SGpar = "RESHASHTBL"
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the SYSGEN parameter RESHASHTBL set correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptLong'" -
    "SYSGEN parameter: ''SGpar'" -  ! short description
    "CALL ShowParameter SYSGEN ''SGpar' """"== 4,194,000"""""
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "c"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ SGpar = "WSINC"
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the SYSGEN parameter WSINC set correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptLong'" -
    "SYSGEN parameter: ''SGpar'" -  ! short description
    "CALL ShowParameter SYSGEN ''SGpar' """"== 8,192"""""
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "d"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ SGpar = "QUANTUM"
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the SYSGEN parameter QUANTUM set correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptLong'" -
    "SYSGEN parameter: ''SGpar'" -  ! short description
    "CALL ShowParameter SYSGEN ''SGpar' """"== 20"""""
$ !
$!! $ ! ---
$!! $ ClrScrn
$!! $ MinorStep = "«»"
$!! $ DTSonly   = VBAR + ""
$!! $ BPSection = "(NIP)"
$!! $ AUD$BPSections == AUD$BPSections + SEP + BPSection
$!! $ SGpar = "«»"
$!! $ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$!! $ TYPE SYS$INPUT
$!!   Is the SYSGEN parameter «» set correctly?

$!! $ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptLong'" -
$!!     "SYSGEN parameter: ''SGpar'" -  ! short description
$!!     "CALL ShowParameter SYSGEN ''SGpar' """"= «»"""""
$ !
$!! $ ! ---
$!! $ ClrScrn
$!! $ MinorStep = "«»"
$!! $ DTSonly   = VBAR + ""
$!! $ BPSection = "(NIP)"
$!! $ AUD$BPSections == AUD$BPSections + SEP + BPSection
$!! $ SGpar = "«»"
$!! $ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$!! $ TYPE SYS$INPUT
$!!   Is the SYSGEN parameter «» set correctly?

$!! $ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptLong'" -
$!!     "SYSGEN parameter: ''SGpar'" -  ! short description
$!!     "CALL ShowParameter SYSGEN ''SGpar' """"= «»"""""
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
