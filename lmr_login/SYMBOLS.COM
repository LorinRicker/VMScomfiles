$ ! SYMBOLS.COM - define personal commands                         'F$VERIFY(0)'
$ !
$ ! Copyright © 1999-2017 by Lorin Ricker.  All rights reserved, with acceptance,
$ ! use, modification and/or distribution permissions as granted and controlled
$ ! by and under the GPL described herein.
$ !
$ ! This program (software) is Free Software, licensed under the terms and
$ ! conditions of the GNU General Public License Version 3 as published by
$ ! the Free Software Foundation: http://www.gnu.org/copyleft/gpl.txt,
$ ! which is hereby incorporated into this software and is a non-severable
$ ! part thereof.  You have specific rights and obligations under this GPL
$ ! which are binding if and when you accept, use, modify and/or distribute
$ ! this software program (source code file) and/or derivatives thereof.
$ !
$ !    use:  @symbols [ REDEFINE | REFRESH | RELOGIN ]
$ !
$MAIN:
$ SET NOON
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ !
$ LMR$Unavailable == ""
$ !
$ ! ----------------------------------------------------------------------
$ ReLogin = ( F$EXTRACT( 0, 2, P1 ) .EQS. "RE" )  !REDEFINE, REFRESH, RELOGIN, RE-whatever
$ ! By convention/intent, DCL$SUBROUTINE_LIBRARY is here:
$ IF ( F$TYPE( DCL$CALL ) .EQS. "" ) .OR. ( ReLogin )
$ THEN @lmr$login:DCL$SUBROUTINE_LIBRARY Setup FALSE
$ ENDIF
$ ! ----------------------------------------------------------------------
$ !
$ VMSArchitecture = F$EDIT( F$GETSYI("ARCH_NAME"), "TRIM" )
$ VMSVersion      = F$EDIT( F$GETSYI("VERSION"), "TRIM" )
$ !
$ ! Nice-to-have abbreviations for the command line:
$ WSO == "WRITE sys$output"
$ SIN == "SEARCH sys$pipe"
$ !
$ !Setup a reasonable/traceable process name for multi-logins (not "_TNAxxx:")
$ PName = F$PROCESS()
$ UName = F$EDIT(F$GETJPI("","USERNAME"),"TRIM")
$ IF PName .NES. UName  !not the first/only login for this user?
$ THEN TName = F$TRNLNM("TT") - "_" - ":"
$      LName = UName
$      !Process name becomes "LName_TName" (15-char max):
$      ProcName = LName + "_" + TName
$      IF ( F$LENGTH( ProcName ) .GT. 15 ) THEN ProcName = ProcName - "L_"
$      IF ( F$LENGTH( ProcName ) .GT. 15 ) THEN ProcName = F$EXTRACT(0,4,ProcName) + "_" + TName
$      IF ProcName .NES. PName THEN SET PROCESS /NAME="''ProcName'"
$ ENDIF
$ !
$ LNode = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ IF F$TYPE(RED) .EQS. "STRING"
$ THEN LMR$promptstr == "''BOLD'''BLUE_BG'''WHITE'''LNode'''NORM'$ "
$      LMR$promptprv == "''BOLD'''RED_BG'''YELLOW'''LNode'''NORM'$ "
$ ELSE LMR$promptstr == "''LNode'$ "
$      LMR$promptprv == "[1m''LNode'[0m$ " !Priv prompt
$ ENDIF
$ !
$ IF ( F$TYPE(LMR_Name) .EQS. "" ) THEN LMR_Name = UName
$ parent == "ATTACH ""''F$PROCESS()'"""  !use whatever SET PROCESS set (not PName)
$ !
$ ! == Ruby ========================================================
$ !
$ ! Personal Ruby tools/scripts:
$ mkrubycmd ruby$mine:process.rb                  proc*ess     TRUE
$ mkrubycmd ruby$mine:bignum.rb                   big*num      TRUE
$ bn == bignum
$ mkrubycmd ruby$mine:tonerow.rb                  tone*row     TRUE
$ mkrubycmd ruby$mine:how-many-chords-on-piano.rb pianoch*ords TRUE
$ !
$ ! Create command aliases for interactive Ruby tools pry and irb:
$ IF ( F$TYPE( pry ) .EQS. "" ) THEN mkrubycmd ruby$root:[bin]pry.rb PRY TRUE
$ !!«» IF ( F$TYPE( irb ) .EQS. "" ) THEN mkrubycmd ruby$root:[lib.ruby.2^.2^.0]irb.rb IRB TRUE
$ !
$ ! ================================================================
$ !
$ ! System Manager:
$ vmsins*tall == "@root:login VMSINSTAL"
$ DCL$CALL Alias "dwho"           "@cmd:dclwho" "SHOW USERS"
$ DCL$CALL Alias "disks*pace"     "@com:diskspace$report" "SHOW DEVICE D /MOUNTED"
$ DCL$CALL Alias "diskl*imits"    "@com:disklimits$report"
$ DCL$CALL Alias "diski*nventory" "@com:diskinventory$report"
$ DCL$CALL Alias "diskm*enu"      "@com:diskmenu$report"
$ DCL$CALL Alias "boottime"       "@cmd:boottime.com"
$ break*in    == "SHOW INTRUSION /TYPE=ALL"
$ delbr*eakin == "DELETE /INTRUSION_RECORD"
$ !
$ IF F$TYPE(authorize) .EQS. ""
$ THEN IF F$TRNLNM( "sysuaf", "lnm$system" ) .NES. ""
$      THEN auth*orize == "$SYS$SYSTEM:AUTHORIZE"
$      ELSE auth*orize == "PIPE cd sys$system ; MCR AUTHORIZE"
$      ENDIF
$ ENDIF
$ !
$ IF F$TYPE(lancp)  .EQS. "" THEN lancp  == "$SYS$SYSTEM:LANCP"
$ IF F$TYPE(ncp)    .EQS. "" THEN ncp    == "$SYS$SYSTEM:NCP"
$ IF F$TYPE(ncl)    .EQS. "" THEN ncl    == "$SYS$SYSTEM:NCL"
$ IF F$TYPE(ping)   .EQS. "" THEN ping   == "$SYS$SYSTEM:TCPIP$PING"
$ IF F$TYPE(sysgen) .EQS. "" THEN sysgen == "$SYS$SYSTEM:SYSGEN"
$ IF F$TYPE(sysman) .EQS. "" THEN sysman == "$SYS$SYSTEM:SYSMAN SET ENV/CLU"
$ !
$ DCL$CALL Alias "priv*ilege"   "@com:privilege.com" "SET PROCESS /PRIVILEGE="
$ IF ( F$EXTRACT(0,1,privilege) .EQS. "@" )
$ THEN pow*er == "''privilege' ONE$SHOT"
$      sudo   == "''privilege' SUDO"  ! make a Linux-synonym too...
$ ENDIF
$!! $ DCL$CALL Alias "rid*manager"  "@mgr$command:rid$manager.com"
$ DCL$CALL Alias "spy"          "@com:showproc.com"
$!! $ DCL$CALL Alias "loop*iso"     "@com:loop$iso"
$!! $ DCL$CALL Alias "mcd"          "@com:cdrom"
$ !
$ ! ================================================================
$ !
$ ! Search & conditionally build zip/unzip symbols:
$ IF F$SEARCH("com:zips.com") .NES. "" THEN @com:zips  ! zip,gzip,unzip, etc.
$ !
$ ! DCL:
$ DCL$CALL Alias "cd"     "@com:cd" "SET DEFAULT"
$ DCL$CALL Alias "dco*nt" "@com:do_continuous"
$ ! Time how long to do something (once):
$ IF F$TYPE(time) .EQS. "" THEN time == "@com:do_continuous -n:1 -t:1"
$ !
$ IF ( VMSArchitecture .NES. "VAX" )
$ THEN dir == "DIRECTORY /SIZE /DATE /PROT /WIDTH=(FILENAME=24,SIZE=10)"  !Alpha, Itanium
$ ELSE dir == "DIRECTORY /SIZE /DATE /PROT /WIDTH=SIZE=7"
$ ENDIF
$ hdr == "DUMP /HEADER /BLOCK=COUNT=0"
$ ! For /EXCLUDE=():
$ XBin == "*.exe,*.mob,*.obj,*.pen,*.%lb"
$ XLog == "*.*log*,*.lis,*.tmp,*.txt"
$ XB   == "/EXCLUDE=(''XBin')"
$ XL   == "/EXCLUDE=(''XLog')"
$ !
$ DCL$CALL Alias "bell"       "@com:bell"
$ DCL$CALL Alias "count"      "@com:count"
$ DCL$CALL Alias "delsym"     "@com:delsymbol"
$ DCL$CALL Alias "ec*ode"     "@com:error_code"
$ DCL$CALL Alias "ps"         "@com:print_dcps"
$ DCL$CALL Alias "dbg"        "@com:vmsdebug"
$ DCL$CALL Alias "ofil*es"    "@com:file$openfiles"
$ DCL$CALL Alias "what*edit"  "@com:what_edit"
$ DCL$CALL Alias "keepa*live" "@com:do_continuous"
$ IF F$TYPE(keepalive) .EQS. "STRING" -
  THEN keepa*live == keepalive + " -w:120 ""TELL ''UName' """"Ping! (KeepAlive)"""""""
$ !
$ ! Useful with PIPEs
$ DCL$CALL Alias "tee" "@com:tee"
$ !
$ cftp         == "COPY /FTP /LOG"
$ glo*bal      == "SHOW SYMBOL /GLOBAL"
$ ftpcl8       == "ftp class8.parsec.com"
$ ssys*tem     == "PIPE SHOW SYSTEM | ''SIN' "  !requires a string-arg from user/cmd-line
$ SUBM*IT      == "SUBMIT /NOTIFY /NOPRINT /LOG_FILE=logs:"
$ !
$ ! Logicals:
$ lnm          == "SHOW LOGICAL /FULL /TABLE=LNM$FILE_DEV"
$!! $ DCL$CALL Alias "mkdir" "@com:makedir"
$!! $ ml*ogical == mkdir + " *"
$ !
$ LFull = ""
$ IF ( F$SEARCH( "sys$login:login_mini.com" ) .NES. "" ) THEN LFull = "_MINI"
$ IF ( F$SEARCH( "sys$login:login_full.com" ) .NES. "" ) THEN LFull = "_FULL"
$ reLog*in == "@SYS$LOGIN:LOGIN''LFull' RELOGIN"
$ DCL$CALL Alias "lo*gout" "@lmr$login:logout.com"  "LOGOUT /FULL"
$ !
$ qfind     == "PIPE SHOW QUEUE /ALL | ''SIN' /HIGHLIGHT=UNDERLINE"
$ qidle     == "PIPE SHOW QUEUE /ALL | ''SIN' /HIGHLIGHT=UNDERLINE idle,started"
$ qstal*led == "PIPE SHOW QUEUE /ALL | ''SIN' /HIGHLIGHT=UNDERLINE stopped,stalled,paused "
$ !
$ clu = ""
$ IF F$GETSYI("CLUSTER_MEMBER") THEN clu = "/CLUSTER"
$ clupt*ime == "PIPE SHOW SYSTEM ''clu'/NOPROCESS /FULL | SEARCH /HIGHLIGHT=UNDERLINE /WINDOW=(1,2) sys$pipe uptime"
$ upt*ime   == "PIPE uptm$ = F$DELTA_TIME( F$GETSYI(""BOOTTIME""), F$TIME(), ""ASCTIM"" ) ; WRITE sys$output uptm$"
$ DCL$CALL Alias "boot*time" "@com:bootttime.com"
$ !
$ ai        == "ANALYZE /IMAGE /SELECT=(ARCH,IMAGE_TYPE,IDENT=IMAGE,NAME)"
$ err*orlog == "ANALYZE /ERROR "
$ IF ( VMSArchitecture .NES. "VAX" )
$ THEN IF ( VMSVersion .GES. "V7.3" )
$      THEN err*orlog == "ANALYZE /ERROR /ELV TRANSLATE "   ! for Alpha/Itanium VMS >= v7.3
$      ENDIF
$ ENDIF
$ !
$ ! Define commands for REBOOT/SHUTDOWN, LOGINS/NOLOGINS, etc.
$ F = "lmr$login:smart$shutdown.com"
$ IF ( F$SEARCH( F ) .NES. "" ) THEN -
    @'F' COMMANDS
$ !
$ IF F$SEARCH("lmr$login:show_cluster$init.ini") .NES. ""
$ THEN DEFINE /PROCESS /SUPERVISOR /NOLOG show_cluster$init lmr$login:show_cluster$init.ini
$      sclu*ster == "SHOW CLUSTER /CONTINUOUS"
$ ENDIF
$ !
$ IF F$SEARCH("com:where.com") .NES. ""
$ THEN DCL$CALL Alias "where" "@com:where.com"
$ ELSE CZ    == ""
$      where == wso + "F$FAO(""!AS!AS !6* (prev: !AS)"""   -
              +              ",F$TRNLNM(""SYS$NODE"")"     -
              +              ",F$ENVIRONMENT(""DEFAULT"")" -
              +              ",CZ)"
