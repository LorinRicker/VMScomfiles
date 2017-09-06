$ ! MAKEDIR.COM --                                                 'F$VERIFY(0)'
$ !
$ ! Copyright © 2003-2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ !  use: @MAKEDIR [ dirspec | * ]                                 -
$ !                [ lnm [ /PROCESS | /JOB | /GROUP | /SYSTEM ] ]  -
$ !                [ /OWNER=option ]                               -
$ !                [ /PROTECTION=(mask) ]                          -
$ !                [ /VERSION_LIMIT=n ]                            -
$ !                [ /GO | /NOGO ]                                 -
$ !                [ /REMOTE=(node[::dev:][,rlnm][,lnmtbl]) ]      -
$ !                [ /REUSE ]                                      -
$ !                [ /LOG ]                                        -
$ !                [ /SHOW ]                                       -
$ !                [ /RESET ]                                      -
$ !                [ /GET ]                                        -
$ !                [ /PUT ]
$ !
$ !  /GET and /PUT are used internally only to define command symbols
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ wso  = "WRITE sys$output"
$ DD   = F$ENVIRONMENT("PROCEDURE")
$ Fac  = F$PARSE(DD,,,"NAME","SYNTAX_ONLY")
$ DD   = F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ Self = DD + Fac
$ Verbose = F$TRNLNM("TOOLS$Debug")
$ !
$ MaxJ    = 9   ! some reasonable upper-limit
$ GoDir   = 1
$ LNMTbl  = "/PROCESS"
$ RemPath = ""
$ RemLNM  = ""
$ RemTbl  = ""
$ Prot    = ""
$ Owner   = ""
$ VersLm  = ""
$ Log     = "/NOLOG"
$ !
$ Comma   = ","
$ Slash   = "/"
$ Equal   = "="
$ Colon   = ":"
$ Space   = " "
$ !
$ IF F$TYPE(MD$LocList) .NES. "STRING" THEN MD$LocList == Comma
$ IF F$TYPE(MD$RemList) .NES. "STRING" THEN MD$RemList == Comma
$ IF F$TYPE(MD$LastLnm) .NES. "STRING" THEN MD$LastLnm == ""
$ !
$ IF ( F$EXTRACT(0,1,P1) .EQS. "?" ) .OR. ( F$EXTRACT(0,1,P2) .EQS. "?" ) -
  THEN GOTO Help
$ !
$ ! ------- Process /PUT or /GET first, since order of arguments is known:
$ ! /PUT
$ IF P2 .EQS. "/PUT"
$ THEN IF Verbose
$      THEN wso "%''Fac'-I-RPUT, $ [1mCOPY /LOG ''P4' ''P3'[0m  !put..."
$      ELSE COPY /LOG 'P4' 'P3'
$      ENDIF
$      GOTO Done   !just the copy, thanks...
$ ENDIF
$ !
$ ! /GET
$ IF P2 .EQS. "/GET"
$ THEN IF Verbose
$      THEN wso "%''Fac'-I-RGET, $ [1mCOPY /LOG ''P3'''P4' []*.*[0m  !get..."
$      ELSE COPY /LOG 'P3''P4' []*.*
$      ENDIF
$      GOTO Done   !just the copy, thanks...
$ ENDIF
$ !
$ ! -------- process arguments and qualifiers --------
$ IF P1 .EQS. "" THEN P1 = "*"
$ !
$ ! Move first non-slashed parameter to P2:
$ IF F$EXTRACT(0,1,P2) .EQS. Slash
$ THEN i = 3
$PL2:
$      IF i .GT. 8 THEN GOTO PC2
$      IF F$EXTRACT(0,1,P'i') .NES. Slash
$      THEN Tmp  = P2
$           P2   = P'i'
$           P'i' = Tmp
$           GOTO PG2
$      ENDIF
$      i = i + 1
$      GOTO PL2
$ ELSE GOTO PG2
$ ENDIF
$PC2:  ! didn't find a non-slashed P2
$ P2 = ""
$ GOTO Q0
$PG2:  ! got a P2
$ !
$Q0:
$ Quals  = P3 + P4 + P5 + P6 + P7 + P8
$ Quals  = F$EDIT(Quals,"COMPRESS,TRIM")
$ LQuals = F$LENGTH(Quals)
$ !
$ ! /GO
$ GoDir = ( F$LOCATE("/GO",Quals) .LT. LQuals ) .OR. GoDir -
          .AND. .NOT. ( F$LOCATE("/NOGO",Quals) .LT. LQuals )
