$ ! RAPT_TOOLS.COM -- Command setup for RAPT                       'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2004 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1993-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  P1: Application facility (abbreviation)
$ !  P2: [PC|VT] value for RMG$KEYBOARD
$ !  P3: [/ABOUT (D)|/NOABOUT]
$ !  P4: [DBA] - optional hook for DBA's symbols
$ !
$ bake         == "@site$utils:bake"
$ make         == "@site$utils:make"
$ shake        == "@site$utils:shake"
$ ked          == "$site$utils:ked"
$ ps           == "@site$utils:print_dcps"
$ raptf*lags   == "@site$utils:RAPTflags"
$ rbi*ndexes   == "@mgr$command:db$rebuild_indexes"
$ rdbf*lags    == "@site$utils:Rdbflags"
$ rsho*w       == "@mgr$command:rmu$show"
$ sc*ontrol    == "@site$utils:source_control"
$ sqlerror*msg == "SEARCH sys$library:sql_literals.pas"
$ sqlkey*words == "@site$utils:sql$keywords"
$ tool*sdebug  == "@site$utils:tools$debug"
$ !
$ ! Use Oracle/Rdb's multiversion logical name "sql$" (not "$sys$system:sql$"):
$ sql == "$sql$"
$ IF F$TRNLNM("sql$edit") .EQS. "" THEN DEFINE /PROCESS /NOLOG sql$edit tpu
$ !
$ ! Retired, deprecated:
$ !!prs*creen    == "$site$utils:printscreen"
$ !!wiz*ard      == "$rmg$wizard:wizard /LIBRARY=wizard"
$ !!erlic*ense   == "$site$utils:er$license"
$ !!rdo          == "$sys$system:rdo.exe"
$ !!IF F$TRNLNM("rdo$edit") .EQS. "" THEN DEFINE /PROCESS /NOLOG rdo$edit tpu
$ !
$ ! ===========================================================================
$ F = "sys$library:rdb$setver.com"  ! Oracle/Rdb's multiversion control
$ IF F$SEARCH(F) .NES. ""
$ THEN rdbs*etversion == "@''F'"
$ ENDIF
$ !
$ F = "site$utils:rapt$setver.com"  ! RAPT's multiversion control
$ IF F$SEARCH(F) .NES. ""
$ THEN raptset*version == "@''F'"
$ ENDIF
$ !
$ ! These definitions handle/respect multiversion RAPT:
$ FC = "load"
$ FN = "rmg$load"
$ LN = F$TRNLNM(FN)
$ IF LN .EQS. ""
$ THEN 'FC' == "$site$utils:" + FN + " /NOABOUT"
$ ELSE 'FC' == "$" + FN + " /NOABOUT"
$ ENDIF
$ !
$ FC = "rmer*ge"
$ FN = "rmg$merge_report"
$ LN = F$TRNLNM(FN)
$ IF LN .EQS. ""
$ THEN 'FC' == "$site$utils:" + FN + " /NOABOUT"
$ ELSE 'FC' == "$" + FN + " /NOABOUT"
$ ENDIF
$ !
$ FC = "rmg"
$ FN = "rmg"
$ LN = F$TRNLNM(FN)
$ IF LN .EQS. ""
$ THEN 'FC' == "$site$utils:" + FN + " /NOABOUT"
$ ELSE 'FC' == "$" + FN + " /NOABOUT"
$ ENDIF
$ ! ===========================================================================
$ !
$ F = "site$utils:smart$sethost.com"
$ IF F$SEARCH(F) .NES. "" THEN @'F' $LOGIN
$ !
$ F = "site$utils:librtool.com"
$ IF F$SEARCH(F) .NES. "" THEN libt*ool == "@''F'"
$ !
$ F = "mgr$command:smart$startup.com"
$ G = "mgr$command:dbm$maintenance.exe"
$ IF ( F$SEARCH(F) .NES. "" ) .AND. ( F$SEARCH(G) .NES. "" ) -
  THEN dbm*aintenance == "@''F' DBM"
$ !
$ IF P1 .NES. ""
$ THEN !!DEFINE /PROCESS /NOLOG rdoini 'P1'$active:rdoini.rdo
$      DEFINE /PROCESS /NOLOG sqlini 'P1'$active:sqlini.sql
$      Setup = "''P1'$active:''P1'$login.com"
$      IF F$SEARCH(Setup) .NES. ""
$      THEN @'Setup' "''P2'" "''P3'" "''P4'" !define application command symbols
$      ENDIF
$      F = "''P1'$DevTree:''P1'$modules.com"
$      IF F$SEARCH(F) .NES. "" THEN modu*les == "@''F'"
$ !
$ ENDIF
$ !
$Done:
$ EXIT
