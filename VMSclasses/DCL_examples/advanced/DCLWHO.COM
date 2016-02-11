$ ! DCLWHO.COM --                                                  'F$VERIFY(0)'
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
$ !  use:  @DCLWHO [Username] -
$ !                [Mode]     -
$ !                [ IMAGE_NAME (D) | PROCESS_NAME | PRIVILEGES
$ !                  | CPU_TIME | LOGIN_TIME ] -
$ !                [Node[,Node...]]
$ !
$ !        "*" and "%" (wildcards) are permitted in both Username and Node
$ !
$ !  NOTE: This command procedure is a superset of SITE$UTILS:WHO.EXE, but
$ !        is written in "pure" DCL, i.e., it runs *NO* executable images,
$ !        making it slighly more useful in the event of a system panic or
$ !        hang (because image-activation does not occur).
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Exit
$ WHO$Prv = F$SETPRV("WORLD")
$ wso = "WRITE sys$output"
$ PCnt = 0
$ !
$ IF P1 .EQS. "?" THEN GOTO Help
$ !
$ CurPid = F$GETJPI("","PID")
$ Ctx = ""
$ !
$ Pn = ""
$ IF P1 .NES. ""
$ THEN i = 0
$P1L:
$      Pw = F$ELEMENT(i,",",P1)
$      IF Pw .EQS. "," THEN GOTO P1Cont
$      IF Pw .NES. ""
$      THEN Pl = F$TRNLNM(Pw)
$           IF Pl .NES. "" THEN Pw = Pl
$           IF Pn .EQS. ""
$           THEN Pn = Pw
$           ELSE Pn = Pn + "," + Pw
$           ENDIF
$      ENDIF
$      i = i + 1
$      GOTO P1L
$ ENDIF
$P1Cont:
$ IF Pn .NES. "" THEN Tmp = F$CONTEXT("PROCESS", Ctx, "USERNAME", Pn, "EQL")
$ !
$ IF P2 .NES. ""
$ THEN i = 0
$P2L:
$      Pw = F$ELEMENT(i,",",P2)
$      IF Pw .EQS. "," THEN GOTO P2Cont
$      IF Pw .NES. ""
$      THEN ON ERROR THEN EXIT ($STATUS .OR. %X10000000)
$           CALL CMD$Parse "''Pw'" Mode "INTERACTIVE" -
                 "INTERACTIVE|BATCH      |NETWORK    |OTHER      |ANY_MODE   |*          "
$           IF (CMD$Mode .EQS. "ANY_MODE") .OR. (CMD$Mode .EQS. "*")
$           THEN Tmp = F$CONTEXT("PROCESS", Ctx, "MODE", "INTERACTIVE", "EQL")
$                Tmp = F$CONTEXT("PROCESS", Ctx, "MODE", "BATCH", "EQL")
$                Tmp = F$CONTEXT("PROCESS", Ctx, "MODE", "NETWORK", "EQL")
$                Tmp = F$CONTEXT("PROCESS", Ctx, "MODE", "OTHER", "EQL")
$                GOTO P2Cont
$           ELSE Tmp = F$CONTEXT("PROCESS", Ctx, "MODE", CMD$Mode, "EQL")
$           ENDIF
$      ENDIF
$      i = i + 1
$      GOTO P2L
$ ELSE Tmp = F$CONTEXT("PROCESS", Ctx, "MODE", "INTERACTIVE", "EQL")
$ ENDIF
$P2Cont:
$ !
$ ON ERROR THEN EXIT ($STATUS .OR. %X10000000)
$ TNam = F$ELEMENT(1,":",P3) - "*" - "%"  !strip wildcards: "starting with" only
$ IF TNam .EQS. ":" THEN TNam = ""
$ P3 = F$ELEMENT(0,":",P3)
$ CALL CMD$Parse "''P3'" Type "IMAGE_NAME" -
       "IMAGE_NAME  |PROCESS_NAME|PRIVILEGES  |LOGIN_TIME  |CPU_TIME    |*           "