$ !
$ ! /LOG
$ IF F$LOCATE("/LOG",Quals) .LT. LQuals
$ THEN Log = "/LOG"
$ ELSE Log = "/NOLOG"
$ ENDIF
$ !
$ ! /RESET
$ Reset = ( F$LOCATE("/RES",Quals) .LT. LQuals )
$ !
$ ! /SHOW
$ ShowLNMs = ( F$LOCATE("/SHO",Quals) .LT. LQuals )
$ !
$ ! /REUSE
$ IF F$LOCATE("/REU",Quals) .LT. LQuals
$ THEN IF MD$RemList .GES. ","  ! not empty...
$      THEN j = MaxJ            ! use latest-remembered...
$QRU0:
$           Tmp = F$ELEMENT(j,Comma,MD$RemList)
$           IF Tmp .GTS. Comma
$           THEN RemLNM = F$ELEMENT(0,Slash,Tmp)
$                RemTbl = F$ELEMENT(1,Slash,Tmp)
$                IF RemTbl .EQS. Slash
$                THEN RemTbl = "/PROCESS"
$                ELSE RemTbl = Slash + RemTbl
$                ENDIF
$                RemPath = F$PARSE(MD$RemPath,,,"NODE","SYNTAX_ONLY") -
                         + F$PARSE(MD$RemPath,,,"DEVICE","SYNTAX_ONLY") -
                         + F$PARSE(F$ENVIRONMENT("DEFAULT"),,,"DIRECTORY","SYNTAX_ONLY")
