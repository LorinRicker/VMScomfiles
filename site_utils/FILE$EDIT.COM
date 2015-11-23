$ ! FILE$EDIT.COM -- Shell for TPU plug-in scripts
$ !                                                                'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1997-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ! v1.11 - Tweak to CheckFile - RAT:"" (none) is also a     07/08/2003
$ !         text-file to normalize.
$ ! v1.10 - Added new LOCKWORKS plug-in to convert source    06/12/2002
$ !         file proprietary/ownership/intellectual property
$ !         from Evans & Ricker, Inc. to LockWorks LLC.
$ !  v1.9 - Added a help-text paragraph for BACKGROUND.      07/24/2001
$ !  v1.8 - Support new BACKGROUND plug-in for *.DEF files.  05/04/2001
$ !  v1.7 - Support new PCKEYS plug-in for RAPT *.DEF files. 08/30/2000
$ !  v1.6 - Support new BINARY (SEQ,FIXED 512) conversion.   07/31/2000
$ !         Also renamed NORMALTEXT to just plain TEXT.
$ !  v1.5 - Support new STRIPCRLF plug-in.                   07/25/2000
$ !  v1.4 - Support new FINDREPLACE plug-in.                   12/04/98
$ !         Also added new CALL_USER callout routines for F$TRNLNM,
$ !         P$SETSYMBOL and F$GETSYMBOL for all plugins (replacing old use
$ !         of FILE_PARSE with new F$TranslateLNM shell).
$ !         Added optional FILE$POSTPROCESS command file invocation.
$ !         Support for new NULL (non)plug-in, which bypasses straight
$ !         to optional FILE$POSTPROCESS.
$ !         Also added cross-check of logical TPU$CALLUSER = "KED$SHARE".
$ !  v1.3 - Support any text-file type (Stream_LF, etc.), but  07/22/98
$ !         convert these types to "normal VMS text files" as a byproduct.
$ !         Also include a direct conversion, NORMALTEXT.  Also add DETAB.
$ !  v1.2 - Support general wildcards, but ignore all files    01/08/98
$ !         which are not "normal VMS text files", i.e., skip all binary,
$ !         library, and any other non-text file formats.
$ !  v1.1 - Echo info-msg for files processed, too.            02/14/97
$ !         Remove support for PAGINATE (not a good idea).
$ !  v1.0 - Base release.                                      01/24/97
$ !         Supporting COPYRIGHT, TRIMTRAIL, NUMBERLINES & PAGINATE.
$ !
$ !  use: @FILE$Edit TPU_PlugIn_Spec [ fname[,fname...] | @filelist ]
$ !
$ !  where P1 is the name of a TPU PlugIn component
$ !           (filespec FILE$EDIT_<plugin>.TPU)
$ !        P2 is either: a) a comma-separated list of filenames (wildcards
$ !           are supported), or b) an indirect list of filenames
$ !        P3..P8 are available for PlugIn-specific use
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ IF F$PARSE(F$TRNLNM("TPU$CALLUSER"),"TPU$CALLUSER",,"NAME","SYNTAX_ONLY") -
     .NES. "KED$SHARE"
$ THEN WRITE sys$output "%FILE$EDIT-F-NO_TPU_CALLUSER, incorrect shareable image"
$      WRITE sys$output "      use of FILE$EDIT tools [1mrequires[0m"
$      WRITE sys$output "      E&R's KED$SHARE shareable image"
$      EXIT
$ ENDIF
$ !
$ IF F$TYPE(Util$Fac) .EQS. ""
$ THEN Util == "@site$utils:utility.com"
$      Util START FED
$ ENDIF
$ wso = "WRITE sys$output"
$ CurF0 = ""
$ !
$ DD  = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(DD,,,"NAME","SYNTAX_ONLY")
$ DD  = F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ !
$ DEFINE /PROCESS /NOLOG FED$Path 'DD',site$utils
$ IF F$EXTRACT(0,1,P1) .EQS. "?" THEN GOTO Help
$ !
$ ! Current list of supported plug-ins:
$ FEDPlugIns =  "BACKGROUND " -     ! 11-char plug-in names ...
             + "|BINARY/C   " -     ! ... "/C" means "Conversion only" and
             + "|COPYRIGHT  " -     !     has no corresponding TPU plug-in
             + "|DETAB      " -
             + "|FINDREPLACE" -
             + "|LOCKWORKS  " -
             + "|NULL/C     " -
             + "|NUMBERLINES" -
             + "|PCKEYS     " -
             + "|STRIPCRLF  " -
             + "|TEXT/C     " -
             + "|TRIMTRAIL  "
