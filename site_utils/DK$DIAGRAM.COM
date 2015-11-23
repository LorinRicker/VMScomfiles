$ ! DK$DIAGRAM.COM -- Construct keypad diagram
$ !     Called by:      dk$package:dk$define_keys.com
$ !     Input:          dk$package:dk$template.'term'
$ !     Output:         dk$'facility'_keypad.'key_map' in the current directory
$ !
$ ON CONTROL_Y THEN GOSUB Signal_Error
$ ON ERROR THEN GOTO Done
$ DELETE := DELETE
$ !
$ Facility  = P1
$ Key_Map   = P2
$ Map_Type  = P3
$ Term      = P4
$ !
$ Null    = ""
$ esc[0,32]=27
$ RVideo[0,1]:='esc'
$ RVideo[1,3]:="[7m"
$ RV_Len = 4
$ NVideo[0,1]:='esc'
$ NVideo[1,2]:="[m"
$ NV_Len = 3
$ !
$ Last = dk$rows * dk$cols - 1
$ File_Type = "keys"
$ IF Key_Map .NES. Null THEN File_Type = Key_Map
$ Keypad = F$EDIT("dk$''P1'_keypad.''File_Type'","LOWERCASE")
$ IF F$LOCATE(Map_Type,"SHIFT_KEY") .NE. 0 THEN GOTO L0
$ State = Null
$ Shift = Key_Map + "_"
$ GOTO L1
$L0:
$ State = Key_Map
$ IF State .NES. Null THEN State = State + "_"
$ Shift = Null
$L1:
$ Template = F$EDIT("dk$package:dk$template.''dk$term'","LOWERCASE")
$ OPEN/READ/ERROR=No_Input dk-template 'Template'
$ OPEN/WRITE/ERROR=No_Output dk-keypad 'Keypad'
$ I = -1
$ Help_Row = Null
$ !
$L2:
$ IF I .EQ. Last THEN GOTO Finish
$ I = I + 1
$ IF I/dk$cols*dk$cols .EQ. I THEN GOSUB New_Row
$ K = F$EDIT(F$ELEMENT(I,";",dk$keys),"COLLAPSE")
$ L = 9 * F$EXTRACT(0,1,K) - 2
$ K = F$EXTRACT(1,9,K)
$ IF K .EQS. Null THEN GOTO L2
$ !
$ IF F$TYPE(DK$'State''K') .EQS. Null THEN GOTO L3
$ Value = DK$'State''K'
$ Value := 'Value'
$ IF Value .EQS. Null THEN GOTO L3
$       Value = F$FAO("!''L'<!AS!>",Value)
$       Col = ((I-(I/dk$cols*dk$cols))*11)+2
$       Help_Row[Col,'L']:= "''Value'"
$       DELETE/SYMBOL/GLOBAL DK$'State''K'
$ !
$L3:
$ IF F$TYPE(DK$'Shift''K') .EQS. Null THEN GOTO L5
$ IF Map_Type .NES. "SHIFT_KEY" THEN GOTO L4
$ Value = DK$'Shift''K'
$ Value := 'Value'
$ IF Value .EQS. Null THEN GOTO L4
$       Value = F$FAO("!''L'<!AS!>",Value)
$       Col = ((I-(I/dk$cols*dk$cols))*18)+2
$       Gold_Row[Col,RV_Len]          := "''RVideo'"
$       Gold_Row[Col+RV_Len,L]        := "''Value'"
$       Gold_Row[Col+RV_Len+L,NV_Len] := "''NVideo'"
$L4:
$ DELETE/SYMBOL/GLOBAL DK$'Shift''K'
$ !
$L5:
$ IF F$TYPE(DK$OTHER_'K') .EQS. Null THEN GOTO L6
$ DELETE/SYMBOL/GLOBAL DK$OTHER_'K'
$L6:
$ GOTO L2
$ !
$Finish:
$ GOSUB New_Row
$ WRITE sys$error F$FAO(F$MESSAGE(UTIL_KEYPAD),Keypad)
$Done:
$ Status = $STATUS
$ IF F$TYPE(dk$term) .NES. "" THEN DELETE/SYMBOL/GLOBAL dk$term
$ IF F$TYPE(dk$keys) .NES. "" THEN DELETE/SYMBOL/GLOBAL dk$keys
$ IF F$TYPE(dk$rows) .NES. "" THEN DELETE/SYMBOL/GLOBAL dk$rows
$ IF F$TYPE(dk$cols) .NES. "" THEN DELETE/SYMBOL/GLOBAL dk$cols
$ IF F$TRNLNM("dk-template") .NES. "" THEN CLOSE dk-template
$ IF F$TRNLNM("dk-keypad")   .NES. "" THEN CLOSE dk-keypad
$ IF (Status) .OR. (F$TYPE(Keypad) .EQS. "") THEN GOTO D0
$ Keypad = F$SEARCH(Keypad)
$ IF Keypad .NES. Null THEN DELETE 'Keypad'
$D0:
$ EXIT (Status .OR. %X10000000)
$ !
$New_Row:
$ IF Help_Row .EQS. Null THEN GOTO L7
$ WRITE dk-keypad Help_Row
$ WRITE dk-keypad Gold_Row
$ READ  dk-template Help_Row
$ WRITE dk-keypad Help_Row
$L7:
$ READ/END_OF_FILE=L8 dk-template Help_Row
$ WRITE dk-keypad Help_Row
$ READ  dk-template Help_Row
$ READ  dk-template Gold_Row
$L8: RETURN %X10000001
$ !
$No_Input:
$ WRITE sys$error F$FAO(F$MESSAGE(UTIL_FILNOTFND),Template)
$ EXIT %X10000000 .OR. UTIL_FILNOTFND
$No_Output:
$ CLOSE dk-template
$ WRITE sys$error F$FAO(F$MESSAGE(UTIL_FILNOTCRE),Keypad)
$ EXIT %X10000000 .OR. UTIL_FILNOTCRE
$ !
$Signal_Error:
$ RETURN %X10000002
