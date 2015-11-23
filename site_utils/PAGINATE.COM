$ ! PAGINATE.COM --                                                'F$VERIFY(0)'
$ !
$ IF P1 .EQS. "" -
  THEN READ /END_OF_FILE=Done -
            /PROMPT="File to paginate: " -
            sys$command P1
$ P0  = F$SEARCH(P1)
$ IF P0 .EQS. ""
$ THEN WRITE sys$error "%PAGINATE-E, file ''P1' not found"
$      EXIT
$ ENDIF
$ dev = F$PARSE(P0,,,"DEVICE","SYNTAX_ONLY")
$ dir = F$PARSE(P0,,,"DIRECTORY","SYNTAX_ONLY")
$ nam = F$PARSE(P0,,,"NAME","SYNTAX_ONLY")
$ lis = "sys$disk:[]" + nam + ".lis"
$ pag = dev + dir + nam + ".page"
$ IF F$TRNLNM("ked$paginate") .EQS. "" -
  THEN  DEFINE /USER_MODE ked$paginate 'pag'
$ IF F$SEARCH("ked$paginate") .EQS. ""
$ THEN WRITE sys$error "%PAGINATE-E, cannot find paginate file ", -
                       F$TRNLNM("ked$paginate")
$      EXIT
$ ENDIF
$ IF F$TRNLNM("ked$firstpage") .EQS. "" -
  THEN  DEFINE /USER_MODE ked$firstpage "1"
$ !
$ IF P2 .NES. "" THEN GOTO Edit
$ DEFINE /USER_MODE sys$error  nl:
$ DEFINE /USER_MODE sys$output nl:
$Edit:
$ DEFINE ked$paginate_output 'lis'
$ EDIT /TPU /NODISPLAY /NOSECTION -
       /COMMAND=sys$input /OUTPUT='lis' 'P0'

CONSTANT
  NULL  := "",
  FALSE := 0,
  TRUE  := 1,
  K$_ff  := ASCII( 12 ),
  K$_tab := ASCII(  9 ),
  K$_spc := ASCII( 32 ),
  K$_dquote := ASCII(  34 ),  !double quote "
  K$_squote := ASCII(  39 ),  !single quote '
  K$_spc_tab  := K$_spc + K$_tab,
  LETTERS := "AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz",
  DIGITS := "0123456789";

PROCEDURE Initialize
  GV$_Xstr := NULL;
  GV$_LSEmeta := "$";
  inf := GET_INFO( COMMAND_LINE, "FILE_NAME" );
  Source_Buffer := CREATE_BUFFER( "Source", inf );
  POSITION( Source_Buffer );
  SET( MODIFIED, CURRENT_BUFFER, OFF );  !don't write source buffer
  List_Buffer := CREATE_BUFFER( "List" );
  outf := GET_INFO( COMMAND_LINE, "OUTPUT_FILE" );
  SET( OUTPUT_FILE, List_Buffer, outf );
  $$SCRATCH_BUFFER := CREATE_BUFFER( "$$SCRATCH" );
  SET( MODIFIED, $$SCRATCH_BUFFER, OFF );
  $$LSE_BUFFER := CREATE_BUFFER( "$$LSE", "ked$paginate" );
  SET( MODIFIED, $$LSE_BUFFER, OFF );
  Top_Buffer := CREATE_BUFFER( "Top" );
  SET( MODIFIED, Top_Buffer, OFF );
  Bottom_Buffer := CREATE_BUFFER( "Bottom" );
  SET( MODIFIED, Bottom_Buffer, OFF );
ENDPROCEDURE  !Initialize


! Procedures from KED:

PROCEDURE KED$LSE_Replace( arg1, arg2, buf )
LOCAL rm, here, tar;
  here := MARK( NONE );
  rm := GET_INFO( buf, "MODE" );
  SET( INSERT, buf );
  POSITION( BEGINNING_OF( buf ) );
  tar := SEARCH_QUIETLY( arg1, FORWARD );
  IF ( tar <> 0 ) THEN
    POSITION( BEGINNING_OF( tar ) );
    ERASE( tar );
    COPY_TEXT( arg2 );
  ENDIF;
  SET( rm, buf );
  POSITION( here );
