$ ! KERMIT.COM --                                                  'F$VERIFY(0)'
$ !
$ !  P1 : LOCAL (D) | SERVER
$ !  P2 : terminal port for remote connections (dial$device)
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ Kd = F$ENVIRONMENT("PROCEDURE")
$ Kd = F$PARSE(Kd,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(Kd,,,"DIRECTORY","SYNTAX_ONLY")
$ !
$ IF F$TRNLNM("ckermit_ini") .EQS. "" THEN DEFINE /JOB /NOLOG ckermit_ini com
$ LTA = ""
$ IF .NOT. F$GETDVI("Dial$Device","EXISTS") -
  .AND. ( F$TRNLNM("ker$mode") .NES. "SERVER" ) -
  .AND. ( P1 .NES. "SERVER" )
$ THEN LTA  = "LTA7777:"
$      TS   = "LAT_08002BB158C0"
$      Port = "PORT_2"
$      @com:Create_ModemPort Dial$Device "" "''LTA'" "''TS'" "''Port'"
$ ENDIF
$ !
$ dd = F$TRNLNM("dial$device") - ":"
$ IF dd .EQS. "" THEN dd = F$TRNLNM("tt") - ":"
$ dd = dd + ":"
$ !
$ CALL Cmd$Parse "''P1'" "Cmd" "LOCAL" "LOCAL |SERVER"
$ Term = F$TRNLNM("TT") - "_"
$ Server = ( F$EXTRACT(0,2,Term) .EQS. "VT" ) -         !dialup via VTAxx:;
           .OR. ( Cmd .EQS. "SERVER" ) -                !by command;
           .OR. ( F$TRNLNM("ker$mode") .EQS. "SERVER" ) !global mode.
$ !
$ KermitF = "site$utils:kermit.exe"
$ Kermit == "$" + KermitF
$ IF F$FILE_ATTRIBUTES(KermitF,"EOF") .GT. 200  !check based on file-size
$ THEN ! set-up C-Kermit:
$      IF Verbose THEN WRITE sys$output "%KERMIT-I-new, C-Kermit"
$      IF .NOT. Server
$      THEN IF P2 .EQS. ""
$           THEN READ sys$command cl /END_OF_FILE=Done /PROMPT="Com-line <''dd'>: "
$                Server = ( F$EXTRACT(0,3,F$EDIT(cl,"UPCASE")) .EQS. "SER" )
$                IF Server
$                THEN GOTO L0
$                ELSE IF cl .NES. "" THEN cl = cl - ":" + ":"
$                     cl = F$PARSE(cl,dd,,"DEVICE","SYNTAX_ONLY")
$                ENDIF
$           ELSE P2 = P2 - ":" + ":"
$                cl = F$PARSE(P2,,,"DEVICE","SYNTAX_ONLY")
$           ENDIF
$           DEFINE /JOB ckermit$line 'cl'
$           ALLOCATE ckermit$line
$           IF .NOT. $STATUS
$           THEN WRITE sys$output "%KERMIT-E-ALLOC, modem port ''cl' is in use"
$                GOTO Done
$           ENDIF
$           IF Verbose THEN SHOW LOGICAL ckermit$line
$           CALL Shift$FKeys -  !F10 is <Ctrl/\>C
              "MP1;1|17/1C\P1;1|18/436F6E6E6563740D\P1;1|19/46696E6973680D\P1;1|20/5365727665720D\P1;1|21/1C43\" -
              "[4mF6: Ctrl/\   F7: Connect   F8: Finish   F9: Server   F10: Ctrl/\ C[0m"
$      ENDIF
$L0:
$      IF Server
$      THEN DEFINE /JOB /NOLOG ckermit_init "''Kd'CKERMIT.INI_SERVER"
$           !For some reason, "ckermit_ini" interferes with server functions:
$           IF F$TRNLNM("ckermit_ini","lnm$process") .NES. "" THEN DEASSIGN /PROCESS ckermit_ini
$           IF F$TRNLNM("ckermit_ini","lnm$job")     .NES. "" THEN DEASSIGN /JOB     ckermit_ini
$      ELSE DEFINE /JOB /NOLOG ckermit_init "''Kd'CKERMIT.INI"
$      ENDIF
$      IF Verbose THEN SHOW LOGICAL ckermit_init
$ !
$ ELSE ! set-up old Kermit-32:
$      Bel[0,32]=7
$      Bel[0,1]:='Bel'
$      WRITE sys$output Bel,"%KERMIT-I-old, Kermit-32 (!)",Bel
$      IF Server
$      THEN DEFINE /JOB /NOLOG vmskermit "''Kd'KERMIT32.SERVER"
$      ELSE DEFINE /JOB /NOLOG vmskermit "''Kd'KERMIT32.LOCAL"
$           DEFINE /JOB /NOLOG ker$comm 'dd'
$           CALL Shift$FKeys -  !F10 is <Ctrl/]>C
              "MP1;1|17/1C\P1;1|18/436F6E6E6563740D\P1;1|19/46696E6973680D\P1;1|20/5365727665720D\P1;1|21/1D43\" -
              "[4mF6: Ctrl/\   F7: Connect   F8: Finish   F9: Server   F10: Ctrl/] C[0m"
