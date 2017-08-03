$ ! RUBY_SETUP.COM                                                 'F$VERIFY(0)'
$ !
$ ! Copyright © 2015-2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ! =================
$VolCheck: SUBROUTINE
$ ! P1 = volume to check
$ ! P2 = Personal Ruby subdirectory
$ !
$ DJ = "DEFINE /JOB /NOLOG "
$ !
$ IF .NOT. F$GETDVI(P1,"ODS5")
$ THEN wso "%''Fac'-W-NOT_ODS5, volume ''P1' is ODS2, mixed-case filenames not supported"
$      RubyVolumeODS5 == "FALSE"
$ ELSE RubyVolumeODS5 == "TRUE"
$ ENDIF
$ !
$ RubyVolumeOkay == "FALSE"
$ dsk  = P1 - ":"
$ dir  = P2 - "[" - "]"
$ d0   = F$ELEMENT(0,".",dir)
$ d0lc = F$EDIT( d0, "LOWERCASE" )
$ d1   = F$ELEMENT(1,".",dir)
$ d1lc = F$EDIT( d1, "LOWERCASE" )
$ IF ( d1lc .EQS. "ruby" ) .AND. ( d0lc .EQS. F$EDIT( UName, "LOWERCASE" ) )
$ THEN testf = dsk + ":[" + d0 + "]"
$      IF ( F$SEARCH( "''testf'''d1'.dir" ) .NES. "" )
$      THEN DJ ruby$base "''dsk':[''d0'.''d1'.]" /TRANS=CONCEALED
$           DJ ruby$mine "''dsk':[''d0'.''d1']"
$           DJ ruby$lib  "''dsk':[''d0'.''d1'.LIB]"
$      ENDIF
$      RubyVolumeOkay == "TRUE"
$ ELSE IF ( d0lc .EQS. "ruby" )
$      THEN testf = dsk + ":[000000]"
$           IF ( F$SEARCH( "''testf'''d1'.dir" ) .NES. "" )
$           THEN DJ ruby$base "''dsk':[''d1'.]" /TRANS=CONCEALED
$                DJ ruby$mine "''dsk':[''d1']"
$                DJ ruby$lib  "''dsk':[''d1'.LIB]"
$           ENDIF
$           RubyVolumeOkay == "TRUE"
$      ENDIF
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! VolCheck
$ !
$ !
$ ! =================
$Main:
$ RubyStartup  == "sys$startup:ruby$startup.com"
$ RubyShutdown == "sys$startup:ruby$shutdown.com"
$ !
$ ! No Ruby-startup comfile?  Don't even bother continuing:
$ IF ( F$SEARCH(RubyStartup) .EQS. "" ) THEN EXIT
$ !
$ UName = F$EDIT( F$GETJPI( "", "USERNAME" ), "TRIM,LOWERCASE" )
$ Proc  = F$ENVIRONMENT("PROCEDURE")
$ Fac   = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ node  = F$EDIT( F$GETSYI("NODENAME"), "TRIM" )
$ !
$ wso = "WRITE sys$output"
$ !
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ !
$ RubyVolumeOkay == 0  ! initial assumptions
$ RubyVolumeODS5 == 0
$ !
$ReCheck:
$ IF ( F$TRNLNM("ruby$root") .NES. "" )
$ THEN IF Verbose THEN wso "%''Fac'-I-Ruby, setting up for Ruby/VMS..."
$      RubyX == "$ruby$root:[bin]ruby"
$ !
$      f = "COM:RUBYCMD"
$      IF ( F$SEARCH( "''f'.COM" ) .NES. "" )
$      THEN rubyc*md   == "@''f' CMD"  ! rubycmd and mkrubycmd are synonyms
$           mkrub*ycmd == "@''f' CMD"
$           ruby       == "@''f' RUN"
$      ELSE IF Verbose THEN wso "%''Fac'-E-FNF, cannot find command file ''f'.COM"
$      ENDIF
$ !
$      ldfile = "COM:MKRUBY_LD"
$      IF ( F$SEARCH( "''ldfile'.COM" ) .NES. "" )
$      THEN @'ldfile' "LDA1024:" "''UName'"
$           vol = F$TRNLNM( "DISK$RUBY" )
$      ELSE vol = F$TRNLNM( "SYS$LOGIN_DEVICE" ) - ":"
$      ENDIF
$      rdir = "[''UName'.ruby]"
$      CALL VolCheck "''vol'" "''rdir'"
$      IF .NOT. RubyVolumeOkay
$      THEN vol = F$TRNLNM("SYS$LOGIN_DEVICE","LNM$JOB") - ":"
$           CALL VolCheck "''vol'" "''rdir'"
$      ENDIF
$      IF RubyVolumeODS5
$      THEN SET PROCESS /PARSE_STYLE=EXTENDED
$           wso "%''Fac'-I-DCLPARSE, parse style set to EXTENDED..."
$      ENDIF
$ !
$ ELSE wso "%''Fac'-E-NoRuby, Ruby for VMS not yet started..."
$      READ sys$command answer /END_OF_FILE=Finish -
         /PROMPT="Start Ruby for VMS on ''node' (Y/n)? "
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
$Finish:
$ IF ( F$TYPE(ruby) .EQS. "STRING" )
$ THEN IF Verbose
$      THEN SHOW LOGICAL /SYSTEM Ruby*
$           SHOW LOGICAL /JOB    Ruby*
$           wso ""
$           SHOW SYMBOL /GLOBAL *Ruby*
$           wso ""
$      ENDIF
$ !
$      wso "%''Fac'-I-VERSION, version of VMS Ruby is:"
$      RubyX -v   ! show version
$ ENDIF
$ EXIT 1     ! 'F$VERIFY(0)'
$ !
