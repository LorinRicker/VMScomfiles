$ ! FILE$WILDCOMP.COM --                                           'F$VERIFY(0)'
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
$ !   v1.0 - Base release.  02/11/2005 LMR
$ !
$ !   use: @FILE$WILDCOMP [wildcard_filespec] [target_directory]
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Fac = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(Fac,,,"NAME","SYNTAX_ONLY")
$ Verbose = F$TRNLNM("Tools$Debug")
$ !
$ IF P1 .EQS. "?" THEN GOTO Help
$ !
$ wso = "WRITE sys$output"
$ IF F$TYPE(compare) .NES. ""
$ THEN comp*are = "DIFFERENCE /PARALLEL"
$ ENDIF
$ !
$ IF P1 .EQS. ""
$ THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="Wildcard filespec <*.DEF>: "
$      IF P1 .EQS. "" THEN P1 = "*.DEF"
$ ENDIF
$QP2:
$ IF P2 .EQS. ""
$ THEN READ sys$command P2 /END_OF_FILE=Done /PROMPT="Comparison directory: "
$      GOTO QP2
$ ENDIF
$ Tar = F$PARSE(P2,,,"NODE","SYNTAX_ONLY") -
      + F$PARSE(P2,,,"DEVICE","SYNTAX_ONLY") -
      + F$PARSE(P2,,,"DIRECTORY","SYNTAX_ONLY")
$ !
$ Prompt = F$FAO("[Enter] to contine (next file),!/") -
         +       "  [1mor[0m [4mC[0momp, [4mD[0miff, [4mG[0met, [4mP[0mut, [4mT[0mime[4mS[0mtamp: "
$ !
$Loop:
$ Answer = ""
$ F = F$SEARCH(P1,1)
$ IF F .EQS. "" THEN GOTO Done
$ wso F$FAO("!/!4*= [1m!AS[0m !#*=", F, 80-F$LENGTH(F)-6 )
$LoopOp:
$ Src = F$PARSE(F,,,"NODE","SYNTAX_ONLY") -
      + F$PARSE(F,,,"DEVICE","SYNTAX_ONLY") -
      + F$PARSE(F,,,"DIRECTORY","SYNTAX_ONLY")
$ F = F$PARSE(F,,,"NAME","SYNTAX_ONLY") + F$PARSE(F,,,"TYPE","SYNTAX_ONLY")
$ SrcF  = F$SEARCH("''Src'''F'",2)
$ TarF  = F$SEARCH("''Tar'''F'",2)
$ SrcTS = F$FILE_ATTRIBUTES("''SrcF'","CDT")
$ TarTS = F$FILE_ATTRIBUTES("''TarF'","CDT")
$ !
$ IF Answer .EQS. ""
$ THEN CHECKSUM /FILE 'SrcF'
$      SrcCSum = F$INTEGER(CHECKSUM$CHECKSUM)
$      CHECKSUM /FILE 'TarF'
$      TarCSum = F$INTEGER(CHECKSUM$CHECKSUM)
$      IF SrcCSum .EQ. TarCSum
$      THEN wso F$FAO( "%!AS-I-[1mEQ[0m, files [1mare equivalent[0m (by checksum) -!/!4* !AS -!/!4* !AS", -
                       Fac, SrcF, TarF )
$      ELSE Compare 'SrcF' 'TarF'
$      ENDIF
$      GOTO LPrompt
$ ELSE GOTO L$'Answer'
$ !
$L$C:  ! (request the comparison again)
$      Compare 'SrcF' 'TarF'
$      GOTO LPrompt
$ !
$L$D:  ! Pure DIFF
$      DIFFERENCE 'SrcF' 'TarF'
$      GOTO LPrompt
$ !
$L$G:  !Get
$      IF Verbose
$      THEN wso "%''Fac'-I-ECHO_GET, $ [1mCOPY ''TarF' ''Src'[0m"
$      ELSE COPY /LOG 'TarF' 'Src'
$      ENDIF
$      GOTO LPrompt
$ !
$L$P:  !Put
$      IF Verbose
$      THEN wso "%''Fac'-I-ECHO_PUT, $ [1mCOPY ''SrcF' ''Tar'[0m"
$      ELSE COPY /LOG 'SrcF' 'Tar'
$      ENDIF
$      GOTO LPrompt
$ !
$L$T:
$L$S:  !DateTimeStamp
$      wso F$FAO( "!/%!AS-I-TIMESTAMPS, -!/ [4m!AS[0m  !AS!/ [4m!AS[0m  !AS", -
                  Fac, SrcTS, SrcF, TarTS, TarF )
