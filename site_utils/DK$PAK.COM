$ ! DK$PAK.COM  -- defines Programmable Action Keys
$ !
$ !  use:  @DK$PAK keyname [-option]
$ !
$ !  PAK can use:           K  N P     V   
$ !     VMS uses: ABC E GH J LM O QRSTU  XYZ
$ !     TPU uses: A CDEF HIJ       R    W  Z
$ !
$ IF F$MODE() .NES. "INTERACTIVE" THEN EXIT
$ SET NOON
$ P2 = F$EDIT(P2,"COLLAPSE,UPCASE")
$ Quiet = F$LOCATE("Q",P2) .LT. F$LENGTH(P2)
$ UTIL_KEYINUSE  = %X08038698
$ UTIL_KEYLOAD   = %X08038021
$ UTIL_KEYNOTLOA = %X080386A0
$ UTIL_FILNOTFND = %X0803896A
$ lnm  = "DK$pak_keys"
$ defd = F$TRNLNM(lnm,"lnm$process")
$ new  = ""
$ prgm = "site$utils:pak$key_bind.exe"
$ IF F$SEARCH(prgm) .EQS. "" THEN GOTO E0
$ pak  = "$''prgm' bind"
$ sep  = ","
$ klet = ",K,N,P,V,"
$ knum = ",30,40,20,10,"
$ knam = ",OPF,ANTOG,CHAN,VTOG,"
$ !
$L0:
$ IF p1 .EQS. "" THEN GOTO Done
$ sel  = F$EXTRACT(0,1,p1)
$ p1   = p1 - sel
$ IF F$LOCATE(sel,defd) .GE. F$LENGTH(defd) -
  .OR. defd .EQS. ""                        -
  THEN  GOTO L1
$ WRITE sys$error F$FAO(F$MESSAGE(UTIL_KEYINUSE),"""''sel'""")
$ GOTO L0   !skip already defined pak's
$L1:
$ idx  = ( F$LOCATE(sel,klet) / 2 ) + 1
$ IF ( idx .GT. 0 ) .AND. ( idx .LE. (F$LENGTH(klet)/2) ) -
  THEN  GOTO L2
$ WRITE sys$error F$FAO(F$MESSAGE(UTIL_KEYINUSE),"""''sel'""")
$ GOTO L0
$L2:
$ id   = F$ELEMENT(idx,sep,knum)
$ nam  = F$ELEMENT(idx,sep,knam)
$ msg  = "''nam':''id' ""''sel'"""
$ pak /id='id' /key='sel'
$ IF .NOT. $STATUS THEN GOTO L3
$ new  = new + sel
$ IF .NOT. Quiet THEN WRITE sys$error F$FAO(F$MESSAGE(UTIL_KEYLOAD),msg)
$ GOTO L0
$L3:
$ WRITE sys$error F$FAO(F$MESSAGE(UTIL_KEYNOTLOA),msg)
$ GOTO L0
$ !
$Done:
$ defd = defd + new   !previous plus new keys
$ DEFINE /PROCESS /NOLOG 'lnm' 'defd'
$ EXIT
$ !
$E0:
$ WRITE sys$error F$FAO(F$MESSAGE(UTIL_FILNOTFND),prgm)
$ EXIT
