$ ! DELETE_QUEUED_JOBS.COM --                                      'F$VERIFY(0)'
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
$ !  useage:
$ !    $ @DELETE_QUEUED_JOBS   HELP | ?
$ !                          | CREATE listfile [ quename ]
$ !                          | NOCONFIRM listfile jobname1 [ jobname2 ]...
$ !                          | CONFIRM   listfile jobname1 [ jobname2 ]...
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ Debug = F$TRNLNM("TOOLS$Debug")     !generic Tools debug flag
$ SPC   = " "
$ WILD  = "*"
$ wso   = "WRITE sys$output"
$ Fac   = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ !
$ QWord     = "queue"
$ QLabel    = "Batch,Printer,Server,"
$ QLabelLen = F$LENGTH( QLabel )
$ GenQLabel = "Generic"
$ !
$ delcount = 0
$ !
$ P2def = F$PARSE( F$TRNLNM( "X", "LNM$PROCESS" ), "SYS$SCRATCH:.LIS", "DELJOBS", , "SYNTAX_ONLY" )
$ !
$ P1 = F$EDIT( P1, "UPCASE,TRIM" )
$ IF ( P1 .EQS. "HELP" ) .OR. ( P1 .EQS. "?" ) THEN GOTO Help
$ !
$ IF ( P2 .EQS.  "" )
$ THEN READ sys$command listfile /PROMPT="Job listing file [''P2def']: " -
         /END_OF_FILE=Done
$      listfile = F$PARSE( listfile, P2def )
$ ELSE listfile = P2
$ ENDIF
$ !
$ Create = ( F$EXTRACT( 0, 4, P1 ) .EQS. "CREA" )
$ IF ( Create )
$ THEN IF ( P3 .EQS. "" )
$      THEN READ sys$command Qname /PROMPT="Create listing file for Queue [SYS$PRINT]: " -
              /END_OF_FILE=Done
$           Qname = F$PARSE( Qname, "SYS$PRINT", , "NAME", "SYNTAX_ONLY" )
$      ELSE Qname = P3
$      ENDIF
$      SHOW QUEUE /OUTPUT='listfile' /ALL 'Qname'
$      TYPE /PAGE 'listfile'
$      GOTO Done
$ ENDIF
$ !
$ Confirm = ( F$EXTRACT( 0, 4, P1 ) .EQS. "CONF" )  ! NOCONFIRM is default
$ !
$ i = 3          ! Loop thru parameters P2 .. P8, terminate on first ""
$OutLoop:
$ IF ( i .GT. 8 ) THEN GOTO Done
$ TargetJob = F$EDIT( P'i', "TRIM,UPCASE" )
$ IF ( TargetJob .EQS. "" ) THEN GOTO Done
$ !
$ OPEN /READ lf 'listfile' /ERROR=Done
$ wso ""  ! ...just some visible spacing
$ !
$ !    Queue-job listing format will either be like (one-line format):
$ !           Entry  Jobname         Username     Blocks  Status
$ !           -----  -------         --------     ------  ------
$ !              22  TESTING         LRICKER           5  Pending
$ !
$ !    or like (two-line format):
$ !           Entry  Jobname         Username     Blocks  Status
$ !           -----  -------         --------     ------  ------
$ !               2  MAINTAIN_T4$DATA
$ !                                  WILLIAMS          2  Pending
$ !
$ !    Always filter out header and top-of-queue lines;
$ !    more work to do if the first line of data has only two elements,
$ !    which means that it's been formatted onto two-lines...
$InLoop:
$      READ lf Rec1 /END_OF_FILE=OLcont
$      Rec1 = F$EDIT( Rec1, "TRIM,COMPRESS,UPCASE" )
$      IF ( Rec1 .EQS. "" ) THEN GOTO InLoop  ! empty data line
$      R0  = F$ELEMENT( 0, SPC, Rec1 )  ! Entry
$      R1  = F$ELEMENT( 1, SPC, Rec1 )  ! Jobname
$      R2  = F$ELEMENT( 2, SPC, Rec1 )  ! Username
$      R4  = F$ELEMENT( 4, SPC, Rec1 )  ! Status
$ !! wso ">>> Rec1: ''Rec1' "
$      IF ( R0 .EQS. GenQLabel ) .AND. ( R2 .EQS. QWord ) THEN GOTO InLoop
$      IF ( F$LOCATE( ",''R0',", QLabel ) .LT. QLabelLen ) -
          .AND. ( R1 .EQS. QWord ) THEN GOTO InLoop
