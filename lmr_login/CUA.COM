$ ! CUA.COM -- Create user account
$ !
$ prv = F$SETPRV("SYSNAM,SYSPRV,CMKRNL")
$ !
$ IF F$TRNLNM("sysuaf") .EQS. ""
$ THEN DEFINE /SYSTEM /EXEC sysuaf     sys$system:sysuaf.dat
$      DEFINE /SYSTEM /EXEC rightslist sys$system:rightslist.dat
$ ENDIF
$ SHOW LOGICAL sysuaf
$ SHOW LOGICAL rightslist
$ !
$ UNm  = "Ricker"
$ Own  = "Lorin Ricker"
$ Acc  = "SYSMGR"
$ Dev  = "sys$sysdevice"
$ Dir  = "ricker"
$ UDir = Dev + ":[" + Dir + "]"
$ uic  = "[20,32]"
$ pwd  = "NEWUSER"
$ dprv = "NETMBX,TMPMBX,OPER,SYSPRV,SETPRV"
$ !
$ wf = "WRITE f"
$ TmpFile = "[]cua_temp.com"
$ OPEN /WRITE /ERROR=Oops f 'TmpFile'
$ !
$ wf "$ MCR AUTHORIZE                                              !'F$VERIFY(1)'"
$ wf ""
$ wf "ADD ''UNm' /ACCOUNT=""''Acc'"" -"
$ wf "  /OWNER=""''Own'"" /UIC=''uic' -"
$ wf "  /DEVICE=''Dev' /DIRECTORY=[''Dir'] -"
$ wf "  /FLAG=NODISUSER /PASSWORD=''pwd' -"
$ wf "  /PWDLIFETIME=0-00:00 /NOPWDEXPIRED -"
$ wf "  /FILLM=300 /BIOLM=2048 /DIOLM=2048 -"
$ wf "  /ASTLM=1024 /TQELM=1024 /ENQLM=8192 -"
$ wf "  /BYTLM=256000 /JTQUOTA=8192 /PGFLQUO=700000 -"
$ wf "  /WSDEF=8192 /WSQUO=16384 /WSEXTENT=32768 -"
$ wf "  /PRIV=(''dprv') -"
$ wf "  /DEFPRIV=(''dprv')"
$ wf ""
$ wf "SHOW /FULL ''UNm'"
$ wf "$ !"
$ wf "$ IF F$SEARCH(""''UDir'"") .EQS. """" "
$ wf "$ THEN CREATE /DIRECTORY /LOG ''UDir' /OWNER=''uic'"
$ wf "$ ENDIF"
$ wf "$ !"
$ wf "$ DELETE /LOG ''TmpFile';*"
$ wf "$ EXIT                                                       !'F$VERIFY(0)'"
$ ! 
$ CLOSE f
$ ! 
$ @'TmpFile'
$ ! 
$Quit:
$ prv = F$SETPRV(prv)
$ EXIT
$ !
$Oops:
$ WRITE sys$error "%CUA-W-OOPS, could not OPEN/WRITE ''TmpFile' in current directory"
$ GOTO Quit
