$ ! RDBFLAGS.COM -- manage RdB debug-flags logical name            'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2004 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1993-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ! P1: any combination of the flag values "BEnORSsT\";
$ !     "" means deassign the logical name.
$ ! P2: redirect output to a file
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL THEN GOSUB Ctrl_Y
$ !
$ wso = "WRITE sys$output"
$ Fac = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ !
$ P1 = F$EDIT(P1,"COLLAPSE,UPCASE")
$ !
$ IF F$TYPE(RDB_VERSION) .NES. "STRING"
$ THEN RMU /SHOW VERSION /OUTPUT=nla0:  !generate local symbol to test...
$      RDB_VERSION == RMU$RDB_VERSION   !...and make it process-permanent
$ ENDIF
$ NewSetFlags = ( RDB_VERSION .GES. "7.1" )
$ !
$ IF F$LOCATE("?",P1) .LT. F$LENGTH(P1) THEN GOTO Help
$ !
$ IF NewSetFlags
$ THEN GOTO Set_Flags
$ ELSE GOTO Debug_Flags
$ ENDIF
$ !
$Set_Flags:                ! new logical RDMS$SET_FLAGS (v7.1 and higher)
$ FlagKeywords == "BLR                   " -  ! Bcn
               + "|CARDINALITY           " -  ! K
               + "|CONTROL_BITS          " -  ! Bc
               + "|CRONO_FLAG            " -  ! Xc
               + "|DATABASE_PARAMETERS   " -  ! P
               + "|DETAIL                " -  ! (no debug-flags equivalent)
               + "|ESTIMATES             " -  ! O
               + "|EXECUTION             " -  ! E
               + "|IGNORE_OUTLINE        " -  ! I
               + "|ITEM_LIST             " -  ! H
               + "|MBLR                  " -  ! M
               + "|OUTLINE               " -  ! Ss
               + "|PREFIX                " -  ! Bn
               + "|REQUEST_NAMES         " -  ! Sn
               + "|SCROLL_EMULATION      " -  ! L
               + "|SORTKEY_EXT           " -  ! S
               + "|SORT_STATISTICS       " -  ! R
               + "|STRATEGY              " -  ! S
               + "|TRACE                 " -  ! Xt
               + "|TRANSACTION_PARAMETERS"    ! T
$ !
$ IF P1 .EQS. ""
$ THEN IF F$TRNLNM("RDMS$SET_FLAGS","LNM$PROCESS") .NES. ""
$      THEN DEASSIGN /PROCESS RDMS$SET_FLAGS
$      ENDIF
$      IF F$TRNLNM("RDMS$DEBUG_FLAGS_OUTPUT","LNM$PROCESS") .NES. ""
$      THEN DEASSIGN /PROCESS RDMS$DEBUG_FLAGS_OUTPUT
$      ENDIF
$      wso "%''Fac'-I-OFF, Rdb Debug Flags are now [1mdisabled[0m"
$ ELSE i = 0
$      IF F$EXTRACT(0,1,P1) .EQS. "+"  !append to current value?
$      THEN P1 = P1 - "+"
$           Flags = F$TRNLNM("RDMS$SET_FLAGS")
$      ELSE Flags = ""
$      ENDIF
$      ON ERROR THEN GOTO BadKeyword
$L0:
$      KeyW = F$ELEMENT(i,",",P1)
$      IF KeyW .EQS. "," THEN GOTO L1
$      ! Note: Because of DCL command-line/buffer limits, FlagKeywords
$      !       is passed as a global symbol, not as an argument...
$      CALL Parse "''KeyW'" Parse$KeyWord "STRATEGY" !! "''FlagKeywords'"
$      IF Flags .EQS. ""
$      THEN Flags = Parse$KeyWord
$      ELSE Flags = Flags + "," + Parse$KeyWord
$      ENDIF
$      i = i + 1
$      GOTO L0
$L1:
$      ON ERROR THEN GOTO Done
$      DEFINE /PROCESS /NOLOG RDMS$SET_FLAGS "''Flags'"
$      SHOW TRANSLATION RDMS$SET_FLAGS
$      IF P2 .NES. ""
$      THEN P2 = F$PARSE(P2,"sys$scratch:.lis")
$           DEFINE /PROCESS /NOLOG RDMS$DEBUG_FLAGS_OUTPUT 'P2'
$           SHOW TRANSLATION RDMS$DEBUG_FLAGS_OUTPUT
$      ENDIF
$ ENDIF
$ GOTO Done
$ !
$BadKeyword:
$ wso ""
$ wso F$FAO( "%!AS-E-SYNTAX, !AS requires new syntax with Rdb v!AS", -
              Fac, Fac, RDB_VERSION )
