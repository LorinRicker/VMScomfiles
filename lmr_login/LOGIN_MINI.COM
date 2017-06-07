$ ! LOGIN_MINI.COM -- Lorin's minimal login                        'F$VERIFY(0)'
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
$ ! ==========
$MAIN:
$ ON ERROR THEN GOTO Done
$ ON CONTROL THEN GOSUB Ctrl_Y
$ SET CONTROL=(T,Y)
$ SET PROTECTION=(S:RWED,O:RWED,G,W) /DEFAULT
$ !
$ ! ----------------------------------------------------------------------
$ ReLogin = ( F$EXTRACT( 0, 2, P1 ) .EQS. "RE" )  !REDEFINE, REFRESH, RE-whatever
$ ! By convention/intent, DCL$SUBROUTINE_LIBRARY is here:
$ IF ( F$TYPE( DCL$CALL ) .EQS. "" ) .OR. ( ReLogin )
$ THEN @lmr$login:DCL$SUBROUTINE_LIBRARY Setup FALSE
$ ENDIF
$ ! ----------------------------------------------------------------------
$ !
$ DCL$CALL PureDCL "APPEND,BACKUP,DIFFERENCE,DUMP,SEARCH,TYPE"
$ DCL$CALL PureDCL "EDIT,COPY,DELETE,DIRECTORY,PURGE,RENAME"
$ !
$ lgi   = F$ENVIRONMENT("PROCEDURE")
$ lgi   = F$PARSE(lgi) - F$PARSE(lgi,,,"VERSION","SYNTAX_ONLY")
$ ssnam = "LMR$LOGIN:LOGIN_MINI"  ! hardwired name: LOGIN_MINI.COM gets renamed LOGIN.COM
$ !
$ IF F$TYPE(LBase) .EQS. "" THEN LBase = F$TRNLNM("sys$login") - "]"
$ Rooted = ".] /TRANSLATION_ATTRIBUTES=(CONCEALED)"
$ !
$ SET NOON
$ !
$ DEFINE = "DEFINE /JOB /NOLOG "
$ !
$ @'LBase'.LOGIN]COMMON_LOGICALS COM "LOGIN|lmr$login"
$ IF ( F$TRNLNM("site$utils") .EQS. "" ) THEN DEFINE site$utils com
$ !
$ ! Convenience logicals for VMS$AUDIT --
$ IF ( F$SEARCH("SYS$LOGIN:VMSAUDITS.DIR") .NES. "" )
$ THEN DEFINE va  'LBase'.vmsaudits]
$      DEFINE var 'LBase'.vmsaudits.reports'Rooted'
$      ! Logical VMS$AUDITCONFIG required by VMS$AUDIT.COM;40(+)
$      DEFINE vms$auditconfig v$audit:vms$audit_lricker.config
$ ENDIF
$ !
$ ! if P1 = { BAC[KUP] | RES[TORE] }, perform a backup/restore of mini-comfile-set:
$ cmd = F$EDIT(F$EXTRACT(0,3,P1),"TRIM,UPCASE")
$ ON WARNING THEN EXIT %X2C  ! guard: "no such goto-label"
$ IF ( cmd .NES. "" ) THEN GOTO 'cmd'$
$ !
$ GOTO 'F$MODE()'
$ !
$INTERACTIVE:
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL THEN GOSUB Ctrl_Y
$ !
$ SET TERMINAL /INQUIRE
$ SET TERMINAL /INSERT /PAGE=48 /WIDTH=132 /DEVICE=VT300 -
    /BROADCAST /TYPE_AHEAD /ALTYPEAHD /APPLICATION_KEYPAD
$ !
$ LNode = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ LMR$promptstr == "''LNode'$ "       ! Normal prompt
$ LMR$promptprv == "[1m''LNode'[0m$ "  !Prilegediv prompt
$ SET PROMPT="''LMR$promptstr'"       !   COM:PRIVILEGE.COM uses both prompt-strings
$ !
$ IF F$TRNLNM("OSM$") .NES. "" THEN OSM == "$OSM_CONTROL"
$ !
$ VMSArchitecture = F$EDIT( F$GETSYI("ARCH_NAME"), "TRIM" )
$ VMSVersion      = F$EDIT( F$GETSYI("VERSION"), "TRIM" )
$ !
$ ! Nice-to-have abbreviations for the command line:
$ WSO == "WRITE sys$output"
$ SIN == "SEARCH sys$pipe"
$ !
$ DEFINE = "DEFINE /PROCESS /NOLOG "
$ DEFINE mfd sys$disk:[000000]
$ DEFINE X   sys$scratch:X.tmp
$ DEFINE Z   sys$scratch:Z.tmp
$ !
$ esc[0,32]= %X1B
$ esc[0,1]:= 'esc'
$ ! --------------------------------
$ ! Define screen-clearing commands:
$ _bckscrL == esc + "[?5h"      ! set background light
$ _bckscrD == esc + "[?5l"      ! set background dark
$ _clrscr  == esc + "[m"  -     ! set rendition normal
            + esc + "[H"  -     ! cursor to 0,0
            + esc + "[2J"       ! clear entire screen
