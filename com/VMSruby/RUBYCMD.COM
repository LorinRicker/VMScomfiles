$ ! RUBYCMD.COM                                                    'F$VERIFY(0)'
$ !
$ ! Copyright © 2016-2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ! usage: $ @RUBYCMD subcommand script_file [ script_args [...] | symbol_name [ TRUE | 1 ] ]
$ !  e.g.: $ @RUBYCMD RUN script_file
$ !    or: $ @RUBYCMD CMD script_file symbol_name [ true ]
$ !
$ ! P1 : RUBYCMD sub-command: RUN or CMD or COMMAND
$ ! P2 : filespec of Ruby script to invoke by global command symbol
$ ! P3 : name of global command symbol to define
$ ! P4 : if truthy, then show the global command symbol
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL THEN GOSUB CtrlY
$ !
$ Proc = F$ENVIRONMENT("PROCEDURE")
$ Fac  = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ !
$ 'Fac'_version == Fac + " v2.1 (16-Jun-2017)"
$ !
$ ! ----------------------------------------------------------------------
$ IF ( F$TYPE( DCL$CALL ) .EQS. "" )
$ THEN @lmr$login:DCL$SUBROUTINE_LIBRARY Setup TRUE
$ ENDIF
$ ! ----------------------------------------------------------------------
$ !
$ Verbose == F$TRNLNM("TOOLS$Debug")     !generic Tools debug flag
$ IF Verbose THEN SHOW SYMBOL /GLOBAL 'Fac'*
$ !
$ showCL = ""
$ !
$ RubyExt = "rb"
$ !
$ wso      = "WRITE sys$output"
$ wserr    = "WRITE sys$error"
$ SLASH    = "/"
$ DOT      = "."
$ COLON    = ":"
$ LBRACKET = "["
$ RBRACKET = "]"
$ SPLAT    = "*"
$ UPARROW  = "^"
$ !
$ CmdSet = "RUN      |" -
         + "CMD      |" -
         + "COMMAND  |" -
         + "HELP     "
$ DCL$CALL CmdParse "''P1'" Ruby$Cmd "RUN" "''CmdSet'"
$ !
$ IF ( ( Ruby$Cmd .EQS. "CMD" ) .AND. ( F$EDIT(P2,"UPCASE,COLLAPSE") .EQS. "HELP" ) ) -
  .OR. ( Ruby$Cmd .EQS. "HELP" ) THEN GOTO Help
