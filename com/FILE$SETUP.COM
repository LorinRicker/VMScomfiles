$ ! FILE$SETUP.COM --                                              'F$VERIFY(0)'
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
$ !    use:  @FILE$SETUP [ REDEFINE | REFRESH ]
$ !
$CDefine:  SUBROUTINE
$ IF F$LOCATE("*",P1) .LT. F$LENGTH(P1)
$ THEN AbbrSym = F$ELEMENT(0,"*",P1)
$ ELSE AbbrSym = P1
$ ENDIF
$ FullSym = P1 - "*"
$ IF F$TYPE('AbbrSym') .EQS. "STRING"  !command symbol already exists?
$ THEN IF Redefine
$      THEN DELETE /SYMBOL /GLOBAL 'AbbrSym'
$           GOTO CDef1
$      ELSE IF Verbose THEN wso "%FILE$SETUP-W-NOREDEFINE, command symbol ""''P1'"" already exists"
$           EXIT 1
$      ENDIF
$ ENDIF
$CDef1:
$ P2 = F$EDIT(P2,"UPCASE")
$ IF F$EXTRACT(0,1,P2) .EQS. "$" THEN P2 = P2 - "$" - ".EXE" + ".EXE"
$ IF F$EXTRACT(0,1,P2) .EQS. "@" THEN P2 = P2 - "@" - ".COM" + ".COM"
$ IF F$SEARCH(P2) .NES. ""
$ THEN IF F$PARSE(P2,,,"TYPE","SYNTAX_ONLY") .EQS. ".EXE"
$      THEN 'P1' == "$''P2'"
$      ELSE 'P1' == "@''P2'"
$      ENDIF
$      IF Verbose THEN SHOW SYMBOL /GLOBAL 'FullSym'
$ ELSE IF FILE$Unavailable .EQS. ""
$      THEN FILE$Unavailable == FullSym
$      ELSE FILE$Unavailable == FILE$Unavailable + ", " + FullSym
$      ENDIF
$      IF Verbose THEN SHOW SYMBOL /LOCAL P1
$      IF Verbose THEN SHOW SYMBOL /LOCAL P2
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! CDefine
$ !
$Main:
$ SET NOON
$ wso = "WRITE sys$output"
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ Redefine = ( F$EXTRACT(0,2,P1) .EQS. "RE" )  !REDEFINE, REFRESH, RE-whatever
$ FILE$Unavailable == ""
$ !
$ CALL CDefine "chk"          "@com:file$compare"
$ IF F$TYPE(chk) .EQS. "STRING" -
  THEN chk == chk - ".COM" - " CHECK" + " CHECK"
$ CALL CDefine "comp*are"     "@com:file$compare"
$ IF F$TYPE(compare) .EQS. "STRING" -
  THEN comp*are == compare - ".COM" - " COMPARE" + " COMPARE"
$ CALL CDefine "wildcomp*are" "@com:file$wildcomp"
$ CALL CDefine "frep*lace"    "@com:file$edit"
$ IF F$TYPE(freplace) .EQS. "STRING" -
  THEN frep*lace == freplace - ".COM" - " FINDREPLACE" + " FINDREPLACE"
$ CALL CDefine "chop"         "$com:chop"
$ CALL CDefine "clean*up"     "@com:file$cleanup"
$ CALL CDefine "cros*scheck"  "@com:file$crosscheck"
$ CALL CDefine "csum"         "@com:file$checksum"
$ CALL CDefine "fat*tributes" "@com:file$attributes"
$ CALL CDefine "fcom*pare"    "@com:file$compare"
$ CALL CDefine "fcou*nt"      "$com:filecount"
$ CALL CDefine "fid"          "@com:file$fid"
$ CALL CDefine "fix"          "@com:file$edit"
$ CALL CDefine "fli*st"       "@com:file$preplist"
$ CALL CDefine "fsec*urity"   "@com:file$security"
$ CALL CDefine "mov*e"        "@com:file$move"
$ CALL CDefine "ofil*es"      "@com:file$openfiles"
$ CALL CDefine "prot*ect"     "@com:file$protect"
$ CALL CDefine "repl*ace"     "@com:file$replace"
$ CALL CDefine "rev*ersion"   "@com:file$reversion"
$ CALL CDefine "slice"        "$com:slice"
$ CALL CDefine "spray"        "@com:file$spray"
$ CALL CDefine "sscon*vert"   "@com:file$ssconvert"
$ CALL CDefine "tail"         "$com:tail"
$ CALL CDefine "tool*sdebug"  "@com:tools$debug"
$ CALL CDefine "untang*le"    "@com:file$untangle"
$ CALL CDefine "xf*r"         "@com:file$xfer"
$ CALL CDefine "xftp"         "@com:file$ftp"
$ !
$Done:
$ IF F$TYPE(FILE$Unavailable) .NES. ""
$ THEN IF FILE$Unavailable .NES. ""
$      THEN wso ""
$           wso "%FILE$SETUP-W-UNAVAIL, DCL command symbols unavailable during this session:"
$           SHOW SYMBOL /GLOBAL FILE$Unavailable
$           wso ""
$      ENDIF
$ ENDIF
$ EXIT