$                CALL DefineRemoteLogical "''RemLNM'" "''RemPath'" "''RemTbl'"
$                ShowLNMs = "TRUE"
$                GOTO A4
$           ELSE j = j - 1
$                IF j .GE. 1
$                THEN GOTO QRU0  ! iterate...
$                ELSE GOTO QRU1  ! done with error...
$                ENDIF
$           ENDIF
$      ENDIF
$QRU1:
$      wso "%''Fac'-E-REUSE, nothing to reuse..."
$      GOTO Done
$ ENDIF
$ !
$ ! /REMOTE=(node::dev:[,rlnm][,lnmtbl])
$ IF F$LOCATE("/REM",Quals) .LT. LQuals
$ THEN i = 1
$QL1:
$      Q = F$EDIT(F$ELEMENT(i,Slash,Quals),"COLLAPSE,UPCASE")
$      IF ( Q .EQS. Slash ) .OR. ( Q .EQS. "" ) .OR. ( i .GT. 8 ) THEN GOTO QC1
$      IF F$EXTRACT(0,3,Q) .EQS. "REM"
$      THEN Tmp = F$ELEMENT(1,Equal,Q) - "(" - ")"
$           IF Tmp .EQS. Equal THEN Tmp = ""
$           RemPath = F$ELEMENT(0,Comma,Tmp)
$           IF RemPath .EQS. Comma THEN RemPath = ""
$           IF F$LOCATE(Comma,Tmp) .LT. F$LENGTH(Tmp)
$           THEN RemLNM = F$ELEMENT(1,Comma,Tmp)
$                RemTbl = F$ELEMENT(2,Comma,Tmp)
$           ENDIF
$           IF ( RemTbl .EQS. "" ) .OR. ( RemTbl .EQS. Comma )
$           THEN RemTbl = "/PROCESS"
$           ELSE RemTbl = Slash + RemTbl
$           ENDIF
$           IF RemLNM .EQS. Comma THEN RemLNM = ""
$           IF RemPath .EQS. ""
$           THEN IF F$TYPE(MD$RemPath) .EQS. "STRING"
$                THEN RemPath = MD$RemPath
$                ELSE wso "%''Fac'-E-REMOTE, node name required for /REMOTE (NODE::DEV:, device optional)"
$                     GOTO Done
$                ENDIF
$                GOTO QC1
$           ELSE len = F$LENGTH(RemPath)
$                n = F$LOCATE("::",RemPath)
$                IF n .LT. len - 2    ! ""node::"?
$                THEN dv = F$EXTRACT(n+2,len-n+2,RemPath)
$                     len = F$LENGTH(dv)
$                     IF F$EXTRACT(len-1,1,dv) .NES. ":"
$                     THEN RemPath = RemPath + ":"
$                     ENDIF
$                ELSE IF n .GE. len   ! "node"
$                     THEN RemPath = RemPath + "::"
$                     ENDIF
$                     TarDir = F$ENVIRONMENT("DEFAULT")
$                     LocDev = F$PARSE(TarDir,,,"DEVICE","SYNTAX_ONLY") - ":"
$                     ! Does local dev-name translate into a rooted-logical?
$                     ! If it does, then use/include the local logical name...
$                     LocTrn = F$TRNLNM(LocDev)
$                     IF F$LOCATE(".]",LocTrn) .LT. F$LENGTH(LocTrn)
$                     THEN RemPath = RemPath + LocDev + ":"
$                     ENDIF
$                     IF Verbose
$                     THEN SHOW SYMBOL /LOCAL LocDev
$                          SHOW SYMBOL /LOCAL LocTrn
$                          SHOW SYMBOL /LOCAL RemPath
$                     ENDIF
$                ENDIF
$                MD$RemPath == RemPath  !global memory for next time...
$                GOTO QC1
$           ENDIF
$      ENDIF
$      i = i + 1
$      GOTO QL1
$ ENDIF
$QC1:
$ !
$ ! /PROT[ECTION]=(mask)
$ IF F$LOCATE("/PROT",Quals) .LT. LQuals
$ THEN i = 1
$QL2:
$      Q = F$EDIT(F$ELEMENT(i,Slash,Quals),"COLLAPSE,UPCASE")
$      IF ( Q .EQS. Slash ) .OR. ( Q .EQS. "" ) .OR. ( i .GT. 8 ) THEN GOTO QC2
$      IF F$EXTRACT(0,4,Q) .EQS. "PROT"
$      THEN Prot = Slash + Q
$           GOTO QC2
$      ENDIF
$      i = i + 1
$      GOTO QL2
$ ENDIF
$QC2:
$ !
$ ! /OWN[ER_UIC]=option
$ IF F$LOCATE("/OWN",Quals) .LT. LQuals
$ THEN i = 1
$QL3:
$      Q = F$EDIT(F$ELEMENT(i,Slash,Quals),"COLLAPSE,UPCASE")
$      IF ( Q .EQS. Slash ) .OR. ( Q .EQS. "" ) .OR. ( i .GT. 8 ) THEN GOTO QC3
$      IF F$EXTRACT(0,3,Q) .EQS. "OWN"
$      THEN Owner = Slash + Q
$           GOTO QC3
$      ENDIF
$      i = i + 1
$      GOTO QL3
$ ENDIF
$QC3:
$ !
$ ! /VERS[ION_LIMIT]=n
$ IF F$LOCATE("/VERS",Quals) .LT. LQuals
$ THEN i = 1
$QL4:
$      Q = F$EDIT(F$ELEMENT(i,Slash,Quals),"COLLAPSE,UPCASE")
$      IF ( Q .EQS. Slash ) .OR. ( Q .EQS. "" ) .OR. ( i .GT. 8 ) THEN GOTO QC4
$      IF F$EXTRACT(0,4,Q) .EQS. "VERS"
$      THEN VersLm = Slash + Q
$           GOTO QC4
$      ENDIF
$      i = i + 1
$      GOTO QL4
$ ENDIF
$QC4:
$ !
$ !
$ ! -------- do it --------
$ IF Verbose
$ THEN SHOW SYMBOL P1
$      SHOW SYMBOL P2
$      SHOW SYMBOL Quals
$      SHOW SYMBOL RemPath
$      SHOW SYMBOL RemLNM
$      SHOW SYMBOL RemTbl
$ ENDIF
$ !
$A0:
$ IF Reset
$ THEN j = 1
$ALoc0:
$      Tmp = F$ELEMENT(j,Comma,MD$LocList)
$      IF ( Tmp .EQS. Comma ) .OR. ( Tmp .EQS. "" )
$      THEN GOTO ALocC0
$      ELSE Tbl = F$ELEMENT(1,Slash,Tmp)
$           LT  = "LNM$" + Tbl
$           Tmp = F$ELEMENT(0,Slash,Tmp)
$           IF F$TRNLNM(Tmp,LT) .NES. "" THEN DEASSIGN 'Tmp' /'Tbl'
$           j = j + 1
$           GOTO ALoc0
$      ENDIF
$ALocC0:
$      j = 1
$ARem0:
$      Tmp = F$ELEMENT(j,Comma,MD$RemList)
$      IF ( Tmp .EQS. Comma ) .OR. ( Tmp .EQS. "" )
$      THEN GOTO ARemC0
$      ELSE Tbl = F$ELEMENT(1,Slash,Tmp)
$           LT  = "LNM$" + Tbl
$           Tmp = F$ELEMENT(0,Slash,Tmp)
$           IF F$TRNLNM(Tmp,LT) .NES. "" THEN DEASSIGN 'Tmp' /'Tbl'
$           j = j + 1
$           GOTO ARem0
$      ENDIF
$ARemC0:
$      CALL RSymbols "" "''Reset'"
$      MD$LocList == Comma
$      MD$RemList == Comma
$      MD$LastLnm == ""
$      IF F$TYPE(MD$RemPath) .NES. "" THEN DELETE /SYMBOL /GLOBAL MD$RemPath
$ ENDIF
$ !
$A1:  ! Create a (sub)directory, optionally go to it...
$ IF ( P1 .NES. "" ) .AND. ( P1 .NES. "*" )
$ THEN ! Construct the fully-formed target directory specification,
$      ! best done by a silent SET DEFAULT (trick!) and a return:
$      CurDir = F$ENVIRONMENT("DEFAULT")  ! save current location
$      SET DEFAULT 'P1'                   ! works even if dir doesn't yet exist
$      TarDir = F$ENVIRONMENT("DEFAULT")  ! what we want to create...
$      SET DEFAULT 'CurDir'               ! return to current location
$      IF Verbose
$      THEN Q  = F$EDIT(" ''Owner' ''Prot' ''VersLm' ''Log' ''F$EDIT(TarDir,"LOWERCASE")'","COMPRESS")
$           wso "%''Fac-I-ECHO, $ [1mCREATE /DIR''Q'[0m"
$           Stat = 1
$      ELSE CREATE /DIRECTORY 'Owner' 'Prot' 'VersLm' 'Log' 'TarDir'
$           Stat = $STATUS
$      ENDIF
$      IF GoDir .AND. Stat
$      THEN cd = "site$utils:cd.com"
$           IF F$SEARCH(cd) .NES. ""
$           THEN IF Verbose
$                THEN TD = F$EDIT(TarDir,"LOWERCASE")
$                     wso "%''Fac'-I-ECHO, $ [1m@''cd' ''TD'[0m"
$                ELSE @'cd' 'TarDir'
$                     wso "%''Fac'-I-GO, cd is ''F$ENVIRONMENT("DEFAULT")'"
$                ENDIF
$           ELSE IF Verbose
$                THEN TD = F$EDIT(TarDir,"LOWERCASE")
$                     wso "%''Fac'-I-ECHO, $ [1mSET DEFAULT ''TD'[0m"
$                     wso "%''Fac'-I-ECHO, $ [1mSHOW DEFAULT[0m"
$                ELSE SET DEFAULT 'TarDir'
$                     wso "%''Fac'-I-GO, show default is ''F$ENVIRONMENT("DEFAULT")'"
$                ENDIF
$           ENDIF
$      ELSE wso "%''Fac'-I-NOGO, directory remains ''F$ENVIRONMENT("DEFAULT")'"
$      ENDIF
$ ELSE TarDir = F$ENVIRONMENT("DEFAULT")
$ ENDIF
$ !
$A2:  ! Define a specific local-target logical name...
$ IF P2 .NES. ""
$ THEN IF F$LOCATE("/SYS",Quals) .LT. LQuals
$      THEN IF F$PRIVILEGE("SYSNAM")
$           THEN LNMTbl = "/SYSTEM"
$           ELSE wso "%''Fac'-E-NOPRIV, insufficient privilege to DEFINE /SYSTEM"
$                GOTO A3
$           ENDIF
$      ENDIF
$      IF F$LOCATE("/GRO",Quals) .LT. LQuals
$      THEN IF F$PRIVILEGE("GRPNAM")
$           THEN LNMTbl = "/GROUP"
$           ELSE wso "%''Fac'-E-NOPRIV, insufficient privilege to DEFINE /GROUP"
$                GOTO A3
$           ENDIF
$      ENDIF
$      IF F$LOCATE("/JOB",Quals) .LT. LQuals THEN LNMTbl = "/JOB"
$      IF F$LOCATE("/PRO",Quals) .LT. LQuals THEN LNMTbl = "/PROCESS"
$      IF Verbose
$      THEN P2 = F$EDIT(P2,"LOWERCASE")
$           TD = F$EDIT(TarDir,"LOWERCASE")
$           wso "%''Fac'-I-ECHO, $ [1mDEFINE ''Log' ''LNMTbl' ''P2' ''TD'[0m"
$      ENDIF
$      LT = "LNM$" + LNMTbl - Slash
$      LEqv = F$TRNLNM(P2,LT)
$      IF LEqv .NES. TarDir
$      THEN DEFINE 'Log' 'LNMTbl' 'P2' 'TarDir'
$           IF Log .EQS. "/LOG" THEN SHOW LOGICAL /FULL 'P2'
$           Tmp = P2 + LNMTbl + Comma
$           IF F$LOCATE(",''Tmp'",MD$LocList) .GE. F$LENGTH(MD$LocList) -
            THEN MD$LocList == MD$LocList + Tmp
