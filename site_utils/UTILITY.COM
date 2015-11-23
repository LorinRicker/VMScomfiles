$ util$ver = 'F$VERIFY(0)'
$ ! UTILITY.COM -- Utility procedures for DCL packages
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2004 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1988-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ! P1        P2        P3         P4      P5       P6   P7   P8  ANSWER_SYMB
$ ! START     FacName   CallerComF VerChk  Quals                  util$fac
$ ! EXIT      FacName                                             (none)
$ !
$ ! CHOOSE    Prompt    Options    Default Quals                  'fac'$choice
$ ! ASK       Prompt    ""         Default Quals                  'fac'$answer
$ !   quals (P5):  Z  Error on Ctrl_Z; Answer := "" and Choice := 0
$ !                N  Null is OK; accept a null response in ASK
$ !                P  Preserve spacing and case; Don't squeeze and upcase
$ !                D  Learn default as ""
$ !                ?  Punctuate prompt with "? ", else ": "
$ !
$ ! SIGNAL    ErrCode   SubstList                                 (none)
$ !
$ ! EXPAND    String    SymName                                   'fac'$'P3'
$ !
$ ! CLUSTER   [SYSMAN commands...(up to 7 lines)...]              (none)
$ !
$ ! INSTALL   Image     LogName    Quals                          (none)
$ ! UNINSTALL Image     LogName                                   (none)
$ !
$ ! HIGHLIGHT String    Rendition                                 'fac'$string
$ ! CLRSCREEN [Light|Dark]                                        (none)
$ !
$ ! FILEPARSE FileSpec  SymName    [Field...(up to 5 fields)...]  'fac'$'P3'
$ !
$ ! FACTORDIR DirSpec   SymList    [Prefix]                       (from SymList)
$ !
$ ! CMDPARSE  Command   SymbName   Default CmdSet   Sep           'fac'$'P3'
$ !                                                             & 'fac'$'P3'_Num
$ !
$ ! REPLACE   String    SymbName   TarStr  ReplStr                'fac'$'P3'
$ !
$ ! MAILTO    SymList   DatFile                                   (from SymList)
$ !
$ ! LOGENTRY  LogFName  Text       Option
$ !
$ ! CHKBATLOG FileSpec  VersLimit  MailTo  Method                 'fac'$EntryNo
$ !                                                             & 'fac'$LogFSpec
$ !                                                             & 'fac'$LogFSVer
$ !
$ ! CHKFILEV  FileSpec  VersLimit  Stall   MailTo   Method        'fac'$FSpec
$ !                                                             & 'fac'$FSVer
$ !
$ ! RAPT$P0   Param1    Param2
$ !
$ ! RDBVERSION RdbVer   "SHOW"                                    RDB_AVAILABLE
$ !                                                             & RDB_V'P2'
$ !
$ ! FINDPROCESS ProcName SymName   MatchType Privs                'fac'$'P3'
$ !
$ !
$ SET SYMBOL/SCOPE=(NOLOCAL)
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON WARNING THEN GOTO Exit
$ GOTO 'P1'
$ !
$ ! ------
$Start:
$ ! ---------------------------
$ util$Version == "V2004.07.09"   !<-- Edit with each new release...
$ util$VerDate == "09-JUL-2004"   !<-- as derived from release date!
$ ! ---------------------------
$ !
$ IF P4 .NES. ""
$ THEN IF P4 .GTS. util$Version
$      THEN WRITE sys$output "%UTILITY-F-INCOMPAT_VERSION, com-file needs [1mminimum version of ''P4'[0m"
$           WRITE sys$output "         I-IDENT, this is UTILITY.COM [4m''util$Version'[0m (''util$VerDate')"
$           EXIT %X2C
$      ENDIF
$ ENDIF
$ IF F$TYPE(util$facs) .EQS. "" THEN util$facs == ""
$ IF F$TYPE(UTIL_FACINUSE) .NES. "" THEN GOTO S3
$ util$tools == F$TRNLNM("TOOLS$DEBUG")  !selectively en/disable debug features
$ @site$utils:util_messages
$ util$m = F$MESSAGE(UTIL_FACINUSE)
$ IF F$LOCATE("NOMSG",util$m) .LT. F$LENGTH(util$m) -
  THEN SET MESSAGE site$utils:util_messages
$S3:
$ util$depth = 0
$S0:
$ util$f = F$ELEMENT(util$depth,",",util$facs)
$ util$depth = util$depth + 1
$ if util$f .EQS. "," THEN GOTO S2
$ if util$f .NES. P2 THEN GOTO S0
$ P3 = P2
$ P2 = UTIL_FACINUSE
$ GOTO SIGNAL
$S2:
$ util$f = P2
$ if util$facs .NES. "" THEN util$f = util$f + ","
$ util$facs == util$f + util$facs
$ util$fac  == P2
$ util$com   = P3
$ 'util$fac'$ == util$com
$ IF F$TRNLNM("''util$fac'$package") .NES. "" THEN GOTO S1
$ util$dev = F$PARSE(util$com,,,"DEVICE","SYNTAX_ONLY")
$ util$dir = F$PARSE(util$com,,,"DIRECTORY","SYNTAX_ONLY")
$ DEFINE 'util$fac'$package 'util$dev''util$dir'
$S1:
$ IF F$SEARCH("''util$fac'$command") .NES. "" THEN GOTO S4
$ DEFINE 'util$fac'$command sys$command
$ 'util$fac'$script_input == 0
$ GOTO S5
$S4:
$ WRITE sys$output "Using script file ",F$TRNLNM("''util$fac'$command")
$ 'util$fac'$script_input == 1
$ 'util$fac'$script_lines == 0
$S5:
$ OPEN 'util$fac'-command 'util$fac'$command
$ util$dev = F$PARSE("''util$fac'$command","sys$disk:",,"DEVICE","SYNTAX_ONLY")
$ 'util$fac'$interactive == F$GETDVI(util$dev,"TRM")
$ IF 'util$fac'$interactive
$ THEN util$p = F$EDIT(P5,"UPCASE,COLLAPSE")
$      IF F$LOCATE("L",util$p) .NE. F$LENGTH(util$p)
$      THEN util$p = F$EDIT(P4,"UPCASE,COLLAPSE")
$           IF util$p .EQS. "" THEN util$p = util$fac
$           @site$utils:utility ASK "Script filename" "" 'util$p' "Z"
$           util$p = F$PARSE('util$fac'$Answer,"sys$disk:[].script")
$           OPEN /WRITE 'util$fac'-learn 'util$p'
$      ENDIF
$ ENDIF
$ EXIT 1 + F$VERIFY(util$ver) * 0
$ !
$ !
$ ! ------
$Choose:
$ ! P2 = prompt, P3 = options, P4 = default, P5 = qualifiers
$Ask:
$ ! P2 = prompt, P3 = "",      P4 = default, P5 = qualifiers
$ !
$ ON ERROR THEN EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ util$status = $STATUS
$ util$eof = 0
$ P5 = F$EDIT(P5,"UPCASE,COLLAPSE")
$ util$e[0,32]=27
$ util$esc[0,1]:='util$e'
$ util$up = util$esc + "M"
$ util$l = P4
$ IF util$l .NES. "" THEN util$l = " <" + P4 + ">"
$ util$punc = ": "
$ IF F$LOCATE("?",P5) .LT. F$LENGTH(P5) -
  THEN util$punc = "? "
$ util$l = """" + P2 + util$l + util$punc + """"
$ util$p = util$esc + "8" + util$esc + "[2K" + util$l
$ IF 'util$fac'$interactive     -
  THEN WRITE sys$output util$esc,"D",util$up,util$esc,"7"
