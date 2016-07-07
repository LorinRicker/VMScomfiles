$! VMSMAIL_PROFILE.COM		Hein van den Heuvel, May-1996
$!
$! Decodes VMSmail Profile records for selected (P1) or for all users

$ on control_y then goto done
$ x = f$parse("vmsmail_profile","sys$system:.data")
$ open/read/share=write vmsmail 'x
$ codes = "/  Newmail/    Flags/Directory/  Forward/Pers Name//Transport" + -
	  "/   Editor/    Queue/         /     Form"
$ flags = "CopySend/CopyReply/NO_AutoPurge/CopyForw/CC"
$record_loop:
$   if p1.eqs.""
$       then read/end=done vmsmail rec
$       else read/end=done/key=&P1 vmsmail rec
$   endif
$   write sys$output f$extr(0,31,rec)
$   rest = f$extr(31,999,rec)
$field_loop:
$   if f$len(rest) .le. 4
$     then
$	if p1.nes."" then goto done
$	goto record_loop
$   endif
$   cod  = f$cvui ( 0 ,  16, rest )
$   len  = f$cvui ( 16,  16, rest )
$   dat  = f$extr (  4, len, rest )
$   rest = f$extr ( 4 + len, 999, rest )
$   if cod.gt.2 then txt = dat
$   if cod.eq.1 then txt = f$string(f$cvui (0,len*8, dat))
$   if cod.eq.2
$     then
$	txt = ""
$	len = f$cvui (0,len*8, dat)
$	bit = 0
$bit_loop:
$	nam = f$elem(bit,"/",flags)
$	if nam.eqs."/" then goto end_flags
$	txt = txt + " " + nam + "=" + f$extr(f$cvsi(bit,1,dat).eq.0,1,"NY")
$	bit = bit + 1
$	goto bit_loop
$end_flags:
$    endif
$    write sys$output f$fao("!2UL !10AS (!2UL) !AS",-
		cod, f$elem(cod,"/",codes), len, txt)
$    goto field_loop
$done:
$close vmsmail
$exit
