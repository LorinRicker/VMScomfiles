$ ! COMMON$LOGIN.COM --                                           'F$VERIFY(0)'
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
$CDefine:  SUBROUTINE
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
$ ELSE IF LMR$Unavailable .EQS. ""
$      THEN LMR$Unavailable == FullSym
$      ELSE LMR$Unavailable == LMR$Unavailable + ", " + FullSym
$      ENDIF
$      IF Verbose THEN SHOW SYMBOL /LOCAL P1
$      IF Verbose THEN SHOW SYMBOL /LOCAL P2
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! CDefine
$ !
$ !
$MAIN:
$ SET NOON
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ Redefine = ( F$EXTRACT(0,2,P1) .EQS. "RE" )  !REDEFINE, REFRESH, RE-whatever
$ Proc = F$ENVIRONMENT("PROCEDURE")
$ FS   = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY") + F$PARSE(Proc,,,"TYPE","SYNTAX_ONLY")
$ !
$ WRITE SYS$OUTPUT "%COMMON$LOGIN-I-TERM, what's the Terminal Emulator (PuTTY, etc.) up to?..."
$ WRITE SYS$OUTPUT "   Pre-TERM/INQ device_type_name: ",F$GETDVI("TT","DEVICE_TYPE_NAME")
$ SET TERMINAL /INQUIRE
$ WRITE SYS$OUTPUT "  Post-TERM/INQ device_type_name: ",F$GETDVI("TT","DEVICE_TYPE_NAME")
$ !
$ TermType = "VT500"
$ PgLength = F$GETDVI("TT","TT_PAGE")
$ PgWidth  = F$GETDVI("TT","DEVBUFSIZ")
$ SET TERMINAL /INSERT /PAGE='PgLength' /WIDTH='PgWidth' /DEVICE='TermType' -
   /BROADCAST /TYPE_AHEAD /ALTYPEAHD /APPLICATION_KEYPAD
$ WRITE SYS$OUTPUT "%COMMON$LOGIN-I-TERM, terminal type set to ''TermType'"
$ !
$ IF F$TRNLNM("site$root") .EQS. "" .OR. Redefine
$ THEN dfn = "DEFINE /NOLOG /JOB /EXECUTIVE"  ! not /SYSTEM
$      sholog = "SHOW LOGICAL /JOB /FULL"
$      priv = F$SETPRV("SYSNAM,SYSPRV,CMKRNL")
$      LBase  = F$TRNLNM("sys$login_device") -
              + "[" + F$EDIT(F$GETJPI("","USERNAME"),"TRIM")
$      IF F$SEARCH("''LBase']$site.dir") .NES. ""
$      THEN LRoot = "''LBase'.$site."
$      ELSE IF F$SEARCH("''LBase']smart.dir") .NES. ""
$           THEN LRoot = "''LBase'.smart."
$           ELSE WRITE sys$error "%COMMON$LOGIN-W-NOSITE, no SMART/E$R/SITE structures, so minimal login"
$                EXIT
$           ENDIF
$      ENDIF
$      dfn site$root    'LRoot'] /TRANSLATION=CONCEALED
$      dfn site$utils   site$root:[utilities]
$      dfn site$help    site$root:[help]
$      dfn mgr$root     'LRoot'manager.] /TRANSLATION=CONCEALED
$      dfn mgr$command  'LRoot'manager.commands],'LBase'.E$R.smart.manager.commands]
$      dfn mgr$login    mgr$command:mgr_login.com
$      !!dfn site$startup site$root:[startup]
$      !!dfn site$sources 'LBase'.e$r.] /TRANSLATION=CONCEALED
$      !!dfn e$r          'LBase'.e$r]
$ !
$      DEFINE /PROCESS kstart 'LBase'.tpu],lmr$login,site$root:[startup]
$      @kstart:ked$startup JOB
$      DEASSIGN /PROCESS kstart
$ !
$      IF Redefine
$      THEN sholog site$*
$           sholog mgr$*
$           sholog ked$*
$           sholog tpu$*
$           !!sholog e$r
$      ENDIF
$ !
$      dfn disks$display sys$sysdevice
$ !       sys$sysdevice,disk$user2,disk$rdb_backup
$      priv = F$SETPRV(priv)
$ ENDIF
$ !
$ CALL CDefine "ked"          "$site$utils:ked.exe"
$ !
$ IF F$TYPE(who) .EQS. ""
$ THEN CALL CDefine "who" "@cmd:dclwho"
$      IF F$TYPE(who) .EQS. ""
$      THEN who == "SHOW USERS"
$      ENDIF
$ ENDIF
$ !
$Done:
$ EXIT
