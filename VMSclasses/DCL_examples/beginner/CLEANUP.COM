$ ! GOOD_CLEANUP.COM --                                            'F$VERIFY(0)'
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Cleanup
$ !
$ ! ... Command processing goes here...
$ OPEN /ERROR=Cleanup infile sys$login:SomeData.dat
$ InternalGlobalSymbol == "We opened the file!..."
$ !
$Cleanup:
$ IF F$TYPE(InternalGlobalSymbol) .NES. "" -
  THEN DELETE /SYMBOL /GLOBAL InternalGlobalSymbol
$ !
$ IF F$TRNLNM("infile") .NES. "" THEN CLOSE infile
$ !
$ EXIT 1
$ !
$Ctrl_Y:
$ RETURN %X2C