$ wso ""
$ GOTO Help
$ !
$Debug_Flags:              ! old logical RDMS$DEBUG_FLAGS (v7.0-xx and older)
$ IF P1 .EQS. ""
$ THEN IF F$TRNLNM("RDMS$DEBUG_FLAGS","LNM$PROCESS") .NES. ""
$      THEN DEASSIGN /PROCESS RDMS$DEBUG_FLAGS
$      ENDIF
$      IF F$TRNLNM("RDMS$DEBUG_FLAGS_OUTPUT","LNM$PROCESS") .NES. ""
$      THEN DEASSIGN /PROCESS RDMS$DEBUG_FLAGS_OUTPUT
$      ENDIF
$      wso "%''Fac'-I-OFF, Rdb Debug Flags are now [1mdisabled[0m"
$ ELSE P1 = P1 - "A" - "D" - "F" - "G" - "J" - "L"  -  ! remove illegal chars
               - "Q" - "U" - "V" - "W" - "Y" - "Z"
$      P1 = P1 - "0" - "1" - "2" - "3" - "4" - "5" - "6" - "7" - "8" - "9"
$      P1len = F$LENGTH(P1)
$      SN = ( F$LOCATE("SN",P1) .LT. P1len )
$      IF F$LOCATE("SSS",P1) .LT. P1len
$      THEN P1 = P1 - "SSS" + "SSs"          ! case must be exactly "Ss"
$      ELSE IF ( F$LOCATE("SS",P1) .LT. P1len ) .AND. .NOT. ( SN )
$           THEN P1 = P1 - "SS" + "Ss"
$           ENDIF
$      ENDIF
$      IF SN
$      THEN P1 = P1 - "S" - "N" - "n" + "Sn" ! "n" implies "S" => "Sn"
$      ENDIF
$      IF F$LOCATE("XT",P1) .LT. P1len
$      THEN P1 = P1 - "XT" + "Xt"            ! case must be exactly "Xt"
$      ENDIF
$      IF F$LOCATE("XC",P1) .LT. P1len
$      THEN P1 = P1 - "XC" + "Xc"            ! case must be exactly "Xc"
$      ENDIF
$      IF F$LOCATE("BCN",P1) .LT. P1len
$      THEN P1 = P1 - "BCN" + "Bcn"            ! case must be exactly "Bcn"
$      ENDIF
$      DEFINE /PROCESS /NOLOG RDMS$DEBUG_FLAGS "''P1'"
$      SHOW TRANSLATION RDMS$DEBUG_FLAGS
$      IF P2 .NES. ""
$      THEN P2 = F$PARSE(P2,"sys$scratch:.lis")
$           DEFINE /PROCESS /NOLOG RDMS$DEBUG_FLAGS_OUTPUT 'P2'
$           SHOW TRANSLATION RDMS$DEBUG_FLAGS_OUTPUT
$      ENDIF
$ ENDIF
$ GOTO Done
$ !
$Done:
$ IF F$TYPE(FlagKeywords) .EQS. "STRING" THEN DELETE /SYMBOL /GLOBAL FlagKeywords
$ IF F$TYPE(Parse$Keywords) .EQS. "STRING" THEN DELETE /SYMBOL /GLOBAL Parse$Keywords
$ EXIT
$ !
$Parse: SUBROUTINE
$ ! P1: command to parse
$ ! P2: global symbol to receive answer
$ ! P3: default command
$ ! P4: command set ("C1|C2[|Cn...]") -- options must be same-length fields
$ ! P5: command separator
$ !
$ P4 = FlagKeywords        ! Copy global symbol (DCL com-line limits!)
$ !
$ IF P1 .EQS. "" THEN P1 = P3
$ IF P2 .EQS. "" THEN P2 = "Parse$Cmd"
$ IF P5 .EQS. "" THEN P5 = "|"
$ P4 = F$EDIT(P4,"UPCASE")
$ S  = F$LOCATE(P5,P4) + 1               !Determine field length
$ P4 = P5 + P4                           !Add separator to front of list...
$ T  = P5 + F$EDIT(P1,"COLLAPSE,UPCASE") !...and to target
$ L  = F$LOCATE( F$EDIT(T,"COLLAPSE,UPCASE"), P4 )      !Test substring
$ IF ( L .LT. F$LENGTH(P4) ) .AND. ( L-(L/S)*S .EQ. 0 ) !Found?
$ THEN L = ( ( L + 1 ) / S ) + 1                        !Calculate offset
$      'P2' == F$EDIT( F$ELEMENT(L,P5,P4), "COLLAPSE" )
$      EXIT 1
$ ELSE 'P2' == "$Err$"
$      WRITE sys$output "\''P1'\ (expecting: ''F$EDIT(P4,"COLLAPSE")')"
$      EXIT 229522  !%DCL-E-IVVERB, unrecognized command verb
$ ENDIF
$ ENDSUBROUTINE
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ IF NewSetFlags
$ THEN wso ""
$      IF F$TRNLNM("RDMS$SET_FLAGS") .NES. ""
$      THEN SHOW TRANSLATION RDMS$SET_FLAGS
$           IF F$TRNLNM("RDMS$DEBUG_FLAGS_OUTPUT") .NES. "" THEN SHOW TRANSLATION RDMS$DEBUG_FLAGS_OUTPUT
$           wso ""
$      ENDIF
$      wso "  use: $ [1m@RDBFLAGS keyword[,...] [output_file][0m  !define logical [4mRDMS$SET_FLAGS[0m"
$      wso "   or: $ [1m@RDBFLAGS[0m                              !turn flags [4moff[0m"
$      TYPE sys$input

  [4mSET FLAGS Keyword      Meaning (these flags are commonly used)       Flag[0m
  [1m?[0m                      Display this help text
  BLR                    Display Binary Language Representation        Bcn
  CARDINALITY            Show cardinality updates                      K
  CONTROL_BITS           Use w/BLR, displays coding of semantic flags  Bc
  CRONO_FLAG             Force timestamp-before-dump display           Xc
  DATABASE_PARAMETERS    Display database parameter buffer on ATTACH   P
  [1mDETAIL[0m                 Used w/STRATEGY, generates detailed report    (none)
  [1mESTIMATES[0m              Query estimates (cost of access in I/Os)      [1mO[0m
  EXECUTION              Execution trace from dynamic optimizer        E
  IGNORE_OUTLINE         Ignore outlines defined in the database       I
  ITEM_LIST              Display item-lists passed to queries          H
  MBLR                   Macro-BLR dump                                M
  [1mOUTLINE[0m                Query outline strategy                        [1mSs[0m
  PREFIX                 Use w/BLR, inhibit offset numbering and       Bn
                           other formatting of binary display
  [1mREQUEST_NAMES[0m          Trace constraints & triggers as evaluated     [1mSn[0m
  SCROLL_EMULATION       Disable scrolling for old-style seg-strings   L
  [1mSORT_STATISTICS[0m        Sort statistics                               [1mR[0m
  SORTKEY_EXT            Referencing only external (constant) values   S (err?)
                           in an ORDER BY
  [1mSTRATEGY[0m               Query/access strategy                         [1mS[0m
  [1mTRACE[0m                  Enable SQL-TRACE statement output             [1mXt[0m
  TRANSACTION_PARAMETERS Transaction activity in the transaction       T
                           parameter buffer during SET TRANS/COMMIT

$      wso "  These Rdb/SQL commands are also available:"
$      wso "     SQL> [1mSET FLAGS 'keyword[,...]'[0m   -- (no abbreviations)"
$      wso "     SQL> [1mSHOW FLAGS[0m"
$      wso ""
$ ELSE wso ""
$      IF F$TRNLNM("RDMS$DEBUG_FLAGS") .NES. ""
$      THEN SHOW TRANSLATION RDMS$DEBUG_FLAGS
$           IF F$TRNLNM("RDMS$DEBUG_FLAGS_OUTPUT") .NES. "" THEN SHOW TRANSLATION RDMS$DEBUG_FLAGS_OUTPUT
$           wso ""
$      ENDIF
$      wso "  use: $ [1m@RDBFLAGS [flags] [output_file][0m   !define logical [4mRDMS$DEBUG_FLAGS[0m"
$      wso "   or: $ [1m@RDBFLAGS[0m                         !turn flags [4moff[0m"
$      wso "         (no parameters) to turn flags [4moff[0m"
$      TYPE sys$input

  [4mFlag  Meaning (these flags are commonly used)       SET FLAGS Keyword     [0m
  [1m?[0m     Display this help text
  [1mO[0m     Query estimates (cost of access in I/Os)      [1mESTIMATES[0m
  [1mP[0m     Display database parameter buffer on ATTACH   [1mDATABASE_PARAMETERS[0m
  [1mR[0m     Sort statistics                               [1mSORT_STATISTICS[0m
  [1mS[0m     Query/access strategy                         [1mSTRATEGY[0m
  [1mSn[0m    Trace constraints & triggers as evaluated     [1mREQUEST_NAMES[0m
  [1mSs[0m    Query outline strategy                        [1mOUTLINE[0m
  [1mXc[0m    Force timestamp-before-dump display           [1mCRONO_FLAG[0m [sic!]
  [1mXt[0m    Enable SQL-TRACE statement output             [1mTRACE[0m

  [4mFlag  Meaning (these flags are used infrequently)   SET FLAGS Keyword     [0m
  Bcn       BLR dump                                  BLR
  E         Execution trace from dynamic optimizer    EXECUTION
  H         Display item-lists passed to queries      ITEM_LIST
  I         Ignore outlines defined in the database   IGNORE_OUTLINE
  K         Show cardinality updates                  CARDINALITY
  M         Macro-BLR dump                            MBLR
  T         Transaction activity (TPB)                TRANSACTION_PARAMETERS
  \         Debug flag: Sets internal DBkey buffer size to 10.
            Permits testing of dynamic optimization with small
            tables (forces use of small temp-tables).  Imposes
            high system overhead, so use for testing only.

$      wso "  These new Rdb/SQL v7 commands are also available:"
$      wso "     SQL> [1mSET FLAGS 'keyword[,...]'[0m   -- (no abbreviations)"
$      wso "     SQL> [1mSHOW FLAGS[0m"
$      wso ""
$ ENDIF
$ EXIT
