$ ! BAKE.COM
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1990-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$L0:
$ IF P1 .EQS. ""
$ THEN READ sys$command P1 /PROMPT="Make file: " /END=Done
$      P1 = F$EDIT(P1,"COMPRESS")
$      IF F$LOCATE(" ",P1) .NE. F$LENGTH(P1)
$      THEN P2 = F$ELEMENT(1," ",P1)
$           P1 = F$ELEMENT(0," ",P1)
$      ENDIF
$      GOTO L0
$ ENDIF
$ B$Fil = F$PARSE(P1,".mak")
$ B$Typ = F$PARSE(B$Fil,,,"TYPE","SYNTAX_ONLY") + -
          F$PARSE(B$Fil,,,"VERSION","SYNTAX_ONLY")
$ B$Log = B$Fil - B$Typ
$ B$Job = F$PARSE(B$Fil,,,"NAME","SYNTAX_ONLY")
$ IF F$TYPE(Bake$Job) .EQS. "" THEN Bake$Job == ""
$ IF Bake$Job .EQS. B$Job THEN Bake$Job == ""
$ SUBMIT site$utils:make /NAME='B$Job' /NOTIFY /NOPRINT /KEEP /LOG='B$Log' -
  /PARA=(""'B$Fil'"",""'P2'"",""'Bake$Job'"")
$ Bake$Job == B$Job
$Done:
$ EXIT
