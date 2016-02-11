$ ! FILE$FTP.COM -- Smart(er) interface to FTP                     'F$VERIFY(0)'
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
$ !  Use:  @FILE$FTP [ source_file >remote_dest
$ !                    | source_file target_file
$ !                    | # (reset and exit)
$ !                    | -nodename (interactive) ] [ /RESET | /NODE=nodename ]
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ wso = "WRITE sys$output"
$ DD  = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(DD,,,"NAME","SYNTAX_ONLY")
$ DD  = F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ priv = F$SETPRV("SYSPRV")
$ !
$ IF P1 .EQS. "#"
$ THEN CALL Forget
$      GOTO Done      !...and do nothing else, just exit
$ ENDIF
$ !
$ Interactive = ( F$EXTRACT(0,1,P1) .EQS. "-" )
$ IF Interactive
$ THEN FTP$Node == P1 - "-"
$ ENDIF
$ IF P2 .NES. "" THEN FTP$Dest == P2
$ P0 = P1 + P2 + P3 + P4 + P5 + P6 + P7 + P8
$ IF F$LOCATE("/RESET",P0) .LT. F$LENGTH(P0)
$ THEN DELETE /SYMBOL /GLOBAL FTP$User         !force Fencrypt dialog screen
$      DELETE /SYMBOL /GLOBAL FTP$Pwd
$      DELETE /SYMBOL /GLOBAL FTP$Node
$ ENDIF
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ !
$ FTPsysfile = F$SEARCH("sys$system:*$ftp.exe")
$ IF FTPsysfile .EQS. "" THEN GOTO NoFTP
$ IF Verbose THEN wso "%''Fac'-E-FNF, FTP system utility is ''FTPsysfile'"
$ !
$ IF F$TYPE(FTP$Node) .NES. "STRING" THEN FTP$Node == ""
$ IF F$SEARCH("''DD'ftp$encrypt.exe") .NES. ""
$ THEN Fencrypt = "$''DD'ftp$encrypt"
$ ELSE GOTO NoEncrypts
$ ENDIF
$ IF F$SEARCH("''DD'ftp$decrypt.exe") .NES. ""
$ THEN Fdecrypt = "$''DD'ftp$decrypt"
$ ELSE GOTO NoEncrypts
$ ENDIF
$ !
$ CALL CheckNode "TRUE"
$ !
$L0:
$ ON ERROR THEN GOTO Done
$ IF (F$TYPE(FTP$User) .NES. "STRING")    -
    .OR. (F$TYPE(FTP$Pwd) .NES. "STRING") -
    .OR. (FTP$Node .EQS. "")
$ THEN DEFINE /USER_MODE rmg$back rmg$back_rms
$      DEFINE /USER_MODE sys$input sys$command
$      Fencrypt /NOABOUT
$      GOTO L0         !loop & check again...
$ ENDIF
$ Fdecrypt /SYMBOLS=(FTP$Node,FTP$User,FTP$Pwd,FTP$P)
$ IF Verbose
$ THEN SHOW SYMBOL FTP$Node
$      SHOW SYMBOL FTP$User
$      SHOW SYMBOL FTP$Pwd
$      !!SHOW SYMBOL FTP$P
$ ENDIF
$ Stars = F$FAO("!''F$LENGTH(FTP$P)'**")  !string of len(pwd) of *'s
$ !
$ IF Interactive .OR ( P1 .EQS. "" )
$ THEN FTP = "FTP " + FTP$Node
$      IF Verbose THEN wso "$ FTP ''FTP$Node' /USERNAME=""''FTP$User'"" /PASSWORD=""''Stars'"""
$      ON ERROR THEN GOTO L1
$      DEFINE /USER_MODE sys$input sys$command
$      FTP /USERNAME="''FTP$User'" /PASSWORD="''FTP$P'"    !'F$VERIFY(0)'
$      GOTO Done
$L1:
$      IF $STATUS .EQ. %X1801818A
$      THEN CALL Forget
$           GOTO L0        !start/prompt over again...
$      ELSE GOTO Done
$      ENDIF
$ ENDIF
$ !
$ IF F$EXTRACT(0,1,P1) .EQS. "@" THEN GOTO IndirectSpec
$DirectSpec:
$ i = 0
$ F0 = "sys$disk:[]"
$DS0:
$ Fl = F$ELEMENT(i,",",P1)
$ IF Fl .EQS. "," THEN GOTO Done          !more files?
$ FS   = F$PARSE(Fl,F0,,,"SYNTAX_ONLY")   !expand w/sticky dev:[dir]
$ FLen = F$LENGTH(FS)
$ Wild = ( F$LOCATE("*",FS) .LT. FLen ) .OR. ( F$LOCATE("%",FS) .LT. FLen )
$ GotOne = 0
$DS1:
$ F0 = F$PARSE(Fl,F0,,"DEVICE","SYNTAX_ONLY") -  !save sticky dev:[dir]
     + F$PARSE(Fl,F0,,"DIRECTORY","SYNTAX_ONLY")