$ ENDIF
$ !
$ ! ================================================================
$ !
$ IF F$SEARCH( "com:file$setup.com" ) .NES. ""      !the FILE$* group
$ THEN @com:file$setup 'P1'
$ ELSE DCL$CALL Alias "chk"          "@com:file$compare"
$      IF F$TYPE(chk) .EQS. "STRING" -
       THEN chk == chk - ".COM" - " CHECK" + " CHECK"
$      DCL$CALL Alias "comp*are"     "@com:file$compare"
$      IF F$TYPE(compare) .EQS. "STRING" -
       THEN comp*are == compare - ".COM" - " COMPARE" + " COMPARE"
$      DCL$CALL Alias "frep*lace"    "@com:file$edit"
$      IF F$TYPE(freplace) .EQS. "STRING" -
       THEN frep*lace == freplace - ".COM" - " FINDREPLACE" + " FINDREPLACE"
$      DCL$CALL Alias "chop"         "$com:chop"
$      DCL$CALL Alias "clean*up"     "@com:file$cleanup"
$      chksum == "CHECKSUM /ALGORITHM=MD5 /SHOW=ALL"
$      DCL$CALL Alias "csum"         "@com:file$checksum"  "''chksum'"
$      DCL$CALL Alias "fat*tributes" "@com:file$attributes"
$      DCL$CALL Alias "fc*ompare"    "@com:file$compare"   "DIFFERENCES /PARALLEL"
$      DCL$CALL Alias "fcou*nt"      "$com:filecount"
$      DCL$CALL Alias "fix"          "@com:file$edit"
$      DCL$CALL Alias "fli*st"       "@com:file$preplist"
$      DCL$CALL Alias "mov*e"        "@com:file$move"      "RENAME /LOG"
$      DCL$CALL Alias "prot*ect"     "@com:file$protect"
$      DCL$CALL Alias "slice"        "$com:slice"
$      DCL$CALL Alias "sscon*vert"   "@com:file$ssconvert"
$      DCL$CALL Alias "tail"         "$com:tail"
$      DCL$CALL Alias "tool*sdebug"  "@com:tools$debug"
$      DCL$CALL Alias "untang*le"    "@com:file$untangle"
$      DCL$CALL Alias "xf*er"        "@com:file$xfer"
$      DCL$CALL Alias "xftp"         "@com:file$ftp"
$ ENDIF
$ !
$ ! Logicals:
$ DCL$CALL Alias "md*ir"     "@com:makedir"
$ ml*ogical == mdir + " *"
$ lnm == "SHOW LOGICAL /FULL /TABLE=LNM$FILE_DEV "
$ !
$ ! Tools:
$ DCL$CALL Alias "cap*ture"    "@com:capture.com"     !capture SYS$OUTPUT to file
$ DCL$CALL Alias "day*s"       "$site$utils:dc$datecalc"
$ DCL$CALL Alias "deltree"     "@site$utils:deltree"
$ DCL$CALL Alias "flush"       "@com:flushscr.com"
$ DCL$CALL Alias "key*words"   "@site$utils:sql$keywords.com"
$ DCL$CALL Alias "sc*ontrol"   "@site$utils:source_control.com"
$ DCL$CALL Alias "tcom"        "@com:typecom.com"
$ DCL$CALL Alias scr*width     "@com:scrwidth.com"
$ tlr == "LIBR /TEXT /REPLACE /LOG"
$ !
$ IF ( F$TYPE(sql) .EQS. "" ) .AND. ( F$SEARCH("site$utils:rapt_tools.com") .NES. "" ) -
  THEN @site$utils:rapt_tools
