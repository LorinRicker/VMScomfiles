$ ! NB(NotaBona).COM  -- 
$ !
$ IF p1 .EQS. ""
$ THEN READ /END_OF_FILE=Done /PROMPT="nota bona: " sys$command subj
$ ELSE subj = "''p1' ''p2' ''p3' ''p4' ''p5' ''p6' ''p7' ''p8'"
$      subj = F$EDIT(subj,"COMPRESS,TRIM,LOWERCASE")
$ ENDIF
$ IF F$TRNLNM("self") .EQS. "" -
  THEN  DEFINE /USER_MODE self 'F$EDIT(F$GETJPI("","USERNAME"),"TRIM")'
$ MAIL nla0: self /SUBJECT="''subj'"
$Done:
$ EXIT