$      ELSE wso "%''Fac'-I-DEFINED, ''P2' is already defined correctly"
$      ENDIF
$      CALL RSymbols "''P2'"
$ ENDIF
$ !
$A3:  ! Define a new or replacement remote-target logical name...
$ IF RemPath .NES. ""
$ THEN IF F$EXTRACT(0,4,RemTbl) .EQS. "/SYS"
$      THEN IF .NOT. F$PRIVILEGE("SYSNAM")
$           THEN wso "%''Fac'-E-NOPRIV, insufficient privilege to DEFINE /SYSTEM"
$                GOTO Done
$           ELSE LT = "lnm$system"
$                GOTO AC3
$           ENDIF
$      ENDIF
$      IF F$EXTRACT(0,4,RemTbl) .EQS. "/GRO"
$      THEN IF .NOT. F$PRIVILEGE("GRPNAM")
$           THEN wso "%''Fac'-E-NOPRIV, insufficient privilege to DEFINE /GROUP"
$                GOTO Done
$           ELSE LT = "lnm$group"
$                GOTO AC3
$           ENDIF
$      ENDIF
$      IF F$EXTRACT(0,4,RemTbl) .EQS. "/JOB"
$      THEN LT = "lnm$job"
$           GOTO AC3
$      ENDIF
$      IF F$EXTRACT(0,4,RemTbl) .EQS. "/PRO"
$      THEN LT = "lnm$process"
$           GOTO AC3
$      ENDIF
$AC3:
$      RemPath = F$PARSE(RemPath,MD$RemPath,,"NODE","SYNTAX_ONLY") -
               + F$PARSE(RemPath,MD$RemPath,,"DEVICE","SYNTAX_ONLY") -
               + F$PARSE(TarDir,,,"DIRECTORY","SYNTAX_ONLY")
