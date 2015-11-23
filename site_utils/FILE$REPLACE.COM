$ ! FILE$REPLACE.COM --                                            'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ !
$ !  use: @FILE$REPLACE fspec[,fspec...] target [ copy_qualifiers ]
$ !
$MAIN:
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ wso = "WRITE sys$output"
$ DD  = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(DD,,,"NAME","SYNTAX_ONLY")
$ DD  = F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ Ver = F$TRNLNM("Tools$Debug")
$ !
$ IF F$EXTRACT(0,1,P1) .EQS. "?" THEN GOTO Help
$ !
$ ! Qualifiers -- swap 'em to the end...
$Q1:
$ IF F$EXTRACT(0,1,P1) .EQS. "/"
$ THEN Tmp = P1
$      P1 = P2
$      P2 = P3
$      P3 = P4
$      P4 = P5
$      P5 = P6
$      P6 = P7
$      P7 = P8
$      P8 = Tmp
$      GOTO Q1
$ ENDIF
$Q2:
$ IF F$EXTRACT(0,1,P2) .EQS. "/"
$ THEN Tmp = P2
$      P2 = P3
$      P3 = P4
$      P4 = P5
$      P5 = P6
$      P6 = P7
$      P7 = P8
$      P8 = Tmp
$      GOTO Q2
$ ENDIF
$ Quals = P3 + " " + P4 + " " + P5 + " " + P6 + " " + P7 + " " + P8
$ Quals = F$EDIT(Quals,"COMPRESS,TRIM,UPCASE")
$ !
$L1:
$ IF P1 .EQS. ""
$ THEN READ /PROMPT="Source filespec: " /END_OF_FILE=Done sys$command P1
$      IF P1 .EQS. "" THEN GOTO L1
$ ENDIF
$ !
$L2:
$ IF P2 .EQS. ""
$ THEN READ /PROMPT="Target filespec: " /END_OF_FILE=Done sys$command P2
$      IF P2 .EQS. "" THEN GOTO L2
$ ENDIF
$ !
$DirectSpec:
$ i = 0
$ F0 = "sys$disk:[]"
$DS0:
$ Fl = F$ELEMENT(i,",",P1)
$ IF Fl .EQS. "," THEN GOTO Done               !more files?
$ FS   = F$PARSE(Fl,F0,"*.*",,"SYNTAX_ONLY")   !expand w/sticky dev:[dir]
$ FLen = F$LENGTH(FS)
$ Wild = ( F$LOCATE("*",FS) .LT. FLen ) .OR. ( F$LOCATE("%",FS) .LT. FLen )
$ GotOne = 0
$DS1:
$ F0 = F$PARSE(Fl,F0,,"DEVICE","SYNTAX_ONLY") -  !save sticky dev:[dir]
     + F$PARSE(Fl,F0,,"DIRECTORY","SYNTAX_ONLY")
$ Fl = F$SEARCH(FS,1)
$ IF Fl .NES. ""
$ THEN CALL TheProcess "''Fl'" "''F0'" "''P2'" "''Quals'"
$     !===============
$      IF Wild
$      THEN GotOne = 1
$           GOTO DS1       !next wildcard
$      ELSE i = i + 1
$           GOTO DS0       !next comma-element
$      ENDIF
$ ELSE IF .NOT. GotOne THEN wso "%''Fac'-E-FNF, cannot find ''FS'"
$      i = i + 1
$      GOTO DS0
$ ENDIF
$ !
$Done:
$ SET NOON
$ EXIT
$ !
$FNF:
$ wso "%''Fac'-E-FNF, cannot find @-list ''Files'"
$ wso ""
$ wso "  Creating indirect @-list file ''Files'"
$ wso ""
$ GOTO MakeIndirect
$ !
$ !
$ !          ==========
$TheProcess: SUBROUTINE
$ ! P1 = Source filespec
$ ! P2 = Sticky dev:[dir]
$ ! P3 = Target filespec
$ ! P4 = Qualifiers
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO TPDone
$ !
$ P1 = F$PARSE(P1,P2,,,"SYNTAX_ONLY")           !inherit sticky dev:[dir]
$ P3 = F$PARSE(P3,P1,"*.*;*",,"SYNTAX_ONLY")    ! & target gets ;* - version
$ !
$ P3V  = F$PARSE(P3,,,"VERSION","SYNTAX_ONLY")
$ P3W  = P3 - P3V + ";*"
$ P3V  = P3V - ";"
$ P3VI = F$INTEGER(P3V)
$ P3C  = F$SEARCH(P3W)
$ IF P3C .NES. ""
$ THEN P3CV  = F$PARSE(P3C,,,"VERSION","SYNTAX_ONLY") - ";"
$      P3CVI = F$INTEGER(P3CV)
$      IF P3CVI .LE. P3VI
$      THEN IF Ver
$           THEN wso "$ COPY /REPLACE ''P1' ''P3' ''P4'"
$           ELSE COPY /REPLACE 'P1' 'P3' 'P4'
$           ENDIF
$      ELSE wso F$FAO("%!AS-W-HIGHVER, a higher version of !AS exists", -
                       Fac, P3)
