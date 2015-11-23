$ ! FILE$XFER.COM -- VMS/Pathworks/DOS saveset transport           'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1994-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ! use: @FILE$XFER Step [saveset] [file[,...] | @Xfer_file] [VERIFY]
$ !
$ !  P1: Step [ PREPARE | SAVE | CONVERT | HELP | ? ]
$ !  P2: Saveset name
$ !  P3: Input file-list, comma-separated,
$ !      or @Xfer_file (indirect file-list)
$ !  P4: Verify [ YES | VERIFY | TRUE | 1 ]
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Ver = P4 .OR. (F$EXTRACT(0,1,P4) .EQS. "V") .OR. F$TRNLNM("TOOLS$Debug")
$ wso = "WRITE sys$output"
$ Me  = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(Me,,,"NAME","SYNTAX_ONLY")
$ !
$ DBSize = "8192"
$ Binaries = "*.OBJ,*.EXE,*.%LB,*.PEN,*.XFER,*.LOG,*.*NEW*,*.DIR"
$ Quals = ""
$ Exclu = ""
$ FIL$BQual == "/INTERCHANGE /NOCRC /BLOCK=''DBSize' /IGNORE=(INTERLOCK)"
$ !
$ IF P1 .EQS. "?" THEN GOTO Help
$ !
$ IF P2 .NES. ""
$ THEN FIL$XFile == P2
$ ELSE FIL$XFile == "X.XFER"
$ ENDIF
$ IF P3 .NES. ""
$ THEN Files = P3
$      Ln = F$LENGTH(P3)
$      ! Check for either a /SINCE or /BEFORE qualifier *without*
$      !   a /MODIFIED qualifier in the input file-spec list:
$      FSince    = (F$LOCATE("/SIN",P3) .LT. Ln)
$      FBefore   = (F$LOCATE("/BEF",P3) .LT. Ln)
$      FModified = (F$LOCATE("/MOD",P3) .LT. Ln)
$      IF ( FSince .OR. FBefore ) .AND. .NOT. FModified -
       THEN Files = Files + "/CREATED"
