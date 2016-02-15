$ ! VAST_13_ACMS.COM --                                           'F$VERIFY(0)'
$ !
$ !  use: @VAST_13_ACMS
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
$ MajorStep = "13"
$ MajorName = "ACMS -- Critical Parameter Checks"
$ MajorCat  = "ACMSGEN"
$ !
$ wso F$FAO( "!/!AS!/%!AS-I-CHECKLIST, starting Checklist !AS", HRul, Fac, MajorStep )
$ wso F$FAO( "%!AS-I-COLLDATA, collecting audit data for system !AS!/!AS", Fac, AUD$Node, HRul )
$ !
$ MinorStep = "a"
$ DTSonly   = VBAR + ""
$ BPSection = "A:p130-131"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ AGpar = "NODE_NAME"
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the ACMSGEN NODE_NAME parameter set properly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "ACMSGEN parameter: ''AGpar'" -  ! short description
    "CALL ShowParameter ACMSGEN ''AGpar' """"== ''AUD$Node'"""""
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "b"
$ DTSonly   = VBAR + ""
$ BPSection = "A:p130-131"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ AGpar = "MAX_LOGINS"
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the ACMSGEN MAX_LOGINS parameter set properly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "ACMSGEN parameter: ''AGpar'" -  ! short description
    "CALL ShowParameter ACMSGEN ''AGpar' """"= 20 submitters"""""
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "c"
$ DTSonly   = VBAR + ""
$ BPSection = "A:p130-131"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ AGpar = "MSS_POOLSIZE"
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the ACMSGEN MSS_POOLSIZE parameter set properly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "ACMSGEN parameter: ''AGpar'" -  ! short description
    "CALL ShowParameter ACMSGEN ''AGpar' """">= 5,000 pagelets"""""
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "d"
$ DTSonly   = VBAR + ""
$ BPSection = "A:p130-131"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ AGpar = "MAX_TTS_CP"
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the ACMSGEN MAX_TTS_CP parameter set properly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "ACMSGEN parameter: ''AGpar'" -  ! short description
    "CALL ShowParameter ACMSGEN ''AGpar' """"= 10"""""
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "e"
$ DTSonly   = VBAR + ""
$ BPSection = "A:p130-131"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ AGpar = "CP_SLOTS"
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the ACMSGEN CP_SLOTS parameter set properly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "ACMSGEN parameter: ''AGpar'" -  ! short description
    "CALL ShowParameter ACMSGEN ''AGpar' """"= 5"""""
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "f"
$ DTSonly   = VBAR + ""
$ BPSection = "A:p130-131"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ AGpar = "PERM_CPS"
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the ACMSGEN PERM_CPS parameter set properly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "ACMSGEN parameter: ''AGpar'" -  ! short description
    "CALL ShowParameter ACMSGEN ''AGpar' """"= 2"""""
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "g"
$ DTSonly   = VBAR + ""
$ BPSection = "A:p130-131"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ AGpar = "MAX_APPL"
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the ACMSGEN MAX_APPL parameter set properly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "ACMSGEN parameter: ''AGpar'" -  ! short description
    "CALL ShowParameter ACMSGEN ''AGpar' """">= 60"""""
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "h"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ AGlnm = "ACMS$ATL_ALQ_BLOCKS"
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the ACMS logical name ACMS$ATL_ALQ_BLOCKS defined correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "ACMS logical: ''AGlnm'" -  ! short description
    "CALL ShowLogical ''AGlnm' """"== 65,535"""""
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "i"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ AGpar = "ACMS$ATL_DEQ_BLOCKS"
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the ACMS logical name ACMS$ATL_DEQ_BLOCKS defined correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "ACMS logical: ''AGlnm'" -  ! short description
    "CALL ShowLogical ''AGlnm' """"== 65,535"""""
$ !
$!! $ ! ---
$!! $ ClrScrn
$!! $ MinorStep = "«»"
$!! $ DTSonly   = VBAR + ""
$!! $ BPSection = "«»"
$!! $ AUD$BPSections == AUD$BPSections + SEP + BPSection
$!! $ AGpar = "«»"
$!! $ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$!! $ TYPE SYS$INPUT
$!!   «»
$!!
$!! $ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
$!!     "«»" -  ! short description
$!!     "«»" -
$!!     "«»"
$!! $ !
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