$ IF CMD$Type .EQS. "*" THEN CMD$Type = "IMAGE_NAME"
$ !
$ IF P4 .NES. ""
$ THEN IF P4 .EQS. "NODE" THEN P4 = F$EDIT(F$GETSYI("NODENAME"),"TRIM")
$      Tmp = F$CONTEXT("PROCESS", Ctx, "NODENAME", P4, "EQL")
$ ELSE Tmp = F$CONTEXT("PROCESS", Ctx, "NODENAME", "*", "EQL")
$ ENDIF
$ !
$ ON ERROR THEN GOTO Exit
$ wso ""
$ GOTO 'CMD$Type'
$IMAGE_NAME:
$PRIVILEGES:
$ wso "[4m  PID    Username     Terminal Node   Group      State  Pri  Image              [0m"
$ GOTO L0
$PROCESS_NAME:
$ wso "[4m  PID    Username     Terminal Process name    State  Pri  Image                [0m"
$ GOTO L0
$LOGIN_TIME:
$ wso "[4m  PID    Username     Terminal Node   Group      State  Pri  Login time         [0m"
$ GOTO L0
$CPU_TIME:
$ wso "[4m  PID    Username     Terminal Node   Group      State  Pri  CPU time           [0m"
$ GOTO L0
$ !
$L0:
$ Pid = F$PID(Ctx)
$ IF Pid .EQS. ""
$ THEN GOTO Done
$ ELSE Img = F$PARSE(F$GETJPI(Pid,"IMAGNAME"),,,"NAME","SYNTAX_ONLY")
$      Prv = F$GETJPI(Pid,"CURPRIV")
$      Rid = F$GETJPI(Pid,"PROCESS_RIGHTS")
$      IF Rid .NES. "" THEN Prv = Prv + "," + Rid
$      GOTO 'F$EXTRACT(0,3,CMD$Type)'1
$PRO1:
$IMA1:
$      IF TNam .NES. ""    !report only processes running a specific image
$      THEN IF F$EXTRACT(0,F$LENGTH(TNam),Img) .EQS. TNam
$           THEN GOTO J1  !report this process...
$           ELSE GOTO L0  !not a matched image name, skip...
$           ENDIF
$      ENDIF
$PRI1:
$      IF TNam .NES. ""    !report only processes having a specific privilege
$      THEN IF F$LOCATE(TNam,Prv) .LT. F$LENGTH(Prv)
$           THEN GOTO J1  !report this process...
$           ELSE GOTO L0  !not a matched image name, skip...
$           ENDIF
$      ENDIF
$CPU1:
$LOG1:
$J1:
$      UNa = F$GETJPI(Pid,"USERNAME")
$      UIC = F$GETJPI(Pid,"UIC")
$      IF F$LOCATE(",",UIC) .LT. F$LENGTH(UIC)          ! "[Grp,User]" form?
$      THEN UIC = F$ELEMENT(0,",",UIC) - "["            ! just show Grp
$      ELSE UICn = F$FAO("!%U",F$IDENTIFIER(UNa,"NAME_TO_NUMBER"))
$           UICn = F$ELEMENT(0,",",UICn) - "["
$           IF UICn .EQS. "1"
$           THEN UIC = "E&R"
$           ELSE UIC = ""
$           ENDIF
$      ENDIF
$      IF CMD$Type .EQS. "PROCESS_NAME"
$      THEN Nod = F$GETJPI(Pid,"PRCNAM")
$      ELSE Nod = F$GETJPI(Pid,"NODENAME")
$      ENDIF
$      Sta = F$GETJPI(Pid,"STATE")
$      CPr = F$STRING(F$GETJPI(Pid,"PRI"))
$      IF F$LENGTH(CPr) .EQS. 1 THEN CPr = " " + CPr
$      BPr = F$STRING(F$GETJPI(Pid,"PRIB"))
$      IPrv = F$GETJPI(Pid,"IMAGPRIV")
$      Mod = F$GETJPI(Pid,"MODE")
$      GOTO 'Mod'
$INTERACTIVE:
$      Ter = F$GETJPI(Pid,"TERMINAL")
$      Own = F$GETJPI(Pid,"OWNER")
$      IF Own .NES. "" THEN Ter = "(sub)"
$      GOTO L2
$BATCH:
$      Ter = "(batch)"
$      GOTO L2
$NETWORK:
$      Ter = "(netwrk)"
$      GOTO L2
$OTHER:
$      Ter = "(other)"
$      GOTO L2
$L2:
$      GOTO 'F$EXTRACT(0,3,CMD$Type)'2
$PRO2:
$PRI2:
$IMA2: IF Pid .EQS. CurPid      !special cases...
$      THEN Img = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$      ELSE IF (Img .EQS. "") .AND. ( Mod .EQS. "INTERACTIVE" ) -
            THEN Img = "(DCL)"
