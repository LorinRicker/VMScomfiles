$ ! SWITCH.COM -- switches context between parent/subprocesses
$ !
$ !   use:  @SWITCH [tag] [command]
$ !
$ ver = 'F$VERIFY(0)'
$ prv = F$SETPRV("NOGROUP,NOWORLD")  !see only this process-tree
$ ON ERROR THEN GOTO Err
$ IF p1 .EQS. "-S" THEN GOTO Sho
$ IF p1 .EQS. "" THEN  GOTO Par
$ pid  = F$INTEGER("%X" + F$GETJPI("","PID"))   !strip leading zeros
$ pn   = p1 + "_" + F$STRING(pid)               !"TAG_<parent_pid>"
$ ctxt = ""
$loop:
$ pid = F$PID(ctxt)
$ IF pid .EQS. "" THEN GOTO Cre
$ IF F$GETJPI(pid,"PRCNAM") .EQS. pn THEN GOTO Att
$ GOTO loop
$Cre:
$ DEFINE /USER_MODE sys$input  sys$command
$ SPAWN /LOG /PROCESS='pn' /INPUT=sys$command -
    'P2' 'P3' 'P4' 'P5' 'P6' 'P7' 'P8'
$ GOTO Done
$Par:
$ pn = "/IDENTIFICATION=''F$GETJPI("","MASTER_PID")'"
$Att:
$ ATTACH 'pn'
$Done:
$ prv = F$SETPRV(prv)
$ EXIT %X10000001 + ( 0 * 'F$VERIFY(ver)' )
$Sho:
$ SHOW PROCESS /SUBPROCESS
$ GOTO Done
$Err:
$ WRITE sys$error "%SWITCH-E, no such process ''pn'"
$ GOTO Done