ENDPROCEDURE  !KED$LSE_Replace

PROCEDURE F$ELEMENT ( n, Sep, Strg )
LOCAL i, j, E, S;
  i := -1;
  j := n;
  E := Sep;
  S := Strg + Sep;
  LOOP
    EXITIF ( j < 0 ) OR ( i = 0 );
    i := INDEX( S, Sep );
    IF ( i > 0 ) THEN
      j := j - 1;
      E := SUBSTR( S, 1, i - 1 );
      S := SUBSTR( S, i + 1, LENGTH( S ) - i );
    ENDIF;
    ENDLOOP;
  !distinguish NULL value from "no such element":
  IF ( i = 0 ) THEN E := Sep; ENDIF;
  RETURN ( E );
ENDPROCEDURE  !F$ELEMENT

PROCEDURE P$_move_L ( dir )
LOCAL offs;
ON_ERROR
ENDON_ERROR
  offs := CURRENT_OFFSET;
  POSITION( LINE_BEGIN );
  IF ( dir = FORWARD ) THEN MOVE_VERTICAL( +1 );
  ELSE IF ( offs = 0 ) THEN MOVE_VERTICAL( -1 ); ENDIF;
  ENDIF;
ENDPROCEDURE  !P$_move_L

PROCEDURE F$_anchored ( pat, ex )
  RETURN ( SEARCH_QUIETLY( ANCHOR + pat, FORWARD, ex ) <> 0 );
ENDPROCEDURE  !F$_anchored

PROCEDURE F$_at_EOB
  RETURN ( MARK( NONE ) = END_OF( CURRENT_BUFFER ) );
ENDPROCEDURE  !F$_at_EOB

PROCEDURE F$_LSE_copy ( line )
LOCAL pat, vr, sr, v;
ON_ERROR
ENDON_ERROR
  POSITION( BEGINNING_OF( $$SCRATCH_BUFFER ) );
  ERASE( $$SCRATCH_BUFFER );
  COPY_TEXT( line );
  ! ignore self-quoted-metachar "$$...", find all "$N"'s for substitution:
  pat := NOTANY( GV$_LSEmeta ) + GV$_LSEmeta + SPAN( DIGITS ) @vr;
  LOOP
    POSITION( LINE_BEGIN );
    sr := SEARCH( pat, FORWARD, EXACT );
    EXITIF ( sr = 0 );                    !no "$N"; done
    v := "$" + SUBSTR( vr, 3, LENGTH( vr ) - 1 );
    GV$_Xstr := NULL;  !clear previous value
    EXECUTE( "GV$_Xstr := " + v ); !retrieve "$N" global var
    POSITION( BEGINNING_OF( vr ) );
    MOVE_HORIZONTAL( +1 );  !compensate: escape-char
    ERASE_CHARACTER( LENGTH( v ) );
    COPY_TEXT( GV$_Xstr );           !substitute
    ENDLOOP;
  POSITION( LINE_BEGIN );
  pat := ( GV$_LSEmeta + GV$_LSEmeta ) @vr;
  LOOP  !replace quoted metachar with single metachar
    sr := SEARCH( pat, FORWARD, EXACT );
    EXITIF ( sr = 0 );
    POSITION( BEGINNING_OF( vr ) );
    ERASE_CHARACTER( +1 );  !the quote "$"
    MOVE_HORIZONTAL( +1 );  !over the final "$"
    ENDLOOP;
  F$_LSE_copy := CURRENT_LINE;
ENDPROCEDURE  !F$_LSE_copy

PROCEDURE F$_LSE_get ( line, sl; btok, etok )
LOCAL bt, et;
! returns next line in $$LSE_BUFFER, conditional split-line (if sl > 0),
! and functional TRUE if at a template delimiter ($BEGIN, $END...)
! or FALSE if more template text to process
  IF ( GET_INFO( btok, "TYPE" ) = STRING ) THEN bt := btok;
  ELSE bt := "$BEGIN"; ENDIF;
  IF ( GET_INFO( etok, "TYPE" ) = STRING ) THEN et := etok;
  ELSE et := "$END"; ENDIF;
  P$_move_L( FORWARD );
  IF ( NOT F$_at_EOB ) THEN
    line := CURRENT_LINE;
    sl := NOT F$_anchored( et + "$", NO_EXACT );
    F$_LSE_get := F$_anchored( bt, NO_EXACT )
               OR F$_anchored( et, NO_EXACT );
  ELSE line := NULL;
    sl := FALSE;
    F$_LSE_get := TRUE;
  ENDIF;
