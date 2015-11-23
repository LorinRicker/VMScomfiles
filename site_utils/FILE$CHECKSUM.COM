$ ! FILE$CHECKSUM.COM -- calculates checksum on requested file     'F$VERIFY(0)'
$ !                   -- based on undocumented DCL command
$ !                      CHECKSUM [ /FILE | /IMAGE ]
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2013 by Lorin Ricker.   All rights reserved.
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1996-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  useage: @FILE$CHECKSUM [ /OUTPUT=outfile ] [ fname[,fname...] | @filelist ]
$ !                         [ MD5 (D) | CRC | XOR ]
$ !                         [ "sep" ]
$ !                         [ FILE (D) | IMAGE ]
$ !                         [ GLOBAL ]
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ IF F$TYPE(Util$Fac) .EQS. ""
$ THEN Util == "@site$utils:utility.com"
$      Util START CHK
$ ENDIF
$ wso  = "WRITE sys$output"
$ Here = F$ENVIRONMENT("DEFAULT")
$ DD   = F$ENVIRONMENT("PROCEDURE")
$ Fac  = F$PARSE(DD,,,"NAME","SYNTAX_ONLY")
$ DD   = F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ !
$L0:
$ IF P1 .EQS. "" -
    THEN READ /PROMPT="filename: " -
    /END_OF_FILE=Done sys$command P1
$ IF P1 .EQS. "" THEN GOTO L0
$ IF F$EXTRACT(0,1,P1) .EQS. "?" THEN GOTO Help
$ !
$ Prv = F$SETPRV("SYSPRV")
$ !
$ Util CMDPARSE "''P2'" Algo "MD5" "CRC|MD5|XOR"
$ Algorithm = CHK$Algo
$ wso "%''Fac'-I-ALGORITHM, ''CHK$Algo' - digest value displayed in hexidecimal"
$ !
$ IF P3 .EQS. ""
$ THEN Sep = ">>"  !default
$ ELSE Sep = P3
$ ENDIF
$ !
$ Util CMDPARSE "''P4'" Answer "FILE" "FILE |IMAGE"
$ Mode = CHK$Answer
$ !
$ setGlobal = ( F$EXTRACT(0,1,P5) .EQS. "G" )  !Global?
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
$ THEN CALL TheProcess "''Fl'" "''Algorithm'" "''setGlobal'" "''Mode'" "''Sep'" "''DBase'"
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
$ CALL TheProcess "''Fl'" "''Algorithm'" "''setGlobal'" "''Mode'" "''Sep'" "''DBase'"
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
$ ON CONTROL_Y THEN EXIT %X2C
$ FWidth = 50
$ FName = F$PARSE(P1,,,"NAME")
$ FType = F$PARSE(P1,,,"TYPE")
$ IF P2 .EQS. "" THEN P2 = "MD5"
$ A = "/ALGORITHM=''P2'"
$ ! If file is located in current default dir, then strip dev:[dir] for brevity:
$ RDD = F$PARSE(P1,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(P1,,,"DIRECTORY","SYNTAX_ONLY")
$ IF RDD .EQS. Here
$ THEN RName = P1 - Here
$ ELSE IF F$LENGTH(P1) .GT. FWidth
$      THEN P1L = F$LENGTH(P1)
$           X = P1L - FWidth + 3
$           RName = "..." + F$EXTRACT(X,P1L-X,P1)
$      ELSE RName = P1
$      ENDIF
$ ENDIF
$ IF ( FType .EQS. ".EXE" ) .AND. ( P4 .EQS. "IMAGE" )
$ THEN Q = "/IMAGE"
$ ELSE Q = "/FILE"
$ ENDIF
$ IF F$SEARCH(P1) .NES. ""
$ THEN CHECKSUM 'A' 'Q' 'P1'
$      CSum = CHECKSUM$CHECKSUM
$      !save the value (CHECKSUM's output is a string; convert to integer):
$      IF P3 THEN 'FName'_checksum == CSum
$      IF F$GETDVI("sys$output","TRM") .AND. -
          F$EXTRACT(0,2,F$GETDVI("sys$output","DEVICE_TYPE_NAME")) .EQS. "VT"
$      THEN Util HIGHLIGHT "''CSum'" BOLD    ! highlight only if output is a VT-terminal (ANSI)
$           CSum = CHK$string
$      ENDIF
$      Rec = F$FAO ("!#AS !AS !AS", FWidth, RName, P5, CSum )
$      wso Rec
$ ELSE wso "%''Fac'-E-FNF, file ""''P1'"" not found"
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! TheProcess
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE sys$input

  useage: @FILE$CHECKSUM [ fname[,fname...] | @filelist ]
                         [ MD5 (D) | CRC | XOR ]
                         [ separator ]
                         [ FILE (D) | IMAGE ]
                         [ GLOBAL ]

  where:

    P1 is a single filespec ([1mfname[0m), a file-list ([1mfname,fname,...[0m), or an
      indirection to a list of filespecs, one file per line ([1m@filelist[0m).
      Wildcards are supported for both [1mfname[0m and [1mfname,fname,...[0m forms,
      but not within indirect file lists.

    P2 is the checksum algorithm, one of MD5 (the default), CRC or XOR (see
      VMS's HELP CHECKSUM /ALGORITHM for more information).

    P3 is an optional separator-string, used to format the output checksum
      report line; the default is ">>".

    P4 is either FILE (the default) or IMAGE, which selects either the
      CHECKSUM /FILE or CHECKSUM /IMAGE qualifier.  /IMAGE is applied
      only to checksums of *.EXE (executable) files.

    P5 is the GLOBAL option, which creates a global symbol whose name
      is <filename>_CHECKSUM for each file which is checksummed.  This
      symbol contains the checksum (an integer value) for that file.
      The default is [4mnot[0m to create the global symbol(s).

$ GOTO Done
$ !
