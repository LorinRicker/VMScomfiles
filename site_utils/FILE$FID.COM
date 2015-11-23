$ ! FILE$FID.COM --                                                'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 2000-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  use: @FILE$FID [ fspec[,fspec...] | @filelist ] [ col_width ]
$ !
$MAIN:
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ wso = "WRITE sys$output"
$ DD  = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(DD,,,"NAME","SYNTAX_ONLY")
$ DD  = F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ Ver = F$TRNLNM("Tools$Debug")
$ !
$L1:
$ IF P1 .EQS. "" -
    THEN READ /PROMPT="filespec: " -
    /END_OF_FILE=Done sys$command P1
$ IF P1 .EQS. "" THEN GOTO L1
$ !
$ FID$FCount  == 0
$ FID$ThisDir == ""
$ IF F$GETDVI("sys$command","DEVBUFSIZ") .GT. 80
$ THEN FID$FNWidth == 64   !132-col
$ ELSE FID$FNWidth == 32   !80-col
$ ENDIF
$ !
$ IF F$EXTRACT(0,1,P1) .EQS. "?" THEN GOTO Help
$ !
$ IF P2 .NES. ""
$ THEN IF F$INTEGER(P2) .GT. FID$FNWidth
$      THEN FID$FNWidth == F$INTEGER(P2)
$      ENDIF
$ ENDIF
$ !
$ IF F$EXTRACT(0,1,P1) .EQS. "@" THEN GOTO IndirectSpec
$ !
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
$ THEN CALL TheProcess "''Fl'" "''F0'"
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
$ CALL TheProcess "''Fl'" "''F0'"
$!===============
$ GOTO IS0
$ !
$IS1:
$ CLOSE f
$ !
$Done:
$ SET NOON
$ IF FID$FCount .GT. 0
$ THEN wso ""
$      wso F$FAO("Total of !ZL file!%S", FID$FCount)
$ ENDIF
$ IF F$TYPE(FIL$XFile)   .NES. "" THEN DELETE /SYMBOL /GLOBAL FIL$XFile
$ IF F$TYPE(FID$FNWidth) .NES. "" THEN DELETE /SYMBOL /GLOBAL FID$FNWidth
$ IF F$TYPE(FID$FCount)  .NES. "" THEN DELETE /SYMBOL /GLOBAL FID$FCount
$ IF F$TYPE(FID$ThisDir) .NES. "" THEN DELETE /SYMBOL /GLOBAL FID$ThisDir
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
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO TPDone
$ !
$ IF P2 .NES. FID$ThisDir
$ THEN i = 0
$      Sep = "."
$      PFN = ""
$      Dir = F$PARSE(P2,,,"DIRECTORY","SYNTAX_ONLY") - "[" - "]"
$TPLoop:
$      Tmp = F$ELEMENT(i,Sep,Dir)
$      IF ( Tmp .EQS. Sep ) .OR. ( Tmp .EQS. "" ) .OR. ( i .GE. 20 )
$      THEN GOTO TPCont
$      ELSE i = i + 1
$           PFN = Tmp
$           GOTO TPLoop
$      ENDIF
$TPCont:
$      IF F$LOCATE(Sep,Dir) .LT. F$LENGTH(Dir)
$      THEN Tmp = Sep + PFN
$      ELSE Tmp = PFN
$      ENDIF
$      Par = P2 - Tmp          ! remove ".subdir" from P2 (parent directory)
$      i = F$LOCATE("[]",Par)  ! If this results in "empty dir []",
$      IF i .LT. F$LENGTH(Par) !   then add "000000" to form MFD
$      THEN Par = F$EXTRACT(0,i+1,Par) + "000000" + F$EXTRACT(i+1,F$LENGTH(Par)-i,Par)
$      ENDIF
$      PDir = Par + PFN + ".dir"
$      IF Ver
$      THEN SHOW SYMBOL Par
$           SHOW SYMBOL PFN
$           SHOW SYMBOL PDir
$      ENDIF
$      wso ""                   ! write a header
$      wso "Directory ''P2' - ", F$FILE_ATTRIBUTE(PDir,"FID")
$      wso ""
$      FID$ThisDir == P2
$ ENDIF
$ !
$ Tp = F$PARSE(P1,,,"TYPE","SYNTAX_ONLY")
$ FN = F$PARSE(P1,,,"NAME","SYNTAX_ONLY") -
     + Tp + F$PARSE(P1,,,"VERSION","SYNTAX_ONLY")
$ !
$ ! If file's locked by another user/process/program, squelch the noise:
$ DEFINE /PROCESS /NOLOG sys$output nl:
$ DEFINE /PROCESS /NOLOG sys$error  nl:
$ FID = F$FILE_ATTRIBUTE(P1,"FID")
$ Stat = $STATUS
$ DEASSIGN /PROCESS sys$error
$ DEASSIGN /PROCESS sys$output
$ !
$ IF Stat .EQ. %X00000800    !%SYSTEM-W-ACCONFLICT, file access conflict
$ THEN FID  = "<file access conflict>"
$      isDir = ""
$      GOTO TP0  !don't check other attributes, just report lock-conflict...
$ ENDIF
$ !
$ IF Tp .EQS. ".DIR"
$ THEN IF F$FILE_ATTRIBUTES(P1,"DIRECTORY")
$      THEN isDir = "VMS directory"
$      ELSE isDir = "not directory"
$      ENDIF
$ ELSE isDir = ""
$ ENDIF
$ !
$TP0:
$ WFID = 16 - F$LENGTH(FID)
$ IF F$LENGTH(FN) .LT. FID$FNWidth
$ THEN Line = F$FAO("!#AS!AS!#* !AS",      FID$FNWidth, FN, FID, WFID, isDir)
$ ELSE Line = F$FAO("!AS!/!#* !AS!#* !AS", FN, FID$FNWidth, FID, WFID, isDir)
$ ENDIF
$ !
$ wso F$EDIT(Line,"TRIM")
$ FID$FCount == FID$FCount + 1
$ !
$TPDone:
$ EXIT 1
$ ENDSUBROUTINE  ! TheProcess
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  FILE$FID is a special-purpose directory command file which lists File and
  Directory IDentification (FID and DID) information for one or more files.

  use:  $ [1m@FILE$FID[0m [ [1mfspec[0m[[1m,fspec[0m...] | [1m@filelist[0m ] [ [1mcol_width[0m ]

  where:
  
   [1mP1[0m is a single filespec ([1mfspec[0m), a file-list ([1mfspec,fspec,...[0m), or an
      indirection to a list of filespecs, one file per line ([1m@filelist[0m).
      Wildcards are supported for both [1mfspec[0m and [1mfspec,fspec,...[0m forms,
      but not within indirect file lists.

   [1mP2[0m is the (optional) display width of the file specification column
      (the first column) in the output display.  This column width is
      automatically managed for both 80-column and 132-column terminal
      displays, but may be set to specific values for special needs.

$ !
$ GOTO Done
$ !