$      ENDIF
$      GOTO MakeLine
$CPU2: Img = F$GETJPI(Pid,"CPUTIM")
$      DD = 0
$      HH = 0
$      MM = 0
$      SS = 0
$      IF Img .GE. 8639999
$      THEN DD = Img / 8640000       !extract Days (HH*24)
$           IF DD .GT. 0 THEN Img = Img - ( DD * 8640000 )
$      ENDIF
$      IF Img .GE. 359999
$      THEN HH = Img / 360000        !extract Hours (MM*60)
$           IF HH .GT. 0 THEN Img = Img - ( HH * 360000 )
$      ENDIF
$      IF Img .GE. 5999
$      THEN MM = Img / 6000          !extract Minutes (SS*60)
$           IF MM .GT. 0 THEN Img = Img - ( MM * 6000 )
$      ENDIF
$      IF Img .GE. 100               !original integer is in SS/100 (hundredths)
$      THEN SS = Img / 100           !extract Seconds, what's left over is .CC
$           IF SS .GT. 0 THEN Img = Img - ( SS * 100 )
$      ENDIF
$      Img = F$FAO("!2SL !2ZL:!2ZL:!2ZL.!2ZL", DD, HH, MM, SS, Img)
$ !
$      EQC = F$GETJPI(Pid,"ENQCNT")
$      EQL = F$GETJPI(Pid,"ENQLM")
$      FLC = F$GETJPI(Pid,"FILCNT")
$      FLL = F$GETJPI(Pid,"FILLM")
$      PFC = F$GETJPI(Pid,"PAGFILCNT")
$      PFQ = F$GETJPI(Pid,"PGFLQUOTA")
$      VPK = F$GETJPI(Pid,"VIRTPEAK")
$      WSZ = F$GETJPI(Pid,"WSSIZE")
$      WSQ = F$GETJPI(Pid,"WSQUOTA")
$      WSX = F$GETJPI(Pid,"WSEXTENT")
$      WSP = F$GETJPI(Pid,"WSPEAK")
$      GOTO MakeLine
$LOG2: Img = F$GETJPI(Pid,"LOGINTIM")
$      GOTO MakeLine
$ !
$MakeLine:
$      IF CMD$Type .EQS. "PROCESS_NAME"
$      THEN Line = F$FAO("!8AS !12AS !8AS !15AS !5AS !2AS/!2AS !20AS", -
                          Pid, UNa,  Ter, Nod,  Sta, CPr, BPr, Img)
$      ELSE Line = F$FAO("!8AS !12AS !8AS !6AS !10AS !5AS !2AS/!2AS !18AS", -
                          Pid, UNa,  Ter, Nod, UIC,  Sta, CPr, BPr, Img)
$      ENDIF
$      CALL WriteLn "''Line'"
$      IF CMD$Type .EQS. "CPU_TIME"
$      THEN Ind = "11"
$           Line = F$FAO("!''Ind'* WS peak: !7<!SL!>   PF count: !8<!SL!>  ENQ count: !5<!SL!>", -
                          WSP, PFC, EQC)
$           CALL WriteLn "''Line'"
$           Line = F$FAO("!''Ind'*    size: !7<!SL!>      quota: !8<!SL!>      limit: !5<!SL!>", -
                          WSZ, PFQ, EQL)
