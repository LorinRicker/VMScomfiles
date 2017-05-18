$ ! DISKINVENTORY$REPORT.COM --                                    'F$VERIFY(0)'
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
$ !  Create spreadsheet inventories (CSV) of all disks
$ !
$ !  use: @DISKINVENTORY$REPORT [/OUTPUT=DI$<ClusterAlias>.csv] «»[disk[,disk]...] [CLUSTER]
$ !
$ !       If P1 is a comma-separated list of disk names, then only these devices
$ !       are checked, otherwise all physical (non-DSA) devices are checked
$ !
$ !       If P2 = "CLUSTER" then SYSMAN uses SET ENVIRONMENT /CLUSTER,
$ !       else it uses SET ENVIRONMENT /NODE=(node_list)
$ !
$ !  Run this com-file without /OUTPUT=filespec to see the report on your terminal;
$ !  use /OUTPUT=filespec to save the report to a comma-separated report file which
$ !  can be imported into an Excel/Calc spreadsheet.
$ !
$MountedDisk:  SUBROUTINE
$ ! P1 = device (disk)
$ ! P2 = undecorated device
$ !
$ ON CONTROL_Y THEN GOSUB SCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ shadow    = F$GETDVI( P1, "SHDW_MASTER_NAME" ) - "_" - ":"
$ volname   = F$GETDVI( P1, "VOLNAM" )
$ curlvsize = F$GETDVI( P1, "VOLSIZE" )
$ maxlvsize = F$GETDVI( P1, "MAXBLOCK" )
$ !
$ ! Report line:
$ DI$DevCount == DI$DevCount + 1
$ wso F$FAO( "!SL,!AS,!AS,!AS,!SL,!SL,!AS", -
             DI$DevCount, shadow, P2, volname, curlvsize, maxlvsize, "" )
