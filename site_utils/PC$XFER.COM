$ ! PC$XFER.COM -- VMS/Pathworks/DOS save-set transport            'F$VERIFY(0)'
$ !             -- V3.2, 2-Oct-96
$ !
$ !  P1: Step [ PREPARE | SAVE | RESTORE | CONVERT ]
$ !  P2: Verify [ YES | VERIFY | TRUE | 1 ]
$ !
$ ON ERROR THEN GOTO Done
$ Ver = P2 .OR. (F$EXTRACT(0,1,P2) .EQS. "V")
$ WSO = "WRITE sys$output"
$ Binaries = "*.OBJ,*.EXE,*.%LB,*.PEN,*.XFER,*.LOG,*.*NEW*,*.DIR"
$ XFile = ""
$ Files = ""
$ Quals = ""
$ Exclu = ""
$ CALL Parse_Cmd "''P1'"
$ XFile = ""
$ GOTO 'PCX$Cmd'
$ !
$Prepare:
$ DX = "X.XFER"
$ DF = "*.*;0"
$ DQ = "/SINCE=TODAY"
$ READ sys$command XFile /END_OF_FILE=Done /PROMPT="Transfer filespec <''DX'>: "
$ XFile = F$PARSE(XFile,DX,,,"SYNTAX_ONLY")
$ XFile = XFile - F$PARSE(XFile,,,"VERSION","SYNTAX_ONLY")
$ READ sys$command Files /END_OF_FILE=Done /PROMPT="Files to transfer <''DF'>: "
$ IF Files .EQS. "" THEN Files = DF
$ READ sys$command Quals /END_OF_FILE=Done /PROMPT="Qualifiers <''DQ'>: "
$ IF Quals .EQS. "" THEN Quals = DQ
$ READ sys$command FL /END_OF_FILE=P0 /PROMPT="Exclude <''Binaries'>: "
$ FL = F$EDIT(FL,"COLLAPSE,TRIM,UPCASE")
$ IF F$EXTRACT(0,1,FL) .EQS. "+"
$ THEN FL = FL - "+"
$      Exclu = "/EXCLUDE=(" + Binaries + "," + FL + ")"
$ ELSE IF FL .NES. ""
$      THEN Exclu = "/EXCLUDE=(" + FL + ")"
$      ELSE Exclu = "/EXCLUDE=(" + Binaries + ")"
$      ENDIF
$ ENDIF
$P0:
$ CALL Command "DIRECTORY /OUT=''XFile' /NOHEAD /NOTRAIL /COLUMN=1 ''Files' ''Quals' ''Exclu'" "''Ver'"
$ Exclu = ""  !reset again
$ READ sys$command answer /END_OF_FILE=Done /PROMPT="Edit ''XFile' <Y>: "
$ answer = F$PARSE(answer,"Y",,"NAME","SYNTAX_ONLY")
$ IF answer
$ THEN DEFINE /USER_MODE sys$input sys$command
$      KED /NOSYM 'XFile'
$      PURGE /NOLOG 'XFile'
$ ENDIF
$ READ sys$command answer /END_OF_FILE=Done /PROMPT="Make the transfer save-set (SAVE) <Y>: "
$ answer = F$PARSE(answer,"Y",,"NAME","SYNTAX_ONLY")
$ IF answer
$ THEN Files = "@" + XFile
$      GOTO Save0
$ ELSE EXIT
$ ENDIF
$ !
$Save:
$ READ sys$command Files /END_OF_FILE=Done /PROMPT="Files: "
$ READ sys$command FL /END_OF_FILE=Save0 /PROMPT="Exclude <''Binaries'>: "
$ FL = F$EDIT(FL,"COLLAPSE,TRIM,UPCASE")
$ IF F$EXTRACT(0,1,FL) .EQS. "+"
$ THEN FL = FL - "+"
$      Exclu = "/EXCLUDE=(" + Binaries + "," + FL + ")"
$ ELSE IF FL .NES. ""
$      THEN Exclu = "/EXCLUDE=(" + FL + ")"
$      ELSE Exclu = "/EXCLUDE=(" + Binaries + ")"
$      ENDIF
$ ENDIF
$Save0:
$ CALL Prompt 'PCX$Cmd' "''F$PARSE(XFile,,,"NAME","SYNTAX_ONLY")'"
$ IF F$EXTRACT(0,1,Files) .EQS. "@"
$ THEN Files = Files - "@"
$      Files = F$PARSE(Files,".xfer")
$      OPEN /READ /ERROR=NoFile f 'Files'
$      Files = ""
$      WSO ""
$      WSO "%PC$XFER-I, reading file-list ''Files'..."
$   S0:
$      READ /END_OF_FILE=S1 f Fl
$      Fl = F$EDIT(Fl,"COLLAPSE,UNCOMMENT")
$      IF Fl .EQS. "" THEN GOTO S0
$      IF Files .EQS. ""
$      THEN Files = Fl
$      ELSE Files = Files + "," + Fl
$      ENDIF
$      GOTO S0
$   S1:
$      IF F$TRNLNM("f") .NES. "" THEN CLOSE f
$ ENDIF
$ WSO ""
$ WSO "%PC$XFER-I, creating ''PCX$SaveSet'..."
$ WSO ""
$ IF Ver
$ THEN IF F$LENGTH(Files) .GT. 40
$      THEN F0 = F$EXTRACT(0,40,Files) + "(...)"
$      ELSE F0 = Files
$      ENDIF
$      WSO "  BACKUP ",F0," /EXCLUDE=(...) ",PCX$SaveSet,"/SAVE ",PCX$BQual
$ ENDIF
$ BACKUP 'Files' 'Exclu' 'PCX$SaveSet' /SAVE 'PCX$BQual'
$ WSO ""
$ WSO "%PC$XFER-I, created save-set ''PCX$SaveSet'..."
$ IF Ver THEN WSO "  BACKUP ",PCX$SaveSet,"/SAVE /LIST=",PCX$List
$ BACKUP 'PCX$SaveSet' /SAVE /LIST='PCX$List'
$ WSO "                   and listing file ''PCX$List'."
$ WSO ""
$ GOTO Done
$ !
$Convert:
$ CALL Prompt 'PCX$Cmd'
$ WSO ""
$ WSO "%PC$XFER-I, converting ''PCX$SaveSet'..."
$ WSO ""
$ CALL Command "BACKUP sys$login:login.com;0 PCX$junk.bck /SAVE ''PCX$BQual'" "''Ver'"
$ CALL Command "COPY /OVERLAY ''PCX$SaveSet' PCX$junk.bck" "''Ver'"
$ CALL Command "RENAME /NOLOG PCX$junk.bck ''PCX$SaveSet'" "''Ver'"
$ WSO "%PC$XFER-S, converted ''PCX$SaveSet' to native VMS format..."
$ BACKUP 'PCX$SaveSet' /SAVE /LIST='PCX$List'
$ WSO "                   and created listing file ''PCX$List'."
$ WSO ""
$ WSO "    You can now restore files to target directories"
$ WSO "    with [1mVMS BACKUP[0m; for example:"
$ WSO ""
$ WSO "    $ [1mBACKUP ''PCX$SaveSet'/SAVE dev:[*...] /LOG[0m"
$ WSO ""
$ GOTO Done
$ !
$Restore:
$ WSO ""
$ WSO "%PC$XFER-I, Instructions:"
$ WSO ""
$ WSO "    1.  ON a Pathworks PC, restore diskette (PC backup format) to"
$ WSO "        a convenient VMS directory, using the [1mDOS RESTORE[0m command;"
$ WSO "        for example:"
$ WSO ""
$ WSO "        C:\> [1mRESTORE A: M:''PCX$SaveSet'[0m"
$ WSO ""
$ WSO "    2.  Use [1mDOS NFT COPY[0m to move/convert ''PCX$SaveSet' to a VMS file;"
$ WSO "        for example:"
$ WSO ""
$ WSO "        C:\> [1mNFT COPY /IMAGE M:''PCX$SaveSet' VMSnode::''PCX$SaveSet'[0m"
$ WSO ""
$ WSO "    3.  When the DOS steps are done, re-invoke this procedure:"
$ WSO ""
$ WSO "        $ [1m@PC$XFER CONVERT[0m"
$ WSO ""
$ GOTO Done
$ !
$Help:
$ TYPE sys$input

  PC$XFER is a hybrid command file for use in an OpenVMS/Pathworks
  network environment.

  It supports the interchange of BACKUP save-sets using PC diskettes
  as a save-set storage/transport medium.

  Alternatively, the CKermit file transfer utility can be used to
  move the save-set file over a modem (dial-up) connection.

  Use:  $ [1m@PC$XFER step[0m

  PC$XFER use requires three steps:

  ------------ On the [1msource[0m system ------------

     [1mPREPARE[0m: Prompts you for a list of files to include in the
           save-set, permitting you to specify qualifiers and
           exclusions.  Optionally permits you to edit the
           resulting files-list for inspection and corrections.

     [1mSAVE[0m: Uses VMS BACKUP to create a save-set containing files
           to transport to another VMS system.  Instructs you to
           use a DOS BACKUP command to move the save-set onto a
           PC diskette or to use CKermit file transfer (BINARY mode).

           On a Pathworks PC, use the [1mDOS BACKUP[0m command to save
           the save-set file on a diskette; for example:

               C:\> [1mBACKUP SaveSet.BCK A:[0m

           You may also use the CKermit file transfer utility to move
           the save-set over a modem connection.  Use:

               CKermit> [1mset file type BINARY[0m
               CKermit> [1mremote set file type BINARY[0m
               CKermit> [1msend SaveSet.BCK[0m
           

  ------------ On the [1mtarget[0m system ------------

  [1mRESTORE[0m: Instructs you to use DOS RESTORE and NFT COPY commands
           to move the save-set from PC diskette into a VMS directory.

  [1mCONVERT[0m: Performs final steps to convert the save-set into a usable
           native VMS file format.

$ !
$Done:
$ IF F$TYPE(PCX$List)    .NES. "" THEN DELETE /SYMBOL /GLOBAL PCX$List
$ IF F$TYPE(PCX$SaveSet) .NES. "" THEN DELETE /SYMBOL /GLOBAL PCX$SaveSet
$ IF F$TYPE(PCX$BQual)   .NES. "" THEN DELETE /SYMBOL /GLOBAL PCX$BQual
$ IF F$TYPE(PCX$Cmd)     .NES. "" THEN DELETE /SYMBOL /GLOBAL PCX$Cmd
$ EXIT
$ !
$NoFile:
$ WSO "%PC$XFER-E-FNF, cannot find file-list ''Files'"
$ GOTO Done
$ !
$ !
$Parse_Cmd:  SUBROUTINE
$ ! P1: command to parse
$ IF P1 .EQS. "" THEN P1 = "HELP"
$ C = "PREPARE |SAVE    |RESTORE |CONVERT |HELP    "
$ L = F$LOCATE( F$EDIT(P1,"COLLAPSE,UPCASE"), C )
$ IF L .LT. F$LENGTH(C)
$ THEN L = ( L + 1 ) / 9
$      PCX$Cmd == F$EDIT( F$ELEMENT(L,"|",C), "COLLAPSE" )
$ ELSE PCX$Cmd == "HELP"
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Command:  SUBROUTINE
$ IF P2 THEN WSO "  ", F$EDIT(P1,"COMPRESS")
$ 'P1'
$ EXIT 1
$ ENDSUBROUTINE  ! Command
$ !
$Prompt:  SUBROUTINE
$ IF F$TYPE(PCX$SaveSet) .EQS. ""
$ THEN READ sys$command SaveSet /END_OF_FILE=Abort /PROMPT="''P1' Save-set name <''P2'>: "
$      PCX$SaveSet == F$PARSE(SaveSet,"sys$scratch:''P2'.bck",,,"SYNTAX_ONLY")
$      PCX$List    == F$PARSE(PCX$SaveSet,,,"DEVICE","SYNTAX_ONLY") -
                    + F$PARSE(PCX$SaveSet,,,"DIRECTORY","SYNTAX_ONLY") -
                    + F$PARSE(PCX$SaveSet,,,"NAME","SYNTAX_ONLY") -
                    + ".LIS"
$      PCX$BQual   == "/INTERCHANGE /NOCRC /BLOCK=8192"
$ ENDIF
$ EXIT 1
$Abort:
$ EXIT %X2C
$ ENDSUBROUTINE
