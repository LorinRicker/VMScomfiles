$ ! KED$COMPILER.COM -- KED compiler -- multilingual version       'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2004 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1990-2001 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  P1 = filespec to compile
$ !  P2 = options (combinations permitted):  
$ !       "C" - "Compile"   "D" - "Debug"     "L" - "Link"
$ !       "P" - "Print"     "R" - "Run"       "V" - "Verbose"
$ !  P3 = compile command arguments
$ !  P4 = link command arguments, including additional object modules
$ !
$ SET SYMBOL /SCOPE=(NOLOCAL)
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR     THEN GOTO Done
$ IF P2 .EQS. "" THEN P2 = "CV"  !default (verbose compile)
$ KED$Options = "CDLPR"
$ KED$Opt2    = "HV"
$ !
$ sep1 = ","  !selection based on file-type;
$ sep2 = "\"  !for picking sub-options
$ xtns = ",ADA,BAS,B32,C  ,COB" -  !3-chars each element
       + ",FOR,MAR,PAS,PLI,SCN,"
$ prc1 = ",ADA\\T,BASIC\\T,BLISS\\T,CC\\T,COBOL\\T" -
       + ",FORTRAN\\T,MACRO\\T,PASCAL\/NOUSAGE\T,PLI\\T,SCAN\\T,"
$ prc2 = ",LINK,LINK,LINK,LINK,LINK" -
       + ",LINK,LINK,LINK,LINK,LINK,"
$ prc3 = ",RUN\,RUN\,RUN\,RUN\,RUN\" -
       + ",RUN\,RUN\,RUN\,RUN\,RUN\,"
$ ext  = F$PARSE(P1,,,"TYPE","SYNTAX_ONLY") - "."
$ ext  = F$FAO("!3AS",F$EXTRACT(0,3,ext))         !blank pad "C  "
$ idx  = ( F$LOCATE(ext,xtns) / 4 ) + 1
$ IF ( idx .LE. 0 ) .OR. ( idx .GT. (F$LENGTH(xtns)/4) ) THEN GOTO lng_err
$ KED$Compiler = F$ELEMENT(0,sep2,F$ELEMENT(idx,sep1,prc1))
$ KED$ComSw    = F$ELEMENT(1,sep2,F$ELEMENT(idx,sep1,prc1))
$ KED$VCL      = F$ELEMENT(2,sep2,F$ELEMENT(idx,sep1,prc1))
$                !VMS Common Language (T/F)
$ KED$Linker   = F$ELEMENT(idx,sep1,prc2)
$ KED$Use      = F$ELEMENT(0,sep2,F$ELEMENT(idx,sep1,prc3))
$ KED$Ext      = F$ELEMENT(1,sep2,F$ELEMENT(idx,sep1,prc3))
$ !
$ KED$ComName  = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ KED$Help     = F$LOCATE("H",p2) .LT. F$LENGTH(p2)
$ KED$Verbose  = F$LOCATE("V",p2) .LT. F$LENGTH(p2)
$ IF KED$Help .OR. KED$Verbose -
  THEN WRITE sys$error "%''KED$ComName'-I, ", -
       "''KED$Compiler'-''KED$Linker' options:  ''KED$Options' ''KED$Opt2'"
$ KED$sw0  = ""
$ KED$sw1  = ""
$ KED$sw2  = ""
$ KED$node = F$PARSE(p1,,,"NODE","SYNTAX_ONLY")
$ KED$dev  = F$PARSE(p1,,,"DEVICE","SYNTAX_ONLY")
$ KED$dir  = F$PARSE(p1,,,"DIRECTORY","SYNTAX_ONLY")
$ KED$name = F$PARSE(p1,,,"NAME","SYNTAX_ONLY")
$ KED$out  = KED$node + KED$dev + KED$dir + KED$name
$ !
$ P2 = F$EDIT(p2,"UPCASE")
$ IF ( F$LOCATE("C",p2) .LT. F$LENGTH(p2) ) .AND. ( F$LOCATE("D",p2) .LT. F$LENGTH(p2) ) -
  THEN P2 = P2 - "C"  !"D" implies Compile
$Loop:
$ KED$t = F$EXTRACT(0,1,p2)
$ IF KED$t .EQS. "" THEN GOTO Done
$ P2 = P2 - KED$t
$ IF F$LOCATE(KED$t,KED$Options) .LT. F$LENGTH(KED$Options) THEN GOSUB 'KED$t'$
$ GOTO Loop
$Done:
$ status = $STATUS
$ READ /END_OF_FILE=D0 /PROMPT="When ready, press <Return>: " -
       sys$command answer
$D0:
$ EXIT (%X10000000 .OR. status)
$ !
$lng_err:
$ WRITE sys$error -
  "%''KED$ComName'-E, language for file type .''ext' not supported"
$ GOTO Done
$ !
$D$:
$ KED$sw1 = "/DEBUG"
$ KED$sw2 = "/NOOPTIMIZE"
$C$:
$ IF KED$Compiler .EQS. "" THEN RETURN
$ CALL V$ "''KED$Compiler'"
$ IF KED$VCL THEN KED$sw0 = "/LIST=KED$output /OBJECT=''KED$out'"
$ DEFINE /USER_MODE sys$input sys$command
$ 'KED$Compiler' 'KED$ComSw' 'KED$sw0' 'KED$sw1' 'KED$sw2' 'P1' 'P3'
$ RETURN
$ !
$L$:
$ IF KED$Linker .EQS. "" THEN RETURN
$ CALL V$ "''KED$Linker'"
$ IF KED$Linker .EQS. "LINK" THEN KED$sw2 = "/EXECUTABLE=''KED$out'"
$ 'KED$Linker' 'KED$sw1' 'KED$sw2' 'KED$out' 'P4'
$ RETURN
$ !
$P$:
$R$:
$ IF KED$Use .EQS. "" THEN RETURN
$ IF ( KED$node .EQS. "" ) .OR. ( KED$Use .NES. "RUN" ) THEN GOTO R0
$ WRITE sys$error "%''KED$ComName'-E, ", -
                  "Cannot run program from remote node:  ''KED$out'"
$ RETURN %X000184C4  !"illegal device or filespec"
$R0:
$ CALL V$ "''KED$Use'"
$ DEFINE /USER_MODE sys$input sys$command
$ 'KED$Use' 'KED$out''KED$Ext'
$ RETURN
$ !
$ V$:  SUBROUTINE
$ IF KED$Verbose -
  THEN WRITE sys$error F$FAO ( "%!AS-I, !48AS (!AS)", -
                               KED$ComName, P1, F$CVTIME(,"ABSOLUTE","TIME") )
$ EXIT
$ ENDSUBROUTINE
$ !
$Ctrl_Y:
$ RETURN %X0000002C