$ !
$ ! ================================================================
$ !
$ ! GNU:
$ IF ( F$TYPE(gawk) .NES. "STRING" ) .OR. ( F$TYPE(grep) .NES. "STRING" )
$ THEN IF F$TRNLNM("GNU$login") .NES. "" THEN @GNU$login
$ ENDIF
$ !
$ ! Kermit:
$ IF F$TYPE(Kermit) .NES. "STRING"
$ THEN IF F$TRNLNM("kermit$login") .NES. "" THEN @kermit$login
$ ENDIF
$ !
$ !! $ ! Netscape Navigator:
$ !! $ IF F$TYPE(Navigator) .NES. "STRING"
$ !! $ THEN IF F$TRNLNM("netscape$login") .NES. "" THEN @netscape$login
$ !! $ ENDIF
$ !! $ !
$ !
$ !! $ ! Smart SetHost:
$ !! $ F = "site$utils:smart$sethost.com"
$ !! $ IF F$SEARCH(F) .NES. "" THEN @'F' $LOGIN
$ !
$ !! $ ! Dungeon:
$ !! $ IF F$TYPE(Dungeon) .NES. "STRING"
$ !! $ THEN IF F$TRNLNM("dungeon$login") .NES. "" THEN @dungeon$login
$ !! $ ENDIF
$ !
$ ! ================================================================
$ !
$ ! PARSEC --
$ IF ( LNode .EQS. "CLASS8" )
$ THEN IF Verbose THEN wso "%SYMBOLS-I-''LNode', alias ""kitkosh"""
$      kitkosh == "ssh 40.129.101.176"
$ ENDIF
$ IF ( LNode .EQS. "VMSPR3" )
$ THEN IF Verbose THEN wso "%SYMBOLS-I-''LNode', tapes* command aliases --"
$      tapesall  == "PIPE MDMS SHOW VOLUME | SORT /KEY=(POS:10,SIZ:10,ASC) /KEY=(POS:1,SIZ:6,ASC)" -
                  + " sys$pipe sys$scratch:all.tapes" -
                  + " ; TYPE /PAGE sys$scratch:all.tapes"
