$ ! LOGICALS.COM -- make unconditional logical name assignments
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
$NCDefine:  SUBROUTINE     !Node-Conditional DEFINE
$ ! P1 : node1 [|node2 ...]
$ ! P2 : logical name
$ ! P3 : equivalence string
$ ! P4 : debug flag (default "No")
$ SET NOON
$ DEFINE = "DEFINE /JOB /NOLOG "
$ i = 0
$NC0:
$ N'i' = F$ELEMENT(i,"|",P1)
$ IF N'i' .EQS. "|" THEN GOTO NC1
$ IF N'i' .EQS. LNode      !OK to define logical for this node?
$ THEN DEFINE 'P2' "''P3'"
$      IF P4
$      THEN SHOW SYMBOL LNode
$           SHOW SYMBOL P2
$           SHOW SYMBOL P3
$           SHOW LOGICAL /FULL 'P2'
$      ENDIF
$ ENDIF
$ i = i + 1
$ GOTO NC0
$NC1:
$ EXIT 1
$ ENDSUBROUTINE  ! NCDefine
$ !
$ !
$Main:
$ SET NOON  ! Don't abort, especially if QueMgr (batch, print) isn't running...
$ !
$ IF F$TYPE(Lbase) .EQS. "" -
  THEN LBase = F$PARSE("sys$login",,,"DEVICE","SYNTAX_ONLY") -
             + "[" + F$EDIT(F$GETJPI("","USERNAME"),"TRIM")
$ Rooted = ".] /TRANSLATION_ATTRIBUTES=(CONCEALED)"
$ LNode  = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ !
$ DEFINE = "DEFINE /JOB /NOLOG "
$ !
$ DEFINE root         'Lbase']
$ DEFINE base         'Lbase''Rooted'
$ !
$ DEFINE filetools 'Lbase'.COM.FILETOOLS]
$ DEFINE vmsruby   'Lbase'.COM.VMSRUBY]
$ @lmr$login:common_logicals -
      "com||,va,filetools,vmsruby,site$utils" -
      "com|cmd" lib logs sys$scratch
$ !
$ ! For Logical Disks (LDAxxx:) --
$ DEFINE ldisks 'Lbase'.LDISKS]
$ !
$ ! Convenience logicals for VMS$AUDIT --
$ IF ( F$SEARCH("SYS$LOGIN:VMSAUDITS.DIR") .NES. "" )
$ THEN DEFINE va  'LBase'.vmsaudits]
$      DEFINE var 'LBase'.vmsaudits.reports'Rooted'
$      ! Logical VMS$AUDITCONFIG required by VMS$AUDIT.COM;40(+)
$      DEFINE vms$auditconfig v$audit:vms$audit_lricker.config
$ ENDIF
$ IF ( F$SEARCH("SYS$LOGIN:TPG.DIR") .NES. "" )
$ THEN DEFINE pgrpt 'LBase.tpg.reports'Rooted'
$ ENDIF
$ !
$ DEFINE DCL$Path []       !current directory only...
$ !
$ ! Manufacture a SYS$BATCH logical name, if possible and necessary:
$ ON ERROR THEN GOTO dispatch
$ SMan = F$GETQUI("DISPLAY_MANAGER",,"SYS$QUEUE_MANAGER")
$ IF SMan .EQS. ""
$ THEN !! not for PARSEC: -> WRITE sys$output "%LOGICALS-W-NOQUEMGR, default queue manager SYS$QUEUE_MANAGER is not started"
$      GOTO dispatch
$ ENDIF
$ SQue = F$GETQUI("DISPLAY_QUEUE","QUEUE_NAME","SYS$BATCH")
$ BQue = F$GETQUI("DISPLAY_QUEUE","QUEUE_NAME","''LNode'_BATCH")
$ IF SQue .EQS. ""         !SYS$BATCH does not exist...
$ THEN IF BQue .NES. ""    !but node_BATCH does...
$      THEN DEFINE sys$batch 'BQue'
$      ELSE WRITE sys$output "%LOGICALS-W-NOBATCH, queues SYS$BATCH and ''LNode'_BATCH do not exist"
$      ENDIF
$ ENDIF
$ !
$dispatch:
$ SET NOON
$ GOTO 'F$MODE()'
$ !
$INTERACTIVE:
$ DEFINE = "DEFINE /PROCESS /NOLOG "
$ !
$ DEFINE dcl$keypad      lmr$login:DK$dcl_keypad.gold
$ DEFINE dcl$init        lmr$login:DK$dcl.com
$ DEFINE lists           'Lbase'.lists]
$ DEFINE mail$keypad     lmr$login:DK$mail_keypad.gold
$ DEFINE mail$init       lmr$login:DK$mail.com
$ DEFINE mail$edit       CALLABLE_TPU
$ DEFINE spell_personal  'Lbase'.spell]spell_personal.dat
$ DEFINE tell$from       "Lorin"
$ DEFINE work            'Lbase'.work]
$ DEFINE X               sys$scratch:X.tmp
$ DEFINE Z               sys$scratch:Z.tmp
$ !
$ inifile = "lmr$login:show_cluster$init.ini"
$ IF F$SEARCH( inifile ) .NES. ""
$ THEN inifname = F$PARSE( inifile, , , "NAME" )
$      DEFINE /PROCESS /SUPERVISOR /NOLOG 'inifname' 'inifile'
$      sclu*ster == "SHOW CLUSTER /CONTINUOUS"
$ ENDIF
$ !
$ inifile = "lmr$login:sysmanini.ini"
$ IF F$SEARCH( inifile ) .NES. ""
$ THEN inifname = F$PARSE( inifile, , , "NAME" )
$      DEFINE /PROCESS /SUPERVISOR /NOLOG 'inifname' 'inifile'
$ ENDIF
$ !
$ IF F$TRNLNM("site$sources") .EQS. ""
$ THEN Src = F$SEARCH("disks$mounted:[smart]sources.dir")
$      IF Src .NES. ""
$      THEN Src = F$PARSE(Src,,,"DEVICE","SYNTAX_ONLY")
$           DEFINE site$sources 'Src'[smart.sources.] /TRANS=CONCEAL
$      ENDIF
$ ENDIF
$ !
$ ! PARSEC
$ IF ( F$EXTRACT(0,6,F$GETSYI("NODENAME")) .NES. "VMSPR1" )
$ THEN DEFINE /JOB /NOLOG storage vmspr1::disk$ftp:
$ ENDIF
$ !
$ EXIT
$ !
$BATCH:
$NETWORK:
$OTHER:
$ !
$ EXIT