$ EXIT 1
$ !
$SCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! MountedDisk
$ !
$OnlineDisk:  SUBROUTINE
$ ! P1 = device (disk)
$ ! P2 = undecorated device
$ ! P3 = "/CLUSTER" or "/NODE=(''CluNodes')" for SYSMAN
$ !
$ ON CONTROL_Y THEN GOSUB SCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ DEV$isAllocated = %X00000840  ! %SYSTEM-W-DEVALLOC, device already allocated to another user
$ DEV$isMounted   = %X0000006C  ! %SYSTEM-F-DEVMOUNT, device is already mounted
$ !
$ smoutfile = "[]DI$sysman_tmp.output"
$ smcomfile = "[]DI$sysman_tmp.com"
$ comment   = ""
$ dq        = """"
$ sq        = "'"
$ sep       = ";"
$ !
$ OPEN /WRITE /ERROR=SCtrl_Y smcom 'smcomfile'
$ ! Ask each clu-node to report: "NODENAME;Mnt[TRUE|FALSE]"
$ WRITE smcom "$ Nod = F$GETSYI(""NODENAME"")"
$ WRITE smcom "$ Mnt = F$GETDVI(" + dq + P1 + dq + ",""MNT"")"
$ WRITE smcom "$ WRITE sys$output " + dq + sq + sq + "Nod" + sq -
                                   + sep + sq + sq + "Mnt" + sq + dq
$ WRITE smcom "$ EXIT"
$ CLOSE smcom
$ !
$ DEFINE /USER_MODE sys$error  nla0:  !suppress the %SYSMAN-I-ENV noise
$ DEFINE /USER_MODE sys$output nla0:
$ SYSMAN SET ENVIRONMENT 'P3'
DO /OUTPUT=[]DI$sysman_tmp.output @[]DI$sysman_tmp.com
$ !
$ isMountedSomewhere = "FALSE"
$ OPEN /READ /ERROR=SCtrl_Y smout 'smoutfile'
$S0:
$ READ /END_OF_FILE=S1 smout line
$ IF F$EXTRACT(0,10,line)    .EQS. "%SYSMAN-I-" THEN GOTO S0  !skip
$ IF F$EXTRACT(0,8,line)     .EQS. "        "   THEN GOTO S0  !     these
$ IF F$EDIT(line,"COLLAPSE") .EQS. ""           THEN GOTO S0  !           lines
$ IF F$EXTRACT(0,7,line)     .EQS. "%SYSTEM"    THEN GOTO S0  !...
$ Sys = F$EDIT(F$ELEMENT(0,sep,line),"TRIM")
$ Val = F$EDIT(F$ELEMENT(1,sep,line),"TRIM")
$ IF Val .EQS. "TRUE" 
$ THEN isMountedSomewhere = "TRUE"  !seen it mounted on at least one node...
$      ! Construct a global symbol result for the main-body
$      IF comment .NES. ""
$      THEN comment = comment + sep + Sys
$      ELSE comment = "mounted on: " + Sys
$      ENDIF
$ ENDIF
$ GOTO S0
$S1:
$ CLOSE smout
$ DELETE /NOLOG 'smoutfile';*,'smcomfile';*
$ !
$ volname   = "(unknown)"
$ curlvsize = 0
$ maxlvsize = 0
$ IF isMountedSomewhere
$ THEN !...likely cannot mount this disk privately, so note it...
$      comment = comment + ";NODE-MOUNT"
$ ELSE SET NOON
$      DEFINE /USER_MODE sys$error  nla0:  !suppress any already-allocated noise
$      DEFINE /USER_MODE sys$output nla0:
$      ALLOCATE /NOLOG 'P1'
$      Stat = $STATUS
$      Sev  = $SEVERITY
$      IF Sev .GTS. "1" -
       THEN WRITE SYS$ERROR F$FAO( "!SL. Dev: !AS - Alloc-status: !XL", DI$DevCount, P1, Stat )
$      IF ( Sev .EQS. "1" ) .AND. ( Stat .NE. DEV$isAllocated ) .AND. ( Stat .NE. DEV$isMounted )
$      THEN !...can safely mount this disk privately to grab its attributes
$           DEFINE /USER_MODE sys$error  nla0:  !suppress the %MOUNT-I-MOUNTED noise
$           DEFINE /USER_MODE sys$output nla0:
$           MOUNT /NOWRITE /NOUNLOAD /OVERRIDE=IDENTIFICATION 'P1'
$           WAIT 00:00:00.125
$           volname   = F$GETDVI( P1, "VOLNAM" )
$           curlvsize = F$GETDVI( P1, "VOLSIZE" )
$           maxlvsize = F$GETDVI( P1, "MAXBLOCK" )
$           DEFINE /USER_MODE sys$error  nla0:  !suppress any %MOUNT-F-NOTMOUNTED noise
$           DEFINE /USER_MODE sys$output nla0:
$           DISMOUNT /NOUNLOAD 'P1'
$      ELSE !...another node's got this disk mounted, so note it...
$           comment = comment + ";NODE-ALLOC"
$      ENDIF
$ ENDIF
$ !
$ ! Report line:
$ DI$DevCount == DI$DevCount + 1
$ wso F$FAO( "!SL,!AS,!AS,!AS,!SL,!SL,!AS", -
             DI$DevCount, "(online)", undev, volname, curlvsize, maxlvsize, comment )
$ !
$ EXIT 1
$ !
$SCtrl_Y:
$ RETURN $status    !!%X2C
$ ENDSUBROUTINE  ! OnlineDisk !'F$VERIFY(0)'
$ !
$ !
$ ! === MAIN ===
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ sysman = "$SYS$SYSTEM:SYSMAN"
$ !
$ DI$CluNodeCount == 0
$ DI$DevCount     == 0
$ wso   = "WRITE sys$output"
$ Fac   = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ Node  = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ Clu   = F$EXTRACT(0,4,Node)
$ comma = ","
$ !
$ ON WARNING THEN GOTO NoSuchSys
$ GOTO 'Node'
$ !
$CluCount:
$ IF F$ELEMENT(DI$CluNodeCount,comma,CluNodes) .EQS. comma
$ THEN GOTO Report
$ ELSE DI$CluNodeCount == DI$CluNodeCount + 1
$      GOTO CluCount
$ ENDIF
$ !
$Report:
$ P2 = P2 - "/"                      ! strip any leading "/" from P2...
$ IF F$EXTRACT(0,3,P2) .EQS. "CLU"   ! P2 = "CLUSTER"?
$ THEN Env = "/CLUSTER"
$ ELSE Env = "/NODE=(''CluNodes')"
$ ENDIF
$ wso F$FAO( "%!AS-I-DISKS, disks on cluster-node !AS!/  Cluster-node count: !SL!/  Env: !AS", -
             Fac, Node, DI$CluNodeCount, Env )
$ !
$ alloclass = "$" + F$STRING(F$GETSYI("ALLOCLASS")) + "$"
$ !
$ IF ( P1 .NES. "" )
$ THEN DD$Disks == P1
$ ELSE DCL$CALL DiscoverDisks DI$Disks "MNT,SHDW_MEMBER"
$ ENDIF
$ !
$ j = 0
$L0:
$ dev = F$ELEMENT(j,comma,DI$Disks)
$ j = j + 1
$ IF ( dev .EQS. comma ) .OR. ( dev .EQS. "" ) THEN GOTO Done
$ !
$ undev = dev - "_" - alloclass - "''Node'$" - ":"   !undecorate it...
$ !!«» wso F$FAO( "!3SL. disk: !AS", DI$DevCount, dev )
$ IF F$GETDVI(dev,"MNT")
$ THEN ! Full accounting for a mounted disk:
$      ! Reporting the DSA units is redundant, as we're collecting the DGA units,
$      ! and their shadow-masters (the DSA virtual disk), so skip it...
$      IF F$EXTRACT(0,3,undev) .EQS. "DSA" THEN GOTO L0      !skip the DSA units...
$      CALL MountedDisk "''dev'" "''undev'"
$ ELSE ! The disk is online, but not currently mounted...
$      xtypes = "DQ,DA,LD"
$      xtylen = F$LENGTH(xtypes)
$      devtype = F$EXTRACT(0,2,undev)
$      IF F$LOCATE(devtype,xtypes) .LT. xtylen THEN GOTO L0  !skip DQAn, DADn, LDAn, etc...
$      IF F$EXTRACT(0,3,undev) .EQS. "DSA" THEN GOTO L0      !again, skip DSA units...
$      CALL OnlineDisk "''dev'" "''undev'" "''Env'"          !...so where is dev online?
$ ENDIF
$ GOTO L0
$ !
$Done:
$ DCL$CALL DeleteGloSyms "DI$DevCount,DI$CluNodeCount,DI$Disks"
$ EXIT 'stat'
$ !
$NoSuchSys:
$ SET NOON
$ wso F$FAO( "%!AS-I-NOSUCHSYS, no such system !AS yet enabled for this report", Fac, Node )
$ stat = %X2C
$ GOTO Done
$ !
$Ctrl_Y:
$ RETURN %X2C