$           CALL WriteLn "''Line'"
$           Line = F$FAO("!''Ind'*   quota: !7<!SL!>  Virt peak: !9<!SL!> FIL count: !5<!SL!>", -
                          WSQ, VPK, FLC)
$           CALL WriteLn "''Line'"
$           Line = F$FAO("!''Ind'*  extent: !7<!SL!> !26* limit: !5<!SL!>", -
                          WSX, FLL)
$           CALL WriteLn "''Line'"
$      ENDIF
$      IF CMD$Type .EQS. "PRIVILEGES"
$      THEN CALL DumpPrivs "" "11"
$           IF IPrv .NES. ""
$           THEN Prv = IPrv
$                CALL DumpPrivs "Image privs: " "14"
$           ENDIF
$      ENDIF
$      PCnt = PCnt + 1
$      GOTO L0
$ ENDIF
$ !
$Done:
$ wso ""
$ wso F$FAO("!AS!19* !ZL !1%Cprocess!%Eprocesses!%F", F$TIME(), PCnt)
$ wso ""
$Exit:
$ ! Error & exit handler: Cancel the context...
$ SET NOON
$ IF F$TYPE(Ctx) .EQS. "PROCESS_CONTEXT" -
  THEN Tmp = F$CONTEXT("PROCESS", Ctx, "CANCEL")
