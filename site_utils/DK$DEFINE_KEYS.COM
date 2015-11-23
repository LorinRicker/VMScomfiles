$ ! DK$DEFINE_KEYS.COM -- Construct DEFINE/KEY command file
$ !     usage:  @dk$define_keys [Facility] [Key_Map] [Map_Type] [Term]
$ !                             Values                  default
$ !             Facility        String                  "DCL"
$ !             Key_Map         String (State Name)     "GOLD"
$ !             Map_Type        "[NO]SHIFT_KEY"         "SHIFT_KEY"
$ !             Term            "VT200","VT100",        "VT200"
$ !                             "IBMPC"
$ !     Calls:          dk$package:dk$diagram.com
$ !                     dk$package:dk$terminal.com
$ !                     dk$package:dk$load_keys.com
$ !     Input:          dk$'facility'.def in the current directory
$ !     Output:         dk$'facility'.com in the current directory
$ !                     dk$'facility'.lis in the current directory
$ !
$ ON CONTROL_Y THEN GOSUB Abort
$ ON ERROR THEN GOTO Done
$ @site$utils:utility START DK 'F$ENVIRONMENT("PROCEDURE")'
$ !
$ DELETE      = "DELETE"
$ Null        = ""
$ Dollar      = "$ "
$ Quotes      = """"
$ No_defs     = "TRUE"
$ No_load     = "TRUE"
$ !
$ Facility    = F$EDIT(P1,"UPCASE")
$ Key_Map     = F$EDIT(P2,"UPCASE")
$ Map_Type    = F$EDIT(P3,"UPCASE")
$ Term_Type   = F$EDIT(P4,"UPCASE")
$ IF Facility .EQS. Null THEN Facility = "DCL"
$ IF Facility .NES. "DCL" THEN Dollar = Null
$ IF Map_Type .EQS. Null THEN Map_Type = "SHIFT_KEY"
$ IF (Map_Type .EQS. "SHIFT_KEY") .AND. (Key_Map .EQS. Null) -
  THEN  Key_Map = "GOLD"
$ State       = Key_Map
$ DK$Defs = F$EDIT("dk$''Facility'.def;","LOWERCASE")
$ DK$Cmds = F$EDIT("dk$''Facility'.com;","LOWERCASE")
$ DK$Load = F$EDIT("dk$''Facility'.lis;","LOWERCASE")
$ !
$ @dk$package:dk$terminal 'Term_Type'
$ OPEN/READ/ERROR=No_Input dk-def 'DK$Defs'
$ OPEN/WRITE/ERROR=No_Output dk-com 'DK$Cmds'
$ IF Facility .NES. "DCL" THEN GOTO Loop
$ WRITE dk-com "$ SET SYMBOL/SCOPE=(NOGLOBAL,NOLOCAL)"
$ WRITE dk-com "$ IF F$EXTRACT(0,4,F$TRNLNM(""smsk$keypad"")) .EQS. ""APPL"" -"
$ WRITE dk-com "  THEN  SET TERMINAL/APPLICATION_KEYPAD"
$ WRITE dk-com "$ DELETE/KEY/NOLOG/ALL/STATE=(DEFAULT,''State')"
$ !
$Loop:
$ READ/END_OF_FILE=Finish dk-def Record
$ Record  = F$EDIT(Record,"TRIM,COMPRESS,UPCASE,UNCOMMENT")
$ IF Record .EQS. "" THEN GOTO Loop
$ !
$ L = F$LOCATE(":",Record)
$ Rec_Typ = F$EDIT(F$EXTRACT(0,L,Record),"LOWERCASE")
$ L = L + 1
$ Record  = F$EDIT(F$EXTRACT(L,F$LENGTH(Record)-L,Record),"TRIM")
$ Rec_Len = F$LENGTH(Record)
$ IF      Rec_Typ .EQS. "e" -          !end
     .OR. Rec_Typ .EQS. "k" -          !key name
     .OR. Rec_Typ .EQS. "s" -          !switches
     .OR. Rec_Typ .EQS. "h" -          !help legend
     .OR. Rec_Typ .EQS. "l" -          !load
     .OR. Rec_Typ .EQS. "t" -          !title
     .OR. Rec_Typ .EQS. "v" -          !verb
    THEN GOTO 'Rec_Typ'
$ ! otherwise:
$ WRITE sys$error F$FAO(F$MESSAGE(UTIL_RECTYPE),Record)
$ GOTO Loop
$ !
$e:     ! "End of Data" record:
$ GOTO Finish
$ !
$t:     ! "Title" record:
$ DK$title == Record
$ GOTO Loop
$ !
$k:     ! "Key" record:
$ Switch = Null
$ Help   = Null
$ Value  = Null
$ Shift  = Null
$ Key = F$EDIT(Record,"LOWERCASE")
$ K = F$FAO("!6AS",Key)
$ IF (F$LOCATE(K,dk$keys) .EQ. F$LENGTH(dk$keys) .AND.          -
      F$LOCATE(K,dk$others) .EQ. F$LENGTH(dk$others))           -
  THEN  WRITE sys$error F$FAO(F$MESSAGE(UTIL_KEYNAME),Key)
$ GOTO Loop
$ !
$s:     ! "Switch" record:
$ Switch = Switch + Record
$ IF F$LOCATE("/IF_STATE=",Record) .NE. Rec_Len -
  THEN  Shift = "OTHER_"  !some (other/any) state is set...
$ IF    (State .NES. Null) .AND. -
        (F$LOCATE("/IF_STATE=''State'",Record) .NE. Rec_Len) -
  THEN  Shift = "''State'_"  !Shift state is set...
$ GOTO Loop
$ !
$ h:    ! "Help" record
$ Help  = Record
$ IF Key .NES. Null THEN DK$'Shift''Key' == Help
$ GOTO Loop
$ !
$v:     ! "Value" record:
$ Value  = Record
$ Value_No_Quotes = Value - Quotes - Quotes  !strip for printing
$ IF Key .EQS. Null THEN GOTO V0
$ No_defs = "FALSE"
$ WRITE dk-com  -
        Dollar,"DEFINE/KEY/NOLOG ",Switch," ",Key," ",Value
$ IF Help .EQS. Null THEN -
        DK$'Shift''Key' == "''F$EXTRACT(0,7,Value_No_Quotes)'"
$V0:
$ GOTO Loop  !reset for next key definition
$ !
$l:     ! "Load" a programmable key
$ IF (Key .EQS. Null) .OR. (Record .EQS. Null) THEN GOTO L0
$ No_load = "FALSE"
$ IF F$TRNLNM("dk-loa") .NES. "" THEN GOTO L1
$ CREATE /FDL=sys$input 'DK$Load'
SYSTEM
	SOURCE                  VAX/VMS
FILE
	ALLOCATION              1
	ORGANIZATION            sequential
RECORD
	BLOCK_SPAN              yes
	CARRIAGE_CONTROL        none
	CONTROL_FIELD_SIZE      2
	FORMAT                  vfc
	SIZE                    0
$ OPEN /APPEND dk-loa 'DK$Load'
$ esc[0,8]=27
$ WRITE dk-loa esc,"M"
$L1:
$ @dk$package:dk$load_keys 'Key' 'Record' dk-loa
$L0:
$ GOTO Loop  !reset for next key definition
$ !
$Finish:
$ IF Facility .EQS. "DCL" THEN WRITE dk-com "$ EXIT"
$ CLOSE dk-com
$ IF (No_defs) THEN DELETE 'DK$Cmds'
$ IF (No_defs) .AND. (No_load) THEN GOTO F0
$ DK$Msg = ""
$ IF No_defs THEN GOTO F2
$ DK$Msg = DK$Cmds
$ IF (.NOT. No_load) THEN DK$Msg = DK$Msg + " and "
$F2:
$ IF (.NOT. No_load) THEN DK$Msg = DK$Msg + DK$Load
$ WRITE sys$error F$FAO(F$MESSAGE(UTIL_DEFKEY),DK$Msg)
$ GOTO F1
$F0:
$ WRITE sys$error F$MESSAGE(UTIL_NODEFKEY)
$F1:
$ @dk$package:dk$diagram 'Facility' "''Key_Map'" "''Map_Type'" 'dk$term'
$ !
$Done:
$ DK$Status = $STATUS
$ SET NOON
$ IF F$TRNLNM("dk-def") .NES. "" THEN CLOSE dk-def
$ IF F$TRNLNM("dk-com") .NES. "" THEN CLOSE dk-com
$ IF F$TRNLNM("dk-loa") .NES. "" THEN CLOSE dk-loa
$ @site$utils:utility EXIT DK
$ EXIT (DK$Status .OR. %X10000000)
$ !
$Abort:
$ RETURN %X0000002C
$ !
$No_Input:
$ @site$utils:utility SIGNAL 'UTIL_FILNOTFND' 'DK$Defs'
$No_Output:
$ @site$utils:utility SIGNAL 'UTIL_FILNOTCRE' 'DK$Cmds'
