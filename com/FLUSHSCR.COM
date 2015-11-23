$ ! FLUSHSCR.COM --                                                'F$VERIFY(0)'
$ !
$ !  flushes all files in SYS$SCRATCH, with a safety valve
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ TPU$Files = "*.tpu$*;*,*.tjl;*"
$ !
$ IF P1 .EQS. "" THEN P1 = "sys$scratch"
$ P1 = P1 - ":"
$ !
$ DEFINE /USER_MODE lib$dt_format lib$date_format_008,lib$time_format_005
$ DIRECTORY 'P1' /WIDTH=(FILENAME=28,SIZE=5,OWNER=10) -
    /EXCLUDE=('TPU$Files') /SIZE /OWNER /PROTECTION /DATE
$ IF F$LOCATE("%RMS-W-FNF",F$MESSAGE($STATUS)) .EQ. 0 THEN EXIT
$ !
$ P0 = "Flush ''P1' (" + F$TRNLNM(P1) + ") <y/[1mN[0m>?  "
$ READ /END_OF_FILE=Done /PROMPT="''P0'" sys$command Answer
$ !
$ IF F$PARSE(Answer,"No",,"NAME","SYNTAX_ONLY") -
  THEN DELETE /NOCONFIRM 'P1':*.*;* /EXCLUDE=('TPU$Files')
$ !
$Done:
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
