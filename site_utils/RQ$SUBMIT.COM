$ ! RQ$SUBMIT.COM - Submit commands for periodic execution         'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2003 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1988-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ! P1 = <command>
$ ! P2 = <day>,<time>,<increment>
$ ! P3 = <system>,<job_name>,<user>
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ wso = "WRITE sys$output"
$ Prv = F$SETPRV("CMKRNL")
$ !
$ IF F$TRNLNM("rq$package") .EQS. ""
$ THEN pdev = F$ENVIRONMENT("PROCEDURE")
$      pdev = F$PARSE(pdev,,,"DEVICE")
$      pdir = F$PARSE(pdev,,,"DIRECTORY")
$      DEFINE /NOLOG rq$package 'pdev''pdir'
$ ENDIF
$ IF F$TRNLNM("holiday") .EQS. ""    -
  THEN DEFINE /NOLOG holiday sys$disk:[]holiday,site$utils:holiday.dat
$ !
$ RQ$Command    == F$EDIT(P1,"COMPRESS,UNCOMMENT")
$ RQ$Day        == F$ELEMENT(0,",",P2)
$ RQ$Time       == F$ELEMENT(1,",",P2)
$ RQ$Incr       == F$ELEMENT(2,",",P2)
$ RQ$System     == F$ELEMENT(0,",",P3)
$ RQ$Name       == F$ELEMENT(1,",",P3)
$ RQ$User       == F$ELEMENT(2,",",P3)
$ Job_Name = ""
$ IF RQ$Name .NES. "" THEN Job_Name = "/NAME=''RQ$Name'"
$ Switches   = "/NOPRINT/IDENTIFY/KEEP/RESTART"
$ !
$ !Optional: Specify a DEV:[DIR] to redirect batch log-file to some
$ !          other place than sys$login directory (which is default)
$ LogFile    = ""
$ RQ$LogFile = F$TRNLNM("RQ$BATCH_LOGFILE")
$ IF RQ$LogFile .NES. ""
$ THEN RQ$FN      = F$PARSE(RQ$Name,,,"NAME","SYNTAX_ONLY")
$      RQ$LogFile = F$PARSE(RQ$LogFile,RQ$FN,"sys$scratch:.log",,"SYNTAX_ONLY")
$      LogFile    = "/LOG_FILE=" + RQ$LogFile
$ ENDIF
$ !
$ IF RQ$System .NES. ""
$ THEN BQue = "/QUEUE=" + RQ$System
$ ELSE BQue = ""
$ ENDIF
$ @site$utils:RQ$Absolute_Time "''RQ$Day',''RQ$Time',''RQ$Incr'" "''P4'"
$ After = "/AFTER=""" + RQ$Abs_Time + """"
$ !
$ Idt = 20
$ Parameters = "/PARAMETERS=(""" + RQ$Command + """," -
             +              """''RQ$Abs_Date',''RQ$Abs_Time',''RQ$Incr'""," -
             +              """''RQ$System',''RQ$Name',''RQ$User'"")"
$ ! And format some printable parameters:
$ PrParameters = F$FAO( "/PARAMETERS=( ""!AS"", -!/!#* ""!AS,!AS,!AS"", -!/!#* ""!AS,!AS,!AS"")", -
                        RQ$Command, Idt, -
                        RQ$Abs_Date, RQ$Abs_Time, RQ$Incr, Idt, -
                        RQ$System, RQ$Name, RQ$user )
$ !
$ IF RQ$Reque .EQS. "NO"
$ THEN RQ$batch = "site$utils:RQ$Queue.com"
$ ELSE RQ$batch = "site$utils:RQ$ReQue.com"
$ ENDIF
$ !
$ IF RQ$Verbose
$ THEN Idt = 6
$      wso F$FAO( "%RQ$SUBMIT-I-ECHO,!/   $ [1mSUBMIT !AS[0m -", RQ$batch )
$      wso F$FAO( "!#* [1m!AS !AS[0m -", Idt, Job_Name, RQ$User )
$      IF BQue    .NES. "" THEN wso F$FAO( "!#* [1m!AS[0m -", Idt, BQue )
$      IF LogFile .NES. "" THEN wso F$FAO( "!#* [1m!AS[0m -", Idt, LogFile )
$      wso F$FAO( "!#* [1m!AS[0m -",     Idt+3, Switches )
$      wso F$FAO( "!#* [1m!AS[0m -",     Idt, After )
$      wso F$FAO( "!#* [1m!AS[0m",       Idt, PrParameters )  !printables...
$ ENDIF
$ SUBMIT 'RQ$batch' -
    'Job_Name' 'RQ$User' 'BQue' -
    'LogFile' 'Switches' -
    'After' 'Parameters'
$ !
$Done:
$ RQ$Status = $STATUS
$ SET NOON
$ IF F$TYPE(Prv) .NES. "" THEN  Prv = F$SETPRV(Prv)
$ IF F$MODE() .EQS. "BATCH" -
  THEN IF F$TRNLNM("rq-holiday","lnm$process") .NES. "" -
       THEN DEASSIGN /PROCESS rq-holiday
$ EXIT (RQ$Status .OR. %X10000000)
$ !
$Ctrl_Y:
$ RETURN %X0000002C
