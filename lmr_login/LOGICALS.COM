$ ! LOGICALS.COM -- make unconditional logical name assignments    'F$VERIFY(0)'
$ !
$TestDir:  SUBROUTINE
$ ! P1 : Subdirectory name to detect, create if missing
$ ! P2 : Logical name to create for subdirectory
$ ! P3 : Root/base user directory, e.g. "SYS$LOGIN_DEVICE:[username"
$ ON CONTROL_Y THEN GOSUB TDCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ dirspec = "sys$login:''P1'.dir"
$ dir     = "''P3'.''P1']"
$ IF ( F$SEARCH(dirspec) .EQS. "" ) THEN CREATE /DIRECTORY /LOG 'dir'
$ DEFINE 'P2' 'dir'
$ EXIT 1
$TDCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! TestDir
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
$common:
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
$ DEFINE base         'Lbase''Rooted'
$ DEFINE logs         'Lbase'.logs]
$ DEFINE com          'Lbase'.$com],site$utils
$ DEFINE lib          'Lbase'.$lib...]
$ DEFINE root         'Lbase']
$ DEFINE sys$scratch  'Lbase'.scratch]
$ DEFINE jnk          sys$scratch
$ !
$ ! Convenience logicals for VMS$AUDIT --
$ CALL TestDir "vmsaudits" "v$audit" "''LBase'"
$ IF ( F$SEARCH("SYS$LOGIN:VMSAUDITS.DIR") .NES. "" )
$ THEN DEFINE va  'LBase'.vmsaudits]
$      DEFINE var 'LBase'.vmsaudits.reports'Rooted'
$      ! Logical VMS$AUDITCONFIG required by VMS$AUDIT.COM;40(+)
$      DEFINE vms$auditconfig v$audit:vms$audit_lricker.config
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
$ DEFINE mfd sys$disk:[000000]
$ !
$ DEFINE = "DEFINE /PROCESS /NOLOG "
$ DEFINE dcl$keypad      lmr$login:DK$dcl_keypad.gold
$ DEFINE dcl$init        lmr$login:DK$dcl.com
$ DEFINE lists           'Lbase'.lists]
$ DEFINE mail$keypad     lmr$login:DK$mail_keypad.gold
$ DEFINE mail$init       lmr$login:DK$mail.com
$ DEFINE mail$edit       CALLABLE_TPU
$ DEFINE spell_personal  lists:spell_personal.dat
$ DEFINE tell$from       "Lorin"
$ DEFINE work            'Lbase'.work]
$ DEFINE X               sys$scratch:X.tmp
$ DEFINE Z               sys$scratch:Z.tmp
$ !
$ IF F$TRNLNM("ER$development")
$ THEN DEFINE Lorin   L_Ricker
$      DEFINE Rick    R_Evans
$      CALL NCDefine OUTLAW|BANDIT Dean    D_Woodward
$ !
$ ELSE IF F$TRNLNM("site$sources") .EQS. ""
$      THEN Src = F$SEARCH("disks$mounted:[smart]sources.dir")
$           IF Src .NES. ""
$           THEN Src = F$PARSE(Src,,,"DEVICE","SYNTAX_ONLY")
$                DEFINE site$sources 'Src'[smart.sources.] /TRANS=CONCEAL
$           ENDIF
$      ENDIF
$ ENDIF
$ !
$ ! PARSEC
$ DEFINE storage vmspr1::disk$storage:
$ !
$ EXIT
$ !
$BATCH:
$NETWORK:
$OTHER:
$ !
$ EXIT
