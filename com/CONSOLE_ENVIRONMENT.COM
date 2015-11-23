$ ! CONSOLE_ENVIRONMENT.COM --                                     'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of Lorin Ricker.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2013 by Lorin Ricker.  All rights reserved.
$ !
$ !  mini-report of the Console Environment Variables
$ !
$GetEnv:  SUBROUTINE
$ ! P1 : Line label
$ ! P2 : Arg for F$GETENV()
$ !
$ ON CONTROL_Y THEN GOSUB SCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ P1Len = F$LENGTH(P1)
$ !
$ ! Build line label:
$ IF P1Len .LE. LblWidth - 1
$ THEN Lbl = F$FAO( "!#* !AS", LblWidth - P1Len, P1 )
$ ELSE Lbl = "<" + P1 + ">"
$ ENDIF
$ !
$ ! Build data line(s):
$ env = F$GETENV(P2)
$ IF env .EQS. "" THEN env = "(none specified)"
$ IF F$LOCATE(sep,env) .LT. F$LENGTH(env)  !'F$VERIFY(0)'
$ THEN j = 0
$      ValA = ""
$      ValB = ""
$L0:   tmp  = F$ELEMENT(j,sep,env)
$      tmpL = F$LENGTH(tmp)
$      IF tmp .EQS. sep THEN GOTO L1
$      IF ValA .NES. ""
$      THEN IF ( F$LENGTH(ValA) + SpcWidth + tmpL ) .LT. ( 255 - (SpcWidth + tmpL + 1) )
$           THEN ValA = F$FAO( "!AS!AS!/!#* !AS", ValA, sep, SpcWidth, tmp )
$           ELSE IF ValB .NES. ""
$                THEN ValB = F$FAO( "!AS!AS!/!#* !AS", ValB, sep, SpcWidth, tmp )
$                ELSE ValB = tmp
$                     ValA = ValA + sep
$                ENDIF
$           ENDIF
$      ELSE ValA = tmp
$      ENDIF
$      j = j + 1
$      GOTO L0
$ ELSE ValA = env
$      ValB = ""
$ ENDIF
$L1:
$ wso F$FAO( "!AS: !AS", Lbl, ValA )
$ IF ValB .NES. "" THEN wso F$FAO( "!#* !AS", SpcWidth, ValB )
$ EXIT 1  !'F$VERIFY(0)'
$ !
$SCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! GetEnv
$ !
$ !
$ ! === MAIN ===
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ wso  = "WRITE sys$output"
$ Fac  = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ Node = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ !
$ LblWidth = 21
$ SpcWidth = LblWidth + 2
$ sep      = ","
$ !
$ wso ""
$ wso "%''Fac'-I-VARIABLES, Console Environment Variables for ''Node'"
$ wso F$FAO("!80*-")
$ CALL GetEnv "Auto Action"         "AUTO_ACTION"
$ CALL GetEnv "Boot Device"         "BOOT_DEV"
$ CALL GetEnv "Default Boot Device" "BOOTDEF_DEV"
$ CALL GetEnv "Boot File"           "BOOT_FILE"
$ CALL GetEnv "Boot OS-Flags"       "BOOT_OSFLAGS"
$ CALL GetEnv "Boot Reset"          "BOOT_RESET"
$ CALL GetEnv "Dump Device"         "DUMP_DEV"
$ wso ""
$ CALL GetEnv "Booted Device"       "BOOTED_DEV"
$ CALL GetEnv "Booted File"         "BOOTED_FILE"
$ CALL GetEnv "Booted OS-Flags"     "BOOTED_OSFLAGS"
$ wso ""
$ CALL GetEnv "Enable Audit"        "ENABLE_AUDIT"
$ CALL GetEnv "License"             "LICENSE"
$ CALL GetEnv "Language"            "LANGUAGE"
$ CALL GetEnv "Character Set"       "CHAR_SET"
$ CALL GetEnv "TTY Device"          "TTY_DEV"
$ wso F$FAO("!80*-!/")
$ !
$Done:
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
