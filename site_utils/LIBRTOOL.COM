$ ! LIBRTOOL.COM --                                                'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2003-2004 by LockWorks LLC.  All rights reserved.
$ !
$ !  v1.1 - Add DECnet nodename and/or disk specifications to /PRODUCTION,
$ !         /DEVELOPMENT and /TESTING; minor fixes & tweaks. 03/26/2003 LMR
$ !  v1.0 - Initial release. 03/25/2003 LMR
$ !
$ !  use:  @LIBRTOOL [ REPLACE (D) | CHECK | LIST | COMPRESS ] -
$ !                  [ library ] [ files,... ] -
$ !                  [ /PRODUCTION[=[node::][dev:]] |
$ !                    /DEVELOPMENT[=[node::][dev:]] |
$ !                    /TESTING[=[node::][dev:]] ] -
$ !                  [ /LOG (D) | /NOLOG ] [ /VERBOSE ]
$ !
$ ON ERROR THEN EXIT 1
$ Util = "@site$utils:utility.com"
$ Util START LTL "" "V2003.02.03"  !Require this minimum version of UTILITY.COM
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Fac = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ DD  = F$ENVIRONMENT("DEFAULT")
$ DD  = F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ wso = "WRITE sys$output"
$ !
$ Verbose = F$TRNLNM("Tools$Debug")
$ !
$ IF P1 .EQS. "?" THEN GOTO Help
$ !
$ ! Initialize, -1 means listing not yet generated;
$ !             = 0 means line count unknown (no TAIL.EXE);
$ !             > 0 is line count of listing file:
$ LTL$LineCount  == -1
$ !
$ LTL$RemSpec    == ""
$ LibListing      = "sys$scratch:LTL$LibListing.lis"
$ Tail            = "site$utils:tail.exe"
$ !
$ Comma = ","
$ Dot   = "."
$ Slash = "/"
$ Equal = "="
$ Colon = ":"
$ ULine = "_"
$ !
$L1:
$ IF P1 .EQS. ""
$ THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="Option <REPLACE>: "
$      P1 = F$PARSE(P1,"REPLACE",,"NAME","SYNTAX_ONLY")
$      GOTO L1
$ ENDIF
$ Util CMDPARSE "''P1'" "Cmd" "REPLACE" "REPLACE |CHECK   |LIST    |COMPRESS"
$ !
$ Files = ""
$ IF F$EXTRACT(0,1,P3) .EQS. "/"
$ THEN Quals = P3
$ ELSE Files = P3
       Quals = ""
$ ENDIF
$L3:
$ IF ( P3 .EQS. "" ) .AND. ( Files .EQS. "" ) -
  .AND. ( ( LTL$Cmd .EQS. "REPLACE" ) .OR. ( LTL$Cmd .EQS. "CHECK" ) )