$ !
$ clr      == "WRITE sys$output _clrscr"
$ cls      == "WRITE sys$output _clrscr"
$ clrd     == "WRITE sys$output _bckscrL,_clrscr"
$ clsd     == "WRITE sys$output _bckscrL,_clrscr"
$ clrl     == "WRITE sys$output _bckscrD,_clrscr"
$ clsl     == "WRITE sys$output _bckscrD,_clrscr"
$ ! --------------------------------
$ !
$ LMR$UNAVAILABLE == ""
$ DCL$CALL Alias "cd"             "@com:cd"        "SET DEFAULT"
$ DCL$CALL Alias "disks*pace"     "@com:diskspace$report" "SHOW DEVICE D /MOUNTED"
$ DCL$CALL Alias "diskl*imits"    "@com:disklimits$report"
$ DCL$CALL Alias "diski*nventory" "@com:diskinventory$report"
$ DCL$CALL Alias "diskm*enu"      "@com:diskmenu$report"
$ DCL$CALL Alias "tool*sdebug"    "@com:tools$debug"
$ DCL$CALL Alias "where"          "@com:where"     "SHOW DEFAULT"
$ DCL$CALL Alias "who"            "@com:DCLwho"    "SHOW USERS"
$ DCL$CALL Alias "priv*ilege"     "@com:privilege" "SET PROCESS /PRIVILEGE="
$ IF ( F$EXTRACT(0,1,privilege) .EQS. "@" )
$ THEN pow*er == "''privilege' ONE$SHOT"
$      sudo   == "''privilege' SUDO"
$ ENDIF
$ !
$ ai       == "ANALYZE /IMAGE /SELECT=(ARCH,IMAGE_TYPE,IDENT=IMAGE,NAME)"
$ cftp     == "COPY /FTP /LOG"
$ chksum   == "CHECKSUM /ALGORITHM=MD5 /SHOW=ALL"
$ dsk*s    == "SHOW DEVICE /MOUNTED D"
$ dir      == "DIRECTORY /ACL /SIZE /DATE /PROTECTION /WIDTH=(FILENAME=24,SIZE=10)"
$ where    == "SHOW DEFAULT"
$ glo*bal  == "SHOW SYMBOL /GLOBAL"
$ lnm      == "SHOW LOGICAL /FULL /TABLE=LNM$FILE_DEV"
$ ftpcl8   == "ftp class8.parsec.com"
$ !
$ LFull = ""
$ IF ( F$SEARCH( "sys$login:login_mini.com" ) .NES. "" ) THEN LFull = "_MINI"
$ IF ( F$SEARCH( "sys$login:login_full.com" ) .NES. "" ) THEN LFull = "_FULL"
$ reLog*in == "@SYS$LOGIN:LOGIN''LFull'"
$ !
$ ssys*tem == "PIPE SHOW SYSTEM | ''SIN' "  !requires a string-arg from user/cmd-line
$ submit   == "SUBMIT /NOTIFY /NOPRINT /LOG_FILE=logs:"
$ !
$ qidle     == "PIPE SHOW QUEUE /ALL | ''SIN' idle,started /HIGHLIGHT=UNDERLINE"
$ qstal*led == "PIPE SHOW QUEUE /ALL | ''SIN' stopped,stalled,paused /HIGHLIGHT=UNDERLINE"
$ !
$ ping     == "$SYS$SYSTEM:TCPIP$PING"
$ sysman   == "MCR SYSMAN"
$ sysgen   == "MCR SYSGEN"
$ !
$ IF F$TYPE(authorize) .EQS. ""
$ THEN IF F$TRNLNM( "sysuaf", "lnm$system" ) .NES. ""
$      THEN auth*orize == "$SYS$SYSTEM:AUTHORIZE"
$      ELSE auth*orize == "PIPE cd sys$system ; MCR AUTHORIZE"
$      ENDIF
$ ENDIF
$ !
$ clu = ""
$ IF F$GETSYI("CLUSTER_MEMBER") THEN clu = "/CLUSTER"
$ clupt*ime == "PIPE SHOW SYSTEM ''clu'/NOPROCESS /FULL | SEARCH /HIGHLIGHT=UNDERLINE /WINDOW=(1,2) sys$pipe uptime"
$ upt*ime   == "PIPE uptm$ = F$DELTA_TIME( F$GETSYI(""BOOTTIME""), F$TIME(), ""ASCTIM"" ) ; WRITE sys$output uptm$"
$ boot*time == "@com:bootttime.com"
$ !
$ err*orlog == "ANALYZE /ERROR "
$ IF ( VMSArchitecture .NES. "VAX" )
$ THEN IF ( VMSVersion .GES. "V7.3" )
$      THEN err*orlog == "ANALYZE /ERROR /ELV TRANSLATE "   ! for Alpha/Itanium VMS >= v7.3
$      ENDIF
$ ENDIF
$ !
$ sclu*ster == "SHOW CLUSTER /CONTINUOUS"
$ IF F$SEARCH("lmr$login:show_cluster$init.ini") .NES. ""
$ THEN DEFINE /PROCESS /SUPERVISOR /NOLOG show_cluster$init lmr$login:show_cluster$init.ini
$ ENDIF
$ !
$ ! Search & conditionally build zip/unzip symbols:
$ IF ( F$SEARCH("com:zips.com") .NES. "" ) THEN @com:zips
$ !
$ ! Logicals:
$ lnm == "SHOW LOGICAL /FULL /TABLE=LNM$FILE_DEV "
$!! $ DCL$CALL Alias "mkdir" "@com:makedir"
$!! $ ml*ogical == mkdir + " *"
$ !
$ EXIT 1
$ !
$BATCH:
$ EXIT 1
$ !
$NETWORK:
$OTHER:
$ EXIT 1
$ !
$BAC$:
$ comlist = "''LBase'.com]privilege.com;,where.com;,boottime.com;"      -
          + ",fix$bck.com;,zips.com;,tools$debug.com;"                  -
          + ",disk*$report.com;,cd.com;"                                -
          + ",''LBase'.login]show_cluster$init.ini;,fixprivs.com;"      -
          + ",dcl$subroutine_library.com;,common_logicals.com;"         -
          + ",site$root:[utilities]makedir.com;"                        -
          + ",mgr$root:[commands]DCLwho.com;"                           -
          + ",sys$login:eve$init.eve;,sys$login:edtini.edt;"
