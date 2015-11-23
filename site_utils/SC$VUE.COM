$ ! SC$VUE.COM -- DECwindows interface to E&R Source_Control       'F$VERIFY(0)'
$ !
$ !  P1: Source_Control command switches
$ !      (provided by FileView verb command line)
$ !          sc-AppUpd   (auv)
$ !          sc-Compare  (cv)
$ !          sc-DifUpd   (duv)
$ !          sc-Show     (sv)
$ !          sc-Update   (uv)
$ !
$ ON WARNING   THEN GOTO TaskError
$ ON CONTROL_Y THEN GOSUB CtrlY
$ !
$ SET MESSAGE site$utils:util_messages
$ sc = "@site$utils:source_control"
$ LibType = ".TLB"
$ OpCount = 0
$ !
$ P1 = F$EDIT(P1,"COLLAPSE,UPCASE")
$ P1L = F$LENGTH(P1)
$ LibOnly =      ( F$LOCATE("S",P1) .LT. P1L ) -  !Show
            .OR. ( F$LOCATE("L",P1) .LT. P1L ) -  !List
            .OR. ( F$LOCATE("H",P1) .LT. P1L ) -  !History
            .OR. ( F$LOCATE("K",P1) .LT. P1L )    !Kompress
$ IF F$LOCATE("V",P1) .LT. P1L
$ THEN vue$popup                !Verbose
$ ELSE vue$popup_progress_box   !Quiet
$ ENDIF
$ !
$ IF LibOnly
$ THEN SelCount = 1
$      vue$get_next_selection
$      vue$read Lib
$      Sel = ""
$ ELSE vue$get_selection_count
$      vue$read SelCount
$      IF SelCount .EQ. 0 THEN GOTO Done
$      FindLibLoop:
$        vue$get_next_selection
$        vue$read Sel
$        IF F$PARSE(Sel,,,"TYPE","SYNTAX_ONLY") .EQS. LibType
$        THEN Lib = Sel                 !Found a library in selected list
$             Sel = ""
$             GOTO DefineLib
$        ELSE IF Sel .NES. ""
$             THEN GOTO FindLibLoop     !Try next selected file
$             ELSE Lib = ""             !No library file found, use default
$                  Sel = ""
$                  GOTO DefineLib
$             ENDIF
$        ENDIF
$ ENDIF
$ !
$DefineLib:
$ IF F$PARSE(Lib,,,"TYPE","SYNTAX_ONLY") .EQS. LibType
$ THEN !Do the Lib-Operation on selected text library:
$      DEFINE /PROCESS /NOLOG source$library 'Lib'
$ ELSE !Must let SC command file find and define the /PROCESS logical name:
$      IF F$TRNLNM("source$library","LNM$PROCESS") .NES. "" -
       THEN DEASSIGN /PROCESS source$library
$ ENDIF
$ !
$ vue$reset_selections                  !Reset for file processing
$Loop:
$ IF .NOT. LibOnly
$ THEN vue$get_next_selection
$      vue$read Sel
$      !Don't operate recursively on the library itself:
$      IF F$PARSE(Sel,,,"TYPE","SYNTAX_ONLY") .EQS. LibType THEN GOTO Loop
$ ENDIF
$ IF ( Sel .NES. "" ) .OR. LibOnly
$ THEN sc 'P1' 'Sel'
$      OpCount = OpCount + 1
$ ENDIF
$ SelCount = SelCount - 1
$ IF SelCount .LE. 0 THEN GOTO Update
$ GOTO Loop
$ !
$Update:
$ vue$update_fileview
$Done:
$ IF OpCount .EQ. 0
$ THEN WRITE sys$output "%SC$VUE-W, no files selected for SC operation ""''P1'"""
$      WRITE sys$output "           SOURCE$LIBRARY = ""''F$TRNLNM("source$library")'"""
$ ENDIF
$ IF F$TRNLNM("source$library","LNM$PROCESS") .NES. "" -
  THEN DEASSIGN /PROCESS source$library
$ EXIT
$ !
$TaskError:
$ vue$set_error_status
$ GOTO Done
$ !
$CtrlY:
$ RETURN %X0000002C
