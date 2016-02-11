$ ! PROC_NAME.COM
$ !
$ this = F$ENVIRONMENT("PROCEDURE")
$ T1 = F$PARSE(this,,,"DEVICE") + F$PARSE(this,,,"DIRECTORY") -
     + F$PARSE(this,,,"NAME")   + F$PARSE(this,,,"TYPE")
$ !
$ WRITE sys$output "first version of this: ''T1'"
$ !
$ T2 = this - F$PARSE(this,,,"VERSION")
$ !
$ WRITE sys$output "second version of this: ''T2'"
$ WRITE sys$output "  ...and this was: ''this'"
$ !
$ EXIT
