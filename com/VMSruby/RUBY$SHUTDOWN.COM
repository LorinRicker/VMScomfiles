$ ! RUBY$SHUTDOWN.COM
$ !+
$ ! 05-Dec-2015
$ ! Startup file for RUBY 2.2.2 on OpenVMS
$ !
$ ! 20-Jan-2016
$ ! Included modifications suggested by Lorin Ricker to include commands
$ ! to install ruby$shr if so desired. By default these commands are
$ ! commented out (user discretion). Be aware that making ruby$shr a known
$ ! image costs 4 GBLSECTS and 12,752 GBLPAGES (currently).
$ !-
$
$ verify = f$verify(0)
$ set noon
$
$! Cleanup logical names...
$!
$!! if f$file_attributes("RUBY$SHR","KNOWN")
$!! then
$!!    install remove ruby$shr
$!! endif
$
$ if f$trnlnm("RUBY$SHR", "LNM$SYSTEM_TABLE") .nes. ""
$ then
$    deassign/sys RUBY$SHR
$ endif
$
$ if f$trnlnm("RUBY$ROOT", "LNM$SYSTEM_TABLE") .nes. ""
$ then
$    deassign/sys RUBY$ROOT
$ endif
$
$ exit
