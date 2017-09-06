$ ! FILE$SPRAY.COM -- does a "loose-rules", shotgun-MAKE           'F$VERIFY(0)'
$ !                   process on a wildcarded file-group
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
$ !    useage: @FILE$SPRAY filespec[,filespec...]        -
$ !                        target_dir                    -
$ !                        [ [/CLEAN] [/PURGE] [/KEEP=n] -
$ !                          [/PROTECTION=(prot_mask)]   -
$ !                          [/LOG] [/VERBOSE] ]
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ IF F$TYPE(Util$Fac) .EQS. ""
$ THEN Util == "@site$utils:utility.com"
$      Util START SPR
$ ENDIF
$ !
$ COPY = "COPY"       ! Hide any external (re)definition
$ !
$ wso = "WRITE sys$output"
$ DD  = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(DD,,,"NAME","SYNTAX_ONLY")
$ DD  = F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ !
$ Verbose = F$TRNLNM("Tools$Debug")
$ !
$L1:
$ IF P1 .EQS. "" -
  THEN READ /PROMPT="filename: " /END_OF_FILE=Done sys$command P1
$ IF P1 .EQS. "" THEN GOTO L1
$ IF F$EXTRACT(0,1,P1) .EQS. "?" THEN GOTO Help
$ !
$L2:
$ IF P2 .EQS. "" -
  THEN READ /PROMPT="target directory: " /END_OF_FILE=Done sys$command P2