$ THEN READ sys$command P3 /END_OF_FILE=Done /PROMPT="File(s): "
$      IF P3 .NES. "" THEN Files = P3
$      GOTO L3
$ ENDIF
$ !
$ i = 4
$QL:
$ IF Quals .EQS. ""
$ THEN Quals = P'i'
$ ELSE Quals = Quals + " " + P'i'
$ ENDIF
$ IF i .LT. 8
$ THEN i = i + 1
$      GOTO QL
$ ENDIF
$ Quals = F$EDIT(Quals,"COMPRESS,TRIM,UPCASE")
$ QLen  = F$LENGTH(Quals)
$ Tree = "DEV"
$ IF F$LOCATE("/PRO",Quals) .LT. QLen
$ THEN Tree = "PROD"
$      CALL ParseQuals "''Quals'" "PRO"  !returns LTL$RemSpec
$ ELSE IF F$LOCATE("/TES",Quals) .LT. QLen
$      THEN Tree = "TEST"
$           CALL ParseQuals "''Quals'" "TES"  !returns LTL$RemSpec
$      ELSE IF F$LOCATE("/DEV",Quals) .LT. QLen
$           THEN Tree = "DEV"
$                CALL ParseQuals "''Quals'" "DEV"  !returns LTL$RemSpec
$           ENDIF
$      ENDIF
$ ENDIF
$ IF F$LOCATE("/NOLO",Quals) .LT. QLen
$ THEN Log = "/NOLOG"
$ ELSE Log = "/LOG"
$ ENDIF
$ Verbose = Verbose .OR. ( F$LOCATE("/VER",Quals) .LT. QLen )
$ !
$ ! Iteratively peel down through subdirectory(ies), saving the root-dir,
$ !   and the last one to offer as default Tlb filename...
$ LibDefault = F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY") - "[" - "]"
$ Root = ""
$LD0:
$ LD = F$ELEMENT(0,Dot,LibDefault)
$ IF Root .EQS. "" THEN Root = LD - Dot
$ IF F$LOCATE(Dot,LibDefault) .GE. F$LENGTH(LibDefault)
$ THEN GOTO L2  ! done... LibDefault is "bottom" subdirectory
$ ELSE LD = LD + Dot
$      LibDefault = LibDefault - LD
$ ENDIF
$ GOTO LD0
$ !
$L2:
$ LTL$Dev == F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY")
$ LTL$Dir == F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ Base     = F$ELEMENT(0,ULine,Root)  ! extract the "LT" from "LT_DEV"...
$ T0       = LTL$Dir - "[" - "]"
$ T0       = F$ELEMENT(0,Dot,T0) + Dot
$ T1       = LTL$Dir - "[" - "]" - T0  ! "...subdir(s)" minus the root-dir name
$ IF Tree .EQS. "PROD"
$ THEN CALL DefaultDD "''Base'$ProdTree" "''T1'" "''DD'" "[''Base'"
$ ELSE IF Tree .EQS. "TEST"
$      THEN CALL DefaultDD "''Base'$TestTree" "''T1'" "''DD'" "[''Base'_TEST"
$      ELSE IF Tree .EQS. "DEV"
$           THEN CALL DefaultDD "''Base'$DevTree" "''T1'" "''DD'" "[''Base'_DEV"
$           ENDIF
$      ENDIF
$ ENDIF
$ IF F$LOCATE("::",LTL$RemSpec) .LT. F$LENGTH(LTL$RemSpec)   ! remote node?
$ THEN DD = LTL$Dir   ! Don't add DEV: -- either use what's specified in
$                     !  LTL$RemSpec, or use sys$disk default on remote node.
$ ELSE DD = LTL$Dev + LTL$Dir
$ ENDIF
$!!«» $ IF Verbose THEN wso "%''Fac'-I-DEBUG, LTL$RemSpec == ""''LTL$RemSpec'"", DD = ""''DD'"""
$ ! Combine (optional) remote node/dev specs with local dev/dir:
$ DD = F$PARSE(LTL$RemSpec,DD,,,"SYNTAX_ONLY") - ".;"
$ IF P2 .EQS. ""
$ THEN READ sys$command P2 /END_OF_FILE=Done /PROMPT="Library <''DD'''LibDefault'.TLB>: "
$ ENDIF
$ !
$ P2  = F$PARSE(P2,LibDefault,"''DD'.tlb",,"SYNTAX_ONLY")
$ Tlb = F$SEARCH(P2,2)
$ IF Tlb .EQS. ""
$ THEN wso "%''Fac'-E-FNF, no such file ''P2'"
$      GOTO Done
$ ELSE Tlb = Tlb - F$PARSE(Tlb,,,"VERSION","SYNTAX_ONLY")
$ ENDIF
$ !
$ ! Always report the target library, for user's sanity:
$ wso F$FAO( "!/%!AS-I-LIBRARY, [4m!AS[0m", Fac, Tlb )
$ !
$ ! Either...
$ !  compress the library, or...
$ !  produce a full listing of library contents:
$ IF ( LTL$Cmd .EQS. "COMPRESS" ) -
  .OR. ( ( LTL$Cmd .EQS. "LIST" ) .AND. ( Files .EQS. "" ) )
$ THEN CALL Libr$'LTL$Cmd' 'Tlb'
$      GOTO Done
$ ENDIF
$ !
$ ! Otherwise, process for each file,...
$DirectSpec:
$ IF Files .EQS. ""
$ THEN wso "%''Fac'-W-NOFILES, no file(s) to process"
$      GOTO Done
$ ENDIF
$ i = 0
$ F0 = "sys$disk:[]"
$DS0:
$ Fl = F$ELEMENT(i,Comma,Files)
$ IF Fl .EQS. Comma THEN GOTO Done               !more files?
$ FS   = F$PARSE(Fl,F0,"*.def",,"SYNTAX_ONLY") !expand w/sticky dev:[dir]
$ FLen = F$LENGTH(FS)
$ Wild = ( F$LOCATE("*",FS) .LT. FLen ) .OR. ( F$LOCATE("%",FS) .LT. FLen )
$ GotOne = 0
$DS1:
$ F0 = F$PARSE(Fl,F0,,"DEVICE","SYNTAX_ONLY") -  !save sticky dev:[dir]
     + F$PARSE(Fl,F0,,"DIRECTORY","SYNTAX_ONLY")
