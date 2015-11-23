$ ! COMPILER_VERSION.COM --                                        'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1999-2000 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  use:  @COMPILER_VERSION [ PASCAL | CC ]
$ !
$ !  Updated 12/21/2000 to look for "Compaq" rather than "DEC" compiler labels,
$ !  and improved some CVR$Version assignment logic. LMR
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ Fac = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ IF F$TYPE(Util$Fac) .EQS. ""
$ THEN Util == "@site$utils:utility.com"
$      Util START CVR
$ ENDIF
$ !
$ CVR$Verbose == F$TRNLNM("TOOLS$Debug")     !generic Tools debug flag
$ CVR$Arch == F$GETSYI("ARCH_NAME")
$ wso = "WRITE sys$output"
$ Vendor = "Compaq"  !formerly: "DEC"
$ !
$ D$Compilers = "PASCAL|CC    |CXX   |C++   "
$P1Loop:
$ IF P1 .EQS. ""
$ THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="Compiler (''F$EDIT(D$Compilers,"COLLAPSE")'): "
$      GOTO P1Loop
$ ELSE Util CMDPARSE "''P1'" Compiler "PASCAL" "''D$Compilers'"
$      IF CVR$Compiler .EQS. "C++" THEN CVR$Compiler == "CXX"
$      GOTO 'CVR$Compiler'
$ ENDIF
$ GOTO Done
$ !
$ !
$CC:        !DEC C compiler
$ IF CVR$Arch .EQS. "VAX"
$ THEN CVR$cpl == "sys$system:vaxc.exe"          !VAX
$      CVR$rtl == "sys$library:vaxcrtlg.exe"
$      CVR$str == "VAX C V"  !Vendor + " C V" ??
$ ELSE CVR$cpl == "sys$system:decc$compiler.exe" !Alpha
$      CVR$rtl == "sys$library:decc$shr.exe"
$      CVR$str == Vendor + " C V"
$ ENDIF
$ !
$ ! 1.  Compile a trivial program to parse the listing file:
$ FN = "sys$scratch:''CVR$Compiler'_list.tmp"
$ CC /NOOBJECT /LISTING='FN' sys$input
main( )
{ }
$ !
$ GOTO CommonAnalysis
$ !
$ !
$CXX:        !DEC C++ compiler
$ IF CVR$Arch .EQS. "VAX"
$ THEN wso "%''Fac'-W-UNSUPPORTED, the C++ language is not supported for VAX/VMS"
$      GOTO Done
$ ELSE CVR$cpl == "sys$system:cxx$compiler.exe"  !Alpha
$      CVR$rtl == "sys$library:cxxl$011_shr.exe"
$      CVR$str == Vendor + " C++ V"
$ ENDIF
$ !
$ ! 1.  Compile a trivial program to parse the listing file:
$ FN = "sys$scratch:''CVR$Compiler'_list.tmp"
$ CXX /NOOBJECT /LISTING='FN' sys$input
main( )
{ }
$ !
$ GOTO CommonAnalysis
$ !
$ !
$PASCAL:    !DEC Pascal compiler
$ IF CVR$Arch .EQS. "VAX"
$ THEN CVR$cpl == "sys$system:pascal.exe"        !VAX
$      CVR$rtl == "sys$library:pasrtl.exe"
$      CVR$str == Vendor + " Pascal V"
$ ELSE CVR$cpl == "sys$system:pascal.exe"        !Alpha
$      CVR$rtl == "sys$library:pas$rtl.exe"
$      CVR$str == Vendor + " Pascal V"
$ ENDIF
$ !
$ ! 1.  Compile a trivial program to parse the listing file:
$ FN = "sys$scratch:''CVR$Compiler'_list.tmp"
$ PASCAL /NOOBJECT /LISTING='FN' sys$input
PROGRAM TestVersion;
BEGIN
END.
$ !
$ GOTO CommonAnalysis
$ !
$ !
$CommonAnalysis:
$ CALL SearchFor "''CVR$str'" "''FN'" "" "CVR$Version"
$ i = F$LOCATE(CVR$str,CVR$Version)
$ l = F$LENGTH(CVR$Version)
$ IF i .LT. l
$ THEN v = F$EDIT(F$EXTRACT(i,l-i+1,CVR$Version),"COMPRESS")
$      CVR$Version == F$ELEMENT(0," ",v) + " " -
                    + F$ELEMENT(1," ",v) + " " -
                    + F$ELEMENT(2," ",v)