$           DF = F$PARSE(P3,,,"DEVICE","SYNTAX_ONLY") -
               + F$PARSE(P3,,,"DIRECTORY","SYNTAX_ONLY") -
               + F$PARSE(P1,,,"NAME","SYNTAX_ONLY") -
               + F$PARSE(P1,,,"TYPE","SYNTAX_ONLY")
$           DIRECTORY /SIZE /DATE /PROTECTION 'DF'
$           READ sys$command Answer /END_OF_FILE=TPDone -
              /PROMPT="Copy Replace existing or Supercede ([1mR[0m/S)? "
$           Answer = F$PARSE(Answer,"Replace",,"NAME","SYNTAX_ONLY")
$           IF F$EXTRACT(0,1,Answer) .EQS. "R"
$           THEN !Replace the existing version
$                IF Ver
$                THEN wso "$ COPY /REPLACE ''P1' ''P3' ''P4'"
$                ELSE COPY /REPLACE 'P1' 'P3' 'P4'
$                ENDIF
$           ELSE !Supercede, create new higher version
$                P3CVI = P3CVI + 1
$                P3V = ";" + F$STRING(P3CVI)
$                P3 = F$PARSE(P3,,,"NODE","SYNTAX_ONLY") -
                    + F$PARSE(P3,,,"DEVICE","SYNTAX_ONLY") -
                    + F$PARSE(P3,,,"DIRECTORY","SYNTAX_ONLY") + P3V
$                IF Ver
$                THEN wso "$ COPY ''P1' ''P3' ''P4'"
$                ELSE COPY 'P1' 'P3' 'P4'
$                ENDIF
$           ENDIF
$      ENDIF
$ ELSE IF Ver
$      THEN wso "$ COPY ''P1' ''P3W' ''P4'"
$      ELSE COPY 'P1' 'P3W' 'P4'
$      ENDIF
$ ENDIF
$ !
$TPDone:
$ EXIT 1
$ ENDSUBROUTINE  ! TheProcess
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  FILE$REPLACE is an intelligent wrapper for the COPY /REPLACE command.
  This command file supplies appropriate defaults and wildcards for the
  target/output file specification.

  use:  $ [1m@FILE$REPLACE[0m [1mfspec[0m[[1m,fspec[0m...] [1mtarget[0m [ [1mcopy_qualifiers[0m ]

  where:
  
   [1mP1[0m is a single source file specification ([1mfspec[0m), or a comma-separated
      file-list ([1mfspec,fspec,...[0m).  Wildcards are supported.

   [1mP2[0m is the target or output file specification, usually simply a device
      and directory Dev:[Dir].  For each source filespec, the target is
      given appropriate derived filespec components; however, the version
      specification for the target becomes `[1m;*[0m' to force COPY /REPLACE to
      replace an existing instance of the target file, if it exists, with
      a new/fresh copy of the source, retaining the same version number.

   The [1mcopy_qualifiers[0m that can be used include any COPY command qualifiers
      which do not conflict with the COPY [4m/REPLACE[0m qualifier.  These include:

      /LOG /CONFIRM /PROTECTION /EXCLUDE
      /BEFORE /SINCE /BY_OWNER
      /CREATED /MODIFIED /EXPIRED

      Other COPY command qualifiers may conflict with /REPLACE, so you may
      want to experiment with test files and directories before using this
      command procedure on a production situation.

$ !
$ GOTO Done
$ !
