$ ! PRIVILEGE.COM -- manages VMS privileges (assumes SETPRV)       'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Evans & Ricker, Inc.  Any unauthorized use, reproduction or
$ !  transfer of this program is strictly prohibited.
$ !
$ !  Copyright © 1989-2001 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !     usage:  PRIV [ cmd | "" ] [-|NO]priv_list
$ !
$ !     where   cmd = [ SHOW | ONE$SHOT
$ !                     | NORMAL | DEFAULT | OPERATOR
$ !                     | SYSTEM | MANAGER | ALL
$ !                     | [ ADD | SUBTRACT | PRIVILEGE ] priv_list ]
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ Ver = F$TRNLNM("Tools$Debug")
$ wso = "WRITE sys$output"
$ Msg = ""
$ !
$ IF P1 .EQS. "?" THEN GOTO Help
$ !
$ CmdSet = "SHOW     |" -
         + "ONE$SHOT |" -  ! do one command
         + "DEFAULT  |" -  ! user's AUTHPRIV set only
         + "NORMAL   |" -  ! TMPMBX,NETMBX
         + "OPERATOR |" -  ! TMPMBX,NETMBX,OPER
         + "SYSTEM   |" -  ! synonyms
         + "MANAGER  |" -  !    "
         + "ALL      |" -  ! *all* privs
         + "ADD      |" -  ! synonyms
         + "SUBTRACT |" -  !    "
         + "PRIVILEGE"     !    "
$ CALL Parse "''P1'" Parse$Cmd "SHOW" "''CmdSet'"
$ !
$ IF Parse$Cmd .EQS. "SHOW"
$ THEN SHOW PROCESS /PRIVILEGE
$      EXIT 1
$ ELSE WeakPrivs = ",DEFAULT,NORMAL,OPERATOR,"
$      Weaken    = ( F$LOCATE(",''Parse$Cmd',",WeakPrivs) .LT. F$LENGTH(WeakPrivs) )
$      GOTO 'Parse$Cmd'
$ ENDIF
$ !
$One$Shot:
$ IF (P2 .NES. "EXIT") .AND. (P2 .NES. "STOP") .AND. (P2 .NES. "")
$ THEN Command = P2 + " " + P3 + " " + P4 + " " + P5 + " " + P6 + " " + P7 + " " + P8
$      Command = F$EDIT(Command,"TRIM")
$      Prv = F$SETPRV("BYPASS,CMKRNL,SECURITY,SYSNAM,SYSPRV,WORLD")
$      'Command'  !
$      IF F$TYPE(Prv) .EQS. "STRING" THEN Prv = F$SETPRV(Prv)
$      wso ""
$ ENDIF
$ GOTO Done
$ !
$Add:
$Subtract:
$Privilege:
$L0:   !replace all "-" with "NO"
$ Dash = F$LOCATE("-",P2)
$ P2L = F$LENGTH(P2)
$ IF Dash .GE. P2L THEN GOTO SetPriv
$ car = F$EXTRACT(0,Dash,P2)
$ cdr = F$EXTRACT(Dash+1,P2L,P2)
$ P2 = car + "NO" + cdr
$ GOTO L0
$ !
$Default:
$ P2  = F$GETJPI("","AUTHPRIV")  ! restore *my* default authorized privs...
$ GOTO SetPriv
$ !
$Normal:
$ P2  = "TMPMBX,NETMBX"
$ GOTO SetPriv
$ !
$Operator:
$ P2  = "TMPMBX,NETMBX,OPER"
$ GOTO SetPriv
$ !
$System:
$Manager:
$ P2 = "BYPASS,CMKRNL,SECURITY,SYSNAM,SYSPRV,WORLD"
$ GOTO SetPriv
$ !
$All:
$ P2 = "ALL"
$ GOTO SetPriv
$ !
$SetPriv:
$ SET NOON
$ IF Weaken THEN Prv = F$SETPRV("NOALL")
$ Prv = F$SETPRV(P2)
$ IF P2 .EQS. "ALL"
$ THEN Msg = "[4mAll privileges[0m"
$ ENDIF
$ !
$Done:
$ SET NOON
$ IF ( P1 .NES. "ONE$SHOT" ) .OR. Ver
$ THEN wso F$FAO( "%PRIVILEGE-I-ENABLED: !AS", Msg )
$      CALL ListPrivs
$ ENDIF
$ LNode = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ !If any SysMgr privilege remains set, then report all privs:
$ IF   F$PRIVILEGE("BYPASS")  .OR. F$PRIVILEGE("CMKRNL")   -
  .OR. F$PRIVILEGE("READALL") .OR. F$PRIVILEGE("SECURITY") -
  .OR. F$PRIVILEGE("SYSNAM")  .OR. F$PRIVILEGE("SYSPRV")   -
  .OR. F$PRIVILEGE("WORLD")   .OR. (P2 .EQS. "REPORT")
