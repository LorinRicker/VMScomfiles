$ ! SHOW_SYS$OUTPUT.COM -- 
$ !                                                                'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 2001 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  Investigate the properties of SYS$OUTPUT under various reassignments.
$ !
$ !  Use: @SHOW_SYS$OUTPUT       or      @SHOW_SYS$OUTPUT /OUTPUT=filespec
$ !
$ wso = "WRITE sys$output"
$ !
$ isTerm = F$GETDVI("sys$output","TRM")
$ IF isTerm
$ THEN wso "[1mSYS$OUTPUT is a terminal[0m"
$      wso "  Physical terminal device name is ",F$GETDVI("sys$output","TT_PHYDEVNAM")
$      wso "  Operator terminal: ",F$GETDVI("sys$output","TT_OPER")
$      wso "  Page length: ",F$INTEGER(F$GETDVI("sys$output","TT_PAGE"))
$      wso "  Page width: ",F$INTEGER(F$GETDVI("sys$output","DEVBUFSIZ"))
$ ELSE wso "[1mSYS$OUTPUT is not a terminal[0m"
$ ENDIF
$ SHOW TRANSLATION sys$output
$ wso "DEVNAM is ",F$GETDVI("sys$output","DEVNAM")
$ wso "FULLDEVNAM is ",F$GETDVI("sys$output","FULLDEVNAM")
$ wso "DEVLOCKNAM is ",F$GETDVI("sys$output","DEVLOCKNAM")
$ wso "Directory structured: ",F$GETDVI("sys$output","DIR")
$ wso "Random access: ",F$GETDVI("sys$output","RND")
$ wso "File oriented: ",F$GETDVI("sys$output","FOD")
$ wso "Record oriented: ",F$GETDVI("sys$output","REC")
$ wso "Blocked record size: ",F$INTEGER(F$GETDVI("sys$output","RECSIZ"))
$ DevClass = F$GETDVI("sys$output","DEVCLASS")
$ DevType  = F$GETDVI("sys$output","DEVTYPE")
$ GOTO DC'F$INTEGER(DevClass)'
$DC1: !Disk
$ wso "SYS$OUTPUT is currently a DISK class device (",F$INTEGER(DevClass),"), type ",F$INTEGER(DevType)
$ wso "Media name: `",F$GETDVI("sys$output","MEDIA_NAME"),"'"
$ wso "Media type: `",F$GETDVI("sys$output","MEDIA_TYPE"),"'"
$ GOTO DC0
$DC2: !Tape
$ wso "SYS$OUTPUT is currently a TAPE class device (",F$INTEGER(DevClass),"), type ",F$INTEGER(DevType)
$ GOTO DC0
$DC66: !Terminal
$ wso "SYS$OUTPUT is currently a TERMINAL class device (",F$INTEGER(DevClass),"), type ",F$INTEGER(DevType)
$ GOTO DC0
$DC67: !Line printer
$ wso "SYS$OUTPUT is currently a LINE PRINTER class device (",F$INTEGER(DevClass),"), type ",F$INTEGER(DevType)
$ GOTO DC0
$DC70: !Workstation
$ wso "SYS$OUTPUT is currently a WORKSTATION class device (",F$INTEGER(DevClass),"), type ",F$INTEGER(DevType)
$ GOTO DC0
$DC160: !Mailbox
$ wso "SYS$OUTPUT is currently a MAILBOX class device (",F$INTEGER(DevClass),"), type ",F$INTEGER(DevType)
$ GOTO DC0
$DC200: !Misc
$ wso "SYS$OUTPUT is currently a MISCELLANEOUS class device (",F$INTEGER(DevClass),"), type ",F$INTEGER(DevType)
$ GOTO DC0
$DC0:
$Done:
$ EXIT