$ IF P2 .EQS. "" THEN GOTO L2
$ TDD = F$PARSE(P2,,,"NODE","SYNTAX_ONLY") + F$PARSE(P2,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(P2,,,"DIRECTORY","SYNTAX_ONLY")
$ !
$ ! Parse any optional P3 (and trailing) qualifiers:
$ P3 = P3 + P4 + P5 + P6 + P7 + P8
$ P3 = F$EDIT(P3,"COLLAPSE,TRIM,UPCASE")
$ CleanIt = 0
$ PurgeIt = 0
$ PMask   = ""
$ QKeep   = ""
$ QLog    = ""
$ Sep = "/"
$ i   = 1
$L3:
$ Q = F$ELEMENT(i,Sep,P3)
$ IF ( Q .EQS. Sep ) .OR. ( i .GT. 6 ) THEN GOTO L3Cont
$ CleanIt = ( F$EXTRACT(0,4,Q) .EQS. "CLEA" ) .OR. CleanIt
$ PurgeIt = ( F$EXTRACT(0,4,Q) .EQS. "PURG" ) .OR. PurgeIt
$ Verbose = ( F$EXTRACT(0,4,Q) .EQS. "VERB" ) .OR. Verbose
$ IF F$EXTRACT(0,4,Q) .EQS. "PROT" THEN PMask = "/" + Q
$ IF F$EXTRACT(0,4,Q) .EQS. "KEEP" THEN QKeep = "/" + Q
$ IF F$EXTRACT(0,3,Q) .EQS. "LOG"  THEN QLog  = "/LOG"
$ i = i + 1
$ GOTO L3
$L3Cont:
$ !
$ CleanFile = "site$utils:file$cleanup.com"
$ IF F$SEARCH(CleanFile) .NES. ""
$ THEN Clean = "@''CleanFile'"
$ ELSE CleanIt = 0
$ ENDIF
$ !
$ IF F$EXTRACT(0,1,P1) .EQS. "@" THEN GOTO IndirectSpec
$DirectSpec:
$ i = 0
$ F0 = "sys$disk:[]"
$DS0:
$ Fl = F$ELEMENT(i,",",P1)
$ IF Fl .EQS. "," THEN GOTO Done               !more files?
$ FS   = F$PARSE(Fl,F0,"*.*",,"SYNTAX_ONLY")   !expand w/sticky dev:[dir]
$ FLen = F$LENGTH(FS)
$ Wild = ( F$LOCATE("*",FS) .LT. FLen ) .OR. ( F$LOCATE("%",FS) .LT. FLen )
$ GotOne = 0
$DS1:
$ F0 = F$PARSE(Fl,F0,,"DEVICE","SYNTAX_ONLY") -  !save sticky dev:[dir]
     + F$PARSE(Fl,F0,,"DIRECTORY","SYNTAX_ONLY")
$ Fl = F$SEARCH(FS)
$ IF Fl .NES. ""
$ THEN CALL TheProcess "''Fl'"
$     !===============
$      IF Wild
$      THEN GotOne = 1
$           GOTO DS1       !next wildcard
$      ELSE i = i + 1
$           GOTO DS0       !next comma-element
$      ENDIF
$ ELSE IF .NOT. GotOne THEN wso "%''Fac'-E-FNF, cannot find ''FS'"
$      i = i + 1
$      GOTO DS0
$ ENDIF
$ !
$MakeIndirect:
$ @site$utils:FILE$PrepList "''Files'" "" "" "" FIL$XFile /CONFIRM
$ IF F$TYPE(FIL$XFile) .EQS. "" THEN GOTO Done  !user-aborted or error
$ P1 = "@" + FIL$XFile                          !try again...
$ !
$IndirectSpec:
$ Files = P1 - "@"
$ Files = F$PARSE(Files,".lis")
$ OPEN /READ /ERROR=FNF f 'Files'
$IS0:
$ READ /END_OF_FILE=IS1 f Fl
$ Fl = F$EDIT(Fl,"COLLAPSE,UPCASE,UNCOMMENT")
$ IF Fl .EQS. "" THEN GOTO IS0                   !skip blank lines & comments
$!===============
$ CALL TheProcess "''Fl'"
$!===============
$ GOTO IS0
$ !
$IS1:
$ CLOSE f
$ !
$Done:
$ IF F$TYPE(FIL$XFile) .NES. "" THEN DELETE /SYMBOL /GLOBAL FIL$XFile
$ IF F$TYPE(Prv) .EQS. "STRING" THEN Prv = F$SETPRV(Prv)
$ Util EXIT
$ EXIT
$ !
$FNF:
$ wso "%''Fac'-E-FNF, cannot find @-list ''Files'"
$ wso ""
$ wso "  Creating indirect @-list file ''Files'"
$ wso ""
$ GOTO MakeIndirect
$ !
$ !
$ !          ==========
$TheProcess: SUBROUTINE
$ ! P1 : source file-spec
$ SET NOON
$ ON CONTROL_Y THEN EXIT %X2C
$ Stat   = 1
$ PureFN = F$PARSE(P1,,,"NAME","SYNTAX_ONLY") + F$PARSE(P1,,,"TYPE","SYNTAX_ONLY")
$ TarFN  = TDD + PureFN
$ SDT    = F$CVTIME(F$FILE_ATTRIBUTES(P1,"CDT"),"COMPARISON")
$ IF F$SEARCH(TarFN) .NES. ""
$ THEN TDT = F$CVTIME(F$FILE_ATTRIBUTES(TarFN,"CDT"),"COMPARISON")
$ ELSE TDT = F$CVTIME("17-NOV-1858","COMPARISON")
$ ENDIF
$ ! If target date/time <= source date/time (source is *newer* than target):
$ IF TDT .LTS. SDT
$ THEN COPY 'P1' 'TDD' 'PMask'     ! ...then replace it, with any clean-up...
$      Stat = $STATUS
$      IF Stat
$      THEN IF Verbose .OR. ( QLog .NES. "" ) THEN wso "%''Fac'-S-COPIED, ''P1' copied to ''TDD'"
$           IF CleanIt
$           THEN Clean 'TarFN' 'QKeep' 'QLog'
$           ELSE IF PurgeIt
$                THEN PURGE 'TarFN' 'QKeep'
$                     IF Verbose THEN wso "%''Fac'-S-PURGED, ''TarFN' purged ''QKeep'"
$                ENDIF
$           ENDIF
$      ENDIF
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! TheProcess
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  FILE$SPRAY is a command file which does a "MAKE-like" file copy operation,
  copying files from one (source) directory to another (target), but only if
  the source file's creation date (CDT) is [1mlater[0m ([1mnewer[0m) than the creation
  date of any existing copy of that same file in the target directory.

  This permits "conditional wild-card copy" operations to be done for classes
  of files, especially in a MAKE-file (*.MAK) context; for example:

     ! This MAKE dependency clause *always* fires (is true):
     site$utils:file$spray.com == site$utils:file$spray.com
     $ @site$utils:file$spray Src:*.setup,*.template Tar: /PURGE/LOG

  However, FILE$SPRAY can also be used interactively and/or in other command-
  file contexts in addition to its use in MAKE files.

  useage: @FILE$SPRAY filespec[,filespec...]        -
                      target_dir                    -
                      [ [/CLEAN] [/PURGE] [/KEEP=n] -
                        [/PROTECTION=(prot_mask)]   -
                        [/LOG] [/VERBOSE] ]

  where:

    P1 is a single filespec ([1mfname[0m), a file-list ([1mfname,fname,...[0m), or an
      indirection to a list of filespecs, one file per line ([1m@filelist[0m).
      Wildcards are supported for both [1mfname[0m and [1mfname,fname,...[0m forms,
      but not within indirect file lists.

    P2 is the target directory (or subdirectory) to which the files are to
      be copied.  This must be a single (sub)directory location.

    P3 is any (optional) qualifiers:

      /CLEAN    For each [1mfname[0m which is successfully copied to the target
                directory, invokes a FILE$CLEANUP (see "$ [1mCLEAN ?[0m" for
                more details on this command file).

      /PURGE    For each [1mfname[0m which is successfully copied to the target
                directory, does a PURGE command to delete old(er) versions
                of the file in the target directory.

      /KEEP[=n] Used with either /CLEAN or /PURGE, causes the most recent
                "[1mn[0m" copies to be retained during the file cleanup or purge
                operation.  If "[1mn[0m" is not specified, then /KEEP=1 is the
                default.

      /PROTECTION=(mask)  Applies the file protection mask "[1m(mask)[0m" to each
                file copied to the target directory.

      /LOG      Generates progress (informational) messages which confirm
                each file's copy and cleanup/purge operation.

      /VERBOSE  Similar to /LOG, but also produces internal diagnostic trace
                information typical of TOOLS$DEBUG.

    Note:  [1mQualifiers may not be abbreviated[0m, and must [1mfollow[0m the file
           specification and target directory parameters.

$ GOTO Done
$ !