$ Fl = F$SEARCH(FS,1)
$ IF Fl .NES. ""
$ THEN CALL Libr$'LTL$Cmd' "''Tlb'" "''Fl'"
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
$Done:
$ SET NOON
$ Util EXIT LTL
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$ !
$Libr$Check:  SUBROUTINE
$ ! P1 = Text library
$ ! P2 = Filespec of module to list
$ ON CONTROL_Y THEN GOSUB SCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ M = F$PARSE(P2,,,"NAME","SYNTAX_ONLY")
$ T = F$PARSE(P2,,,"TYPE","SYNTAX_ONLY") - Dot
$ CALL Libr$ModuleName "''P2'"  !returns LTL$ModName
$ IF Verbose
$ THEN T = P1 - F$PARSE(P1,,,"DEVICE","SYNTAX_ONLY") - F$PARSE(P1,,,"DIRECTORY","SYNTAX_ONLY") - ";"
$      wso F$FAO( "%!AS-I-CHECK, checking module !AS in library !AS", -
                  Fac, LTL$ModName, T )
$ ELSE ! Check P2 against extracted module from Tlb by CHECKSUM;
$      ! if same, say success,
$      ! else check previous versions until success or no-more-files
$      ModF = "sys$scratch:" + M + Dot + T
$      ON ERROR THEN GOTO KeyNotFound
$      DEFINE /NOLOG /USER_MODE sys$output _nla0:
$      DEFINE /NOLOG /USER_MODE sys$error  _nla0:
$      LIBRARY /TEXT /NOLOG /EXTRACT='LTL$ModName' /OUTPUT='ModF' 'P1'
$      ON ERROR THEN EXIT %X2C
$      CHECKSUM /FILE 'ModF'
$      ModFCS = CHECKSUM$CHECKSUM
$      CHECKSUM /FILE 'P2'
$      SrcFCS = CHECKSUM$CHECKSUM
$      IF SrcFCS .EQS. ModFCS
$      THEN P2 = P2 - F$PARSE(P2,,,"DEVICE","SYNTAX_ONLY")
$           wso F$FAO( "%!AS-S-OK,  current [1m!AS[0m matches!/!#* [1m!AS[0m", -
                       Fac, LTL$ModName, F$LENGTH(Fac)+9, P2 )
$           GOTO LChk2  !...found, done
$      ELSE SrcF = P2 - F$PARSE(P2,,,"VERSION","SYNTAX_ONLY") + ";*"
$           ! Throw this top-version away, already checked it above...
$           SF = F$SEARCH(SrcF,3)
$LChk0:
$           SF = F$SEARCH(SrcF,3)  ! previous version(s)...
$           IF SF .EQS. "" THEN GOTO LChk1  !...failed to match file version
$           CHECKSUM /FILE 'SF'
$           SrcFCS = CHECKSUM$CHECKSUM
$           IF SrcFCS .EQS. ModFCS
$           THEN V = F$PARSE(SF,,,"VERSION","SYNTAX_ONLY")
$                SF = SF - F$PARSE(SF,,,"DEVICE","SYNTAX_ONLY") - V
$                wso F$FAO( "%!AS-W-OLD, [4mstale[0m [1m!AS[0m matches!/!#* [1m!AS[4m!AS[0m", -
                            Fac, LTL$ModName, F$LENGTH(Fac)+9, SF, V )
$                GOTO LChk2  !...found, done
$           ELSE GOTO LChk0  !...next file candidate
$           ENDIF
$      ENDIF
$LChk1:  !...failed to match file version
$      P2 = P2 - F$PARSE(P2,,,"DEVICE","SYNTAX_ONLY") - F$PARSE(P2,,,"VERSION","SYNTAX_ONLY")
$      wso F$FAO( "%!AS-W-FNF, matching file version for [1m!AS[0m not found;!/!#* !AS matching file is [4mdeleted[0m", -
                  Fac, LTL$ModName, F$LENGTH(Fac)+9, P2 )
$LChk2:  !...found, done
$      IF F$SEARCH(ModF,2) .NES. "" THEN DELETE /NOLOG 'ModF';*
$ ENDIF
$ EXIT 1
$ !
$KeyNotFound:
$ SET NOON
$ wso F$FAO( "%!AS-W-KEYNOTFND, module !AS not found in library", -
             Fac, M )
$ EXIT 1
$ !
$SCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! Libr$Check
$ !
$Libr$Compress:  SUBROUTINE
$ ! P1 = Text library
$ SET NOON
$ T = P1 - F$PARSE(P1,,,"DEVICE","SYNTAX_ONLY") - F$PARSE(P1,,,"DIRECTORY","SYNTAX_ONLY") - ";"
$ IF Verbose
$ THEN wso F$FAO( "%!AS-I-ECHO, $ [1mLIBR /TEXT /COMPRESS !AS[0m", -
                  Fac, T )
