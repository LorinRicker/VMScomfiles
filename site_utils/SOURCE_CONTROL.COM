$ ! SOURCE_CONTROL.COM -- SOURCE$LIBRARY maintenance               'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1992-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  @SOURCE_CONTROL [[-]Func] [File[,File]] [ModuleName]
$ !
$ !   'Func' is: A  = Apply a diff-file to an extracted base file
$ !              C  = Compare module with a file (checksum)
$ !              D  = create a Diff-file
$ !              E  = Extract a module
$ !              F  = File-compare a module with a file
$ !              H  = History of library updates
$ !              K  = c(K)ompress source$library (/DATA=REDUCE)
$ !              L  = List source$library contents
$ !              N  = New library (make one)
$ !              Q  = Query mode
$ !              R  = Remove a module
$ !              S  = Show source$library contents
$ !              U  = Update a module with a file
$ !              V  = Verbose mode
$ !              W  = Wide terminal mode
$ !              X  = Xverbose mode (debug)
$ !              AU = Apply & Update
$ !              DU = Diff-file & Update
$ !              ?  = Display help
$ !
$ !   'File' can be a list of files, including wildcards "*" and "%".
$ !
$ !   'ModuleName' is the name of a module within the SOURCE$LIBRARY
$ !
$ ON CONTROL_Y THEN GOTO Done
$ ON ERROR     THEN GOTO Done
$ Fac    = "%SRCCON-"
$ EDIT   = "EDIT"
$ DEFINE = "DEFINE /PROCESS"
$ WSO    = "WRITE sys$output"
$ IDT    = "$site$utils:library_idt"
$ MnL    = 39                   !Maximum length for a text library module name
$ !use KED's symbol CX to determine default file-type, with fallback to .PAS:
$ IF F$TYPE(CX) .EQS. "" THEN CX = ".pas"
$ dext = F$PARSE(CX,".pas",,"TYPE","SYNTAX_ONLY")
$ !
$ Sep   = "|"
$ Comma = ","
$ Legal = ""
$ Lset  = "ACDEFHKLNQRSUVWX"
$ Tmp   = Lset
$ !
$BldLegal:   !create a separated list out of Lset characters:
$ Legal = Legal + Sep + F$EXTRACT(0,1,Tmp)
$ Tmp   = F$EXTRACT(1,F$LENGTH(Tmp)-1,Tmp)
$ IF Tmp .NES. "" THEN GOTO BldLegal
$ !Include "AU" and "DU":
$ Legal  = Legal + Sep + "AU" + Sep + "DU" + Sep
$ !
$ParseFunction:
$ IF F$EXTRACT(0,1,P2) .EQS. "-"  !oops... got "func" in P2, swap with P1
$ THEN Tmp = P2
$      P2  = P1
$      P1  = Tmp
$ ENDIF
$ P1 = P1 - "-"  !other than that, assume P1 is "func" and strip any "-"
$ IF P1 .EQS. ""
$ THEN WSO "   Difference¹  Apply²       Update¹²     Compare      File-diff³"
$      WSO "   Show         List         History"
$      WSO "   Kompress     New          Extract      Remove"
$      WSO "   /Query       /Verbose     /Wide³       /Xverbose"
$      WSO ""
$      READ sys$command P1 /END_OF_FILE=Done /PROMPT="Function <S>? "
$      CF = ""          !Force filespec prompt, too (local CF)
$ ENDIF
$ P1 = F$EDIT(P1,"COLLAPSE,UPCASE")
$ IF P1 .EQS. "?" THEN GOTO Help
$ IF P1 .EQS. "" THEN P1 = "S"
$ !
$ !Any of (Query,Verbose,Debug) are OK; don't error-check these functions:
$ Tmp = Sep + P1 - "/" - "Q" - "/" - "V" - "/" - "W" - "/" - "X" + Sep
$ IF F$LOCATE(Tmp,Legal) .GE. F$LENGTH(Legal)         !legal function requested?
$ THEN WSO "''Fac'E-BADCOMMAND, illegal command ""''P1'"""
$      WSO ""
$      P1 = ""
$      GOTO ParseFunction
$ ELSE L = ""
$   ParseP1:
$      L = F$EXTRACT(0,1,Lset)
$      Lset = F$EXTRACT(1,F$LENGTH(Lset)-1,Lset)
$      'L'$ = ( F$LOCATE(L,P1) .LT. F$LENGTH(P1) )  !is function asserted in P1?
$      IF Lset .NES. "" THEN GOTO ParseP1
$ ENDIF
$ IF X$
$ THEN V$ = X$    !debug implies verbose mode
$      WSO "''Fac'I-VERSION, ''F$ENVIRONMENT("PROCEDURE")'"       !Show com-file
$ ENDIF
$ !
$ ! The source$library logical name:
$ !   1) Usually, a /PROCESS logical name is set by a CONTEXT.COM or by
$ !      SC$VUE.COM (FileView wrapper); if no /PROCESS logical name exists,
$ !      then a /JOB logical is honored if it exists.
$ !   2) If undefined (in either table, /PROCESS or /JOB), then search for
$ !      the file SOURCE$LIBRARY.TLB from current subdirectory back up to
$ !      the root directory --- first found is defined/used; if none found,
$ !      then error-msg and quit.
$ IF F$TRNLNM("source$library") .EQS. ""
$ THEN S = F$TRNLNM("sys$disk")
$      D = "[]"    !Start at current (sub)directory, use first source$library
$    LibSearch:    ! found in this directory tree (looking from sub-to-root)
$      LD = F$PARSE("''S'''D'",,,"DIRECTORY","SYNTAX_ONLY")
$      IF LD .NES. "[000000]"   !MFD?
$      THEN IF F$SEARCH("''S'''LD'source$library.tlb") .NES. ""
$           THEN DEFINE source$library 'S''LD'source$library.tlb
$                GOTO LibFound
$           ELSE D = D - "]" + "-]"  !keep searching one [-] subdir at a time
$                GOTO LibSearch
$           ENDIF
$      ELSE IF N$
$           THEN CALL NewL$ 'MnL'   !make New Library
$           ELSE CALL Msg$ "E-NOLIBRARY, no SOURCE$LIBRARY found for this directory"
$           ENDIF
$           GOTO Done
$      ENDIF
$ ENDIF
$ !
$LibFound:
$ IF V$ THEN WSO "''Fac'I, SOURCE$LIBRARY = ",F$TRNLNM("source$library")
$LibrOperations:
$ IF H$
$ THEN CALL Hist$
$      GOTO Done
$ ENDIF
$ IF K$
$ THEN CALL Komp$
$      GOTO Done
$ ENDIF
$ IF L$
$ THEN CALL List$
$      GOTO Done
$ ENDIF
$ IF S$
$ THEN CALL Show$
$      GOTO Done
$ ENDIF
$ !
$PromptFile:
$ IF ( P2 .EQS. "" ) .AND. ( F$TYPE(CF) .NES. ""  ) THEN P2 = CF       !KED file
$ IF P2 .EQS. ""
$ THEN READ sys$command P2 /END_OF_FILE=Done /PROMPT="File? "
$      GOTO PromptFile
$ ELSE GOTO FirstFile
$ ENDIF
$ !
$FirstFile:
$ i = 0
$NextFile:
$ NFil = F$ELEMENT(i,Comma,P2)
$ IF NFil .EQS. Comma           !No more files?
$ THEN GOTO Done
$ ELSE i = i + 1
$      LFil = ""                !Init/forget Last File...
$ ENDIF
$ NFL   = F$LENGTH(NFil)
$ Wild$ = ( F$LOCATE("*",NFil) .LT. NFL ) .OR. ( F$LOCATE("%",NFil) .LT. NFL )
$ !
$FLoop:
$ IF ( .NOT. A$ ) .AND. ( .NOT. E$ ) .AND. ( .NOT. R$ )
$ THEN Fil = F$SEARCH(NFil,1)
$      ! F$Search returns "" iff NFil contains a wildcard, so must
$      ! remember and handle LFil for exact filespecs too:
$      IF ( Fil .EQS. "" ) .OR. ( Fil .EQS. LFil )
$      THEN GOTO NextFile
$      ELSE LFil = Fil             !For next iteration...
$      ENDIF
$ ELSE IF Wild$
$      THEN WSO "''Fac'E-NOWILDCARD, do not use wildcards"
$           WSO "   with Apply, Extract or Remove"
$           P2 = ""     !force re-prompt
$           CF = ""
$           GOTO PromptFile
$      ELSE Fil = F$PARSE(NFil,,,,"SYNTAX_ONLY")
$      ENDIF
$ ENDIF
$ Typ = F$PARSE(Fil,,,"TYPE","SYNTAX_ONLY")
$ IF Typ .EQS. ".DIF"
$ THEN IF .NOT. Wild$ THEN WSO "''Fac'E-RECURSE, cannot apply ''Fil' to itself"
$      GOTO FLoop
$ ENDIF
$ IF Q$
$ THEN READ sys$command Answer /END_OF_FILE=Done /PROMPT="''Fil' <N>? "
$      Answer = F$PARSE(Answer,"No",,"NAME","SYNTAX_ONLY")
$ ELSE Answer = "Yes"  !not Query mode, so do it...
$ ENDIF
$ IF Answer
$ THEN ModName = P3
$      IF ModName .EQS. ""
$      THEN ModName = F$PARSE(Fil,,,"NAME","SYNTAX_ONLY") + "-" + Typ - "."
$      ENDIF
$      IF F$LENGTH(ModName) .GT. MnL
$      THEN WSO "''Fac'E-NAMTOOLONG, module name is too long"
$           WSO "   ""''ModName'"" (>''MnL' char)"
$           IF Wild$
$           THEN GOTO FLoop  !next file, if any...
$           ELSE GOTO Done   !no wildcards, bail out...
$           ENDIF
$      ENDIF
$ ELSE GOTO FLoop            !Query mode: No, don't process this file; next...
$ ENDIF
$ Dir  = F$PARSE(Fil,,,"DEVICE","SYNTAX_ONLY") -
       + F$PARSE(Fil,,,"DIRECTORY","SYNTAX_ONLY")
