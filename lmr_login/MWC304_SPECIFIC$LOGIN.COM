$ ! MWC304_SPECIFIC$LOGIN.COM --                                   'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1998-1999 by Evans & Ricker, Inc.  All rights reserved.
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
$ ! Site-specific setup goes here:
$ !
$ !$ IF ( LNode .EQS. "MWC304" )  !Alphas
$ !$ THEN DEFINE /NOLOG /JOB disks$display -
$ !         sys$sysdevice:  !,disk$user2,disk$rdb_backup, -
$ !$!         disk$rdb1,disk$rdb2,disk$rdb3,disk$rdb4, -
$ !$!         disk$rdb5,disk$rdb6,disk$rdb7,disk$misc_rdb
$ !$      DEFINE /NOLOG /SYSTEM /EXEC mgr$command  sys$sysdevice:[lorin.smart.manager.commands]
$ !$      DEFINE /NOLOG /SYSTEM /EXEC site$utils   sys$sysdevice:[lorin.smart.utilities]
$ !$      DEFINE /NOLOG /SYSTEM /EXEC site$sources sys$sysdevice:[lorin.e$r.]
$ !$ ENDIF
$ !$ !
$ ! Things likely to be missing at ...:
$ CALL CDefine "disk*space"   "@site$utils:diskspace.com"
$ CALL CDefine "ked"          "$site$utils:ked.exe"
$!$ CALL CDefine "«»"        "«»"
$ !
$ CALL CDefine "who"          "$site$utils:who.exe"
$ IF F$TYPE(who) .EQS. ""
$ THEN CALL CDefine "who" "@mgr$command:dclwho"
$      IF F$TYPE(who) .EQS. ""
$      THEN who == "SHOW USERS"
$      ENDIF
$ ENDIF
$ !
$Done:
$ EXIT
