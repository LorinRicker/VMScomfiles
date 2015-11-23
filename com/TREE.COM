$ ! TREE.COM
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1988-2001 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  use:  @TREE [/OUTPUT=file] [directory_root] [/[NO]LINES]
$ !
$ !  where: [directory_root] specifies the root of the directory tree to draw;
$ !            if omitted, the directory tree is drawn from the current default
$ !            directory.
$ !         /OUTPUT=file redirects the output to a file; if present, this
$ !            qualifier must appear immediately after the command verb and
$ !            before the directory_root parameter (P1).
$ !         /LINES is the default which draws the directory tree using the
$ !            DEC Line-Drawing Character Set; /NOLINES draws the tree using
$ !            dashes and bars ("|--").  Use /NOLINES if the output is to be
$ !            printed on a printer which does not support the line-drawing
$ !            character set.
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ wso   = "WRITE sys$output"
$ Level = 0
$ !
$ Here = F$ENVIRONMENT("DEFAULT")
$ Dir  = Here
$ IF P1 .EQS. ""
$ THEN P1 = Here
$ ELSE SET DEFAULT 'P1'
$ ENDIF
$ wso ""
$ wso P1
$ !
$ Quals = P2 + P3 + P4 + P5 + P6 + P7 + P8
$ QLen  = F$LENGTH(Quals)
$ !
$ LineCharSet = ( F$LOCATE("/NOLI",Quals) .GE. QLen )  ! /NOLINE *not* found?
$ !
$ IF LineCharSet
$ THEN Line = "tqqqqqqq"
$      Bar  = "x"
$ ELSE Line = "|-------"
$      Bar  = "|"
$ ENDIF
$ Indt = Bar + "       "
$ Blanks = Line
$ !
$ IF LineCharSet
$ THEN wso "",Bar,""
$ ELSE wso Bar
$ ENDIF
$ !
$Loop:
$ Last = Dir
$ Dir  = F$SEARCH("*.DIR",Level)
$ DNam = Dir - F$PARSE(Dir,,,"DEVICE")
$ IF DNam .EQS. "[000000]000000.DIR;1" THEN GOTO Loop
$ IF Dir .NES. ""
$ THEN GOTO Deeper
$ ELSE GOTO Higher
$ ENDIF
$ !
$Deeper:
$ Level = Level + 1
$ IF Level .NE. 1 THEN Blanks = Indt + Blanks
$ vz = F$PARSE(Dir,,,"NAME")
$ IF LineCharSet
$ THEN wso "",Blanks,"","[",vz,"]"
$ ELSE wso Blanks,"[",vz,"]"
$ ENDIF
$ SET DEFAULT [.'vz']
$ GOTO Loop
$ !
$Higher:
$ IF Level .EQ. 0
$ THEN IF LineCharSet
$      THEN wso "mq`"
$      ELSE wso "+-","«","»"
$      ENDIF
$      GOTO Done
$ ENDIF
$ IF Last .EQS. ""
$ THEN IF LineCharSet
$      THEN Tmp = Blanks - Line + Bar
$           wso "",Tmp,""
$      ELSE wso Blanks - "-------"
$      ENDIF
$ ENDIF
$ Level = Level - 1
$ Blanks = Blanks - Indt
$ SET DEFAULT [-]
$ GOTO Loop
$ !
$Done:
$ SET NOON
$ wso ""
$ SET DEFAULT 'Here'
$ EXIT
$ !
$ !   gives:
$ !
$ !   ISLKP1> @tree.com data01:[000000]
$ !
$ !   DATA01:[000000]
$ !   |
$ !   |-------[ISLK01]
$ !   |-------[ISLK13]
$ !   |       |-------[ISLK_DAT]
$ !   |       |       |-------[DB_PRO]
$ !   |       |
$ !   |
$ !   |-------[ISLK_DAT]
$ !   |       |-------[ORDER]
$ !   |       |-------[ZH]
$ !   |
$ !   |-------[TOTO]
$ !   |       |-------[SYSMGR]
$ !   |
$ !   +--[EOD]