$ Name = F$PARSE(Fil,,,"NAME","SYNTAX_ONLY")
$ Base = Dir + Name + ".sc$base"
$ Dif  = Dir + Name + ".dif"
$ !
$FileOperations:
$ IF A$
$ THEN CALL Appl$ 'Base' 'Fil' 'ModName' 'Dif'
$      IF U$ THEN CALL Upda$ 'Fil' 'ModName'
$      GOTO NextFile  !no wildcards, remember?...
$ ENDIF
$ IF C$ THEN CALL Comp$ 'Base' 'Fil' 'ModName'
$ IF D$
$ THEN CALL Diff$ 'Base' 'Fil' 'ModName' 'Dif'
$      IF U$ THEN CALL Upda$ 'Fil' 'ModName'
$      GOTO Floop
$ ENDIF
$ IF E$
$ THEN CALL Extr$ 'Base' 'Fil' 'ModName'
$      GOTO NextFile  !no wildcards, remember?...
$ ENDIF
$ IF F$ THEN CALL FCmp$ 'Base' 'Fil' 'ModName'
$ IF R$
$ THEN CALL Remo$ 'Base' 'Fil' 'ModName'
$      GOTO NextFile  !no wildcards, remember?...
$ ENDIF
$ IF U$ THEN CALL Upda$ 'Fil' 'ModName'
$ GOTO Floop
$ !
$Done:
$ EXIT
$ !
$ !
$Msg$:  SUBROUTINE
$ SET NOON
$ WSO Fac, P1
$ IF P4 .NES. "" THEN X$ = P4
$ IF X$ .AND. ( P2 .NES. "" ) THEN WSO "   ", P2
$ IF X$ .AND. ( P3 .NES. "" ) THEN WSO "   ", P3
$ IF X$ .AND. ( ( P2 .NES. "" ) .OR. ( P3 .NES. "" ) ) THEN WSO ""
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Appl$:  SUBROUTINE  !Apply a *.DIF
$ SET NOON
$ P2 = P2 - F$PARSE(P2,,,"VERSION","SYNTAX_ONLY")
$ IF V$ THEN CALL Msg$ "I-APPLY, updating source ''P2'" -
                       "libr module: ''P3'" -
                       "   dif file: ''P4'"