$      wso F$FAO( "!#* $ [1mPURGE /SINCE /KEEP=2 !AS[0m", -
                  F$LENGTH(Fac)+10, T )
$ ELSE wso F$FAO( "%!AS-I-COMPRESS, compressing library !AS", Fac, T )
$      LIBRARY /TEXT /COMPRESS /NOLOG 'P1'
$      PURGE /NOLOG /SINCE /KEEP=2 'P1'  ! keep two versions from today,
$      PURGE /NOLOG        /KEEP=3 'P1'  !  and three versions total
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! Libr$Compress
$ !
$Libr$List:  SUBROUTINE
$ ! P1 = Text library
$ ! P2 = Filespec of module to list
$ SET NOON
$ IF Verbose
$ THEN IF LTL$LineCount .EQ. -1
$      THEN T = P1 - F$PARSE(P1,,,"DEVICE","SYNTAX_ONLY")
$           wso F$FAO( "%!AS-I-ECHO, $ [1mLIBR /TEXT /LIST=!AS /FULL -[0m!/!#* [1m!AS[0m", -
                       Fac, LibListing, F$LENGTH(Fac)+14, T )
$           LTL$LineCount == 0
$      ENDIF
$      IF P2 .NES. ""
$      THEN CALL Libr$ModuleName "''P2'"  !returns LTL$ModName
$           wso F$FAO( "!#* $ [1mSEARCH !AS ""!AS"" /WINDOW=1[0m", -
                       F$LENGTH(Fac)+10, LibListing, LTL$Modname )
$      ENDIF
$      EXIT 1
$ ENDIF
$ IF LTL$LineCount .EQ. -1
$ THEN LIBRARY /TEXT /LIST='LibListing' /FULL 'P1'
$      IF F$SEARCH(Tail,2) .NES. ""
$      THEN tail = "$''Tail'"
$           DEFINE /USER_MODE /NOLOG sys$output _nla0:
$           tail 'LibListing' /COUNT=LINES /SYMBOL=LineCount
$           LTL$LineCount == F$INTEGER(LineCount)
$      ELSE LTL$LineCount == 0  ! unknown
$      ENDIF
$ ENDIF
$ IF P2 .EQS. ""
$ THEN IF LTL$LineCount .GE. F$INTEGER(F$GETDVI("sys$output","TT_PAGE")) - 2
$      THEN Pg = "/PAGE"
$      ELSE Pg = "/NOPAGE"
$           wso F$FAO("!/!80*-")
$      ENDIF
$      TYPE 'LibListing' 'Pg'
$      wso F$FAO("!80*-!/")
$ ELSE CALL Libr$ModuleName "''P2'"  !returns LTL$ModName
$      wso F$FAO("!80*-")
$      SEARCH 'LibListing' "''LTL$ModName' " /WINDOW=1
$      wso F$FAO("!80*-")
$ ENDIF
$ IF F$SEARCH(LibListing) .NES. "" THEN PURGE /NOLOG 'LibListing'
$ EXIT 1
$ ENDSUBROUTINE  ! Libr$List
$ !
$Libr$Replace:  SUBROUTINE
$ ! P1 = Text library
$ ! P2 = filespec (module to replace)
$ SET NOON
$ CALL Libr$ModuleName "''P2'"  !returns LTL$ModName
$ IF Verbose
$ THEN T = P1 - F$PARSE(P1,,,"DEVICE","SYNTAX_ONLY") - F$PARSE(P1,,,"DIRECTORY","SYNTAX_ONLY") - ";"
$      F = P2 - F$PARSE(P2,,,"DEVICE","SYNTAX_ONLY")
$      wso F$FAO( "%!AS-I-ECHO, $ [1mLIBR /TEXT /REPLACE !AS !AS-!/!#* /MODULE=!AS [0m", -
                  Fac, T, F, F$LENGTH(Fac)+14, LTL$ModName )
