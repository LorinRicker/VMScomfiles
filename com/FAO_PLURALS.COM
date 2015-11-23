$ ! FAO_PLURALS.COM -- 
$ !                                                                'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1997-1999 by Evans & Ricker, Inc.  All rights reserved.
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
