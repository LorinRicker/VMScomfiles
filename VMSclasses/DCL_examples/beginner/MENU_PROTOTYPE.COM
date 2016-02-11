$ ! MENU_PROTOTYPE.COM --                                          'F$VERIFY(0)'
$ !
$ wso = "WRITE sys$output"
$ !
$ TYPE SYS$INPUT
       M E N U

   1 - menu-choice-1
   2 - menu-choice-2
   3 - menu-choice-3
   4 - menu-choice-4
   0 - Quit

$ !
$ ! Alternately, you could use (uncomment the "$!!"):
$!! $ wso "       M E N U"
$!! $ wso ""
$!! $ wso "   1 - menu-choice-1"
$!! $ wso "   2 - menu-choice-2"
$!! $ wso "   3 - menu-choice-3"
$!! $ wso "   4 - menu-choice-4"
$!! $ wso "   0 - Quit"
$!! $ wso ""
$ !
$ READ /PROMPT="Menu option? " sys$command choice
$ GOTO lab$'choice'
$ !
$lab$1:
$ ! code to execute choice 1...
$ wso "...(execute code for choice ''choice')"
$ GOTO common
$ !
$lab$2:
$ ! code to execute choice 2...
$ wso "...(execute code for choice ''choice')"
$ GOTO common
$ !
$lab$3:
$ ! code to execute choice 3...
$ wso "...(execute code for choice ''choice')"
$ GOTO common
$ !
$lab$4:
$ ! code to execute choice 4...
$ wso "...(execute code for choice ''choice')"
$ GOTO common
$ !
$common:
$ wso "Success! We're done..."
$ !
$lab$0:
$ EXIT
