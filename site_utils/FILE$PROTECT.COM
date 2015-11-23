$ ! FILE$PROTECT.COM --                                            'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1998-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  useage: @FILE$PROTECT [ fname[,fname...] | @filelist ]
$ !                        [(s,o,g,w)]
$ !                        [ PROTECT (D) | ADOPT | BOTH | DEFAULT | LISTONLY ]
$ !                        [ LIST ]
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ prv = F$SETPRV("BYPASS")  !Overpower any access problems!
$ !
$ V = F$EXTRACT(0,2,F$GETSYI("VERSION"))
$ IF V .EQS. "V1" THEN V = "V5"  !alias for early ALPHA AXP versions (v1.5)
$ IF V .GES. "V6" THEN V = "V6"  !now account for v7, v8, ...
$ !
$ IF F$TYPE(Util$Fac) .EQS. ""
$ THEN Util == "@site$utils:utility.com"
$      Util START PRO
$ ENDIF
$ wso = "WRITE sys$output"
$ DD  = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(DD,,,"NAME","SYNTAX_ONLY")
$ DD  = F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ !
$ Debug = F$TRNLNM("TOOLS$Debug")
$ IF Debug
$ THEN Log = "/LOG"
$      IF V .EQS. "V6" THEN wso "%''Fac'-I-''V', using [1mSET SECURITY[0m syntax"
$      IF V .EQS. "V5" THEN wso "%''Fac'-I-''V', using [1mSET FILE[0m syntax"
$ ELSE Log = ""
$ ENDIF
$ !
$ Li = ( F$EXTRACT(0,1,P4) .EQS. "L" )
$ Util CMDPARSE "''P3'" "" "PROTECT" "PROTECT |DEFAULT |BOTH    |ADOPT   |LISTONLY"
$ IF ( PRO$Cmd .EQS. "LISTONLY" )
$ THEN Li = 1
$ ENDIF
$ !
$ P2 = F$EDIT(P2,"COLLAPSE") - "(" - ")"
$ IF P2 .EQS. ""
$ THEN PM = F$ENVIRONMENT("PROTECTION")
$      IF F$EXTRACT(0,1,P1) .NES. "?"
$      THEN wso "%''Fac'-I-DEFAULT, using default protection"
$           wso "                         [1m''PM'[0m"
$      ENDIF
$ ELSE PM = P2
$      IF Debug .AND. ( F$EXTRACT(0,1,P1) .NES. "?" )
$      THEN wso "%''Fac'-I-PROT, using specified protection [1m''PM'[0m"
$      ENDIF
$ ENDIF
$ !
$L0:
$ IF P1 .EQS. "" -
    THEN READ /PROMPT="filename: " -
    /END_OF_FILE=Done sys$command P1
$ IF P1 .EQS. "" THEN GOTO L0
$ IF F$EXTRACT(0,1,P1) .EQS. "?" THEN GOTO Help
$ !
$ IF F$EXTRACT(0,1,P1) .EQS. "@" THEN GOTO IndirectSpec
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
$ THEN CALL 'V'TheProcess "''Fl'" "''PM'"
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
$MakeIndirect:
$ @site$utils:FILE$PrepList "''Files'" "" "" "" FIL$XFile /CONFIRM
$ IF F$TYPE(FIL$XFile) .EQS. "" THEN GOTO Done  !user-aborted or error
$ P1 = "@" + FIL$XFile                          !try again...
$ !
$IndirectSpec:
$ Files = P1 - "@"
$ Files = F$PARSE(Files,".lis")
$ OPEN /READ /ERROR=FNF f 'Files'
$IS0:
$ READ /END_OF_FILE=IS1 f Fl
$ Fl = F$EDIT(Fl,"COLLAPSE,UPCASE,UNCOMMENT")
$ IF Fl .EQS. "" THEN GOTO IS0                   !skip blank lines & comments
$!===============
$ CALL 'V'TheProcess "''Fl'" "''PM'"
$!===============
$ GOTO IS0
$ !
$IS1:
$ CLOSE f
$ !
$Done:
$ GOTO 'V'_Done
$V5_Done:
$ IF Li THEN DIRECTORY /WIDTH=(FILE=16,SIZE=4,OWN=16) -
              /SIZE=ALL /OWN /PROTECTION /ACL 'P1'
