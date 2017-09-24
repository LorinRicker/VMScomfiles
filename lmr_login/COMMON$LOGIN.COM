$ ! COMMON$LOGIN.COM --
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
$MAIN:
$ SET NOON
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ !
$ ! ----------------------------------------------------------------------
$ ReLogin = ( F$EXTRACT( 0, 2, P1 ) .EQS. "RE" )  !REDEFINE, REFRESH, RE-whatever
$ ! By convention/intent, DCL$SUBROUTINE_LIBRARY is here:
$ IF ( F$TYPE( DCL$CALL ) .EQS. "" ) .OR. ( ReLogin )
$ THEN @lmr$login:DCL$SUBROUTINE_LIBRARY Setup FALSE
$ ENDIF
$ ! ----------------------------------------------------------------------
$ !
$ Proc = F$ENVIRONMENT("PROCEDURE")
$ FS   = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY") + F$PARSE(Proc,,,"TYPE","SYNTAX_ONLY")
$ !
$ SET TERMINAL /INQUIRE   ! this reads/sets the page-&-width sizes
$ TermType = "VT500"
$ PgLength = F$GETDVI("TT","TT_PAGE")
$ PgWidth  = F$GETDVI("TT","DEVBUFSIZ")
$ ! SET TERMINAL: Setting page /WIDTH= clears the screen...
$ !               and getting /PAGE= and /WIDTH= right is order-dependent,
$ !               these must precede /DEVICE= !! -- so... in exactly this order:
$ SET TERMINAL /PAGE='PgLength' /WIDTH='PgWidth' /DEVICE='TermType' -
   /INSERT /BROADCAST /TYPE_AHEAD /ALTYPEAHD /APPLICATION_KEYPAD
$ IF Verbosity THEN WRITE sys$output "%COMMON$LOGIN-I-TERM, terminal type set to ''TermType'"
$ !
$ IF F$TRNLNM("site$root") .EQS. "" .OR. ReLogin
$ THEN dfn = "DEFINE /NOLOG /JOB /EXECUTIVE"  ! not /SYSTEM
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
$      IF ReLogin
$      THEN sholog = "SHOW LOGICAL /JOB /FULL"
$           sholog site$*
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
$ DCL$CALL Alias "ked" "$site$utils:ked.exe"
$ DCL$CALL Alias "who" "@cmd:dclwho" "SHOW USERS"
$ !
$Done:
$ EXIT
