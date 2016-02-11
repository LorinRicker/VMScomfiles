$ ! NB(NotaBona).COM  -- 
$ !
$ ! Copyright © 1999-2016 by Lorin Ricker.  All rights reserved, with acceptance,
$ ! use, modification and/or distribution permissions as granted and controlled
$ ! by and under the GPL described herein.
$ !
$ ! This program (software) is Free Software, licensed under the terms and
$ ! conditions of the GNU General Public License Version 3 as published by
$ ! the Free Software Foundation: http://www.gnu.org/copyleft/gpl.txt,
$ ! which is hereby incorporated into this software and is a non-severable
$ ! part thereof.  You have specific rights and obligations under this GPL
$ ! which are binding if and when you accept, use, modify and/or distribute
$ ! this software program (source code file) and/or derivatives thereof.
$ !
$ IF p1 .EQS. ""
$ THEN READ /END_OF_FILE=Done /PROMPT="nota bona: " sys$command subj
$ ELSE subj = "''p1' ''p2' ''p3' ''p4' ''p5' ''p6' ''p7' ''p8'"
$      subj = F$EDIT(subj,"COMPRESS,TRIM,LOWERCASE")
$ ENDIF
$ IF F$TRNLNM("self") .EQS. "" -
  THEN  DEFINE /USER_MODE self 'F$EDIT(F$GETJPI("","USERNAME"),"TRIM")'
$ MAIL nla0: self /SUBJECT="''subj'"
$Done:
$ EXIT
