$ ! LOGIN.COM -- "My" login script -- 1st version                  'F$VERIFY(0)'
$ !
$ ! Likely want this set the same way for all process types:
$ SET PROTECTION=(S:RWED,O:RWED,G,W) /DEFAULT
$ !
$ GOTO 'F$MODE()'
$ !
$ ! ==========
$INTERACTIVE:
$ SET TERMINAL /INQUIRE /INSERT
$ !
$ ! VMS-style command aliases (symbols) --
$ dir      == "DIRECTORY /SIZE /DATE /PROTECTION"
$ move     == "RENAME"
$ prlj     == "PRINT /QUEUE=LASERJET /LOG"
$ ssys*tem == "PIPE SHOW SYSTEM | SEARCH SYS$PIPE "
$ SUBM*IT  == "SUBMIT /NOTIFY /NOPRINT /LOG_FILE=logs:"
$ count    == "PIPE SHOW SYSTEM | SEARCH SYS$PIPE /STATISTICS "
$ ! ...
$ !
$ SET PROMPT="CLASS8$ "
$ !
$ EXIT    ! 'F$VERIFY(0)'
$ !
$ ! ==========
$BATCH:
$ !
$ ! Batch job definitions, if any, go here...
$ ! (Why don't we do a SET TERMINAL command here?)
$ !
$ ! Replicate this interactive symbol, for consistency
$ !   in self-SUBMITted batch jobs --
$ SUBM*IT  == "SUBMIT /NOTIFY /NOPRINT /LOG_FILE=logs:"
$ !
$ EXIT    ! 'F$VERIFY(0)'
$ !
$ ! ==========
$NETWORK:
$OTHER:
$ ! This section is rarely, if ever, used...
$ !
$ EXIT    ! 'F$VERIFY(0)'
$ !
