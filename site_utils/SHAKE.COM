$ ! SHAKE.COM --                                                   'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1990-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  use:  @SHAKE dir1_spec[,dir2_spec...] [-options] [exclusions_list]
$ !
$ ! where: P1 - directory-tree specification(s) to process,
$ !             e.g., [LT_DEV...] or [MC.REPORTS...]
$ !                or [MC...],[PPS...],[SCS...]
$ !                or [MC.JAIL],[MC.COMMISSARY],[MC.SUPERVISION] ...etc.
$ !        P2 - SHAKE and/or MAKE options.
$ !             SHAKE adds 4 options to the standard MAKE options:
$ !               -B: submit to Batch
$ !               -C: Confirmation of each .MAK file before including
$ !               -E: Edit the output command-file, don't execute it
$ !               -$: include $*.MAK files only (those starting with "$")
$ !             SHAKE options are stripped off and processed herein,
$ !             and any remaining MAKE options are passed on.
$ !        P3 - list of *.MAK filenames to exclude;
$ !             excludes VALIDATIONS.MAK and REPORTS.MAK by default
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ IF (P1 .EQS. "?") .OR. (P2 .EQS. "?") THEN GOTO Help
$ !
$ SUBMIT      = "SUBMIT"
$ wso         = "WRITE sys$output"
$ Fac         = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ S$Verify    = F$TRNLNM("TOOLS$DEBUG")
$ S$ComFile   = "SYS$SCRATCH:" + Fac + "_WORK.COM"
$ S$LogFile   = "SYS$SCRATCH:" + Fac + "_WORK.LOG"
$ S$Confirm   = "Yes"
$ S$All       = 0
$ S$FCount    = 0
$ S$ExecuteIt = "Y"
$ IF S$Verify
$ THEN S$Del = "/DELETE"
$ ELSE S$Del = ""
$ ENDIF
$ !
$ IF F$LOCATE("-",P1) .NE. 0 THEN GOTO Q0
$ T1 = P1
$ P1 = P2
$ P2 = T1
$Q0:
$ S$B = 0   !submit to Batch
$ S$C = 0   !Confirmation of each .MAK file before including
$ S$E = 0   !Edit the script-file, don't execute it
$ S$$ = 0   !include $*.MAK files only (those starting with "$")
$ IF F$LOCATE("-",P2) .NE. 0 THEN GOTO Q2
$Q1:
$ IF F$LOCATE("B",P2) .LT. F$LENGTH(P2)
$ THEN S$B = 1
$      P2  = P2 - "B"
$ ENDIF
$ IF F$LOCATE("C",P2) .LT. F$LENGTH(P2)
$ THEN S$C = 1
$      P2  = P2 - "C"
$ ENDIF
$ IF F$LOCATE("E",P2) .LT. F$LENGTH(P2)
$ THEN S$E = 1
$      P2  = P2 - "E"
$ ENDIF
$ IF F$LOCATE("$",P2) .LT. F$LENGTH(P2)
$ THEN S$$ = 1
$      P2  = P2 - "$"
$ ENDIF
$Q2:
$   !remaining switches, if any, are given to MAKE:
$ IF F$LENGTH(P2) .GE. 2
$ THEN M$Switches = " " + P2
$ ELSE M$Switches = ""
$ ENDIF
$ !
$ Here = F$ENVIRONMENT("DEFAULT")
$ DDir = F$PARSE(Here,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(Here,,,"DIRECTORY","SYNTAX_ONLY")
$ IF P1 .EQS. ""
$ THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="Directory tree < ''DDir' >: "
$      IF P1 .EQS. "" THEN P1 = DDir
$ ENDIF
$ !
$ ! Exclusion-list default-check;
$ !  VALIDATIONS.MAK and REPORTS.MAK are E&R "standard" Make #-inclusion files:
$ IF P3 .EQS. ""
$ THEN P3 = ",VALIDATIONS,REPORTS,"
$ ELSE P3 = "," + P3 + ","
$ ENDIF
$ P3L = F$LENGTH(P3)
$ !
$ OPEN /WRITE /ERROR=OpenErr S$CF 'S$ComFile'
$ wf = "WRITE S$CF"
$ PrevD = ""
$ Year  = F$CVTIME("","ABSOLUTE","YEAR")
$ wf "$ ! ''S$ComFile'                                      'F$VERIFY(0)'"
$ wf "$ !"
$ wf "$ !  This program is the confidential and proprietary product of"
$ wf "$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or"
$ wf "$ !  transfer of this program is strictly prohibited."
$ wf "$ !"
$ wf "$ !  Copyright © 1990-''Year' by Evans & Ricker, Inc.  All rights reserved."
$ wf "$ !"
$ wf "$ ON CONTROL THEN GOSUB Ctrl_Y"
$ wf "$ ON ERROR THEN GOTO Done"
$ !
$ i = 0
$OuterLoop:
$ CDir = F$ELEMENT(i,",",P1)
$ IF CDir .EQS. "," THEN GOTO DoIt
$ !
$ Dir = F$PARSE(CDir,,,"DIRECTORY","SYNTAX_ONLY")
$ Dev = F$PARSE(CDir,,,"DEVICE","SYNTAX_ONLY")
$ Nam = F$PARSE(CDir,,,"NAME","SYNTAX_ONLY")
$ Typ = F$PARSE(CDir,,,"TYPE","SYNTAX_ONLY")
$ IF Nam .EQS. "" THEN Nam = "*"
$ IF Typ .EQS. "." THEN Typ = ".mak"
$ IF S$$
$ THEN S$MakeFiles = Dev + Dir + "$" + Nam + Typ  !"$*.MAK" forms only!
$ ELSE S$MakeFiles = Dev + Dir + Nam + Typ        !Exclude "$*.MAK" forms...
$ ENDIF
$ !
$InnerLoop:
$ F = F$SEARCH(S$MakeFiles,0)
$ IF F .EQS. ""    !Last file (in this directory)?
$ THEN i = i + 1
$      GOTO OuterLoop
$ ENDIF
$ FN = F$PARSE(F,,,"NAME","SYNTAX_ONLY")
$ FC = F$EXTRACT(0,1,FN)
$ FV = F$ELEMENT(0,";",F)    !strip ;N version
$ !
$ IF .NOT. S$$                                 !Unless "-$" flag,
$ THEN IF FC .EQS. "$" THEN GOTO InnerLoop     ! skip $RELEASE.MAK, etc.
$ ELSE IF FC .NES. "$" THEN GOTO InnerLoop     ! skip any/all but "$*.mak"
$ ENDIF
$ !
$ ! Check against exclusion-list:
$ IF P3L .GT. 0 -
  THEN IF F$LOCATE(",''FN',",P3) .LT. P3L THEN GOTO InnerLoop  !Skip exclusions
$ !
$ IF S$C .AND. ( .NOT. S$All )
$ THEN READ sys$command Answer /END_OF_FILE=DoItQ /PROMPT="Make ''FV' ([1mY[0m/n/a/q)? "
$      Answer = F$EDIT(Answer,"COMPRESS,TRIM,UPCASE")
$      S$Confirm = F$PARSE(Answer,"Yes",,"NAME","SYNTAX_ONLY")
$      IF ( Answer .EQS. "*" ) .OR. ( F$EXTRACT(0,1,Answer) .EQS. "A" )  !All?
$      THEN S$All = 1           !Stop asking
$           S$Confirm = "Yes"   ! and just confirm the rest of them...
$      ENDIF
$      IF F$EXTRACT(0,1,Answer) .EQS. "Q"  !Quit?  Force Confirmation back on
$      THEN GOTO DoItQ                     ! and jump to processing...
$      ENDIF
$ ENDIF
$ !
$ IF S$Confirm
$ THEN DD = F$PARSE(F,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(F,,,"DIRECTORY","SYNTAX_ONLY")
$      IF DD .NES. PrevD
$      THEN wf "$ !"
$           wf "$ CALL SetContext ''DD'"
$           PrevD = DD
$      ENDIF
$      wf "$ make ''FN'''M$Switches'"
$      S$FCount = S$FCount + 1
$ ENDIF
$ GOTO InnerLoop
$ !
$DoItQ:     !Quit or Ctrl/Z from file-by-file prompt...
$ S$C = 1   ! if user Quit, then force Confirmation back on
$DoIt:
$ wf "$ !"
$ wf "$Done:"
$ wf "$ SET DEFAULT ''Here'   !return to original default directory"
$ wf "$ EXIT"
$ wf "$ !"
$ wf "$SetContext:  SUBROUTINE"
$ wf "$ SET NOON"
$ wf "$ SET DEFAULT 'P1'"
$ wf "$ WRITE sys$output F$FAO(""!^!50*= [1m!AS[0m ===="",P1)"
$ wf "$ WRITE sys$output """""
$ wf "$ EXIT 1"
$ wf "$ ENDSUBROUTINE  ! SetContext"
$ wf "$ !"
$ wf "$Ctrl_Y:"
$ wf "$ RETURN %X2C"
$ !
$ IF F$TRNLNM("S$CF","lnm$process") .NES. "" THEN CLOSE S$CF
$ !
$ IF S$FCount .EQ. 0
$ THEN IF S$$
$      THEN S$ = "$"
$      ELSE S$ = ""
$      ENDIF
$      wso "%''Fac'-E-NO_MAKE_FILES, no ''S$'*.MAK files were found to include"
$      GOTO Done
$ ENDIF
$ !
$ IF S$E
$ THEN DEFINE /USER_MODE /NOLOG sys$input sys$command
$      KED 'S$ComFile'
$      GOTO Done
$ ENDIF
$ !
$ wso ""
$ wso "%''Fac'-I-PROCESSING, MAKE step:"
$ IF S$B
$ THEN wso "%''Fac'-I-BATCH, submitting ''S$ComFile' to SYS$BATCH"
$      wso ""
$      SUBMIT 'S$ComFile' 'S$Del' /LOG='S$LogFile' /NOPRINT /KEEP
$ ELSE IF S$C
$      THEN READ sys$command Answer /END_OF_FILE=Done -
              /PROMPT="Review ''S$ComFile' before executing ([1mY[0m/n)? "
$           Answer = F$PARSE(Answer,"Yes",,"NAME","SYNTAX_ONLY")
$           IF Answer
$           THEN TYPE /PAGE 'S$ComFile'
$                wso "==================="
$                wso ""
$           ENDIF
$           READ sys$command S$ExecuteIt /END_OF_FILE=Done -
              /PROMPT="Execute ''S$ComFile' (y/[1mN[0m)? "
$           Answer = F$PARSE(S$ExecuteIt,"No",,"NAME","SYNTAX_ONLY")
$           IF S$ExecuteIt THEN @'S$ComFile'
$      ELSE IF .NOT. S$Verify
$           THEN wso "%''Fac'-I-INTERACTIVE, executing @''S$ComFile'"
$                wso ""
$                @'S$ComFile'
$           ENDIF
$      ENDIF
$      IF S$ExecuteIt .AND. ( .NOT. S$Verify ) THEN DELETE /NOLOG 'S$ComFile';*
$ ENDIF
$ !
$Done:
$ IF F$TRNLNM("S$CF","lnm$process") .NES. "" THEN CLOSE S$CF
$ EXIT
$ !
$OpenErr:
$ wso "%''Fac'-E-OPENERR, error opening ''S$ComFile' for output"
$ GOTO Done
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  SHAKE is a complimentary command-file to MAKE (and BAKE); it scans one or
  more directories (or directory-trees) for *.MAK files, creating an output
  command-file, [1mSYS$SCRATCH:SHAKE_WORK.COM[0m, which invokes each *.MAK file it
  finds.  This permits you to execute all of the Make Scripts for a particular
  project (directory-tree) in one convenient operation.

  use:  [1m@SHAKE dir1_spec[,dir2_spec...] [-options] [exclusions_list][0m

 where:
 
 [1mdir1[,dir2...][0m is a directory (or a directory-tree) specification, or a
   comma-separated list of directory-trees, to process.  SHAKE will scan
   the directory(ies) to find all *.MAK files, and will include each Make
   Script in its output file, SYS$SCRATCH:SHAKE_WORK.COM.
   
   By default, only *.MAK files which do not start with a "$" are included
   in the SHAKE_WORK.COM command file; this is based on the convention that
   "special" Make Script files are named beginning with a "$", and should
   not normally be included in a "make the entire project" operation; e.g.,
   scripts such as $RELEASE.MAK and/or $COPY_VAX.COM should be omitted from
   a complete product/project build.
   
   In the event that Make Scripts of the form "$*.MAK" [1mare[0m to be processed
   in a SHAKE, the command option [1m-$[0m is provided (see below).

   Directory and directory-tree examples:
   
       [LT_DEV.JAIL]       -- Process *.MAK scripts in this subdirectory only
       [MC.JAIL],[MC.IA]   -- Scripts in two distinct subdirectories only
       [MC...]             -- Scripts in [MC] and all of its subdirectories
       [PPS...],[SCS...]   -- Scripts in two entire project trees


 [1m-options[0m are SHAKE and/or MAKE options; these option-letters can be freely
   intermixed.  SHAKE adds three options, [1m-BC$[0m, to the standard MAKE options:

          [1m-B[0m: submit to Batch; SYS$SCRATCH:SHAKE_WORK.COM is submitted to
              the default batch queue (SYS$BATCH) for execution.  By default,
              the output command-file is executed directly (interactively)
              unless you specifically direct it to batch execution.

          [1m-C[0m: forces Confirmation (prompting) of each .MAK file before it is
              included in the output command-file.  The prompt is:
              
                 Make [1mmake_filespec[0m ([1mY[0m/n/a/q)?
              
              Responses (which may be abbreviated to the first letter) are:
              
                 [1mY[0mes (the default) to include this [1mmake_filespec[0m in the
                      output command-file.
                 [1mN[0mo to skip this [1mmake_filespec[0m.
                 [1mQ[0muit to skip this (the current) [1mmake_filespec[0m and stop the
                      scanning/prompting for more *.MAK files.
                 [1mA[0mll to stop prompting and include all subsequent *.MAK files
                      in the output command-file.  The wildcard character [1m*[0m
                      also means "all".

              When all *.MAK file-prompting, and the output command-file, is
              complete, you are prompted:
              
                 %SHAKE-I-PROCESSING, MAKE step:
                 Review SYS$SCRATCH:SHAKE_WORK.COM before executing ([1mY[0m/n)?
              
              Respond with [1mY[0mes (the default) to have the output command-file
              printed on your screen (with TYPE /PAGE) for your review; enter
              [1mN[0mo to skip this review.
              
              You are next prompted to:
              
                 Execute SYS$SCRATCH:SHAKE_WORK.COM (y/[1mN[0m)?

              Respond with [1mY[0mes to execute the output command-file immediately
              (or have it submitted to the batch queue if the -B option was
              specified); enter [1mN[0mo (the default) to skip immediate execution 
              of the command-file, saving it for later use.

              If you respond to [1many[0m prompt with a [1mCtrl/Z[0m, SHAKE quits (exits)
              immediately without any further processing.

          [1m-E[0m: Invokes the KED editor, allowing you to edit and review the
              output command-file.  In this case, the command-file is not
              executed; you'll have to invoke it manually after you finish
              your edit/review, or save it for later use.
              
          [1m-$[0m: A "toggle option" which forces SHAKE to include Make Script
              filenames which begin with a "[1m$[0m" (of the form [1m$*.MAK[0m), rather
              than excluding them, which is the default behavior.

              This option allows you to control SHAKE behavior based on the
              conventions that:  a) "typical" Make Scripts are named starting
              with letters A-Z or digits 0-9;  b) "special" Make Scripts are
              named starting with the "$" character.
              
              These conventions permit all "typical" Scripts, the ones which
              normally build application components during routine development
              cycles, to be "typically named" and therefore SHAKE processed as
              a potentially single group --- "special" Scripts, such as
              $RELEASE.MAK (etc.), would be excluded from routine SHAKE-ing.
              
              For rare ocassions when special $*.MAK Scripts should be SHAKEd
              as a group, the -$ option is available.

   All SHAKE options are stripped off and processed herein, and any remaining
   MAKE options are passed on to the Make command-file.

   For additional help on the Make utility and specific Make options, type
   [1mHELP MAKE[0m or [1mMAKE -H[0m at a DCL $-prompt.


 [1mexclusions_list[0m is a list of *.MAK filenames to exclude from scanning and
   processing.
   
       Note:  The special Make script files [1mVALIDATIONS.MAK[0m and [1mREPORTS.MAK[0m
       are excluded by default; these are include-script files which are
       frequent (semi-standard) parts of project desktops; as such, these
       should normally not be added to a Make script.

   Exclusion examples:
   
       TEMP                -- Excludes any TEMP.MAK files encountered.
       VALIDATIONS,TEMP    -- Excludes both VALIDATIONS.MAK and TEMP.MAK files.


$ GOTO Done
