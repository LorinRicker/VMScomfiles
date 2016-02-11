$ ! SDL.COM -- recreates Pascal/VMS System Support Routines from
$ !            SYS$LIBRARY:STARLETSD.TLB; uses unsupported VMS
$ !            programs SYS$SYSTEM:SDLNPARSE.EXE (VMS distribution)
$ !            and SDLPASCAL.EXE (PASCAL distribution).
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
$ !            Recipe (dis/re)covered in KITINSTAL for PASSTR03x.
$ !            Permits replacement of huge SYS$LIBRARY:STARLET.(PAS/PEN)
$ !            files which are kept around for routine development...
$ !            Instead, generate modules only as needed from VMS's master
$ !            program development database.
$ !
$ !  use:  @SDL module_name [language] [-CHSV]
$ !
$ SDL  = "SDL"
$ DEFINE /JOB /NOLOG sys$library -
    'F$TRNLNM("sys$library"),sys$user1:[sys0.syslib]
$ IF F$TRNLNM("sdl$library") .EQS. "" -
  THEN  DEFINE /JOB /NOLOG sdl$library sys$library:starletsd.tlb
$ IF ( F$EXTRACT(0,2,p1) .EQS. "-H" ) -
  THEN  GOTO help
$ IF p1 .EQS. ""                     -
  THEN  READ /END_OF_FILE=done       -
             /PROMPT="module name? " -
             sys$command p1
$ fl = F$PARSE(p1,"sys$disk:[].txt",,,"SYNTAX_ONLY")
$ fl = fl - F$PARSE(fl,,,"TYPE","SYNTAX_ONLY")     -
          - F$PARSE(fl,,,"VERSION","SYNTAX_ONLY")
$ IF F$EXTRACT(0,1,p2) .NES. "-" -
  THEN  GOTO C0
$ p3 = p2
$ p2 = ""
$C0:
$ cmpr = F$LOCATE("C",p3) .LT. F$LENGTH(p3)
$ horz = F$LOCATE("H",p3) .LT. F$LENGTH(p3)
$ strp = F$LOCATE("S",p3) .LT. F$LENGTH(p3)
$ vert = F$LOCATE("V",p3) .LT. F$LENGTH(p3)
$ !
$ sep  = ","  !selection based on user input
$ abrs = ",ADA,BAS,BLI,C  ,COB,FOR,MAC,PAS,PLI,"  !3-chars each element
$ lans = ",ADA,BASIC,BLISS,C,COBOL,FORTRA,MACRO,PASCAL,PLI,"
$ xtns = ",ADA,BAS,B32,C,COB,FOR,MAR,PAS,PLI,"
$ p2   = F$PARSE(p2,"PAS",,"NAME","SYNTAX_ONLY")  !default "PAS" if p2 null;
$ IF p2 .EQS. "MAR" THEN p2 = "MAC"               !alias "MACRO";
$ lng  = F$FAO("!3AS",F$EXTRACT(0,3,p2))          !blank pad "C  "
$ idx  = ( F$LOCATE(lng,abrs) / 4 ) + 1
$ IF ( idx .LE. 0 ) .OR. ( idx .GT. (F$LENGTH(abrs)/4) ) -
  THEN  GOTO lng_err
$ ext  = F$ELEMENT(idx,sep,xtns)
$ lng  = F$ELEMENT(idx,sep,lans)
$ !
$ ON ERROR THEN GOTO done
$ LIBRARY /TEXT /EXTRACT='p1' /OUTPUT=sys$scratch:'p1'.sdi sdl$library
$ DEFINE /USER_MODE sdl$share sys$library
$ ON ERROR THEN GOTO D0
$ SDL /NOPARSE /NOHEADER /VMS /LANGUAGE=('lng'='fl') sys$scratch:'p1'
$ IF strp -
  THEN  CALL Filter uncomment 'fl'.'ext'    !strips source comments
$ IF cmpr .OR. horz -
  THEN  CALL Filter hcompress 'fl'.'ext'    !compresses whitespace
$ IF cmpr .OR. strp .OR. vert -
  THEN  CALL Filter vcompress 'fl'.'ext'    !compresses blank lines
$ PURGE  'fl'.'ext'
$ WRITE sys$error "%SDL-S, module ''fl'.''ext' generated"
$D0:
$ DELETE sys$scratch:'p1'.sdi;0
$done:
$ EXIT %X10000001
$ !
$help:
$ sdl_help = "sys$scratch:sdl$libr.lis"
$ WRITE sys$error "%SDL-I, usage:  @SDL module_name [language] [-CHSV]"
$ WRITE sys$error ""
$ WRITE sys$error "        contents of ''F$TRNLNM("sdl$library")..."
$ WRITE sys$error ""
$ IF F$SEARCH(sdl_help) .EQS. "" -
  THEN  LIBRARY /TEXT /LIST='sdl_help' sdl$library
$ TYPE /PAGE 'sdl_help'
$ GOTO done
$ !
$lng_err:
$ WRITE sys$error "%SDL-E, language ''p2' not supported"
$ GOTO done
$ !
$ Filter:  SUBROUTINE
$ EDIT = "EDIT"
$ DEFINE /USER_MODE sys$error  nla0:  !hide "%TPU-S-FILEIN/OUT" noise
$ DEFINE /USER_MODE sys$output nla0:
$ EDIT /TPU /NOSECTION /NODISPLAY /COMMAND=ked$utils:'p1' 'p2'
$ EXIT
$ ENDSUBROUTINE