$      IF RemLNM .EQS. ""
$      THEN ! invent a default: R1, R2, ..., R<MaxJ>
$           j    = 1
$AR0:
$           IF j .GT. MaxJ THEN GOTO AR1
$           REqv = F$TRNLNM("R''j'",LT)
$           IF REqv .NES. ""
$           THEN IF REqv .EQS. RemPath
$                THEN wso "%''Fac'-I-DEFINED, R''j' is already defined correctly"
$                     SHOW LOGICAL /FULL R'j'
$                     CALL RSymbols "R''j'"
$                     GOTO A4
$                ENDIF
$           ELSE RemLNM = "R''j'"
$                GOTO AR1
$           ENDIF
$           j = j + 1
$           GOTO AR0
$      ENDIF
$AR1:
$      CALL DefineRemoteLogical "''RemLNM'" "''RemPath'" "''RemTbl'"
$ ENDIF
$ !
$A4:
$ IF ShowLNMs
$ THEN j = 1
$      h = 0
$ALoc4:
$      Tmp = F$ELEMENT(j,Comma,MD$LocList)
$      IF ( Tmp .EQS. Comma ) .OR. ( Tmp .EQS. "" )
$      THEN GOTO ALocC4
$      ELSE IF h .EQ. 0
$           THEN wso F$FAO("!/[4m!AS local logical names:[0m", Fac)
$                h = 1
$           ENDIF
$           Tbl = F$ELEMENT(1,Slash,Tmp)
$           LT  = "LNM$" + Tbl
$           Tmp = F$ELEMENT(0,Slash,Tmp)
$           IF F$TRNLNM(Tmp,LT) .NES. ""
$           THEN SHOW LOGICAL /FULL 'Tmp' /'Tbl'
$                j = j + 1
$           ELSE Tmp = Tmp + Slash + Tbl + Comma
$                MD$LocList == MD$LocList - Tmp  !remove residue from memory
$           ENDIF
$           GOTO ALoc4
$      ENDIF
$ALocC4:
$      IF j .EQ. 1 THEN wso "%''Fac'-I-NO_LOCAL, no local logicals"
$      j = 1
$      h = 0
$ARem4:
$      Tmp = F$ELEMENT(j,Comma,MD$RemList)
$      IF ( Tmp .EQS. Comma ) .OR. ( Tmp .EQS. "" )
$      THEN GOTO ARemC4
$      ELSE IF h .EQ. 0
$           THEN wso F$FAO("!/[4m!AS remote logical names:[0m", Fac)
$                h = 1
$           ENDIF
$           Tbl = F$ELEMENT(1,Slash,Tmp)
$           LT  = "LNM$" + Tbl
$           Tmp = F$ELEMENT(0,Slash,Tmp)
$           IF F$TRNLNM(Tmp,LT) .NES. ""
$           THEN SHOW LOGICAL /FULL 'Tmp' /'Tbl'
$                j = j + 1
$           ELSE Tmp = Tmp + Slash + Tbl + Comma
$                MD$RemList == MD$RemList - Tmp  !remove residue from memory
$           ENDIF
$           GOTO ARem4
$      ENDIF
$ARemC4:
$      IF j .EQ. 1
$      THEN wso "%''Fac'-I-NO_REMOTE, no remote logicals"
$      ELSE wso F$FAO("!80*-")
$      ENDIF
$ ENDIF
$ !
$Done:
$ SET NOON
$ IF Verbose
$ THEN wso "%''Fac'-I-MEMORY, persistent memory of:"
$      IF F$TYPE(MD$LocList) .EQS. "STRING" THEN SHOW SYMBOL /GLOBAL MD$LocList
$      IF F$TYPE(MD$RemList) .EQS. "STRING" THEN SHOW SYMBOL /GLOBAL MD$RemList
$      IF F$TYPE(MD$RemPath) .EQS. "STRING" THEN SHOW SYMBOL /GLOBAL MD$RemPath
$      IF F$TYPE(MD$LastLnm) .EQS. "STRING" THEN SHOW SYMBOL /GLOBAL MD$LastLnm
$      IF F$TYPE(RGET) .EQS. "STRING"
$      THEN t1 = F$ELEMENT(3,Space,RGET)
$           t0 = RGET - t1
$           wso F$FAO("!8* [1m[4mRGET[0m == ""!AS[1m[4m!AS[0m""", t0, t1 )
$      ENDIF
$      IF F$TYPE(RPUT) .EQS. "STRING"
$      THEN t1 = F$ELEMENT(3,Space,RPUT)
$           t0 = RPUT - t1
$           wso F$FAO("!8* [1m[4mRPUT[0m == ""!AS[1m[4m!AS[0m""", t0, t1 )
$      ENDIF
$ ENDIF
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$ !
$DefineRemoteLogical:  SUBROUTINE
$ ! P1 - remote logical name
$ ! P2 - remote path
$ ! P3 - logical name table
$ !
$ ON CONTROL_Y THEN GOSUB DRLCtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ IF Verbose
$ THEN RL = F$EDIT(P1,"LOWERCASE")
$      RD = F$EDIT(P2,"LOWERCASE")
$      wso "%''Fac'-I-ECHO, $ [1mDEFINE''Log' ''P3' ''RL' ''RD'[0m"
$ ENDIF
$ LT = "LNM$" + P3 - Slash
$ REqv = F$TRNLNM(P1,LT)
$ IF REqv .NES. P2
$ THEN DEFINE 'Log' 'P3' 'P1' 'P2'
$      IF Log .EQS. "/LOG" THEN SHOW LOGICAL /FULL 'P1'
$      Tmp = P1 + P3 + Comma
$      IF F$LOCATE(",''Tmp'",MD$RemList) .GE. F$LENGTH(MD$RemList) -
       THEN MD$RemList == MD$RemList + Tmp