$      tapesfree == "PIPE MDMS SHOW VOLUME | ''SIN' free " -
                  + "| SORT /KEY=(POS:1,SIZ=7,ASC) sys$pipe sys$scratch:free.tapes" -
                  + " ; TYPE /PAGE sys$scratch:free.tapes"
$      tapesfind == "PIPE MDMS SHOW VOLUME | ''SIN' transit,alloc " -
                  + "| SORT /KEY=(POS:1,SIZ=7,ASC) sys$pipe sys$scratch:find.tapes" -
                  + " ; TYPE /PAGE sys$scratch:find.tapes"
$      IF Verbose THEN SHOW SYMBOL /GLOBAL tapes*
$ ENDIF
$ IF ( LNode .EQS. "VMSPR3" )
$ THEN IF Verbose THEN wso "%SYMBOLS-I-''LNode', license/PAK command alias --"
$      mklic*ensepg == "@user_disk:[williams]pg_license"
$      IF Verbose THEN SHOW SYMBOL /GLOBAL mklic*
$ ENDIF
$ !
$ ! ================================================================
$ !
$Done:
$ IF ( F$TYPE(LMR$Unavailable) .NES. "" )
$ THEN IF ( LMR$Unavailable .NES. "" )
$      THEN WRITE sys$output ""
$           WRITE sys$output "%SYMBOLS-W-UNAVAIL_COM, these DCL command symbols are unavailable:"
$           SHOW SYMBOL /GLOBAL LMR$Unavailable
$           WRITE sys$output ""
$      ENDIF
$ ENDIF
$ EXIT
$ !
