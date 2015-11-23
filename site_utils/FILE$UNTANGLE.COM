$ ! FILE$UNTANGLE.COM -- "Untangles" a directory of files          'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1999-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  useage: @FILE$UNTANGLE filespec[,filespec...] [ /CONFIRM | /TEST ]
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ IF F$TYPE(Util$Fac) .EQS. ""
$ THEN Util == "@site$utils:utility.com"
$      Util START UNT
$ ENDIF
$ wso = "WRITE sys$output"
$ DD  = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(DD,,,"NAME","SYNTAX_ONLY")
$ DD  = F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ !
$L0:
$ IF P1 .EQS. "" -
    THEN READ /PROMPT="filespec: " /END_OF_FILE=Done sys$command P1
$ IF P1 .EQS. "" THEN GOTO L0
$ IF F$EXTRACT(0,1,P1) .EQS. "?" THEN GOTO Help
$ !
$ Prv = F$SETPRV("SYSPRV")
$ !
$ ! /TEST and /CONFIRM are mutually exclusive:
$ TestMode = ( F$EXTRACT(0,2,P2) .EQS. "/T" )
$ IF F$EXTRACT(0,2,P2) .EQS. "/C"
$ THEN Confirm = "/CONFIRM"
$ ELSE Confirm = ""
$ ENDIF
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ !
$ IF F$EXTRACT(0,1,P1) .EQS. "@" THEN GOTO IndirectSpec
$DirectSpec:
$ i = 0
$ F0 = "sys$disk:[]"
$DS0:
$ Fl = F$ELEMENT(i,",",P1)
$ IF Fl .EQS. "," THEN GOTO Done               !more files?
$ FS   = F$PARSE(Fl,F0,"*.*",,"SYNTAX_ONLY")   !expand w/sticky dev:[dir]
$ FS   = F$ELEMENT(0,";",FS)                   !strip any ;version
$ FLen = F$LENGTH(FS)
$ Wild = ( F$LOCATE("*",FS) .LT. FLen ) .OR. ( F$LOCATE("%",FS) .LT. FLen )
$ GotOne = 0
$DS1:
$ F0 = F$PARSE(Fl,F0,,"DEVICE","SYNTAX_ONLY") -  !save sticky dev:[dir]
     + F$PARSE(Fl,F0,,"DIRECTORY","SYNTAX_ONLY")
