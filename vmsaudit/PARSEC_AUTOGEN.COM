$! My_autogen.com
$!
$! This procedure executesautogen.com and displays the report to the user
$! Along with a list of changed parameters
$! If the system has been up 14 days or more, it will save feedback information
$! And use it, otherwise it will use previously saved feedback information.
$!
$ define /user_mode sys$output sys$scratch:params.inf_old
$ mcr sysgen
use active
show/all
show/special
use current
write sys$scratch:vmssys.parsec
$!
$ call uptime
$ if uptime_days .ge. 14
$    then start = "savparams"
$    else start = "getdata"
$    endif
$ if p1 .nes. "" then start = p1
$ if start .nes. "NONE"
$ then
$	if p2 .eqs. "" then p2 = "setparams"
$	write sys$output "@sys$update:autogen ''start' ''p2' ''p3'"
$	svprv = f$setprv ("sysprv,cmkrnl")
$	@sys$update:autogen 'start' 'p2' 'p3'
$	svprv = f$setprv (svprv)
$ endif
$!
$ define /user_mode sys$output sys$scratch:params.inf_new
$ mcr sysgen
use current
show/all
show/special
$!
$ close /nolog in1
$ close /nolog in2
$ close /nolog out
$ open /read in1 sys$scratch:params.inf_new
$ open /read in2 sys$scratch:params.inf_old
$ open /write out sys$scratch:params.inf_dif
$ write out "Parameter name		  Old value  New value Difference    Default" 
$next_diff:
$ read in1 /end=done_diff rec1
$ read in2 rec2
$ if rec1 .eqs. rec2 then goto next_diff
$ if f$extract (2, 9, rec1) .eqs. "Parameter" then goto next_diff 
$ rec1 = f$edit (rec1, "trim")
$ pname = f$element (0, " ", rec1)
$ if pname .eqs. "internal" then goto next_diff 
$ mode = f$extract (f$length(rec1)-5, 5, rec1)
$ if mode .eqs. "Ascii"
$ then
$	pnew = f$edit (f$element (1, """", rec1), "trim")
$	pnew = f$extract (f$length(pnew), 10, "          " + pnew)
$	pdef = f$edit (f$element (3, """", rec1), "trim")
$	pdef = f$extract (f$length(pdef), 10, "          " + pdef)
$	pold = f$edit (f$element (1, """", rec2), "trim")
$	pold = f$extract (f$length(pold), 10, "          " + pold)
$	write out f$fao ("!24AS !10AS !10AS            !10AS", pname, pold, pnew, pdef)
$ else
$	rec1 = f$edit (rec1, "compress")
$	pnew = f$integer (f$element (1, " ", rec1))
$	pdef = f$interer (f$element (2, " ", rec1))
$	rec2 = f$edit (rec2, "trim,compress")
$	pold = f$integer (f$element (1, " ", rec2))
$	diff = f$fao ("!10SL", f$integer(pnew) - f$integer(pold))
$	write out f$fao ("!24AS !10UL !10UL !AS !10UL", pname, pold, pnew, diff, pdef)
$ endif
$ goto next_diff
$done_diff:
$ close in1
$ close in2
$ delete sys$scratch:params.inf_new;*
$ delete sys$scratch:params.inf_old;*
$ close out
$ if start .nes. "NONE" then -
  read sys$command recl/prompt="Press <RETURN> to review reports "
$ type /page=save sys$scratch:params.inf_dif,sys$system:agen$params.report
$ if start .nes. "NONE"
$ then
$	read sys$command recl/prompt="Do you wish to keep these changes [Y]? "
$	if recl .nes. "" .and. .not. recl
$	then
$		mcr sysgen
use sys$scratch:vmssys.parsec
write current
$	endif
$ endif
$ delete sys$scratch:params.inf_dif;*,sys$scratch:vmssys.parsec;*
$ exit
$!
$! Support routine
$uptime:
$ subroutine
$! UPTIME.COM
$!
$! This procedure gets system current uptime from a SHOW SYSTEM command
$! And stores the value in some global symbols.
$!
$ show system /output=uptime.dat
$ open /read /share=read inf uptime.dat
$!OpenVMS V6.2-1H3  on node PARIS   4-FEB-1999 10:11:36:.03  Uptime  10 18:48:48
$ read inf upt
$ close inf 
$ delete /nolog uptime.dat;*
$ x = f$locate ("Uptime", upt)
$ upt = f$extract (x+7, 9999, upt)
$ uptime == f$edit (upt, "trim,compress")
$ uptime_days == f$integer (f$element (0, " ", uptime))
$ x = f$element (0, ":", uptime)
$ uptime_hours == uptime_days * 24 + f$integer (f$element (1, " ", x))
$ if p1 .nes. "" then -
  write sys$output "''f$getsyi("nodename")' has been up ''uptime'"
$ exit
$ endsubroutine
