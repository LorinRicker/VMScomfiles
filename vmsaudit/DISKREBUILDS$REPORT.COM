$ ! DISKREBUILDS$REPORT.COM --                                     'F$VERIFY(0)'
$ !
$ ! Copyright © 2018 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ !  Create spreadsheet inventories (CSV) of all disks
$ !
$ !  use: @DISKREBUILDS$REPORT [disk[,disk]...]
$ !
$ !       If P1 is a comma-separated list of disk names, then only these devices
$ !       are checked, otherwise all physical (non-DSA) devices are checked
$ !
$ !  Run this com-file without /OUTPUT=filespec to see the report on your terminal;
$ !  use /OUTPUT=filespec to save the report to a comma-separated report file which
$ !  can be imported into an Excel/Calc spreadsheet.
$ !
$ !
$ ! === MAIN ===
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO DR$Exit
$ !
$ VMS$ver  = F$EDIT(F$GETSYI("VERSION"),"TRIM")
$ minVMS80 = ( VMS$ver .GES. "V8.0" ) 
$ !
$ Verbose = F$TRNLNM( "TOOLS$DEBUG" )
$ !
$ DD$Disks  == ""
$ wso        = "WRITE sys$output"
$ wse        = "WRITE sys$error"
$ Fac        = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ Node       = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ COMMA      = ","
$ DOLLAR     = "$"
$ SLASH      = "/"
$ SPACE      = " "
$ SPC5       = SPACE + SPACE + SPACE + SPACE + SPACE
$ UNDERSCORE = "_"
$ !
$ tmpfile = "sys$scratch:DR$" + Fac + ".tmp" - "$REPORT"
$ !
$ alloclass = DOLLAR + F$STRING( F$GETSYI( "ALLOCLASS" ) ) + DOLLAR
$ !
$ devfldlen = 16
$ headfill  = 72
$ !
$ headln = F$FAO( "-- Device/Volume Rebuilds !#*-", headfill )
$ !
$ wso F$FAO( "%!AS-I-DEV-REBUILDS, Device/Volume Rebuilds Needed on !AS", Fac, Node )
$ wso ""
$ wso headln
$ !
$ InfoUnavailable = "Information unavailable"
$ SDHeader        = "Rebuild needed?"
$ !
$ AnyRebuildNeeded = 0
$ !
$ prv = F$SETPRV( "SYSPRV,VOLPRO" )
$ SHOW DEVICE /REBUILD_STATUS D /OUTPUT='tmpfile'
$ IF ( F$SEARCH( tmpfile ) .EQS. "" ) THEN GOTO DR$tmp_error
$ !
$ OPEN /READ /SHARE f 'tmpfile'
$ loopcnt = 0
$ devcnt  = 0
$DR$Loop1:
$ READ f record /END_OF_FILE=DR$Cont1
$ recl = F$LENGTH( record )
$ IF ( F$LOCATE( InfoUnavailable, record ) .LT. recl ) -
    .OR. ( F$LOCATE( SDHeader, record )    .LT. recl ) -
  THEN GOTO DR$Loop1    ! just skip no-info devices
$ devcnt = devcnt + 1
$ compRec = F$EDIT( record, "TRIM,COMPRESS,UPCASE" )
$ volume  = F$ELEMENT( 0, SPACE, compRec )
$ RebuildNeeded    = ( F$ELEMENT( 1, SPACE, compRec ) .EQS. "YES" )
$ AnyRebuildNeeded = AnyRebuildNeeded .OR. RebuildNeeded
$ wso F$FAO( "!3SL. !AS", devcnt, record )
$ loopcnt = loopcnt + 1
$ GOTO DR$Loop1
$ !
$DR$Cont1:
$ CLOSE /NOLOG f
$ !
$ wso F$FAO( "!#*-", F$LENGTH( headln ) )
$ wso ""
$ !
$ IF AnyRebuildNeeded
$ THEN READ sys$command answer /PROMPT="  Rebuild volumes now [y/N]? "
$      answer = F$PARSE( answer, "No", , "NAME", "SYNTAX_ONLY" )
$      IF answer
$      THEN OPEN /READ /SHARE f 'tmpfile'
$           loopcnt = 0
$           devcnt  = 0
$DR$Loop2:
$           READ f record /END_OF_FILE=DR$Cont2
$           recl = F$LENGTH( record )
$           IF ( F$LOCATE( InfoUnavailable, record ) .LT. recl ) -
              .OR. ( F$LOCATE( SDHeader, record )    .LT. recl ) -
            THEN GOTO DR$Loop2    ! just skip no-info devices
$           compRec = F$EDIT( record, "TRIM,COMPRESS,UPCASE" )
$           volume  = F$ELEMENT( 0, SPACE, compRec )
$           RebuildNeeded = ( F$ELEMENT( 1, SPACE, compRec ) .EQS. "YES" )
$           IF RebuildNeeded
$           THEN devcnt = devcnt + 1
$                wso F$FAO( "!3SL. !AS", devcnt, record )
$                READ sys$command answer -
                   /PROMPT="''SPC5'Rebuild this volume ''volume' now [y/N]? "
$                answer = F$PARSE( answer, "No", , "NAME", "SYNTAX_ONLY" )
$                IF answer
$                THEN wso "''SPC5'Rebuilding volume ''volume'..."
$                     IF Verbose
$                     THEN wso F$FAO( "%!AS-E-ECHO, $ SET VOLUME /REBUILD !AS", Fac, volume )
$                     ELSE SET VOLUME /REBUILD 'volume'
$                     ENDIF
$                     wso ""
$                ENDIF
$           ENDIF
$           loopcnt = loopcnt + 1
$           GOTO DR$Loop2
$DR$Cont2:
$      CLOSE /NOLOG f
$      ENDIF
$ ENDIF
$ !
$DR$Exit:
$ CLOSE /NOLOG f
$ IF ( F$TYPE( prv ) .EQS. "STRING" ) THEN prv = F$SETPRV( prv )
$ IF .NOT. Verbose
$ THEN DELETE /NOLOG 'tmpfile';*
$      DCL$CALL DeleteGloSyms "DD$Disks"
$ ENDIF
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$DR$tmp_error:
$ wse F$FAO( "%!AS-E-ERROPEN, error opening temp-file !AS", Fac, tmpfile )
$ GOTO DR$Exit
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
