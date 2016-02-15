$ ! VAST_SHARED.COM --                                            'F$VERIFY(0)'
$ !
$ !  @VAST_SHARED [called_routine]
$ !
$ ! Copyright (C) 2012-2013 Lorin Ricker <lorin@rickernet.us>
$ ! Version: 2.0, 05/17/2013
$ !
$ ! This program is free software, under the terms and conditions of the
$ ! GNU General Public License published by the Free Software Foundation.
$ !
$ ! --------
$FileSpecDQ:  SUBROUTINE
$ ! P1 : subdirectory name
$ ! P2 : file's "FNAME.EXT"
$ ! P3 : global symbol name to return, excluding "FNAME.EXT"
$ ! P4 : global symbol name to return, including "FNAME.EXT"
$ !
$ IF AUD$ACStr .NES. ""
$ THEN acstr = """''AUD$ACStr'"""
$ ELSE acstr = ""
$ ENDIF
$ DDQ     = DQUOTE + DQUOTE
$ Dir     = AUD$Dir - "]" + DOT + P1 + "]"
$ DirDQ   = AUD$RNode + DDQ + acstr + DDQ + "::" + AUD$Dev + Dir
$ Dir     = AUD$RNode + acstr + "::" + AUD$Dev + Dir
$ 'P3'   == Dir
$ 'P3'DQ == DirDQ
$ 'P4'   == Dir   + P2
$ 'P4'DQ == DirDQ + P2
$ IF Debugging
$ THEN txt = "FILESPECDQ, generated"
$      wserr F$FAO( "%!AS-I-!AS !AS!/!8* == ""!AS""",   Fac, txt, P3, 'P3' )
$      wserr F$FAO( "%!AS-I-!AS !ASDQ!/!8* == ""!AS""", Fac, txt, P3, 'P3'DQ )
$      wserr F$FAO( "%!AS-I-!AS !AS!/!8* == ""!AS""",   Fac, txt, P4, 'P4' )
$      wserr F$FAO( "%!AS-I-!AS !ASDQ!/!8* == ""!AS""", Fac, txt, P4, 'P4'DQ )
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! FileSpecDQ
$ ! --------
$ !
$ ! --------
$CheckAndCreateSubDir:  SUBROUTINE
$ ! P1 : Name of subdirectory to check/create
$ ! P2 : Name of top-directory path in which to check/create subdirectory
$ !
$ ON CONTROL_Y THEN GOSUB CCSBCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ IF P2 .EQS. ""
$ THEN rootdirn = AUD$Dir
$ ELSE rootdirn = P2
$ ENDIF
$ rootdirn = rootdirn - "[" - "]"
$ !
$ ! Conditionally create a [.''P1'] subdirectory:
$ SubDirStat = %X1
$ IF Debugging THEN wserr "AUD$Dir: ""''AUD$Dir'"" -- rootdirn: ""''rootdirn'"""
$ IF AUD$Dir .EQS. "[''rootdirn']"
$ THEN tdir = AUD$NodeAcc + AUD$Dev + "[" + rootdirn + "." + P1 + "]"
$      IF Debugging THEN wserr F$FAO( "%!AS-I-PATH, statistics directory is !AS", Fac, tdir )
$      IF F$SEARCH("''AUD$PathAccDQ'''P1'.DIR") .EQS. ""
$      THEN CREATE /DIRECTORY /OWNER=PARENT /PROT=(S:RWE,O:RWE,G:RWE,W:RE) /LOG 'tdir'
$           SubDirStat = $STATUS
$      ENDIF
$ ELSE SubDirStat = %X1001C04A    !%RMS-E-DNF, directory not found
$ ENDIF
$ EXIT 'SubDirStat'
$ !
$CCSBCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! CheckAndCreateSubDir
$ ! --------
$ !
$ !
$ ! --------
$FindIDOSD:  SUBROUTINE
$ IF F$TRNLNM("AUD$IDOSD","LNM$PROCESS") .NES. "" THEN EXIT %X1
$ !
$ ON CONTROL_Y THEN GOSUB SCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ slist = ""
$ tmpfile = "SYS$DISK:[]VAST_temp.txt"
$ SHOW LOGICAL /SYSTEM DISK$IDOSD* /OUTPUT='tmpfile'
$ OPEN /ERROR=TmpOpenErr /READ tmp 'tmpfile'
$F0:
$ READ /END_OF_FILE=CloseTmp tmp line
$ line = F$EDIT(line,"TRIM,COMPRESS")
$ IF line .EQS. "" THEN GOTO F0                  !skip empty
$ IF F$EXTRACT(0,1,line) .EQS. "(" THEN GOTO F0  !skip "(LNM$SYSTEM_TABLE)", etc.
$ lnm = F$ELEMENT(0,SPC,line) - DQUOTE - DQUOTE
$ IF slist .NES. ""
$ THEN slist = slist + COMMA + lnm
$ ELSE slist = lnm
$ ENDIF
$ GOTO F0
$ !
$CloseTmp:
$ IF F$TRNLNM("tmp") .NES. "" THEN CLOSE /DISPOSITION=DELETE tmp
$ !
$ IF slist .NES. "" THEN DEFINE /PROCESS /SUPERVISOR /NOLOG AUD$IDOSD 'slist'
$ !
$ EXIT 1
$ !
$SCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! FindIDOSD
$ ! --------
$ !
$ ! --------
$FindPageSwap:  SUBROUTINE
$ IF F$TRNLNM("AUD$IPAGESWAP","LNM$PROCESS") .NES. "" THEN EXIT %X1
$ !
$ ON CONTROL_Y THEN GOSUB SCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ slist = ""
$ tmpfile = "SYS$DISK:[]VAST_temp.txt"
$ !
$ i = "I"  ! try "DISK$IPAGESWAP*" first...
$ !
$FPS:
$ SHOW LOGICAL /SYSTEM DISK$'i'PAGESWAP* /OUTPUT='tmpfile'
$ OPEN /ERROR=TmpOpenErr /READ tmp 'tmpfile'
$F0:
$ READ /END_OF_FILE=CloseTmp tmp line
$ line = F$EDIT(line,"TRIM,COMPRESS")
$ IF line .EQS. "" THEN GOTO F0                  !skip empty
$ IF F$EXTRACT(0,1,line) .EQS. "(" THEN GOTO F0  !skip "(LNM$SYSTEM_TABLE)", etc.
$ lnm = F$ELEMENT(0,SPC,line) - DQUOTE - DQUOTE
$ IF slist .NES. ""
$ THEN slist = slist + COMMA + lnm
$ ELSE slist = lnm
$ ENDIF
$ GOTO F0
$ !
$CloseTmp:
$ IF F$TRNLNM("tmp") .NES. "" THEN CLOSE /DISPOSITION=DELETE tmp
$ !
$ IF i .NES. ""  ! already tried "DISK$IPAGESWAP*", now try "DISK$PAGESWAP*"...
$ THEN i = ""
$      GOTO FPS
$ ENDIF
$ !
$ IF slist .NES. "" THEN DEFINE /PROCESS /SUPERVISOR /NOLOG AUD$IPAGESWAP 'slist'
$ !
$ EXIT 1
$ !
$SCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! FindPageSwap
$ ! --------
$ !
$ !
$ ! === Main ===
$Main:
$ ON CONTROL THEN GOSUB SRCtrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Stat = %X1
$ IF P1 .NES. ""
$ THEN CALL 'P1' "''P2'" "''P3'" "''P4'" "''P5'" "''P6'" "''P7'" "''P8'"
$      Stat = $STATUS
$ ENDIF
$ !
$Done:
$ EXIT 'Stat'
$ !
$SRCtrl_Y:
$ RETURN %X2C
