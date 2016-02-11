$ ! LOGIN.COM -- "My" login script -- template version             'F$VERIFY(0)'
$ !
$ GOTO 'F$MODE()'
$ !
$ ! ==========
$INTERACTIVE:
$ SET TERMINAL /INQUIRE
$ !
$ ! Interactive login process definitions go here...
$ !
$ EXIT    ! 'F$VERIFY(0)'
$ !
$ ! ==========
$BATCH:
$ !
$ ! Batch job definitions, if any, go here...
$ ! (Why don't we do a SET TERMINAL command here?)
$ !
$ EXIT    ! 'F$VERIFY(0)'
$ !
$ ! ==========
$NETWORK:
$OTHER:
$ ! This section is rarely, if ever, used...
$ !
$ EXIT    ! 'F$VERIFY(0)'
$ !
