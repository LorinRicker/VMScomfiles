$ ! FILE$REVERSION.COM --                                          'F$VERIFY(0)'
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
$ !  use: @FILE$REVERSION fname[,fname...] [[;]version] [/LOG] [/DIRECTORY]
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ IF F$TYPE(Util$Fac) .EQS. ""
$ THEN Util == "@site$utils:utility.com"
$      Util START REV
$ ENDIF
$ !
$ wso = "WRITE sys$output"
$ DD  = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(DD,,,"NAME","SYNTAX_ONLY")
$ DD  = F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ !
$ Verbose = F$TRNLNM("Tools$Debug")
$ !
$ IF F$EXTRACT(0,1,P2) .EQS. "/"
$ THEN P8 = P7
$      P7 = P6
$      P6 = P5
$      P5 = P4
$      P4 = P3
$      P3 = P2
$      P2 = ""
$ ENDIF
$ Quals = P3 + " " + P4 + " " + P5 + " " + P6 + " " + P7 + " " + P8
$ Quals = F$EDIT(Quals,"COMPRESS,TRIM,UPCASE")
$ QLen  = F$LENGTH(Quals)
$ IF F$LOCATE("/L",Quals) .LT. QLen
$ THEN Log = "/LOG"
$ ELSE Log = ""
$ ENDIF
$ DoDir = ( F$LOCATE("/D",Quals) .LT. QLen )
$ !
$L1:
$ IF P1 .EQS. "" -
  THEN READ /PROMPT="filename: " /END_OF_FILE=Done sys$command P1
$ IF P1 .EQS. "" THEN GOTO L1
$ IF F$EXTRACT(0,1,P1) .EQS. "?" THEN GOTO Help
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
$ Fl = F$SEARCH(FS)
$ IF Fl .NES. ""
$ THEN CALL TheProcess "''Fl'" "''P2'"
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
$ IF ( P1 .NES. "" ) .AND. ( DoDir ) -
  THEN DIRECTORY /SIZE /DATE /PROT 'P1'
$ Util EXIT REV
$ EXIT
$ !
$ !
$ !          ==========
$TheProcess: SUBROUTINE
$ ! P1 : File to process
$ ! P2 : (optional) specific version to set
$ ON CONTROL_Y THEN EXIT %X2C
$ CurVers = F$PARSE(P1,,,"VERSION","SYNTAX_ONLY")
$ FN      = P1 - CurVers
$ CurVers = CurVers - ";"
$ CV      = F$INTEGER(CurVers)
$ PreVers = F$SEARCH("''FN';-1")
$ IF PreVers .NES. ""
$ THEN PreVers = F$PARSE(PreVers,,,"VERSION","SYNTAX_ONLY") - ";"
$      PV      = F$INTEGER(PreVers)
$ ELSE PreVers = "0"
$      PV      =  0
$ ENDIF
$ IF P2 .NES. ""           !user provided the ;version
$ THEN P2 = P2 - ";"
$      TV = F$INTEGER(P2)
$      IF TV .GT. PV
$      THEN TarVers = P2
$      ELSE FN = F$PARSE(P1,,,"NAME","SYNTAX_ONLY") + F$PARSE(P1,,,"TYPE","SYNTAX_ONLY")
$           wso "%''Fac'-E-BAD_VERSION, cannot rename below ''FN'[1m;''PreVers'[0m"
$           GOTO TP0
$      ENDIF
$ ELSE TV = PV + 1         !use the next-higher ;version over antecedent file
$      TarVers = F$STRING(TV)
$ ENDIF
$ !
$ IF Verbose THEN wso "$ RENAME ''P1' ''FN';''TarVers'"
$ RENAME 'P1' 'FN';'TarVers' 'Log'
$ !
$TP0:
$ EXIT 1
$ ENDSUBROUTINE  ! TheProcess
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE sys$input

  use: @FILE$REVERSION fname[,fname...] [[;]version] [/LOG] [/DIRECTORY]

  where:

    P1 is a single filespec ([1mfname[0m), a file-list ([1mfname,fname,...[0m).
      Wildcards are supported for both [1mfname[0m and [1mfname,fname,...[0m forms.

    P2 is the optional [1mversion number[0m (with or without leading ";") to which
      you want to reset the file's version.  By default, the "top version" of
      the file will be renamed to the version which is one higher than it's
      own immediate antecedent; that is, given FOO.BAR;100, FOO.BAR;88 and
      FOO.BAR;86, the command:

      $ [1m@FILE$REVERSION FOO.BAR[0m

      will rename FOO.BAR;100 to FOO.BAR;89, while:

      $ @FILE$REVERSION FOO.BAR [1m90[0m           !(or [1m;90[0m)

      will rename FOO.BAR;100 to FOO.BAR;90.

      Note that if you attempt to rename a file to anything less than the
      version of it's immediate antecedent will result in an error; for
      example, the command:

      $ @FILE$REVERSION FOO.BAR [1m;81[0m

      generates the error

      %FILE$REVERSION-E-BAD_VERSION, cannot rename below FOO.BAR[1m;88[0m

    [1m/LOG[0m displays the result of the reversion operation for each file.

    [1m/DIRECTORY[0m displays a summary directory listing of the files processed.

$ !
$ P1 = ""  !don't let DIRECTORY command fire on exit after Help...
$ DoDir = 0
$ GOTO Done
