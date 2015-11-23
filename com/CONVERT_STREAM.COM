$ ! CONVERT_STREAM.COM -- converts stream ASCII files (containing embedded
$ !                       <CR><LF>'s) to proper VMS text files.
$ !
$ IF P1 .EQS. "" THEN READ /END_OF_FILE=done -
                           /PROMPT="Filespec: " sys$command P1
$ IF P1 .EQS. "" THEN GOTO done
$ !
$Loop:
$ fn = F$SEARCH(P1)
$ IF fn .EQS. "" THEN GOTO done
$ Org = F$FILE_ATTRIBUTES(fn,"ORG")
$ IF Org .NES. "SEQ" THEN GOTO Loop  !File organization: Sequential
$ Rfm = F$FILE_ATTRIBUTES(fn,"RFM")
$ IF Rfm .NES. "FIX" THEN GOTO Loop  !Record format: Fixed 512 byte records
$ Rat = F$FILE_ATTRIBUTES(fn,"RAT")
$ IF Rat .NES. "" THEN GOTO Loop     !Record attributes: None
$ fn = fn - F$PARSE(fn,,,"VERSION","SYNTAX_ONLY")
$ WRITE sys$output "%CONVERT_STREAM-I, converting ''fn'"
$ Cvt /OUTPUT='fn' 'fn'
$ GOTO Loop
$done:
$ EXIT
