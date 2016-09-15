$ ! RUBYCMD.COM                                                    'F$VERIFY(0)'
$ !
$ ! Copyright © 2016 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ! usage: $ @RUBYCMD subcommand Ruby_script_file [ symbol_name ] [ TRUE | 1 ]
$ !
$ ! P1 : RUBYCMD sub-command: RUN, CMD/COMMAND, etc
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
$ wserr    = "WRITE sys$error"
$ SLASH    = "/"
$ DOT      = "."
$ COLON    = ":"
$ LBRACKET = "["
$ RBRACKET = "]"
$ !
$ CmdSet = "RUN      |" -
         + "CMD      |" -
         + "COMMAND  |" -
         + "HELP     "
$ CALL Parse "''P1'" Parse$Cmd "RUN" "''CmdSet'"
$ !
$ IF Parse$Cmd .EQS. "HELP" THEN GOTO Help
$ !
$ IF ( F$SEARCH( P3 ) .NES. "" )
$ THEN IF ( F$TYPE(ruby) .EQS. "STRING" )
$      THEN SET PROCESS /PARSE_STYLE=EXTENDED
$           ! Convert LNAME:prog.rb and/or DEV:[DIR.SUB]prog.rb into *nix-PATH style
$           ! /DEV/DIR/SUB/prog.rb, translating LNAME logical as needed:
$           Rdev = F$PARSE(P3,,,"DEVICE","SYNTAX_ONLY") - COLON
$           Rdir = F$PARSE(P3,,,"DIRECTORY","SYNTAX_ONLY") - LBRACKET - RBRACKET - LBRACKET - RBRACKET
$           i = 0
$           Rpath = SLASH
$L0:
$           elem = F$ELEMENT(i,DOT,Rdir)
$           IF ( elem .EQS. DOT ) THEN GOTO L0cont
$           IF ( elem .NES. ""  ) THEN Rpath = Rpath + elem + SLASH
$           i = i + 1
$           GOTO L0
$L0cont:
$           Rscriptname = F$PARSE(P2,,,"NAME","SYNTAX_ONLY")
$           Rscripttype = F$PARSE(P2,,,"TYPE","SYNTAX_ONLY")
$           Rscript = SLASH + Rdev + Rpath + Rscriptname + Rscripttype
$           ! Define a global command symbol for this Ruby script:
$           'P2' == "''ruby' ''Rscript'"
$      ELSE wserr "%''Fac'-E-NO_RUBY, Ruby is not installed or set-up on this system"
$      ENDIF
$ ELSE wserr "%''Fac'-E-FNF, cannot find Ruby script ""''P3'"""
$      GOTO Done
$ ENDIF
$ !
$ P2 = P2 - "*"
$ IF "''P4'" THEN IF ( F$TYPE('P2') .EQS. "STRING" ) THEN SHOW SYMBOL /GLOBAL 'P2'
$ !
$Done:
$ EXIT 1  ! 'F$VERIFY(0)'
$ !
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$Parse: SUBROUTINE
$ ! P1: command to parse
$ ! P2: global symbol to receive answer
$ ! P3: default command
$ ! P4: command set ("C1|C2[|Cn...]") -- options must be same-length fields
$ ! P5: command separator
$ IF P1 .EQS. "" THEN P1 = P3
$ IF P2 .EQS. "" THEN P2 = "Parse$Cmd"
$ IF P5 .EQS. "" THEN P5 = "|"
$ P4 = F$EDIT(P4,"UPCASE")
$ S  = F$LOCATE(P5,P4) + 1               !Determine field length
$ P4 = P5 + P4                           !Add separator to front of list...
$ T  = P5 + F$EDIT(P1,"COLLAPSE,UPCASE") !...and to target
$ L  = F$LOCATE( F$EDIT(T,"COLLAPSE,UPCASE"), P4 )      !Test substring
$ IF ( L .LT. F$LENGTH(P4) ) .AND. ( L-(L/S)*S .EQ. 0 ) !Found?
$ THEN L = ( ( L + 1 ) / S ) + 1                        !Calculate offset
$      'P2' == F$EDIT( F$ELEMENT(L,P5,P4), "COLLAPSE" )
$      EXIT 1
$ ELSE 'P2' == "$Err$"
$      wso "\''P1'\ (expecting: ''F$EDIT(P4,"COLLAPSE")')"
$      EXIT 229522  !%DCL-E-IVVERB, unrecognized command verb
$ ENDIF
$ ENDSUBROUTINE  ! Parse
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

     usage:  [1m@PRIVILEGE[0m [ [1mcmd[0m | [1m""[0m ] [ [[1m-[0m|[1mNO[0m][1mpriv_list[0m ]

     where   [1mcmd[0m = [ [1mSHOW[0m (D)   | [1mONE$SHOT[0m  | [1mSUDO[0m
                     |   [1mNORMAL[0  m | [1mDEFAULT[0m   | [1mOPERATOR[0m
                     |   [1mSYSTEM[0  m | [1mMANAGER[0m   | [1mSECURITY[0m | [1mALL[0m
                     | [ [ [1m ADD[0m | [1mPRIVILEGE[0m | [1mSUBTRACT[0m | [1mREMOVE[0m ] [1mpriv_list[0m ]

       and   [1mpriv_list[0m is a comma-separated list of VMS privilege names
             (used only if P1 is "PRIVILEGE", "ADD", "SUBTRACT" or "REMOVE" )

         SHOW        -- Display current privileges (SHOW PROCESS /PRIVILEGE).