$ Util CMDPARSE "''P1'" PlugIn "COPYRIGHT" "''FEDPlugIns'"
$ !
$ Switch     = F$ELEMENT(1,"/",FED$PlugIn)
$ FED$PlugIn = F$ELEMENT(0,"/",FED$PlugIn)
$ IF Switch .NES. "C"      ! It's a Plug-in, not a Conversion...
$ THEN ! Check Plug-in's existence, shout-&-die if not found...
$      FED$PlugInFS == F$SEARCH("FED$Path:file$edit_''FED$PlugIn'.tpu")
$      IF FED$PlugInFS .EQS. ""
$      THEN wso "%FILE$EDIT-E-CNF, plug-in component FED$PATH:FILE$EDIT_''FED$PlugIn'.TPU not found;"
$           wso "                  search path: "            -
                ,F$TRNLNM("FED$Path","lnm$process",0), "," -
                ,F$TRNLNM("FED$Path","lnm$process",1)
$           GOTO Done
$      ENDIF
$ ENDIF
$ BinaryMode = ( FED$PlugIn .EQS. "BINARY" )
$ !
$L0:
$ IF P2 .EQS. "" -
    THEN READ /PROMPT="filename: " -
    /END_OF_FILE=Done sys$command P2
$ IF P2 .EQS. "" THEN GOTO L0
$ !
$ FED$Verbose == F$TRNLNM("TOOLS$Debug")     !generic Tools debug flag
$ FED$FCount  == 0
$ FED$MCount  == 0
$ !
$ IF F$EXTRACT(0,1,P2) .EQS. "@" THEN GOTO IndirectSpec
$ FLen = F$LENGTH(P2)
$ SingleFS =       ( F$LOCATE("*",P2) .GE. FLen ) -  !a single filespec,
             .AND. ( F$LOCATE("%",P2) .GE. FLen ) -  ! no wildcards or
             .AND. ( F$LOCATE(",",P2) .GE. FLen )    ! comma-list?
$DirectSpec:
$ i = 0
$ F0 = "sys$disk:[]"
$DS0:
$ Fl = F$ELEMENT(i,",",P2)
$ IF Fl .EQS. "," THEN GOTO Done               !more files?
$ FS   = F$PARSE(Fl,F0,"*.*",,"SYNTAX_ONLY")   !expand w/sticky dev:[dir]
$ FLen = F$LENGTH(FS)
$ Wild = ( F$LOCATE("*",FS) .LT. FLen ) .OR. ( F$LOCATE("%",FS) .LT. FLen )
$ GotOne = 0
$DS1:
$ Fl = F$SEARCH(FS)
$ IF Fl .NES. ""
$ THEN F0 = F$PARSE(Fl,F0,,"DEVICE","SYNTAX_ONLY") -  !save sticky dev:[dir]
          + F$PARSE(Fl,F0,,"DIRECTORY","SYNTAX_ONLY")
