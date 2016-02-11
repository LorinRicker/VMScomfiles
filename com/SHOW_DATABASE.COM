$ ! SHOW_DATABASE.COM --
$ !                                                                'F$VERIFY(0)'
$ !
$ ! Copyright © 1999-2016 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ !  use: @SHOW_DATABASE [ database_logical_name ]
$ !                        [ FULL | ALL | DISK | WHERE ]
$ !
$ !  P1 default = "LT$Database"
$ !
$ Proc = F$ENVIRONMENT("PROCEDURE")
$ Proc = Proc - F$PARSE(Proc,,,"VERSION","SYNTAX_ONLY")
$ Fac  = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ wso  = "WRITE sys$output"
$ IF P1 .EQS. "" THEN P1 = "LT$Database"
$ !
$ DB = F$TRNLNM(P1,"lnm$process")
$ IF DB .NES. ""
$ THEN wso ""
$      wso "%''Fac'-I-LNM, ''P1' = [1m''DB'[0m (process)"
$ ELSE DB = F$TRNLNM(P1,"lnm$job")
$      IF DB .NES. ""
$      THEN wso ""
$           wso "%''Fac'-I-LNM, ''P1' = [1m''DB'[0m (job)"
$      ELSE DB = F$TRNLNM(P1,"lnm$system")
$           IF DB .NES. ""
$           THEN wso ""
$                wso "%''Fac'-I-LNM, ''P1' = [1m''DB'[0m (system)"
$           ELSE wso "%''Fac'-W-NO_LNM, no such logical name ''P1'"
$                GOTO Done
$           ENDIF
$      ENDIF
$ ENDIF
$ !
$ IF ( P2 .EQS. "ALL" ) .OR. ( P2 .EQS. "FULL" )
$ THEN wso ""
$      SHOW LOGICAL /FULL 'P1'
$      wso ""
$ ENDIF
$ !
$ IF ( P2 .EQS. "DISK" ) .OR. ( P2 .EQS. "WHERE" )
$ ! Now find which disk this database's root-file is on:
$ THEN DB$Dev = F$PARSE(P1,,,"DEVICE","SYNTAX_ONLY") - ":"
$      DFile  = F$PARSE(P1,".rdb")
$      DFID   = F$FILE_ATTRIBUTES(DFile,"FID")
$      MaxI = F$TRNLNM(DB$Dev,,,,,"MAX_INDEX")
$      I = 0
$L0:
$      IF I .LE. MaxI
$      THEN T = F$TRNLNM(DB$Dev,,I)
$! $           show sym DB$Dev
$! $           show sym T
$! $           show sym P1
$           IF F$LOCATE(".]",T) .LT. F$LENGTH(T) THEN T = T - ".]" + ".*]"
$           Tar = F$PARSE("''T'''P1'","db$rdb:[rdb_databases.*].rdb")
$           IF F$SEARCH(Tar) .NES. ""
$           THEN TFID = F$FILE_ATTRIBUTES(Tar,"FID")
$                IF TFID .EQS. DFID  ! the right/same root file?
$                THEN DB$Dev = F$PARSE(Tar,,,"DEVICE","SYNTAX_ONLY")
$                     wso "%''Fac-I-ON_DISK, ''P1' root file is on disk [1m''DB$Dev'[0m"
$                     GOTO Done
$                ELSE I = I + 1
$                     GOTO L0
$                ENDIF
$           ELSE I = I + 1
$                GOTO L0
$           ENDIF
$      ELSE GOTO NoDiskFound
$      ENDIF
$ ENDIF
$ !
$NoDiskFound:
$Done:
$ IF F$TYPE(showdb) .EQS. "" THEN showdb == "@''Proc'"
$ EXIT
