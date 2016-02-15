$ ! VAST_STATS.COM --                                             'F$VERIFY(0)'
$ !
$ !  use: @VAST_STATS
$ !
$ ! Copyright (C) 2012-2013 Lorin Ricker <lorin@rickernet.us>
$ ! Version: 2.0, 05/17/2013
$ !
$ ! This program is free software, under the terms and conditions of the
$ ! GNU General Public License published by the Free Software Foundation.
$ !
$ ! -----
$CreateStatsFile:  SUBROUTINE
$ ! P1 : Full name of Stats File double-DQOUTE'd
$ !
$ IF F$SEARCH(P1) .NES. "" THEN EXIT %X1  ! file exists, just exit with success
$ !
$ ! else... create it:
$ IF Debugging THEN wserr F$FAO( "%!AS-I-CREATE, creating database !AS", Fac, P1 )
$ CREATE /FDL=sys$input /LOG 'P1'
SYSTEM
        SOURCE                  VMS

FILE
        ALLOCATION              1000
        BUCKET_SIZE             0
        CLUSTER_SIZE            3
        CONTIGUOUS              no
        EXTENSION               100
        FILE_MONITORING         no
        GLOBAL_BUFFER_COUNT     0
        ORGANIZATION            indexed
        PROTECTION              (S:RWE,O:RWE,G:RW,W:R)

RECORD
        BLOCK_SPAN              yes
        CARRIAGE_CONTROL        carriage_return
        FORMAT                  FIXED
        SIZE                    512

AREA 0
        ALLOCATION              240
        BEST_TRY_CONTIGUOUS     yes
        BUCKET_SIZE             0
        EXTENSION               24

AREA 1
        ALLOCATION              760
        BEST_TRY_CONTIGUOUS     yes
        BUCKET_SIZE             0
        EXTENSION               100

KEY 0
        CHANGES                 NO
        DATA_AREA               0
        DATA_FILL               90
        DATA_KEY_COMPRESSION    no
        DATA_RECORD_COMPRESSION no
        DUPLICATES              no
        INDEX_AREA              1
        INDEX_COMPRESSION       no
        INDEX_FILL              90
        NAME                    "KeySeg"
        NULL_KEY                no
        PROLOG                  3
        SEG0_POSITION           0
        SEG0_LENGTH             7
        SEG1_POSITION           7
        SEG1_LENGTH             17
        TYPE                    string

$ !
$ stat = $STATUS
$ DIRECTORY /SIZE /DATE /PROT /ACL /OWNER 'P1'
$ EXIT 'stat'
$ ENDSUBROUTINE  ! CreateStatsFile
$ ! -----
$ !
$ ! -----
$AssertLength:  SUBROUTINE
$ ! P1 : Segment name
$ ! P2 : Actual data segment length
$ ! P3 : Expected segment length
$ ! P4 : Actual data segment
$ !
$ IF P2 .EQS. ""
$ THEN ActualLen = F$LENGTH(P4)
$ ELSE ActualLen = F$INTEGER(P2)
$ ENDIF
$ ExpectedLen = F$INTEGER(P3)
$ IF ActualLen .EQ. ExpectedLen
$ THEN EXIT %X1  ! assertion succeeds
$ ELSE msg  = F$FAO( "%!AS-F-OOPS, ", Fac )
$      msgL = F$LENGTH(msg)
$      wserr F$FAO( "!ASassertion failure for segment !AS, actual segment length !SL", -
                    msg, P1, ActualLen )
