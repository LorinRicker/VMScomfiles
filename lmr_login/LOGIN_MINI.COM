$ ! LOGIN.COM -- Lorin's minimal login                                  'F$VERIFY(0)'
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
$!!  $TestDir:  SUBROUTINE
$!!  $ ! P1 : Subdirectory name to detect, create if missing
$!!  $ ! P2 : Logical name to create for subdirectory
$!!  $ ! P3 : Root/base user directory, e.g. "SYS$LOGIN_DEVICE:[username"
$!!  $ ON CONTROL_Y THEN GOSUB TDCtrl_Y
$!!  $ ON ERROR THEN EXIT %X2C
$!!  $ dirspec = "sys$login:''P1'.dir"
$!!  $ dir     = "''P3'.''P1']"
$!!  $ IF ( F$SEARCH(dirspec) .EQS. "" ) THEN CREATE /DIRECTORY /LOG 'dir'
$!!  $ DEFINE 'P2' 'dir'
$!!  $ EXIT 1
$!!  $TDCtrl_Y:
$!!  $ RETURN %X2C
$!!  $ ENDSUBROUTINE  ! TestDir
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
$      ELSE wso "%SYMBOLS-W-NOREDEFINE, command symbol ""''P1'"" already exists"
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
$ ELSE IF ( P3 .NES. "" )
$      THEN 'P1' == "''P3'"  ! alternate (default DCL) command
$      ELSE IF LMR$Unavailable .EQS. ""
$           THEN LMR$Unavailable == FullSym
$           ELSE LMR$Unavailable == LMR$Unavailable + ", " + FullSym
$           ENDIF
$      ENDIF
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! CDefine
$ !
$PureDCL: SUBROUTINE
$ SET NOON
$ ! Sanity check for site-specific global string, make it go away!...
$ IF ( F$TYPE('P1') .EQS. "STRING" )
$ THEN DELETE = "DELETE"
$      DEFINE /NOLOG /USER_MODE sys$output NLA0:
$      DEFINE /NOLOG /USER_MODE sys$error  NLA0:
$      DELETE /SYMBOL /GLOBAL 'P1'
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! PureDCL
$ !
$ !
$ ! ==========
$MAIN:
$ ON ERROR THEN GOTO Done
$ ON CONTROL THEN GOSUB Ctrl_Y
$ SET CONTROL=(T,Y)
$ SET PROTECTION=(S:RWED,O:RWED,G,W) /DEFAULT
$ !
$ CALL PureDCL "BACKUP"
$ CALL PureDCL "COPY"
$ CALL PureDCL "DELETE"
$ CALL PureDCL "DIFFERENCES"
$ CALL PureDCL "DIRECTORY"
$ CALL PureDCL "EDIT"
$ CALL PureDCL "PURGE"
$ CALL PureDCL "RENAME"
$ CALL PureDCL "SEARCH"
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
$!! $ CALL TestDir "SCRATCH"   "sys$scratch" "''LBase'"
$!! $ CALL TestDir "LOGS"      "logs"        "''LBase'"
$!! $ CALL TestDir "COM"       "com"         "''LBase'"
$!! $ CALL TestDir "LOGIN"     "lmr$login"   "''LBase'"
$!! $ CALL TestDir "VMSAUDITS" "v$audit"     "''LBase'"
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
$ Redefine = "TRUE"   ! for now, always redefine...
$ CALL CDefine "cd"         "@com:cd"        "SET DEFAULT"
$ CALL CDefine "disks*pace" "@com:diskspace" "SHOW DEVICE D /MOUNTED"
$ CALL CDefine "where"      "@com:where"     "SHOW DEFAULT"
$ CALL CDefine "who"        "@com:DCLwho"    "SHOW USERS"
$ CALL CDefine "priv*ilege" "@com:privilege" "SET PROCESS /PRIVILEGE="
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
$ auth     == "MCR AUTHORIZE"
$ ping     == "$SYS$SYSTEM:TCPIP$PING"
$ sysman   == "MCR SYSMAN"
$ sysgen   == "MCR SYSGEN"
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
$!! $ CALL CDefine "mkdir" "@com:makedir"
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
          + ",''LBase'.com]fix$bck.com;,zips.com;"                      -
          + ",''LBase'.login]show_cluster$init.ini;,fixprivs.com;"      -
          + ",site$root:[utilities]cd.com;,diskspace.com;,makedir.com;" -
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
$ lgi   = "LOGIN_MINI.COM"   ! F$ENV("PROCEDURE") might now be LOGIN.COM...
$ IF ( F$SEARCH("''ssnam'") .NES. "" )
$ THEN BACKUP /LOG 'ssnam' /SAVE_SET /SELECT='lgi'  sys$login:login.com /NEW_VERSION
$      BACKUP /LOG 'ssnam' /SAVE_SET /SELECT=(edtini.edt,eve$init.eve) sys$login:*.* /NEW_VERSION
$      BACKUP /LOG 'ssnam' /SAVE_SET /SELECT=(show_cluster$init.ini,fixprivs.com) lmr$login:*.* /NEW_VERSION
$      BACKUP /LOG 'ssnam' /SAVE_SET /SELECT=(*.com) /EXCLUDE=('lgi') com:*.* /NEW_VERSION
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