$      ! Force /SINCE/CREATED rather than /MODIFIED (BACKUP's default)
$ ELSE Files = ""
$ ENDIF
$ !
$ CALL Parse_Cmd "''P1'"
$ GOTO 'FIL$Cmd'
$ !
$Prepare:
$ DX = FIL$XFile
$Prep0:
$ DF = "*.*;0"
$ DQ = ""        ! "/SINCE=TODAY"
$ !
$ @site$utils:FILE$PrepList "''DX'" "''DF'" "''DQ'" "''Binaries'" FIL$XFile /CONFIRM
$ IF F$TYPE(FIL$XFile) .EQS. "" THEN GOTO Done  !user-aborted or error
$ Exclu = ""  !reset again
$ !
$ READ sys$command answer /END_OF_FILE=Done /PROMPT="Make the transfer saveset (SAVE) <Y>: "
$ answer = F$PARSE(answer,"Y",,"NAME","SYNTAX_ONLY")
$ IF answer
$ THEN Files = "@" + FIL$XFile
$      GOTO Save0
$ ELSE EXIT
$ ENDIF
$ !
$Save:
$ IF Files .EQS. "" -
  THEN READ sys$command Files /END_OF_FILE=Done /PROMPT="Files: "
$ wso "   Default exclusions: <''Binaries'>"
$ READ sys$command FL /END_OF_FILE=Done /PROMPT="        Exclude files: "
$ FL = F$EDIT(FL,"COLLAPSE,TRIM,UPCASE")
$ IF F$EXTRACT(0,1,FL) .EQS. "+"
$ THEN FL = FL - "+"
$      Exclu = "/EXCLUDE=(" + Binaries + "," + FL + ")"
$ ELSE IF FL .NES. ""
$      THEN Exclu = "/EXCLUDE=(" + FL + ")"
$      ELSE Exclu = "/EXCLUDE=(" + Binaries + ")"
$      ENDIF
$ ENDIF
$ FQual = ""
$ READ sys$command FQual /END_OF_FILE=Done /PROMPT="Additional qualifiers: "
$ !
$Save0:
$ IF F$EXTRACT(0,1,Files) .EQS. "@"
$ THEN FIL$XFile == Files - "@"
$      FIL$XFile == F$PARSE(FIL$XFile,,,"NAME","SYNTAX_ONLY") + ".bck"
$ ENDIF
$ CALL Parse_SaveSet "''P2'"
$ !
$ FLmsg = ""
$ IF F$EXTRACT(0,1,Files) .EQS. "@"
$ THEN Files = Files - "@"
$      Files = F$PARSE(Files,".xfer")
$      FLmsg = " from file-list ''Files'"
$      OPEN /READ /ERROR=FNF f 'Files'
$      Files   = ""
$      DevDir  = ""
$      ODevDir = ""
$      ONamTyp = ""
$   S0:
$      READ /END_OF_FILE=S1 f Fl
$      Fl = F$EDIT(Fl,"COLLAPSE,UNCOMMENT")
$      IF Fl .EQS. "" THEN GOTO S0                 !skip blank lines & comments
$      ! Assert: Strip ;VERS... only copy ;0 of file --
$      TFile  = F$PARSE(Fl,DevDir,,,"SYNTAX_ONLY")
$      DevDir = F$PARSE(TFile,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(TFile,,,"DIRECTORY","SYNTAX_ONLY")
$      NamTyp = F$PARSE(TFile,,,"NAME","SYNTAX_ONLY") + F$PARSE(TFile,,,"TYPE","SYNTAX_ONLY")
$      IF NamTyp .NES. ONamTyp
$      THEN IF DevDir .NES. ODevDir
$           THEN Fl = DevDir + NamTyp
$           ELSE Fl = NamTyp
$           ENDIF
$           ODevDir = DevDir
$           ONamTyp = NamTyp
$      ELSE IF DevDir .NES. ODevDir
$           THEN Fl = DevDir + NamTyp
$                ODevDir = DevDir
$                ONamTyp = NamTyp
$           ELSE GOTO S0   !older/multiple version of same file... skip it
$           ENDIF
$      ENDIF
$      Fl = Fl + ";"
$      IF F$SEARCH(TFile) .NES. ""
$      THEN IF Files .EQS. ""
$           THEN Files = Fl
$           ELSE Files = Files + "," + Fl
$           ENDIF
$      ELSE wso "%''Fac'-W-FNF, file ''Fl' not found"
$      ENDIF
$      IF Ver
$      THEN SHOW SYMBOL Files
$           READ sys$command Dummy /END_OF_FILE=Done /PROMPT="Press <Return> to continue..."
$      ENDIF
$      GOTO S0
$   S1:
$      IF F$TRNLNM("f") .NES. "" THEN CLOSE f
$ ENDIF
$ wso ""
$ wso "%''Fac'-I, creating ''FIL$SaveSet'", FLmsg, "..."
$ IF Ver
$ THEN wso "  $ BACKUP ",FIL$BQual," -"
$      wso "      ",Files," -"
$      wso "         ",Exclu,FQual," -"
$      wso "      ",FIL$SaveSet,"/SAVE "
$      wso "  $ BACKUP ",FIL$SaveSet,"/SAVE /LIST=",FIL$List
$ ELSE BACKUP 'Files' 'Exclu' 'FQual' 'FIL$SaveSet' /SAVE 'FIL$BQual'
$      wso ""
$      wso "%''Fac'-I, created saveset ''FIL$SaveSet'"
$      BACKUP 'FIL$SaveSet' /SAVE /LIST='FIL$List'
$      wso "              and listing file ''FIL$List'"
$      wso ""
$      READ sys$command answer /END_OF_FILE=Done /PROMPT="Check the listing <N>: "
$      answer = F$PARSE(answer,"N",,"NAME","SYNTAX_ONLY")
$      IF answer
$      THEN wso ""
$           TYPE /PAGE 'FIL$List'
$           wso ""
$      ENDIF
$      IF F$TYPE(FTP$TarS) .EQS. "STRING"
$      THEN IF FTP$TarS .NES. ""
$           THEN Node = ""
$                IF F$TYPE(FTP$Node) .EQS. "STRING"
$                THEN IF FTP$Node .NES. ""
$                     THEN Node = "on [1m''FTP$Node'[0m "
$                     ENDIF
$                ENDIF
$                READ sys$command answer /END_OF_FILE=Done -
                   /PROMPT="Send ''FIL$SaveSet' to ''FTP$Dest' ''Node'<Y/n>? "
$                answer = F$PARSE(answer,"Y",,"NAME","SYNTAX_ONLY")
$                IF answer THEN @site$utils:file$ftp 'FIL$SaveSet' 'FTP$Dest'
$                GOTO Done
$           ENDIF
$      ENDIF
$      wso "%''Fac'-W-NOMEMYET, manually transfer files (FTP) this time..."
$ ENDIF
$ GOTO Done
$ !
$Convert:
$ CALL Parse_SaveSet "''P2'"
$ CvtComFile = "SITE$UTILS:FILE$SSCONVERT.COM"
$ IF F$SEARCH(CvtComFile) .NES. ""
$ THEN @'CvtComFile' "''FIL$SaveSet'" "Yes" "''DBSize'"
$ ELSE wso "%''Fac'-E-FNF, cannot find file ''CvtComFile'"
$ ENDIF
$ GOTO Done
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  Use:  $ [1m@FILE$XFER step [saveset] [file[,...] | @Xfer_file] [VERIFY][0m

  FILE$XFER is a hybrid command file for use in a mixed network environment
  which may not fully support VMS file attributes, especially those which
  apply to a Backup saveset.

  FILE$XFER supports two primary functions:

    1. The preparation and creation of a VMS Backup saveset as a "container
       for files" which then can be copied/transferred to another VMS system.

    2. After the saveset file is transferred (typically with a loss or change
       of essential Backup saveset file attributes), converts that container
       file back into a proper Backup saveset by restoring appropriate file
       attributes.

  Either FTP or the CKermit file transfer utility can be used to move (transfer
  or copy) the saveset file over a wide- or local-area network (WAN or LAN) or
  a modem (dial-up) connection.

  FILE$XFER  also supports the interchange of BACKUP savesets using PC diskettes
  (or other suitable medium) as a saveset storage/transport medium.

  FILE$XFER use requires three steps:

  ------------ On the [1msource[0m system ------------

     [1mPREPARE[0m: This step is optional.  It prompts you for a list of files
           to include in the saveset, permitting you to specify qualifiers
           and exclusions.  It also optionally permits you to edit the
           resulting files-list for inspection and corrections.

     [1mSAVE[0m: Uses VMS BACKUP to create a saveset containing files to transport
           to another VMS system.  Instructs you to use an appropriate file
           transfer command to move the saveset to another system.

           For example, you might use FTP to transfer the saveset from
           one VMS system to another over a local- or wide-area network:

               $ [1mftp <nodename>[0m
               FTP> [1mset default DEV:[DIR.SUB][0m
               FTP> [1mset default DEV:[DIR.SUB] /LOCAL[0m
               FTP> [1mbinary[0m
               FTP> [1mput SaveSet.BCK[0m

           Note that "Unix-style" FTP commands (like "binary" or "cd")
           are case-sensitive (must be in lower-case!), while VMS-style
           FTP commands (like "SET DEFAULT", GET and PUT) are case-
           insensitive.

           You may also use the CKermit file transfer utility to move
           the saveset over a modem connection.  Use:

               CKermit> [1mset file type BINARY[0m
               CKermit> [1mremote set file type BINARY[0m
               CKermit> [1msend SaveSet.BCK[0m

           On a Pathworks PC, use the [1mDOS BACKUP[0m command to save the saveset
           file on a diskette (or on multiple diskettes); for example:

               C:\> [1mBACKUP SaveSet.BCK A:[0m

           On the target system, the DOS diskette saveset must be restored
           to recover the original VMS Backup saveset.

  ------------ On the [1mtarget[0m system ------------

  Use network or PC commands and utilities to move the VMS Backup SaveSet
  to any convenient VMS directory; then:

  [1mCONVERT[0m: Performs final steps to convert the saveset into a usable
           native VMS backup file format.

  Finally, you can use appropriate VMS BACKUP commands to "explode" (restore)
  the original files from the saveset to target directories; for example:
  
  $ [1mBACKUP saveset.bck /SAVE dev:[*...] /NEW_VERSION /LOG /OWNER=ORIGINAL[0m

  Under some circumstances, the FILE$UNTANGLE utility may be useful after
  restoring a saveset (see $ [1mUNTANGLE ?[0m).

$ !
$Done:
$ IF F$TYPE(FIL$List)    .NES. "" THEN DELETE /SYMBOL /GLOBAL FIL$List
$ IF F$TYPE(FIL$SaveSet) .NES. "" THEN DELETE /SYMBOL /GLOBAL FIL$SaveSet
$ IF F$TYPE(FIL$BQual)   .NES. "" THEN DELETE /SYMBOL /GLOBAL FIL$BQual
$ IF F$TYPE(FIL$Cmd)     .NES. "" THEN DELETE /SYMBOL /GLOBAL FIL$Cmd
$ IF F$TYPE(FIL$XFile)   .NES. "" THEN DELETE /SYMBOL /GLOBAL FIL$XFile
$ EXIT
$ !
$FNF:
$ wso "%''Fac'-E-FNF, cannot find @-list ''Files'"
$ wso ""
$ wso "  Creating indirect @-list file ''Files'"
$ wso ""
$ DX = Files
$ GOTO Prep0
$ !
$ !
$ ! Parse_Cmd is a local variant of the same routine in site$utils:utility.com;
$ ! this local version makes this com-file self-sufficient.
$ !          ==========
$Parse_Cmd:  SUBROUTINE
$ ! P1: command to parse
$ SET NOON
$ IF P1 .EQS. "" THEN P1 = "HELP"
$ C = "PREPARE |SAVE    |CONVERT |HELP    "
$ L = F$LOCATE( F$EDIT(P1,"COLLAPSE,UPCASE"), C )
$ IF L .LT. F$LENGTH(C)
$ THEN L = ( L + 1 ) / 9
$      FIL$Cmd == F$EDIT( F$ELEMENT(L,"|",C), "COLLAPSE" )
$ ELSE FIL$Cmd == "HELP"
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! Parse_Cmd
$ !
$Parse_SaveSet:  SUBROUTINE
$ P1 = F$PARSE(FIL$XFile,,,"NAME","SYNTAX_ONLY")
$ IF P1 .EQS. ""
$ THEN IF F$TYPE(FIL$SaveSet) .EQS. ""
$      THEN READ sys$command SaveSet /END_OF_FILE=Abort /PROMPT="''FIL$Cmd' Saveset name <''P1'>: "
$      ENDIF
$ ELSE SaveSet = P1
$ ENDIF
$ FIL$SaveSet == F$PARSE(SaveSet,"sys$scratch:''P1'.bck",,,"SYNTAX_ONLY")
$ FIL$List    == F$PARSE(FIL$SaveSet,,,"DEVICE","SYNTAX_ONLY") -
               + F$PARSE(FIL$SaveSet,,,"DIRECTORY","SYNTAX_ONLY") -
               + F$PARSE(FIL$SaveSet,,,"NAME","SYNTAX_ONLY") -
               + ".LIS"
$ EXIT 1
$ ENDSUBROUTINE  ! Parse_SaveSet
$ !
$Ctrl_Y:
$ RETURN %X2C