$ IF F$TYPE(CMD$Mode) .NES. "" THEN DELETE /SYMBOL /GLOBAL CMD$Mode
$ IF F$TYPE(CMD$Type) .NES. "" THEN DELETE /SYMBOL /GLOBAL CMD$Type
$ IF F$TYPE(WHO$Prv) .NES. "" THEN WHO$Prv = F$SETPRV(WHO$Prv)
$ EXIT
$ !
$ !
$DumpPrivs:  SUBROUTINE
$ SET NOON
$ Pv = P1
$ i  = 0
$Pv0:
$ P = F$ELEMENT(i,",",Prv)
$ IF P .EQS. "," THEN GOTO Pv1
$ IF Pv .EQS. ""
$ THEN Pv = P
$ ELSE Pv = Pv + " " + P
$ ENDIF
$ IF F$LENGTH(Pv) .GE. 42
$ THEN Line = F$FAO("!''P2'* !AS", Pv)
$      CALL WriteLn "''Line'"
$      Pv = ""
$ ENDIF
$ i = i + 1
$ GOTO Pv0
$Pv1:
$ IF CMD$Type .EQS. "PRIVILEGES"
$ THEN Line = F$FAO("!''P2'* !AS", Pv)        !flush last line of privileges
$      IF F$EDIT(Line,"COLLAPSE") .NES. "" -  !(not empty)
       THEN CALL WriteLn "''Line'"
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! DumpPrivs
$ !
$WriteLn:  SUBROUTINE
$ SET NOON
$ IF Pid .EQS. CurPid THEN P1 = "[1m" + P1 + "[0m"
$ wso P1
$ EXIT 1
$ ENDSUBROUTINE  ! WriteLn
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
$      CMD$'P2'     == F$EDIT( F$ELEMENT(L,P5,P4), "COLLAPSE" )
$      !!CMD$'P2'_Num == L  !1-based: 1=first command, 2=second, ...
$      EXIT 1
$ ELSE CMD$'P2'     == "$Err$"
$      !!CMD$'P2'_Num == -1
$      WRITE sys$output "\''P1'\ (expecting: ''F$EDIT(P4,"COLLAPSE")')"
$      EXIT 229522  !%DCL-E-IVVERB, unrecognized command verb
$ ENDIF
$ ENDSUBROUTINE
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  Usage:  @DCLWHO [Username[,Username...]] -
                  [Mode[,Mode...]]         -
                  [ IMAGE_NAME[:imagename] (D)
                    | PROCESS_NAME[:imagename]
                    | PRIVILEGES[:privilege]
                    | CPU_TIME
                    | LOGIN_TIME ] -
                  [Node[,Node...]]

        Use either "*" or "" to indicate omitted parameters.

        Wildcards "*" and "%" are permitted in both Username and Node.

        Username, Mode and Node can be either a single name or a comma-
        separated list of names.

  DCLWHO is a command procedure which displays a VMS process "who" report.
  It is modelled after E&R's SITE$UTILS:WHO.EXE program, and produces a
  nearly identical report with a similar command-line interface.

  However, DCLWHO.COM has the advantage of [1mnot[0m running a compiled program
  (an image program) -- since it is programmed in pure DCL (e.g., lexicals),
  it has the modest advantage of perhaps "running" in the face of a "system
  lockup" (e.g., deadlocked, stalled or run-away processes, unresolvable
  resource waits, etc.) where activating an image like WHO.EXE may serve to
  only stall your process.

  Note: Since a command-file cannot be installed with privileges (as can
  an image like WHO.EXE), you must have either SETPRV or WORLD to see a
  complete, system-wide display of processes.  Non-privileged users will
  see a warning-W-class error and a process-list which is limited in scope.

  [4mParameters (all are optional)[0m:

  P1: Username -- limits the display to just those processes which are
      owned by users who match the name(s) or pattern(s).  Logical names
      which translate to a username are also permitted.

  P2: Process mode -- limits the display to specific process modes.
      Must be one or more of: INTERACTIVE, BATCH, NETWORK or OTHER.
      Default is INTERACTIVE.

  P3: Report type detail -- selects optional fields to be displayed;
      default is IMAGE_NAME.  Must be one of:

      IMAGE_NAME    Default report which includes PID, username, terminal
                    (if the process is INTERACTIVE) or mode, node-name,
                    process state, current and base priority, and the
                    current image name (blank if DCL).

                    If specified explicitly, IMAGE_NAME can be followed
                    by an image name which further limits the display
                    to only those processes which are running that image:

                    IMAGE_NAME:imagename

      PROCESS_NAME  The process name replaces the node-name column.

                    PROCESS_NAME can be followed by an image name which
                    further limits the display to only those processes
                    which are running that image:

                    PROCESS_NAME:imagename

      PRIVILEGES    Adds one or more lines containing the process's current
                    privileges, rights-identifiers, and the privileges of
                    the installed-image (if any) to the default report.

                    PRIVILEGE can be followed by a privilege or rights-
                    identifiers name which further limits the display
                    only those processes which are running with that
                    privilege:

                    PRIVILEGES:priv

      CPU_TIME      The amount of CPU time that the process has consumed
                    replaces the image name column, and a list of working-
                    set, page-fault, virtual peak, enqueue and file limit
                    process values are displayed for each process.

      LOGIN_TIME    The date and time that the process was created
                    replaces the image name column.

  P4: Node -- limits the display to just those VMScluster nodes which
      are specified; default is "*" (all nodes in the cluster or just
      the current node if not in a cluster).  The special value "NODE"
      can be used to display the report for "the current node only"
      (even if you don't know the name of your node).

  [4mExamples[0m:

  $ WHO == "@mgr$command:dclwho.com"

  $ WHO                    !Default report
  $ WHO *                  ! (ditto)

  $ WHO * *                !Lists the whole system, all modes

  $ WHO *RICKER*,R_*       !Report only these users

  $ WHO * BATCH            !Report batch jobs only
  $ WHO "" NET,OTHER       !Report network and detached processes

  $ WHO * *                !Report whole system process-list
  $ WHO * ANY_MODE         ! (ditto)

  $ WHO * BAT,INT CPU      !Report CPU time for batch and interactives

  $ WHO * "" PRIV          !Include process privileges for interactives

  $ WHO * * * RUGER        !Report whole system-list for named node(s) only
  $ WHO * * * STURM,RUGER

  $ WHO /OUTPUT=filespec   !Redirects report output to a file...
                           !  Note that /OUTPUT must immediately follow the
                           !  command WHO, before any command parameters

$ GOTO Exit
$ !
$Ctrl_Y:
$ RETURN %X2C
