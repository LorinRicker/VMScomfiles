$ ! FILE$CLEANUP.COM --                                            'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1998-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  useage: @FILE$CLEANUP [ fname[,fname...] | @filelist ]
$ !                        [ /LOG ] [ /TEST ]
$ !                        [ /KEEP[=n] | /PURGE[=n] ]
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ IF F$TYPE(Util$Fac) .EQS. ""
$ THEN Util == "@site$utils:utility.com"
$      Util START FIL
$ ENDIF
$ wso = "WRITE sys$output"
$ DD  = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(DD,,,"NAME","SYNTAX_ONLY")
$ DD  = F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ LogFlag = 0  !(required init/define)
$ !
$ FIL$Count      == 0
$ FIL$ALQDeleted == 0
$ FIL$EOFDeleted == 0
$ FIL$LastD      == ""
$ !
$L0:
$ IF P1 .EQS. "" -
    THEN READ /PROMPT="filename: " -
    /END_OF_FILE=Done sys$command P1
$ IF P1 .EQS. "" THEN GOTO L0
$ IF F$EXTRACT(0,1,P1) .EQS. "?" THEN GOTO Help
$ !
$ N = 1
$ P0 = P2 + P3 + P4 + P5 + P6 + P7 + P8  !lump'em all together
$ P0 = F$EDIT(P0,"COMPRESS,TRIM,UPCASE")
$ P0L = F$LENGTH(P0)
$ LogFlag  = ( F$LOCATE("/LOG", P0) .LT. P0L ) .OR. ( F$LOCATE("/LOG",P1) .LT. F$LENGTH(P1) )
$ KeepFlag = ( F$LOCATE("/KEEP",P0) .LT. P0L ) .OR. ( F$LOCATE("/PURGE",P0) .LT. P0L )
$ IF LogFlag
$ THEN P1 = P1 - "/LOG"
$ ENDIF
$ IF KeepFlag
$ THEN K = P0 - "/KEEP" - "/PURGE" - "/LOG" - "/TEST"
$      K = F$ELEMENT(1,"=",K)
$      IF K .NES. "=" THEN N = F$INTEGER(K)
$      IF N .LT. 1 THEN N = 1
$ ENDIF
$ !
$ Debug = F$TRNLNM("TOOLS$Debug") .OR. ( F$LOCATE("/TEST",P0) .LT. P0L )
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
$ Fl = F$SEARCH(FS,1)
$ IF Fl .NES. ""
$ THEN CALL TheProcess "''Fl'" "''N'"
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
$ IF Fl .EQS. "" THEN GOTO IS0                     !skip blank lines & comments
$ Fl = Fl - F$PARSE(Fl,,,"VERSION","SYNTAX_ONLY")  !strip any version-spec
$!===============
$ CALL TheProcess "''Fl'" "''N'"
$!===============
$ GOTO IS0
$ !
$IS1:
$ CLOSE f
$ !
$Done:
$ IF Debug
$ THEN wso ""
$      wso "%''Fac'-I-TEST_ONLY, [1mtest mode only[0m, no files were actually deleted..."
$      msg = F$FAO("!27* !ZL file!%S, would be deleted", -
                   FIL$Count)
$      wso msg
$      msg = F$FAO("!27* !ZL(!ZL) blocks, excluding purges", -
                   FIL$ALQDeleted, FIL$EOFDeleted)
$      wso msg
$      wso ""
$ ELSE IF LogFlag
$      THEN IF FIL$Count .EQ. 0
$           THEN wso "%''Fac'-I-NOFILES, no files qualified for cleanup, none deleted"
$           ELSE msg = F$FAO("%!AS-S-CLEANED, deleted !ZL file!%S, reclaiming !ZL block!%S", -
                               Fac, FIL$Count, FIL$ALQDeleted)
