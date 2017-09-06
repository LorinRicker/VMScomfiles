$ ! FILE$COMPARE.COM -- driver for more esoteric DIFFERENCE use    'F$VERIFY(0)'
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
$ !  use: @FILE$COMPARE operation file1 [file2] [qualifiers]
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ IF F$TYPE(Util$Fac) .EQS. ""
$ THEN Util == "@site$utils:utility.com"
$      Util START CMP
$ ENDIF
$ !
$ Status  = 1
$ Verbose = F$TRNLNM("TOOLS$Debug")     !generic Tools debug flag
$ !
$ wso = "WRITE sys$output"
$ DD  = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(DD,,,"NAME","SYNTAX_ONLY")
$ DD  = F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ !
$L0:
$ IF P1 .NES. "" THEN GOTO L1
$ READ /END_OF_FILE=Done /PROMPT="option ([1mCheck[0m/Comp/Bars/Bin/Wide/SLP): " sys$command P2
$ GOTO L0
$L1:
$ IF ( P1 .EQS. "?" ) .OR. ( F$EXTRACT(0,1,P2) .EQS. "?" ) THEN GOTO Help
$ Util CMDPARSE "''P1'" Answer "CHECK" "CHECK       |COMPARE     |BARS        |BINARY      |WIDEPARALLEL|SLP_OUTPUT  |HELP        "
$ IF CMP$Answer .EQS. "HELP" THEN GOTO Help
$ !
$ IF F$LOCATE("/",P3) .LT. F$LENGTH(P3)  ! jiggle qualifiers to P4,
$ THEN P4 = P3                           !  if P3 is logically empty
$      P3 = ""
$ ENDIF
$ !
$L2:   ! P2 is first filename, P3 is second (or empty)
$ IF P2 .NES. "" THEN GOTO L3
$ READ /END_OF_FILE=Done /PROMPT="filename: " sys$command P2
$ GOTO L2
$L3:
$ F1 = F$SEARCH(P2)
$ IF F1 .NES. ""
$ THEN IF P3 .EQS. ""
$      THEN P3 = F1 - F$PARSE(F1,,,"VERSION","SYNTAX_ONLY") + ";-1"
$      ENDIF
$      P3 = P3 - ".*" - "*"           !remove any wildcard chars... then get
$      F2 = F$SEARCH(F$PARSE(P3,P2))  !missing parts of P3 filespec from P2
$      IF F2 .EQS. ""
$      THEN P2 = P3
$           GOTO Err_FNF
$      ENDIF
$ ELSE GOTO Err_FNF
$ ENDIF
$ !
$ FullChk = ( F$LOCATE("/FU",P4) .LT. F$LENGTH(P4) )  ! for CHECK operation
$ !
$ TextFile = F$FILE_ATTRIBUTES(F1,"ORG") .EQS. "SEQ"      -
             .AND. F$FILE_ATTRIBUTES(F1,"RAT") .EQS. "CR" -
             .AND. F$FILE_ATTRIBUTES(F1,"RFM") .EQS. "VAR"
$ GOTO 'CMP$Answer'
$ !
$CHECK:
$ Prv = F$SETPRV("SYSPRV")
$ CHECKSUM 'F1'
$ F1_checksum = F$INTEGER(CHECKSUM$CHECKSUM)
$ CHECKSUM 'F2'
$ F2_checksum = F$INTEGER(CHECKSUM$CHECKSUM)
$ IF F1_checksum .EQ. F2_checksum
$ THEN Status = %X006C8009                        !files are same
$      wso "%''Fac'-S-SAME, files have same checksum value"
$ ELSE Status = %X006C8013                        !files are different
$      wso "%''Fac'-I-DIFFERENT, files have different checksum values"
$ ENDIF
$ IF Verbose .OR. FullChk
$ THEN n = 64
$      wso F$FAO("  !''n'<!AS!>  %X!XL", F1, F1_checksum)
$      wso F$FAO("  !''n'<!AS!>  %X!XL", F2, F2_checksum)
$ ENDIF
$ GOTO Done
$ !
$BINARY:  ! binary file comparisons, &/or dump-style output
$ IF TextFile
$ THEN ascii = ",ASCII"
$ ELSE ascii = ""
$ ENDIF
$ DIFFERENCE 'P2' 'P3' /MODE=(HEXADECIMAL'ascii') 'P4'
$ GOTO Done
$ !
$BARS:  ! change bars on ASCII files
$ DIFFERENCE 'P2'/CHANGE_BAR="|" 'P3' 'P4'
$ GOTO Done
$ !
$WIDEPARALLEL:
$ IF ( F$GETDVI("sys$command","DEVBUFSIZ") .EQ. 80 ) -
  THEN SET TERMINAL /WIDTH=132
