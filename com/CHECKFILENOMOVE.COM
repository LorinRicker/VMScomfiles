$ ! CHECKFILENOMOVE.COM --
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
$ !  usage: @CHECKFILENOMOVE [ disk-device: ] [ALL]
$ !
$ !  Using (borrowing) the same System File specifications used by
$ !  the VMS command file SYS$SYSTEM:SETFILENOMOVE.COM, check and
$ !  report those System Files which are (still) marked as "Moveable"
$ !  (SET FILE /MOVE rather than /NOMOVE), in violation of VMS's
$ !  policy/expectations for correct Disk Defragging (DFG).
$ !
$MoveAttr: SUBROUTINE
$ ! P1 : (wildcarded) file-spec to test
$ ! P2 : disk
$ ! P3 : "true" reports both disabled/enabled files,
$ !      otherwise enabled files only are reported
$ !
$ fs = F$PARSE(P1,P2,,,"SYNTAX_ONLY")
$ wild = F$LOCATE("*",fs) .LT. F$LENGTH(fs)
$ !
$ ena$msg = "!enabled"
$ dis$msg = "disabled"
$ unk$msg = "?unknown"
$ !
$L0:
$ ! Set trap for (almost always): %SYSTEM-W-ACCONFLICT, file access conflict --
$ ON WARNING THEN pipe -
    ( WRITE sys$output F$FAO( "  !AS - !AS (!AS)", unk$msg, fspec, "%SYSTEM-W-ACCONFLICT" ) ; -
      CONTINUE )