$ !
$ ! ==========
$ ! The startup command file RUBY$STARTUP.COM invokes RUBY$DEFINE_LOGICALS.COM
$ ! (both in SYS$STARTUP) to define the system-wide logical names RUBY$ROOT
$ ! and RUBY$SHR.
$ !
$ ! The startup command file RUBY_SETUP.COM (in SYS$STARTUP or a private
$ ! directory, depending upon installation decisions/options) defines key
$ ! process/job-private logical names: RUBY$BASE, RUBY$MINE and RUBY$LIB,
$ ! plus the foreign command symbol 'RubyX' used herein:
$ !    RubyX == "$ruby$root:[bin]ruby"
$ ! ==========
$ !
$ IF Verbose THEN showCL = "SHOW"
$ DCL$CALL CommandLine LINUX "" 'showCL'
$ !
$ IF ( F$TYPE(RubyX) .EQS. "STRING" )
$ THEN CONTINUE   ! 'F$VERIFY(0)'
$      ! ==========
$      ! Convert LNAME:prog.rb and/or DEV:[DIR.SUB]prog.rb into *nix-PATH style
$      ! /DEV/DIR/SUB/prog.rb, translating LNAME logical as needed:
$      Rdev = F$PARSE(P2,,,"DEVICE","SYNTAX_ONLY") - COLON
$      Rdir = F$PARSE(P2,,,"DIRECTORY","SYNTAX_ONLY") - LBRACKET - RBRACKET - LBRACKET - RBRACKET
$      i = 0
$      Rpath = SLASH
$L0:
$      elem = F$ELEMENT(i,DOT,Rdir)
$      IF ( elem .EQS. DOT ) THEN GOTO L0cont
$      IF ( F$LOCATE( UPARROW, elem ) .EQ. F$LENGTH( elem )-1 )
$      THEN ! convert escaped dots "^." in dir-names to literal dots ".",
$           !    e.g.: "2^.2^.0" -> "2.2.0"
$           Rpath = Rpath + elem + DOT - UPARROW
$      ELSE IF ( elem .NES. ""  ) THEN Rpath = Rpath + elem + SLASH
$      ENDIF
$      i = i + 1
$      GOTO L0
$L0cont:
$      Rscriptname = F$PARSE(P2,,,"NAME","SYNTAX_ONLY")
$      Rscripttype = F$PARSE(P2,,,"TYPE","SYNTAX_ONLY")
$      IF ( Rscripttype .EQS. DOT )
$      THEN Rscripttype = Rscripttype + RubyExt
$           P2          = P2 + DOT + RubyExt
$      ENDIF
$      Rscript = SLASH + Rdev + Rpath + Rscriptname + Rscripttype
$      Rscript = F$EDIT( Rscript, "LOWERCASE" )
$      IF Verbose
$      THEN wso "        Rdev: ""''Rdev'"""
$           wso "       Rpath: ""''Rpath'"""
$           wso " Rscriptname: ""''Rscriptname'"""
$           wso " Rscripttype: ""''Rscripttype'"""
$           wso "     Rscript: ""''Rscript'"""
$      ENDIF
$      ! ==========
$      IF ( F$SEARCH( P2 ) .NES. "" )
$      THEN GOTO 'Ruby$Cmd'$
$ !
$RUN$:      ! ==========
$           Args = F$EDIT( "''P3' ''P4' ''P5' ''P6' ''P7' ''P8'","COMPRESS" )
$           IF Verbose
$           THEN wso "$ DEFINE /USER_MODE sys$input sys$command"
$                wso "$ RubyX ''Rscript' ''Args'"
$           ENDIF
$           DEFINE /USER_MODE sys$input sys$command
$           RubyX 'Rscript' 'Args'
$           GOTO Done
$ !
$CMD$:
$COMMAND$:  ! ==========
$           ! Define a global command symbol for this Ruby script:
$           'P3' == "''RubyX' ''Rscript'"
$           symname = P3 - SPLAT
$           IF ( "''P4'" ) .OR. ( Verbose )
$           THEN wso F$FAO( "%!AS-I-SYMBOL, !AS == ""!AS !AS""", -
                            Fac, P3, RubyX, Rscript )
$                IF ( F$TYPE('symname') .EQS. "STRING" ) THEN SHOW SYMBOL /GLOBAL 'symname'
$           ENDIF
$           GOTO Done
$ !
$      ELSE wserr "%''Fac'-E-FNF, cannot find Ruby script ""''Rscript'"""
$           GOTO Done
$      ENDIF
$ ELSE wserr "%''Fac'-E-NO_RUBY, Ruby is not installed or set-up on this system"
$ ENDIF
$ !
$Done:
$ DCL$CALL DeleteGloSyms "Ruby$Cmd,Ruby$Cmd_NUM"
$ EXIT 1  ! 'F$VERIFY(0)'
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

     usage:  $ [1m@RUBYCMD subcommand script_file [0m[ [1margs[0m [[1m...[0m]
                                                 | [1msymname[0m [ [1mTRUE[0m | [1m1[0m ] ]

     where [1msubcommand[0m is one of:

         [1mRUN[0m     -- Run the following Ruby script immediately and directly.

         [1mCMD[0m or  -- Create a DCL global command symbol (alias) to run the
         [1mCOMMAND[0m    Ruby script.

     and [1margs[0m [[1m...[0m] is a space-separated list of up to six (6) Ruby script
                    arguments (P3..P8),

      [4mor[0m [1msymname[0m is the name of a DCL global command symbol (alias) which is
                    to be defined to run this Ruby script (an abbreviation
                    point "glo*sym" can be used),

       and [[1mTRUE[0m|[1m1[0m] is a "truthy" value to echo that global command symbol
                    when defined.

$ !
$ EXIT 1  ! 'F$VERIFY(0)'
$ !