$ ELSE CVR$Version == "(''CVR$Compiler' version not found)"
$ ENDIF
$ wso ""
$ wso "[1m''CVR$Version'[0m"
$ !
$ ! 2. Analyze compiler image file for internal version information:
$ cpl = F$SEARCH(CVR$cpl)
$ IF cpl .EQS. ""
$ THEN wso "%''Fac'-W-FNF, cannot find compiler file [1m''CVR$cpl'[0m"
$ ELSE FN = "sys$scratch:''CVR$Compiler'_compiler.tmp"
$      DEFINE /USER_MODE sys$output nl:
$      DEFINE /USER_MODE sys$error  nl:
$      ANALYZE /IMAGE /OUTPUT='FN' 'cpl'
$      wso "Compiler internal version information"
$      wso "  for file [1m''cpl'[0m"
$      wso ""
$      CALL SearchFor "Image Identification Information" "''FN'" "Patch Information"
$ ENDIF
$ !
$ ! 3. Analyze language RTL/shareable file for internal version information:
$ rtl = F$SEARCH(CVR$rtl)
$ IF rtl .EQS. ""
$ THEN wso "%''Fac'-W-FNF, cannot find RTL file [1m''CVR$rtl'[0m"
$ ELSE FN = "sys$scratch:''CVR$Compiler'_rtl.tmp"
$      DEFINE /USER_MODE sys$output nl:
$      DEFINE /USER_MODE sys$error  nl:
$      ANALYZE /IMAGE /OUTPUT='FN' 'rtl'
$      wso "Language RTL/shareable internal version information"
$      wso "  for file [1m''rtl'[0m"
$      wso ""
$      !CALL SearchFor "Image Identification Information" "''FN'" "Patch Information"
$      CALL SearchFor "Image Identification Information" "''FN'" 8
$ ENDIF
$ !
$Done:
$ SET NOON
$ IF .NOT. CVR$Verbose
$ THEN DEFINE /USER_MODE sys$output nl:
$      DEFINE /USER_MODE sys$error  nl:
$      DELETE /NOLOG sys$scratch:'CVR$Compiler'_*.tmp;*
$ ENDIF
$ Util EXIT CVR
$ EXIT
$ !
$ !
$SearchFor:  SUBROUTINE
$ ! P1: String to locate
$ ! P2: File to read
$ ! P3: (optional) if string:  keep printing until this string is found
$ !                if integer: print `N' lines
$ ! P4: (optional) global symbol to set to found line
$ SET NOON
$ IF F$TYPE(P4) .EQS. "STRING" THEN IF P4 .NES. "" THEN 'P4' == ""  !initialize
$ OPEN /READ /ERROR=SF1 f 'P2'
$SF0:
$ READ /ERROR=SF1 /END_OF_FILE=SF1 f rec
$ r0 = F$EDIT(rec,"COMPRESS")
$ IF F$LOCATE(P1,r0) .LT. F$LENGTH(r0) THEN GOTO SF2
$ GOTO SF0
$SF2:
$ IF ( F$TYPE(P3) .EQS. "STRING" ) .AND. ( P3 .NES. "" )
$ THEN CALL PrintUntil "''rec'" "''P3'"
$ ELSE IF F$TYPE(P3) .EQS. "INTEGER"
$      THEN i = 1
$SF4:                 !print next `N' lines
$           wso rec
$           READ /ERROR=SF1 /END_OF_FILE=SF1 f rec
$           IF i .LT. P3
$           THEN i = i + 1
$                GOTO SF4
$           ELSE GOTO SF1
$           ENDIF
$      ELSE IF F$TYPE(P4) .EQS. "STRING"
$           THEN IF P4 .NES. ""
$                THEN 'P4' == F$EDIT(rec,"COMPRESS")
$                     IF CVR$Verbose THEN SHOW SYMBOL /GLOBAL 'P4'
$                ENDIF
$           ENDIF
$      ENDIF
$ ENDIF
$SF1:
$ IF F$TRNLNM("f") .NES. "" THEN CLOSE f
$ EXIT 1
$ ENDSUBROUTINE  ! SearchFor
$ !
$PrintUntil:  SUBROUTINE
$ ! P1: 1st record to print
$ ! P2: Keep printing from file until this string is found
$ SET NOON
$PU0:
$ IF F$LOCATE(P2,P1) .GE. F$LENGTH(P1)
$ THEN wso P1
$ ELSE GOTO PU2  !stop when P2 string is found
$ ENDIF
$ READ /ERROR=PU1 /END_OF_FILE=PU2 f P1
$ GOTO PU0
$PU1:
$ wso "%''Fac'-E-FILE_ERROR, file continuation problem in PrintUntil"
$PU2:
$ EXIT 1
$ ENDSUBROUTINE  ! PrintUntil
$ !
$Ctrl_Y:
$ RETURN %X2C