$V6_Done:
$ IF F$TYPE(FIL$XFile) .NES. "" THEN DELETE /SYMBOL /GLOBAL FIL$XFile
$ IF F$TYPE(Prv) .EQS. "STRING" THEN Prv = F$SETPRV(Prv)
$ Util EXIT
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
$V6TheProcess: SUBROUTINE
$ ON CONTROL_Y THEN EXIT %X2C
$ IF F$SEARCH(P1) .NES. ""
$ THEN GOTO 'PRO$Cmd'
$PROTECT:
$      SET SECURITY /CLASS=FILE /PROTECTION=('P2') 'P1' 'Log'
$      GOTO Done
$ADOPT:
$      P2 = F$FILE_ATTRIBUTES(P1,"PRO") !keep what it's got
$BOTH:
$      SET SECURITY /CLASS=FILE /DEFAULT 'P1' 'Log'
$      SET SECURITY /CLASS=FILE /PROTECTION=('P2') 'P1' 'Log'
$      GOTO Done
$DEFAULT:
$      SET SECURITY /CLASS=FILE /DEFAULT 'P1' 'Log'
$LISTONLY:
$DONE:
$      Stat = $STATUS
$      IF Li THEN SHOW SECURITY 'P1'
$      EXIT Stat
$ ELSE wso "%''Fac'-E-FNF, file ""''P1'"" not found"
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! TheProcess
$ !
$ !          ==========
$V5TheProcess: SUBROUTINE
$ ON CONTROL_Y THEN EXIT %X2C
$ IF F$SEARCH(P1) .NES. ""
$ THEN GOTO 'PRO$Cmd'
$PROTECT:
$      SET FILE /PROTECTION=('P2') 'P1' 'Log'
$      EXIT $STATUS
$ADOPT:
$      SET FILE /OWNER=PARENT 'P1' 'Log'
$      EXIT $STATUS
$BOTH:
$      SET FILE /PROTECTION=('P2') /OWNER=PARENT 'P1' 'Log'
$      EXIT $STATUS
$DEFAULT:
$      P2 = F$ENVIRONMENT("PROTECTION")
$      SET FILE /PROTECTION=('P2') /OWNER=PARENT 'P1' 'Log'
$LISTONLY:
$DONE:
$      EXIT $STATUS
$ ELSE wso "%''Fac'-E-FNF, file ""''P1'"" not found"
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! TheProcess
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE sys$input

  useage: @FILE$PROTECT [ fname[,fname...] | @filelist ]
                        [(s,o,g,w)]
                        [ PROTECT (D) | ADOPT | BOTH | DEFAULT | LISTONLY ]
                        [ LIST ]

  where:

    P1 is a single filespec ([1mfname[0m), a file-list ([1mfname,fname,...[0m), or an
      indirection to a list of filespecs, one file per line ([1m@filelist[0m).
      Wildcards are supported for both [1mfname[0m and [1mfname,fname,...[0m forms,
      but not within indirect file lists.

    P2 is an optional [1mfile protection mask[0m, e.g., (S:RWED,O:RWED,G,W:RE).
      If missing, the current process-default protection codes are used
      instead.

    P3 is one of:

       PROTECT  - (default) Apply the file protection mask to files.

       ADOPT    - Set files ownership to that of their directory.

       BOTH     - Apply both PROTECT and ADOPT.

       DEFAULT  - Apply process-default protection mask, file ownership
                  and ACLs.

       LISTONLY - Show security-listing (directory) only.

    P4 is optional LIST, which produces file security-listing (directory)
      after (and in addition to) applying the P3 option above.  Specifying
      LIST as P4 permits you to do both a P3-protection option and a listing.

$ GOTO Done