$ CALL Extr$ 'P1' "" 'P3'
$ Stat = $STATUS
$ IF Stat
$ THEN EDIT /SUM /OUTPUT='P2' 'P1' /UPDATE='P4'
$      IF $STATUS THEN CALL Clean$ 'P4';0  !the dif-file
$      CALL Clean$ 'P1';*                  !the base file
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Comp$:  SUBROUTINE  !Compare checksums: base and current file
$ SET NOON
$ IF V$ THEN CALL Msg$ "I-COMPARE, comparing ''P2'"
$ CALL Extr$ 'P1' "" 'P3'
$ IF $STATUS
$ THEN CHECKSUM /FILE 'P1'                      !base file = libr module
$      P1$CS = " «" + F$STRING( CHECKSUM$CHECKSUM ) + "»"
$      CHECKSUM /FILE 'P2'                      !source file
$      P2$CS = " «" + F$STRING( CHECKSUM$CHECKSUM ) + "»"
$      Same = ( P1$CS .EQS. P2$CS )
$      Ctrl = ( V$ .OR. Wild$ )
$      IF .NOT. V$
$      THEN P1$CS = ""
$           P2$CS = ""
$      ENDIF
$      IF Same
$      THEN CALL Msg$ "S-OK, source file and libr module are in sync" -
                      "source file: ''P2'''P2$CS'" "" 'Ctrl'
