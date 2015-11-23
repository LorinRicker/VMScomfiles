$ ! FILE$OPENFILES.COM --                                          'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1999-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  use:  @FILE$OPENFILES [Device] [Search_String [...] ]
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Verbose  = F$TRNLNM("Tools$Debug")
$ Prv      = F$SETPRV("SYSPRV,WORLD")
$ Fac      = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ wso      = "WRITE sys$output"
$ OutF     = "sys$scratch:" + Fac + ".tmp0"
$ SeaF     = "sys$scratch:" + Fac + ".tmp1"
$ DC$_DISK = 1
$ QMat     = ""
$ DefUName = F$EDIT(F$GETJPI("","USERNAME"),"COMPRESS,TRIM,UPCASE")
$ IF F$TRNLNM("disks$mounted") .NES. ""
$ THEN DefDev = "Disks$Mounted"
$ ELSE DefDev = F$PARSE("sys$disk",,,"DEVICE","SYNTAX_ONLY")
$ ENDIF
$ !
$ IF P1 .EQS. "?" THEN GOTO Help
$ !
$ TailFile = "site$utils:tail.exe"
$ IF F$SEARCH(TailFile) .NES. "" THEN tail = "$''TailFile'"
$ !
$ ! If P1 exists *and* is a disk-device, then check open-files on it;
$ ! otherwise, use the default device, and merge P1 into the search-string:
$ Dev = DefDev
$PLoop:
$ IF P1 .EQS. ""
$ THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="Disk-device <''DefDev'>? "
$      IF P1 .NES. ""
$      THEN Dev = P1
$      ELSE Dev = DefDev
$      ENDIF
$ ELSE Dev = P1
$ ENDIF
$ IF F$GETDVI(Dev,"EXISTS")
$ THEN IF F$GETDVI(Dev,"DEVCLASS") .EQ. DC$_DISK
$      THEN GOTO PCont
$      ELSE GOTO NotDisk
$      ENDIF
$ ELSE GOTO NotDisk
$ ENDIF
$NotDisk:
$ P2 = P1 + " " + P2  !If 1st arg is not a disk, just add it to P2...
$ P1 = ""             ! and force the Disk-device prompt
$ GOTO PLoop
$ !
$PCont:
$ P2 = F$EDIT(P2,"TRIM")
$ IF P2 .EQS. ""
$ THEN READ sys$command P2 /END_OF_FILE=Done /PROMPT="Search string <''DefUName'>? "
$      IF P2 .EQS. ""
$      THEN SStr = DefUName
$      ELSE SStr = P2
$      ENDIF
$ ELSE SStr = P2
$      i = 3
$PC1:
$      IF i .GT. 8 THEN GOTO PC2
$      IF F$EXTRACT(0,4,P'i') .EQS. "/MAT"
$      THEN QMat = P'i'    !let user say /MATCH=OR or /MATCH=AND (D)
$      ELSE IF P'i' .NES. "" THEN SStr = SStr + "," + P'i'
$      ENDIF
$      i = i + 1
$      GOTO PC1
$PC2:
$      SStr = F$EDIT(SStr,"TRIM")
$      IF ( F$LOCATE(",",SStr) .LT. F$LENGTH(SStr) ) .AND. ( QMat .EQS. "" )
$      THEN QMat = "/MATCH=AND"
$      ENDIF
$ ENDIF
$ !
$ Dev = Dev - ":"
$ !
$ IF Verbose
$ THEN SHOW SYMBOL Dev
$      SHOW SYMBOL SStr
$ ENDIF
$ !
$ MIndx = F$TRNLNM(Dev,,,,,"MAX_INDEX")
$ ! If Dev is *not* a logical, then MAX_INDEX returns "" (empty),
$ !  so force one iteration:
$ IF ( F$TYPE(MIndx) .EQS. "STRING" ) .AND. ( MIndx .EQS. "" )
$ THEN MIndx = 0
$ ENDIF
$ !
$ idx = 0
$L0:
$ IF idx .GT. MIndx THEN GOTO Done
$ NDev = F$TRNLNM(Dev,,idx)
$ IF NDev .EQS. "" THEN NDev = Dev
$ IF Verbose THEN wso "  NDev = ''NDev'  (iteration ''idx')"
$ CALL The_Process "''NDev'" "''SStr'"
$ idx = idx + 1
$ GOTO L0
$ !
$Done:
$ SET NOON
$ IF F$SEARCH(OutF) .NES. "" THEN DELETE /NOLOG 'OutF';*
$ IF F$SEARCH(SeaF) .NES. "" THEN DELETE /NOLOG 'SeaF';*
$ Prv = F$SETPRV(Prv)
$ EXIT
$ !
$The_Process:  SUBROUTINE
$ SET NOON
$ wso ""
$ wso F$FAO("%!AS-I-DEVICE, open file report for device [1m!AS[0m",Fac,NDev)
$ SHOW DEVICE /FILES /OUTPUT='OutF' 'NDev'
$ IF P2 .EQS. "*"
$ THEN TYPE 'OutF'
$ ELSE SEARCH /OUTPUT='SeaF' 'OutF' 'SStr' 'QMat' /HIGHLIGHT=BOLD
$      TYPE 'SeaF'
$ ENDIF
$ !
$ IF F$TYPE(tail) .EQS. "STRING"
$ THEN TAIL /NOOUTPUT /COUNT=LINES /SYMBOL=OFCount 'OutF'
$      OFCount = F$INTEGER(OFCount) - 2             !minus the two header lines
$      IF P2 .EQS. "*"
$      THEN wso F$FAO("%!AS-I-COUNT, !ZL open files on [1m!AS[0m",Fac,OFCount,NDev)
$      ELSE TAIL /NOOUTPUT /COUNT=LINES /SYMBOL=SFCount 'SeaF'
$           SFCount = F$INTEGER(SFCount)
$           wso F$FAO("%!AS-I-COUNT, !ZL matched file!%S (out of !ZL open) on [1m!AS[0m",Fac,SFCount,OFCount,NDev)
$           DELETE /SYMBOL /LOCAL SFCount
$      ENDIF
$      DELETE /SYMBOL /LOCAL OFCount
$ ENDIF
$ wso ""
$ EXIT 1
$ ENDSUBROUTINE  ! The_Process
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE sys$input /PAGE

  FILE$OPENFILES is a command procedure which displays open files on a
  per-disk and/or per-user basis, permitting you to determine and review
  which files are open, for which user(s) and on which disk(s).

  use:  @FILE$OPENFILES [Device] [ Search_String [...] [ /MATCH=[AND|OR] ] ]

  where:

    P1 is the disk device (physical name or logical name) on which you
    want to report open files.  By default, FILE$OPENFILES uses either
    the search-list logical name DISKS$MOUNTED (if it exists) or that
    of the current device (your SHOW DEFAULT device).

    P2 ... P8 are:  [1ma[0m) name(s) of users;  [1mb[0m) name(s) of directories;
    [1mc[0m) name(s) of programs;  or [1md[0m) any combination of these.
    Optionally, the last of these parameters can be the qualifier
    /MATCH=AND or /MATCH=OR to control the way that the SEARCH
    command searches for the string(s).  The search-string elements
    themselves can be separated either by commas "," or spaces " ".

  Examples:

    $ OFILES == "@site$utils:file$openfiles"

    $ OFILES sys$user1 b_bones            !Which files are open for user
                                          ! B_BONES on disk SYS$USER1?

    %FILE$OPENFILES-I-DEVICE, open file report for device DISK$USER1
    B_BONES         00000D67  [LT]DESKTOP_STARTUP.COM;82
    B_BONES         00000D67  [LT.CENTER]CENTER_NET.EXE;4
    B_BONES         00000D67  [RDM$RUJ]LT$DATABASE$0001D9F71EB3.RUJ;1
    %FILE$OPENFILES-I-COUNT, 3 matched files (out of 34 open) on DISK$USER1

    $ OFILES b_bones                      !Since P1 is not a disk device,
    Disk-device <Disks$Mounted>?          ! auto-prompts for a disk, using
                                          ! DISKS$MOUNTED as the default

    $ OFILES sys$user0 b_bones rdb idx    !Display open Rdb database
                                          ! index ("idx") files for
                                          ! user B_BONES

    $ OFILES sys$user2 b_bones,tester_t /MATCH=OR  !Display any open files
                                                   ! for either user B_BONES
                                                   ! and/or TESTER_T

$ !
$ GOTO Done
