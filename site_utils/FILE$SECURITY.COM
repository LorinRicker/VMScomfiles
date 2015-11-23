$ ! FILE$SECURITY.COM -- 
$ !                                                                'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1999-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  use: @FILE$SECURITY option [root_dir] [...]
$ !
$ !  where option can be one of:
$ !    DIRECTORY | TEST | SMARTMGR
$ !    FILES | FILEREMOVE
$ !    PROJECTACL | PROJREMOVE
$ !
$ !  if option = FILES
$ !    then    P2: Files (list) to protect
$ !            P3: Rights identifier (RID) required to access the directory
$ !            P4: Access to apply for that RID
$ !            P5: Owner UIC for the directory and all files
$ !            P6: File protection mask (under the ACL itself)
$ !
$ !  if option = PROJECTACL
$ !    then    P2: Root directory (defaults to Current/Default Directory)
$ !            P3: Rights identifier (RID) required to access the directory
$ !            P4: Access to apply for that RID
$ !            P5: Owner UIC for the directory and all files
$ !            P6: File protection mask (under the ACL itself)
$ !
$ !  if option = PROJREMOVE or FILEREMOVE
$ !    then no prompts or parameters
$ !
$ !  if option = SMARTMGR
$ !    then no prompts or parameters, except for the
$ !    root directory (which defaults to MGR$COMMAND:);
$ !    everything else defaults to values for SMART
$ !
$ ! NOTE: Don't put ACLs on shareable images (confuses image activation):
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ Util = "@site$utils:utility.com"
$ !
$ Util START SSA
$ Prv  = F$GETJPI("","CURPRIV")
$ Fac  = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ Here = F$ENVIRONMENT("DEFAULT")
$ !
$ VMSversion = F$EDIT(F$GETSYI("VERSION"),"TRIM,UPCASE")
$ IF VMSversion .LTS. "V6."
$ THEN SetProt = "SET FILE"             !VMS v5.x and older
$      SetACL  = "SET ACL"
$ ELSE SetProt = "SET SECURITY"         !new to VMS v6.x
$      SetACL  = "SET SECURITY"
$ ENDIF
$ !
$ SSA$Verbose == F$TRNLNM("TOOLS$Debug")     !generic Tools debug flag
$ wso = "WRITE sys$output"
$ !
$ IF P1 .EQS. "?" THEN GOTO Help
$ Util CMDPARSE "''P1'" Cmd "DIRECTORY" "DIRECTORY |FILES     |FILEREMOVE|PROJECTACL|PROJREMOVE|SMARTMGR  |TEST      "
$ !
$ GOTO P$'SSA$Cmd'
$P$SMARTMGR:
$ Prmpt = "SMART root directory ([1mmgr$command[0m)"
$ GOTO P2Loop
$P$DIRECTORY:
$P$TEST:
$P$PROJECTACL:
$P$PROJREMOVE:
$ Prmpt = "Root directory (''Here')"
$ GOTO P2Loop
$P$FILES:
$P$FILEREMOVE:
$ Prmpt = "Files"
$P2Loop:
$ IF P2 .EQS. ""
$ THEN READ sys$command P2 /END_OF_FILE=Done /PROMPT="''Prmpt': "
$      GOTO P2Loop
$ ENDIF
$ !
$ IF F$EXTRACT(0,4,SSA$Cmd) .EQS. "FILE"
$ THEN SSA$FList == P2
$      GOTO 'SSA$Cmd'
$ ENDIF
$Factor:
$ Util FactorDir "''P2'" "Dev,Dir,DirN,DirB,DirF,DTree,DExists,DLevl"
$ !                       1   2   3    4    5    6      7       8
$ GOTO 'SSA$Cmd'
$ !
$TEST:                ! Show/test a directory's parse/factoring; do nothing else
$ IF SSA$DExists
$ THEN tmp = "Yes"
$ ELSE tmp = "No"
$ ENDIF
$ wso ""
$ wso F$FAO("  full directory spec: [1m!AS[0m",SSA$DirF)
$ wso F$FAO("     directory exists? [1m!AS[0m",tmp)
$ wso F$FAO("  directory tree spec: !AS",SSA$DTree)
$ wso F$FAO("     number of levels: !SL",SSA$DLevl)
$ wso F$FAO("               device: !AS",SSA$Dev)
$ wso F$FAO("            directory: !AS",SSA$Dir)
$ wso F$FAO("       directory name: !AS",SSA$DirN)
$ wso F$FAO("        base (parent): !AS",SSA$DirB)
$ wso F$FAO("                input: !AS",P2)
$ wso ""
$ GOTO Done
$ !
$DIRECTORY:
$ wso "[1m"
$ DIRECTORY /SECURITY /SIZE /DATE 'SSA$DirF'
$ wso "[0m"
$ READ sys$command Answer /END_OF_FILE=Done -
     /PROMPT="Examine security for ''SSA$DTree'*.*;0 ([1mY[0mes/No/Page)? "
