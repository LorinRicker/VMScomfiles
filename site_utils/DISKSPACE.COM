$ ! DISKSPACE.COM  -- display available space on disks             'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1990-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ @site$utils:utility START DS 'F$ENVIRONMENT("PROCEDURE")'
$ SAY = "WRITE sys$output"
$ D$Term = F$GETDVI("sys$output","TRM")  !output to TT: or to a file?
$ !
$ IF P1 .EQS. "" THEN P1 = "S"
$ D$Size = F$LOCATE("S",P1) .NE. F$LENGTH(P1)
$ D$Rate = F$LOCATE("R",P1) .NE. F$LENGTH(P1)
$ D$MaxF = F$LOCATE("M",P1) .NE. F$LENGTH(P1)
$ !
$Size:
$ IF .NOT. D$Size THEN GOTO Rate
$ TUMB  = 0
$ TFMB  = 0
$ TFree = 0
$ Format = "!14AS !12AS !10SL !3SL% !10SL !3SL% !10SL"
$ Summary = "!4SL unit total:!12* !10SL !3SL% !10SL !3SL% !10SL"
$ !
$ CALL Heading "Disk Usage Summary on " -
  "Device         Label           Used MB    %  Free blks    %   Total MB"
$ !
$ D$Index = 0
$ D = 0
$ !
$L0:
$ D$Device = F$TRNLNM("disks$display",,D$Index)
$ IF D$Device .EQS. "" THEN GOTO D0
$ IF .NOT. F$GETDVI(D$Device,"EXISTS") THEN GOTO N0
$ IF F$GETDVI(D$Device,"DEVCLASS") .NE. 1 THEN GOTO N0
$ Disk  = F$GETDVI(D$Device,"FULLDEVNAM") - "_" - ":"
$ Label = F$GETDVI(Disk,"VOLNAM")
$ Total = F$GETDVI(Disk,"MAXBLOCK")
$ IF Total .EQ. 0 THEN Total = 1
$ Free  = F$GETDVI(Disk,"FREEBLOCKS")
$ TFree = TFree + Free
$ IF .NOT. F$GETDVI(Disk,"MNT") THEN Free = Total
$ FMB  = ( Free + 512 ) / 2 / 1000
$ TFMB = TFMB + FMB
$ Used = ( Total - Free )
$ UMB  = ( Used + 512 ) / 2 / 1000
$ TUMB = TUMB + UMB
$ TMB  = FMB + UMB
$ SFree  = Free / 100  !Scale these values down so 32-bit math doesn't overflow
$ SUsed  = Used / 100  ! (just want percentages to calculate "in the ballpark")
$ STotal = Total / 100
$ FPct = SFree * 100 / STotal
$ UPct = SUsed * 100 / STotal
$ SAY F$FAO(Format,          -
            Disk, Label,     -
            UMB, UPct, -
            Free, FPct, -
            TMB)
$ D = D + 1
$!
$N0:
$ D$Index = D$Index + 1
$ GOTO L0
$ !
$D0:
$ SAY ""
$ TMB = TUMB + TFMB
$ SAY F$FAO(Summary,D,TUMB,TUMB*100/TMB,TFree,TFMB*100/TMB,TMB)
$ IF D$Rate THEN SAY ""
$ !
$Rate:
$ IF .NOT. D$Rate THEN GOTO MaxF
$ Format  = "!14AS !12AS         !12SL !3SL%"
$ Summary = "!4SL unit total:!20* !12SL !3SL%"
$ CALL Heading "Disk IO Rate on " -
  "Device         Label                  Operations    %"
$ !
$ D$Index  = 0
$ D = 0
$ Total = 0
$L1:
$ D$Device = F$TRNLNM("disks$display",,D$Index)
$ IF D$Device .EQS. "" THEN GOTO D1
$ IF .NOT. F$GETDVI(D$Device,"EXISTS") THEN GOTO N1
$ IF F$GETDVI(D$Device,"DEVCLASS") .NE. 1 THEN GOTO N1
$ Disk_'D'  = F$GETDVI(D$Device,"FULLDEVNAM") - "_" - ":"
$ Label_'D' = F$GETDVI(Disk_'D',"VOLNAM")
$ Count_'D' = F$GETDVI(Disk_'D',"OPCNT")
$ Total = Total + Count_'D'
$ D = D + 1
$!
$N1:
$ D$Index = D$Index + 1
$ GOTO L1
$D1:
$ D = 0
$D1_1:
$ IF F$TYPE(Disk_'D') .EQS. "" THEN GOTO D1_2
$ SAY F$FAO(Format,Disk_'D',Label_'D',Count_'D',Count_'D'/(Total/100))
$ D = D + 1
$ GOTO D1_1
$D1_2:
$ SAY ""
$ SAY F$FAO(Summary,D,Total,100)
$ IF D$MaxF THEN SAY ""
$ !
$MaxF:
$ IF .NOT. D$MaxF THEN GOTO Done
$ Format  = "!14AS !12AS         !8SL !3SL%"
$ Summary = "!4SL unit total:!20* !8SL !3SL%"
$ CALL Heading "Maximum Number of Disk Files on " -
  "Device         Label               Max Files    %"
$ !
$ Total = 0
$ D$Index = 0
$ D = 0
$L2:
$ D$Device = F$TRNLNM("disks$display",,D$Index)
$ IF D$Device .EQS. "" THEN GOTO D2
$ IF .NOT. F$GETDVI(D$Device,"EXISTS") THEN GOTO N2
$ IF F$GETDVI(D$Device,"DEVCLASS") .NE. 1 THEN GOTO N2
$ Disk_'D'  = F$GETDVI(D$Device,"FULLDEVNAM") - "_" - ":"
$ Label_'D' = F$GETDVI(Disk_'D',"VOLNAM")
$ Count_'D' = F$GETDVI(Disk_'D',"MAXFILES")
$ Total = Total + Count_'D'
$ D = D + 1
$!
$N2:
$ D$Index = D$Index + 1
$ GOTO L2
$D2:
$ D = 0
$D2_1:
$ IF F$TYPE(Disk_'D') .EQS. "" THEN GOTO D2_2
$ SAY F$FAO(Format,Disk_'D',Label_'D',Count_'D',Count_'D'/(Total/100))
$ D = D + 1
$ GOTO D2_1
$D2_2:
$ SAY ""
$ SAY F$FAO(Summary,D,Total,100)
$ !
$Done:
$ @site$utils:utility EXIT DS
$ EXIT
$ !
$Heading:  SUBROUTINE
$ P1 = P1 + F$CVTIME("","ABSOLUTE","DATE") + " at " -
          + F$CVTIME("","ABSOLUTE","HOUR") + ":"    -
          + F$CVTIME("","ABSOLUTE","MINUTE")
$ IF D$Term
$ THEN @site$utils:utility HIGHLIGHT "''P1'" UNDERLINE
$      SAY DS$String
$ ELSE SAY P1
$ ENDIF
$ SAY ""
$ I = 2
$ J = 3
$H0:
$ IF ( P'J' .EQS. "" ) .OR. ( J .GT. 7 )
$ THEN IF D$Term
$      THEN H = P'I'
$           @site$utils:utility HIGHLIGHT "''H'" UNDERLINE
$           SAY DS$String
$      ELSE SAY P'I'
$           SAY F$FAO("!#*-",F$LENGTH(P'I'))
$      ENDIF
$      EXIT 1
$ ELSE SAY P'I'
$      I = I + 1
$      J = J + 1
$      GOTO H0
$ ENDIF
$ ENDSUBROUTINE
$ !
$Ctrl_C:
$Ctrl_Y:
$ RETURN %X2C