$      IF .NOT. BinaryMode
$      THEN CALL CheckFile "''Fl'"
$           IF .NOT. FED$TextFile
$           THEN IF SingleFS THEN wso "%FILE$EDIT-E-NOT_TEXT, ''FS' is not a text file"
$                GOTO DS2         !skip all non-text files
$           ENDIF
$      ENDIF
$      IF F0 .NES. CurF0
$      THEN CurF0 = F0
$           wso "%FILE$EDIT-I-DIRECTORY, [1m''CurF0'[0m"
$      ENDIF
$     !===============
$      CALL TheProcess "''FED$PlugIn'" "''Fl'" "''P3'" "''P4'" "''P5'" "''P6'" "''P7'" "''P8'"
$     !===============
$DS2:
$      IF Wild
$      THEN GotOne = 1
$           GOTO DS1       !next wildcard
$      ELSE i = i + 1
$           GOTO DS0       !next comma-element
$      ENDIF
$ ELSE IF .NOT. GotOne THEN wso "%FILE$EDIT-E-FNF, cannot find ''FS'"
$      i = i + 1
$      GOTO DS0
$ ENDIF
$ !
$MakeIndirect:
$ @site$utils:FILE$PrepList "''Files'" "" "" "" FIL$XFile /CONFIRM
$ IF F$TYPE(FIL$XFile) .EQS. "" THEN GOTO Done  !user-aborted or error
$ P2 = "@" + FIL$XFile                          !try again...
$ !
$IndirectSpec:
$ Files = P2 - "@"
$ Files = F$PARSE(Files,".lis")
$ OPEN /READ /ERROR=FNF f 'Files'
$IS0:
$ READ /END_OF_FILE=IS1 f Fl
$ Fl = F$EDIT(Fl,"COLLAPSE,UPCASE,UNCOMMENT")
$ IF Fl .EQS. "" THEN GOTO IS0                   !skip blank lines & comments
$ IF .NOT. BinaryMode
$ THEN CALL CheckFile "''Fl'"
$      IF .NOT. FED$TextFile THEN GOTO IS0            !skip all non-text files
$ ENDIF
$ F0 = F$PARSE(Fl,F0,,"DEVICE","SYNTAX_ONLY") + F$PARSE(Fl,F0,,"DIRECTORY","SYNTAX_ONLY")
$ IF F0 .NES. CurF0
$ THEN CurF0 = F0
$      wso "%FILE$EDIT-I-DIRECTORY, [1m''CurF0'[0m"
$ ENDIF
$!===============
$ CALL TheProcess "''FED$PlugIn'" "''Fl'" "''P3'" "''P4'" "''P5'" "''P6'" "''P7'" "''P8'"
$!===============
$ GOTO IS0
$ !
$IS1:
$ CLOSE f
$ !
$Done:
$ IF F$TYPE(FED$FCount) .EQS. "INTEGER"
$ THEN IF FED$FCount .GE. 0
$      THEN IF FED$MCount .GT. 0
$           THEN wso ""
$                wso F$FAO( "%FILE$EDIT-S-COUNT, modified !SL, processed !SL file!%S", FED$MCount, FED$FCount )
$                wso ""
$           ELSE wso ""
$                wso F$FAO( "%FILE$EDIT-S-COUNT, processed !SL file!%S", FED$FCount )
$                wso ""
$           ENDIF
$      ENDIF
$ ENDIF
$ IF F$TYPE(FIL$XFile)    .NES. "" THEN DELETE /SYMBOL /GLOBAL FIL$XFile
$ IF F$TRNLNM("FED$Path","lnm$process") .NES. "" THEN DEASSIGN /PROCESS FED$Path
$ Util EXIT
$ EXIT
$ !
$FNF:
$ wso "%FILE$EDIT-E-FNF, cannot find @-list ''Files'"
$ wso ""
$ wso "  Creating indirect @-list file ''Files'"
$ wso ""
$ GOTO MakeIndirect
$ !
$ !
$ !              ==========
$CheckFile:  SUBROUTINE
$ ! P1: filespec
$ Org           = F$FILE_ATTRIBUTES(P1,"ORG")
$ Rat           = F$FILE_ATTRIBUTES(P1,"RAT")
$ FED$Rfm      == F$FILE_ATTRIBUTES(P1,"RFM")
$ FED$TextFile ==      ( Org .EQS. "SEQ" )             -  !only process VMS
                 .AND. (( Rat .EQS. "CR" )             -  ! files which are
                          .OR. ( Rat .EQS. "" ))       -  ! ORG:SEQ,
                 .AND. (( FED$Rfm .EQS. "VAR" )        -  ! RAT:{CR or none}
                          .OR. ( FED$Rfm .EQS. "STM" ) -  ! and RFM:{stream,
                          .OR. ( FED$Rfm .EQS. "STMLF" )) !  streamLF or VAR}
