$ ! FAO_PLURALS.COM -- 
$ !                                                                'F$VERIFY(0)'
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
$ !  Demonstrate several ways to form irregular plurals with F$FAO.
$ !
$ wso = "WRITE sys$output"
$ IF P1 .EQS. "" THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="Count? "
$ P1 = F$INTEGER(P1)
$ !
$ wso F$FAO("!ZL cat!%S.", P1)
$ wso F$FAO("!ZL kitt!1%Cy!%Eies!%F.", P1)
$ wso F$FAO("!ZL process!1%C!%Ees!%F.", P1)
$ wso F$FAO("!ZL librar!1%Cy!%Eies!%F.", P1)
$ wso F$FAO("!ZL child!1%C!%Eren!%F.", P1)
$ ! Example from OpenVMS DCL Dictionary, A-M, p. DCLI-320:
$ wso F$FAO("There !0UL!1%Cis!%Eare!%F !-!UL !-!0UL!1%Cchild!%Echildren!%F here.", P1)
$ wso F$FAO("!UL cat!%S !-!0UL!1%Cis!%Eare!%F meowing.", P1)
$ !
$Done:
$ EXIT