$C0:
$ READ /END_OF_FILE=C7 /PROMPT='util$p' 'util$fac'-command util$a
$ IF F$EDIT(util$a,"UPCASE") .EQS. "^Z" THEN GOTO C7
$ IF 'util$fac'$script_input
$ THEN 'util$fac'$script_lines == 'util$fac'$script_lines + 1
$      IF F$LOCATE("!",util$a) .EQ. 0 THEN GOTO C0
$ ENDIF
$ IF F$LOCATE("P",P5) .EQ. F$LENGTH(P5) -
  THEN util$a = F$EDIT(util$a,"UPCASE,COMPRESS,TRIM,UNCOMMENT")
$ util$o = 0
$ util$d = 0
$ IF util$a .EQS. ""
$ THEN util$a = P4
$      util$d = F$LOCATE("D",P5) .NE. F$LENGTH(P5)
$ ENDIF
$ IF (util$a .NES. "") .OR. (F$LOCATE("N",P5) .NE. F$LENGTH(P5))        -
  THEN GOTO C3
$ IF .NOT. 'util$fac'$script_input
$ THEN WRITE sys$error util$esc,"[2K",F$MESSAGE(UTIL_NODEFAULT),util$up
$      GOTO C0
$ ELSE GOTO C8
$ ENDIF
$C3:
$ IF P1 .NES. "ASK" THEN GOTO C5
$ 'util$fac'$answer == util$a
$ GOTO C4
$C5:
$ util$a = F$EXTRACT(0,1,util$a)
$C6:
$ util$opt = F$ELEMENT(util$o,",",P3)
$ IF util$opt .NES. "," THEN GOTO C2
$ IF .NOT. 'util$fac'$script_input
$ THEN WRITE sys$error util$esc,"[2K",F$FAO(F$MESSAGE(UTIL_ENTRY),util$a),util$up
$     GOTO C0
$ ELSE GOTO C8
$ ENDIF
$C2:
$ util$o = util$o + 1
$ util$c = F$LOCATE(util$a,util$opt)
$ IF util$c .EQ. F$LENGTH(util$opt) THEN GOTO C6
$ 'util$fac'$choice == util$c + 1
$C4:
$ IF 'util$fac'$interactive
$ THEN WRITE sys$output util$esc,"8",util$esc,"D",util$esc,"[2K"
$      CALL Learn 'util$eof' 'P1' 'util$d' 'util$l'
$ ENDIF
$ EXIT (util$status .OR. %X10000000) + F$VERIFY(util$ver) * 0
$C7:
$ util$status = $STATUS
$ util$eof = 1
$ IF F$LOCATE("Z",P5) .EQ. F$LENGTH(P5) -
  THEN util$status =  1                         ! UTIL_FINISH
$ 'util$fac'$choice == 0
$ 'util$fac'$answer == ""
$ GOTO C4
$C8:                                            ! Error in script input
$ WRITE sys$output "Error in script input at line ",'util$fac'$script_lines
$C9:
$ READ /END_OF_FILE=C7 'util$fac'-command util$a
$ GOTO C9
$ !
$Learn: SUBROUTINE
$ IF (F$TRNLNM("''util$fac'-learn") .NES. "") .AND. (.NOT. P1)
$ THEN LLen = F$LENGTH('util$fac'$Answer) + 1
$      IF LLen .LT. 32 THEN LLen = 32
$      util$fao = "!''LLen'AS!!!AS"
$      IF P3
$      THEN WRITE 'util$fac'-learn F$FAO(util$fao,"",P4)
$      ELSE IF P2 .EQS. "ASK"
$           THEN WRITE 'util$fac'-learn F$FAO(util$fao,'util$fac'$Answer,P4)
$           ELSE WRITE 'util$fac'-learn F$FAO(util$fao,F$STRING('util$fac'$Choice),P4)
$           ENDIF
$      ENDIF
$ ENDIF
$ ENDSUBROUTINE
$ !
$ !
$ ! ------
$ClrScreen:
$ ! Clear screen for VTX00 terminals                              !'F$VERIFY(0)'
$ IF F$GETDVI("TT","TT_ANSICRT") THEN GOTO crt
$ WRITE sys$output F$FAO("!2(/)!8*-!3(/)")
$ EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$crt:
$ util$e[0,32]=27
$ util$esc[0,1]:='util$e'
$ clr = util$esc + "[m" + util$esc + "[H" + util$esc + "[J"
$ IF P2 .EQS. "" THEN GOTO clr0  !don't change background
$ GOTO clr'F$EXTRACT(0,1,P2)'
$clrD:
$ clr = clr + util$esc + "[?5l" !dark
$ GOTO clr0
$clrL:
$ clr = clr + util$esc + "[?5h" !light
$clr0:
$ WRITE sys$output clr
$ EXIT 1 + F$VERIFY(util$ver) * 0
$ !
$ !
$ ! ------
$Exit:                                                            !'F$VERIFY(0)'
$ util$status = $STATUS
$ ON ERROR THEN GOTO Exit
$ IF F$TYPE(util$fac) .EQS. "" THEN GOTO E2
$ util$sym = "sys$scratch:''util$fac'$symbols.lis;"
$ ON ERROR THEN GOTO E1
$ CALL/OUTPUT='util$sym' SYMBOLS 'util$fac'$*
$ OPEN util-sym 'util$sym'
$E0:
$ READ/END_OF_FILE=E1 util-sym util$symbol
$ DELETE /SYMBOL /GLOBAL 'F$ELEMENT(0,"=",F$EDIT(util$symbol,"COLLAPSE"))'
$ GOTO E0
$E1:
$ SET NOON
$ IF F$TRNLNM("util-sym") .NES. "" THEN CLOSE util-sym
$ IF F$SEARCH(util$sym) .NES. "" THEN DELETE 'util$sym'
$ IF F$TRNLNM("''util$fac'-learn") .NES. "" -
  THEN CLOSE 'util$fac'-learn
$ IF F$TRNLNM("''util$fac'-command") .NES. "" -
  THEN CLOSE 'util$fac'-command
$ IF F$TRNLNM("''util$fac'$command","LNM$PROCESS_TABLE") .EQS. "SYS$COMMAND" -
  THEN DEASSIGN 'util$fac'$command
