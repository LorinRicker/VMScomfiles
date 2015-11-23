$ ! MAKE$VUE.COM -- DECwindows interface to E&R Make Utility       'F$VERIFY(0)'
$ !
$ !  P1: Make (build) command switches
$ !      (provided by FileView verb command line)
$ !          make        (-v)
$ !          make-all    (-va)
$ !          make-debug  (-vx)
$ !          make-strong (-s)
$ !
$ ON WARNING   THEN GOTO TaskError
$ ON CONTROL_Y THEN GOSUB CtrlY
$ !
$ vue$get_selection_count
$ vue$read SelCount
$ IF SelCount .EQ. 0 THEN GOTO Done
$ SET MESSAGE site$utils:util_messages
$ make = "@site$utils:make"
$ P1 = F$EDIT(P1,"COLLAPSE,UPCASE")
$ IF F$LOCATE("V",P1) .LT. F$LENGTH(P1)
$ THEN vue$popup                !Verbose
$ ELSE vue$popup_progress_box   !Quiet
$ ENDIF
$ !
$Loop:
$ vue$get_next_selection
$ vue$read Sel
$ MakeFile = F$PARSE(Sel,"sys$disk:[]")
$ Strip    = F$PARSE(MakeFile,,,"TYPE","SYNTAX_ONLY")    -
           + F$PARSE(MakeFile,,,"VERSION","SYNTAX_ONLY")
$ MakeFile = MakeFile - Strip
$ make 'MakeFile' -'P1'
$ SelCount = SelCount - 1
$ IF SelCount .LE. 0 THEN GOTO Update
$ GOTO Loop
$ !
$Update:
$ vue$update_fileview
$Done:
$ EXIT
$ !
$TaskError:
$ vue$set_error_status
$ EXIT
$ !
$CtrlY:
$ RETURN %X0000002C
