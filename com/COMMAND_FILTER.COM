$ ! COMMAND_FILTER.COM --                                          'F$VERIFY(0)'
$ !
$ !  @command_filter "Command" "SearchText" [Match] [Window] [Format] [TempFile]
$ !                                          OR      (1)      PASSALL
$ !                                          AND     (n)      NONULLS
$ !                                          NOR     (m,n)    DUMP
$ !                                          NAND
$ !
$ ON ERROR     THEN GOTO Done
$ ON CONTROL_Y THEN GOTO Done
$ IF P1 .EQS. ""
$ THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="    Command: "
$ ENDIF
$ IF P2 .EQS. ""
$ THEN READ sys$command P2 /END_OF_FILE=Done /PROMPT="Search text: "
$ ENDIF
$ IF P3 .EQS. "" THEN P3 = "OR"
$ IF P4 .EQS. ""
$ THEN P4 = "(1)"
$ ELSE P4 = P4 -"(" - ")"
$      P4 = "(" + P4 + ")"
$ ENDIF
$ IF P5 .EQS. "" THEN P5 = "PASSALL"
$ IF P6 .EQS. "" THEN P6 = "sys$scratch:command_filter.temporary_output"
$ !
$ DEFINE /USER_MODE sys$output 'P6'
$ 'P1'
$ IF $STATUS
$ THEN SEARCH 'P6' 'P2' /MATCH='P3' /WINDOW='P4' /FORMAT='P5'
$ ENDIF
$ !
$Done:
$ IF F$SEARCH(P6) .NES. "" THEN DELETE /NOLOG 'P6';*
$ EXIT