$ IF F$TYPE(util$facs) .EQS. "" THEN GOTO E3
$ util$facs == util$facs - F$ELEMENT(0,",",util$facs) - ","
$ if util$facs .EQS. "" THEN GOTO E3
$ util$fac  == F$ELEMENT(0,",",util$facs)
$ GOTO E2
$E3:
$ IF F$TYPE(util$facs)    .NES. "" THEN DELETE /SYMBOL /GLOBAL util$facs
$ IF F$TYPE(util$fac)     .NES. "" THEN DELETE /SYMBOL /GLOBAL util$fac
$ IF F$TYPE(util$tools)   .NES. "" THEN DELETE /SYMBOL /GLOBAL util$tools
$ IF F$TYPE(util$Version) .NES. "" THEN DELETE /SYMBOL /GLOBAL util$Version
$ IF F$TYPE(util$VerDate) .NES. "" THEN DELETE /SYMBOL /GLOBAL util$VerDate
$E2:
$ EXIT (util$status .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ !
$ !
$ ! ------
$Signal:
$ ON ERROR THEN EXIT ($STATUS .OR. %X10000000)  + F$VERIFY(util$ver) * 0
$ IF F$TYPE(UTIL_FACINUSE) .EQS. ""
$ THEN @site$utils:util_messages
$      util$m = F$MESSAGE(UTIL_FACINUSE)
$      IF F$LOCATE("NOMSG",util$m) .LT. F$LENGTH(util$m)
$      THEN SET MESSAGE site$utils:util_messages
$      ENDIF
$ ENDIF
$ WRITE sys$error F$FAO(F$MESSAGE(P2),P3,P4,P5,P6,P7,P8)
$ EXIT (%X10000000 .OR. 'P2') + F$VERIFY(util$ver) * 0
$ !
$ ! ------
$Expand:
$ CALL Expand_String 'P2' 'P3'
$ EXIT 1 + F$VERIFY(util$ver) * 0
$ !
$Expand_String: SUBROUTINE
$ SET SYMBOL/SCOPE=NOLOCAL
$ IF F$TYPE('util$fac'$'P2') .EQS. "" THEN 'util$fac'$'P2' == ""
$ util$e = 0
$ IF P1 .EQS. "" THEN GOTO X9
$X0:
$ util$elem = F$ELEMENT(util$e,",",P1)
$ IF util$elem .EQS. "," THEN GOTO X9
$ IF F$TRNLNM(util$elem) .EQS. ""
$ THEN IF 'util$fac'$'P2' .EQS. ""
$      THEN 'util$fac'$'P2' == util$elem
$      ELSE 'util$fac'$'P2' == 'util$fac'$'P2' + "," + util$elem
$      ENDIF
$ ELSE util$i = 0
$X1:   util$lnm = F$TRNLNM(util$elem,,util$i)
$      IF util$lnm .EQS. "" THEN GOTO X2
$      CALL Expand_String 'util$lnm' 'P2'
$      util$i = util$i + 1
$      GOTO X1
$ ENDIF
$X2:
$ util$e = util$e + 1
$ GOTO X0
$X9:
$ ENDSUBROUTINE
$ !
$Symbols: SUBROUTINE
$ ON CONTROL_Y THEN EXIT %X0000002C
$ ON ERROR THEN EXIT ($STATUS .OR. %X10000000)
$ SHOW SYMBOL /GLOBAL 'P1'
$ IF F$TYPE(util$facs) .NES. ""                 -
  THEN IF F$ELEMENT(1,",",util$facs) .EQS. ","  -
       THEN SHOW SYMBOL /GLOBAL UTIL_*
$ ENDSUBROUTINE
$ !
$ ! ------
$Ctrl_Y:
$ RETURN %X0000002C
$ !
$ !
$ ! ------
$Install:
$ ! P2 : Image name (and dev:[dir] if needed)
$ ! P3 : Logical name (optional)
$ ! P4 : INSTALL qualifiers (optional)
$ ON ERROR THEN EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ DEFINE = "DEFINE /SYSTEM /EXECUTIVE_MODE /NOLOG"
$ IF P4 .EQS. "" THEN P4 = "/SHARE"
$ Img = F$PARSE(P2,"sys$library:.exe",,,"SYNTAX_ONLY") - ";"
$ IF F$SEARCH(Img) .NES. ""
$ THEN IF P3 .NES. "" THEN DEFINE 'P3' 'Img'
$      IF .NOT. F$FILE_ATTRIBUTES(Img,"KNOWN")
$      THEN INSTALL CREATE  'Img' 'P4'
$      ELSE INSTALL REPLACE 'Img'
$      ENDIF
$ ENDIF
$ EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ !
$UnInstall:
$ ! P2 : Image name (and dev:[dir] if needed)
$ ! P3 : Logical name (optional)
$ ON ERROR THEN EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ DEASSIGN = "DEASSIGN /SYSTEM /EXECUTIVE_MODE"
$ Img = F$PARSE(P2,"sys$library:.exe",,,"SYNTAX_ONLY") - ";"
$ IF F$FILE_ATTRIBUTES(Img,"KNOWN") THEN INSTALL REMOVE 'P2'
$ IF ( P3 .NES. "" ) -
  THEN IF ( F$TRNLNM(P3) .NES. "" ) THEN DEASSIGN 'P3'
$ EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ !
$ !
$ ! ------
$Highlight:      !adds [BOLD,UNDERLINE,REVERSE,BLINK] rendition to a string
$ ! P2: the string to illuminate
$ ! P3: desired rendition
$ ON ERROR THEN EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ CALL Cmd$Parse "''P3'" "Cmd" -
                 "BOLD" "BOLD     |UNDERLINE|BLINK    |REVERSE  "
$ util$e[0,32]=27
$ util$esc[0,1]:='util$e'
$ Ron  = util$esc + F$ELEMENT('util$fac'$Cmd_Num-1,"|","[1m|[4m|[5m|[7m|")
$ Roff = util$esc + "[0m"
$ 'util$fac'$String == Ron + P2 + Roff
$ util$status = $STATUS
$ EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ !
$ ! ------
$Replace:
$ ON ERROR THEN EXIT ($STATUS .OR. %X10000000)
$L1:
$ I  = F$LOCATE(P4,P2)          !find TarStr in source String
$ DL = F$LENGTH(P2)             !length of source
$ IF I .GE. DL THEN GOTO L2     !nothing (more) to replace?
$ P2 = F$EXTRACT(0,I,P2) + P5 + F$EXTRACT(I+1,DL-I-1,P2)
$ GOTO L1
$L2:
$ 'util$fac'$'P3' == P2
$ EXIT
$ !
$ !
$ !  ------
$FactorDir:       !factors a directory spec, counts levels, tests existence
$ !
$ !  This service routine accepts a directory specification, such as:
$ !
$ !      "DEV:[DIR]",  "DEV:[DIR.SUB1]",  "DEV:[DIR.SUB1.SUB2]"  (etc.)
$ !
$ !  and "factors" it, returning as global symbols:
$ !
$ !   1. Device part of that directory-spec,
$ !   2. Directory part of that directory-spec,
$ !   3. Directory Name ("DIR", "SUB1" or "SUB2" for the examples above)
$ !   4. Directory Base ("[000000]", "[DIR]", or "[DIR.SUB1]" above)
$ !   5. Full File-Spec for the directory file itself ("DEV:[000000]DIR.DIR;1"
$ !        "DEV:[DIR]SUB1.DIR;1" or "DEV:[DIR.SUB1]SUB2.DIR;1")
$ !   6. Down-Tree-Spec (with dots): "DEV:[DIR...]", "DEV:[DIR.SUB1...]", etc.
$ !   7. Boolean flag that the directory file actually exists (1 or 0)
$ !   8. Directory level (0 is the root-directory level), integer
$ !
$ ON ERROR THEN EXIT ($STATUS .OR. %X10000000)
$ util$status = $STATUS
$ CALL Factor$Directory "''P2'" "''P3'" "''P4'"
$ EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ !
$Factor$Directory:  SUBROUTINE
$ ! P1: directory-spec to factor
$ ! P2: comma-list of Output Global Symbol Names to receive values
$ !     "Dev, Dir, DirName, DirBase, FullSpec, TreeDown, DirExists [,DirLevel]"
$ ! P3: (optional) prefix string for each Output Global Symbol Name
$ !                (defaults to "''util$fac'$")
$ !
$ SET NOON
$ wso = "WRITE sys$output"
$ fac = "UTILITY:FactorDir"
$ Here = F$ENVIRONMENT("DEFAULT")
$ IF P3 .EQS. "" THEN P3 = util$fac + "$"
$ IF F$TYPE('P3'Verbose) .EQS. "" THEN 'P3'Verbose = 0
$ !
$ ! Dev
$ tmp = F$EDIT(F$ELEMENT(0,",",P2),"COLLAPSE,UPCASE")
$ IF (tmp .EQS. "") .OR. (tmp .EQS. ",")
$ THEN tmp = "Device (S1)"
$      GOTO FDErr
$ ELSE S1 = P3 + tmp
$ ENDIF
$ ! Dir
$ tmp = F$EDIT(F$ELEMENT(1,",",P2),"COLLAPSE,UPCASE")
$ IF (tmp .EQS. "") .OR. (tmp .EQS. ",")
$ THEN tmp = "Directory (S2)"
$      GOTO FDErr
$ ELSE S2 = P3 + tmp
$ ENDIF
$ ! DirName
$ tmp = F$EDIT(F$ELEMENT(2,",",P2),"COLLAPSE,UPCASE")
$ IF (tmp .EQS. "") .OR. (tmp .EQS. ",")
$ THEN tmp = "Directory Name (S3)"
$      GOTO FDErr
$ ELSE S3 = P3 + tmp
$ ENDIF
$ ! DirBase
$ tmp = F$EDIT(F$ELEMENT(3,",",P2),"COLLAPSE,UPCASE")
$ IF (tmp .EQS. "") .OR. (tmp .EQS. ",")
$ THEN tmp = "Directory Base (S4)"
$      GOTO FDErr
$ ELSE S4 = P3 + tmp
$ ENDIF
$ ! FullSpec
$ tmp = F$EDIT(F$ELEMENT(4,",",P2),"COLLAPSE,UPCASE")
$ IF (tmp .EQS. "") .OR. (tmp .EQS. ",")
$ THEN tmp = "Full Spec (S5)"
$      GOTO FDErr
$ ELSE S5 = P3 + tmp
$ ENDIF
$ ! DirDown
$ tmp = F$EDIT(F$ELEMENT(5,",",P2),"COLLAPSE,UPCASE")
$ IF (tmp .EQS. "") .OR. (tmp .EQS. ",")
$ THEN tmp = "Dir Down (S6)"
$      GOTO FDErr
$ ELSE S6 = P3 + tmp
$ ENDIF
$ ! DirExists
$ tmp = F$EDIT(F$ELEMENT(6,",",P2),"COLLAPSE,UPCASE")
$ IF (tmp .EQS. "") .OR. (tmp .EQS. ",")
$ THEN tmp = "Dir Exists (S7)"
$      GOTO FDErr
$ ELSE S7 = P3 + tmp
$ ENDIF
$ ! DirLevel (optional):
$ S8 = P3 + F$EDIT(F$ELEMENT(7,",",P2),"COLLAPSE,UPCASE")
$ !
$ ! Device:
$ 'S1' == F$PARSE(P1,Here,,"DEVICE","SYNTAX_ONLY")
$ ! Directory:
$ 'S2' == F$PARSE(P1,Here,,"DIRECTORY","SYNTAX_ONLY")
$ ! Directory Name (initialized):
$ 'S3' == 'S2' - "[" - "]"
$ ! Directory Base (initialized):
$ 'S4' == ""
$ !
$ !Factor directory-spec "[D1.D2.D3]" (etc.) into "[D1.D2]D3.DIR":
$ I = 0
$ len = F$LENGTH('S3')
$ dot = F$LOCATE(".",'S3')
$ IF dot .EQ. len
$ THEN 'S4' = "000000"                  !Directory Base: root/MFD, special case
$      GOTO D1
$ ENDIF
$D0:
$ IF dot .GE. len
$ THEN 'S3' == cdr                      !Directory Name (final value)
$      GOTO D1
$ ELSE car = F$ELEMENT(0,".",'S3')
$      cdr = F$EXTRACT(dot+1,len-dot,'S3')
$      IF 'S4' .NES. ""
$      THEN 'S4' == 'S4' + "." + car    !Directory Base (building it up)
$      ELSE 'S4' == car
$      ENDIF
$      IF SSA$Verbose THEN wso F$FAO("!2SL: !AS (!AS, !AS)",I,'S4',car,cdr)
$      'S3' == cdr                      !Directory Name (parsing it down)
$      len = F$LENGTH('S3')
$      dot = F$LOCATE(".",'S3')
$      I = I + 1
$      GOTO D0
$ ENDIF
$ !
$D1:
$ ! Full Directory FileSpec:
$ 'S5' == 'S1' + "[" + 'S4' + "]" + 'S3' + ".dir"
$ ! Tree-Down spec:
$ tmp = 'S2' - "[" - "]"
$ 'S6' == 'S1' + "[" + tmp + "...]"
$ ! Dir exists?
$ 'S7' == ( F$SEARCH('S5') .NES. "" )
$ !
$ ! Directory Level:
$ IF F$TYPE(S8) .EQS. "STRING" THEN 'S8' == I + 1  !"[000000]"/MFD is level 0
$ IF SSA$Verbose
$ THEN SHOW SYMBOL 'S1'  !Dev
$      SHOW SYMBOL 'S2'  !Dir
$      SHOW SYMBOL 'S3'  !DirName
$      SHOW SYMBOL 'S4'  !DirBase
$      SHOW SYMBOL 'S5'  !Full filespec
$      SHOW SYMBOL 'S6'  !TreeDown
$      SHOW SYMBOL 'S7'  !Exists
$      IF F$TYPE(S8) .EQS. "STRING" THEN SHOW SYMBOL 'S8'  !Level (optional)
$ ENDIF
$ EXIT 1
$ !
$FDErr:
$ wso F$FAO("%!AS-E-BADPARAM, missing symbol name for [1m!AS[0m",fac,tmp)
$ EXIT %X2C
$ ENDSUBROUTINE  ! Factor$Directory
$ !
$ !
$ !  ------
$CmdParse:       !Provides first/minimal-matching command recognition
$ ON ERROR THEN EXIT ($STATUS .OR. %X10000000)
$ util$status = $STATUS
$ CALL Cmd$Parse "''P2'" "''P3'" "''P4'" "''P5'" "''P6'"
$ EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ !
$Cmd$Parse: SUBROUTINE
$ ! P1: command to parse
$ ! P2: global symbol to receive answer
$ ! P3: default command
$ ! P4: command-set ("C1|C2[|Cn...]") -- options must be same-length fields
$ !     or "@symbol" where "symbol" contains command-set (this accommodates
$ !     very long command-sets, > 255 characters)
$ ! P5: command separator
$ IF P1 .EQS. "" THEN P1 = P3
$ IF P2 .EQS. "" THEN P2 = "Cmd"
$ IF P5 .EQS. "" THEN P5 = "|"
$ IF F$EXTRACT(0,1,P4) .EQS. "@"
$ THEN sym = P4 - "@"
$      P4 = 'sym'
$ ENDIF
$ P4 = F$EDIT(P4,"UPCASE")
$ S  = F$LOCATE(P5,P4) + 1               !Determine field length
$ P4 = P5 + P4                           !Add separator to front of list...
$ T  = P5 + F$EDIT(P1,"COLLAPSE,UPCASE") !...and to target
$ L  = F$LOCATE( F$EDIT(T,"COLLAPSE,UPCASE"), P4 )      !Test substring
$ IF ( L .LT. F$LENGTH(P4) ) .AND. ( L-(L/S)*S .EQ. 0 ) !Found?
$ THEN L = ( ( L + 1 ) / S ) + 1                        !Calculate offset
$      !Return both the full command and its element #:
$      'util$fac'$'P2'     == F$EDIT( F$ELEMENT(L,P5,P4), "COLLAPSE" )
$      'util$fac'$'P2'_Num == L  !1-based: 1=first command, 2=second, ...
$      EXIT 1
$ ELSE 'util$fac'$'P2'     == "$Err$"
$      'util$fac'$'P2'_Num == -1
$      WRITE sys$output "\''P1'\ (expecting: ''F$EDIT(P4,"COLLAPSE")')"
$      EXIT 229522  !%DCL-E-IVVERB, unrecognized command verb
$ ENDIF
$ ENDSUBROUTINE
$ !
$ !
$ ! ------
$FileParse:       !Provides all-in-one file parse
$ ON ERROR THEN EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ util$status = $STATUS
$ CALL File$Parse "''P2'" "''P3'" "''P4'" "''P5'" "''P6'" "''P7'" "''P8'"
$ EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ !
$File$Parse:  SUBROUTINE
$ ! P1:     filespec to parse
$ ! P2:     global symbol to receive answer
$ ! P3..P7: field(s) to return
$ IF P2 .EQS. "" THEN P2 = "File"
$ Nd = F$PARSE(P1,,, "NODE",      "SYNTAX_ONLY")
$ Dv = F$PARSE(P1,,, "DEVICE",    "SYNTAX_ONLY")
$ Dr = F$PARSE(P1,,, "DIRECTORY", "SYNTAX_ONLY")
$ Na = F$PARSE(P1,,, "NAME",      "SYNTAX_ONLY")
$ Ty = F$PARSE(P1,,, "TYPE",      "SYNTAX_ONLY")
$ Vr = F$PARSE(P1,,, "VERSION",   "SYNTAX_ONLY")
$ P3 = F$EDIT(P3,"COLLAPSE,UPCASE")
$ IF ( P3 .EQS. "" ) .OR. ( P3 .EQS. "ALL" ) .OR. ( P3 .EQS. "FULL" )
$ THEN FP = Nd + Dv + Dr + Na + Ty + Vr
$ ELSE F  = "," + P3 + "," + P4 + "," + P5 + "," + P6 + "," + P7 + "," + P8
$      F  = F$EDIT(F,"COLLAPSE,UPCASE")
$      FL = F$LENGTH(F)
$      FP = ""
$      IF ( F$LOCATE(",NOD",F) .LT. FL ) THEN FP = FP + Nd
$      IF ( F$LOCATE(",DEV",F) .LT. FL ) THEN FP = FP + Dv
$      IF ( F$LOCATE(",DIR",F) .LT. FL ) THEN FP = FP + Dr
$      IF ( F$LOCATE(",NAM",F) .LT. FL ) THEN FP = FP + Na
$      IF ( F$LOCATE(",TYP",F) .LT. FL ) THEN FP = FP + Ty
$      IF ( F$LOCATE(",VER",F) .LT. FL ) THEN FP = FP + Vr
$ ENDIF
$ 'util$fac'$'P2' == FP
$ EXIT 1
$ ENDSUBROUTINE
$ !
$ !
$ ! ------
$Cluster:  !'F$VERIFY(0)'
$ ! Do commands cluster-wide (conditionally) or for this node --
$ !   Each P2..P8:
$ !     If prefixed with "$NODES:", then provides comma-separated list of
$ !        nodenames for SET ENVIRONMENT ... If present, a "$NODES:" line
$ !        *MUST BE* the FIRST parameter, i.e., P2 (for SYSMAN setup)!
$ !        Example: "$NODES: STURM,RUGER,PALE[,...]"
$ !     If prefixed with "$OUTPUT:", then provides name of output file for
$ !        any output captured from SYSMAN, and causes that output to be
$ !        TYPE'd (unless "$NOTYPE" is specified after "$OUTPUT"); if not
$ !        present, then output goes to SYS$SCRATCH:UTILITY_SYSMAN.LIS ...
$ !        Example: "$OUTPUT: sys$scratch:rshow_users.lis"
$ !     If prefixed with "$NOTYPE:", then output file is *not* TYPE'd,
$ !        on the presumption that the caller will handle output...
$ !        Note: $NOTYPE *must follow* $OUTPUT in order to override the
$ !              default action of $OUTPUT which is to TYPE the output.
$ !        Example: "$NOTYPE" or "$NOTYPE:"
$ !     If prefixed with "$DELOUTPUT:", then the output file will
$ !        be deleted; otherwise, it's retained...
$ !     Otherwise, a DCL command line for SYSMAN DO ... Note! No leading "$"!
$ !
$ SET NOON
$ wso = "WRITE sys$output"
$ wf  = "WRITE f"
$ NoProblem = 1                         !assume the best...
$ Nodes  = ""
$ CmdF   = "SYS$SCRATCH:UTILITY_TEMP.COM"
$ OutF   = "sys$scratch:utility_sysman.lis"
$ TypIt  = 0      !default: No, don't TYPE the output file
$ DelOut = 0
$ LNode  = F$EDIT(F$GETSYI("NODENAME"),"TRIM")
$ ClusterMember = F$GETSYI("CLUSTER_MEMBER")
$ IF ClusterMember
$ THEN Pfx = "DO "
$ ELSE Pfx = "$ "
$ ENDIF
$ !
$ ! Have to spin through P2..P8 twice!...Once for "$XXX:", second for commands:
$ IF util$tools THEN wso "%UTILITY-I-CLUSTER, parameter pass 1"
$ i = 2
$CluLoop1:
$ IF i .GT. 8 THEN GOTO Clu2
$ P'i' = F$EDIT(P'i',"TRIM,UPCASE")
$ IF P'i' .EQS. ""  !Skip any empty parameters...
$ THEN i = i + 1
$      GOTO CluLoop1
$ ENDIF
$ IF F$EXTRACT(0,1,P'i') .EQS. "$"          ! Leads with a "$" (1st char)?
$ THEN IF util$tools THEN SHOW SYMBOL P'i'
$      Lbl = F$ELEMENT(0,":",P'i') - "$"
$      IF util$tools THEN SHOW SYMBOL Lbl
$      ON WARNING THEN GOTO CluUndef
$      GOTO Clu'Lbl'
$CluNODE:             !honor both spellings: $NODE and $NODES
$CluNODES:
$      Nodes = F$EDIT(F$ELEMENT(1,":",P'i'),"COLLAPSE,UPCASE")
$      IF util$tools THEN SHOW SYMBOL Nodes
$      i = i + 1
$      GOTO CluLoop1
$CluOUTPUT:
$      Colon = F$LOCATE(":",P'i')
$      OutF  = F$EXTRACT(Colon+1,F$LENGTH(P'i')-Colon,P'i')
$      OutF  = F$EDIT(OutF,"TRIM,UPCASE")
$      IF util$tools THEN SHOW SYMBOL OutF
$      TypIt = 1    ! Special output file requested?  TYPE/PAGE it...
$      i = i + 1
$      GOTO CluLoop1
$CluNOTYPE:
$      TypIt = 0
$      i = i + 1
$      GOTO CluLoop1
$CluDELOUTPUT:
$      DelOut = 1
$      i = i + 1
$      GOTO CluLoop1
$ ELSE i = i + 1
$      GOTO CluLoop1
$ ENDIF
$CluUndef:
$ wso F$FAO("%UTILITY-E-BAD_LABEL, no such GOTO label [1m!AS[0m in CLUSTER",Lbl)
$ NoProblem = 0
$ GOTO CluDo
$ !
$Clu2:  !Create the com-file preamble...
$ OPEN /WRITE f 'CmdF'
$ wf "$ ! ''CmdF' -- temporary command file (can be deleted)"
$ wf "$ SET NOON"
$ IF ClusterMember
$ THEN IF Nodes .NES. ""
$      THEN wf "$ WRITE sys$output ""%SYSMAN-I-REMOTENODES, connecting to nodes ''Nodes'"""
$           Clu = "/NODES=(''Nodes')"
$      ELSE wf "$ WRITE sys$output ""%SYSMAN-I-REMOTENODES, connecting to entire cluster"
$           Clu = "/CLUSTER"
$      ENDIF
$ ELSE wf "$ WRITE sys$output ""%STANDALONE-I-LOCALNODE, executing on local node ''LNode' only"""
$ ENDIF
$ wf "$ DEFINE /USER_MODE sys$output ''OutF'"
$ wf "$ DEFINE /USER_MODE sys$error  nl:"
$ IF ClusterMember
$ THEN wf "$ MCR SYSMAN"
$      wf "SET ENVIRONMENT ''Clu'"
$      wf "SET PROFILE /PRIVILEGES=(OPER,CMKRNL,SYSNAM,SYSPRV,WORLD)"
$ ENDIF
$ !
$ IF util$tools THEN wso "%UTILITY-I-CLUSTER, parameter pass 2"
$ i = 2  !second pass through P2..P8 -- write any commands...
$CluLoop2:
$ IF i .GT. 8 THEN GOTO CluDo
$ IF F$EXTRACT(0,1,P'i') .NES. "$"    ! Now skip the "$XXX:" specials...
$ THEN IF util$tools THEN SHOW SYMBOL P'i'
$      IF P'i' .NES. "" THEN wf Pfx, P'i'
$ ENDIF
$ i = i + 1
$ GOTO CluLoop2
$ !
$CluDo:
$ SET NOON
$ IF ClusterMember THEN wf "EXIT"      !from SYSMAN
$ wf "$ EXIT"
$ CLOSE f
$ !
$ IF util$tools THEN TYPE 'CmdF'
$ IF NoProblem THEN @'CmdF'
$ IF TypIt THEN TYPE /PAGE 'OutF'
$ IF .NOT. util$tools
$ THEN IF DelOut THEN DELETE /NOLOG 'OutF';*
$      IF NoProblem THEN DELETE /NOLOG 'CmdF';*
$ ENDIF
$ EXIT 1
$ !
$ !
$ !  ------
$MailTo:   ! forms up to three lists of SysMgr names for mail, reply & pager
$ ON ERROR THEN EXIT ($STATUS .OR. %X10000000)
$ util$status = $STATUS
$ CALL MailTo$Names "''P2'" "''P3'"
$ EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ !
$MailTo$Names:  SUBROUTINE  !'F$VERIFY(0)'
$ ! P1: "MailTo[,ReplyTo[,PageTo]]" names of global symbols
$ ! P2: Filespec to read (must be provided without ".ext": we'll supply our own)
$ !
$ SET NOON
$ Node = F$EDIT(F$GETSYI("NODENAME"),"TRIM,UPCASE")
$ Tmp0 = ""
$ Tmp1 = ""
$ Tmp2 = ""
$ Dat  = F$PARSE(P2,"mgr$command:.dat")
$ !
$ GS0 = F$ELEMENT(0,",",P1)
$ GS0Def = ( GS0 .NES. "," ) .AND. ( GS0 .NES. "" )
$ IF GS0Def THEN 'util$fac'$'GS0' == ""
$ GS1 = F$ELEMENT(1,",",P1)
$ GS1Def = ( GS1 .NES. "," ) .AND. ( GS1 .NES. "" )
$ IF GS1Def THEN 'util$fac'$'GS1' == ""
$ GS2 = F$ELEMENT(2,",",P1)
$ GS2Def = ( GS2 .NES. "," ) .AND. ( GS2 .NES. "" )
$ IF GS2Def THEN 'util$fac'$'GS2' == ""
$ !
$ ! Consume the SMART$System_Managers data file
$ !  to build a comma-separated mail-to list:
$ IF F$SEARCH(Dat) .NES. ""
$ THEN OPEN /READ /SHARE /ERROR=MTF1 MTFile 'Dat'
$MTFLoop:
$      READ /ERROR=MTFNF /END_OF_FILE=MTFDone MTFile Rec
$      Rec = F$EDIT(Rec,"UNCOMMENT,TRIM")
$      IF ( Rec .EQS. "" ) THEN GOTO MTFLoop  !skip comments & blank lines
$      IF GS0Def
$      THEN IF F$TYPE('util$fac'$'GS0') .EQS. "STRING"
$           THEN R0 = F$ELEMENT(0,";",Rec)        ! "email [/NODE]"
$                UName = F$EDIT(F$ELEMENT(0,"/",R0),"COLLAPSE")
$                ! Prefix Internet email addresses: "SMTP%uname@foo.com"
$                IF F$LOCATE("@",UName) .LT. F$LENGTH(UName) THEN UName = "SMTP%" + UName
$                NName = F$EDIT(F$ELEMENT(1,"/",R0),"COLLAPSE")
$                ! If username tagged for "this" or "any" node, add it to list:
$                IF ( NName .EQS. Node ) .OR. ( NName .EQS. "/" )
$                THEN IF Tmp0 .EQS. ""
$                     THEN Tmp0 = UName
$                     ELSE Tmp0 = Tmp0 + "," + UName
$                     ENDIF
$                ENDIF
$           ENDIF
$      ENDIF
$      IF GS1Def
$      THEN IF F$TYPE('util$fac'$'GS1') .EQS. "STRING"
$           THEN R1 = F$ELEMENT(1,";",Rec)        ! ";reply_username"
$                IF ( R1 .NES. ";" ) .AND. ( R1 .NES. "" )
$                THEN UName = F$EDIT(R1,"COLLAPSE")
$                     IF F$LOCATE("@",UName) .LT. F$LENGTH(UName) THEN UName = "SMTP%" + UName
$                     IF Tmp1 .EQS. ""
$                     THEN Tmp1 = UName
$                     ELSE Tmp1 = Tmp1 + "," + UName
$                     ENDIF
$                ENDIF
$           ENDIF
$      ENDIF
$      IF GS2Def
$      THEN IF F$TYPE('util$fac'$'GS2') .EQS. "STRING"
$           THEN R2 = F$ELEMENT(2,";",Rec)        ! ";pager-email"
$                IF ( R2 .NES. ";" ) .AND. ( R2 .NES. "" )
$                THEN UName = F$EDIT(R2,"COLLAPSE")
$                     IF F$LOCATE("@",UName) .LT. F$LENGTH(UName) THEN UName = "SMTP%" + UName
$                     IF Tmp2 .EQS. ""
$                     THEN Tmp2 = UName
$                     ELSE Tmp2 = Tmp2 + "," + UName
$                     ENDIF
$                ENDIF
$           ENDIF
$      ENDIF
$      GOTO MTFLoop
$MTFDone:
$      CLOSE MTFile
$      IF GS0Def
$      THEN IF F$TYPE('util$fac'$'GS0') .EQS. "STRING" THEN 'util$fac'$'GS0' == Tmp0
$      ENDIF
$      IF GS1Def
$      THEN IF F$TYPE('util$fac'$'GS1') .EQS. "STRING" THEN 'util$fac'$'GS1' == Tmp1
$      ENDIF
$      IF GS2Def
$      THEN IF F$TYPE('util$fac'$'GS2') .EQS. "STRING" THEN 'util$fac'$'GS2' == Tmp2
$      ENDIF
$      EXIT 1
$ ELSE wso "%''Fac'-E-MAILTONAMES, file not found: ""''P2'.dat"""
$      EXIT 1
$ ENDIF
$MTFNF:
$ wso "%''Fac'-E-FILOPENERR, error opening file ''P2'.dat"
$ EXIT 1
$ ENDSUBROUTINE  ! MailTo$Names
$ !
$ !
$ ! ------
$LogEntry:
$ ON ERROR THEN EXIT ($STATUS .OR. %X10000000)
$ util$status = $STATUS
$ CALL Log$Entry "''P2'" "''P3'" "''P4'" "''P5'" "''P6'" "''P7'" "''P8'"
$ EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ !
$Log$Entry:  SUBROUTINE
$ ! P1 = Name of log-file (logical name or partial/full filespec)
$ ! P2 = Any text to write to log-file
$ ! P3 = Option ( DATA (D) | TEXT | COMMENT | [TIME|DATE]STAMP | SEPARATOR )
$ ! P4 = Indentation (number of characters to indent)
$ !
$ SET NOON
$ IF F$TRNLNM(P1) .EQS. "" THEN P1 = F$PARSE(P1,"sys$disk:[].data")
$ !
$ IF F$SEARCH(P1) .EQS. ""
$ THEN OFlag = "/WRITE"
$ ELSE OFlag = "/APPEND"
$ ENDIF
$ IF P3 .NES. "" 
$ THEN P3 = F$EXTRACT(0,4,F$EDIT(P3,"UPCASE,COLLAPSE"))
$ ELSE P3 = "DATA"
$ ENDIF
$ IF P4 .NES. ""
$ THEN Indent = F$INTEGER(P4)
$      IF Indent .LT. 0 THEN Indent = 0
$ ELSE Indent = 0
$ ENDIF
$ !
$ OPEN 'OFlag' /SHARE=READ LogF /ERROR=LE$FNF 'P1'
$ GOTO 'P3'$W
$ !
$TIME$W:  ![TIME|DATE]STAMP
$DATE$W:
$STAM$W:
$ UName = F$EDIT(F$GETJPI("","USERNAME"),"TRIM")
$ TStmp = F$CVTIME("","ABSOLUTE","DATE") + " at " -
        + F$CVTIME("","ABSOLUTE","HOUR") + ":" + F$CVTIME("","ABSOLUTE","MINUTE")
$ WRITE LogF F$FAO( "!#*= Entry by !12AS on !AS", Indent+4, UName, TStmp )
$ !
$DATA$W:  ![DATA|TEXT]
$TEXT$W:
$SEPA$W:  ![SEPARATOR]
$ ! (Note: outputs only 1 blank line if P2="" and P3="SEPARATOR")
$ IF ( P2 .NES. "" ) THEN WRITE LogF F$FAO( "!#* !AS", Indent, P2 )
$ IF ( P3 .EQS. "SEPA" ) THEN WRITE LogF ""
$ GOTO CloseIt
$ !
$COMM$W:
$ WRITE LogF F$FAO( "!#* Comment: ""!AS""", Indent+4, P2 )
$ !
$CloseIt:
$ IF F$TRNLNM("LogF","lnm$process") .NES. "" THEN CLOSE LogF
$ !
$ IF OFlag .EQS. "/WRITE" THEN SET SECURITY /PROT=(S:RWE,O:RWE,G,W) 'P1'
$ !
$ EXIT 1
$LE$FNF:
$ Stat = $STATUS
$ WRITE sys$output "%UTILITY-E-FNF, cannot open ""''P1'"" (in LogEntry)"
$ EXIT Stat .OR. %X10000000
$ ENDSUBROUTINE  ! Log$Entry
$ !
$ !
$ ! ------
$CHKBATLOG:
$ ! P2 = Name of batch log-file (logical name or partial/full filespec)
$ ! P3 = Version-limit for batch job's log-files
$ ! P4 = Notification names ("VMSName[,Name...]"or "SMART$System_Managers"),
$ !      but no notification if empty
$ ! P5 = Rename method: "I" (default, individual and calculated renames),
$ !                 or: "X" (crisscross, two bulk renames through a temp-spec)
$ !
$ SET NOON
$ Mode = F$MODE()
$ IF Mode .EQS. "BATCH"  !determine "this" job's entryno & log-file name
$ THEN EntryNo  = 0
$      LogFSpec = ""
$      EntryNo  = F$GETQUI( "DISPLAY_ENTRY", "ENTRY_NUMBER", , "THIS_JOB" )
$      LogNull  = F$GETQUI( "DISPLAY_ENTRY", "JOB_LOG_NULL", , "THIS_JOB" )
$      IF .NOT. LogNull
$      THEN LogFSpec = F$GETQUI( "DISPLAY_ENTRY", "LOG_SPECIFICATION", , "THIS_JOB" )
$           LogFSpec = F$PARSE(LogFSpec,P2)
$           FS       = F$SEARCH(LogFSpec)
$           LogFSVer = F$PARSE(FS,,,"VERSION","SYNTAX_ONLY")
$           FSVer = LogFSVer - ";"
$           FSVer = F$INTEGER(FSVer)
$           IF FSVer .GE. 32767        !time to reset version #'s ?
$           THEN SUBMIT site$utils:Util$Reset_File_Version /NOLOG -
                          /PARAMETERS=("''Mode'|''EntryNo'","''LogFSpec'","''P3'","''P5'")
$                IF P4 .NES. ""
$                THEN P4 = F$EDIT(P4,"COLLAPSE,UPCASE")
$                     IF P4 .EQS. "SMART$SYSTEM_MANAGERS"
$                     THEN CALL MailTo$Names "MailTo" "''P4'"
$                          P4 = 'util$fac'$MailTo
$                     ENDIF
$                     Msg = F$FAO("%UTILITY-I-RESET_FILE_VERSION, file versions for !AS!/ have been reset; please check this file-group",LogFSpec)
$                     MAIL _nla0: "''P4'" /SUBJECT="''Msg'"
$                ENDIF
$           ENDIF
$           'util$fac'$EntryNo  == EntryNo
$           'util$fac'$LogFSpec == LogFSpec
$           'util$fac'$LogFSVer == ";''FSVer'"
$      ENDIF
$ ELSE ! do nothing... and silently...
$      'util$fac'$EntryNo  == ""
$      'util$fac'$LogFSpec == ""
$      'util$fac'$LogFSVer == ""
$ ENDIF
$ !
$ EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ !
$ !
$ ! ------
$CHKFILEV:  !'F$VERIFY(0)'
$ ! P2 = Name of file to check (logical name or partial/full filespec)
$ ! P3 = Version-limit for file
$ ! P4 = Stall (in seconds SS or as "hh:mm:ss.cc"), delay before proceeding
$ !      with version-renumbering (allows current process to complete &
$ !      release any exclusive file-locks or other concurrent complications)
$ ! P5 = Notification names ("VMSName[,Name...]"or "SMART$System_Managers"),
$ !      but no notification if empty
$ ! P6 = Rename method: "I" (default, individual and calculated renames),
$ !                 or: "X" (crisscross, two bulk renames through a temp-spec)
$ !
$ SET NOON
$ Stat  = 1
$ Mode  = F$MODE()
$ FSpec = F$SEARCH(P2)
$ FSVer = F$PARSE(FSpec,,,"VERSION","SYNTAX_ONLY")
$ FSVer = FSVer - ";"
$ FSVer = F$INTEGER(FSVer)
$ IF FSVer .GE. 32767        !time to reset version #'s ?
$ THEN @site$utils:Util$Reset_File_Version "''Mode'|''P4'" "''FSpec'" "''P3'" "''P6'"
$      Stat = $STATUS
$      IF P5 .NES. ""
$      THEN P5 = F$EDIT(P5,"COLLAPSE,UPCASE")
$           IF P5 .EQS. "SMART$SYSTEM_MANAGERS"
$           THEN CALL MailTo$Names "MailTo" "''P5'"
$                P5 = 'util$fac'$MailTo
$           ENDIF
$           Msg = F$FAO("%UTILITY-I-RESET_FILE_VERSION, file versions for !AS!/ have been reset; please check this file-group",FSpec)
$           MAIL _nla0: "''P5'" /SUBJECT="''Msg'"
$      ENDIF
$ ENDIF
$ !
$ 'util$fac'$FSpec == FSpec
$ 'util$fac'$FSVer == ";''FSVer'"
$ !
$ EXIT (Stat .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ !
$ !
$ ! ------
$RAPT$P0:
$ SET NOON
$ IF P2 .NES. "" THEN CALL RAPT$Parse_Parameters "''P2'"
$ IF P3 .NES. "" THEN CALL RAPT$Parse_Parameters "''P3'"
$ EXIT 1 + F$VERIFY(util$ver) * 0
$ !
$RAPT$Parse_Parameters:  SUBROUTINE
$ ON ERROR THEN EXIT %X2C
$ IF F$EXTRACT(0,1,P1) .EQS. "@"
$ THEN P1 = P1 - "@"
$      IF P1 .EQS. "" THEN P1 = "NOFILENAME"
$      OPEN /READ /ERROR=RAPT$P_Error Parse$F 'P1'
$L1:   READ /END_OF_FILE=RAPT$P_Done Parse$F Parse$P0
$      F_'F$ELEMENT(0,"=",Parse$P0)' == "''F$ELEMENT(1,"=",Parse$P0)'"
$      GOTO L1
$ ELSE IF P1 .NES. ""
$      THEN P = 0
$L2:        Parse$P0 = F$ELEMENT(P,"|",P1)
$           IF Parse$P0 .NES. "|"
$           THEN P = P + 1
$                F_'F$ELEMENT(0,"=",Parse$P0)' == "''F$ELEMENT(1,"=",Parse$P0)'"
$                GOTO L2
$           ENDIF
$      ENDIF
$ ENDIF
$RAPT$P_Done:
$ SET NOON
$ IF F$TRNLNM("Parse$F") .NES. "" 
$ THEN CLOSE Parse$F
$      DELETE 'P1'
$ ENDIF
$ EXIT 1
$RAPT$P_Error:
$ Stat = $STATUS
$ WRITE sys$error F$FAO(F$MESSAGE(UTIL_FILNOTFND),P1)
$ EXIT 'Stat'
$ENDSUBROUTINE
$ !
$ !
$ ! ------
$RDBVERSION:
$ ! P2 = Rdb version to report availability (sets Boolean RDB_V'P2')
$ ! P3 = optional "SHOW" to show Rdb versions available
$ !
$ ON ERROR THEN EXIT ($STATUS .OR. %X10000000)
$ util$status = $STATUS
$ ! This slightly-kludgy method allows non-priv'd users (and priv'd ones too)
$ !  to determine which version(s) of multiversion Oracle/Rdb are currently
$ !  running/available.  Method is to use SMART's WHO.EXE utility (which is
$ !  installed as a WORLD-privileged known image; using DCL lexicals to
$ !  determine this would limit this function to priv'd users only!) to dump
$ !  a temp-file listing of F$MODE=OTHER processes, which is then searched
$ !  for processes named "RDMS_MONITOR*", where the "*" is either "" or is
$ !  version-digits like "70", "71", etc.
$ !
$ ! Results are returned in two global symbols:
$ !  1) RDB_AVAILABLE is a string containing one or more version-id's, one
$ !     each for each version of Rdb which is available (comma separated).
$ !  2) RDB_V'P2' is a Boolean ("YES" or "NO") indicating the availability
$ !     of the Rdb version named as P2.
$ !
$ RDB_AVAILABLE == ""
$ RMon = "RDMS_MONITOR"
$ P2 = F$ELEMENT(0,"-",P2)      ! strip "-nn" from "V7.X-nn"
$ P2 = P2 - "V" - "v" - "."     ! and strip "[V|v]." leaving "7X"
$ RDB_V'P2' == "NO"
$ Tmp = "sys$scratch:util$rdbversion.tmp"
$ WHO = "$site$utils:who"       ! guard against symbol redefinition
$ WHO /OTHER /PROCESS /OUTPUT='Tmp'
$ OPEN /READ /ERROR=RFileError f 'Tmp'
$RVL0:
$ READ /END_OF_FILE=RVL1 f Line
$ Line = F$EDIT(Line,"COMPRESS,TRIM,UPCASE")
$ IF Line .NES. ""
$ THEN PrcNam = F$ELEMENT(3," ",Line)
$      IF F$LOCATE(RMon,PrcNam) .LT. F$LENGTH(PrcNam)
$      THEN RdbV = PrcNam - RMon
$           IF RdbV .EQS. "" THEN RdbV = "70"
$           RdbVStr = "V" + F$EXTRACT(0,1,RdbV) + "." + F$EXTRACT(1,1,RdbV)
$           IF RDB_AVAILABLE .EQS. ""
$           THEN RDB_AVAILABLE == RdbVStr
$           ELSE ! On a cluster, will have multiple instances of each
$                ! RDMS_MONITOR version, so report each version only once:
$                IF F$LOCATE(RdbVStr,RDB_AVAILABLE) .EQ. F$LENGTH(RDB_AVAILABLE)
$                THEN RDB_AVAILABLE == RDB_AVAILABLE + "," + RdbVStr
$                ENDIF
$           ENDIF
$           IF RdbV .EQS. P2 THEN RDB_V'P2' == "YES"
$      ENDIF
$ ENDIF
$ GOTO RVL0
$RVL1:
$ CLOSE f
$ IF P3 .EQS. "SHOW" -
  THEN WRITE sys$output "[4mRdb versions available: ''RDB_AVAILABLE'[0m"