$ ELSE wso "%''Fac'-I-DEFINED, ''P1' is already defined correctly"
$ ENDIF
$ CALL RSymbols "''P1'"
$ EXIT 1
$ !
$DRLCtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! DefineRemoteLogical
$ !
$RSymbols:  SUBROUTINE
$ SET NOON
$ ! (Re)Create two utility command symbols which make
$ ! it easier to copy files to/from the target:
$ IF .NOT. P2  ! reset?
$ THEN RGET == "@''Self' * /GET ''P1':"
$      RPUT == "@''Self' * /PUT ''P1':"
$ ELSE IF F$TYPE(RGET) .NES. "" THEN DELETE /SYMBOL /GLOBAL RGET
$      IF F$TYPE(RPUT) .NES. "" THEN DELETE /SYMBOL /GLOBAL RPUT
$ ENDIF
$ IF Log .NES. ""
$ THEN T1 = F$ELEMENT(3,Space,RGET) - ":"
$      wso "%''Fac'-I-CMDSYM, [4mRPUT[0m and [4mRGET[0m now use [1m[4m''T1'[0m:"
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! RSymbols
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  MAKEDIR.COM provides a related set of functional enhancements for creating
  directories/subdirectories and for maintaining (copying) files between
  `project mirror' directories on two DECnet nodes.  It can:

  a) Create a subdirectory, define a logical name for that subdirectory, and
     optionally perform a SET DEFAULT to that new subdirectory.

  b) Create a logical name for either the newly created subdirectory, or for
     the current directory if another subdirectory is not created.

  c) Define a logical name for a `project mirror' subdirectory which matches
     the current subdirectory on another node/system connected via DECnet.

  use: [1m@MAKEDIR[0m [ [1mdirspec[0m | [1m*[0m ]                                 -
                [ [1mlnm[0m [ [1m/PROCESS[0m | [1m/JOB[0m | [1m/GROUP[0m | [1m/SYSTEM[0m ] ]  -
                [ [1m/OWNER=option[0m ]                               -
                [ [1m/PROTECTION=(mask)[0m ]                          -
                [ [1m/VERSION_LIMIT=n[0m ]                            -
                [ [1m/GO[0m | [1m/NOGO[0m ]                                 -
                [ [1m/REMOTE=(node[0m[[1m::dev:[0m][[1m,rlnm[0m][[1m,lnmtbl[0m]) ]      -
                [ [1m/REUSE[0m ]                                      -
                [ [1m/LOG[0m ]                                        -
                [ [1m/SHOW[0m ]                                       -
                [ [1m/RESET[0m ]
  where

  [1mdirspec[0m        - The specification of the directory (or subdirectory) you
                   want to create.  This dir-spec must be given using correct
                   VMS syntax; either absolute (e.g., DEVICE:[DIR.SUB]) or
                   relative (e.g., [-.SUB]) directory syntax is valid.

                   If you want to create a local and/or a remote logical
                   name for the current directory rather than creating a
                   (sub)directory, specify "[1m*[0m" for this P1 parameter.

  [1mlnm[0m            - The logical name to be defined for the (sub)directory
                   created by this procedure, or the logical name for the
                   current directory if "[1m*[0m" is specifed for P1.

                   By default, the logical name is created in the LNM$PROCESS
                   logical name table.  This can be changed by using one of
                   these command qualifiers:  [1m/PROCESS[0m (the default), [1m/JOB[0m
                   (requires no additional privilege), [1m/GROUP[0m (requires that
                   you have GRPNAM privilege), or [1m/SYSTEM[0m (requires SYSNAM
                   privilege).

  [1m/OWNER[0m         - These are all CREATE /DIRECTORY command qualifiers; see
  [1m/PROTECTION[0m    - the HELP entry for this DCL command for full information
  [1m/VERSION_LIMIT[0m - on these qualifiers:
                     $ [1mHELP CREATE /DIR[0m ...

  [1m/GO[0m (default)  - When a subdirectory is created, this procedure will either
  [1m/NOGO[0m          - CD (if SITE$UTILS:CD.COM is installed) or SET DEFAULT to
                   that newly created subdirectory; [1m/GO[0m is the default action
                   when creating a new subdirectory.  [1m/NOGO[0m forces the process
                   to stay in the current directory; no additional CD or SET
                   DEFAULT is done.

  [1m/REMOTE[0m        - Creates a logical name for a `project mirror' directory on
                   another DECnet node, which permits you to perform any
                   DECnet-enabled DCL command using this logical name (which
                   can save considerable typing for frequent operations),
                   including COPY, DIRECTORY, PURGE, DELETE and RENAME opera-
                   tions.  See examples below.

                   The general argument syntax for this qualifier is
                   [1m/REMOTE=(node::dev:,logical_name,lnm_table)[0m.  Of these
                   argument components, only the [1mnode::[0m is required.  In
                   particular, if the remote (target) directory is located
                   on the [4msame[0m device as that of your own login/home direc-
                   tory, then the [1mdev:[0m can be omitted.

                   The "::" punctuation is optional if you are specifying
                   only the [1mnode::[0m name, but is required if you specify a
                   [1mdev:[0m device.  The trailing ":" device punctuation is
                   also optional.  Do [4mnot[0m specify a "[dir]" or "[dir.sub]",
                   since the remote directory this will be inherited (copied)
                   from your current local default directory specification.

                   MAKEDIR remembers the last node name and device name you
                   specified on a previous use of /REMOTE, and will apply
                   either or both of these names to the next use of /REMOTE
                   that does not specify a node and/or device name.  This
                   means that a node/device name is required for only the
                   very first use of /REMOTE during an interactive session.
                   Of course, you can specify a node and/or device any time
                   you need to change either of these specifications.

                   You can specify your own [1mlogical_name[0m for the remote/
                   target directory if you like; however, if you omit this
                   logical name, then the procedure will automatically make
                   a logical name assignment for you, starting with [4mR1[0m, and
                   using [4mR2[0m through [4mR9[0m for subsequent remote/target directory
                   logicals (if/as you continue to omit this component for
                   subsequent uses of /REMOTE).

                   By default, the remote logical_name is created in the
                   LNM$PROCESS logical name table; as with the local logical
                   name, this can be changed using one of these table names:
                   [1mPROCESS[0m (the default), [1mJOB[0m (requires no additional privi-
                   lege), [1mGROUP[0m (requires GRPNAM privilege), or [1mSYSTEM[0m
                   (requires SYSNAM privilege).  Note that these table names
                   [4mmust not[0m have a leading "/" (a syntax limitation).

  [1m/REUSE[0m         - Repeats (reuses) the last /REMOTE=(node::dev:[,...])
                   command, presumably because you have changed directories
                   and want to use the same remote logical name setup as you
                   were using in a previous directory.

  [1m/LOG[0m           - Displays progress and status messages.

  [1m/SHOW[0m          - Displays a list of all of the local and remote logical
                   names that MAKEDIR has defined during the current session.

  [1m/RESET[0m         - Deassigns all logical names defined by MAKEDIR
                   and resets all global memory elements.


  [4mExamples[0m

 1. The following two symbol definitions make it easy to use the two
    primary functions of MAKEDIR.COM:

    $ [1mMD*IR     == "@site$utils:makedir"[0m
    $ [1mML*OGICAL == "@site$utils:makedir *"[0m

 2. Assume your current directory is SYS$USER1:[PROJ] ...

    $ [1mSHOW DEFAULT[0m
      SYS$USER1:[PROJ]

 3. To create a subdirectory here and set default to it (/GO is the default):

    $ [1mMDIR [.TEST][0m
      SYS$USER1:[PROJ.TEST]
    %MAKEDIR-I-GO, cd is SYS$USER1:[PROJ.TEST]

    Since SITE$UTILS:CD.COM is installed, the above messages confirm
    its use to effect the SET DEFAULT; if this command procedure is not
    present on your system, then native VMS SET/SHOW DEFAULT commands
    are used by MAKEDIR.

 4. To create another subdirectory, this time without going to it, but also
    creating a logical name for it:

    $ [1mMDIR [.ATEST] TEST /NOGO[0m
    %MAKEDIR-I-NOGO, directory remains SYS$USER1:[PROJ.TEST]
       "TEST" [super] = "SYS$USER1:[PROJ.TEST.ATEST]" (LNM$PROCESS_TABLE)

 5. To create another root-level directory on another device (presuming
    that you have VMS privileges necessary to do so), go to it, and create
    a logical for it:

    $ [1mMDIR SYS$USER2:[NEWPROJECT] NEWPROJ /GO /LOG[0m
    %CREATE-I-CREATED, SYS$USER2:[NEWPROJECT] created
      SYS$USER2:[NEWPROJECT]
    %MAKEDIR-I-GO, cd is SYS$USER2:[NEWPROJECT]
       "NEWPROJ" [super] = "SYS$USER2:[NEWPROJECT]" (LNM$PROCESS_TABLE)

    The /LOG qualifier causes CREATE /DIR to log a confirming message;
    the CD and MAKEDIR procedures report the new current director; and
    the new logical name value is reported.

    Note that any of the valid command qualifiers for CREATE /DIRECTORY
    are also valid for MAKEDIR (see help text above).

 6. To make a job-table logical name for the current directory, without
    creating a (sub)directory:

    $ [1mCD SYS$USER1:[PROJ][0m
      SYS$USER1:[PROJ] /JOB
    $ [1mMLOG PROJ[0m
        "PROJ" [super] = "SYS$USER1:[PROJ]" (LNM$JOB_TABLE)

 7. To define a logical name for a `project mirror' directory on another
    DECnet node (that is, a [PROJ] directory exists on a node named RUGER
    and is on the same device as your own login-directory on that node):

    $ [1mMLOG /REMOTE=RUGER[0m
      "R1" [super] = "RUGER::[PROJ]" (LNM$PROCESS_TABLE)

    Note that since no remote logical name was specified, the name R1
    was automatically generated.  Now, R1 can be used to manage files
    between this local SYS$USER1:[PROJ] directory and the `mirror'
    directory on node RUGER::.

    $ [1mCOPY THISFILE.COM R1 /LOG[0m
    %COPY-S-COPIED, SYS$USER1:[PROJ]THISFILE.COM;19 copied
    to RUGER::SYS$USER2:[PROJ]THISFILE.COM;19 (22 blocks)
    $ [1mDIR R1:THISFILE[0m

    Directory RUGER::SYS$USER2:[PROJ]

    THISFILE.COM;19       THISFILE.COM;18   ...

    Total of 2 files, 44 blocks.

    Note that since a remote logical name like R1 encodes an entire
    `node::dev:[dir.sub]' location, you must use a colon ":" to use
    the logical in another file-spec, e.g., "[1mR1[4m:[0m[1mTHISFILE.COM[0m"

 8. If the `project mirror' directory is on a remote disk which is not
    the same as that of your login directory, then you must specify the
    remote device on contains that remote directory.  This example also
    specifies a non-default remote logical name, and puts it in the /JOB
    logical name table:

    $ [1mCD [DOCS][0m
      SYS$USER1:[DOCS]
    $ [1mMLOG /REMOTE=(RUGER::[4mSYS$USER3:[0m[1m,[4mMIRROR[0m[1m,[4mJOB[0m[1m)[0m
        "MIRROR" [super] = "RUGER::SYS$USER3:[DOCS]" (LNM$JOB_TABLE)

 9. $ [1mMDIR [.TEST] TEST /GO /LOG /REMOTE=(RUGER::SYS$USER[4m3[0m[1m:,REMTEST)[0m
    %CREATE-I-CREATED, SYS$USER1:[DOCS.TEST] created
      SYS$USER1:[DOCS.TEST]
    %MAKEDIR-I-GO, cd is SYS$USER1:[DOCS.TEST]
      "TEST" [super] = "SYS$USER1:[DOCS.TEST]" (LNM$PROCESS_TABLE)
      "REMTEST" [super] = "RUGER::SYS$USER[4m3[0m:[DOCS.TEST]" (LNM$PROCESS_TABLE)

    Note that MAKEDIR does [4mnot[0m ensure that the remote `project mirror'
    directory actually exists; it is up to you (or a colleague) to do
    that and/or create the corresponding directory structures on that
    remote node if and as necessary.  MAKEDIR's /REMOTE qualifier only
    defines logical names (for reasons of practicality and complexity,
    CREATE /DIRECTORY will not create directories on a remote node).

$ !
$ GOTO Done
