$ ! MLOGIC.COM -- forms logical name from current directory or stack
$ !
$ !  usage:  @MLOGIC lnm
$ !
$ IF p1 .EQS. "" THEN EXIT
$ DEFINE /PROCESS /NOLOG 'p1' 'F$ENVIRONMENT("DEFAULT")'
$ WRITE sys$error -
    "%MLOGIC-I, process logical ""''p1'"" = ""''F$TRNLNM(p1,"LNM$PROCESS")'"""
$ EXIT
