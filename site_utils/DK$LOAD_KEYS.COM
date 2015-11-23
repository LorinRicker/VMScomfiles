$ ! DK$LOAD_KEYS.COM -- load User Definable Keys on VT220/VT240 terminals
$ !
$ !  use:  @DK$LOAD_KEYS [Key] [Value] [Output]
$ !   or:  @DK$LOAD_KEYS @Filespec
$ !
$ ! Key:        F6 through F20 or HELP or DO; prompt for Key.
$ ! Value:      Any string of characters; Control characters
$ !             can be included in Value using `x (CTRL/x);
$ !             Prompt for Value.
$ ! Output:     Output file for load sequences; Must already be open;
$ !             Default is sys$output.
$ ! Filespec:   Input file of records which include Key-Value pairs.
$ !
$ esc[0,8]= 27
$ DCS = esc + "P"
$ ST  = esc + "\"
$ !
$ Key = P1
$ Val = P2
$ IF P3 .EQS. "" THEN P3 = "sys$output"
$M0:
$ IF F$EXTRACT(0,1,Key) .EQS. "@" THEN GOTO Indirect
$ IF Key .NES. "" THEN GOTO M1
$ READ /PROMPT="Key: " /END_OF_FILE=C0 sys$command Key
$ GOTO M0
$M1:
$ IF Val .NES. "" THEN GOTO M2
$ READ /PROMPT="Definition for ''Key': " /END_OF_FILE=C0 sys$command Val
$ GOTO M1
$M2:
$ CALL udf 'Key' "''Val'" 'P3'
$ GOTO C0
$Indirect:
$ Input_File = F$PARSE(Key-"@",".DEF",,,"SYNTAX_ONLY")
$ OPEN /READ /ERROR=C2 dk-definition 'Input_File'
$ !
$I1:
$ READ /END_OF_FILE=C0 dk-definition Rec
$ Rec = F$EDIT(Rec,"UNCOMMENT,COMPRESS")
$ IF Rec .EQS. "" THEN GOTO I1
$ Key = F$ELEMENT(0," ",Rec)
$ Val = Rec - Key - " "
$ CALL udf 'Key' "''Val'" 'P3'
$ GOTO I1
$ !
$c0:
$ IF F$TRNLNM("dk-definition") .NES. "" THEN CLOSE dk-definition
$ EXIT
$ !
$C2:
$ UTIL_FILNOTFND = %X0803896A
$ WRITE sys$error F$FAO(F$MESSAGE(UTIL_FILNOTFND),Input_File)
$ EXIT %X10000000 .OR. UTIL_FILNOTFND
$ !
$udf:    SUBROUTINE
$ !     P1 is the key name
$ !     P2 is the string to load
$ !     P3 is the output file
$ Fkey = F$EDIT(P1,"COLLAPSE,UPCASE") - "F"  !convert "Fnn" to "nn"
$ ON WARNING THEN GOTO no_key
$ GOTO 'Fkey'$
$ !
$ ! key aliases:
$HELP$:
$ Fkey = "15"
$ GOTO 'Fkey'$
$DO$:
$ Fkey = "16"
$ GOTO 'Fkey'$
$ !
$6$:
$7$:
$8$:
$9$:
$10$:
$ keyn = F$INTEGER(Fkey) + 11
$ GOTO load_key
$ !
$11$:
$12$:
$13$:
$14$:
$ keyn = F$INTEGER(Fkey) + 12
$ GOTO load_key
$ !
$15$:
$16$:
$ keyn = F$INTEGER(Fkey) + 13
$ GOTO load_key
$ !
$17$:
$18$:
$19$:
$20$:
$ keyn = F$INTEGER(Fkey) + 14
$ GOTO load_key
$ !
$load_key:
$! val = F$EDIT(P2,"TRIM")
$ udf = DCS + "1;1|" + F$STRING(keyn) + "/"
$ i   = -1
$ ctl =  0
$ !
$loop:
$ i = i + 1
$ IF i .GE. F$LENGTH(val) THEN GOTO load_it
$ chr = F$EXTRACT(i,1,val)       !next char
$ IF (ctl .EQ. 0) .AND. (chr .EQS. "`") THEN GOTO L1
$ IF ctl .EQ. 64 THEN chr = F$EDIT(chr,"UPCASE")
$ IF chr .EQS. "`" THEN ctl = 0
$ dec = F$CVUI(0,8,chr) - ctl
$ udf = udf + F$FAO("!XB",dec)   !build (more) string, hex-digit format
$ ctl = 0
$ GOTO loop
$L1:
$ ctl = 64
$ GOTO loop
$ !
$load_it:
$ udf = udf + ST
$ WRITE 'P3' udf
$ GOTO L0
$ !
$no_key:
$ UTIL_KEYNAME = %X08038658
$ WRITE sys$error F$FAO(F$MESSAGE(UTIL_KEYNAME),key)
$ !
$L0:
$ ENDSUBROUTINE