$      wserr F$FAO( "!#* expected segment length !SL", msgL, ExpectedLen )
$      IF P4 .NES. "" THEN wserr F$FAO( "!/!#* segment |!AS|!/", msgL, P4 )
$      EXIT %X2C
$ ENDIF
$ ENDSUBROUTINE  ! AssertLength
$ ! -----
$ !
$ ! -----
$WriteStat:  SUBROUTINE
$ ! P1 : Global Symbol (statistic) name
$ val = 'P1'
$ wserr F$FAO( "!#* !30AS = !3SL", 4, P1, val )
$ EXIT 1
$ ENDSUBROUTINE  ! WriteStat
$ ! -----
$ !
$ !
$ ! ===== Main =====
$Main:
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ IF Debugging
$ THEN wserr F$FAO( "!/%!AS-I-REMEXE, remote execution from !AS", Fac, AUD$NodeAcc )
$      wserr F$FAO( "%!AS-I-STATS, writing statistics...!/", Fac )
$ ENDIF
$ !
$ SubDirName = "STATISTICS"
$ ! DoShared creates global symbol AUD$StatsDir
$ DoShared CheckAndCreateSubDir "''SubDirName'"
$ AUD$WriteStats == $STATUS
$ IF .NOT. AUD$WriteStats THEN GOTO StatsDirErr
$ !
$ ! FileSpecDQ creates four global symbols: 'P3', 'P3'DQ, 'P4' and 'P4'DQ
$ DoShared FileSpecDQ "''SubDirName'" "VAST_STATISTICS.DAT" "AUD$StatsDir" "AUD$StatsName"
$ !
$ CALL CreateStatsFile "''AUD$StatsNameDQ'"
$ !
$ AssertLen = "CALL AssertLength"
$ !
$ ExpectedKeySegLen   =  24
$ ExpectedDataSeg0Len = 201
$ ExpectedDataSeg1Len = 287
$ ExpectedStatDataLen = 512 ! ExpectedKeySegLen + ExpectedDataSeg0Len + ExpectedDataSeg1Len
$ !
$ fsep = VBAR   ! set major data field separator
$ !
$ wso F$FAO( "!AS!/Statistics (counters) summary:", HRul )
$ !
$ ! Assemble KeySeg:  "TIMESTAMP|NODE|"
$ KeySeg = F$FAO( "!16AS!AS!6AS!AS", -
                  AUD$TimeStamp, fsep, AUD$Node, fsep )
$ AssertLen "KeySeg" "" "''ExpectedKeySegLen'" "''KeySeg'"
$ !
$ ! Assemble DataSeg0:  "RECSTAT|TY|ARCH|VERSION|USERNAME|AUDITORS|COMMENT1|COMMENT2|"
$ ! (two-part assembly due to DCL symbol-length restrictions...):
$ DataSeg0 = F$FAO( "!7AS!AS!2AS!AS!6AS!AS!20AS!AS!12AS!AS!50AS!AS", -
                    AUD$RecStat, fsep, AUD$DTSType, fsep, -
                    AUD$Arch, fsep, AUD$Version, fsep,    -
                    AUD$UName, fsep, AUD$Auditors, fsep )
$ DataSeg0 = DataSeg0 -
           + F$FAO( "!48AS!AS!48AS!AS", -
                    AUD$Comment1, fsep, AUD$Comment2, fsep )
$ AssertLen "DataSeg0" "" "''ExpectedDataSeg0Len'" "''DataSeg0'"
$ !
$ ! Assemble DataSeg1 (the statistics data by categories):
$ !                   "ACMSGEN|APPLICATION|DECNET|HARDWARE|SOFTWARE|SYSGEN|TCPIP|VMS|TOTAL"
$ DataSeg1 = ""
$ j = 0
$DL0:
$ ! For each major category --
$ cat = F$ELEMENT(j,COMMA,AUDIT$MajorCats)
$ IF cat .EQS. COMMA THEN GOTO DL1
$ ! Build the variable-part of the Stats-Data record.
$ ! The final "TOTAL" group gets "NNN" numeric field width (range 0..999),
$ ! all others get "NN" (range 0..99) --
$ IF cat .NES. "TOTAL"
$ THEN lw = 11  ! "ACMSGEN._._" | "APPLICATION" | ...(etc.)
$      fw =  2  ! "a:NN;r:NN;s:NN;t:NN"
$ ELSE lw =  7  ! "TOTAL._"
$      fw =  3  ! "a:NNN;r:NNN;s:NNN;t:NNN"
$ ENDIF
$ dseg =        F$FAO( "!#AS=!1AS:!#SL", lw, cat, "a", fw, AUDIT$Cntr_'cat'_Accepts )
$ dseg = dseg + F$FAO(     ";!1AS:!#SL",          "r", fw, AUDIT$Cntr_'cat'_Rejects )
$ dseg = dseg + F$FAO(     ";!1AS:!#SL",          "s", fw, AUDIT$Cntr_'cat'_Skips )
$ dseg = dseg + F$FAO(     ";!1AS:!#SL",          "t", fw, AUDIT$Cntr_'cat'_Tests )
$ IF DataSeg1 .NES. ""
$ THEN DataSeg1 = DataSeg1 + fsep + dseg
$ ELSE DataSeg1 = dseg
$ ENDIF
$ !
$ ! Dump the statistics (counters) summary:
$ CALL WriteStat "AUDIT$Cntr_''cat'_Accepts"
$ CALL WriteStat "AUDIT$Cntr_''cat'_Rejects"
$ CALL WriteStat "AUDIT$Cntr_''cat'_Skips"
$ CALL WriteStat "AUDIT$Cntr_''cat'_Tests"
$ wserr F$FAO( "!#* |!AS|!/", 6, dseg )
$ !
$ j = j + 1
$ GOTO DL0
$DL1:
$ AssertLen "DataSeg1" "" "''ExpectedDataSeg1Len'" "''DataSeg1'"
$ !
$ ! See end-of-this-file for Stats-Data record format/layout --
$ StatDataLen = F$LENGTH(KeySeg) + F$LENGTH(DataSeg0) + F$LENGTH(DataSeg1)
$ AssertLen "StatDataRec" "''StatDataLen'" "''ExpectedStatDataLen'" ""
$ !
$ IF Debugging
$ THEN wso F$FAO( "%!AS-I-DEBUG, would write Summary Data Record to Statistics Data File", Fac )
$      wso F$FAO( "!AS", DHRul )
$      wso F$FAO( "!9AS !#AS", "KeySeg:",   ExpectedKeySegLen,   KeySeg )
$      wso F$FAO( "!9AS !#AS", "DataSeg0:", ExpectedDataSeg0Len, DataSeg0 )
$      j = 0
$      lbl = "DataSeg1:"
$DebL0:
$      seg = F$ELEMENT(j,VBAR,DataSeg1)
$      IF seg .EQS. VBAR THEN GOTO DebL1
$      IF j .GT. 0 THEN lbl = " "
$      wso F$FAO( "!9AS !#AS", lbl, 31, seg )
$      j = j + 1
$      GOTO DebL0
$DebL1:
$      wso F$FAO( "!AS!/", DHRul )
$ ELSE wso F$FAO( "!AS!/Commit an Audit Run Summary Data Record to Statistics Data File", HRul )
$      wso F$FAO( "!AS?", AUD$StatsName )
$      READ sys$command Answer /END_OF_FILE=Done -
         /PROMPT="Commit statistics data (yes/NO)? "
