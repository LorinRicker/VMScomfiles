$ ! UTIL$RESET_FILE_VERSION.COM --                                 'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2004 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  Synchronize against calling/invoking batch job (by entry), or wait for
$ !  a stall-interval if not a batch job (optional), then evaluate and rename
$ !  version-numbers for the specified file-spec, from ~..32767 down to 1..N.
$ !
$ !  P1 = Calling job's queue entry number: "BATCH|Entry#"; or for other
$ !       modes, stall-interval: "INTERACTIVE|seconds" or "INTERACTIVE|hh:mm:ss"
$ !  P2 = Filespec to renumber versions for... Must be a *single* filespec
$ !       (no wildcards!) per call to this routine.
$ !  P3 = PURGE/KEEP= & /VERSION_LIMIT= for calling job's files
$ !  P4 = Method, either "I" (default, individual and calculated renames),
$ !                   or "X" (crisscross, two bulk renames through a temp-spec)
$ !
$ Fac = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(Fac,,,"NAME","SYNTAX_ONLY")
$ wso = "WRITE sys$output"
$ Sep = "|"
$ Verbose = F$TRNLNM("Tools$Debug")
$ ! If TOOLS$DEBUG = TRUE, echo-traces commands rather than executing them...
$ !
$ IF Verbose THEN wso "%''Fac'-I-ECHO, command trace:"
$ !
$ IF P1 .NES. ""
$ THEN CallerMode = F$ELEMENT(0,Sep,P1)
$      IF CallerMode .EQS. "BATCH"
$      THEN SET NOON
$           ! This SYNCH may generate a "%JBC-E-NOSUCHENT, no such entry",
$           ! but that's OK, since we just don't want to execute at the
$           ! same time that the calling batch job's executing...
$           CallerEntry = F$ELEMENT(1,Sep,P1)
$           IF Verbose
$           THEN wso " -I-ECHO, $ SYNCHRONIZE /ENTRY=[4m''CallerEntry'[0m"
$           ELSE SYNCHRONIZE /ENTRY='CallerEntry'
$           ENDIF
$      ELSE Stall = F$ELEMENT(1,Sep,P1)
$           IF ( Stall .NES. "" ) .AND. ( Stall .NES. Sep )
$           THEN IF F$LOCATE(":",Stall) .LT. F$LENGTH(Stall)
$                THEN IF Verbose
$                     THEN wso " -I-ECHO, $ WAIT [4m''Stall'[0m         !HH:MM:SS.CC"
$                     ELSE WAIT 'Stall'
$                     ENDIF
$                ELSE IF F$LENGTH(Stall) .EQ. 1 THEN Stall = "0" + Stall
$                     IF Verbose
$                     THEN wso " -I-ECHO, $ WAIT 00:00:[4m''Stall'[0m   !just seconds"
$                     ELSE WAIT 00:00:'Stall'
$                     ENDIF
$                ENDIF
$           ENDIF
$      ENDIF
$ ENDIF
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ IF P2 .NES. ""
$ THEN FS = F$PARSE(P2)
$      FS = FS - F$PARSE(FS,,,"VERSION","SYNTAX_ONLY")
$      IF P3 .NES. ""
$      THEN PurgeLim = F$INTEGER(P3)
$      ELSE PurgeLim = 0
$      ENDIF
$      IF PurgeLim .GT. 0
$      THEN IF Verbose
$           THEN wso " -I-ECHO, $ PURGE /NOLOG [4m''FS'[0m /KEEP=[4m''P3'[0m"
$                wso " -I-ECHO, $ SET FILE /VERSION_LIMIT=[4m''P3'[0m [4m''FS'[0m;*"
$           ELSE PURGE /NOLOG 'FS' /KEEP='P3'
$                SET FILE /VERSION_LIMIT='P3' 'FS';*
$           ENDIF
$      ENDIF
$ !
$ P4 = F$EXTRACT(0,1,F$EDIT(P4,"COLLAPSE,UPCASE"))
$ IF P4 .NES. "X" THEN P4 = "I"
$ GOTO Method'P4'
$ !
$MethodI:
$ ! A more complicated method than MethodX, requiring some calculation (and
$ ! may still have some bugs for unforseen conditions), but does half as many
$ ! RENAMEs as MethodX, therefore somewhat easier on directory-block thrashing,
$ ! and looks to be interruptible and restartable.  Should be twice as fast as
$ ! MethodX for large numbers of file-versions.
$ !
$ IF Verbose THEN wso "[1m[4mMethod I - individual renames[0m"
$ !
$ ! "Subscripted" symbols V'j' and i'j' compensate for DCL 256-character limit!
$      i = 0
$      j = 0
$L0:        ! Loop to detect all existing versions of this logfile
$      IF F$TYPE(V'j') .EQS. ""
$      THEN V'j' = ""  !create/init...
$           i'j' = 0
$      ENDIF
$      F = F$SEARCH("''FS';*")
$      IF F .EQS. "" THEN GOTO L1
$      V'j' = V'j' + F$PARSE(F,,,"VERSION","SYNTAX_ONLY")
$      IF Verbose
$      THEN LVj = F$LENGTH(V'j')
$           IF LVj .GE. 63
$           THEN tmp = "..." + F$EXTRACT(LVj-60,60,V'j')
$           ELSE tmp = V'j'
$           ENDIF
$           wso F$FAO( "i:!4SL, j:!2SL - ""!AS""", i, j, tmp )
$      ENDIF
$      i = i + 1
$      i'j' = i'j' + 1
$      IF F$LENGTH(V'j') .GE. 248 THEN j = j + 1
$      GOTO L0
$ !
$L1:
$      MaxV = i
$L2:   ! Loop to rename high-versions to 1..., in correct order
$      V = F$ELEMENT(i'j',";",V'j')
$      T = MaxV - i + 1
$      IF Verbose
$      THEN wso " -I-ECHO, $ RENAME /NOLOG [1m''FS'[0m;[4m''V'[0m *.*;[4m''T'[0m"
$      ELSE RENAME /NOLOG 'FS';'V' *.*;'T'
$      ENDIF
$      i'j' = i'j' - 1
$      i = i - 1
$      IF i'j' .LE. 0 THEN j = j - 1
$      IF i .LE. 0 THEN GOTO Done
$      GOTO L2
$ ENDIF
$ !
$MethodX:
$ ! A "no-brainer" method, but does twice as many RENAMEs as MethodI, and
$ ! probably thrashes the hell out of the directory-blocks.  Fast for small
$ ! numbers of file-versions, but what happens if it gets interrupted/crashed?
$ !
$ IF Verbose THEN wso "[1m[4mMethod X - crisscross renames[0m"
$ !
$ DD  = F$PARSE(FS,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(FS,,,"DIRECTORY","SYNTAX_ONLY")
$ FN  = F$PARSE(FS,,,"NAME","SYNTAX_ONLY")
$ T   = "$TMP$"
$MXL0:
$ Tmp = DD + FN + "." + T
$ IF F$SEARCH(Tmp) .NES. ""  !find a temp-spec that doesn't previously exist...
$ THEN T = "$" + T
$      IF F$LENGTH(T) .LE. 9
$      THEN GOTO MXL0
$      ELSE wso "''Fac'-F-TEMP_FAIL, cannot find a safe temp-spec to use (.''T')"
$           GOTO Done
$      ENDIF
$ ENDIF
$ IF Verbose
$ THEN wso "-I-ECHO, $ RENAME /NOLOG ''FS'[4m;*[0m -"
$      wso "                         ''Tmp'[4m;[0m"
$      wso "         $ RENAME /NOLOG ''Tmp'[4m;*[0m -"
$      wso "                         ''FS'[4m;[0m"
$ ELSE RENAME /NOLOG 'FS';* 'Tmp';
$      RENAME /NOLOG 'Tmp';* 'FS';
$ ENDIF
$ GOTO Done
$ !
$Done:
$ Stat = $STATUS
$ EXIT 'Stat'
$ !
$Ctrl_Y:
$ RETURN %X2C
