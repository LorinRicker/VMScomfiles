$ ! MENU_SAMPLE.COM --                                             'F$VERIFY(0)'
$ !
$ wso = "WRITE SYS$OUTPUT"
$ !
$L0:
$ TYPE sys$input /page

     Enter:
       1   -- Start application
       2   -- Start calculator
       3   -- Generate reports
       4   -- Clean month-end stuff
      99   -- Exit

$ !
$ READ sys$command /PROMPT="Enter option: " answer
$ GOTO L$'answer'
$ !
$L$1:
$ ! invoke application here
$ wso "invoked application..."
$ GOTO L0
$ !
$L$2:
$ ! invoke calculator here
$ wso "invoked calculator..."
$ GOTO L0
$ !
$L$3:
$ wso "invoked reports..."
$ ! invoke reports
$ GOTO L0
$ !
$L$4:
$ wso "invoked monthly cleanup..."
$ ! Clean month-end
$ GOTO L0
$ !
$L$99:
$ EXIT