ENDPROCEDURE  !F$_LSE_get

PROCEDURE P$_LSE_$v
LOCAL id, pat, sr, var, par, def;
  id := LETTERS + DIGITS + K$_spc_tab + K$_dquote + K$_squote
      + "~!@#$%^&*()[]{}-_+;\|,./?";    !can't allow ":=" within prompt
  var := NULL;  par := NULL;  def := NULL;
  pat := ANCHOR + ( GV$_LSEmeta + SPAN( DIGITS ) @var ) + ( SPAN( id ) @par )
       + ( LINE_END | ( MATCH( ":=" ) + ( SPAN( id ) @def ) ) );
  sr := SEARCH_QUIETLY( pat, FORWARD, EXACT );
  IF ( sr <> 0 ) THEN
    par := STR( par );
    def := SUBSTR( def, 1, LENGTH( def ) );  !string or range
    EDIT( par, TRIM, OFF );
    EDIT( def, TRIM, OFF );
    var := "$" + SUBSTR( var, 2, LENGTH( var ) - 1 );
    GV$_Xstr := F$_prompt( par, def, "D", FALSE );
    EXECUTE( var + ":=GV$_Xstr" );  !creates on-the-fly global-var "$N"
  ENDIF;
ENDPROCEDURE  !P$_LSE_$v


PROCEDURE P$_pagecopy ( buf, arg )
LOCAL line, sl;
  IF ( GET_INFO( arg, "TYPE" ) <> STRING ) OR ( arg = NULL ) THEN
    arg := "$END";
  ENDIF;
  ERASE( buf );
  LOOP
    POSITION( $$LSE_BUFFER );
    EXITIF ( F$_LSE_get( line, sl, arg ) );
    line := F$_LSE_copy( line );
    POSITION( buf );
    COPY_TEXT( line );
    IF ( sl ) THEN SPLIT_LINE; ENDIF;
    ENDLOOP;
  POSITION( buf );  !return to end of copied template
  APPEND_LINE;
ENDPROCEDURE  !P$_pagecopy

PROCEDURE P$_pageinit( tmpl )
LOCAL Pbuf, pat, sr, line, sl;
ON_ERROR
[TPU$_STRNOTFOUND,
 TPU$_CONTROLC,
 OTHERWISE]:
  POSITION( Pbuf );  !restore user buffer
  ABORT;
ENDON_ERROR
  Pbuf := CURRENT_BUFFER;
  POSITION( BEGINNING_OF( $$LSE_BUFFER ) );
  pat := LINE_BEGIN + tmpl;
  sr := SEARCH( pat, FORWARD, NO_EXACT );
  IF ( sr <> 0 ) THEN 
    POSITION( BEGINNING_OF( sr ) );
    LOOP  ! acquire any prompted variables
      EXITIF ( F$_LSE_get( line, sl ) );  !found "$BEGIN"
      P$_LSE_$v;
      ENDLOOP;
    P$_pagecopy( Top_Buffer, "$PAGELENGTH" );
    POSITION( $$LSE_BUFFER );
    TopLength    := GET_INFO( Top_Buffer, "RECORD_COUNT" );
    BottomLength := GET_INFO( Bottom_Buffer, "RECORD_COUNT" );
    PageLength   := INT( F$ELEMENT( 1, K$_spc, CURRENT_LINE ) );
    TextLength   := PageLength - TopLength - BottomLength;
    P$_pagecopy( Bottom_Buffer, "$END" );
  ENDIF;
  POSITION( Pbuf );
ENDPROCEDURE  !P$_pageinit


PROCEDURE P$_paginate ( SrcBuf, LisBuf )
LOCAL done, r, i, rng, firstpage;
ON_ERROR
  done := TRUE;  !end of SrcBuf