$ IF FED$TextFile
$ THEN FED$Normal ==       ( FED$Rfm .EQS. "VAR" ) -
                     .AND. ( Org .EQS. "SEQ" ) -
                     .AND. ( Rat .EQS. "CR" )
$ ELSE FED$Normal == "FALSE"
$ ENDIF
$!! $ IF FED$Verbose
$!! $ THEN SHOW SYMBOL FED$Rfm
$!! $      SHOW SYMBOL FED$TextFile
$!! $      SHOW SYMBOL FED$Normal
$!! $ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! CheckFile
$ !
$ !
$ !          ==========
$TheProcess: SUBROUTINE
$ !     P1: PlugIn name
$ !     P2: File to edit
$ ! P3..P8: Plug-in specific
$ !
$ ON CONTROL_Y THEN EXIT %X2C
$ OutF = ""
$ P2 = P2 - F$PARSE(P2,,,"VERSION","SYNTAX_ONLY")         !strip ";N"
$ IF F$SEARCH(P2) .NES. ""
$ THEN FN = P2 - F$PARSE(P2,,,"DEVICE","SYNTAX_ONLY") - F$PARSE(P2,,,"DIRECTORY","SYNTAX_ONLY")
$      GOTO 'P1'
$ !
$BACKGROUND:
$      IF F$PARSE(P2,,,"TYPE","SYNTAX_ONLY") .NES. ".DEF"
$      THEN wso "%FILE$EDIT-W-NOT_RAPT_DEF, ''FN' is not a RAPT .DEF file"
$           READ sys$command Answer /END_OF_FILE=TPDone -
              /PROMPT="                           Check & process this file anyway (y/[1mN[0m)? "
