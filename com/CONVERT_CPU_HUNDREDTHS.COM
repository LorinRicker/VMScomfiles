$ ! CONVERT_CPU_HUNDREDTHS.COM -- 
$ !                                                                'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1997-1999 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  Test/demo of algorithm to convert DCL integer containing CPU time
$ !    used (in hundredths of a second) to delta-time (elapsed) format,
$ !    DD HH:MM:SS.CC.
$ !
$ !
$ IF P1 .NES. ""
$ THEN Img = F$INTEGER(P1)
$ ELSE Img = F$GETJPI("","CPUTIM")
$ ENDIF
$ !
$ DD = 0
$ HH = 0
$ MM = 0
$ SS = 0
$ IF Img .GE. 8639999
$ THEN DD = Img / 8640000       !extract Days (HH*24)
$      IF DD .GT. 0 THEN Img = Img - ( DD * 8640000 )
$ ENDIF
$ IF Img .GE. 359999
$ THEN HH = Img / 360000        !extract Hours (MM*60)
$      IF HH .GT. 0 THEN Img = Img - ( HH * 360000 )
$ ENDIF
$ IF Img .GE. 5999
$ THEN MM = Img / 6000          !extract Minutes (SS*60)
$      IF MM .GT. 0 THEN Img = Img - ( MM * 6000 )
$ ENDIF
$ IF Img .GE. 100               !original integer is in SS/100 (hundredths)
$ THEN SS = Img / 100           !extract Seconds, what's left over is .CC
$      IF SS .GT. 0 THEN Img = Img - ( SS * 100 )
$ ENDIF
$ Img = F$FAO("!2SL !2ZL:!2ZL:!2ZL.!2ZL", DD, HH, MM, SS, Img)
$ !
$ WRITE sys$output Img
$ !
$Done:
$ EXIT