$ Fl = F$SEARCH(FS)
$ IF Fl .NES. ""
$ THEN CALL TheProcess "''Fl'" "''P2'"
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
$ CALL TheProcess "''Fl'" "''P2'"
$!===============
$ GOTO IS0
$ !
$IS1:
$ CLOSE f
$ !
$Done:                                                            !'F$VERIFY(0)'
$ Stat = $STATUS
$ IF F$TYPE(FTP$P)     .NES. "" THEN DELETE /SYMBOL /GLOBAL FTP$P
$ IF F$TYPE(FTP$Src)   .NES. "" THEN DELETE /SYMBOL /GLOBAL FTP$Src
$ IF F$TYPE(FTP$Tar)   .NES. "" THEN DELETE /SYMBOL /GLOBAL FTP$Tar
$ IF F$TYPE(FIL$XFile) .NES. "" THEN DELETE /SYMBOL /GLOBAL FIL$XFile
$ IF F$TYPE(priv) .EQS. "STRING" THEN priv = F$SETPRV("SYSPRV")
$ EXIT Stat
$ !
$NoEncrypts:
$ wso "%''Fac'-F-NO_COMPONENTS, missing support components FTP$Encrypt/Decrypt"
$ CALL Forget
$ GOTO Done
$ !
$NoFTP:
$ wso "%''Fac'-F-NOT_AVAIL, FTP is not available on this system"
$ GOTO Done
$ !
$FNF:
$ wso "%''Fac'-E-FNF, cannot find @-list ''Files'"
$ wso ""
$ wso "  Creating indirect @-list file ''Files'"
$ wso ""
$ GOTO MakeIndirect
$ !
$ !
$ !           ==========
$TheProcess:  SUBROUTINE
$ P1 = P1 - F$PARSE(P1,,,"VERSION")
$ IF Verbose THEN SHOW SYMBOL P1
$ IF Verbose THEN SHOW SYMBOL P2
$ CALL ParseFSpec "''P1'" "FTP$Src"
$ CALL ParseFSpec "''P2'" "FTP$Tar" "''P1'"
$ IF F$EXTRACT(0,1,P1) .NES. ">"   !source is not remote,
$ THEN IF F$SEARCH(P1) .EQS. ""    !so test local existence
$      THEN wso "%''Fac'-E-FNF, file ''P1' not found"
            GOTO TP0
$      ENDIF
$ ENDIF
$ IF Verbose THEN wso "$ COPY /FTP /LOG ",FTP$Src," ",FTP$TarS
$ COPY /FTP /LOG 'FTP$Src' 'FTP$Tar'                              !'F$VERIFY(0)'
$TP0:
$ EXIT 1
$ ENDSUBROUTINE  ! TheProcess
$ !
$ParseFSpec:  SUBROUTINE
$ SET NOON
$ Acc = """" + FTP$User + " " + FTP$P + """"
$ Aps = """" + FTP$User + " password" + """"
$ P1L = F$LENGTH(P1)
$ IF F$EXTRACT(0,1,P1) .EQS. ">"
$ THEN P1 = P1 - ">"
$      ! Inherit filename & type, but do *not* translate remote's logical (dir)
$      IF P3 .NES. "" THEN P1 = P1 + F$PARSE(P3,,,"NAME") + F$PARSE(P3,,,"TYPE")
$      T = FTP$Node + Acc + "::" + P1
$      FTP$TarS == FTP$Node + Aps + "::" + P1
$ ELSE X = F$LOCATE("::",P1)
$      IF X .LT. P1L
$      THEN T = F$EXTRACT(0,X,P1) + Acc + F$EXTRACT(X,P1L-X,P1)
$      ELSE T = P1
$      ENDIF
$ ENDIF
$ 'P2' == T
$ EXIT 1
$ ENDSUBROUTINE  ! ParseFSpec
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$CheckNode:  SUBROUTINE
$ ! P1 = TRUE: delete symbol FTP$Pwd; = FALSE: leave it be...
$ NLen = F$LENGTH(P0)
$ NPos = F$LOCATE("/NODE=",P0)
$ IF NPos .LT. NLen
$ THEN P0 = F$EXTRACT(NPos,NLen-NPos,P0)
$      P0 = F$ELEMENT(0," ",P0)
$      Nd = F$ELEMENT(1,"=",P0)
$      IF Verbose .AND. ( F$TYPE(FTP$Node) .EQS. "STRING" )
$      THEN IF FTP$Node .NES. Nd THEN wso "%''Fac'-I-NODE_OVERRIDE, node ''FTP$Node' superceded by command-line /NODE=''Nd'"
$      ENDIF
$      FTP$Node == Nd
$      IF P1 .AND. ( F$TYPE(FTP$Pwd) .NES. "" )
$      THEN DELETE /SYMBOL /GLOBAL FTP$Pwd
$      ENDIF
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! CheckNode
$ !
$Forget:  SUBROUTINE
$ wso "%''Fac'-I-RESET, FTP values forgotten"
$ IF F$TYPE(FTP$User) .NES. "" THEN DELETE /SYMBOL /GLOBAL FTP$User
$ IF F$TYPE(FTP$Pwd)  .NES. "" THEN DELETE /SYMBOL /GLOBAL FTP$Pwd
$ IF F$TYPE(FTP$P)    .NES. "" THEN DELETE /SYMBOL /GLOBAL FTP$P
$ IF F$TYPE(FTP$TarS) .NES. "" THEN DELETE /SYMBOL /GLOBAL FTP$TarS
$ IF F$TYPE(FTP$Dest) .NES. "" THEN DELETE /SYMBOL /GLOBAL FTP$Dest
$ ! ...but don't erase FTP$Node...
$ EXIT 1
$ ENDSUBROUTINE  ! Forget