$           Answer = F$PARSE(Answer,"No",,"NAME","SYNTAX_ONLY")
$           IF .NOT. Answer THEN EXIT 1  !...just skip this file...
$      ENDIF
$      DEFINE /NOLOG /USER_MODE sys$error  nl:  !suppress line-output
$      DEFINE /NOLOG /USER_MODE sys$output nl:
$ !    Looking for "SCREEN ... /SIZ"
$      SEARCH 'P2' "SCREEN","/SIZ" /MATCH=AND /NOWARNINGS !suppress messages
$      IF $STATUS .EQ. %X08D78053     !"%SEARCH-I-NOMATCHES, no strings matched"
$      THEN wso "%FILE$EDIT-W-[1mNOT_PROCESSED[0m, ''FN' does not have a SCREEN statement"
$           EXIT 1
$      ENDIF
$      GOTO TPU_PlugIn
$ !
$BINARY:
$      wso "%FILE$EDIT-I-CONVERT, file ''FN' is being converted to FIXED-512"
$      SET FILE /ATTRIBUTES=(ORG:SEQ,RAT:NONE,RFM:FIX,LRL=512) 'P2'
$      FED$FCount == FED$FCount + 1     !count each file...
$      GOTO TPDone
$ !
$COPYRIGHT:      !Check to see if copyright notice exists before editing:
$      FED$Year == F$CVTIME("","ABSOLUTE","YEAR")
$      Copyright = " © "
$      DEFINE /NOLOG /USER_MODE sys$error  nl:  !suppress line-output
$      DEFINE /NOLOG /USER_MODE sys$output nl:
$      SEARCH 'P2' "''Copyright'" /NOWARNINGS   !suppress messages
$      IF $STATUS .EQ. %X08D78053     !"%SEARCH-I-NOMATCHES, no strings matched"
$      THEN wso "%FILE$EDIT-W-[1mNO_©[0m, file ''FN' has no [1m©[0m notice"
$           EXIT 1
$      ENDIF
$      DEFINE /NOLOG /USER_MODE sys$error  nl:  !suppress line-output
$      DEFINE /NOLOG /USER_MODE sys$output nl:
$      SEARCH 'P2' "''Copyright'","''FED$Year'" /MATCH=AND /NOWARNINGS
$      IF $STATUS .EQ. 1              !found a current copyright
$      THEN wso "%FILE$EDIT-I-CURRENT_©, file ''FN' has a current [1m©[0m notice"
$           EXIT 1
$      ENDIF
$      GOTO TPU_PlugIn
$ !
$DETAB:
$STRIPCRLF:
$      GOTO TPU_PlugIn
$ !
$FINDREPLACE:
$ ! P3: Target string(s) to find and replace
$ ! P4: Replacement text
$ ! P5: (optional) NOEXACT | EXACT | WORDNOEXACT | WORDEXACT (D)
$ !     (EXACT|NOEXACT controls case-matching,
$ !      WORD prefix forces match of entire word, no internal substrings)
$FR3:
$      IF P3 .EQS. ""
$      THEN READ sys$command P3 /END_OF_FILE=TPDone /PROMPT="Search string: "
$           IF P3 .EQS. "" THEN GOTO FR3
$      ENDIF
$FR4:
$      IF P4 .EQS. ""
$      THEN READ sys$command P4 /END_OF_FILE=TPDone /PROMPT="Replacement text: "
$           IF P4 .EQS. "" THEN GOTO FR4
$      ENDIF
$      FED$TarString == P3
$      FED$RplString == P4
$ !
$      Util CMDPARSE "''P5'" Answer "WORDEXACT" "NOEXACT    |EXACT      |WORDNOEXACT|WORDEXACT  "
$      IF F$LOCATE("WORD",FED$Answer) .EQ. 0    !"WORD" prefix?
$      THEN FED$Delimited == "TRUE"
$      ELSE FED$Delimited == "FALSE"
$      ENDIF
$      FED$Exact == FED$Answer - "WORD"
$      GOTO TPU_PlugIn
$ !
$LOCKWORKS:
$      FED$Year == F$CVTIME("","ABSOLUTE","YEAR")
$      IF F$PARSE(P2,,,"TYPE","SYNTAX_ONLY") .EQS. ".DEF"
$      THEN FED$isDEF == "YES"
$      ELSE FED$isDEF == "NO"
$      ENDIF
$      DEFINE /NOLOG /USER_MODE sys$error  nl:  !suppress line-output
$      DEFINE /NOLOG /USER_MODE sys$output nl:
$ !    Looking for "LockWorks LLC"... if found, already owned by LockWorks LLC
$      SEARCH 'P2' "LockWorks LLC" /NOWARNINGS  !suppress messages
$      IF $STATUS .EQ. 1              !found "LockWorks LLC"
$      THEN wso "%FILE$EDIT-W-CORRECT_OWNER, ''FN' already owned by LockWorks LLC"
$           EXIT 1
$      ENDIF
$      GOTO TPU_PlugIn
$ !
$NULL:
$      FED$Modified == "FALSE"
$      FED$FCount == FED$FCount + 1
$      GOTO PostProcess                 !skip TPU-PlugIn, just post-process
$ !
$NUMBERLINES:
$      FS   = P2 - F$PARSE(P2,,,"TYPE","SYNTAX_ONLY")
$      OutF = "/OUTPUT=" + FS + ".LIS"
$      GOTO TPU_PlugIn
$ !
$PCKEYS:
$      IF F$PARSE(P2,,,"TYPE","SYNTAX_ONLY") .NES. ".DEF"
$      THEN wso "%FILE$EDIT-W-NOT_RAPT_DEF, ''FN' is not a RAPT .DEF file"
$           READ sys$command Answer /END_OF_FILE=TPDone -
              /PROMPT="                           Check & process this file anyway (y/[1mN[0m)? "