$      GOTO LPrompt
$ ENDIF
$ !
$LPrompt:
$ wso ""
$ READ sys$command Answer /END_OF_FILE=Done /PROMPT="''Prompt'"
$ Answer = F$EDIT(F$EXTRACT(0,1,Answer),"COLLAPSE,UPCASE")
$ IF Answer .NES. ""
$ THEN GOTO LoopOp
$ ELSE GOTO Loop
$ ENDIF
$ !
$Done:
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

 FILE$COMPWILD is a command procedure which supports the comparison of a
 large number of related filespecs (files related by file-type, e.g. *.DEF
 or *.PAS, etc.) with corresponding files in another directory.

  use:  [1m@FILE$COMPWILD [wildcard_filespec] [target_directory][0m

    [1mwildcard_filespec[0m is a file specification, including one or more wildcards,
                      which is the source group of files to be compared.

    [1mtarget_directory[0m  is a local or remote target directory containing versions
                      of this same group of files with which to compare the
                      source files.

 FILE$COMPWILD loops through the source file group, providing a comparison
 of each file pair's checksum (for each file in the pair) by default.  If
 the checksums of the two files are identical, this is reported with the
 message:
 
   %FILE$WILDCOMP-I-[1mEQ[0m, files [1mare equivalent[0m (by checksum) ...
 
 If the checksums are different, then a DIFFERENCE comparison is done on the
 file pair, shown as a parallel-formated report.

 After each file is compared, the user is prompted to either [4mcontinue to the[0m
 [4mnext file in the loop[0m or to [4mchoose another file operation for the current[0m
 [4mfile pair[0m, with this prompt:

    [1m[Enter][0m to contine (next file),
      [1mor[0m [4mC[0momp, [4mD[0miff, [4mG[0met, [4mP[0mut, [4mT[0mime[4mS[0mtamp:

 Press the [1m[Enter][0m key if you want to simply proceed to [4mcompare the next file[0m
 in the wildcard loop.

 Enter [1mC[OMPARE][0m if you want to [4mrepeat the DIFFERENCE comparison operation[0m in
 parallel display mode.

 Enter [1mD[IFF][0m if you want to [4mrepeat the DIFFERENCE comparison operation[0m; this
 time, the DIFFERENCE report is in [1mline-by-line[0m (default, not parallel) format,
 so you can examine entire lines for textual differences.

 Enter [1mP[UT][0m if, based on the comparison, you decide that you want to [1mcopy[0m
 the [4mcurrent source file to the target directory[0m.

 Enter [1mG[ET][0m if, based on the comparison, you want to [1mcopy[0m the [4mcurrent target[0m
 [4mfile to the source directory[0m.

 Enter [1mT[IMESTAMP][0m to review the creation dates/times for both files.


 [4mExample[0m

 $ [1mSHOW SYMBOL /GLOBAL WILDCOMP[0m
   WILDCOMP*ARE == "@SITE$UTILS:FILE$WILDCOMP.COM"
 $ [1mSHOW DEFAULT[0m
   DISK$USER2:[LT_DEV.COMMON]   !on node OUTLAW
 $ [1mMLOG /LOG /REMOTE=BANDIT[0m
      "R1" [super] = "BANDIT::[LT_DEV.COMMON]" (LNM$PROCESS_TABLE)

 $ [1m[4mWILDCOMP *.DEF R1:[0m

 ==== [1mDISK$USER2:[LT_DEV.COMMON]ABOUT_INMATE.DEF;6[0m =============================
 %FILE$WILDCOMP-I-[1mEQ[0m, files [1mare equivalent[0m (by checksum) -
     DISK$USER2:[LT_DEV.COMMON]ABOUT_INMATE.DEF;6 -
     BANDIT::SYS$USER1:[LT_DEV.COMMON]ABOUT_INMATE.DEF;6

 [1m[Enter][0m to contine (next file),
   [1mor[0m [4mC[0momp, [4mD[0miff, [4mG[0met, [4mP[0mut, [4mT[0mime[4mS[0mtamp: [1m[Enter][0m

 ==== [1mDISK$USER2:[LT_DEV.COMMON]ACHECK_FACSIMILE.DEF;6[0m =========================
 -------------------------------------------------------------------------------
 File DISK$USER2:[LT_DEV.COMMON]ACHECK  |  File BANDIT::SYS$USER1:[LT_DEV.COMMON
 ------------------- 6 ------------------------------------- 6 -----------------
 ! Copyright © 2002-2003 by LockWorks   |  ! Copyright © 2002-2004 by LockWorks
 -------------------------------------------------------------------------------

 Number of difference sections found: 1
 Number of difference records found: 1

 DIFFERENCES /IGNORE=()/PARALLEL-
     DISK$USER2:[LT_DEV.COMMON]ACHECK_FACSIMILE.DEF;6-
     BANDIT::SYS$USER1:[LT_DEV.COMMON]ACHECK_FACSIMILE.DEF;7

 [1m[Enter][0m to contine (next file),
   [1mor[0m [4mC[0momp, [4mD[0miff, [4mG[0met, [4mP[0mut, [4mT[0mime[4mS[0mtamp: [1m[Enter][0m

 ==== [1mDISK$USER2:[LT_DEV.COMMON]CASE_SEARCH.DEF;59[0m =============================
 ------------------------------------------------------------------------------
 File DISK$USER2:[LT_DEV.COMMON]CASE_S |  File BANDIT::SYS$USER1:[LT_DEV.COMMON
 ------------------- 51 ----------------------------------- 51 ----------------
 FIELD SID /POS=(4,47) /SIZE=8 /DATATY |  FIELD SID /POS=(4,47) /SIZE=8 /DATATY
 ------------------------------------------------------------------------------

 Number of difference sections found: 1
 Number of difference records found: 1

 DIFFERENCES /IGNORE=()/PARALLEL-
     DISK$USER2:[LT_DEV.COMMON]CASE_SEARCH.DEF;59-
     BANDIT::SYS$USER1:[LT_DEV.COMMON]CASE_SEARCH.DEF;61

 [1m[Enter][0m to contine (next file),
   [1mor[0m [4mC[0momp, [4mD[0miff, [4mG[0met, [4mP[0mut, [4mT[0mime[4mS[0mtamp: [1mDIFF[0m
 ************
 File DISK$USER2:[LT_DEV.COMMON]CASE_SEARCH.DEF;59
 51   FIELD SID /POS=(4,47) /SIZE=8 /DATATYPE=VARCHAR:10 -
 52     /ATTR=(DISPLAY_ONLY) /EXPORT=SID
 ******
 File BANDIT::SYS$USER1:[LT_DEV.COMMON]CASE_SEARCH.DEF;61
 51   FIELD SID /POS=(4,47) /SIZE=8 /DATATYPE=CHAR:10 -
 52     /ATTR=(DISPLAY_ONLY) /EXPORT=SID
 ************

 Number of difference sections found: 1
 Number of difference records found: 1

 DIFFERENCES /IGNORE=()/MERGED=1-
     DISK$USER2:[LT_DEV.COMMON]CASE_SEARCH.DEF;59-
     BANDIT::SYS$USER1:[LT_DEV.COMMON]CASE_SEARCH.DEF;61

 [1m[Enter][0m to contine (next file),
   [1mor[0m [4mC[0momp, [4mD[0miff, [4mG[0met, [4mP[0mut, [4mT[0mime[4mS[0mtamp: [1mGET[0m
 %COPY-S-COPIED, BANDIT::SYS$USER1:[LT_DEV.COMMON]CASE_SEARCH.DEF;61 copied to
 DISK$USER2:[LT_DEV.COMMON]CASE_SEARCH.DEF;61 (5 blocks)

 [1m[Enter][0m to contine (next file),
   [1mor[0m [4mC[0momp, [4mD[0miff, [4mG[0met, [4mP[0mut, [4mT[0mime[4mS[0mtamp: [1m[Enter][0m

  ...(etc. for the rest of the files)...

$ !
$ GOTO Done