$ Answer = F$EXTRACT(0,1,F$PARSE(Answer,"Yes",,"NAME","SYNTAX_ONLY"))
$ IF ( Answer .EQS. "Y" ) .OR. ( Answer .EQS. "P" )
$ THEN IF F$SEARCH("''SSA$DTree'*.*;0") .NES. ""
$      THEN IF ( Answer .EQS. "P" )
$           THEN DIRECTORY /SECURITY /SIZE /DATE 'SSA$DTree'*.*;0 /PAGE=SAVE
$           ELSE DIRECTORY /SECURITY /SIZE /DATE 'SSA$DTree'*.*;0
$           ENDIF
$      ELSE wso "%''Fac'-I-NO_FILES, no files found in ''SSA$DTree'"
$      ENDIF
$ ENDIF
$ GOTO Done
$ !
$FILES:
$ IF VMSversion .GES. "V6."
$ THEN READ sys$command Answer /END_OF_FILE=Done -
         /PROMPT="Selectively (with /CONFIRM) (y/[1mN[0m)? "
$      IF F$PARSE(Answer,"Yes",,"NAME","SYNTAX_ONLY")
$      THEN Conf = "/CONFIRM"
$      ELSE Conf = ""
$      ENDIF
$ ENDIF
$ !
$File0:
$ CALL Parameter "''P3'" "SSA$Ident" "Rights identifier"
$ IF F$IDENTIFIER(SSA$Ident,"NAME_TO_NUMBER") .EQ. 0
$ THEN wso "%''Fac'-E-NO_RIGHTS_ID, rights identifier [1m''SSA$Ident'[0m does not exist"
$      GOTO File0
$ ENDIF
$ !
$ DefAccess = "READ+WRITE+DELETE"
$ CALL Parameter "''P4'" "SSA$Access" "Identifier access" "''DefAccess'"
$ IF SSA$Access .EQS. ""
$ THEN SSA$Access == DefAccess
$ ELSE SSA$Access == SSA$Access - "(" - ")"
$      Util REPLACE "''SSA$Access'" "Access" "," "+"
$ ENDIF
$ !
$ DefUIC = "SYSTEM"
$ CALL Parameter "''P5'" "SSA$OwnerUIC"   "Owner" "''DefUIC'"
$ IF SSA$OwnerUIC .EQS. ""
$ THEN SSA$OwnerUIC == DefUIC
$ ELSE SSA$OwnerUIC == SSA$OwnerUIC - "[" - "]"
$ ENDIF
$ !
$ DefFPMask = "S:RWED,O:RWED,G,W"
$ CALL Parameter "''P6'" "SSA$FPMask" "File protection mask" "''DefFPMask'"
$ IF SSA$FPMask .EQS. ""
$ THEN SSA$FPMask == DefFPMask
$ ELSE SSA$FPMask == SSA$FPMask - "(" - ")"
$      Util REPLACE "''SSA$FPMask'" "FPMask" "+" ","
$ ENDIF
$ !
$ IF VMSversion .LTS. "V6."
$ THEN SetProt 'SSA$FList' /OWNER='SSA$OwnerUIC' /PROTECTION=('SSA$FPMask')
$      SetACL 'SSA$FList' -
          /ACL=(IDENTIFIER='SSA$Ident', ACCESS='SSA$Access')
$ ELSE SetACL 'SSA$FList' 'Conf' -
          /ACL=(IDENTIFIER='SSA$Ident', ACCESS='SSA$Access') -
          /OWNER='SSA$OwnerUIC' /PROTECTION=('SSA$FPMask')
$ ENDIF
$ GOTO Done
$ !
$FILEREMOVE:
$ READ sys$command Answer /END_OF_FILE=Done -
    /PROMPT="Selectively (with /CONFIRM) (y/[1mN[0m)? "
