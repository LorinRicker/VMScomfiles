$ ! DELSYMBOLS.COM -- Deletes site-specific "garbage" symbols      'F$VERIFY(0)'
$ !
$ ! P1: "YES" to re-define E&R/personal symbols
$ !
$ DEFINE = "DEFINE"
$ DEFINE /USER_MODE sys$output nl:
$ DEFINE /USER_MODE sys$error  nl:
$ DELETE /SYMBOL /GLOBAL /ALL
$ !
$ IF P1
$ THEN IF F$TRNLNM("mgr$login")             .NES. "" THEN @mgr$login
$      IF F$TRNLNM("site$sylogin")          .NES. "" THEN @site$sylogin
$      IF F$TRNLNM("sys$sylogin")           .NES. "" THEN @sys$sylogin
$      IF F$SEARCH("lmr$login:symbols.com") .NES. "" THEN @lmr$login:symbols
$      IF F$SEARCH("com:tpu.com")           .NES. "" THEN @com:tpu
$ ENDIF
$ EXIT
