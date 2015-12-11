$ ! LOGICALS.COM -- make unconditional logical name assignments    'F$VERIFY(0)'
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
$ IF ( F$SEARCH("SYS$LOGIN:VMSAUDITS.DIR") .NES. "" )
$ THEN DEFINE va  'LBase'.vmsaudits]
$      DEFINE var 'LBase'.vmsaudits.reports'Rooted'
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
$      CALL NCDefine OUTLAW|BANDIT Jill    Jill_R     !Reichensperger
$! $      CALL NCDefine OUTLAW|BANDIT Dixie   D_Ricker
$ !
$ ! Watch: Complicated quoting rules:  P3's target text is "SMTP%"J_User@node""
$! $      !! CALL NCDefine OUTLAW DEFINE «» "SMTP%""""«»@bodine"""""
$! $      CALL NCDefine OUTLAW Michele "SMTP%""""Murphy_MM@judson"""""
$! $      CALL NCDefine OUTLAW Rich    "SMTP%""""Petrelli_R@judson"""""
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
$!! $ CALL NCDefine EAGLE                Morrie   M_Volkov
$!! $ CALL NCDefine EAGLE                Wendy    W_Guest
$!! $ CALL NCDefine EAGLE                Jennifer J_Rodriguez
$!! $ CALL NCDefine EAGLE                Judy     J_Robbins
$!! $ CALL NCDefine EAGLE                Ted      T_Nelson
$ !
$ EXIT
$ !
$BATCH:
$NETWORK:
$OTHER:
$!! $ CALL NCDefine BRUINS|CELTIC|REDSOX DZ        sys$user4:[scs.$dropzone]
$!! $ CALL NCDefine OUTLAW|BANDIT        DZ        sys$user1:[scs.$dropzone]
$ !
$!! $ CALL NCDefine BODINE|JUDSON|TAYLOR sys$batch BODINE_BATCH  !force this!
$!! $ CALL NCDefine BODINE|JUDSON|TAYLOR LLZ       disk$user_4:[pps.LandingZone]
$ !
$ EXIT