$ !
$ fspec = F$SEARCH(fs,1)
$ IF fspec .NES. ""
$ THEN mvcond = dis$msg    ! suppress system-noise about %SYSTEM-W-ACCONFLICT
$      SET MESSAGE /NOFACILITY /NOSEVERITY /NOIDENT /NOTEXT
$      Evaluated == Evaluated + 1
$      IF F$FILE_ATTRIBUTE(fspec,"MOVE") THEN mvcond = ena$msg
$      SET MESSAGE /FACILITY /SEVERITY /IDENT /TEXT
$      IF P3 .OR. ( mvcond .NES. dis$msg )
$      THEN wso F$FAO( "  !AS - !AS", mvcond, fspec )
$           Displayed == Displayed + 1
$      ENDIF
$      IF wild THEN GOTO L0  !'F$VERIFY(0)'
$ ENDIF
$ !
$ EXIT %X01
$ ENDSUBROUTINE
$ !
$ !
$ ! --- Main ----
$ ! P1 : disk (defaults to SYS$SYSDEVICE:)
$ ! P2 : ALL for both enabled/disabled file move-attrs
$ !
$ SET NOON
$ wso = "WRITE sys$output"
$ Displayed == 0
$ Evaluated == 0
$ !
$ IF P1 .EQS. "ALL"
$ THEN all = 1
$      P1 = "SYS$SYSDEVICE"
$ ELSE P1 = P2 - "/"
$      all = P2 .EQS. "ALL"
$ ENDIF
$ !
$ IF P1 .EQS. "" THEN P1 = "SYS$SYSDEVICE"
$ P1 = P1 - ":" + ":"
$ !
$ wso ""
$ wso " Move Attr - File on ''P1'"
$ wso "--------------------------------------------------------------------------------"
$ !
$ CALL MoveAttr "<000000>000000.DIR;1"                          "''P1'" "''all'"
$ CALL MoveAttr "<000000>SYS*.DIR;1"                            "''P1'" "''all'"
$ CALL MoveAttr "<000000>VMS$COMMON.DIR;1"                      "''P1'" "''all'"
$ CALL MoveAttr "<SYS*>*.DIR;1"                                 "''P1'" "''all'"
$ CALL MoveAttr "<VMS$COMMON>*.DIR;1"                           "''P1'" "''all'"
$ CALL MoveAttr "<000000>QUORUM.DAT;0"                          "''P1'" "''all'"
$ CALL MoveAttr "<SYS*.SYS$LDR>*.EXE;0"                         "''P1'" "''all'"
$ CALL MoveAttr "<VMS$COMMON.SYS$LDR>*.EXE;0"                   "''P1'" "''all'"
$ CALL MoveAttr "<SYS*.SYSEXE>CLUSTER_AUTHORIZE.DAT;0"          "''P1'" "''all'"
$ CALL MoveAttr "<VMS$COMMON.SYSEXE>CLUSTER_AUTHORIZE.DAT;0"    "''P1'" "''all'"
$ CALL MoveAttr "<SYS*.SYSEXE>SYS$INCARNATION.DAT;0"            "''P1'" "''all'"
$ CALL MoveAttr "<VMS$COMMON.SYSEXE>SYS$INCARNATION.DAT;0"      "''P1'" "''all'"
$ CALL MoveAttr "<SYS*.SYSEXE>LOGINOUT.EXE;0"                   "''P1'" "''all'"
$ CALL MoveAttr "<VMS$COMMON.SYSEXE>LOGINOUT.EXE;0"             "''P1'" "''all'"
$ CALL MoveAttr "<SYS*.SYSEXE>PAGEFILE.SYS;0"                   "''P1'" "''all'"
$ CALL MoveAttr "<VMS$COMMON.SYSEXE>PAGEFILE.SYS;0"             "''P1'" "''all'"
$ CALL MoveAttr "<SYS*.SYSEXE>STABACKUP.EXE;0"                  "''P1'" "''all'"
$ CALL MoveAttr "<VMS$COMMON.SYSEXE>STABACKUP.EXE;0"            "''P1'" "''all'"
$ CALL MoveAttr "<SYS*.SYSEXE>STACONFIG.EXE;0"                  "''P1'" "''all'"
$ CALL MoveAttr "<VMS$COMMON.SYSEXE>STACONFIG.EXE;0"            "''P1'" "''all'"
$ CALL MoveAttr "<SYS*.SYSEXE>SWAPFILE.SYS;0"                   "''P1'" "''all'"
$ CALL MoveAttr "<VMS$COMMON.SYSEXE>SWAPFILE.SYS;0"             "''P1'" "''all'"
$ CALL MoveAttr "<SYS*.SYSEXE>SYSBOOT.EXE;0"                    "''P1'" "''all'"
$ CALL MoveAttr "<VMS$COMMON.SYSEXE>SYSBOOT.EXE;0"              "''P1'" "''all'"
$ CALL MoveAttr "<SYS*.SYSEXE>SYSDUMP.DMP;0"                    "''P1'" "''all'"
$ CALL MoveAttr "<VMS$COMMON.SYSEXE>SYSDUMP.DMP;0"              "''P1'" "''all'"
$ CALL MoveAttr "<SYS*.SYSEXE>*.PAR;0"                          "''P1'" "''all'"
$ CALL MoveAttr "<VMS$COMMON.SYSEXE>*.PAR;0"                    "''P1'" "''all'"
$ CALL MoveAttr "<SYS*.SYSEXE>APB.EXE;0"                        "''P1'" "''all'"
$ CALL MoveAttr "<VMS$COMMON.SYSEXE>APB.EXE;0"                  "''P1'" "''all'"
$ CALL MoveAttr "<SYS*.SYSLDR>SYS$EFI.SYS;0"                    "''P1'" "''all'"
$ CALL MoveAttr "<VMS$COMMON.SYSLDR>SYS$EFI.SYS;0"              "''P1'" "''all'"
$ CALL MoveAttr "<SYS*.SYSMSG>SYSMSG.EXE;0"                     "''P1'" "''all'"
$ CALL MoveAttr "<VMS$COMMON.SYSMSG>SYSMSG.EXE;0"               "''P1'" "''all'"
$ !
$ wso "--------------------------------------------------------------------------------"
$ wso F$FAO( "Displayed !ZL out of !ZL file!%S", Displayed, Evaluated )
$ wso ""
$ !
$Quit:
$ DELETE /SYMBOL /GLOBAL Evaluated
$ DELETE /SYMBOL /GLOBAL Displayed
$ EXIT %X01
