$ ! VAST_DOSTEP.COM --                                            'F$VERIFY(0)'
$ !
$ !  Callable "DoStep" and "Execute" routines for VAST_*
$ !
$ !  use (from VAST_xx_zzz.COM checklist procedures):
$ !
$ !     @VAST_DOSTEP MajorStep MinorStep PromptLong -
$ !                   ShortDescription -
$ !                   Command1 -
$ !                   Command2 -
$ !                   Command3 -
$ !                   Command4
$ !
$ !  Delete AUD$* global symbols:
$ !
$ ! Copyright (C) 2012-2013 Lorin Ricker <lorin@rickernet.us>
$ ! Version: 2.0, 05/17/2013
$ !
$ ! This program is free software, under the terms and conditions of the
$ ! GNU General Public License published by the Free Software Foundation.
$ !
$ ! --------
$BootOptions:  SUBROUTINE
$ ! Inline commands: 2 (display boot options), D 2 (display device options), E (exit) --
$ @sys$manager:boot_options "''AUD$PathAccDQ'VAST_BOOT_OPTIONS_ANSWERS.TXT"
$ !
$ EXIT 1
$ !
$SCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! BootOptions
$ ! --------
$ !
$ ! --------
$CountLNMItems:  SUBROUTINE
$ ! P1 = a logical names group to display
$ lnmroot = P1 - "*"
$ AUD$lnm_tmp = "SYS$DISK:[]VAST_LNM_TEMP.LIS"
$ SHOW LOGICAL /SYSTEM 'P1' /OUTPUT='AUD$lnm_tmp'
$ OPEN /READ tmp 'AUD$lnm_tmp'
$ lcnt = 0
$CLI0:
$ READ /END_OF_FILE=CLI1 tmp line
$ line = F$EDIT(line,"UNCOMMENT,COMPRESS")
$ linelen = F$LENGTH(line)
$ IF linelen .EQ. 0 THEN GOTO CLI0
$ ! Count only lines of form " 'lnmroot'* = *"
$ IF ( F$LOCATE(lnmroot,line) .LT. linelen ) .AND. ( F$LOCATE(EQUAL,line) .LT. linelen ) -
  THEN lcnt = lcnt + 1
$ GOTO CLI0
$CLI1:
$ CLOSE /DISPOSITION=DELETE tmp
$ wso F$FAO( "!/  There are !SL !AS system logical name!%S defined", -
             lcnt, P1 )
