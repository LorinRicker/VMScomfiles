$ ! REMID2IP.COM                                                   'F$VERIFY(0)'
$ !
$ ! Convert a hex-string version of an IP address to a dotted decimal
$ ! string in the global DCL symbol IP_ADDRESS.  -- Jim Becker
$ !
$ Verbose = F$TRNLNM("Tools$Debug")
$ Quals = P2 + P3 + P4 + P5 + P6 + P7 + P8
$ QLen  = F$LENGTH(Quals)
$ Verbose = Verbose .OR. ( F$LOCATE("/L",Quals) .LT. QLen)  ! /LOG ?
$ Verbose = Verbose .OR. ( F$LOCATE("/V",Quals) .LT. QLen)  ! /VERBOSE ?
$ !
$ IF P1 .EQS. ""
$ THEN remid = F$TRNLNM("sys$rem_id")
$ ELSE remid = P1
$ ENDIF
$ IF remid .EQS. "" THEN EXIT
$!
$! Remote id often appears in these forms: TELNET_xxxxxxxx, FTP_xxxxxxxx
$ IF F$LOCATE("_",remid) .LT. F$LENGTH(remid)
$ THEN id = F$ELEMENT(1,"_",remid)
$ ELSE id = remid
$ ENDIF
$ msg = F$ENVIRONMENT("MESSAGE")
$ ON WARNING THEN GOTO Skip_IP
$ SET MESSAGE /NOFACILITY /NOSEVERITY /NOIDENT /NOTEXT
$ byte1 = %x'F$EXTRACT(0,2,id)'
$ byte2 = %x'F$EXTRACT(2,2,id)'
$ byte3 = %x'F$EXTRACT(4,2,id)'
$ byte4 = %x'F$EXTRACT(6,2,id)'
$ IP_Address == F$FAO("!UB.!UB.!UB.!UB", byte1, byte2, byte3, byte4)
$ IF Verbose
$ THEN WRITE sys$output F$FAO("REMID2IP-I-ECHO, IP address corresponding to !AS is [1m!AS[0m", remid, IP_Address)
$ ENDIF
$ !
$Skip_IP:
$ SET MESSAGE 'msg'
$ EXIT
