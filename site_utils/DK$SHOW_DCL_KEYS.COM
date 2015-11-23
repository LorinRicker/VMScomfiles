$ ! DK$SHOW_DCL_KEYS.COM -- structured listing of existing key definitions
$ !
$ ON CONTROL THEN GOTO endlist
$ !
$ full_flag = ""
$ IF p1 .NES. "" THEN full_flag = "/FULL"
$ !
$ SK_states = "SYS$SCRATCH:dk$show_keys.states"
$ SK_keys   = "SYS$SCRATCH:dk$show_keys.keys"
$ !
$ !SHOW KEY doesn't run an image, so /USER_MODE is wrong here...
$ ASSIGN /PROCESS 'SK_states' SYS$OUTPUT
$ SHOW KEY /DIRECTORY  !collect all currently defined key states
$ DEASSIGN /PROCESS SYS$OUTPUT
$ !
$ OPEN /READ  states  'SK_states'
$ OPEN /WRITE listing 'SK_keys'
$ !
$loop:
$ READ /END_OF_FILE=endlist states cur_state
$ ASSIGN /PROCESS listing SYS$OUTPUT
$ SHOW KEY /STATE='cur_state' /ALL 'full_flag'
$ DEASSIGN /PROCESS SYS$OUTPUT
$ WRITE listing ""
$ GOTO loop
$ !
$endlist:
$ CLOSE listing
$ CLOSE states
$ DELETE /NOLOG /NOCONFIRM 'SK_states';0
$ clr
$ TYPE 'SK_keys'
$ !
$ EXIT
$ !