$      ENDIF
$ ENDIF
$ !
$ IF F$GETJPI("","PRIB") .GE. 4 THEN SET PROCESS /PRIORITY=3
$ Time_0 = F$TIME()
$ DEFINE /USER_MODE sys$input sys$command
$ Kermit
$ !
$Done:
$ IF F$GETJPI("","PRIB") .LT. 4 THEN SET PROCESS /PRIORITY=4
$ Dc = "site$utils:dc$datecalc.exe"
$ IF ( F$TYPE(Time_0) .NES. "" )  -
  .AND. ( F$SEARCH(Dc) .NES. "" ) -
  .AND. ( .NOT. Server )
$ THEN Dc = "$" + dc
$      Dc "''Time_0'" /DELTA /SYMBOL=Time_0 /SCOPE=LOCAL
$      WRITE sys$output F$FAO("%KERMIT-I-CONNECT_TIME:  !AS",TIME_0)
$ ENDIF
$ IF F$TRNLNM("ckermit$line","lnm$job") .NES. ""
$ THEN IF F$GETDVI("ckermit$line","ALL") THEN DEALLOCATE ckermit$line
$      DEASSIGN /JOB ckermit$line
$ ENDIF
$ IF LTA .NES. ""
$ THEN LCP delete port 'LTA'
$      WRITE sys$output "%KERMIT-I-DESTROYED, device ''LTA' deleted"
$ ENDIF
$ IF F$TRNLNM("ckermit_init","lnm$job") .NES. "" THEN DEASSIGN /JOB ckermit_init
$ IF F$TRNLNM("vmskermit","lnm$job")    .NES. "" THEN DEASSIGN /JOB vmskermit
$ EXIT
$ !
$ !
$Cmd$Parse: SUBROUTINE
$ ! P1: command to parse
$ ! P2: global symbol to receive answer
$ ! P3: default command
$ ! P4: command set ("C1|C2[|Cn...]") -- options must be same-length fields
$ ! P5: command separator
$ IF P1 .EQS. "" THEN P1 = P3
$ IF P2 .EQS. "" THEN P2 = "Cmd"
$ IF P5 .EQS. "" THEN P5 = "|"
$ P4 = F$EDIT(P4,"UPCASE")
$ S  = F$LOCATE(P5,P4) + 1               !Determine field length
$ P4 = P5 + P4                           !Add separator to front of list...
$ T  = P5 + F$EDIT(P1,"COLLAPSE,UPCASE") !...and to target
$ L  = F$LOCATE( F$EDIT(T,"COLLAPSE,UPCASE"), P4 )      !Test substring
$ IF ( L .LT. F$LENGTH(P4) ) .AND. ( L-(L/S)*S .EQ. 0 ) !Found?
$ THEN L = ( ( L + 1 ) / S ) + 1                        !Calculate offset
$      !Return both the full command and its element #:
$      'P2'     == F$EDIT( F$ELEMENT(L,P5,P4), "COLLAPSE" )
$      'P2'_Num == L  !1-based: 1=first command, 2=second, ...
$      EXIT 1
$ ELSE 'P2'     == "$Err$"
$      'P2'_Num == -1
$      WRITE sys$output "\''P1'\ (expecting: ''F$EDIT(P4,"COLLAPSE")')"
$      EXIT 229522  !%DCL-E-IVVERB, unrecognized command verb
$ ENDIF
$ ENDSUBROUTINE
$ !
$Shift$FKeys:  SUBROUTINE
$ WRITE sys$output ""
$ WRITE sys$output "''P1'"  !download <Shift><F*> text
$ WRITE sys$output "''P2'"  !show legend
$ WRITE sys$output ""
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Ctrl_Y:
$ RETURN %X2C
