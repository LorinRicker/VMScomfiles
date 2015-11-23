$ ! TYPECOM.COM -- resolve a DCL symbol definition;                'F$VERIFY(0)'
$ !                if it refers to an "@filename.COM", then type the file...
$ !
$ !  Copyright © 2000-2014 by Lorin Ricker.  All rights reserved.
$ !  Copyright © 1986-2000 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !      use: @TYPECOM foreign_command_symbol
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON WARNING THEN GOTO NoCom
$ wso = "WRITE sys$output"
$ !
$ Ver = F$TRNLNM("Tools$Debug")
$ sver = 0
$ IF Ver THEN sver = F$VERIFY(1)
$ !
$ IF P1 .EQS. "" THEN GOTO Done
$ !
$ Sym = &P1
$ IF Ver THEN SHOW SYMBOL /LOCAL Sym
$ IF F$EXTRACT(0,1,Sym) .NES. "@" THEN GOTO NoCom
$ Sym = Sym - "@"
$ F   = Sym
$ Sym = F$SEARCH( Sym )
$ IF Ver THEN SHOW SYMBOL /LOCAL Sym
$ IF ( Sym .EQS. "" )
$ THEN wso F$FAO( "%TYPECOM-E-FNF, file not found: !AS", F )
$      GOTO Done
$ ENDIF
$ !
$ wso F$FAO("!80*-")
$ DIRECTORY /SIZE /DATE /PROT 'Sym'
$ wso ""
$ SHOW SYMBOL /GLOBAL 'P1'
$ IF Ver THEN SHOW SYMBOL Sym
$ wso ""
$ wso F$FAO("!80*-")
$ !
$T0:
$ TYPE /PAGE 'Sym'
$ wso F$FAO("!80*-")
$ GOTO Done
$ !
$NoCom:
$ wso "%TYPECOM-E-NOCOMFILE, ""''P1'"" is not a command file reference"
$ !
$Done:
$ EXIT 1   ! 'F$VERIFY(sver)'
$ !
$Ctrl_Y:
$ RETURN %X2C
