$ ! FIXPRIVS.COM --                                                'F$VERIFY(0)'
$ !
$ ! Change/restore an intentionally privileged user account
$ ! from ALL privs to SETPRV,OPER,TMPMBX,NETMBX for more
$ ! safe and rational privilege use.
$ !
$ ! use:  @FIXPRIV username
$ !
$ ON ERROR THEN GOTO FPAbort
$ !
$ super = "SETPRV,OPER,TMPMBX,NETMBX"
$ !
$L0:
$ IF ( P1 .EQS. "" )
$ THEN READ sys$command uname /PROMPT="Username: " /END_OF_FILE=FPAbort
$      IF ( uname .EQS. "" ) THEN GOTO L0
$ ELSE uname = P1
$ ENDIF
$ !
$ SHOW LOGICAL sysuaf
$ READ sys$command answer /PROMPT="Okay to continue [y,N]? " /END_OF_FILE=FPAbort
$ answer = F$PARSE(F$EDIT(answer,"TRIM,UPCASE"),"No",,"NAME","SYNTAX_ONLY")
$ IF .NOT. answer THEN GOTO FPAbort
$ !
$ READ sys$command pwdlife /PROMPT="Pwd life [no change, or 0, 365, etc]? "
$ IF ( F$EXTRACT(0,2,F$EDIT(pwdlife,"TRIM,UPCASE")) .EQS. "NO" ) THEN pwdlife = ""
$ !
$ here = F$ENVIRONMENT("DEFAULT")
$ prv  = F$SETPRV("SYSPRV")
$ SET DEFAULT sys$system
$ MCR AUTHORIZE modify 'uname' -
                  /PRIV=(NOALL,'super') -
                  /DEFPRIV=(NOALL,'super')
$ IF ( pwdlife .NES. "" ) -
  THEN MCR AUTHORIZE modify 'uname' /PWDLIFE="''pwdlife'-"
$ MCR AUTHORIZE show 'uname'
$ !
$Done:
$ IF F$TYPE(here) .EQS. "STRING" THEN SET DEFAULT 'here'
$ IF F$TYPE(prv)  .EQS. "STRING" THEN prv = F$SETPRV("''prv'")
$ EXIT 1
$ !
$FPAbort:
$ IF F$TYPE(here) .EQS. "STRING" THEN SET DEFAULT 'here'
$ IF F$TYPE(prv)  .EQS. "STRING" THEN prv = F$SETPRV("''prv'")
$ EXIT %X2C
$ !