$ IF F$PARSE(Answer,"No",,"NAME","SYNTAX_ONLY")
$ THEN Conf = "/CONFIRM"
$ ELSE Conf = ""
$ ENDIF
$ SetACL 'SSA$FList' 'Conf' /ACL /DELETE=ALL
$ GOTO Done
$ !
$PROJECTACL:
$ Prv  = F$SETPRV("SYSPRV,BYPASS")
$Proj0:
$ CALL Parameter "''P3'" "SSA$Ident" "Rights identifier"
$ IF F$IDENTIFIER(SSA$Ident,"NAME_TO_NUMBER") .EQ. 0
$ THEN wso "%''Fac'-E-NO_RIGHTS_ID, rights identifier [1m''SSA$Ident'[0m does not exist"
$      GOTO Proj0
$ ENDIF
$ !
$ DefAccess = "READ+WRITE+DELETE"
$ CALL Parameter "''P4'" "SSA$Access" "Identifier access" "''DefAccess'"
$ IF SSA$Access .EQS. ""
$ THEN SSA$Access == DefAccess
$ ELSE SSA$Access == SSA$Access - "(" - ")"
$      Util REPLACE "''SSA$Access'" "Access" "," "+"
$ ENDIF
$ !
$ DefUIC = "SYSTEM"
$Proj1:
$ CALL Parameter "''P5'" "SSA$OwnerUIC"   "Owner" "''DefUIC'"
$ IF SSA$OwnerUIC .EQS. ""
$ THEN SSA$OwnerUIC == DefUIC
$ ELSE SSA$OwnerUIC == SSA$OwnerUIC - "[" - "]"
$ ENDIF
$ IF F$IDENTIFIER(SSA$OwnerUIC,"NAME_TO_NUMBER") .EQ. 0
$ THEN wso "%''Fac'-E-NO_RIGHTS_ID, UIC [1m''SSA$OwnerUIC'[0m does not exist"
$      GOTO Proj1
$ ENDIF
$ !
$ DefFPMask = "S:RWED,O:RWED,G,W"
$ CALL Parameter "''P6'" "SSA$FPMask" "File protection mask" "''DefFPMask'"
$ IF SSA$FPMask .EQS. ""
$ THEN SSA$FPMask == DefFPMask
$ ELSE SSA$FPMask == SSA$FPMask - "(" - ")"
$      Util REPLACE "''SSA$FPMask'" "FPMask" "+" ","
$ ENDIF
$ !
$ DirAccess = SSA$Access - "+DELETE"
$ DirMask = "S:RWE,O:RWE"
$ I = 0
$ProjLoop:
$ M = F$ELEMENT(I,",",SSA$FPMask)
$ IF M .NES. ","
$ THEN C = F$EXTRACT(0,1,M)
$      IF ( C .EQS. "G" ) .OR. ( C .EQS. "W" )
$      THEN P = F$ELEMENT(1,":",M)
$           IF P .NES. ":"
$           THEN IF F$LOCATE("W",P) .LT. F$LENGTH(P)
$                THEN DirMask = DirMask + "," + C + ":RWE"
$                ELSE DirMask = DirMask + "," + C + ":RE"
$                ENDIF
$           ELSE DirMask = DirMask + "," + C
$           ENDIF
$      ENDIF
$ ENDIF
$ IF I .LE. 3
$ THEN I = I + 1
$      GOTO ProjLoop
$ ENDIF
$ GOTO Set$Protection
$ !
$SMARTMGR:
$ !Mostly default values:
$ SSA$Ident    == "MANAGER"  !SMART's system manager RID
$ SSA$Access   == "READ+WRITE+DELETE"
$ SSA$OwnerUIC == "SYSTEM"
$ SSA$FPMask   == "S:RWED,O:RWED,G,W"
$ DirAccess = SSA$Access - "+DELETE"
$ DirMask = "S:RWE,O:RWE"
$ GOTO Set$Protection
$ !
$SET$PROTECTION:
$ ! Protection mask and ACL access for users of this directory:
$ wso ""
$ SetProt 'SSA$DirF' /OWNER='SSA$OwnerUIC' /PROTECTION=('DirMask') /LOG
$ SetACL 'SSA$DirF' -
    /ACL=(IDENTIFIER='SSA$Ident', ACCESS='DirAccess')
$ !
$ ! Default ACL access & protection mask for files created in this directory:
$ SetACL 'SSA$DirF' -
    /ACL=(DEFAULT_PROTECTION,'SSA$FPMask')
$ SetACL 'SSA$DirF' -
    /ACL=(IDENTIFIER='SSA$Ident', OPTIONS=DEFAULT, ACCESS='SSA$Access')
$ !
$ wso ""
$ wso "  [1mApply[0m ACL (''SSA$Ident': ''SSA$Access), ownership (''SSA$OwnerUIC'),"
$ wso "    and file protection mask (''SSA$FPMask')"
$ READ sys$command Answer /END_OF_FILE=Done -
    /PROMPT="    to all files in ''SSA$DTree' ([1mY[0m/n)? "
