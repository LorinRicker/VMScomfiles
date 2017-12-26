$ ! CONTEXT.COM -- subdirectory setups                             'F$VERIFY(0)'
$ !
$ WRITE sys$error "[CONTEXT ''p1']"
$ GOTO 'p1'
$ !
$in:
$ Proc = F$ENVIRONMENT( "PROCEDURE" )
$ DD   = F$PARSE( Proc, , , "DEVICE" ) + F$PARSE( Proc, , , "DIRECTORY" )
$ cf   = "''DD'VMS$AUDIT_LRICKER.CONFIG"
$ IF ( F$SEARCH( cf ) .NES. "" )
$ THEN DEFINE /JOB /NOLOG VMS$AUDITCONFIG 'cf'
$ ELSE WRITE sys$error "%CONTEXT-W-NO_CONFIG, file ''cf' not found"
$ ENDIF
$ IF ( F$TRNLNM( "v$audit" ) .EQS. "" ) THEN DEFINE /PROCESS v$audit 'DD'
$Done:
$ EXIT 1   ! 'F$VERIFY(0)'
$ !
$out:
$ EXIT 1   ! 'F$VERIFY(0)'
$ !
