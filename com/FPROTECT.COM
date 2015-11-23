$ ! FPROTECT.COM -- set file protections                           'F$VERIFY(0)'
$ !
$ !  use:  protect file (s,o,g,w) [PROTECT|ADOPT|BOTH|DEFAULT] [LIST]
$ !
$ @com:utility START pro
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ prv = F$SETPRV("BYPASS")  !Overpower any access problems!
$ !
$ V = F$EXTRACT(0,2,F$GETSYI("VERSION"))
$ IF V .EQS. "V1" THEN V = "V5"  !alias for early ALPHA AXP versions (v1.5)
$ IF V .GES. "V6" THEN V = "V6"  !now account for v7, v8, ...
$ Li = ( F$EXTRACT(0,1,P4) .EQS. "L" )
$ IF P1 .EQS. "" THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="File: "
$ @com:utility FILEPARSE 'P1' DD DEVICE DIRECTORY
$ @com:utility FILEPARSE 'P1' N  NAME
$ @com:utility FILEPARSE 'P1' TV TYPE VERSION
$ P1 = PRO$DD + "*" + PRO$N + PRO$TV
$ @com:utility CMDPARSE "''P3'" "" "PROTECT" "PROTECT|DEFAULT|BOTH   |ADOPT  |LIST   "
$ IF PRO$Cmd .EQS. "LIST"
$ THEN Li = 1
$      PRO$Cmd == "PROTECT"
$ ENDIF
$ P2 = F$EDIT(P2,"COLLAPSE") - "(" - ")"
$ IF P2 .EQS. ""
$ THEN PM = F$ENVIRONMENT("PROTECTION")
$ ELSE PM = P2
$ ENDIF
$ !
$Loop:
$ Fn = F$SEARCH(P1)  !resolve wildcards
$ IF Fn .EQS. "" THEN GOTO 'V'_Done
$ GOTO 'V'_'PRO$Cmd'
$ !
$ ! VMS v6.0 syntax:
$V6_PROTECT:
$ SET SECURITY /CLASS=FILE /PROTECTION=('PM') 'Fn'
$ GOTO Loop
$V6_ADOPT:
$ PM = F$FILE_ATTRIBUTES(Fn,"PRO") !keep what it's got
$V6_BOTH:
$ SET SECURITY /CLASS=FILE /DEFAULT 'Fn'
$ SET SECURITY /CLASS=FILE /PROTECTION=('PM') 'Fn'
$ GOTO Loop
$V6_DEFAULT:
$ SET SECURITY /CLASS=FILE /DEFAULT 'Fn'
$ GOTO Loop
$ !
$ ! VMS v5.x syntax, including ALPHA AXP v1.5:
$V5_PROTECT:
$ SET FILE /PROTECTION=('PM') 'Fn'
$ GOTO Loop
$V5_ADOPT:
$ SET FILE /OWNER=PARENT 'Fn'
$ GOTO Loop
$V5_BOTH:
$ SET FILE /PROTECTION=('PM') /OWNER=PARENT 'Fn'
$ GOTO Loop
$V5_DEFAULT:
$ PM = F$ENVIRONMENT("PROTECTION")
$ SET FILE /PROTECTION=('PM') /OWNER=PARENT 'Fn'
$ GOTO Loop
$ !
$V6_Done:
$ IF Li THEN SHOW SECURITY 'P1'
$ GOTO Done
$V5_Done:
$ IF Li THEN DIRECTORY /WIDTH=(FILE=16,SIZE=4,OWN=16) -
              /SIZE=ALL /OWN /PROTECTION /ACL 'P1'
$Done:
$ prv = F$SETPRV(prv)
$ @com:utility EXIT
$ EXIT 1
$ !
$Ctrl_Y:
$ RETURN %X2C
