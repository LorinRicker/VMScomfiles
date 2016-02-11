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
$ CALL CDefine "chk"          "@site$utils:file$compare"
$ IF F$TYPE(chk) .EQS. "STRING" -
  THEN chk == chk - ".COM" - " CHECK" + " CHECK"
$ CALL CDefine "comp*are"     "@site$utils:file$compare"
$ IF F$TYPE(compare) .EQS. "STRING" -
  THEN comp*are == compare - ".COM" - " COMPARE" + " COMPARE"
$ CALL CDefine "wildcomp*are" "@site$utils:file$wildcomp"
$ CALL CDefine "frep*lace"    "@site$utils:file$edit"
$ IF F$TYPE(freplace) .EQS. "STRING" -
  THEN frep*lace == freplace - ".COM" - " FINDREPLACE" + " FINDREPLACE"
$ CALL CDefine "chop"         "$site$utils:chop"
$ CALL CDefine "clean*up"     "@site$utils:file$cleanup"
$ CALL CDefine "cros*scheck"  "@site$utils:file$crosscheck"
$ CALL CDefine "csum"         "@site$utils:file$checksum"
$ CALL CDefine "fat*tributes" "@site$utils:file$attributes"
$ CALL CDefine "fcom*pare"    "@site$utils:file$compare"
$ CALL CDefine "fcou*nt"      "$site$utils:filecount"
$ CALL CDefine "fid"          "@site$utils:file$fid"
$ CALL CDefine "fix"          "@site$utils:file$edit"
$ CALL CDefine "fli*st"       "@site$utils:file$preplist"
$ CALL CDefine "fsec*urity"   "@site$utils:file$security"
$ CALL CDefine "mov*e"        "@site$utils:file$move"
$ CALL CDefine "ofil*es"      "@site$utils:file$openfiles"
$ CALL CDefine "prot*ect"     "@site$utils:file$protect"
$ CALL CDefine "repl*ace"     "@site$utils:file$replace"
$ CALL CDefine "rev*ersion"   "@site$utils:file$reversion"
$ CALL CDefine "slice"        "$site$utils:slice"
$ CALL CDefine "spray"        "@site$utils:file$spray"
$ CALL CDefine "sscon*vert"   "@site$utils:file$ssconvert"
$ CALL CDefine "tail"         "$site$utils:tail"
$ CALL CDefine "tool*sdebug"  "@site$utils:tools$debug"
$ CALL CDefine "untang*le"    "@site$utils:file$untangle"
$ CALL CDefine "xf*r"         "@site$utils:file$xfer"
$ CALL CDefine "xftp"         "@site$utils:file$ftp"
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