$ ELSE LIBRARY /TEXT /REPLACE 'Log' 'P1' 'P2' /MODULE='LTL$ModName'
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! Libr$Replace
$ !
$Libr$ModuleName:  SUBROUTINE
$ ! P1 = filespec
$ ! returns global symbol LTL$ModName
$ SET NOON
$ FN = F$PARSE(P1,,,"NAME","SYNTAX_ONLY")
$ FT = F$PARSE(P1,,,"TYPE","SYNTAX_ONLY")
$ IF FT .EQS. ".DEF"
$ THEN LTL$ModName == FN
$ ELSE FT = FT - Dot
$      LTL$ModName == FN + ULine + FT
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! Libr$ModuleName
$ !
$ParseQuals:  SUBROUTINE
$ ! P1 = Qualifiers
$ ! P2 = Target qualifier (the one we're looking for)
$ SET NOON
$ Tmp = ""
$ i = 1
$PQ0:
$ Q = F$EDIT(F$ELEMENT(i,Slash,P1),"COLLAPSE,UPCASE")
$ IF ( Q .EQS. Slash ) .OR. ( Q .EQS. "" ) .OR. ( i .GT. 8 ) THEN GOTO PQ1
$ IF F$EXTRACT(0,3,Q) .EQS. P2
$ THEN Tmp = F$ELEMENT(1,Equal,Q)
$      IF Tmp .NES. Equal
$      THEN len = F$LENGTH(Tmp)
$           IF F$LOCATE(":",Tmp) .LT. len  !any colons at all?
$           THEN n = F$LOCATE("::",Tmp)
$                IF n .LT. len - 2
$                THEN dv = F$EXTRACT(n+2,len-n+2,Tmp)
$                     len = F$LENGTH(dv)
$                     IF F$EXTRACT(len-1,1,dv) .NES. ":" THEN Tmp = Tmp + ":"
$                ELSE IF n .GE. len THEN Tmp = Tmp + "::"
$                ENDIF
$           ELSE ! No colons, so figure out whether Tmp is a node or a disk;
$                !   this is a real hack -- F$DEVICE() is really finicky, so
$                !   the following logic works OK for distinguishing a node
$                !   like BANDIT from a disk such as SYS$USER1, but probably
$                !   breaks down for more tricky cases:
$                T0 = F$TRNLNM(Tmp) - ":"  !try a punctuation-free translation
$                IF F$EXTRACT(0,1,T0) .EQS. "_" THEN T0 = T0 - "_"
$                IF T0 .EQS. "" THEN T0 = Tmp  !not a logical? use it as is...
$                T0 = F$DEVICE("_''T0':","DISK")  !<< finicky about "_:"
$                IF T0 .NES. ""
$                THEN Tmp = Tmp + ":"  !a disk, append a colon
$                ELSE Tmp = Tmp + "::" !a nodename, append two colons
$                ENDIF
$           ENDIF
$      ELSE Tmp = ""
$      ENDIF
$      GOTO PQ1  ! done...
$ ELSE i = i + 1
$      GOTO PQ0  ! loop again...
$ ENDIF
$PQ1:
$ IF Tmp .NES. "" THEN LTL$RemSpec == Tmp
$ EXIT 1
$ ENDSUBROUTINE  ! ParseQuals
$ !
$DefaultDD:  SUBROUTINE
$ ! P1 = project logical name
$ ! P2 = desktop subdirectory
$ ! P3 = initial default dev/dir
$ ! P4 = directory to use if logical name not defined
$ SET NOON
$ IF F$TRNLNM(P1) .NES. ""
$ THEN LTL$Dev == F$PARSE(P1,,,"DEVICE","SYNTAX_ONLY")
$      LTL$Dir == F$PARSE(P1,,,"DIRECTORY","SYNTAX_ONLY") - "]" + Dot + P2 + "]"
$ ELSE LTL$Dev == F$PARSE(P3,,,"DEVICE","SYNTAX_ONLY")
$      LTL$Dir == P4 + Dot + P2 + "]"
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! DefaultDD
$ !
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  LIBRTOOL is a command procedure which supports several operations on
  text library (*.TLB) files, including:

  · Module insertion and replacement.
  · Listing of library contents.
  · Library file compression.
  · Checking of a module against its source file set either to verify
    that the module is current, or to identify which file version it
    matches.

  LIBRTOOL is designed to work within the RAPT project model, including
  development, production and testing directory trees.

  use: [1m@LIBRTOOL[0m [ [1mREPLACE[0m | [1mCHECK[0m | [1mLIST[0m | [1mCOMPRESS[0m ] -
                 [ [1mlibrary[0m ] [ [1mfiles,...[0m ] -
                 [ [1m/PRODUCTION[0m[[1m=[0m[[1mnode::[0m][[1mdev:[0m]]  |
                   [1m/DEVELOPMENT[0m[[1m=[0m[[1mnode::[0m][[1mdev:[0m]] |
                   [1m/TESTING[0m[[1m=[0m[[1mnode::[0m][[1mdev:[0m]]      ]
                 [ [1m/LOG[0m (D) | [1m/NOLOG[0m ] [ [1m/VERBOSE[0m ]

  where

  P1 - An option keyword:

       [1mREPLACE[0m  - [4mInserts[0m or [4mreplaces[0m source files into the text library
                  (*.TLB) file.  Requires both a text library file and
                  a source file or list of files (comma-separated).
                  [1m[4mNOTE![0m This REPLACE option is [4mnot[0m intended as a routine
                        substitute for RAPT MAKE (project build) formulae;
                        instead, it is to be used on a careful and occasional
                        basis to replace/update a given source file module,
                        requiring you, the user/developer, to assume full
                        responsibility for the consequences of this build-
                        shortcut.
       [1mCHECK[0m    - [4mVerifies[0m whether the module in the text library which
                  corresponds to each source file is:
                    · [4mcurrent[0m - the module matches the latest version of
                      that source file;
                    · [4mstale[0m - the module matches an older version of the
                      source file (and that version is identified);
                    · [4mnot found[0m - the module is not found in the library.
                  Requires both a library file and source file(s).
       [1mLIST[0m     - Generates either:
                    · a [4mfull listing[0m of the complete contents of the
                      library;
                    · a [4mbrief listing[0m of the module(s) in the library
                      which correspond to the source file(s).
                  Requires a library file; if no source files are given,
                  then a listing of the complete library is generated;
                  otherwise, a brief modular listing is provided for each
                  source file.
       [1mCOMPRESS[0m - [4mCompresses[0m (squeezes) the text library file, producing
                  a new file version of that library.  Older versions of
                  the library file set are purged to no more than three
                  versions.

  P2 - The name or full file specification of a [4mtext library[0m *.TLB file.
       This parameter is required for all command options.

       If not provided on the command line, the text library file is prompted
       using a default response which is based on the current subdirectory;
       that subdirectory name is used as the file name of the text library.
       For example, if your current directory location is [1mdev:[LT_DEV.JAIL][0m,
       then the prompt for this parameter offers the library file spec
       [1mdev:[LT_DEV.JAIL]JAIL.TLB[0m -- you can of course provide another text
       library file specification (complete or in parts).

  P3 - A [4msource file specification[0m, or a [4mcomma-separated list[0m of source file
       specs.  This parameter is required for the REPLACE and CHECK command
       options; it is optional for the LIST option; it is ignored for the
       COMPRESS option.

       Any file specification in this list defaults to the file type .DEF
       if the file type is missing.  Any other file type (e.g., .PAS, .MAK,
       etc.) must be specified if needed; non-.DEF files are inserted and
       checked with a module name of the form "<filename>_<filetype>"; .DEF
       files are inserted and checked with a module name which is simply
       the name of that file, "<filename>" (this corresponds to the conven-
       tions of RAPT project MAKE formulae).

       Files in a comma-separated list are processed one-at-a-time, in the
       order given.  Files which are specified without a dev: or [dir.sub]
       are assumed to be located in the current subdirectory; however, any
       file spec may include either dev: or [dir.sub] (or both), and that
       device/directory specification is `sticky' to subsequent files, until
       changed by a subsequent dev/dir specification.

  P4... - Qualifiers; any reasonable combination of:

        [1m/DEVELOPMENT[0m - Use any one of these qualifiers to specify that the
        [1m/PRODUCTION[0m    text library file is to be found in the [4mdevelopment[0m,
        [1m/TESTING[0m       [4mproduction[0m or [4mtesting[0m project directory tree, respec-
                       tively.  If [4mnone[0m of these three qualifiers is present
                       on the command line, then the text library must be
                       found in your current directory location.

                       Each of the above qualifiers can have an optional
                       remote node and/or remote device specified as its
                       value string (e.g., [1m/PRODUCTION=JUDSON::SYS$USER1:[0m).

                       · Specify [4mjust a nodename[0m in cases where the target
                         library is [4mlocated on a remote DECnet node[0m, and
                         the disk volume where it is located is the [4msame[0m
                         [4mdisk as your login device[0m on that remote node.

                       · Specify [4mjust a disk device[0m in the case where the
                         target library is [4mlocated on the local system[0m,
                         but it is on a disk drive which is [4mdifferent from[0m
                         [4myour current device-directory location[0m.

                       · Specify [4mboth the nodename and disk device[0m in the
                         case where the target library is [4mlocated on a[0m
                         [4mremote DECnet node[0m [1mand[0m [4mon a disk volume other[0m
                         [4mthan your login device on that remote node[0m.

                       · If the target library is [4mlocated on the local system[0m
                         [1mand[0m [4mon the same disk drive[0m as your current device-
                         directory location, then [4mdo not specify either a[0m
                         [4mnodename or a disk with the qualifier[0m.

                       Note that specifying a remote computer nodename
                       is supported only in a [1mDECnet[0m environment; TCP/IP
                       does not support this kind of remote access.

        [1m/LOG[0m         - Enables or disables command-log output messages as
        [1m/NOLOG[0m         text library operations are executed.  /LOG is the
                       default, on the assumption that confirming output
                       messages for command options are useful; use /NOLOG
                       to `run silently'.

        [1m/VERBOSE[0m     - Enables debug/trace mode for that invocation of the
                       command procedure, producing debug messages which
                       trace the operation of the procedure.  Note that in
                       this mode, command options are not actually performed;
                       instead, command text is output to display what opera-
                       tion(s) would have been performed if the procedure
                       is executed without /VERBOSE.  This is useful for both
                       debugging the command procedure and for understanding
                       how it works.

                       This qualifier is equivalent to asserting [1m$ TOOL ON[0m
                       (which sets the logical name TOOLS$DEBUG to "TRUE");
                       however, /VERBOSE is `one-shot' and must be provided
                       for each command line invocation, whereas the logical
                       name persists until [1m$ TOOL OFF[0m countermands it.

  [4mExamples[0m

  Note: These examples presume a working project directory using the RAPT
  `desktop' model, in which the name of the desktop's text library is
  identical to that of the subdirectory, e.g.: dev:[LT_DEV.[4mJAIL[0m][4mJAIL[0m.TLB
  Furthermore, assume that you have set this subdirectory as your current
  directory location:  $ [1mCD dev:[LT_DEV.JAIL][0m

  1.  $ [1m@site$utils:RAPT_TOOLS[0m   ! defines the command symbol [1mLIBT*OOL[0m

  2.  List the complete contents of the library:

      $ [1mLIBTOOL LIST[0m
      Library <DISK$USER2:[LT_DEV.JAIL]JAIL.TLB>: [1m<Enter>[0m

      %LIBRTOOL-I-LIBRARY, [4mDISK$USER2:[LT_DEV.JAIL]JAIL.TLB[0m

      Librarian A09-22
      Directory of TEXT library [LT_DEV.JAIL]JAIL.TLB;1 on 25-MAR-2003
      Creation date:   4-JAN-2003 12:05:25      Creator:  Librarian A09-22
      Revision date:   4-JAN-2003 12:06:13      Library format:   3.0
      Number of modules:    322                 Max. key length:  39
      Other entries:          0                 Preallocated index blocks: 11
      Recoverable deleted blocks:   0           Total index blocks used:   21
      Max. Number history records: 20           Library history records:   20

      $COMMON_MAK      inserted  4-JAN-2003 12:06:13
      $PRERELEASE_MAK  inserted  4-JAN-2003 12:06:13
      $RELEASE_MAK     inserted  4-JAN-2003 12:06:13
      ABOUT_COMPONENT_MAK inserted  4-JAN-2003 12:05:41
      ABOUT_INMATE     inserted  4-JAN-2003 12:05:39

      ... (output truncated) ...

  3.  List a couple of modules:

      $ [1mLIBT LIST jail booking,fingerprints[0m

      %LIBRTOOL-I-LIBRARY, [4mDISK$USER2:[LT_DEV.JAIL]JAIL.TLB[0m
      -----------------------------------------------------------------------
      [1mBOOKING[0m          inserted  4-JAN-2003 12:05:25
      -----------------------------------------------------------------------
      -----------------------------------------------------------------------
      [1mFINGERPRINTS[0m     inserted  4-JAN-2003 12:05:28
      -----------------------------------------------------------------------

  4.  Replace (update) these same two modules:

      $ [1mLIBT REPLACE jail booking,fingerprints[0m

      %LIBRTOOL-I-LIBRARY, [4mDISK$USER2:[LT_DEV.JAIL]JAIL.TLB[0m
      %LIBRAR-S-REPLACED, module BOOKING replaced in [LT_DEV.JAIL]JAIL.TLB
      %LIBRAR-S-REPLACED, module FINGERPRINTS replaced in [LT_DEV.JAIL]JAIL.TLB

      Repeating command example #3 above will verify these replacements
      with new insertion date/time stamps.

  5.  Replace a module from the [.LOOKUPS] (validation lists) directory,
      and verify it:

      $ [1mLIBT REPL jail [-.lookups]eye_color[0m

      %LIBRTOOL-I-LIBRARY, [4mDISK$USER2:[LT_DEV.JAIL]JAIL.TLB[0m
      %LIBRAR-S-REPLACED, module EYE_COLOR replaced in [LT_DEV.JAIL]JAIL.TLB
      $ [1mLIBT LIST jail [-.lookups]eye_color[0m
      ------------------------------------------------------------------------
      [1mEYE_COLOR[0m        inserted 25-MAR-2003 21:34:48
      ------------------------------------------------------------------------

  6.  Compress the text library:

      $ [1mDIR jail.tlb[0m

      Directory DISK$USER2:[LT_DEV.JAIL]

      JAIL.TLB;1                   1961   4-JAN-2003 12:05:25.33  (RWED,RWED,,)

      Total of 1 file, 1961 blocks.

      $ [1mLIBT COMPRESS jail[0m

      %LIBRTOOL-I-LIBRARY, [4mDISK$USER2:[LT_DEV.JAIL]JAIL.TLB[0m
      %LIBRTOOL-I-COMPRESS, compressing library JAIL.TLB
      $ [1mDIR jail.tlb[0m

      Directory DISK$USER2:[LT_DEV.JAIL]

      JAIL.TLB;2                   1799  25-MAR-2003 21:37:45.91  (RWED,RWED,,)
      JAIL.TLB;1                   1961   4-JAN-2003 12:05:25.33  (RWED,RWED,,)

      Total of 2 files, 3760 blocks.

      Note: This COMPRESS option also purges the .TLB file to no more than
            three (3) file versions.

  7.  Check some source file modules:

      $ [1mLIBT CHECK jail jail,jail.pas[0m

      %LIBRTOOL-I-LIBRARY, [4mDISK$USER2:[LT_DEV.JAIL]JAIL.TLB[0m
      %LIBRTOOL-W-OLD, [4mstale[0m [1mJAIL[0m matches
                       [1m[LT_DEV.JAIL]JAIL.DEF[4m;77[0m
      %LIBRTOOL-S-OK,  current [1mJAIL_PAS[0m matches
                       [1m[LT_DEV.JAIL]JAIL.PAS;121[0m

      $ DIR jail.def,jail.pas

      Directory DISK$USER2:[LT_DEV.JAIL]

      JAIL.DEF;79                     4  29-JAN-2003 14:48:22.74  (RWED,RWED,,)
      JAIL.DEF;77                     4  23-JAN-2002 20:05:43.79  (RWED,RWED,,)
      JAIL.PAS;121                    5   4-FEB-2002 14:59:13.71  (RWED,RWED,,)

      Total of 3 files, 13 blocks.

      Note that this example shows that the library module corresponding to
      JAIL.DEF is `old' (stale), and that the file version which matches that
      library module is actually JAIL.DEF[4m;77[0m, not the current version.  The
      module for JAIL.PAS (module name JAIL_PAS) is indeed current.

  8.  Check a source module on a remote (DECnet) computer system:

      $ [1mLIBT CHECK jail trustz /PRODUCTION=BANDIT[0m

      %LIBRTOOL-I-LIBRARY, [4mBANDIT::SYS$USER1:[LT.JAIL]JAIL.TLB[0m
      %LIBRTOOL-W-OLD, [4mstale[0m [1mTRUSTZ[0m matches
                       [1m[LT_DEV.JAIL]TRUSTZ.DEF[4m;60[0m

  9.  Check a source module on a remote (DECnet) computer system and on
      a disk volume which is different from your login device on that
      remote node:

      $ [1mLIBT CHECK jail trustz /TESTING=BANDIT::SYS$USER2[0m

      %LIBRTOOL-I-LIBRARY, [4mBANDIT::SYS$USER2:[LT_TEST.JAIL]JAIL.TLB[0m
      %LIBRTOOL-W-OK,  current [1mTRUSTZ[0m matches
                       [1m[LT_DEV.JAIL]TRUSTZ.DEF;64[0m

 10.  Check a source module on the local system, but on a disk drive which
      is different from your current device-directory location:

      $ [1mLIBT CHECK jail trustz /TESTING=SYS$USER3[0m

      %LIBRTOOL-I-LIBRARY, [4mSYS$USER3:[LT_TEST.JAIL]JAIL.TLB[0m
      %LIBRTOOL-W-OLD, [4mstale[0m [1mTRUSTZ[0m matches
                       [1m[LT_DEV.JAIL]TRUSTZ.DEF[4m;61[0m

 11.  What does the /VERBOSE qualifier do?

      $ [1mLIBT REPL jail jail.def /VERBOSE[0m
      %LIBRTOOL-I-LIB, library is [4mDISK$USER2:[LT_DEV.JAIL]JAIL.TLB[0m
      %LIBRTOOL-I-ECHO, $ [1mLIBR /TEXT /REPLACE JAIL.TLB [LT_DEV.JAIL]JAIL.DEF;79-[0m
                            [1m/MODULE=JAIL[0m

      This qualifier suppresses actual execution of commands, and just echoes
      them for your perusal.

$ !
$ GOTO Done