$      IF ( R0 .EQS. "Entry" ) .AND. ( R1 .EQS. "Jobname" ) THEN GOTO InLoop
$      IF ( R0 .EQS. "-----" ) .AND. ( R1 .EQS. "-------" ) THEN GOTO InLoop
$      IF ( R2 .EQS. SPC ) .OR. ( R2 .EQS. "" )  ! it's a two-line format:
$      THEN READ lf Rec2 /END_OF_LINE=OLcont     ! read next line, parse it too...
$           Rec2 = F$EDIT( Rec2, "TRIM,COMPRESS,UPCASE" )
$           R2   = F$ELEMENT( 0, SPC, Rec2 )  ! Username
$           R4   = F$ELEMENT( 2, SPC, Rec2 )  ! Status
$ !! wso ">>> Rec2: ''Rec2' "
$      ENDIF
$      IF ( R1 .EQS. TargetJob ) .OR. ( P'i' .EQS. WILD )
$      THEN IF ( Confirm )
$           THEN R4 = F$EDIT( R4, "lowercase" )
$                READ sys$command answer /PROMPT="Delete [4m''R4' entry ''R0'[0m user:''R2' job:''R1' [Y/n]? " -
                   /END_OF_FILE=Done
$                DoIt = F$PARSE( answer, "Yes", , "NAME", "SYNTAX_ONLY" )
$           ELSE DoIt = "TRUE"
$           ENDIF
$           IF ( DoIt )
$           THEN delcount = delcount + 1
$                IF ( Debug )
$                THEN wso F$FAO( "%!AS-I-ECHO, $ DELETE /ENTRY=!AS", Fac, R0 )
$                ELSE DELETE /ENTRY='R0'
$                ENDIF
$           ENDIF
$      ENDIF
$      GOTO InLoop
$OLcont:
$ CLOSE /NOLOG lf
$ i = i + 1
$ GOTO OutLoop
$ !
$Done:
$ CLOSE /NOLOG lf
$ IF ( delcount .GT. 0 )
$ THEN wso F$FAO( "%!AS-S-DELCOUNT, deleted !SL job!%S", Fac, delcount )
$ ELSE wso F$FAO( "%!AS-I-DELNONE, no jobs deleted", Fac )
$ ENDIF
$ EXIT 1    ! 'F$VERIFY(0)'
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  Deletes pending jobs by name from a printer or batch queue.

  usage:
    $ [1m@DELETE_QUEUED_JOBS[0m [1mHELP[0m | [1m?[0m
                        | [1mCREATE[0m [1mlistfile[0m [ [1mquename[0m ]
                        | [1mNOCONFIRM[0m [1mlistfile[0m [1mjobname1[0m [ [1mjobname2[0m ]...
                        | [1mCONFIRM[0m   [1mlistfile[0m [1mjobname1[0m [ [1mjobname2[0m ]...

  where:

    [1mCREATE[0m  Generates a listing file of pending jobs for a particular queue.
            This listing file can then be used as the driver-data for the
            actual queued job deletions, either in the current run of this
            command file or in a subsequent invocation.

   [1mNOCONFIRM[0m  Delete all queued jobs which match any specified jobname without
            asking for confirmation.

   [1mCONFIRM[0m  Confirm each matching job name before deleting that job.

   [1mlistfile[0m Use the named listing file as driver-data for the queued job
            deletions.

   [1mjobname[0m  Name of at least one print or batch job to delete (there may be
            multiple instances of the same job name in any particular queue).
            This parameter is [4mrequired[0m.
            If more than one job name is to be specified, separate the job names
            by spaces, up to a limit of six (6) job names.
            If any job name is the wildcard character "[1m*[0m", then all jobs will
            be matched and potentially deleted.  This works best if the wildcard
            character is the first and only job name.

   [1mHELP[0m     Display this help text.

$ EXIT 1    ! 'F$VERIFY(0)'
$ !
