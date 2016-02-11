$ ! SHOW_SYS$OUTPUT.COM -- 
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