$           Answer = F$PARSE(Answer,"No",,"NAME","SYNTAX_ONLY")
$           IF .NOT. Answer THEN EXIT 1  !...just skip this file...
$      ENDIF
$      DEFINE /NOLOG /USER_MODE sys$error  nl:  !suppress line-output
$      DEFINE /NOLOG /USER_MODE sys$output nl:
$ !    Looking for "OPTIONS /KEYBOARD=PC"... if found, then skip this file
$      SEARCH 'P2' "OPTIONS","/KEY","=PC" /MATCH=AND /NOWARNINGS !suppress messages
$      IF $STATUS .EQ. 1    !found evidence that this file's already been fixed
$      THEN wso "%FILE$EDIT-I-PCKEYS_OK, file ''FN' has been previously converted"
$           EXIT 1
$      ENDIF
$ !    To avoid erroneously editing Validation-Lists (which won't have OPTIONS)
$ !     also check for a DATABASE and/or SCREEN commands:
$      DEFINE /NOLOG /USER_MODE sys$error  nl:  !suppress line-output
$      DEFINE /NOLOG /USER_MODE sys$output nl:
$      SEARCH 'P2' "DATABASE ","SCREEN " /MATCH=OR /NOWARNINGS !suppress messages
$      IF $STATUS .EQ. %X08D78053     !"%SEARCH-I-NOMATCHES, no strings matched"
$      THEN wso "%FILE$EDIT-W-[1mNOT_PROCESSED[0m, ''FN' is probably a validation-list"
$           wso "                            (no DATABASE or SCREEN statements were found)"
$           EXIT 1
$      ENDIF
$      GOTO TPU_PlugIn
$ !
$TEXT:     !Nothing else to do...
$      IF FED$TextFile .AND. ( .NOT. FED$Normal )  !Stream, Stream_LF, etc.?
$      THEN wso "%FILE$EDIT-I-CONVERT, ''FED$Rfm' file ''FN' is being normalized"
$           CALL NormalizeFile 'P2'
$           FED$FCount == FED$FCount + 1     !count each file...
$      ENDIF
$      GOTO TPDone
$ !
$TRIMTRAIL:
$      GOTO TPU_PlugIn
$ !
$ !
$ ! ============================================================================
$TPU_PlugIn:
$      IF FED$TextFile .AND. ( .NOT. FED$Normal )  !Stream, Stream_LF, etc.?
$      THEN wso "%FILE$EDIT-I-CONVERT, ''FED$Rfm' file ''FN' is being normalized"
$           CALL NormalizeFile 'P2'
$      ENDIF
$      wso "%FILE$EDIT-I-FIXING, file ''FN' is being processed"
$ !
$      IF .NOT. FED$Verbose     !If verbose, then suppress TPU's natural output
$      THEN DEFINE /NOLOG /USER_MODE sys$error  nl:
$           DEFINE /NOLOG /USER_MODE sys$output nl:
$      ENDIF
$      ON ERROR THEN GOTO TPDone
$      EDIT /TPU /NODISPLAY /NOSECTION /NOJOURNAL -
            /COMMAND='FED$PlugInFS' 'P2' 'OutF'
$      FED$FCount == FED$FCount + 1                       !count each file...
$      IF FED$Modified THEN FED$MCount == FED$MCount + 1  ! and each modified...
$ ! ============================================================================
$PostProcess:
$ !    Conditionally invoke a user's post-process command file, designated
$ !    by logical name FILE$POSTPROCESS or found in current directory.
$ !    Arguments for FILE$POSTPROCESS:
$ !      P1: the processed file
$ !      P2: the name of the PlugIn which did the transform
$ !      P3: whether this file was actually modified by the PlugIn (TRUE/FALSE)
$ !      P4: the count (number) for this file
$      PostProcess = F$PARSE("FILE$PostProcess","sys$disk:[].com",,,"SYNTAX_ONLY")
$      PostProcess = F$SEARCH(PostProcess)
$      IF PostProcess .NES. ""
$      THEN @'PostProcess' "''P2'" "''P1'" "''FED$Modified'" "''FED$FCount'"
$      ENDIF
$ ! ============================================================================
$ !
$ ELSE wso "%FILE$EDIT-E-FNF, file ""''P2'"" not found"
$ ENDIF
$TPDone:
$ EXIT 1
$ ENDSUBROUTINE  ! TheProcess
$ !
$NormalizeFile:  SUBROUTINE
$ ! P1: filename to convert
$ !
$ SET NOON
$ CONVERT /FDL=sys$input 'P1' 'P1'
FILE
	BEST_TRY_CONTIGUOUS     yes
	EXTENSION               0
	FILE_MONITORING         no
	GLOBAL_BUFFER_COUNT     0
	ORGANIZATION            sequential

RECORD
	BLOCK_SPAN              yes
	CARRIAGE_CONTROL        carriage_return
	FORMAT                  variable
	SIZE                    0
$ !
$ EXIT 1
$ ENDSUBROUTINE  ! NormalizeFile
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  FILE$EDIT is a file-processor which supports the use of several TPU "plug-
  ins" or other basic file conversions.  FILE$EDIT can do such repetitive
  tasks, on one or many files, e.g.:  [1ma[0m) fixing/updating copyright notices;
  [1mb[0m) de-tabbing (replacing <tab> characters with spaces); [1mc[0m) trimming trailing
  blanks from lines; [1md[0m) stripping embedded <cr>/<lf> characters; [1me[0m) converting
  "unusual" file formats to "normal" VMS text or binary forms; [1mf[0m) user-written
  file processes (via "post-processing").

  use: @FILE$EDIT PlugIn [ fname[,fname...] | @filelist ] [ options... ]

  where:

    P1 is the name of a [1mTPU plug-in script[0m, a complete text editing command file
       written in the TPU programming language.  The development of a TPU-based
       text editing program is outside of the scope of this brief help.

       These PlugIns (TPU scripts) and conversions are currently provided:

       [1mBACKGROUND[0m  -- Updates RAPT resource source-files (*.DEF) from TUI-only
                      screen backgrounds to full GUI support by generating
                      BACKGROUND statements for LTclient.  Parses and cross-
                      checks existing TUI-style background labels (found in
                      the SCREEN/EOSCREEN statement pairs) and generates
                      corresponding BACKGROUND /GUI_ONLY statements as needed
                      for each label.  Each new BACKGROUND /GUI statement is
                      positioned exactly as found in the TUI SCREEN background.
                      If a BACKGROUND statement already exists for a particular
                      TUI label, it is retained (not replaced and not updated).

       [1mBINARY[0m      -- Converts a file, such as a stream-LF file, into strict
                      VMS binary file format (sequential, fixed 512-byte
                      records, no record format).  Useful especially for
                      files which have been FTP'd through a PC-environment
                      or connection, thus being accidentally converted to
                      "stream", "stream-CR" or "stream-LF" record format
                      as a result.

       [1mCOPYRIGHT[0m   -- Edits and updates source-file internal copyright notices,
                      changing the latest year-date into the current year ---
                      "Copyright © 1996" becomes "Copyright © 1996-1998" and
                      "Copyright © 1994-1996" becomes "Copyright © 1994-1998".

       [1mDETAB[0m       -- Replaces <tab> characters with correct number
                      of spaces (based on tab-every-eight-characters).

       [1mFINDREPLACE[0m -- Finds all instances of a TargetString and replaces
                      each with a ReplacementString.

                      use:
                      @FILE$EDIT FINDREPLACE filespec[,...] -
                                  "TargetString" "ReplacementString" -
                                  [ OPTION ]

                      where OPTION is:
                        NOEXACT: Case-blind search for TargetString (default).
                        EXACT:   Case-exact-match search for TargetString.
                        WORDNOEXACT or
                        WORDEXACT: As above, but the WORD prefix forces the
                                   search to match entire words (delimited
                                   by spaces and punctuation), not just sub-
                                   strings within words.
                        WORDEXACT is the default OPTION (least aggressive).

       [1mLOCKWORKS[0m   -- Converts "Evans & Ricker, Inc."-style intellectual
                      property and copyright notices to "LockWorks LLC"-style.

       [1mNULL[0m        -- The "empty PlugIn", does no TPU processing, but invokes
                      the FILE$POSTPROCESS command file (if defined; see below).

       [1mNUMBERLINES[0m -- Numbers the lines in a text file.

       [1mPCKEYS[0m      -- Converts RAPT resource source-files (*.DEF) from "old-
                      style" VT-keymap names to "new-style" PC keynames.
                      Looks for the string "OPTIONS /KEYBOARD=PC" in the
                      source file:  if found, assumes this file has already
                      been converted and skips it;  if [1mnot[0m found, then auto-
                      edits the file as follows:

                   1) Inserts the line "OPTIONS /KEYBOARD=PC" immediately
                      before any RAPT line starting with the keyword
                      "DATABASE".
                   2) Replaces VT keynames with PC keynames:

                      "F8"  "F9" "F10" "F11" become "F5" "F6"  "F7"  "F8"
                     "F17" "F18" "F19" "F20" become "F9" "F10" "F11" "F12"
                "PREVIOUS", "PREV" and "PRE" become "PGUP"
                            "NEXT" and "NEX" become "PGDN"
                                      "FIND" becomes "HOME"   (KEYSTROKE only)
                                    "SELECT" becomes "END"    (KEYSTROKE only)
                                    "REMOVE" becomes "DELETE" (KEYSTROKE only)
                                    "INSERT" remains "INSERT" (KEYSTROKE only)

                      If the files you have specified are not RAPT's *.DEF
                      file-type (resource files), a warning message is
                      displayed and you are asked to confirm that file's
                      processing:  Enter "Yes" to auto-edit the file, or
                      "No" (the default) to skip that file.

                [4mHint[0m: Turn [1m"$ TOOLS ON"[0m (set the logical name [1mTOOLS$DEBUG[0m to
                      "[1mYES[0m") to enable additional syntax checks and warning
                      messages for certain "developer alert" RAPT constructs,
                      such as obsolete "KEYSTROKE DO" and "BUCKET" statements,
                      and /(IM,EX)PORT=BUCKET syntax.

       [1mSTRIPCRLF[0m   -- Trims <CR> and <LF> characters from each line of the
                      source file.

       [1mTEXT[0m        -- Converts a text file, such as a stream-LF file, into
                      "normal" VMS text format (sequential, variable-length,
                      CR-carriage control).

       [1mTRIMTRAIL[0m   -- Trims trailing blanks from each line of the source file.


    P2 is a single filespec ([1mfname[0m), a file-list ([1mfname,fname,...[0m), or an
      indirection to a list of filespecs, one file per line ([1m@filelist[0m).
      Wildcards are supported for both [1mfname[0m and [1mfname,fname,...[0m forms,
      but not within indirect file lists.


  [4mPOST-PROCESSING and LOGICAL NAMES[0m

  If a command file named [1mFILE$POSTPROCESS.COM[0m exists in the current (default)
  directory, or if the logical name [1mFILE$POSTPROCESS[0m is defined to point at
  a suitable command file, then this command file is executed after FILE$EDIT
  invokes the PlugIn for each file processed.  This post-processing command
  file is invoked with the following parameters:

    P1: the processed file (full file specification [4mwithout[0m the version ";N")
    P2: the name of the PlugIn which did the transform
    P3: whether this file was actually modified by the PlugIn (TRUE/FALSE)
    P4: the count (number) for this file

  It is up to you to create and debug a FILE$POSTPROCESS.COM command file to
  suit your specific needs.  Note that you can use the NULL plug-in to drive
  your own processing (using FILE$EDIT's wildcard/file looping) [4mwithout[0m using
  one of the other provided plug-ins.

  FILE$EDIT's TPU PlugIn scripts are equipped to produce diagnostic/trace
  and/or enhanced output if the logical name [1mTOOLS$Debug[0m has the value "Yes",
  "True" or "1".

$ GOTO Done