$      Answer = F$PARSE(Answer,"NO",,"NAME","SYNTAX_ONLY")
$      IF Answer
$      THEN ! Open and write Summary Data Record to the Statistics File (RMS-indexed):
$           OPEN /APPEND /ERROR=OpenStatErr statf 'AUD$StatsName'
$           statusstatf = $STATUS
$         ! =====
$         ! Write just one summary record for this audit:
$           WRITE /SYMBOL statf KeySeg, DataSeg0, DataSeg1
$         ! =====
$           IF $STATUS
$           THEN wso F$FAO( "%!AS-S-SUCCESS, stats record written for !AS !AS", -
                            Fac, AUD$Node, AUD$TimeStamp )
$           ELSE wso F$FAO( "%!AS-E-FAIL, attempted stats record write failed for !AS !AS", -
                            Fac, AUD$Node, AUD$TimeStamp )
$           ENDIF
$      ENDIF
$ ENDIF
$ !
$Done:
$ IF F$TYPE(statusstatf) .NES. ""
$ THEN CLOSE statf
$      DELETE /SYMBOL /LOCAL statusstatf
$ ENDIF
$ !
$ EXIT %X1
$ !
$OpenStatErr:
$ wserr F$FAO( "%!AS-F-OPENSTATDERR, cannot open ""!AS"" for writing statistics record", -
               Fac, AUD$StatsName )
