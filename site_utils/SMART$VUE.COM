$ ! SMART$VUE.COM -- DECwindows interface to E&R SMART Toolkit     'F$VERIFY(0)'
$ !
$ !  Provided by FileView verb command line:
$ !  P1: SMART option or command-list ( com1[|comN...] )
$ !  P2: "DISMISS"  (require user dismissal of popup box)
$ !      "PROGRESS" (display progress box)
$ !      "..."      (generate dialog box for user input)
$ !  P3: default response in dialog box
$ !
$ ON WARNING   THEN GOTO TaskError
$ ON CONTROL_Y THEN GOSUB CtrlY
$ !
$ P2 = F$EDIT(P2,"COLLAPSE,UPCASE")
$ Dialog   = ( F$LOCATE("...",P2) .LT. F$LENGTH(P2) )
$ IF Dialog THEN P2 = P2 - "..."
$ Dismiss  = "FALSE"    !Assume user-dismissal not needed
$ Progress = ( F$LOCATE("PROGRESS",P2) .LT. F$LENGTH(P2) )
$ IF Progress
$ THEN vue$popup_progress_box
$ ELSE vue$popup_focus
$      Dismiss = ( F$LOCATE("DISMISS",P2) .LT. F$LENGTH(P2) )  !User-dismissal?
$      @site$utils:cls LIGHT
$ ENDIF
$ !
$ SET = "SET"
$ SET MESSAGE site$utils:util_messages
$ @mgr$login
$ !
$ Sep = "|"
$ I = 0
$ParseLoop:
$ C'I' = F$ELEMENT(I,Sep,P1)
$ IF C'I' .EQS. Sep THEN GOTO Com
$ I = I + 1
$ GOTO ParseLoop
$ !
$Com:
$ I = 0
$ComLoop:
$ IF C'I' .EQS. Sep THEN GOTO Update
$ Command = C'I'
$ IF Dialog
$ THEN vue$inquire """''Command':"" ""''P3'"""
$      vue$read What
$      IF What .NES. ""
$      THEN Command = Command + " " + What
$      ELSE Dismiss = "FALSE"      !Empty What means user clicked Cancel-button
$           GOTO Done
$      ENDIF
$ ENDIF
$ DEFINE /USER_MODE sys$input sys$command
$ 'Command'                                             !SMART command
$ I = I + 1
$ GOTO ComLoop
$ !
$Update:
$ vue$update_fileview
$Done:
$ IF .NOT. Dismiss THEN vue$popdown
$ EXIT 1
$ !
$TaskError:
$ vue$popdown
$ vue$set_error_status
$ EXIT
$ !
$CtrlY:
$ RETURN %X0000002C
