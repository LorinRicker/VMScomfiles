$ ! CONTEXT.COM -- subdirectory setups                             'F$VERIFY(0)'
$ !
$ WRITE sys$error "[CONTEXT ''p1']"
$ GOTO 'p1'
$ !
$in:
$ IF F$TRNLNM("ttk") .NES. "" THEN GOTO done
$ DEFINE = "DEFINE /NOLOG /PROCESS "
$ DEFINE ttk tpu$src:tpu_toolkit.tpu
$ tpudeb*ug == "EDIT /TPU /DEBUG"
$done:
$ EXIT
$ !
$out:
$ IF F$TRNLNM("source$library")   .NES. "" THEN DEASSIGN source$library
$ EXIT