$ EXIT 1
$ ENDSUBROUTINE  ! CountLNMItems
$ ! --------
$ !
$ !
$ ! --------
$TestValue:  SUBROUTINE
$ ! P1 = SYSGEN or ACMSGEN parameter
$ ! P2 = actual value
$ ! P3 = test criterion
$ !
$ SET NOON
$ wso F$FAO( "  --- Target criterion: !AS should be !AS", P1, P3 )
$ dclopr   = ""
$ relopr   = F$ELEMENT(0,SPC,P3)
$ expected = F$ELEMENT(1,SPC,P3) - COMMA - COMMA - COMMA - COMMA
$ IF ( relopr .EQS. GE )
$ THEN dclopr = ".GES."
$ ELSE IF ( relopr .EQS. EQUAL ) .OR. ( relopr .EQS. EQUALITY )
$      THEN dclopr = ".EQS."
$      ELSE IF ( relopr .EQS. LE )
$           THEN dclopr = ".LES."
$           ELSE IF ( F$EXTRACT(0,1,relopr) .EQS. TILDE )  ! ~, ~=, ~<=, ~>=, etc.
$                THEN dclopr = ""
$                ELSE wserr F$FAO( "%!AS-E-BADOPR, unsupported operator ""!AS""", P4, relopr )
$                     EXIT %X2C
$                ENDIF
$           ENDIF
$      ENDIF
$ ENDIF
$ Stat = %X1
$ IF dclopr .NES. ""
$ THEN IF ( "''P2'" 'dclopr' "''expected'" )
$      THEN msg1 = "---"
$           msg2 = "passes"
$           msg3 = relopr
$      ELSE msg1 = "!!!"
$           msg2 = "fails"
$           msg3 = "is not " + relopr
$           Stat = %X2C
$      ENDIF
$      wso F$FAO( "  !AS Test !AS -- actual !AS !AS !AS", msg1, msg2, P1, msg3, expected )
$ ENDIF
$ wso ""
$ EXIT 'Stat'  ! 'F$VERIFY(0)'
$ ENDSUBROUTINE  ! TestValue
$ ! --------
$ !
$ ! --------
$ShowLogical:  SUBROUTINE
$ ! P1 = Logical name to display
$ ! P2 = (optional) target criterion (e.g. ">= 5,000")
$ ! P3 = (optional) lnm-table: SYSTEM (default), JOB, GROUP, PROCESS
$ !
$ SET NOON
$ !
$ IF P3 .EQS. ""
$ THEN tbl = "SYSTEM"
$ ELSE tbl = P3 - "LNM$" - "_TABLE" - SLASH
$ ENDIF
$ !
$ Stat = %X1
$ lnm = F$TRNLNM(P1,"LNM$''tbl'")
$ IF lnm .NES. ""
$ THEN SHOW LOGICAL /'tbl' 'P1'  ! let VMS display it
$      IF P2 .NES. ""
$      THEN CALL TestValue "''P1'" "''lnm'" "''P2'" "ShowLogical"
$           Stat = $STATUS
$      ENDIF
$ ELSE wso F$FAO( "!AS-E-NOLNM, logical name ""!AS"" is undefined in LNM$!AS table", -
                  Fac, P1, tbl )
$ ENDIF
$ EXIT 'Stat'
$ ENDSUBROUTINE  ! ShowLogical
$ ! --------
$ !
$ ! --------
$ShowParameter:  SUBROUTINE
$ ! P1 = "SYSGEN" or "ACMSGEN"
$ ! P2 = SYSGEN or ACMSGEN parameter to display
$ ! P3 = (optional) target criterion (e.g. ">= 5,000")
$ !
$ SET NOON
$ !
$ wtf = "WRITE tfil"
$ AUD$sp_out = "SYS$DISK:[]VAST_ShowParameter_OUTPUT.TXT"
$ AUD$sp_tmp = "SYS$DISK:[]VAST_ShowParameter_TEMP.COM"
$ !
$ ! Prep the com-file to show the VMS or ACMS parameter value --
$ ! (cannot use F$GETSYI() for ACMSGEN parameters...):
$ OPEN /WRITE /ERROR=SPWriteErr tfil 'AUD$sp_tmp'
$ wtf "$ DEFINE /USER_MODE sys$output ''AUD$sp_out'"
$ wtf "$ MCR ''P1'"
$ wtf "USE CURRENT"
$ wtf "SHOW ''P2'"
$ wtf "EXIT"
$ wtf "$ EXIT 1"
$ CLOSE tfil
$ !
$ ! Produce the output to a temp-out file:
$ @'AUD$sp_tmp'
$ DELETE /NOLOG 'AUD$sp_tmp';*
$ !
$ ! Parse the temp-out file to glean the parameter and value --
$ ! (note SYSGEN produces a header for output, ACMSGEN does not):
$ OPEN /READ /ERROR=SPReadErr tout 'AUD$sp_out'
$SP0:
$ READ /END_OF_FILE=SP1 tout line
$ line = F$EDIT(line,"TRIM,COMPRESS") - DQUOTE - DQUOTE
$ IF line .EQS. "" THEN GOTO SP0
$ lead = F$EXTRACT(0,14,line)
$ IF ( lead .EQS. "Parameter Name" ) .OR. ( lead .EQS. "--------------" ) THEN GOTO SP0
$ param = F$ELEMENT(0,SPC,line)
$ value = F$ELEMENT(1,SPC,line)
$ GOTO SP1  ! ...only one value expected
$SP1:
$ CLOSE tout /DISPOSITION=DELETE
$ !
$ ! Display actual value --
$ wso F$FAO(   "  >>> Current !8AS: !AS = !AS", P1, param, value )
$ !
$ ! If test criterion is provided, evaluate it --
$ IF P3 .NES. ""
$ THEN SET NOON
$      CALL TestValue "''param'" "''value'" "''P3'" "ShowParameter"
$      Stat = $STATUS
$ ENDIF
$ !
$ EXIT 'Stat'
$ !
$SPWriteErr:
$ Stat = $STATUS
$ wso F$FAO( "%!AS-E-OPENERR, error opening !AS for write access", Fac, AUD$sp_tmp )
$ EXIT Stat
$ !
$SPReadErr:
$ Stat = $STATUS
$ wso F$FAO( "%!AS-E-OPENERR, error opening !AS for read access", Fac, AUD$sp_out )
$ EXIT Stat
$ !
$ ENDSUBROUTINE  ! ShowParameter
$ ! --------
$ !
$ !
$ ! --------
$Execute:  SUBROUTINE
$ ON CONTROL_Y THEN GOSUB ExCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ IF P1 .NES. ""
$ THEN IF F$EXTRACT(0,1,P1) .NES. WSOmark
$      THEN wso F$FAO( "$ [1m!AS[0m", P1 )
$           SET NOON
$           ! Workaround: The VMS TCPIP and SHOW CLUSTER commands think that they need to
$           !             know (check) where their SYS$INPUT is coming from (presumably
$           !             to conditionally enable Ctrl/C ASTs), but they hack up hairballs
$           !             "%SYSTEM-E-IVDEVNAM, invalid device name" if their command input
$           !             is a remote-proc (over DECnet)... so we have to conditionally set
$           !             SYS$INPUT to NLA0 for these cases:
$           specialcase = ( F$EXTRACT(0,6,P1) .EQS. "TCPIP " ) -
                     .OR. ( F$EXTRACT(0,8,P1) .EQS. "SHOW CLU" )
