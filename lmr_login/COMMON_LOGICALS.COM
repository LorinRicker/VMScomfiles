$ ! COMMON_LOGICALS.COM -- define common logical names
$ !
$ ! Copyright © 2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$MAIN:
$ ON ERROR THEN EXIT %X2C
$ !
$ P1 = F$EDIT( P1, "UPCASE" )
$ IF ( P1 .EQS. "HELP" ) .OR. ( P1 .EQS. "?" ) THEN GOTO Help
$ !
$ SEP = "|"
$ !
$ Debug = F$TRNLNM( "TOOLS$DEBUG" )
$ CL$newdircount == 0
$ !
$ IF ( F$TYPE( LBase ) .EQS. "" ) -
  THEN LBase = F$PARSE( "sys$login",,,"DEVICE","SYNTAX_ONLY" ) -
             + "[" + F$EDIT( F$GETJPI( "","USERNAME" ),"TRIM,UPCASE" )
$ Rooted = ".] /TRANSLATION_ATTRIBUTES=(CONCEALED,TERMINAL)"
$ LNode  = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ !
$ ! Subroutine DefCommons defines MFD (logicals and symbols)
$ !   and logicals SYS$SCRATCH and LOGS -- generally, it is
$ !   called once only per login process:
$ IF ( F$TRNLNM( "MFD", "LNM$JOB" ) .EQS. "" ) -
    .AND. ( F$TYPE( mfd ) .NES. "STRING" )     -
  THEN CALL DefCommons
$ IF ( P1 .NES. "" )  ! one or more parameters given
$ THEN i = 1
$MLoop:
$      ! Run through P1...P8:
$      IF ( i .GE. 9 ) THEN EXIT 1
$      param = F$EDIT( P'i', "UPCASE,COLLAPSE")
$      IF ( param .EQS. "" ) THEN GOTO MLend
$      arg0 = F$ELEMENT( 0, SEP, param )
$      arg1 = F$ELEMENT( 1, SEP, param )
$      arg2 = F$ELEMENT( 2, SEP, param )
$      IF ( arg1 .EQS. SEP ) THEN arg1 = ""
$      IF ( arg2 .EQS. SEP ) THEN arg2 = ""
$      CALL DefLnm "''LBase'" "''arg0'" "''arg1'" "''arg2'"
$      i = i + 1
$      GOTO MLoop
$ ENDIF
$ !
$MLend:
$ IF Debug .AND. ( CL$newdircount .GT. 0 ) -
  THEN DIRECTORY /SIZE /DATE /OWNER /PROTECTION 'LBase']*.DIR /SINCE=TODAY
$ IF F$TYPE( CL$newdircount ) THEN DELETE /SYMBOL /GLOBAL CL$newdircount
$ EXIT 1   !
$ !
$ !
$ !
$DefCommons:  SUBROUTINE
$ ON CONTROL_Y THEN GOSUB SCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ ! Just do a known, predefined group
$ CALL DefMFD
$ CALL DefLnm "''LBase'" "COM"          ""          ""
$ CALL DefLnm "''LBase'" "LIB"          ""          ""
$ CALL DefLnm "''LBase'" "LOGIN"        "LMR$LOGIN" ""
$ CALL DefLnm "''LBase'" "LOGS"         ""          ""
$ CALL DefLnm "''LBase'" "SYS$SCRATCH"  ""          ""
$ EXIT 1
$ !
$SCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! DefCommons
$ !
$DefLnm:  SUBROUTINE
$ ! Test subdirectory existence, create if needed --
$ ! then define a job-logical for that subdirectory:
$ ! P1 : Root/base user directory, e.g. "SYS$LOGIN_DEVICE:[username";
$ !      use username as base directory name if P3 is null
$ ! P2 : Subdirectory name to detect, create if missing
$ ! P3 : Logical name to create for subdirectory;
$ !      use P2 if P3 is null
$ ! P4 : Optional additional search-list elements ",dirspec[,...]";
$ !      ignored if null
$ !
$ ON CONTROL_Y THEN GOSUB DLNMCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ IF ( P3 .NES. "" )
$ THEN lnm = P3
$ ELSE lnm = P2
$ ENDIF
$ !
$ dirspec = "''P1']''P2'.DIR;1"
$ dir     = "''P1'.''P2']"
$ !
$ ! Special case (all systems) -- rename SCRATCH.DIR -> SYS$SCRATCH.DIR --
$ IF ( P2 .EQS. "SYS$SCRATCH" )
$ THEN IF ( F$SEARCH( "''P1']SCRATCH.DIR;1" ) .NES. "" )
$      THEN SET FILE /PROT=(O:RWED) SCRATCH.DIR
$           RENAME /LOG 'P1']SCRATCH.DIR 'P1']SYS$SCRATCH.*
$           SET FILE /PROT=(O:RWE) SYS$SCRATCH.DIR
$           GOTO D0
$      ENDIF
$ ENDIF
$ ! If the subdirectory does not exist, create it --
$ IF ( F$SEARCH( dirspec ) .EQS. "" )
$ THEN CREATE /DIRECTORY /OWNER=PARENT /PROTECTION=(S:RWE,O:RWE,G,W) /LOG 'dir'
$      CL$newdircount == CL$newdircount + 1
$ ENDIF
$ !
$D0:
$ DEFINE /JOB /NOLOG 'lnm' 'dir''P4'
$ !
$ EXIT 1
$ !
$DLNMCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! DefLnm
$ !
$DefMFD:  SUBROUTINE
$ ! Define both job-logical names and global symbols
$ ! for the Master File Directory (MFD) on _this_ disk:
$ SET NOON
$ DEFINE /JOB /NOLOG mfd  "[000000]"
$ DEFINE /JOB /NOLOG mfdr "[000000...]"
$ mfd  == "[000000]"
$ mfdr == "[000000...]"
$ EXIT 1
$ ENDSUBROUTINE  ! DefMFD
$ !
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

