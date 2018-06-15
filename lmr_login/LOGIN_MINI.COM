$ ! LOGIN_MINI.COM -- Lorin's minimal login                        'F$VERIFY(0)'
$ !
$ ! Copyright © 1999-2018 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ DEFINE filetools 'Lbase'.COM.FILETOOLS]
$ @'LBase'.LOGIN]COMMON_LOGICALS "COM||,va,filetools" "LOGIN|lmr$login"
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
$ @lmr$login:setterminal
$ !
$ IF F$TRNLNM("OSM$") .NES. "" THEN OSM == "$OSM_CONTROL"
$ !
$ ! Dependency: must create ANSI esc-sequences/commands before SYMBOLS.COM...
$ DCL$CALL DefineANSIseq      ! ANSI esc-sequence renditions & colors
$ DCL$CALL DefineClearscreen  ! clr/cls commands
$ @lmr$login:symbols
$ ! Dependency: ...and set prompt after defining ANSIseq and SYMBOLS.COM...
$ IF ( F$TYPE( LMR$promptstr ) .EQS. "STRING" )
$ THEN SET PROMPT="''LMR$promptstr'"
$ ELSE SET PROMPT="''LNode'$ "
$ ENDIF
$ !
$ DEFINE = "DEFINE /PROCESS /NOLOG "
$ DEFINE mfd sys$disk:[000000]
$ DEFINE X   sys$scratch:X.tmp
$ DEFINE Z   sys$scratch:Z.tmp
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
$ comlist = "''LBase'.login]symbols.com;,setterminal.com;"              -
          +    ",dcl$subroutine_library.com;,common_logicals.com;"      -
          +    ",show_cluster$init.ini;,fixprivs.com;"                  -
          + ",''LBase'.com]privilege.com;,cd.com;,where.com;"           -
          +    ",boottime.com;,fix$bck.com;,zips.com;"                  -
          +    ",dclwho.com;,makedir.com;"                              -
          +    ",disk$clone.com;,do_continuous.com;"                    -
          + ",''LBase'.com.filetools]*.com;,*.tpu;"                     -
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
$ lgi   = "LOGIN_MINI.COM"     ! F$ENV("PROCEDURE") might now be LOGIN.COM...
$ clgi  = "dcl$subroutine_library.com,common*.com,fixprivs.com,show_cluster$init.ini"
$ ftools = "file$*.*,disk*$*.com"
$ edt   = "*.eve,*.edt"
$ ini   = "*.ini,"
$ IF ( F$SEARCH("''ssnam'") .NES. "" )
$ THEN bkup = "BACKUP /LOG ''ssnam' /SAVESET"
$      bkup /SELECT=('lgi')    sys$login:login.com /NEW_VERSION
$      bkup /SELECT=('edt')    sys$login:*.* /NEW_VERSION
$      bkup /SELECT=('clgi')   lmr$login:*.* /NEW_VERSION
$      bkup /SELECT=(*.com)    com:*.*       /NEW_VERSION /EXCLUDE=('lgi','clgi','ftools')
$      bkup /SELECT=('ftools') filetools:*.* /NEW_VERSION
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
