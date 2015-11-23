$ ! DK$TERMINAL.COM -- Setup terminal dependent data for DK$*
$ !
$ !     Usage:          @dk$package:dk$terminal 'Term_Type'
$ !     Called by:      dk$package:dk$define_keys.com
$ !     Returns global symbols: dk$term,dk$keys,dk$rows,dk$cols
$ !
$ Term = F$EDIT(F$EXTRACT(0,5,P1),"UPCASE")
$ IF    Term .EQS. "VT100" .OR.   -
        Term .EQS. "IBMPC" .OR.   -
        Term .EQS. "IBMAT"        -
  THEN  GOTO 'Term'
$VT300:
$VT200:                  !Default terminal type is VT200
$ dk$term == "VT200"
$ dk$others == "f6    ;f7    ;f8    ;f9    ;f10   ;f11   ;f12   ;f13   ;f14   "
$ dk$keys == -
   "1help  ;2do    ;       ;       ;1f17   ;1f18   ;1f19   ;1f20   ;" -
 + "1e1    ;1e2    ;1e3    ;       ;1pf1   ;1pf2   ;1pf3   ;1pf4   ;" -
 + "1e4    ;1e5    ;1e6    ;       ;1kp7   ;1kp8   ;1kp9   ;1minus ;" -
 + "       ;1up    ;2title ;       ;1kp4   ;1kp5   ;1kp6   ;1comma ;" -
 + "1left  ;1down  ;1right ;       ;1kp1   ;1kp2   ;1kp3   ;1enter ;" -
 + "       ;       ;       ;       ;2kp0   ;       ;1period;       ;"
$ dk$cols == 8
$ dk$rows == 6
$ GOTO Done
$ !
$VT100:                   !All VT100 type terminals
$ dk$term == "VT100"
$ dk$others == ""
$ dk$keys == -
   "1up    ;1down  ;1left  ;1right ;       ;1pf1   ;1pf2   ;1pf3   ;1pf4   ;" -
 + "       ;       ;       ;       ;       ;1kp7   ;1kp8   ;1kp9   ;1minus ;" -
 + "       ;       ;       ;       ;       ;1kp4   ;1kp5   ;1kp6   ;1comma ;" -
 + "       ;       ;2title ;       ;       ;1kp1   ;1kp2   ;1kp3   ;1enter ;" -
 + "       ;       ;       ;       ;       ;2kp0   ;       ;1period;       ;"
$ dk$cols == 9
$ dk$rows == 5
$ GOTO Done
$ !
$IBMAT:                   !IBM AT compatible keyboards
$ dk$term == "IBMAT"
$ dk$others == ""
$ dk$keys == -
   "1pf1   ;1pf2   ;       ;       ;1esc   ;1num   ;1scroll;1sys   ;" -
 + "1pf3   ;1pf4   ;       ;       ;1kp7   ;1kp8   ;1kp9   ;1prt   ;" -
 + "1f5    ;1f6    ;2title ;       ;1kp4   ;1kp5   ;1kp6   ;1minus ;" -
 + "1f7    ;1f8    ;       ;       ;1kp1   ;1kp2   ;1kp3   ;1enter ;" -
 + "1f9    ;1f10   ;       ;       ;2kp0   ;       ;1period;       ;"
$ dk$cols == 8
$ dk$rows == 5
$ GOTO Done
$ !
$IBMPC:                   !IBM PC compatible keyboards
$ dk$term == "IBMPC"
$ dk$others == ""
$ dk$keys == -
   "1pf1   ;1pf2   ;       ;       ;2num   ;       ;2scroll;       ;" -
 + "1pf3   ;1pf4   ;       ;       ;1kp7   ;1kp8   ;1kp9   ;1minus ;" -
 + "1f5    ;1f6    ;2title ;       ;1kp4   ;1kp5   ;1kp6   ;       ;" -
 + "1f7    ;1f8    ;       ;1prt   ;1kp1   ;1kp2   ;1kp3   ;1enter ;" -
 + "1f9    ;1f10   ;       ;2kp0   ;       ;2period;       ;       ;"
$ dk$cols == 8
$ dk$rows == 5
$ !
$Done:
$ EXIT
