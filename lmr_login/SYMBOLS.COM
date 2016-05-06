$ ! SYMBOLS.COM - define personal commands                         'F$VERIFY(0)'
$ !
$ ! Copyright © 1999-2016 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ !    use:  @symbols [ REDEFINE | REFRESH ]
$ !
$CDefine:  SUBROUTINE
$ ! P1 : command symbol
$ ! P2 : command file
$ ! P3 : alternate command string
$ IF F$LOCATE("*",P1) .LT. F$LENGTH(P1)
$ THEN AbbrSym = F$ELEMENT(0,"*",P1)
$ ELSE AbbrSym = P1
$ ENDIF
$ FullSym = P1 - "*"
$ IF F$TYPE('AbbrSym') .EQS. "STRING"  !command symbol already exists?
$ THEN IF Redefine
$      THEN DELETE /SYMBOL /GLOBAL 'AbbrSym'
$           GOTO CDef1
$      ELSE IF Verbose THEN wso "%SYMBOLS-W-NOREDEFINE, command symbol ""''P1'"" already exists"
$           EXIT 1
$      ENDIF
$ ENDIF
$CDef1:
$ P2 = F$EDIT(P2,"UPCASE")
$ IF F$EXTRACT(0,1,P2) .EQS. "$" THEN P2 = P2 - "$" - ".EXE" + ".EXE"
$ IF F$EXTRACT(0,1,P2) .EQS. "@" THEN P2 = P2 - "@" - ".COM" + ".COM"
$ IF F$SEARCH(P2) .NES. ""
$ THEN IF F$PARSE(P2,,,"TYPE","SYNTAX_ONLY") .EQS. ".EXE"
$      THEN 'P1' == "$''P2'"
$      ELSE 'P1' == "@''P2'"
$      ENDIF
$      IF Verbose THEN SHOW SYMBOL /GLOBAL 'FullSym'
$ ELSE IF ( P3 .NES. "" )
$      THEN 'P1' == "''P3'"  ! alternate (default DCL) command
$      ELSE IF LMR$Unavailable .EQS. ""
$           THEN LMR$Unavailable == FullSym
$           ELSE LMR$Unavailable == LMR$Unavailable + ", " + FullSym
$           ENDIF
$           IF Verbose THEN SHOW SYMBOL /LOCAL P1
$           IF Verbose THEN SHOW SYMBOL /LOCAL P2
$      ENDIF
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! CDefine
$ !
$ !
$MAIN:
$ SET NOON
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ Redefine = ( F$EXTRACT(0,2,P1) .EQS. "RE" )  !REDEFINE, REFRESH, RE-whatever
$ !
$ VMSArchitecture = F$EDIT( F$GETSYI("ARCH_NAME"), "TRIM" )
$ VMSVersion      = F$EDIT( F$GETSYI("VERSION"), "TRIM" )
$ !
$ ! Nice-to-have abbreviations for the command line:
$ WSO == "WRITE sys$output"
$ SIN == "SEARCH sys$input"
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
$ THEN LMR$promptstr == "''BOLD'''PURPLE_BG'''WHITE'''LNode'''NORM'$ "
$      LMR$promptprv == "''BOLD'''RED_BG'''YELLOW'''LNode'''NORM'$ "
$ ELSE LMR$promptstr == "''LNode'$ "
$      LMR$promptprv == "[1m''LNode'[0m$ " !Priv prompt
$ ENDIF
$ !
$ IF ( F$TYPE(LMR_Name) .EQS. "" ) THEN LMR_Name = UName
$ parent == "ATTACH ""''F$PROCESS()'"""  !use whatever SET PROCESS set (not PName)
$ !
$ ! System Manager:
$ vmsins*tall == "@root:login VMSINSTAL"
$ !establish symbol before mgr$login:
$ IF F$TYPE(dwho)     .EQS. "" THEN CALL CDefine "dwho"     "@mgr$command:dclwho"
$ IF F$TYPE(boottime) .EQS. "" THEN CALL CDefine "boottime" "@mgr$command:boottime.com"
$ IF F$TYPE(breakin)  .EQS. ""
$ THEN CALL CDefine "break*in" "@mgr$command:breakin.com"
$      IF F$TYPE(breakin)  .EQS. ""  !mgr$command:breakin.com not found?
$      THEN break*in    == "SHOW INTRUSION /TYPE=ALL"
$           delbreak*in == "DELETE /INTRUSION_RECORD"
$      ENDIF
$ ENDIF
$ IF F$TYPE(authorize) .EQS. "" THEN auth*orize == "$SYS$SYSTEM:AUTHORIZE"
$ IF F$TYPE(sysgen)    .EQS. "" THEN sysgen     == "$SYS$SYSTEM:SYSGEN"
$ IF F$TYPE(sysman)    .EQS. "" THEN sysman     == "$SYS$SYSTEM:SYSMAN SET ENV/CLU"
$ IF F$TYPE(lancp)     .EQS. "" THEN lancp      == "$SYS$SYSTEM:LANCP"
$ IF F$TYPE(ncp)       .EQS. "" THEN ncp        == "$SYS$SYSTEM:NCP"
$ IF F$TYPE(ncl)       .EQS. "" THEN ncl        == "$SYS$SYSTEM:NCL"
$ IF F$TYPE(ping)      .EQS. "" THEN ping       == "UCX PING"
$ !
$ CALL CDefine "lo*gout"      "@lmr$login:logout.com"
$ CALL CDefine "priv"         "@com:privilege.com"
$ CALL CDefine "pow*er"       "@com:privilege.com"
$ IF F$TYPE(power) .EQS. "STRING"
$ THEN pow*er == power - ".COM" - " ONE$SHOT" + " ONE$SHOT"
$      sudo   == "''power'"   ! make a Linux-synonym too...
$ ENDIF
$ CALL CDefine "rid*manager"  "@mgr$command:rid$manager.com"
$ CALL CDefine "spy"          "@com:showproc.com"
$ CALL CDefine "loop*iso"     "@com:loop$iso"
$ !!CALL CDefine "mcd"          "@com:cdrom"
$ !
$ IF F$SEARCH("com:zips.com") .NES. "" THEN @com:zips  ! zip,gzip,unzip, etc.
$ !
$ ! DCL:
$ CALL CDefine "cd"        "@com:cd"
$ CALL CDefine "dco*nt"    "@com:do_continuous"
$ ! Time how long to do something (once):
$ IF F$TYPE(time) .EQS. "" THEN time == "@com:do_continuous -n:1 -t:1"
$ !
$ IF ( VMSArchitecture .NES. "VAX" )
$ THEN dir == "DIRECTORY /ACL /SIZE /DATE /PROT /WIDTH=(FILENAME=24,SIZE=10)"  !Alpha, Itanium
$ ELSE dir == "DIRECTORY /ACL /SIZE /DATE /PROT /WIDTH=SIZE=7"
$ ENDIF
$ hdr == "DUMP /HEADER /BLOCK=COUNT=0"
$ ! For /EXCLUDE=():
$ XBin == "*.exe,*.mob,*.obj,*.pen,*.%lb"
$ XLog == "*.*log*,*.lis,*.tmp,*.txt"
$ XB   == "/EXCLUDE=(''XBin')"
$ XL   == "/EXCLUDE=(''XLog')"
$ !
$ esc[0,32]= %X1B
$ esc[0,1]:= 'esc'
$ _clrscr  == esc + "[m" + esc + "[H" + esc + "[2J"
$ _clrscrL == esc + "[?5h" !light
$ _clrscrD == esc + "[?5l" !dark
$ clr      == "WRITE sys$output _clrscr"
$ !
$ CALL CDefine "bell"       "@com:bell"
$ CALL CDefine "count"      "@com:count"
$ CALL CDefine "delsym"     "@com:delsymbol"
$ CALL CDefine "ec*ode"     "@com:error_code"
$ CALL CDefine "ps"         "@com:print_dcps"
$ CALL CDefine "dbg"        "@com:vmsdebug"
$ CALL CDefine "ofil*es"    "@com:file$openfiles"
$ CALL CDefine "what*edit"  "@com:what_edit"
$ CALL CDefine "keepa*live" "@com:do_continuous"
$ IF F$TYPE(keepalive) .EQS. "STRING" -
  THEN keepa*live == keepalive + " -w:120 ""TELL ''UName' """"Ping! (KeepAlive)"""""""
$ !
$ ! Useful with PIPEs
$ CALL CDefine "tee" "@com:tee"
$ !
$ ai           == "ANALYZE /IMAGE /SELECT=(ARCH,IMAGE_TYPE,IDENT=IMAGE,NAME)"
$ cftp         == "COPY /FTP /LOG"
$ chksum       == "CHECKSUM /ALGORITHM=MD5 /SHOW=ALL"
$ dsk*s        == "SHOW DEVICE /MOUNTED D"
$ glo*bal      == "SHOW SYMBOL /GLOBAL"
$ lnm          == "SHOW LOGICAL /FULL /TABLE=LNM$FILE_DEV"
$ ftpcl8       == "ftp class8.parsec.com"
$ ssys*tem     == "PIPE SHOW SYSTEM | ''SIN' "  !requires a string-arg from user/cmd-line
$ reLog*in     == "@sys$login:login"
$ SUBM*IT      == "SUBMIT /NOTIFY /NOPRINT /LOG_FILE=logs:"
$ !
$ qidle        == "PIPE SHOW QUEUE /ALL | ''SIN' idle,started /HIGHLIGHT=UNDERLINE"
$ qstal*led    == "PIPE SHOW QUEUE /ALL | ''SIN' stopped,stalled,paused /HIGHLIGHT=UNDERLINE"
$ !
$ auth     == "MCR AUTHORIZE"
$ ping     == "$SYS$SYSTEM:TCPIP$PING"
$ sysman   == "MCR SYSMAN"
$ sysgen   == "MCR SYSGEN"
$ !
$ clu = ""
$ IF F$GETSYI("CLUSTER_MEMBER") THEN clu = "/CLUSTER"
$ upt*ime      == "PIPE SHOW SYSTEM ''clu'/NOPROCESS /FULL | SEARCH /HIGHLIGHT=UNDERLINE /WINDOW=(1,2) sys$input uptime"
$ !
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
$ THEN CALL CDefine "where" "@com:where.com"
$ ELSE CZ == ""
$      where == "WRITE sys$output F$FAO(""!AS!AS !6* (prev: !AS)"""   -
              +                         ",F$TRNLNM(""SYS$NODE"")"     -
              +                         ",F$ENVIRONMENT(""DEFAULT"")" -
              +                         ",CZ)"
