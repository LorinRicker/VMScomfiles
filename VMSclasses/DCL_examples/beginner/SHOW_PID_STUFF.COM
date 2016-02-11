$ ! SHOW_PID_STUFF.COM --                                          'F$VERIFY(0)'
$ !
$ ctx = ""
$LOOP:
$ pid = F$PID(ctx)
$ IF pid .NES. ""
$ THEN WRITE sys$output F$FAO( "!/PID: !XL", pid )
$      WRITE sys$output "Username: ''F$EDIT(F$GETJPI(pid,"USERNAME"),"TRIM")'"
$      WRITE sys$output "Procname: ''F$GETJPI(pid,"PRCNAM")'"
$      GOTO LOOP
$ ENDIF
$ EXIT