ENDON_ERROR
  firstpage := TRUE;
  done := FALSE;
  ERASE( LisBuf );
  LOOP
    POSITION( SrcBuf );
    r := MARK( NONE );
    i := 0;
    ff := FALSE;
    done := ( F$_at_EOB );
    EXITIF ( done );
    LOOP
      IF ( SUBSTR( CURRENT_LINE, 1, 1 ) = K$_ff ) THEN
        ff := TRUE;
        ERASE_CHARACTER( +1 );
      ENDIF;
      EXITIF ( i >= TextLength - 1 ) OR ( ff ) OR ( done );
      P$_move_L( FORWARD );
      i := i + 1;
      ENDLOOP;
    MOVE_HORIZONTAL( -1 );
    rng := CREATE_RANGE( r, MARK( NONE ), NONE );
    MOVE_HORIZONTAL( +1 );
    POSITION( END_OF( LisBuf ) );
    COPY_TEXT( Top_Buffer );
    IF ( firstpage ) THEN
      POSITION( BEGINNING_OF( Top_Buffer ) );
      COPY_TEXT( K$_ff );
      firstpage := FALSE;
    ENDIF;
    POSITION( END_OF( LisBuf ) );
    COPY_TEXT( rng );
    i := i + 1;
    POSITION( END_OF( LisBuf ) );
    LOOP
      EXITIF ( i >= TextLength );
      SPLIT_LINE;   ! pad blank lines until flush bottom
      i := i + 1;
      ENDLOOP;
    POSITION( END_OF( LisBuf ) );
    COPY_TEXT( Bottom_Buffer );
    ENDLOOP;
  POSITION( LisBuf );
  APPEND_LINE;
ENDPROCEDURE  !P$_paginate

PROCEDURE P$_pagetokens ( pg, NPCnt )
LOCAL pn;
  ERASE( $$SCRATCH_BUFFER );
  POSITION( $$SCRATCH_BUFFER );
  COPY_TEXT( pg );
  ERASE( pg );
  pn := STR( NPCnt );
  KED$LSE_Replace(  "$PAGE", pn, $$SCRATCH_BUFFER );
  KED$LSE_Replace( "$RPAGE", FAO( "!3SL", NPCnt ), $$SCRATCH_BUFFER );
  CASE LENGTH( pn ) FROM 1 TO 2
    [1]: pn := K$_spc + pn + K$_spc;
    [2]: pn := K$_spc + pn;
    ENDCASE;
  KED$LSE_Replace( "$CPAGE", pn, $$SCRATCH_BUFFER );
  POSITION( END_OF( pg ) );
  COPY_TEXT( $$SCRATCH_BUFFER );
  NPCnt := NPCnt + 1;
ENDPROCEDURE  !P$_pagetokens

PROCEDURE P$_pagecount ( LisBuf, PCnt, NPCnt )
LOCAL rng, pg;
  NPCnt := PCnt;
  POSITION( BEGINNING_OF( LisBuf ) );
  LOOP
    rng := SEARCH_QUIETLY( K$_ff, FORWARD, EXACT );
    EXITIF ( rng = 0 );
    pg := CREATE_RANGE( MARK( NONE ), BEGINNING_OF( rng ), NONE );
    P$_pagetokens( pg, NPCnt );
    MOVE_HORIZONTAL( +1 );  !past the current <ff>
    ENDLOOP;
  pg := CREATE_RANGE( MARK( NONE ), END_OF( LisBuf ), NONE );
  P$_pagetokens( pg, NPCnt );
ENDPROCEDURE  !P$_pagecount


! main procedure

  Initialize;
  P$_pageinit( "$PAGINAT" );
  P$_paginate( Source_Buffer, List_Buffer );
  PCount := FILE_PARSE( "ked$firstpage", NULL, NULL, NAME );
  NextPCount := 0;
  IF ( PCount = NULL ) THEN PCount := 1; ELSE PCount := INT( PCount ); ENDIF;
  P$_pagecount( List_Buffer, PCount, NextPCount );
  WRITE_FILE( List_Buffer, outf );
  SPAWN( "$ DEFINE /NOLOG /JOB ked$nextpage " + STR( NextPCount ) );
  QUIT;

$Done:
$ EXIT $STATUS
