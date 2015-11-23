$ ! TYPESET$VUE.COM -- TeX/LaTeX typesetting                       'F$VERIFY(0)'
$ !
$ !  P1: [ LATEX | TEX ] (LaTeX or TeX selection)
$ !  P2: optional printer form name, no default
$ !      (provided by FileView verb command line)
$ !  P3: optional printer queue name, default = SYS$PRINT
$ !      (provided by FileView verb command line)
$ !  P4: T2VIEW (typeset only for display)
$ !
$ ON ERROR     THEN GOTO TaskError
$ ON CONTROL_Y THEN GOSUB CtrlY
$ LegalTypes = ".TEX.DVI.LN3"
$ LTlen      = F$LENGTH(LegalTypes)
$ T2view     = "$t2_view_image"
$ DELETE     = "DELETE"
$ PID        = F$GETJPI("","PID")
$ !
$ vue$get_symbol VUE$SHOW_HIDDEN_DIALOGS
$ vue$read ShowHidden
$ vue$suppress_output_popup
$ vue$get_selection_count
$ vue$read SelCount
$ IF SelCount .EQ. 0
$ THEN vue$popup_message "Please select a .TEX file to process"
$      GOTO Done
$ ENDIF
$ !
$ IF P1 .EQS. "" THEN P1 = "LaTeX"
$ DisplayOnly = ( P4 .EQS. "T2VIEW" )
$ !
$ CALL GetNextSel
$ IF TS$Sel .EQS. "" THEN GOTO Done
$ !
$ PrtQ = ""
$ IF P3 .NES. "" THEN PrtQ = "/QUEUE=''P3'"
$ IF P2 .NES. "" THEN PrtQ = "/FORM=''P2'"
$ PrtQ = PrtQ + " /DELETE /COPIES=1"
$ IF ShowHidden   !Did user use <Shift><MB#> to invoke menu choice?
$ THEN vue$inquire """PRINT ''TS$FN'.LN3"" ""''PrtQ'"""
$      vue$read PrtQ
$      IF PrtQ .EQS. "" THEN GOTO Done
$ ENDIF
$ !
$ vue$popup_progress_box
$Loop:
$ IF TS$Sel .NES. ""
$ THEN GOTO 'TS$FT'
$    TEX$:
$      vue$set_task_label "''P1' ''TS$FN'.TEX"
$      WRITE sys$output "''P1' ''TS$FN'.TEX"
$      SET PROCESS /ID='PID' /PRIORITY=3
$      'P1' 'TS$FN'  !TeX or LaTex
$      SET PROCESS /ID='PID' /PRIORITY=4
$    DVI$:
$      IF DisplayOnly
$      THEN vue$set_task_label "T2/view ''TS$FN'.DVI"
$           vue$popdown
$           T2view 'TS$FN'.dvi
$      ELSE vue$set_task_label "T2/script ''TS$FN'.DVI"
$           SET PROCESS /ID='PID' /PRIORITY=3
$           !But now using Northlake's T2_SCRIPT (8-Sep-95); LnTeX retired
$           T2 /OUTPUT='TS$FN'.ps 'TS$FN'.dvi
$           !LnTeX /OUTPUT='TS$FN' 'TS$FN'.dvi
$           SET PROCESS /ID='PID' /PRIORITY=4
$      ENDIF
$    PS$:
$    LN3$:
$      DELETE 'TS$FN'.lis;*
$      IF .NOT. DisplayOnly
$      THEN DELETE 'TS$FN'.dvi;*
$           vue$set_task_label "Print ''TS$FN'.ps & cleanup"
$           IF PrtQ .NES. ""
$           THEN PRINT /NOTIFY /PARAMETERS=(DATA_TYPE=POSTSCRIPT) 'PrtQ' 'TS$FN'.ps
$                IF $STATUS THEN vue$set_task_label "''TS$FN' submitted"
$           ENDIF
$      ENDIF
$ ENDIF
$L0:
$ SelCount = SelCount - 1
$ IF SelCount .LE. 0 THEN GOTO Update
$ CALL GetNextSel
$ GOTO Loop
$ !
$Update:
$ IF .NOT. ShowHidden THEN vue$popdown
$ vue$highlight_update
$ IF P2 .NES. "" -
  THEN vue$popup_message "Mount form ''P2' on printer."
$Done:
$ IF F$TYPE(TS$Sel) .NES. "" THEN DELETE /SYMBOL /GLOBAL TS$Sel
$ IF F$TYPE(TS$FN)  .NES. "" THEN DELETE /SYMBOL /GLOBAL TS$FN
$ IF F$TYPE(TS$FT)  .NES. "" THEN DELETE /SYMBOL /GLOBAL TS$FT
$ SET PROCESS /ID='PID' /PRIORITY=4  !(just in case)
$ EXIT
$ !
$TaskError:
$ vue$set_error_status
$ GOTO Done
$ !
$GetNextSel:  SUBROUTINE
$ vue$get_next_selection
$ vue$read Sel
$ TS$Sel == Sel
$ IF Sel .NES. ""
$ THEN TS$FN == F$PARSE(Sel,,,"NAME","SYNTAX_ONLY")
$         FT  = F$PARSE(Sel,,,"TYPE","SYNTAX_ONLY")
$      IF F$LOCATE(FT,LegalTypes) .LT. LTlen
$      THEN TS$FT == FT - "." + "$"
$      ELSE WRITE sys$output "%TYPESET$VUE-E-BADTYPE, unsupported file type ""''FT'"""
$      ENDIF
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE
$ !
$CtrlY:
$ RETURN %X0000002C
