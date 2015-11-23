$ ! PRINT_DCPS.COM -- DECprint Supervisor PRINT command aide       'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 1994-2002 Evans & Ricker, Inc.  All rights reserved.
$ !
$ !    Use: @PRINT_DCPS File [parameter [parameter [...] ] ]
$ !
$ !    P1:     File to print (required)
$ !    P2..P8: Optional parameters (see Help text below)
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ IF P1 .EQS. "?" THEN GOTO Help
$ !
$ PRINT = "PRINT"
$ ! Find a suitable DECprint Supervisor (DCPS) print que:
$ DCPS_Que == F$TRNLNM("DCPS$Que","lnm$job")
$ IF DCPS_Que .EQS. ""
$ THEN CALL Find_DCPS_Que
$      IF DCPS_Que .NES. ""
$      THEN READ sys$command Answer /END_OF_FILE=Done -
                /PROMPT="DCPS print que [''DCPS_Que']: "
$           DCPS_Que == F$PARSE(Answer,DCPS_Que,,"NAME","SYNTAX_ONLY")
$           IF DCPS_Que .NES. ""
$           THEN DEFINE /JOB /NOLOG DCPS$Que 'DCPS_Que'
$           ENDIF
$      ELSE WRITE sys$output "%PRINT_DCPS-E-NO_QUE, no DECprint Supervisor queue found"
$           GOTO Done
$      ENDIF
$ ENDIF
$ !
$ IF P1 .EQS. "" THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="File to print: "
$ !
$ Qual = ""
$ i = 2
$PL:
$ IF i .GT. 8 THEN GOTO PN          !For each P2..P8:
$ IF F$EXTRACT(0,1,P'i') .EQS. "/"  !regular PRINT command qualifier?
$ THEN Qual = Qual + P'i'           !yes, save it...
$      P'i' = ""                    !  and exclude it from parsing below
$ ENDIF
$ i = i + 1
$ GOTO PL
$PN:
$ P2 = " " + P2 + " " + P3 + " " + P4 + " " + P5 + " " + P6 + " " + P7 + " " + P8
$ P2 = F$EDIT(P2,"COMPRESS,UPCASE")
$ P2L = F$LENGTH(P2)
$ !
$ Verbose = ( F$LOCATE(" V",P2) .LT. P2L )
$ !
$ Ori = "PAGE_ORIENTATION="             ! Orientation
$ IF F$LOCATE(" L",P2) .LT. P2L
$ THEN Ori = Ori + "LANDSCAPE"
$ ELSE Ori = Ori + "PORTRAIT"
$ ENDIF
$ !
$ Nup = F$LOCATE(" #",P2)               ! Number-Up
$ IF Nup .LT. P2L
$ THEN Nup = F$EDIT(F$EXTRACT(Nup+2,P2L-Nup-2,P2),"TRIM")
$      Nup = ",NUMBER_UP=" + F$ELEMENT(0," ",Nup)
$ ELSE Nup = ""
$ ENDIF
$ !
$ ShC = F$LOCATE(" *",P2)               ! Sheet-count
$ IF ShC .LT. P2L
$ THEN ShC = F$EDIT(F$EXTRACT(ShC+2,P2L-ShC-2,P2),"TRIM")
$      ShC = ",SHEET_COUNT=" + F$ELEMENT(0," ",ShC)
$ ELSE ShC = ""
$ ENDIF
$ !
$ Sid = F$LOCATE(" &",P2)               ! Sides
$ Tum = ""
$ IF Sid .LT. P2L
$ THEN Sid = F$EDIT(F$EXTRACT(Sid+2,P2L-Sid-2,P2),"TRIM")
$      Tum = F$EXTRACT(0,1,F$ELEMENT(0," ",Sid))
$      IF Tum .EQS. "T"
$      THEN Tum = "TUMBLE"
$      ELSE IF Tum .GES. "2"
$           THEN Tum = "2"
$           ELSE Tum = "1"
$           ENDIF
$      ENDIF
$      Sid = ",SIDES=" + Tum
$ ELSE Sid = ""
$ ENDIF
$ !
$ PgL = F$LOCATE(" (",P2)               ! Page limits
$ IF PgL .LT. P2L
$ THEN PgL = F$EDIT(F$EXTRACT(PgL+1,P2L-PgL-1,P2),"TRIM")
$      PgL = ",PAGE_LIMIT=""" + F$ELEMENT(0," ",PgL) + """"   ! ="(,)"
$ ELSE PgL = ""
$ ENDIF
$ !
$ Hol = F$LOCATE(" 3H",P2)              ! 3-hole punch margin
$ IF Hol .LT. P2L
$ THEN Hol = ",""LAYUP="
$      IF (Tum .EQS. "TUMBLE") .OR. (Tum .EQS. "2")
$      THEN Hol = Hol + "LPS$DOUBLEHOLES"""       !no borders, alternate
$      ELSE IF (Tum .EQS. "1")
$           THEN Hol = Hol + "LPS$SINGLEHOLES"""  !no borders, no alternate
$           ELSE IF (Nup .NES. "")
$                THEN Hol = Hol + "LPS$NUP"""     !permits borders
$                ELSE Hol = Hol + "LPS$HOLES"""   !no borders
$                ENDIF
$           ENDIF
$      ENDIF
$ ELSE Hol = ""
$ ENDIF
$ !
$ Lit = F$LOCATE(" [",P2)               ! Literal parameters
$ IF Lit .LT. P2L
$ THEN Lit = F$EDIT(F$EXTRACT(Lit+1,P2L-Lit-1,P2),"TRIM")
$      Lit = ",""" + F$ELEMENT(0," ",Lit) + """" - "[" - "]"
$ ELSE Lit = ""
$ ENDIF
$ !
$ ! The payoff:
$ IF Verbose
$ THEN WRITE sys$output "$ PRINT /QUE=''DCPS_Que' ''P1' -"
$      WRITE sys$output "    /PARAMETERS=(",Ori,PgL,Nup,ShC,Sid,Hol,Lit,")"
$ ENDIF
$ PRINT /QUE='DCPS_Que' 'P1' 'Qual' -
    /PARA=('Ori''PgL''Nup''ShC''Sid''Hol''Lit')
$ !
$Done:
$ IF F$TYPE(DCPS_Que) .NES. "" THEN DELETE /SYMBOL /GLOBAL DCPS_Que
$ EXIT
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  This command file makes it simple to use any PostScript printer controlled
  by the [4mDECprint Supervisor[0m (DCPS), including the enhanced PRINT command's
  /PARAMETER=(...) qualifier.

       Use: [1m@PRINT_DCPS File [Parameter [Parameter [...] ] ][0m

       where:  [1mFile[0m is the file to print.

         [1mParameter[0m is a [4mspace-separated list[0m of any of the following:

            [1mP[0mORTRAIT (default) or [1mL[0mANDSCAPE for [4mpage orientation[0m.
            Either word can be abbreviated.

            [1m#[0mn for [4mnumber-up[0m (multiple pages per sheet).
            This is a pound-sign followed by an integer.

            [1m*[0mn for [4msheet-count[0m (multiple copies of a sheet).
            This is an asterisk followed by an integer.

            [1m(m,n)[0m for [4mpage limits[0m (page-range to print).
            This is a pair of integers enclosed in parentheses.

            [1m&[0mn for [4msingle/double-sided[0m (including tumble), if
            supported by the printer.
            This is an ampersand followed by an integer:
               [1m&1[0m for single-sided (default),
               [1m&2[0m for double-sided,
               [1m&T[0m for tumble-double-sided.

            [1m3H[0mOLE for a 5/6-inch (60 pt.) 3-hole punch margin.
            This auto-selects the correct layup module based on
            the single/double-sided option.

            [1m[parameter,...][0m for one or more literal values for the
            /PARAMETER qualifier of the PRINT command.  Use this if
            none of the other command file options provide access to
            a value that you need.  If you use more than one value,
            separate them with commas "," and do not embed spaces.

            [1m/QUALIFIER[0m for any other regular PRINT command qualifiers
            (excluding the /PARAMETERS qualifier), including /DELETE,
            /CONFIRM, /COPIES, /JOB_COUNT, /SINCE, etc.

            [1mV[0mERBOSE displays the PRINT command to be used.

  The first time you use this command file, you will be prompted to confirm
  the DCPS print que on your system.  Alternatively, you can assign the job-
  logical name DCPS$QUE to the DCPS printer you want to use:

      [1m$ DEFINE /JOB DCPS$QUE Que_Name_of_Printer[0m


  Examples: [1m$ @PRINT_DCPS foobar.lis LAND (3,6) #4 3H[0m
            prints pages 3 thru 6 of the file in landscape mode,
            all four pages on a single sheet in 4-up mode, with
            a 3-hole punch margin.

            [1m$ @PRINT_DCPS foobar.ps &2 3H [DATA=POST][0m
            prints the file double-sided with alternating 3-hole
            punch margins, and guarantees that the file will be
            translated as PostScript.

$ !
$ EXIT
$ !
$ !
$Find_DCPS_Que:  SUBROUTINE
$ ! P1: verbose flag (boolean)
$ DCPS_Que == ""
$ Q = F$GETQUI("CANCEL_OPERATION")  !reset...
$L0:
$ Q = F$GETQUI( "DISPLAY_QUEUE", "QUEUE_NAME", "*", "WILDCARD,SYMBIONT" )
$ IF Q .NES. ""
$ THEN P = F$GETQUI( "DISPLAY_QUEUE", "PROCESSOR", "*", "WILDCARD,FREEZE_CONTEXT" )
$      IF P1 THEN WRITE sys$output "Que: ''Q'   Symbiont: ''P'"
$      IF F$LOCATE("CPS$SMB",P) .LT. F$LENGTH(P) !either "DCPS$SMB" or "CPS$SMB"
$      THEN DCPS_Que == Q  !success, found the right symbiont processor
$           EXIT 1
$      ELSE GOTO L0
$      ENDIF
$ ELSE EXIT 1
$ ENDIF
$ GOTO L0
$ ENDSUBROUTINE
$ !
$Ctrl_Y:
$ RETURN %x2C