$ THEN promptstr = LMR$promptprv    ! Privileged
$ ELSE promptstr = LMR$promptstr    ! Non-privileged
$ ENDIF
$ SET PROMPT="''promptstr'"
$ !
$ EXIT 1
$ !
$ !
$ !
$ListPrivs:  SUBROUTINE
$ ! no parameters
$ ON CONTROL THEN EXIT %X2C
$ ON ERROR THEN EXIT %X2C
$ Ln   = ""
$ j    = 0
$ CPrv = F$GETJPI("","CURPRIV")
$WLoop:
$ P = F$ELEMENT(j,",",CPrv)
$ IF ( P .EQS. "" ) .OR. ( P .EQS. "," ) THEN GOTO WEnd
$ IF Ln .EQS. ""
$ THEN Ln = P
$ ELSE Ln = Ln + "," + P
$ ENDIF
$ IF F$LENGTH(Ln) .GE. 60
$ THEN wso F$FAO( "!#* !AS", 4, Ln )
$      Ln = ""
$ ENDIF
$ j = j + 1
$ GOTO WLoop
$WEnd:
$ IF Ln .NES. "" THEN wso F$FAO( "!#* !AS", 4, Ln )
$ wso ""
$ EXIT 1
$ ENDSUBROUTINE  ! ListPrivs
$ !
$Parse: SUBROUTINE
$ ! P1: command to parse
$ ! P2: global symbol to receive answer
$ ! P3: default command
$ ! P4: command set ("C1|C2[|Cn...]") -- options must be same-length fields
$ ! P5: command separator
$ IF P1 .EQS. "" THEN P1 = P3
$ IF P2 .EQS. "" THEN P2 = "Parse$Cmd"
$ IF P5 .EQS. "" THEN P5 = "|"
$ P4 = F$EDIT(P4,"UPCASE")
$ S  = F$LOCATE(P5,P4) + 1               !Determine field length
$ P4 = P5 + P4                           !Add separator to front of list...
$ T  = P5 + F$EDIT(P1,"COLLAPSE,UPCASE") !...and to target
$ L  = F$LOCATE( F$EDIT(T,"COLLAPSE,UPCASE"), P4 )      !Test substring
$ IF ( L .LT. F$LENGTH(P4) ) .AND. ( L-(L/S)*S .EQ. 0 ) !Found?
$ THEN L = ( ( L + 1 ) / S ) + 1                        !Calculate offset
$      'P2' == F$EDIT( F$ELEMENT(L,P5,P4), "COLLAPSE" )
$      EXIT 1
$ ELSE 'P2' == "$Err$"
$      wso "\''P1'\ (expecting: ''F$EDIT(P4,"COLLAPSE")')"
$      EXIT 229522  !%DCL-E-IVVERB, unrecognized command verb
$ ENDIF
$ ENDSUBROUTINE
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

     usage:  [1m@PRIVILEGE[0m [ [1mcmd[0m | [1m""[0m ] [ [[1m-[0m|[1mNO[0m][1mpriv_list[0m ]

     where   [1mcmd[0m = [ [1mSHOW[0m (D) | [1mONE$SHOT[0m
                     | [1mNORMAL[0m | [1mDEFAULT[0m | [1mOPERATOR[0m
                     | [1mSYSTEM[0m | [1mMANAGER[0m | [1mALL[0m
                     | [ [1mADD[0m | [1mSUBTRACT[0m | [1mPRIVILEGE[0m ] [1mpriv_list[0m ]

       and   [1mpriv_list[0m is a comma-separated list of VMS privilege names
             (used only if P1 is "PRIVILEGE", "ADD" or "SUBTRACT")

         SHOW        -- Display current privileges (SHOW PROCESS /PRIVILEGE).

         ONE$SHOT    -- Performs the single command (on the rest of the
                        command line) with these elevated privileges:
                        [1mBYPASS, CMKRNL, SECURITY, SYSNAM, SYSPRV, WORLD[0m
                        which are immediately retired/dropped after the
                        single command is executed.

         NORMAL      -- Sets TMPMBX, NETMBX (normal user privileges),
                        revoking any and all elevated privileges.

         DEFAULT     -- Restores [4myour[0m authorized privileges, revoking
                        any and all elevated privileges.

         OPERATOR    -- Sets TMPMBX, NETMBX, [1mOPER[0m (operator privileges),
                        revoking any and all elevated privileges.

         SYSTEM      -- Adds [1mBYPASS, CMKRNL, SECURITY, SYSNAM, SYSPRV, WORLD[0m
         or MANAGER     to current process privileges.

         ALL         -- Sets [1m[4mall[0m VMS privileges which are authorized for
                        this process.

         PRIVILEGE   -- Requires that P2 specifies a comma-separated list of
         or ADD         VMS privileges to set.  If a privilege is prefixed
         or SUBTRACT    by "NO" or "-" (e.g., "NOBYPASS" or "-BYPASS"), then
                        that privilege is removed.

$ !
$ GOTO Done
