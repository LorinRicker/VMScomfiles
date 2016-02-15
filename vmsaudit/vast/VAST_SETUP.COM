$ ! VAST_SETUP.COM --                                             'F$VERIFY(0)'
$ !
$ !  use: @VAST_SETUP [ [ COMMAND (D) | DEFINE ]
$ !                      | [ AUTHORIZE | USER ] | PROXY | TREE | SECURITY ]
$ !
$ ! Copyright (C) 2012-2013 Lorin Ricker <lorin@rickernet.us>
$ ! Version: 2.0, 05/17/2013
$ !
$ ! This program is free software, under the terms and conditions of the
$ ! GNU General Public License published by the Free Software Foundation.
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ wso    = "WRITE sys$output"
$ DQUOTE = """"
$ !
$ proc   = F$ENVIRONMENT("PROCEDURE")
$ node   = F$ELEMENT(0,DQUOTE,F$PARSE(proc,,,"NODE","SYNTAX_ONLY"))  ! strip "username password"::
$ fac    = F$PARSE(proc,,,"NAME","SYNTAX_ONLY")
$ dd     = F$PARSE(proc,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(proc,,,"DIRECTORY","SYNTAX_ONLY")
$ !
$ ROproxy   = "DTSAUDITSYS"
$ AuditTree = "[" + ROproxy + "]"
$ AuditDisk = "DISK$TOOLS:"
$ adroot = AuditDisk + AuditTree - "]"
$ adrept = adroot + ".REPORTS]"
$ adstat = adroot + ".STATISTICS]"
$ !
$ PinToNode = "MCCS00" ! «-- Change this if ['AuditTree'...] is moved to another system «--
$ !
$ IF node .EQS. ""
$ THEN node = PinToNode
$ ELSE ThisNode  = F$EDIT(F$EXTRACT(0,6,node),"COLLAPSE") - ":" - ":"
$      IF ThisNode .NES. PinToNode
$      THEN msg  = F$FAO( "!AS-F-WRONGNODE, ", Fac )
$           msgL = F$LENGTH(msg)
$           wso F$FAO( "!ASattempting to execute Audit System Suite the from wrong system:", msg )
$           wso F$FAO( "!#* accessing node !AS", msgL, ThisNode )
$           wso F$FAO( "!#* should be node !AS", msgL, PinToNode )
$           EXIT %X2C
$      ENDIF
$ ENDIF
$ !
$ IF P1 .EQS. "" THEN P1 = "COMMAND"
$ !
$ GOTO 'F$EXTRACT(0,4,P1)'$
$ !
$COMM$:
$DEFI$:
$ ! Construct a global symbol to remote-invoke VAST_SYSTEM using a read-only proxy:
$ audit*system == "@''node'""''ROproxy'""::''AuditDisk'''AuditTree'VAST_SYSTEM"
$ SHOW SYMBOL /GLOBAL auditsystem
$ EXIT %X1
$ !
$ ! ----- The scripts below are for Audit System Suite setup and maintenance only -----
$ !
$AUTH$:
$USER$:
$ prv  = F$SETPRV("SYSPRV,SYSNAM,CMKRNL")
$ UNm  = ROproxy
$ Own  = "DTS Group"
$ Acc  = "DTSGROUP"
$ Dev  = AuditDisk
$ Dir  = AuditTree
$ UDir = Dev + Dir
$ uic  = "[20,2020]"
$ pwd  = "4Audit$Only"
$ dprv = "NOALL,NETMBX,TMPMBX,OPER"
$ !
$ wf = "WRITE f"
$ TmpFile = "[]cua_temp.com"
$ OPEN /WRITE /ERROR=Oops f 'TmpFile'
$ !
$ wf "$ MCR AUTHORIZE                                              !'F$VERIFY(0)'"
$ wf ""
$ wf "ADD ''UNm' /ACCOUNT=""''Acc'"" -"
$ wf "  /OWNER=""''Own'"" /UIC=''uic' -"
$ wf "  /DEVICE=''Dev' /DIRECTORY=''Dir' -"
$ wf "  /NOBATCH /NOINTERACTIVE /LGICMD=NLA0: -"
$ wf "  /FLAGS=(RESTRICTED,PWDMIX,NODISUSER) -"
$ wf "  /PASSWORD=""''pwd'"" -"
$ wf "  /PWDLIFETIME=0-00:00 /NOPWDEXPIRED -"
$ wf "  /FILLM=300 /BIOLM=2048 /DIOLM=2048 -"
$ wf "  /ASTLM=1024 /TQELM=1024 /ENQLM=8192 -"
$ wf "  /BYTLM=200000 /JTQUOTA=8192 /PGFLQUO=400000 -"
$ wf "  /WSDEF=16384 /WSQUO=32768 /WSEXTENT=65536 -"
$ wf "  /PRIV=(''dprv') -"
$ wf "  /DEFPRIV=(''dprv')"
$ wf ""
$ wf "SHOW /FULL ''UNm'"
$ wf "EXIT"
$ wf ""
$ wf "$ !"
$ wf "$ DELETE /LOG ''TmpFile';*"
$ wf "$ EXIT                                                       !'F$VERIFY(0)'"
$ CLOSE f
$ !
$ @'TmpFile'
$ !
$ GOTO Done
$ !
$Oops:
$ WRITE sys$error "%CUA-W-OOPS, could not OPEN/WRITE ''TmpFile' in current directory"
$ GOTO Done
$ !
$PROX$:
$ prv = F$SETPRV("SYSPRV,SYSNAM,CMKRNL")
$ uaf = "$SYS$SYSTEM:AUTHORIZE"
$ uaf ADD /PROXY *::* 'ROproxy' !! /DEFAULT
$ !! uaf SHOW /PROXY *::*
$ GOTO Done
$ !
$TREE$:
$ prv = F$SETPRV("SYSPRV,BYPASS")
$ tdir = AuditDisk + "[000000]" + ROproxy + ".DIR"
$ adir = AuditDisk + AuditTree
$ IF F$SEARCH(tdir) .EQS. ""
$ THEN CREATE /DIRECTORY /LOG 'adir'   /OWNER='ROproxy' /PROT=(S:RWE,O:RWE,G:RWE,W:RE)
$      CREATE /DIRECTORY /LOG 'adrept' /OWNER=PARENT    /PROT=(S:RWE,O:RWE,G:RWE,W:RE)
$      CREATE /DIRECTORY /LOG 'adstat' /OWNER=PARENT    /PROT=(S:RWE,O:RWE,G:RWE,W:RE)
$      @$release "" /LOG
$ ELSE wso F$FAO( "%!AS-I-EXISTS, directory !AS exists", fac, adir )
$ ENDIF
$ GOTO Done
$ !
$SECU$:
$ prv = F$SETPRV("SYSPRV,BYPASS")
$ adir = AuditDisk + AuditTree
$ SET SECURITY 'adir'*.*;* /EXCLUDE=(*.DIR;*,*.LOG;*) /PROT=(S:RWED,O:RWED,G:RE,W:E) -
    /ACL=(IDENTIFIER='ROproxy',ACCESS=READ+EXECUTE)
$ SET SECURITY 'adir'*.DIR;* /PROT=(S:RWE,O:RWE,G:RWE,W:E) -
    /ACL=((IDENTIFIER='ROproxy',OPTIONS=DEFAULT,ACCESS=READ+WRITE), -
          (IDENTIFIER='ROproxy',ACCESS=READ+WRITE))
$ statfile = adstat + "VAST_STATISTICS.DAT"
$ IF F$SEARCH(statfile) .NES. ""
$ THEN SET SECURITY 'statfile';* /PROT=(S:RW,O:RW,G:RW,W:R) -
         /ACL=(IDENTIFIER='ROproxy',ACCESS=READ+WRITE)
$ ENDIF
$ reptfile = adrept + "*.*"
$ IF F$SEARCH(reptfile) .NES. ""
$ THEN SET SECURITY 'reptfile';* /PROT=(S:RWED,O:RWED,G:RWD,W:R) -
         /ACL=(IDENTIFIER='ROproxy',ACCESS=READ+WRITE+DELETE)
$ ENDIF
$ netlog = adir + "NET$SERVER.LOG"
$ IF F$SEARCH(netlog) .NES. ""
$ THEN SET FILE /VERSION=2 /NOLOG 'netlog';*
$      PURGE /KEEP=2 /NOLOG 'netlog'
$      SET SECURITY /ACL /DELETE /NOLOG 'netlog';*
$ ENDIF
$ GOTO Done
$ !
$Done:
$ IF F$TYPE(prv) .NES. "" THEN prv = F$SETPRV(prv)
$ EXIT %X1
$ !
$Ctrl_Y:
$ RETURN %X2C