$           IF specialcase THEN DEFINE /USER_MODE sys$input NLA0:
$           'P1'
$           AUD$Stat == $STATUS
$           ON ERROR THEN EXIT %X2C
$      ELSE text = P1 - WSOmark
$           wso F$FAO( "  !AS [1m!AS[0m", WSOprompt, text )
$           AUD$Stat == 1
$      ENDIF
$      ! Since assignment "==" above itself changes $STATUS,
$      ! we have to re-synthesize $SEVERITY here...
$      AUD$Level == F$ELEMENT(1,DASH,F$MESSAGE(AUD$Stat))
$      IF F$LOCATE(AUD$Level,"FEW") .LT. 3  !Fatal, Error or Warning?
$      THEN AUD$Sev == 4
$      ELSE AUD$Sev == 1
$      ENDIF
$ ENDIF
$ExDone:
$ EXIT 1
$ !
$ExCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! Execute
$ ! --------
$ !
$ !
$ ! === DoStep Main ===
$Main:
$DoStep:
$ ! P1 = Checklist Major Step
$ ! P2 = Checklist Minor Step [ | DTS_types_only ] ! e.g.: "c| BB,SB,XF,SX"
$ ! P3 = Prompt
$ ! P4 = Step quick description
$ ! P5 = Command #1
$ ! P6 = Command #2
$ ! P7 = Command #3
$ ! P8 = Command #4
$ !
$ ON CONTROL_Y THEN GOSUB DSCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ ! Separate Minor Step from DTS-types; a (non-"*") specific DTS-type
$ ! means that this test applies only to systems of that type...
$ minstep = F$EDIT(F$ELEMENT(0,VBAR,P2),"COLLAPSE")
$ dtstype = F$EDIT(F$ELEMENT(1,VBAR,P2),"UPCASE,COLLAPSE")
$ IF ( dtstype .EQS. "" ).OR. ( dtstype .EQS. VBAR )
$ THEN dtslist = SPLAT
$ ELSE dtslist = COMMA + dtstype + COMMA
$ ENDIF
$ !
$ P4L = F$LENGTH(P4)
$ IF AUD$MaxDescrL .LT. P4L THEN AUD$MaxDescrL == P4L
$ wso F$FAO( "!16* Checklist Step !AS.!AS. !AS!/", P1, minstep, P4 )
$ Stp = P1 + DOT + minstep + DOT + BSLASH + P4 + BSLASH
$ IF P8 .EQS. ""
$ THEN Sync = "Sync"
$ ELSE Sync = ""
$ ENDIF
$ !
$ ! Check if this test is DTS-type specific, skip if this node is wrong DTS-type:
$ IF ( dtslist .EQS. SPLAT ) -  ! any DTS-type?  or is ",FE," in ",BB,SB,FE,SF,"?
  .OR. ( F$LOCATE(",''AUD$DTStype',",dtslist) .LT. F$LENGTH(dtslist) )
