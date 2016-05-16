$ ! LOGIN.COM -- "My" login script -- 2nd version                  'F$VERIFY(0)'
$ !
$ ! Likely want this set the same way for all process types:
$ SET PROTECTION=(S:RWED,O:RWED,G,W) /DEFAULT
$ !
$ GOTO 'F$MODE()'
$ !
$ ! ==========
$INTERACTIVE:
$ SET TERMINAL /INQUIRE /INSERT
$ SET CONTROL=(Y,T)
$ !
$ IF ( F$SEARCH("SCRATCH.DIR;1") .EQS. "" )
$ THEN CREATE /DIRECTORY [.SCRATCH]
$ ENDIF
$ home = F$TRNLNM("SYS$LOGIN") - "]"
$ DEFINE /JOB /NOLOG SYS$SCRATCH 'home'.SCRATCH]
$ DEFINE /JOB /NOLOG com         'home'.$COM]
$ DEFINE /JOB /NOLOG logs        'home'.LOGS]
$ !
$ EveInitF = "sys$login:eve$init.eve"
$ IF ( F$SEARCH(EveInitF) .EQS. "" )
$ THEN CREATE 'EveInitF'  ! a *nix-style "here-doc":
! EVE$INIT.EVE -- sets EDT-keypad and bound-cursor modes:
SET KEYPAD EDT
SET CURSOR BOUND
$ ! -- end of "here-doc" data
$ ENDIF
$ DEFINE /PROCESS /NOLOG eve$init 'EveInitF'
$ !
$ ! VMS-style command aliases (symbols) --
$ dir      == "DIRECTORY /SIZE /DATE /PROTECTION"
$ ed*it    == "EDIT /TPU /INIT=eve$init"
$ move     == "RENAME"
$ prlj     == "PRINT /QUEUE=LASERJET /LOG"
$ ssys*tem == "PIPE SHOW SYSTEM | SEARCH SYS$INPUT "
$ SUBM*IT  == "SUBMIT /NOTIFY /NOPRINT /LOG_FILE=logs:"
$ count    == "PIPE SHOW SYSTEM | SEARCH SYS$INPUT /STATISTICS "
$ !
$ ! Linux/Unix-style command aliases (symbols) --
$ cd       == "SET DEFAULT"
$ pwd      == "SHOW DEFAULT"
$ cls      == "TYPE /PAGE=CLEARSCREEN NLA0:"
$ cp       == "COPY"
$ rm       == "DELETE"
$ mv       == "RENAME"
$ ls       == "DIRECTORY /SIZE /DATE /PROTECTION"
$ home     == "PIPE SET DEFAULT sys$login ; SHOW DEFAULT"
$ upt*ime  == "SHOW SYSTEM /NOPROCESS /FULL"
$ !
$ PgSize  = F$INTEGER(F$GETDVI("TT","TT_PAGE")) - 2    ! allow some margin
$ PgWidth = F$INTEGER(F$GETDVI("TT","DEVBUFSIZ")) - 2
$ tail     == "TYPE /TAIL=''PgSize'"
$ ! ...
$ !
$ nodename = F$EDIT( F$GETSYI("NODENAME"), "TRIM,UPCASE" )
$ SET PROMPT="''nodename'$ "
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
