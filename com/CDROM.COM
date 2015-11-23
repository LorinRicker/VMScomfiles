$ ! CDROM.COM -- auto-mount a CDROM                                'F$VERIFY(0)'
$ !
$ !  Version for PALE
$ !
$ !  P1 : MOUNT|DISMOUNT action         (default = MOUNT)
$ !  P2 : CLUSTER|SYSTEM|LOCAL scope    (default = SYSTEM)
$ !  P3 : BOOK                          (optional Bookreader logicals)
$ !  P4 : device name                   (default = node$DKA400)
$ !
$ @com:utility START cdrom
$ prv = F$SETPRV("SYSNAM,SYSPRV,OPER")
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ SNode = F$GETSYI("NODENAME")
$ Lnm   = "CD$ROM"
$ Fac   = "%CDROM-"
$ IF P4 .EQS. ""
$ THEN P4 = SNode + "$DKA400:"  !default, typical device name for RRD40, etc.
$ ELSE P4 = P4 - ":" + ":"
$ ENDIF
$ DNode = F$ELEMENT(0,"$",P4)
$ IF DNode .EQS. "" THEN P4 = SNode + "$" + P4
$ @com:utility CmdParse "''P3'" "" "BOOK" "BOOK"
$ BookReader = ( cdrom$Cmd .EQS. "BOOK" )
$ @com:utility CmdParse "''P2'" "" "SYSTEM" "CLUSTER|SYSTEM |LOCAL  "
$ Cluster = ( cdrom$Cmd .EQS. "CLUSTER" )
$ System  = ( cdrom$Cmd .EQS. "SYSTEM" )
$ @com:utility CmdParse "''P1'" "" "MOUNT" "MOUNT   |DISMOUNT"
$ GOTO 'cdrom$Cmd'
$ !
$MOUNT:
$ IF DNode .EQS. SNode
$ THEN IF .NOT. F$GETDVI(P4,"EXISTS")
$      THEN READ sys$command dummy /END_OF_FILE=Done -
              /PROMPT="Be sure ''P4' is powered up, then press <Return> "
$           MCR SYSGEN autoconfigure all
$      ENDIF
$      IF .NOT. F$GETDVI(P4,"EXISTS")
$      THEN WRITE sys$error "''Fac'E, Device ''P4' does not exist"
$           GOTO Done
$      ENDIF
$ ELSE WRITE sys$error "''Fac'E, Run this com-file on node ""''DNode'"" only"
$      GOTO Done
$ ENDIF
$ IF F$GETDVI(P4,"MNT")
$ THEN WRITE sys$error "''Fac'I, Device ''P4' is already mounted"
$      GOTO Done
$ ENDIF
$ !
$ DEFINE /USER_MODE sys$output nl:
$ DEFINE /USER_MODE sys$error  nl:
$ MOUNT /NOWRITE /OVERRIDE=IDENTIFICATION 'P4'
$ Label = F$GETDVI(P4,"VOLNAM")
$ ! Now mounted for LOCAL access... check to see if CLUSTER mount needed:
$ IF Cluster
$ THEN DISMOUNT 'P4'
$      MOUNT /CLUSTER /NOWRITE 'P4' 'Label' 'Lnm'
$      WRITE sys$output "''Fac'I, Mounted ''P4' (''Label') cluster-wide"
$      WRITE sys$output "          Device logical name is ""''Lnm'"""
$ ELSE IF System
$      THEN DISMOUNT 'P4'
$           MOUNT /SYSTEM /NOWRITE 'P4' 'Label' 'Lnm'
$           WRITE sys$output "''Fac'I, Mounted ''P4' (''Label') system-wide"
$           WRITE sys$output "          Device logical name is ""''Lnm'"""
$      ELSE WRITE sys$output "''Fac'I, Mounted ''P4' (''Label') for private access"
$      ENDIF
$ ENDIF
$ IF BookReader
$ THEN Book  = ( F$SEARCH("''P4'[000000]DECW$BOOK.DIR") .NES. "" )
$      Shelf = ( F$SEARCH("''P4'[000000]DECW$BOOKSHELF.DIR") .NES. "" )
$      Tmp = "sys$scratch:cdrom_tmp.com"
$      OPEN /WRITE f 'Tmp'
$      WRITE f "$ ! CDROM_TMP.COM  --  'F$VERIFY(0)'"
$      WRITE f "$ DEFINE /USER_MODE sys$output nl:"
$      WRITE f "$ DEFINE /USER_MODE sys$error  nl:"
$      WRITE f "$ MCR SYSMAN"
$      WRITE f "SET ENVIRONMENT /CLUSTER"
$      WRITE f "SET PROFILE /PRIVILEGE=(SYSNAM,SYSPRV,OPER)"
$      IF Book  THEN WRITE f "DO DEFINE /NOLOG /SYSTEM decw$book ''P4'[decw$book]"
$      IF Shelf THEN WRITE f "DO DEFINE /NOLOG /SYSTEM decw$bookshelf ''P4'[decw$bookshelf]"
$      WRITE f "EXIT"
$      IF Book  THEN WRITE f "$ WRITE sys$output ""''Fac'I, Defined system logical name DECW$BOOK"""
$      IF Shelf THEN WRITE f "$ WRITE sys$output ""''Fac'I, Defined system logical name DECW$BOOKSHELF"""
$      WRITE f "$ EXIT $STATUS"
$      CLOSE f
$      @'Tmp'
$      IF F$SEARCH(Tmp) .NES. "" THEN DELETE /NOLOG 'Tmp';*
$ ENDIF
$ GOTO Done
$ !
$DISMOUNT:
$ IF Cluster
$ THEN DISMOUNT /CLUSTER 'P4'
$      WRITE sys$output "''Fac'I, Dismounted ''P4' from cluster-access"
$ ELSE DISMOUNT 'P4'
$ ENDIF
$ !
$Done:
$ @com:utility EXIT
$ prv = F$SETPRV(prv)
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X0000002C