$ DELETE /NOLOG 'Tmp';*
$ EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ !
$RFileError:
$ WRITE sys$output "%UTILITY-F-RDBVERSION_OPENERR, cannot open ''Tmp'"
$ EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
$ !
$ !
$ ! ------
$FindProcess:
$ ! Given a ProcessName (P2), determine whether that process is actually
$ ! running, return that process name or "" (not found) as 'fac'$'P3'.
$ !
$ ! P2 = Name of process to find
$ ! P3 = Symbol name for return value (as 'fac'$'P3'), default: "PName"
$ ! P4 = [ EXACT (D) | STARTING_WITH | CONTAINING ]
$ ! P5 = [ WORLD | GROUP ]  (no default; need WORLD to see all VMS processes)
$ !
$ ON ERROR THEN GOTO FPDone
$ P2  = F$EDIT(P2,"COMPRESS,TRIM,UPCASE")
$ P2L = F$LENGTH(P2)
$ IF P3 .EQS. "" THEN P3 = "PName"
$ IF P4 .EQS. ""
$ THEN P4 = "EXACT"
$ ELSE P4 = F$EDIT(F$EXTRACT(0,5,P4),"COMPRESS,TRIM,UPCASE")
$ ENDIF
$ IF P5 .NES. ""
$ THEN P5 = P5 - "(" - ")"
$      Prv = F$SETPRV(P5)
$ ENDIF
$ Ctx = ""
$ 'util$fac'$'P3' == ""
$ !
$L0:
$ Pid = F$PID(Ctx)
$ IF Pid .EQS. ""
$ THEN GOTO FPDone
$ ELSE PNam = F$EDIT(F$GETJPI(Pid,"PRCNAM"),"COMPRESS,TRIM,UPCASE")
$      Matched = 0
$      IF P4 .EQS. "EXACT" THEN Matched = ( PNam .EQS. P2 )
$      IF P4 .EQS. "START" THEN Matched = ( F$EXTRACT(0,P2L,PNam) .EQS. P2 )
$      IF P4 .EQS. "CONTA" THEN Matched = ( F$LOCATE(P2,PNam) .LT. F$LENGTH(PNam) )
$      IF Matched
$      THEN 'util$fac'$'P3' == PNam
$           GOTO FPDone
$      ELSE GOTO L0
$      ENDIF
$ ENDIF
$ !
$FPDone:
$ SET NOON
$ IF F$TYPE(Ctx) .EQS. "PROCESS_CONTEXT" -
  THEN Tmp = F$CONTEXT("PROCESS", Ctx, "CANCEL")
$ IF F$TYPE(Prv) .EQS. "STRING" THEN Prv = F$SETPRV(Prv)
$ EXIT ($STATUS .OR. %X10000000) + F$VERIFY(util$ver) * 0