$ EXIT %X2C
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$ ! STATS-DATA RECORD FORMAT:
$ !
$ ! General:
$ !   1. All data fields are pure ASCII characters (no binary data), and are separated by
$ !      a field separator character "|" (vert-bar).
$ !   2. Data field lengths (below) include counted-separators.
$ !   3. Total record length is 24 + 201 + 287 = 512 bytes.
$ !   3. There are 2 + 8 + 9 = 19 ("F") data fields, and 18 ("F-1") field separators "|".
$ !   4. There are three major data segments: KeySeg, DataSeg0 and DataSeg1.
$ !   5. Data fields are fixed-length, blank padded as needed (shown as "._._." below).
$ !   6. KeySeg consists of 2 data fields:
$ !        TIMESTAMP|NODE|
$ !        -- 16 + 6 + 2 = 24 bytes (bytes)
$ !        a) TIMESTAMP is the (comparison-ordered) date/time of this audit record;
$ !        b) NODE is the name of the system, e.g., "R4BB10";
$ !        c) and includes 2 field separators "|".
$ !   7. DataSeg0 consists of 8 data fields:
$ !        RECSTAT|TY|ARCH|VERSION|USERNAME|AUDITORS|COMMENT1|COMMENT2|
$ !        -- 7 + 2 + 6 + 20 + 12 + 50 + 48 + 48 + 8 = 201 bytes
$ !        a) RECSTAT is one of: "VALID  ", "TEST   ", "INVALID", or "DELETED";
$ !        b) TY (the DTS-type) is one of: "BB", "SB" (Billing nodes),
$ !                                        "XR", "SX" (Cross-reference nodes),
$ !                                        "ET", "SE" (Edge-technology nodes),
$ !                                        "FE", "SF" (Front-end nodes),
$ !                                        "RP", "SR" (Reporting nodes);
$ !        c) ARCH (architecture) is one of: "ALPHA" or "IA64";
$ !        d) VERSION is the version/date string of this Audit System Suite,
$ !           e.g. "v1.11 (25-Mar-2013)";
$ !        e) USERNAME is the VMS-username of the (primary) auditor, e.g., "RICKER";
$ !        f) AUDITORS are the name(s) of the participants (or observers) of the audit;
$ !        g) COMMENT1 and COMMENT2 are each arbitrary text;
$ !        h) DataSeg0 includes 8 field separators "|".
$ !   8. DataSeg1 consists of 9 major data fields:
$ !      ACMSGEN|APPLICATION|DECNET|HARDWARE|SOFTWARE|SYSGEN|TCPIP|VMS|TOTAL
$ !      -- ( 9 * 31 ) + 8 = 287 bytes
$ !        a) Each major data field consists of a NAMELABEL (ACMSGEN, APPLICATION, ...),
$ !           each followed by a group of four labeled minor fields, "a" (accepted),
$ !           "r" (rejected), "s" (skipped) and "t" (tested) and their respective
$ !           (integer) values; e.g., "SYSGEN     =a:11;r: 4;s: 0;t:15";
$ !        b) The major label fields are blank-padded to length 11, except for the TOTAL
$ !           which is blank-padded to length 7, and each are separated from the minor
$ !           fields by an "=" equal sign;
$ !        c) Each minor field's label is exactly one character, is separated from its value
$ !           by a ":" colon, and each integer value is right-justified in a 2-byte field,
$ !           except for the totals, which are right-justified in a 3-byte field;
$ !        d) Each major field is 31 bytes in length (not including field separators);
$ !        e) DataSeg1 includes 8 field separators "|".
$ !
$ !
$ ! Stats-Data record format:  KeySeg|DataSeg0|DataSeg1 (512 bytes total), where --
$ !
$ ![[KeySeg:
$ ![[0        1         2
$ ![[123456789 123456789 12345 -
$ ![[TIMESTAMP._._._.|NODE._|Recstat...
$ ![[     16         |  6   |]  <== KeySeg = 24 bytes
$ ![[        24 (KeySeg)     ]      (including 2 field separators)
$ !
$ !
$ ! DataSeg0:         v--- DATA[201] ---v
$ !  2    3  3  3   4  4      5         6   6     7
$ ! 456789 123456789 123456789 123456789 123456789 1234567 -
$ !  RECSTAT|TY|ARCH._|VERSION._._._._._._.|USERNAME._._|Auditors...
$ ! [   7   | 2|   6  |       20           |    12      |
$ ! [                     51                            |]...
$ !
$ !                         1         1         1
$ !  7  8         9         0         1         2
$ ! 6789 123456789 123456789 123456789 123456789 12345678 -
$ !  AUDITORS._._._._._._._._._._._._._._._._._._._._._|Comment1...
$ ! [                     50                           |]...
$ !
$ !  1 1         1         1         1         1
$ !  2 3         4         5         6         7
$ ! 789 123456789 123456789 123456789 123456789 1234567 -
$ !  COMMENT1._._._._._._._._._._._._._._._._._._._._|Comment2...
$ ! [                     48                         |]...
$ !
$ !  1  1         1         2         2         2
$ !  7  8         9         0         1         2
$ ! 6789 123456789 123456789 123456789 123456789 123456 -
$ !  COMMENT2._._._._._._._._._._._._._._._._._._._._|Acmsgen...
$ ! [                     48                         |]  <== DataSeg0 = 201 bytes
$ ! ...   ^--- DATA[201] ---^                         ]      (including 8 field separators)
$ !
$ !
$ ! DataSeg1:         v--- DATA[287] ---v
$ !  2   2         2         2       2 2         2         2         2
$ !  2   3         4         5       5 6         7         8         9
$ ! 56789 123456789 123456789 123456789 123456789 123456789 123456789 -
$ !  ACMSGEN._._=a:NN;r:NN;s:NN;t:NN|APPLICATION=a:NN;r:NN;s:NN;t:NN|Decnet...
$ ! [               31              |               31              |
$ !
$ !  2         3         3         3 3       3         3         3
$ !  9         0         1         2 2       3         4         5
$ !   123456789 123456789 123456789 123456789 123456789 123456789 1234 -
$ !  DECNET._._.=a:NN;r:NN;s:NN;t:NN|HARDWARE._.=a:NN;r:NN;s:NN;t:NN|Software...
$ ! |               31              |               31              |
$ !
$ !  3     3         3         3     3   3         4         4
$ !  5     6         7         8     8   9         0         1
$ ! 3456789 123456789 123456789 123456789 123456789 123456789 12345678 -
$ !  SOFTWARE._.=a:NN;r:NN;s:NN;t:NN|SYSGEN._._.=a:NN;r:NN;s:NN;t:NN|Tcpip...
$ ! |               31              |               31              |
$ !
$ !  4 4         4         4         4         4         4         4
$ !  1 2         3         4         5         6         7         8
$ ! 789 123456789 123456789 123456789 123456789 123456789 123456789 12 -
$ !  TCPIP._._._=a:NN;r:NN;s:NN;t:NN|VMS._._._._=a:NN;r:NN;s:NN;t:NN|Total...
$ ! |               31              |               31              |
$ !
$ !  4       4         5         5 5]]
$ !  8       9         0         1 1]]
$ ! 123456789 123456789 123456789 12]]
$ !  TOTAL._=a:NNN;r:NNN;s:NNN;t:NNN]]
$ ! |               31              ]]
$ !       ^--- DATA[287] ---^       ]] <== DataSeg1 = 287 bytes
$ !                                 ]]    (including 8 field separators)
$ !               End-Of-Record ---^]]
$ !
$ !
$ !  Extracting data from a StatRec (data record):
$ !                  F$ELEMENT(element,"|",StatRec)
$ !                           F$EXTRACT(offset,length,StatRec)
$ !
$ !  field           element  start-pos  offset  length
$ !  --------------  -------  ---------  ------  ------
$ !  NODE                0         1        0       6
$ !  TIMESTAMP           1         8        7      16
$ !
$ !  RECSTAT             2        25       24       7
$ !  DTSTYPE (TY)        3        33       32       2
$ !  ARCH                4        36       35       6
$ !  VERSION             5        43       42      20
$ !  USERNAME            6        64       63      12
$ !  AUDITORS            7        77       76      50
$ !  COMMENT1            8       128      127      48
$ !  COMMENT2            9       177      176      48
$ !
$ !  ACMSGEN            10       226      225      31
$ !  APPLICATION        11       258      257      31
$ !  DECNET             12       290      289      31
$ !  HARDWARE           13       322      321      31
$ !  SOFTWARE           14       354      353      31
$ !  SYSGEN             15       386      385      31
$ !  TCPIP              16       418      417      31
$ !  VMS                17       450      449      31
$ !  TOTAL              18       482      481      31
$ !
$ !  Last Char (EOR)                              512 = Length of Record
$ !
$ !
$ ! $ ! Example: the string and integer values of the VMS Accepts counter --
$ ! $ vmsfield  = F$ELEMENT(17,VBAR,StatRec)                 ! "VMS        =a:12;r: 3;s: 1;t:16"
$ ! $ vmslabel  = F$EDIT(F$ELEMENT(0,EQUAL,vmsfield),"TRIM") ! "VMS"
$ ! $ vmsdata   = F$ELEMENT(1,EQUAL,vmsfield)                ! "a:12;r: 3;s: 1;t:16"
$ ! $ vmsaccept = F$ELEMENT(0,SEMI,vmsdata)                  ! "a:12"
$ ! $ vmsastr   = F$ELEMENT(1,COLON,vmsaccept)               ! "12"
$ ! $ vmsaint   = F$INTEGER(vmsastr)                         ! 12
$ ! $ ! Given vmsdata, get the Reject counter:
$ ! $ vmsrint   = F$INTEGER(F$ELEMENT(1,COLON,F$ELEMENT(1,SEMI,vmsdata)))
$ !