$ ENDIF
$ !
$ IF F$SEARCH("site$utils:file$setup.com") .NES. ""      !the FILE$* group
$ THEN @site$utils:file$setup 'P1'
$ ELSE CALL CDefine "chk"          "@com:file$compare"
$      IF F$TYPE(chk) .EQS. "STRING" -
       THEN chk == chk - ".COM" - " CHECK" + " CHECK"
$      CALL CDefine "comp*are"     "@com:file$compare"
$      IF F$TYPE(compare) .EQS. "STRING" -
       THEN comp*are == compare - ".COM" - " COMPARE" + " COMPARE"
$      CALL CDefine "frep*lace"    "@com:file$edit"
$      IF F$TYPE(freplace) .EQS. "STRING" -
       THEN frep*lace == freplace - ".COM" - " FINDREPLACE" + " FINDREPLACE"
$      CALL CDefine "chop"         "$com:chop"
$      CALL CDefine "clean*up"     "@com:file$cleanup"
$      CALL CDefine "csum"         "@com:file$checksum"
$      CALL CDefine "fat*tributes" "@com:file$attributes"
$      CALL CDefine "fc*ompare"    "@com:file$compare"
$      CALL CDefine "fcou*nt"      "$com:filecount"
$      CALL CDefine "fix"          "@com:file$edit"
$      CALL CDefine "fli*st"       "@com:file$preplist"
$      CALL CDefine "mov*e"        "@com:file$move"
$      CALL CDefine "prot*ect"     "@com:file$protect"
$      CALL CDefine "slice"        "$com:slice"
$      CALL CDefine "sscon*vert"   "@com:file$ssconvert"
$      CALL CDefine "tail"         "$com:tail"
$      CALL CDefine "tool*sdebug"  "@com:tools$debug"
$      CALL CDefine "untang*le"    "@com:file$untangle"
$      CALL CDefine "xf*er"        "@com:file$xfer"
$      CALL CDefine "xftp"         "@com:file$ftp"
$ ENDIF
$ !
$ ! Logicals:
$ CALL CDefine "md*ir"     "@com:makedir"
$ ml*ogical == mdir + " *"
$ lnm == "SHOW LOGICAL /FULL /TABLE=LNM$FILE_DEV "
$ !
$ ! Dungeon:
$ IF F$TYPE(Dungeon) .NES. "STRING"
$ THEN IF F$TRNLNM("dungeon$login") .NES. "" THEN @dungeon$login
$ ENDIF
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
$ ! Netscape Navigator:
$ IF F$TYPE(Navigator) .NES. "STRING"
$ THEN IF F$TRNLNM("netscape$login") .NES. "" THEN @netscape$login
$ ENDIF
$ !
$ ! Smart SetHost:
$ F = "site$utils:smart$sethost.com"
$ IF F$SEARCH(F) .NES. "" THEN @'F' $LOGIN
$ !
$ ! Tools:
$ CALL CDefine "cap*ture"    "@com:capture.com"     !capture SYS$OUTPUT to file
$ CALL CDefine "day*s"       "$site$utils:dc$datecalc"
$ CALL CDefine "flush"       "@com:flushscr.com"
$ CALL CDefine "key*words"   "@site$utils:sql$keywords.com"
$ CALL CDefine "sc*ontrol"   "@site$utils:source_control.com"
$ CALL CDefine "tcom"        "@com:typecom.com"
$ CALL CDefine scr*width     "@com:scrwidth.com"
$ tlr == "LIBR /TEXT /REPLACE /LOG"
$ !
$ IF ( F$TYPE(sql) .EQS. "" ) .AND. ( F$SEARCH("site$utils:rapt_tools.com") .NES. "" ) -
  THEN @site$utils:rapt_tools
