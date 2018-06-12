$ ! SHOWMEMORY.COM                                                 'F$VERIFY(0)
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
$ IF ( F$TYPE( DCL$CALL ) .EQS. "" ) .OR. ( ReLogin )
$ THEN @lmr$login:DCL$SUBROUTINE_LIBRARY Setup TRUE
$ ENDIF
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO SM$Done
$ !
$ Verbose = ( F$EXTRACT( 0, 1, F$EDIT( P1, "COLLAPSE,UPCASE" ) ) .EQS. "V" )
$ wso     = "WRITE sys$output"
$ !
$ Fac        = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ Node       = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ COMMA      = ","
$ header     = "RAM [4m       Total         Free       In Use     Modified[0m"
$ fldlen     = 11
$ !
$ mainmemory = F$GETSYI("MAIN_MEMORY")
$ memMod     = F$INTEGER( "%X''F$EXTRACT(  0, 8, mainmemory )'" )
$ memInUse   = F$INTEGER( "%X''F$EXTRACT(  8, 8, mainmemory )'" )
$ memFree    = F$INTEGER( "%X''F$EXTRACT( 16, 8, mainmemory )'" )
$ memTotal   = F$INTEGER( "%X''F$EXTRACT( 24, 8, mainmemory )'" )
$ DCL$CALL Thousands SM$memMod   "''memMod'"
$ DCL$CALL Thousands SM$memInUse "''memInUse'"
$ DCL$CALL Thousands SM$memFree  "''memFree'"
$ DCL$CALL Thousands SM$memTotal "''memTotal'"
$ ModLen   = F$LENGTH( SM$memMod )
$ InUseLen = F$LENGTH( SM$memInUse )
$ FreeLen  = F$LENGTH( SM$memFree )
$ TotalLen = F$LENGTH( SM$memTotal )
$ !
$ ! Given DCL's arithmetic (32-bit integers, watch for overflows),
$ !  the following is approximate only --
$ IF ( F$GETSYI( "ARCH_NAME" ) .EQS. "VAX" )
$ THEN pagesize     =  512  ! bytes per page, 32-bit architecture
$      architecture = "32-bit"
$ ELSE pagesize     = 8192  !   "    "   "  , 64-bit architecture
$      architecture = "64-bit"
$ ENDIF
$ SPlen = F$LENGTH( F$STRING( memTotal ) )
$ GOTO SP'SPlen'  ! ...simplest way to break down ranges...
$SP6:
$SP7:
$SP8:
$SP9:
$ TotalRAM = ( ( memTotal / 1024 ) * pagesize ) / 1024 / 1000
$ UnitsRAM = "GB"
$ GOTO SP0
$ !
$SP3:
$SP4:
$SP5:
$ TotalRAM = ( memTotal / 1024 ) * pagesize / 1000
$ UnitsRAM = "MB"
$ GOTO SP0
$ !
$SP1:
$SP2:
$ TotalRAM = ( memTotal * pagesize ) / 1024
$ UnitsRAM = "KB"
$ GOTO SP0
$ !
$SP0:
$ !
$ IF Verbose
$ THEN SHOW SYMBOL /LOCAL mainmemory
$      SHOW SYMBOL /LOCAL mem*
$      wso ""
$      SHOW MEMORY /PHYSICAL
$ ENDIF
$ wso ""
$ wso header
$ wso F$FAO( "!5* !#* !8AS !#* !8AS !#* !8AS !#* !8AS", -
             fldlen-TotalLen, SM$memTotal, -
             fldlen-FreeLen,  SM$memFree,  -
             fldlen-InUseLen, SM$memInUse, -
             fldlen-ModLen,   SM$memMod    )
$ wso "''Node' -- Total RAM: ~''TotalRAM' ''UnitsRAM'"
$ wso F$FAO( "!#* !AS architecture, !SL-byte page size", -
             F$LENGTH(Node) + 4, architecture, pagesize )
$ wso ""
$ !
$SM$Done:
$ DCL$CALL DeleteGloSyms "SM$Free,SM$InUse,SM$Mod,SM$Total"
$ EXIT 1  ! 'F$VERIFY(0)
$ !
