$ ! WATCH.COM -- turn on and off SET WATCH FILE (unsupported DCL)
$ !
$ !    P1 can be any of the following:
$ !             ALL
$ !             ATTACHED
$ !             ATTRIBUTES
$ !             CONTROL_FUNCTIONS
$ !             DIRECTORY_OPERATIONS
$ !             DUMP
$ !             MAJOR_FUNCTIONS
$ !             QUOTA_OPERATIONS
$ !             NONE (to stop SET WATCH)
$ !    
$ IF P1 .EQS. "" THEN P1 = "NONE"
$ prv = F$SETPRV("CMEXEC")
$ SET WATCH FILE /CLASS='P1'
$ prv = F$SETPRV(prv)
$ EXIT
