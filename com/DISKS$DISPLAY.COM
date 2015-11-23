$ ! DISKS$DISPLAY.COM --                                           'F$VERIFY(0)'
$ !
$ Prv = F$SETPRV("SYSNAM,CMKRNL,SYSPRV")
$ DEFINE /NOLOG /JOB disks$display -
    sys$sysdevice,sys$user1,sys$user2,sys$user3,sys$user4,sys$user5,-
    disk$alphavmsjt,disk$alphavmstj,-
    disk$altpagja,disk$altpagjb,disk$applocj,disk$syslocj,-
    disk$ltdbB,disk$ltdbC,disk$ltdbD,disk$ltdbE,-
    disk$user0,disk$user1,disk$user2,disk$user3,disk$user4,-
    disk$user5,disk$user6,disk$user8,disk$user9,disk$usera
$ Prv = F$SETPRV(Prv)
$ !
$ IF F$TYPE(disks) .EQS. "" THEN disk*s == "@site$utils:diskspace.com"
$ !
$ EXIT
