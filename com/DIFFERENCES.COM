$ ! DIFFERENCES.COM -- driver for more esoteric DIFFERENCES use
$ !
$ !  use: @differences option file1 [file2] [qualifiers]
$ !
$ SET NOON
$D0:
$ IF p2 .NES. "" THEN GOTO D1
$ READ /END_OF_FILE=done -
       /PROMPT="File? " -
       sys$command p2
$ GOTO D0
$D1:
$ GOTO 'F$EXTRACT(0,1,p1)'$
$ !
$B$:  ! binary file comparisons
$ ascii = ""
$ IF    F$FILE_ATTRIBUTES(p2,"ORG") .EQS. "SEQ" -
  .AND. F$FILE_ATTRIBUTES(p2,"RAT") .EQS. "CR"  -
  .AND. F$FILE_ATTRIBUTES(p2,"RFM") .EQS. "VAR" -
  THEN  ascii = ",ASCII"
$ DIFFERENCES 'p2' 'p3'        -
    /MODE=(HEXADECIMAL'ascii') -
    /CHANGE_BAR=(»,NUMBER) 'p4'
$ GOTO done
$ !
$C$:  ! fancy change bars on ASCII files
$ comment = ""
$ IF F$PARSE(p2,,,"TYPE","SYNTAX_ONLY") .EQS. ".PAS" -
  THEN  comment = "=({,})"
$ DIFFERENCES  'p2' 'p3'                         -
    /COMMENT_DELIMITER'comment'                  -
    /IGNORE=(PRETTY,BLANK_LINES,COMMENTS,        -
             FORM_FEEDS,TRAILING_SPACES,SPACING) -
    /CHANGE_BAR=(»,NONUMBER) 'p4'
$ GOTO done
$ !
$P$:
$ @com:scrwidth 132
$ DIFFERENCES  'p2' 'p3'                         -
    /IGNORE=(EXACT,BLANK_LINES,COMMENTS,         -
             FORM_FEEDS,TRAILING_SPACES,SPACING) -
     /PARALLEL 'p4'
$ GOTO done
$ !
$S$:
$ slp = p2 - F$PARSE(p2,,,"TYPE","SYNTAX_ONLY") + ".SLP"
$ DIFFERENCES 'p2' /SLP /OUTPUT='slp'
$ WRITE sys$output "%DIFFERENCES-I-SLPOUT, ''slp' created"
$ GOTO done
$ !
$done:
$ EXIT