$      ELSE CALL Msg$ "W-DIFFERENT, source file and libr module are different" -
                      "source file: ''P2'''P2$CS'" -
                      "libr module: ''P3'''P1$CS'" "TRUE"
$      ENDIF
$      CALL Clean$ 'P1';*                  !the base file
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Diff$:  SUBROUTINE  !produce a *.DIF
$ SET NOON
$ IF V$ THEN CALL Msg$ "I-DIFF, creating dif file ''P4'" -
                       "source file: ''P2'" -
                       "libr module: ''P3'"
$ CALL Extr$ 'P1' "" 'P3'
$ IF $STATUS
$ THEN DIFFERENCE /SLP /OUTPUT='P4' 'P1' 'P2'
$      CALL Clean$ 'P1';*                  !the base file
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Extr$:  SUBROUTINE  !Extract a module
$ SET NOON
$ IF P2 .NES. ""
$ THEN P2 = P2 - F$PARSE(P2,,,"VERSION","SYNTAX_ONLY")
$      IF V$ THEN CALL Msg$ "I-EXTRACT, creating source ''P2'" -
                            "libr module: ''P3'"
$ ENDIF
$ DEFINE /USER_MODE sys$output nl:          !suppress "module not found" msgs
$ DEFINE /USER_MODE sys$error  nl:
$ LIBRARY /EXTRACT=('P3') /OUTPUT='P1' source$library
$ Stat = $STATUS
$ IF Stat
$ THEN IF P2 .NES. ""
$      THEN RENAME 'P1' 'P2'
$      Stat = $STATUS
$      ENDIF
$ ELSE CALL Msg$ "W-NOMODULE, module ''P3' not found in SOURCE$LIBRARY" -
                 "source file: ''P2'"
$ ENDIF
$ EXIT ( %X10000000 .OR. Stat )
$ ENDSUBROUTINE
$ !
$Fcmp$:  SUBROUTINE  !Difference base and current file
$ SET NOON
$ IF V$ THEN CALL Msg$ "I-FILECOMP, file comparing ''P2'"
$ CALL Extr$ 'P1' "" 'P3'
$ IF $STATUS
$ THEN IF W$
$      THEN IF F$GETDVI("sys$command","DEVBUFSIZ") .LE. 80 -
            THEN SET TERMINAL /WIDTH=132