$ Answer = F$PARSE(Answer,"Yes",,"NAME","SYNTAX_ONLY")
$ IF Answer
$ THEN wso ""
$      wso "%''Fac'-I-SET_PROT, setting protections; please wait..."
$      SetACL /DEFAULT 'SSA$DTree'*.*;*
$      wso "                           ...done"
$ ENDIF
$ GOTO Directory
$ !
$PROJREMOVE:
$ Prv  = F$SETPRV("SYSPRV,BYPASS")
$ !
$ wso ""
$ SetACL 'SSA$DirF' /ACL /DELETE=ALL /LOG
$ !
$ wso ""
$ wso "  [1mRemove[0m all ACLs (but retain current file ownership and protection mask)"
$ READ sys$command Answer /END_OF_FILE=Done -
    /PROMPT="    from all files in ''SSA$DTree' ([1mY[0m/n)? "
$ Answer = F$PARSE(Answer,"No",,"NAME","SYNTAX_ONLY")
$ IF Answer
$ THEN wso ""
$      wso "%''Fac'-I-SET_PROT, removing ACLs; please wait..."
$      SetACL /DEFAULT 'SSA$DTree'*.*;*
$      wso "                           ...done"
$ ENDIF
$ GOTO Directory
$ !
$Done:
$ SET NOON
$ Prv = F$SETPRV(Prv)
$ Util EXIT SSA
$ EXIT
$ !
$ !
$HELP:
$ TYPE /PAGE sys$input

  use: [1m@FILE$SECURITY option [root_dir] [...][0m

  where [1moption[0m can be one of:

    DIRECTORY  -- Displays a DIRECTORY /SECURITY listing for files.

    FILES      -- Sets an ACL, protection mask and ownership on files.

    FILEREMOVE -- Removes an ACL from files (without removing protection
                  mask or ownership).

    PROJECTACL -- Establishes an ACL, protection mask and ownership scheme
                  for a root (project) directory, and all files and sub-
                  directories within that tree.

    PROJREMOVE -- Removes an ACL from a root (project) directory and all
                  files and subdirectories within that tree, but does not
                  remove protection masks or file ownership.

    SMARTMGR   -- Establishes ACL, protection mask and file ownership
                  suitable for system management files (as in E&R SMART),
                  i.e., using RID = MANAGER, (S:RWED,O:RWED,G,W) mask,
                  and [SYSTEM] UIC for all files and subdirectories in
                  the tree.

    TEST       -- Tests the directory factoring algorithm, displays results.

  You will be prompted for additional parameters based on [1moption[0m; however,
  parameters can also be specified on the command line as follows:

  If option = [1mFILES[0m
    then    P2: Files (list) to protect
            P3: Rights identifier (RID) required to access the directory
            P4: Access to apply for that RID
            P5: Owner UIC for the directory and all files
            P6: File protection mask (under the ACL itself)

  If option = [1mPROJECTACL[0m
    then    P2: Root directory (defaults to Current/Default Directory)
            P3: Rights identifier (RID) required to access the directory
            P4: Access to apply for that RID
            P5: Owner UIC for the directory and all files
            P6: File protection mask (under the ACL itself)

  If option = [1mPROJREMOVE[0m or [1mFILEREMOVE[0m
    then no prompts or parameters

  If option = [1mDIRECTORY[0m or [1mTEST[0m
    then no prompts or parameters

  If option = [1mSMARTMGR[0m
    then no prompts or parameters, except for the
    root directory (which defaults to MGR$COMMAND:);
    everything else defaults to values for SMART

   NOTE: Don't put ACLs on shareable images (confuses image activation).

$ !
$ GOTO Done
$ !
$ !
$Parameter:  SUBROUTINE
$ ! P1: input value to assign, prompt if this is null
$ ! P2: global symbol to assign value
$ ! P3: prompt text
$ ! P4: default value
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN EXIT $STATUS
$ParLoop:
$ IF P1 .NES. ""
$ THEN 'P2' == F$EDIT(P1,"COMPRESS,TRIM,UPCASE")
$      EXIT 1
$ ELSE def = ""
$      IF P4 .NES. "" THEN def = " (" + P4 + ")"
$      READ sys$command P1 /END_OF_FILE=ParDone /PROMPT="''P3'''def': "
$      IF ( P1 .EQS. "" ) .AND. ( P4 .NES. "" ) THEN P1 = P4
$      GOTO ParLoop
$ ENDIF
$ParDone:
$ 'P2' == ""
$ EXIT %X2C      !signal abort to main...
$ ENDSUBROUTINE  ! Parameter
$ !
$Ctrl_Y:
$ RETURN %X2C
