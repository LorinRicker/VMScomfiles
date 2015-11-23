$ ! CD.COM -- Change Directory                                     'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1990-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ! usage:
$ !   $ cd                            ! change to previous directory
$ !   $ cd dir                        ! change to dir
$ !   $ cd dir1 dir2 ... dirN         ! change to dirN through dir1, dir2, ...
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL THEN GOSUB CtrlY
$ !
$ Verbose = F$TRNLNM("Tools$Debug")
$ !
$ czTmp = F$ENVIRONMENT("DEFAULT")      ! Remember this last place you're in...
$ IF F$TYPE(cz) .EQS. "" THEN cz == "sys$login"  ! Initialize
$ !
$ ! No arg means go to last-remembered dev:[dir] --
$ IF P1 .EQS. "" THEN P1  = cz
$ !
$L1:
$ IF F$TRNLNM(P1,,,,,"MAX_INDEX") .GT. 0       ! A search list?
$ THEN P1 = F$TRNLNM(P1)                       ! 1st equiv-strg
$ ELSE ! If this is a single `word', translate it as a logical...
$      Nam = F$PARSE(P1,,,"NAME","SYNTAX_ONLY")
$      IF Nam .EQS. P1   ! it's a "WORD", not a "DEV:[DIR]WORD" form
$      THEN P1 = F$TRNLNM(Nam)
$      ENDIF
$ ENDIF
$ cdd = F$PARSE(P1,,,"NODE") + F$PARSE(P1,,,"DEVICE") + F$PARSE(P1,,,"DIRECTORY")
$ cde = F$PARSE(P1)
$ IF ( cde .NES. "" )
$ THEN IF F$SEARCH("context.com") .NES. "" THEN @context OUT "''cdd'"
$      SET DEFAULT 'cdd'
$      IF P2 .EQS. "" THEN IF F$TYPE(smsk$clear_on_cd) .NES. "" THEN cls
$      IF F$SEARCH("context.com") .NES. "" THEN @context IN "''cdd'"
$ ELSE WRITE sys$output "%CD-W-NODIR, no such directory ",cdd
$      SHOW DEFAULT
$      EXIT 1  !but don't signal an error, just return...
$ ENDIF
$ SHOW DEFAULT
$ IF P2 .NES. ""
$ THEN P1 = P2
$      P2 = P3
$      P3 = P4
$      P4 = P5
$      P5 = P6
$      P6 = P7
$      P7 = P8
$      P8 = ""
$      GOTO L1
$ ELSE cz == czTmp
$ IF Verbose THEN SHOW SYMBOL /GLOBAL cz
$ ENDIF
$Done:
$ EXIT 1
$ !
$CtrlY:
$ RETURN %X2C
