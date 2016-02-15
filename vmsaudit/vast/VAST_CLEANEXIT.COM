$ ! VAST_CLEANEXIT.COM --                                         'F$VERIFY(0)'
$ !
$ !  Clean-up service routine --
$ !     @VAST_CLEANEXIT
$ !
$ !  Clean-up entire VAST_* environment, including
$ !  deletion of AUD*$* global symbols:
$ !
$ ! Copyright (C) 2012-2013 Lorin Ricker <lorin@rickernet.us>
$ ! Version: 2.0, 05/17/2013
$ !
$ ! This program is free software, under the terms and conditions of the
$ ! GNU General Public License published by the Free Software Foundation.
$ !
$ ! -----
$DelGloSyms:  SUBROUTINE
$ ! P1 : Global symbol name prefix (e.g., "AUD$" or "VAST_", etc.)
$ !
$ ! Rather than a conditional DEL/SYM/GLO for each AUD$* global symbol
$ ! (i.e.: IF F$TYPE(AUD$Arch) .NES. "" THEN DELETE /SYMBOL /GLOBAL AUD$Arch),
$ ! spool 'em all out to a file and spin through it to get 'em all:
$ !
$ SET NOON
$ tmpfile = "SYS$DISK:[]VAST_globals.tmp"
$ DEFINE /PROCESS /NOLOG sys$output 'tmpfile'
$ DEFINE /PROCESS /NOLOG sys$error  'tmpfile'
$ SHOW SYMBOL /GLOBAL 'P1'*
$ DEASSIGN /PROCESS sys$error
$ DEASSIGN /PROCESS sys$output
$ !! «» IF Debugging THEN TYPE /PAGE 'tmpfile'
$ !
$ ON CONTROL_Y THEN GOSUB DGSCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ OPEN /READ /ERROR=DGSOpenErr tmp 'tmpfile'
$CE0:
$ READ /END_OF_FILE=CE1 tmp gsline
$ gs = F$EDIT(F$ELEMENT(0,EQUAL,gsline),"COLLAPSE")
$ !! «» IF Debugging THEN wso F$FAO( "%!AS-I-DEBUG, DELETE /SYMBOL /GLOBAL ""!AS""", Fac, gs )
$ IF F$TYPE('gs') .NES. "" THEN DELETE /SYMBOL /GLOBAL 'gs'
$ GOTO CE0
$CE1:
$ IF F$TRNLNM("tmp") .NES. "" THEN CLOSE /DISPOSITION=DELETE tmp
$ IF Debugging
$ THEN msg  = F$FAO( "%!AS-I-SHOWSYMBOLS, ", Fac )
$      msgL = F$LENGTH(msg)
$      wserr F$FAO( "!ASconfirming $ DELETE /SYMBOL /GLOBAL !AS*...", msg, P1 )
$      wserr F$FAO( "!#* all !AS* symbols should be gone...", msgL, P1 )
$      SHOW SYMBOL /GLOBAL 'P1'*
$ ENDIF
$ EXIT 1
$ !
$DGSOpenErr:
$ Stat = $STATUS
$ wso F$FAO( "%!AS-E-OPENERR, error opening temp-file !AS", Fac, tmpfile )
$ EXIT 'Stat'
$ !
$DGSCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! DelGloSyms
$ ! -----
$ !
$ !
$ ! === Main ===
$Main:
$ SET NOON
$ !
$ Debugging = F$TRNLNM("TOOLS$DEBUG")
$ !
$ ! Capture SysMgr privileges so the global symbol can delete:
$ IF F$TYPE(AUD$Privs) .NES. "" THEN prvs = AUD$Privs
$ !
$!! $ IF F$TRNLNM("AUD$IDOSD","LNM$PROCESS")    .NES. "" THEN DEASSIGN /PROCESS AUD$IDOSD
$!! $ IF F$TRNLNM("AUD$PAGESWAP","LNM$PROCESS") .NES. "" THEN DEASSIGN /PROCESS AUD$PAGESWAP
$ !
$ ! Next-to-Last-Thing before full exit --
$ CALL DelGloSyms "AUD$"
$ CALL DelGloSyms "AUDIT$"
$ !
$Done:
$ ! Last-Thing before full exit --
$ ! Rescind all SysMgr privileges:
$ IF F$TYPE(prvs) .NES. "" THEN prvs = F$SETPRV(prvs)
$ EXIT %X1
