$ ! SHOW_DATABASE.COM --                                           'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1999-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  use: @SHOW_DATABASE [ database_logical_name ] -
$ !                      [ /FULL | FULL | /ALL | ALL ]
$ !
$ !  P1 default = "LT$Database"
$ !
$ Proc = F$ENVIRONMENT("PROCEDURE")
$ Proc = Proc - F$PARSE(Proc,,,"VERSION","SYNTAX_ONLY")
$ Fac  = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ wso  = "WRITE sys$output"
$ ScrWidth = F$GETDVI("sys$command","DEVBUFSIZ")
$ !
$ P2Qual   = ",/F,FU,/A,AL,"
$ P2       = F$EXTRACT(0,2,P2)
$ Full     = ( F$LOCATE(",''P2',",P2Qual) .LT. F$LENGTH(P2Qual) )
$ !
$ IF P1 .EQS. "" THEN P1 = "LT$Database"
$ !
$ DB = F$TRNLNM(P1)
$ IF DB .NES. ""
$ THEN Mode = F$EDIT(F$TRNLNM(P1,,,,,"ACCESS_MODE"),"LOWERCASE,TRIM")
$      Mode = F$EXTRACT(0,5,Mode)
$      IF ( Mode .EQS. "execu" )  THEN Mode = F$EXTRACT(0,4,Mode)
$      Tbl  = F$EDIT(F$TRNLNM(P1,,,,,"TABLE_NAME"),"LOWERCASE,TRIM") - "lnm$"
$      Tbl  = F$ELEMENT(0,"_",Tbl)
$      Hdr  = F$FAO( "%!AS-I-LNM, !AS [!AS/!AS] =", Fac, P1, Mode, Tbl )
$      HdrL = F$LENGTH(Hdr)
$ ELSE wso "%''Fac'-W-NO_LNM, no such logical name ''P1'"
$      GOTO Done
$ ENDIF
$ !
$ IF Full THEN wso F$FAO("!80*-")
$ IF HdrL + F$LENGTH(DB) .LT. ScrWidth
$ THEN wso F$FAO( "!AS [1m!AS[0m", Hdr, DB )
$ ELSE wso F$FAO( "!AS!/!22* [1m!AS[0m", Hdr, DB )
$ ENDIF
$ !
$ IF Full
$ THEN wso F$FAO("!80*-")
$      Tdb = F$PARSE(P1,".rdb")
$      IF F$SEARCH(Tdb) .NES. ""
$      THEN IF F$PARSE(Tdb,,,"NODE","SYNTAX_ONLY") .EQS. ""  !not a remote-db?
$           THEN RMUVar = F$TRNLNM("RDMS$RMU_Variant")
$                IF RMUVar .NES. "" THEN RMU == "''RMUVar'"
$                RMU /SHOW VERSION 'P1'
$                IF RMU$DATABASE_VERSION .EQS. RMU$RDB_VERSION !currently set to the right one?
$                THEN wso "%''Fac'-I-RDB_OK, Rdb version is set correctly for ''P1'"
$                ENDIF
$           ELSE wso "%''Fac'-W-REMOTE_DB, cannot determine Rdb version for remote database"
$           ENDIF
$      ELSE wso "%''Fac'-W-NO_DB, no database found for ''P2'"
$           @site$utils:utility RDBVersion 71 SHOW
$      ENDIF
$      wso F$FAO("!80*-!/")
$ ENDIF
$ !
$Done:
$ IF F$TYPE(showdb) .EQS. "" THEN showdb == "@''Proc'"
$ EXIT