$                wso msg
$           ENDIF
$      ENDIF
$ ENDIF
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
$ ON WARNING THEN GOTO TPDone
$ ON CONTROL_Y THEN EXIT %X2C
$  !
$ FV = P1 - F$PARSE(P1,,,"VERSION","SYNTAX_ONLY")
$ P1 = FV + ";*"
$ IF KeepFlag
$ THEN Keep = "/KEEP=''N'"
$ ELSE Keep = ""
$ ENDIF
$ IF LogFlag
$ THEN Log = "/LOG"
$ ELSE Log = "/NOLOG"
$ ENDIF
$ CDate = ""
$ !
$TP0:
$ F = F$SEARCH(P1,2)
$ IF F .EQS. "" THEN GOTO TPEnd
$ !
$ D = F$PARSE(F,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(F,,,"DIRECTORY","SYNTAX_ONLY")
$ IF D .EQS. FIL$LastD
$ THEN FN = "  " + F - D
$ ELSE FIL$LastD == D
$      FN = F - D
$      FN = "[1m" + D + "[0m" + FN
$ ENDIF
$ !
$ T = F$PARSE(F,,,"TYPE","SYNTAX_ONLY")
$ IF ( T .EQS. ".RDB" ) .OR. ( T .EQS. ".RDA" ) .OR. ( T .EQS. ".SNP" ) -
  THEN GOTO TP0  !skip any/all Rdb files...!
$ !
$ ! Updatable .%LB or .DAT file? Check revision date, else use creation date
$ RevFile = ( F$EXTRACT(2,2,T) .EQS. "LB" ) -
            .OR. ( T .EQS. ".DAT" )
$ IF RevFile
$ THEN FDate = F$CVTIME( F$FILE_ATTRIBUTES(F,"RDT"), "COMPARISON", "DATE" )
$ ELSE FDate = F$CVTIME( F$FILE_ATTRIBUTES(F,"CDT"), "COMPARISON", "DATE" )
$ ENDIF
$ ! Also determine file's size & allocation for reporting:
$ F_EOF = F$FILE_ATTRIBUTES(F,"EOF")  !actual block-size (file-size)
$ F_ALQ = F$FILE_ATTRIBUTES(F,"ALQ")  !allocation for this file
$ !
$ IF ( FDate .NES. CDate ) .OR. ( CDate .EQS. "" )
$ THEN CDate = FDate       !Keep first/top copy of this file for this date
$      Vers  = F$PARSE(F,,,"VERSION","SYNTAX_ONLY") - ";"
$      Vers0 = F$INTEGER(Vers)
$      IF RevFile
$      THEN Dt = "rev:" + FDate
$      ELSE Dt = FDate
$      ENDIF
$      IF Debug THEN wso "%''Fac'-I-KEEP,   ''FN' (''Dt')"
$ ELSE                     !...delete all older versions for this date
$      V  = F$PARSE(F,,,"VERSION","SYNTAX_ONLY") - ";"
$      V0 = F$INTEGER(V)
       IF V0 .LT. Vers0
$      THEN IF .NOT. Debug
$           THEN ON ERROR THEN EXIT $STATUS  !bail-out if no access/file-protect
$                DELETE 'F' 'Log'
$           ELSE wso "%''Fac'-I-[1mDELETE[0m, ''FN'"
$           ENDIF
$           FIL$Count      == FIL$Count + 1
$           FIL$EOFDeleted == FIL$EOFDeleted + F_EOF
$           FIL$ALQDeleted == FIL$ALQDeleted + F_ALQ
$      ENDIF
$ ENDIF
$ GOTO TP0
$ !
$TPEnd:
$ IF KeepFlag
$ THEN IF .NOT. Debug
$      THEN ON ERROR THEN EXIT $STATUS       !bail-out if no access/file-protect
$           PURGE 'FV' 'Keep' /NOLOG
$      ELSE wso "%''Fac'-I-[1mPURGE[0m,  ''FV' ''Keep'"
$      ENDIF
$ ENDIF
$ !
$TPDone:
$ EXIT 1
$ ENDSUBROUTINE  ! TheProcess
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ Debug = "FALSE"
$ TYPE sys$input /page

  FILE$CLEANUP is a process that purge/deletes a file-group (multiple versions
  of a file-specification), retaining only the [1mlatest [0m(most recent or top-most)
  file version [1mfor each date[0m.

  In other words, where software development edits produce several versions of
  a file on Monday, several more on Tuesday, and a few more on Wednesday, then
  a FILE$CLEANUP operation done late Wednesday will result in purge/deleting
  so that there is a [1msingle file version [0m(the latest) [1mfor each day[0m --- one for
  Wednesday, plus the single latest file version for Tuesday, and the single
  latest for Monday --- three files, the latest version for each day, remain.

  This process compares Revision Dates for all updatable data and library
  files (.DAT, .TLB, .HLB, .OLB, etc.), but checks Creation Dates for all
  other file types.

  Rdb database files (.RDB, .RDA and .SNP) are ignored completely, i.e.,
  these files will never be deleted or purged by FILE$CLEANUP.

  useage: @FILE$CLEANUP [ fname[,fname...] | @filelist ]
                        [ /KEEP[=N] | /PURGE[=N] ]
                        [ /LOG ] [ /TEST ]

  where:

   [1mP1[0m is a single filespec ([1mfname[0m), a file-list ([1mfname,fname,...[0m), or an
      indirection to a list of filespecs, one file per line ([1m@filelist[0m).
      Wildcards are supported for both [1mfname[0m and [1mfname,fname,...[0m forms,
      but not within indirect file lists.

      FILE$CLEANUP works on each filespec component separately, retaining
      the latest version-per-date for each individual file.

    Optional qualifiers:

      [1m/KEEP=N[0m -- Specifies that, after date-based deletes are done, the
        remaining files will be purged, keeping only the most recent [1mN[0m
        versions.  In this case, [1mall[0m versions will be subject to purge,
        regardless of date.

      [1m/KEEP[0m -- Same as [1m/KEEP=1[0m.

      [1m/PURGE[=N][0m -- Exactly the same as /KEEP[=N].

      [1m/LOG[0m -- Output log-messages for all file delete operations
        (purging is silent).

      [1m/TEST[0m -- Invokes a [1msafe test-mode[0m; messages are printed to show
        which files will be kept and which ones will be deleted, and a
        test-alert (warning) message is printed at the end of this output,
        but [1mno files are actually deleted[0m.

        Remove this /TEST qualifier to actually delete files for this
        file-specification.

    Note:  [1mQualifiers may not be abbreviated[0m.

$ GOTO Done
