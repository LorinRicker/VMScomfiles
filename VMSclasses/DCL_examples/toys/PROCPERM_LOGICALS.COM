$ ! PROCPERM_LOGICALS.COM                                          'F$VERIFY(0)'
$ !
$ ! Display the equivalence strings for the four process-permanent logical names;
$ ! this can be executed interactively or from a batch job:
$ !
$ WRITE sys$output "Process-permanent logical names for this ''F$MODE()' process:"
$ WRITE sys$output ""
$ SHOW LOGICAL sys$command
$ SHOW LOGICAL sys$input
$ SHOW LOGICAL sys$output
$ SHOW LOGICAL sys$error
$ EXIT      ! 'F$VERIFY(0)'
$ !