$ THEN CONTINUE  ! auditing node is okay for this test...
$ ELSE wso F$FAO( "%!AS-W-DTS_SKIPSTEP, !AS skipping this !AS step: ""!AS""", -
                  Fac, AUD$Node, dtstype, P4 )
$      result = Stp + Skip
$      READ sys$command Answer /END_OF_FILE=DSDone /PROMPT="''PromptSync'"
$      GOTO DSRes
$ ENDIF
$ !
$ IF P3 .EQS. SkipFlag
$ THEN wso F$FAO( "%!AS-W-SKIPSTEP, skipping this step: ""!AS""", -
                  Fac, P4 )
$      result = Stp + Skip
$      READ sys$command Answer /END_OF_FILE=DSDone /PROMPT="''PromptSync'"
$      GOTO DSRes
$ ENDIF
$ !
$ CALL Execute "''P5'"
$ IF AUD$Sev .GT. 1 THEN GOTO DSFail
$ CALL Execute "''P6'"
$ IF AUD$Sev .GT. 1 THEN GOTO DSFail
$ CALL Execute "''P7'"
$ IF AUD$Sev .GT. 1 THEN GOTO DSFail
$ CALL Execute "''P8'"
$ IF AUD$Sev .GT. 1 THEN GOTO DSFail
$ !
$DSAsk:
$ wso ""
$ prmpt = F$FAO( "[1m''P3'[0m", P1, minstep )
$ READ sys$command Answer /END_OF_FILE=DSDone /PROMPT="''prmpt'"
$ wso F$FAO( "!#*-!/", F$LENGTH(P3)+3 )
$ Answer = F$PARSE(Answer,"NO",,"NAME","SYNTAX_ONLY")
$ IF Answer
$ THEN result = Stp + Accept
$ ELSE result = Stp + Reject
$ ENDIF
$ GOTO DSRes
$ !
$DSFail:
$ ! An error-forced fail:
$ result = Stp + Reject
$ wso ""
$ msg1 = "An error in this test/step forces reject/failure..."
$ msg2 = F$FAO( "($STATUS/$SEVERITY: %X!XL/%X!1XL -!AS-)", F$INTEGER(AUD$Stat), AUD$Sev, AUD$Level )
$ wso F$FAO( "  !!>> [1m!AS[0m!/     !AS!/", msg1, msg2 )
$ READ sys$command Answer /END_OF_FILE=DSDone /PROMPT="''PromptSync'"
$ GOTO DSRes
$ !
$DSRes:
$ ! Primary output from DoStep is this global symbol AUD$Results:
$ IF AUD$Results .NES. ""
$ THEN AUD$Results == AUD$Results + SEP + result
$ ELSE AUD$Results == result
$ ENDIF
$DSDone:
$ EXIT 1
$ !
$DSCtrl_Y:
$ RETURN %X2C