$ !
$ ! PARSEC --
$ IF ( LNode .EQS. "VMSPR3" )
$ THEN wso ""
$      wso "%SYMBOLS-I-''LNode', tapes* command aliases --"
$      tapesall  == "PIPE MDMS SHOW VOLUME | SORT /KEY=(POS:12,SIZ:10,ASC) /KEY=(POS:1,SIZ:6,ASC)" -
                  + " sys$input sys$scratch:all.tapes" -
                  + " ; TYPE /PAGE sys$scratch:all.tapes"
$      tapesfree == "PIPE MDMS SHOW VOLUME | ''SIN' free " -
                  + "| SORT /KEY=(POS:26,SIZ=14,DESC) sys$input sys$scratch:free.tapes" -
                  + " ; TYPE /PAGE sys$scratch:free.tapes"
$      tapesfind == "PIPE MDMS SHOW VOLUME | ''SIN' transit,alloc " -
                  + "| SORT /KEY=(POS:26,SIZ=14,ASC) sys$input sys$scratch:find.tapes" -
                  + " ; TYPE /PAGE sys$scratch:find.tapes"
$      SHOW SYMBOL /GLOBAL tapes*
$ ENDIF
$ IF ( LNode .EQS. "VMSPR3" )
$ THEN wso ""
$      wso "%SYMBOLS-I-''LNode', license/PAK command alias --"
$      mklic*ensepg == "@user_disk:[williams]pg_license"
$      SHOW SYMBOL /GLOBAL mklic*
$ ENDIF
$ !
$Done:
$ IF F$TYPE(LMR$Unavailable) .NES. ""
$ THEN IF LMR$Unavailable .NES. ""
$      THEN WRITE sys$output ""
$           WRITE sys$output "%SYMBOLS-W-UNAVAIL_COM, these DCL command symbols are unavailable:"
$           SHOW SYMBOL /GLOBAL LMR$Unavailable
$           WRITE sys$output ""
$      ENDIF
$ ENDIF
$ EXIT
$ !