[4mCOMMON_LOGICALS.COM[0m

  This command procedure is designed to be included (edited into) your
  own personal LOGIN.COM file.  It defines "common logical names for
  your subdirectories" -- two of these by default, [1mSYS$SCRATCH [0m(as a
  distinct subdirectory, relocating this function from your "home" or
  "login" directory), and [1mLOGS[0m as a separate and distinct subdirectory
  for your batch jobs' log-files.  All logical names defined by this
  procedure are defined as [4mjob logicals[0m (/JOB).
  
  To use this command file, include a line like this into your own
  personal LOGIN.COM file at an appropriate place (usually in the
  INTERACTIVE stanza or section):
  
  [1m$ @COMMON_LOGICALS ["subdir[|lognam[|,searchlist]...]"][0m

  Be sure to specify the directory path where you've stored this command
  file as part of the above @-invocation (see examples below):
  
  Like all DCL command files, this procedure can accept up to eight (8)
  parameters -- Need more?  Call COMMON_LOGICALS.COM two (or more) times
  from your LOGIN.COM file, each time with a different set of parameters.

  [4mExamples[0m:
  
  1. This simple call creates logical names SYS$SCRATCH and LOGS,
     and will create appropriate subdirectories as needed if those
     don't yet exist:
     
     $ @SYS$LOGIN_DEV:[LRICKER.COM]COMMON_LOGICALS
  
  2. To add additional subdirectory logical names of your own, each
     of which will have a subdirectory created if it doesn't already
     exist, and each subdirectory will be named identically to the
     logical name itself:
     
     $ @SYS$LOGIN_DEV:[LRICKER.COM]COMMON_LOGICALS [1mCOM LIB[0m
     
     creates logical names:
       [1mCOM[0m  -->  SYS$LOGIN_DEV:[LRICKER[1m.COM[0m]
       [1mLIB[0m  -->  SYS$LOGIN_DEV:[LRICKER[1m.LIB[0m]
  
  3. To add a logical name which should be named differently from
     its subdirectory, specify the two names as "subdir|logname"
     -- separate the subdirectory name with a "pipe" character "|"
     from the alternate/different logical name:

     $ @SYS$LOGIN_DEV:[LRICKER.COM]COMMON_LOGICALS -
         COM LIB [1m"LOGIN|my$login"[0m

  4. If one of the logicals should actually be a search-list,
     specify it as "subdir|logname|,searchlist[,searchlist]"
     -- separate the three elements with "pipe" characters "|"
     and the third element must begin with a comma "," and can
     have as many search path elements as needed, as a comma-
     separated list:

     $ @SYS$LOGIN_DEV:[LRICKER.COM]COMMON_LOGICALS -
         [1m"COM||[4m,site$utils,common:[tools]"[0m "LIB" "LOGIN|my$login"