$COMPARE:
$ DIFFERENCE 'P2' 'P3' /PARALLEL 'P4'
$ GOTO Done
$ !
$SLP_OUTPUT:
$ slp = P2 - F$PARSE(P2,,,"TYPE","SYNTAX_ONLY") + ".SLP"
$ ! Make a SLP file which edits F2 (the ;-1 file) into F1 (the ;0 file) ---
$ !  Yes, these arguments seem "backwards", but are in correct order!
$ DIFFERENCE 'F2' 'F1' /SLP /OUTPUT='slp'
$ slp = F$SEARCH(slp)
$ wso "%''Fac'-I-SLPOUT, file ''slp' created"
$ GOTO Done
$ !
$Done:
$ IF F$TYPE(Prv) .EQS. "STRING" THEN Prv = F$SETPRV(Prv)
$ Util EXIT
$ EXIT Status
$ !
$Err_FNF:
$ wso "%''Fac'-E-FNF, cannot find file ''P2'"
$ GOTO Done
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE sys$input /PAGE

  useage: @FILE$COMPARE operation file1 [file2] [qualifiers]

  where:

    [1moperation[0m is one of the following command arguments, which may be
      abbreviated to any minimally unique spelling:

       CHECK        - Default.  Performs a checksum comparison on [1mfile1[0m and
                      its predecessor (previous version), or between file1
                      and [1mfile2[0m.  Reports either that ``files have same
                      checksum value'' (a good indicator that they are
                      indeed identical) or that ``files have different
                      checksum values'' (they are not the same).

                      If the qualifier [1m/FULL[0m is specified, or the logical
                      name [1mTOOLS$Debug[0m has the value "Yes", "True" or "1",
                      then the output will include the file specifications 
                      and the corresponding hexadecimal checksum values.

       BINARY       - Performs a binary DIFFERENCES command to compare [1mfile1[0m
                      to [1mfile2[0m, with output in hexadecimal "dump" format.
                      This operation can be used with both a "proper" VMS
                      text file and any binary file format.

       BARS         - Performs a standard DIFFERENCES command to compare
                      [1mfile1[0m to [1mfile2[0m with change-bar formatting.  The "|"
                      character is used to mark each line in the file1
                      which is different from file2.

       COMPARE      - Performs a standard DIFFERENCES command to compare
                      [1mfile1[0m to [1mfile2[0m in parallel-listing format.

       WIDEPARALLEL - Same as PARALLEL, but first puts your terminal in
                      "[1mwide[0m" (132-column) display mode.

       SLP_OUTPUT   - Creates a SLP differences file which can be used
                      to change (auto-edit) [1mfile2[0m into [1mfile1[0m.  See the
                      DCL command EDIT/SUM and the SUMSLP utility as
                      documented in the [1mOpenVMS SUMSLP Utility Manual[0m.

    [1mfile1[0m is the first file to compare.  This file can be either a "proper"
      VMS text file, or it can be any other binary file type.

    [1mfile2[0m is an optional second file to compare to the first file (P2).  If
      this file specification is omitted, then the previous version (next
      lowest version number) of the first file is used for comparison.
      P3 also inherits any missing parts of its file specification from
      the corresponding parts of P2.

    [1mqualifiers[0m provides any additional DIFFERENCES command qualifiers which you
      may want to use to augment the behavior of the BINARY, BARS, PARALLEL
      or WIDEPARALLEL operations.  These additional qualifiers are ignored
      for the COMPARE and SLP_OUTPUT operations.

    The [1m/FULL[0m qualifier may be given for the CHECK operation -- this displays
      file specifications and the corresponding hexadecimal checksum values.

$ GOTO Done
$ !