$ Fl = F$SEARCH(FS,1)
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
$ ! P1 : file
$ !
$ ! Note: F$FILE_ATTRIBUTE could encounter
$ !         %SYSTEM-W-ACCONFLICT, file access conflicts
$ !       so set ON WARNING...
$ !
$ ON WARNING THEN GOTO TPError
$ ON CONTROL_Y THEN EXIT %X2C
$! $ IF Verbose
$! $ THEN Log = "/LOG"
$! $ ELSE Log = ""
$! $ ENDIF
$ File = F$ELEMENT(0,";",P1)            !strip any ;version
$ FAll = File + ";*"
$ !
$TP0:
$ ! First, evaluate the top ;version of the group:
$ Tested = 0
$ Junk   = F$SEARCH("RESET.RESET",2)      !ensure a fresh start...
$ TopF   = F$SEARCH(FAll,2)
$ TopV   = F$PARSE(TopF,,,"VERSION","SYNTAX_ONLY") - ";"
$ TopVN  = F$INTEGER(TopV)
$ TopCDT = F$FILE_ATTRIBUTE(TopF,"CDT")  !file's creation datetime
$ TopDT  = F$CVTIME(TopCDT,"COMPARISON")
$TP1:
$ ! Look at the remaining files in the group in descending ;version order:
$ CurF   = F$SEARCH(FAll,2)
$ IF CurF .EQS. "" THEN GOTO TP99  !end-of-file-group, so quit
$ CurV   = F$PARSE(CurF,,,"VERSION","SYNTAX_ONLY") - ";"
$ CurVN  = F$INTEGER(CurV)
$ CurCDT = F$FILE_ATTRIBUTE(CurF,"CDT")  !file's creation datetime
$ CurDT  = F$CVTIME(CurCDT,"COMPARISON")
$ !
$ IF CurDT .GTS. TopDT
$ THEN IF TestMode
$      THEN TopF   = CurF
$           TopCDT = CurCDT
$           TopDT  = CurDT
$           Tested = 1
$           GOT TP1  !next file in group
$      ELSE NxtVN = TopVN + 1
$           IF Verbose
$           THEN wso "%''Fac'-I-UNTANGLING, ''CurF'"
$                wso "                             renamed to version [1m;''NxtVN'[0m"
$           ENDIF
$           RENAME 'CurF' 'File';'NxtVN' 'Confirm'
$           TopVN = NxtVN
$           GOTO TP0  !start the whole analysis over for this file group...
$      ENDIF
$ ELSE GOTO TP1  !next file in group
$ ENDIF
$ !
$TP99:
$ IF TestMode .AND. Tested
$ THEN wso ""
$      wso "%''Fac'-I-[1mKNOT_DETECTED[0m, this file-group is entangled:"
$      DIRECTORY /NOTRAIL /DATE /WIDTH=(FILENAME=50) 'FAll'
$      wso ""
$      wso "%''Fac'-I-ANALYSIS, file [1m''TopF'[0m"
$      wso "                           is most-recent: [1m''TopDT'[0m"
$      wso ""
$ ENDIF
$ EXIT 1
$ !
$TPError:
$ Stat = $STATUS
$ EXIT 1
$ ENDSUBROUTINE  ! TheProcess
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  useage: [1m@FILE$UNTANGLE filespec[0m[[1m,filespec[0m...] [ [1m/CONFIRM[0m | [1m/TEST[0m ]

  where:

    [1mP1[0m -- a single filename, a wild-carded file specification, or a comma-
          separated list of these.
    
    [1m/CONFIRM[0m -- prompts you to confirm each file untangle operation before
          it is performed; without this qualifier, the process continues
          without prompting you... or...
    
    [1m/TEST[0m -- performs most-recent version and datetime analysis without
          actually renaming (untangling) any files in a FILENAME.EXT group.
          Then mode is useful when looking for problems in a directory, and
          to be sure that such analysis is indeed correct before committing
          to actually doing the untangle (renaming) operations.
    
  FILE$UNTANGLE is a command file which "untangles" a file's "most current"
  problem which can sometimes occur with files restored from a BACKUP save-
  set.
  
  It operates by assuming that the correct and desired ordering of multi-
  version files has the "latest" file version "on top", i.e., the [1mmost recent
  file[0m also carries the [1mhighest version by number[0m.

  Occasionally, when restoring one or more files from a BACKUP save-set,
  "older" files can be restored "over" (i.e., with higher file versions)
  than "newer" files:
  
      this (which is wrong):             rather than this (correct):
      ======================             ===========================
      FOO.BAR;13 20-MAR-2000             FOO.BAR[4m;14  1-APR-2000[0m
      FOO.BAR;12 18-MAR-2000             FOO.BAR;13 20-MAR-2000
      FOO.BAR[4m;6   1-APR-2000[0m             FOO.BAR;12 18-MAR-2000
    
  In the above examples, the time-portion of each file's datetime stamp is
  omitted for visual clarity and simplicity --- however, the argument here,
  and the processing done by FILE$UNTANGLE, is the same taking into account
  the full datetime stamp of each file processed.

  This problem typically happens if the BACKUP save-set contains multiple
  versions for one or more files, and all are restored [4mwith[0m the /NEW_VERSION
  qualifier: in this case, they are "reverse-restored".  This problem can
  also occur when using FTP to get or put files with wildcard specifications:
  because FTP has a particularly "Unix-like" view of a file-system, it too
  can "reverse-copy" files by version.

  Note that in the "wrong" example above, the "latest" version of the file
  FOO.BAR, dated 1-APR-2000, was restored as version ;6 (probably the original
  version number of the file as recorded in the save-set), rather than being
  correctly restored (with /NEW_VERSION) as on the right, as version ;14 (the
  "top-most" version).

  FILE$UNTANGLE sorts this problem out.  For each unique FILENAME.EXT within
  a given directory, it scans through all existing versions of that file,
  finds the one whose datetime stamp is [4mmost recent[0m, and renames that file
  to the [4mcurrent top version number[0m (one version number higher than the top
  version number of the "entangled" group of files).
  
  Note that this process does [4mnot[0m completely re-sort the file-group by date-
  time stamps... it only [4mensures that the latest (most recent) file is "on[0m
  [4mtop" with the highest version number[0m.  Any lingering entanglements of older
  files should be dealt with by PURGE-ing.

$ !
$ GOTO Done
