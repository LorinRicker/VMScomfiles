$ ! AUDIT_PROCESS_TERMINATION.COM --                 'F$VERIFY(0)'
$ !
$ ! Copyright © 2017 by Lorin Ricker.  All rights reserved, with acceptance,
$ ! use, modification and/or distribution permissions as granted and controlled
$ ! by and under the GPL described herein.
$ !
$ ! This program (software) is Free Software, licensed under the terms and
$ ! conditions of the GNU General Public License Version 3 as published by
$ ! the Free Software Foundation: http://www.gnu.org/copyleft/gpl.txt,
$ ! which is hereby incorporated into this software and is a non-severable
$ ! part thereof.  You have specific rights and obligations under this GPL
$ ! which are binding if and when you accept, use, modify and/or distribute
$ ! this software program (source code file) and/or derivatives thereof.
$ !
$ !  Enable/Disable VMS Audit Server's PROCESS=(DELPRC,FORCEX) audit events.
$ !
$ !  use:  @AUDIT_PROCESS_TERMINATION [ Enable | Disable ]
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Proc = F$ENVIRONMENT("PROCEDURE")
$ Fac  = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ wso  = "WRITE sys$output"
$ !
$ AS$setting = "PROCESS=(DELPRC,FORCEX)"
$ !
$ IF ( P1 .EQS. "" )
$ THEN READ sys$command P1 /END_OF_FILE=Done -
         /PROMPT="Enable or Disable PROCESS=(DELPRC,FORCEX) [ENABLE]? "
$ ENDIF
$ P1 = F$PARSE( P1, "Enable", , "NAME" )
$ P1 = F$EXTRACT( 0, 1, F$EDIT( P1, "TRIM,UPCASE" ) )
$ !
$ prv = F$SETPRV( "SECURITY" )
$ !
$ IF ( P1 .EQS. "E" )
$ THEN SET AUDIT /AUDIT /ENABLE='AS$setting'
$ ELSE IF ( P1 .EQS. "D" )
$      THEN SET AUDIT /AUDIT /DISABLE='AS$setting'
$      ELSE wso "%''Fac'-E-NOCHANGE, bad choice, no change to Audit Server settings"
$      ENDIF
$ ENDIF
$ !
$Done:
$ SHOW AUDIT
$ IF ( F$TYPE( prv ) .EQS. "STRING" ) THEN prv = F$SETPRV( prv )
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
