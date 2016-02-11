$ ! RUBY_SETUP.COM                                                 'F$VERIFY(0)'
$ !
$ ! Copyright © 2015-2016 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ Proc = F$ENVIRONMENT("PROCEDURE")
$ Fac  = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ !
$ wso = "WRITE sys$output"
$ !
$ RubyVolumeOkay == 0  ! initial assumptions
$ RubyVolumeODS5 == 0
$ !
$ RubyStartup  == "sys$startup:ruby$startup.com"
$ RubyShutdown == "sys$startup:ruby$shutdown.com"
$ !
$ReCheck:
$ IF ( F$TRNLNM("ruby$root") .NES. "" )
$ THEN wso "%''Fac'-I-Ruby, setting up for Ruby/VMS..."
$      ruby == "$ruby$root:[bin]ruby"
$ !
$      vol  = F$TRNLNM("SYS$SYSDEVICE","LNM$SYSTEM") - ":"
$      rdir = "[LRICKER.RUBY]"
$      CALL VolCheck "''vol'" "''rdir'"
$      IF .NOT. RubyVolumeOkay
$      THEN vol = F$TRNLNM("SYS$LOGIN_DEVICE","LNM$JOB") - ":"
$           CALL VolCheck "''vol'" "''rdir'"
$      ENDIF
$      IF RubyVolumeODS5
$      THEN SET PROCESS /PARSE_STYLE=EXTENDED
$           wso "%''Fac'-I-DCLPARSE, parse style set to extended..."
$      ENDIF
$ !
$ ELSE wso "%''Fac'-E-NoRuby, Ruby for VMS not installed..."
$      READ sys$command answer /END_OF_FILE=Done -
         /PROMPT="Start Ruby for VMS (Y/n)? "
$      IF ( F$EDIT( F$EXTRACT(0,1,answer),"UPCASE,TRIM") .NES. "N" )
$      THEN IF ( F$SEARCH( RubyStartup ) .NES. "" )
$           THEN prv = F$SETPRV("SYSPRV,SYSNAM,CMKRNL")
$                @'RubyStartup'
$                prv = F$SETPRV(prv)
$           ENDIF
$      WAIT 00:00:01
$      GOTO ReCheck
$      ENDIF
$ ENDIF
$ !
$Done:
$ IF F$TYPE(ruby) .EQS. "STRING"
$ THEN wso ""
$      SHOW LOGICAL /SYSTEM /FULL Ruby*
$      SHOW LOGICAL /JOB /FULL Ruby*
$      wso ""
$      SHOW SYMBOL /GLOBAL Ruby*
$      wso ""
$      ruby -v   ! show version
$ ENDIF
$ EXIT 1     ! 'F$VERIFY(0)'
$ !
$VolCheck: SUBROUTINE
$ ! P1 = volume to check
$ ! P2 = Personal Ruby subdirectory
$ !
$ DJ = "DEFINE /JOB /NOLOG "
$ !
$ RubyVolumeOkay == "FALSE"
$ dir = P2 - "[" - "]"
$ d0  = F$EDIT( F$ELEMENT(0,".",dir), "LOWERCASE" )
$ d1  = F$EDIT( F$ELEMENT(1,".",dir), "LOWERCASE" )
$ IF ( d1 .EQS. "ruby" ) .AND. ( d0 .EQS. "lricker" )
$ THEN testf = P1 + ":[" + d0 + "]"
$      IF ( F$SEARCH( "''testf'''d1'.dir" ) .NES. "" )
$      THEN DJ ruby$base "''P1':[''d0'.]" /TRANS=CONCEALED
$           DJ ruby$mine "''P1':[''d0'.''d1']"
$           DJ ruby$lib  "''P1':[''d0'.''d1'.lib]"
$      ENDIF
$      RubyVolumeOkay == "TRUE"
$ ELSE IF ( d0 .EQS. "ruby" )
$      THEN testf = P1 + ":[000000]"
$           IF ( F$SEARCH( "''testf'''d1'.dir" ) .NES. "" )
$           THEN DJ ruby$base "''P1':[''d1'.]" /TRANS=CONCEALED
$                DJ ruby$mine "''P1':[''d1']"
$                DJ ruby$lib  "''P1':[''d1'.lib]"
$           ENDIF
$           RubyVolumeOkay == "TRUE"
$      ENDIF
$ ENDIF
$ IF .NOT. F$GETDVI(P1,"ODS5")
$ THEN wso "%''Fac'-W-NOT_ODS5, volume ''P1' is ODS2, mixed-case filenames not supported"
$      RubyVolumeODS5 == "FALSE"
$ ELSE RubyVolumeODS5 == "TRUE"
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! VolCheck
