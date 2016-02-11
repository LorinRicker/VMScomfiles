$ ! INFINITE.COM
$ !
$ ! The only way to terminate this loop is with Ctrl/Y or Ctrl/C --
$Loop:
$ write sys$output "this is a test"
$ GOTO Loop
$ EXIT
