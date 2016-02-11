$ ! MON_DISK.COM
$ !
$ ! The only way to terminate this output is with Ctrl/Y or Ctrl/C --
$L0:
$ SHOW DEVICE D /MOUNTED
$ WAIT 00:00:15
$ GOTO L0
$ EXIT