$ !!DEFINE /USER_MODE /PROCESS sys$output NLA0:
$ !!DEFINE /USER_MODE /PROCESS sys$error  NLA0:
$ BACKUP /LIST='ssnam' /NOCRC /GROUP_SIZE=0 /INTERCHANGE -
    'lgi';0,'comlist' 'ssnam'.BCK /SAVE_SET
$ TYPE 'ssnam'.LIS
$ PURGE 'ssnam'.*
$ DIRECTORY /SIZE /DATE /PROT 'ssnam'
$ EXIT 1
$ !
$RES$:
$ ssnam = ssnam + ".BCK"
$ lgi   = "LOGIN_MINI.COM" -   ! F$ENV("PROCEDURE") might now be LOGIN.COM...
$ clgi  = "dcl$subroutine_library.com,common*.com,fixprivs.com,show_cluster$init.ini"
$ edt   = "*.eve,*.edt"
$ ini   = "*.ini,"
$ IF ( F$SEARCH("''ssnam'") .NES. "" )
$ THEN bkup = "BACKUP /LOG ''ssnam' /SAVESET"
$      bkup /SELECT=('lgi')             sys$login:login.com /NEW_VERSION
$      bkup /SELECT=('edt')                   sys$login:*.* /NEW_VERSION
$      bkup /SELECT=('clgi')                  lmr$login:*.* /NEW_VERSION
$      bkup /SELECT=(*.com) /EXCLUDE=('lgi','clgi') com:*.* /NEW_VERSION
$ ELSE WRITE sys$error "%LOGIN_MINI-E-FNF, cannot find file ''ssnam'"
$ ENDIF
$ EXIT 1
$ !
$Done:
$ SET NOON
$ EXIT 1
$ !
$Ctrl_Y:
$ RETURN %X2C