$           Idnt = 52
$      ELSE Idnt = 26
$      ENDIF
$      Wdth = F$STRING( F$GETDVI("sys$command","DEVBUFSIZ") )
$      WSO F$FAO("!''Wdth'*=")
$      WSO F$FAO("!''Idnt'* Libr Module  |  Source File")
$      DIFFERENCES /PARALLEL 'P1' 'P2'
$      CALL Clean$ 'P1';*                  !the base file
$ ENDIF
$ WSO ""
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Hist$:  SUBROUTINE  !List history of library updates
$ SET NOON
$ LIBRARY /LIST /HISTORY source$library
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Komp$:  SUBROUTINE  !c(K)ompress the library
$ SET NOON
$ SrcLib = F$PARSE("source$library")
$ IF V$ THEN CALL Msg$ "I-KOMPRESS, compressing SOURCE$LIBRARY (''SrcLib')"
$ LIBRARY /COMPRESS /DATA=REDUCE source$library
$ IF $STATUS THEN SET FILE 'SrcLib' /TRUNCATE
$ IF $STATUS THEN PURGE source$library
$ IF V$ THEN DIRECTORY /SIZE=ALL /DATE /PROTECTION 'SrcLib'
$ EXIT 1
$ ENDSUBROUTINE
$ !
$List$:  SUBROUTINE  !List library contents
$ SET NOON
$ LIBRARY /LIST source$library
$ EXIT 1
$ ENDSUBROUTINE
$ !
$NewL$:  SUBROUTINE  !Make a new library
$ SET NOON
$ IF F$SEARCH("source$library",2) .EQS. ""
$ THEN CALL Msg$ "I-CREATE, creating new SOURCE$LIBRARY"
$      DEFINE source$library 'F$ENVIRONMENT("DEFAULT")'source$library.tlb
$      LIBRARY /TEXT /CREATE=(KEYSIZE:'P1') source$library /DATA=REDUCE
$ ELSE CALL Msg$ "E-LIBEXISTS, SOURCE$LIBRARY already exists"
$      SHOW LOGICAL /FULL source$library
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Remo$:  SUBROUTINE  !Remove a module
$ SET NOON
$ IF V$
$ THEN CALL Msg$ "I-REMOVE, removing module ''P3'"
$      log = "/LOG"
$ ELSE log = ""
$ ENDIF
$ CALL Extr$ 'P1' 'P2' 'P3'
$ IF $STATUS
$ THEN LIBRARY /DELETE=('P3') 'log' source$library
$      CALL Clean$ 'P1';*                  !the base file
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Show$:  SUBROUTINE  !Show modules & dates in library
$ SET NOON
$ DEFINE /USER_MODE lib$dt_format lib$date_format_006,lib$time_format_005
$ IDT LIST source$library
$ WSO F$FAO("!46* Default file-type: ""!AS""",dext)
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Upda$:  SUBROUTINE  !Update the library
$ SET NOON
$ !If Applying, then strip version from output source filespec:
$ IF A$ THEN P1 = P1 - F$PARSE(P1,,,"VERSION","SYNTAX_ONLY")
$ IF V$ THEN CALL Msg$ "I-UPDATE, updating libr module ''P2'" -
                       "source file: ''P1'"
$ LIBRARY /REPLACE source$library 'P1' /MODULE=('P2')
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Clean$:  SUBROUTINE
$ P1 = F$PARSE(P1,"sys$disk:[].sc$base",,,"SYNTAX_ONLY")
$ IF P1 .NES. ""    !cleanup from previous iteration before next file
$ THEN IF F$SEARCH(P1,2) .NES. ""
$      THEN IF X$ THEN WSO "''Fac'I-CLEANUP, deleting ''P1'"
$           DelPrv = F$SETPRV("SYSPRV")
$           DELETE /NOLOG 'P1'
$           DelPrv = F$SETPRV(DelPrv)
$      ENDIF
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  SOURCE_CONTROL is a command procedure which supports basic source-control
  library functions using a standard VMS text library and its modular contents.

  SOURCE_CONTROL operates on the source library referred to by the logical name
  SOURCE$LIBRARY, which may be defined (by you, the user) either manually or,
  more typically, by CD'ing to a directory which has a CONTEXT.COM file which
  defines the appropriate source library for you (i.e., within the context of
  a particular project and/or directory-tree).

  usage:  @SOURCE_CONTROL [[-]Func] [File[,File]] [ModuleName]

   where
   'Func' is: A  = Apply a diff-file to an extracted base file
              C  = Compare module with a file (checksum)
              D  = create a Diff-file
              E  = Extract a module
              F  = File-compare a module with a file
              H  = History of library updates
              K  = c(K)ompress source$library (/DATA=REDUCE)
              L  = List SOURCE$LIBRARY contents
              N  = New library (make one)
              Q  = Query mode
              R  = Remove a module
              S  = Show SOURCE$LIBRARY contents
              U  = Update a module with a file
              V  = Verbose mode
              W  = Wide terminal mode
              X  = Xverbose mode (debug)
              AU = Apply & Update
              DU = Diff-file & Update
              ?  = Display help

   'File' can be a list of files, including wildcards "*" and "%".

   'ModuleName' is the name of a module within the SOURCE$LIBRARY

$ GOTO Done
