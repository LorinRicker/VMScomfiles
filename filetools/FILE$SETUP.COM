$ ! FILE$SETUP.COM --                                              'F$VERIFY(0)'
$ !
$ ! Copyright © 1999-2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$Main:
$ SET NOON
$ wso = "WRITE sys$output"
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ Redefine = ( F$EXTRACT(0,2,P1) .EQS. "RE" )  !REDEFINE, REFRESH, RE-whatever
$ FILE$Unavailable == ""
$ !
$ DCL$CALL Alias "chk"          "@com:file$compare"
$ IF F$TYPE(chk) .EQS. "STRING" -
  THEN chk == chk - ".COM" - " CHECK" + " CHECK"
$ DCL$CALL Alias "comp*are"     "@com:file$compare"
$ IF F$TYPE(compare) .EQS. "STRING" -
  THEN comp*are == compare - ".COM" - " COMPARE" + " COMPARE"
$ DCL$CALL Alias "wildcomp*are" "@com:file$wildcomp"
$ DCL$CALL Alias "frep*lace"    "@com:file$edit"
$ IF F$TYPE(freplace) .EQS. "STRING" -
  THEN frep*lace == freplace - ".COM" - " FINDREPLACE" + " FINDREPLACE"
$ DCL$CALL Alias "chop"         "$com:chop"
$ DCL$CALL Alias "clean*up"     "@com:file$cleanup"
$ DCL$CALL Alias "cros*scheck"  "@com:file$crosscheck"
$ DCL$CALL Alias "csum"         "@com:file$checksum"
$ DCL$CALL Alias "fat*tributes" "@com:file$attributes"
$ DCL$CALL Alias "fcom*pare"    "@com:file$compare"
$ DCL$CALL Alias "fcou*nt"      "$com:filecount"
$ DCL$CALL Alias "fid"          "@com:file$fid"
$ DCL$CALL Alias "fix"          "@com:file$edit"
$ DCL$CALL Alias "fli*st"       "@com:file$preplist"
$ DCL$CALL Alias "fsec*urity"   "@com:file$security"
$ DCL$CALL Alias "mov*e"        "@com:file$move"
$ DCL$CALL Alias "ofil*es"      "@com:file$openfiles"
$ DCL$CALL Alias "prot*ect"     "@com:file$protect"
$ DCL$CALL Alias "repl*ace"     "@com:file$replace"
$ DCL$CALL Alias "rev*ersion"   "@com:file$reversion"
$ DCL$CALL Alias "slice"        "$com:slice"
$ DCL$CALL Alias "spray"        "@com:file$spray"
$ DCL$CALL Alias "sscon*vert"   "@com:file$ssconvert"
$ DCL$CALL Alias "tail"         "$com:tail"
$ DCL$CALL Alias "tool*sdebug"  "@com:tools$debug"
$ DCL$CALL Alias "untang*le"    "@com:file$untangle"
$ DCL$CALL Alias "xf*r"         "@com:file$xfer"
$ DCL$CALL Alias "xftp"         "@com:file$ftp"
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
