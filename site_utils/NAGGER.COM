$ ! NAGGER.COM --
$ !
$ ! P1 = Message
$ ! P2 = user name
$ ! P3 = Number of times
$ ! P4 = Interval
$ C = 0
$ UName = F$EDIT(F$GETJPI("","USERNAME"),"TRIM")
$ !
$AskP1:
$ IF P1 .NES. "" THEN GOTO AskP2
$ READ /ERROR=Done /PROMPT="Message: " sys$command P1
$ GOTO AskP1
$AskP2:
$ IF P2 .NES. "" THEN GOTO AskP3
$ READ /ERROR=Done /PROMPT="Tell <''UName'>: " sys$command P2
$ IF P2 .EQS. "" THEN P2 = UName
$AskP3:
$ IF P3 .NES. "" THEN GOTO AskP4
$ READ /ERROR=Done /PROMPT="Times <1>: " sys$command P3
$ IF P3 .EQS. "" THEN P3 = 1
$AskP4:
$ IF P4 .NES. "" THEN GOTO R0
$ READ /ERROR=Done /PROMPT="Interval <00:05>: " sys$command P4
$ IF P4 .EQS. "" THEN P4 = "00:05"
$ !
$R0:
$ TELL 'P2' "''P1'" /BELL /NOMAIL
$ C = C + 1
$ IF C .GE. P3 THEN GOTO Done
$ WAIT 'P4'
$ GOTO R0
$Done:
$ EXIT
