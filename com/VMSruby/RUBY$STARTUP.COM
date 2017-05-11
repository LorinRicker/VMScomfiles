$ ! RUBY$STARTUP.COM                                               'F$VERIFY(0)'
$ !+
$ ! 05-Dec-2015
$ ! Startup file for RUBY 2.2.2 on OpenVMS
$ !
$ !   Suggested tweaks/mods - Lorin Ricker 18-Jan-2016
$ !     Making RUBY$SHR a known image costs
$ !     4 GBLSECTS and 12,752 GBLPAGES (currently);
$ !     installing this just to "see what happens"...
$ !   Add install of RUBY.EXE for performance improvement - LMR 11-May-2017
$ !-
$ !
$ set noon
$ !
$ file = f$search("sys$startup:ruby$define_logicals.com")
$ !
$ if file .eqs. ""
$ then
$    root = f$trnlmn("pcsi$destination")
$    if "''root'" .eqs. ""
$    then
$       write sys$output "The logical name RUBY$ROOT is not defined; check installation."
$       exit
$    endif
$ !
$    root = "''root'" - "]" + "ruby.]"
$    define /system /nolog /trans=concealed ruby$root 'root'
$    define /system /nolog ruby$shr ruby$root:[lib]ruby$shr.exe
$ else
$    @sys$startup:ruby$define_logicals.com
$ endif
$ !
$ if f$file_attributes("RUBY$SHR","KNOWN")
$ then install replace ruby$shr
$ else install add ruby$shr /open /header_res /share
$ endif
$ !
$ rubyexe = "RUBY$ROOT:[BIN]RUBY.EXE"
$ if f$file_attributes(rubyexe,"KNOWN")
$ then install replace 'rubyexe'
$ else install add 'rubyexe' /open /header_res /share
$ endif
$ !
$ exit
