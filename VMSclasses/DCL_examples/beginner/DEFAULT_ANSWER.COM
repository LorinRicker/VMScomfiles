$ ! DEFAULT_ANSWER.COM
$ !
$ READ sys$command Answer /PROMPT="Confirm this operation (yes/NO): "
$ show symbol /local Answer
$ Answer = F$EXTRACT(0,1,F$PARSE(Answer,"no",,"NAME","SYNTAX_ONLY"))
$ show symbol /local Answer
$ EXIT
