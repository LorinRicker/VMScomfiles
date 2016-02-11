$ ! PAK$REGISTER.COM -- Workhorse callable routines for PAK$*.COM  'F$VERIFY(0)'
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
$DoLicense: SUBROUTINE
$ !   P1 : ProductName     (no default)
$ !   P2 : Checksum        (no default)
$ !
$ ! Data-coupled to callers by global symbols PAK$*:
$ !   P3 : Authorization   (default = PAK$Authorization)
$ !   P4 : Units           (default = PAK$Units)
$ !
$ ! Each of the following must have its value explicitly provided:
$ !   P5 : TerminationDate|ReleaseDate
$ !   P6 : Activity|Availability
$ !   P7 : KeyOptions|HardwareID|Token|Version
$ !   P8 : Issuer|Producer
$ !
$ wso = "WRITE sys$output"
$ !
$ PNam = P1
$ Cksm = P2
$ !
$ ! Defaults:
$ IF P3 .EQS. ""
$ THEN Auth = PAK$Authorization
$ ELSE Auth = P3
$ ENDIF
$ IF Auth .NES. PAK$Nil
$ THEN QAuth = "/AUTHORIZATION=''Auth'"
$ ELSE QAuth = ""
$ ENDIF
$ !
$ IF P4 .EQS. ""
$ THEN Unit = PAK$Units
$ ELSE Unit = P4
$ ENDIF
$ IF Unit .NES. PAK$Nil
$ THEN QUnit = "/UNITS=''Unit'"
$ ELSE QUnit = ""
$ ENDIF
$ !
$ IF P5 .NES. ""
$ THEN Q0 = F$ELEMENT(0,PAK$Sep,P5)
$      IF ( Q0 .EQS. "" ) .OR. ( Q0 .EQS. PAK$Sep )
$      THEN Term = PAK$TerminationDate
$      ELSE Term = Q0
$      ENDIF
$      Q1 = F$ELEMENT(1,PAK$Sep,P5)
$      IF ( Q1 .EQS. "" ) .OR. ( Q1 .EQS. PAK$Sep )
$      THEN Rele = PAK$ReleaseDate
$      ELSE Rele = Q1
$      ENDIF
$ ELSE Term = PAK$Nil
$      Rele = PAK$Nil
$ ENDIF
$ IF Term .NES. PAK$Nil
$ THEN QTerm = "/TERMINATION_DATE=''Term'"
$ ELSE QTerm = ""
$ ENDIF
$ IF Rele .NES. PAK$Nil
$ THEN QRele = "/RELEASE_DATE=''Rele'"
$ ELSE QRele = ""
$ ENDIF
$ !
$ IF P6 .NES. ""
$ THEN Q0 = F$ELEMENT(0,PAK$Sep,P6)
$      IF ( Q0 .EQS. "" ) .OR. ( Q0 .EQS. PAK$Sep )
$      THEN Acti = PAK$Activity
$      ELSE Acti = Q0
$      ENDIF
$      Q1 = F$ELEMENT(1,PAK$Sep,P6)
$      IF ( Q1 .EQS. "" ) .OR. ( Q1 .EQS. PAK$Sep )
$      THEN Avai = PAK$Availability
$      ELSE Avai = Q1
$      ENDIF
$ ELSE Acti = PAK$Nil
$      Avai = PAK$Nil
$ ENDIF
$ IF Acti .NES. PAK$Nil
$ THEN QActi = "/ACTIVITY=''Acti'"
$ ELSE QActi = ""
$ ENDIF
$ IF Avai .NES. PAK$Nil
$ THEN QAvai = "/AVAILABILITY=''Avai'"
$ ELSE QAvai = ""
$ ENDIF
$ !
$ IF P7 .NES. ""
$ THEN Q0 = F$ELEMENT(0,PAK$Sep,P7)
$      IF ( Q0 .EQS. "" ) .OR. ( Q0 .EQS. PAK$Sep )
$      THEN Opti = PAK$Options
$      ELSE Opti = Q0
$      ENDIF
$      Q1 = F$ELEMENT(1,PAK$Sep,P7)
$      IF ( Q1 .EQS. "" ) .OR. ( Q1 .EQS. PAK$Sep )
$      THEN HwID = PAK$HardwareID
$      ELSE HwID = Q1
$      ENDIF
$      Q2 = F$ELEMENT(2,PAK$Sep,P7)
$      IF ( Q2 .EQS. "" ) .OR. ( Q2 .EQS. PAK$Sep )
$      THEN Toke = PAK$Token
$      ELSE Toke = Q2
$      ENDIF
$      Q3 = F$ELEMENT(3,PAK$Sep,P7)
$      IF ( Q3 .EQS. "" ) .OR. ( Q3 .EQS. PAK$Sep )
$      THEN Vers = PAK$Version
$      ELSE Vers = Q3
$      ENDIF
$ ELSE Opti = PAK$Nil
$      HwID = PAK$Nil
$      Toke = PAK$Nil
$      Vers = PAK$Nil
$ ENDIF
$ IF Opti .NES. PAK$Nil
$ THEN QOpti = "/OPTIONS=(''Opti')"
$ ELSE QOpti = ""
$ ENDIF
$ IF HwID .NES. PAK$Nil
$ THEN QHwID = "/HARDWARE_ID=''HwID'"
$ ELSE QHwID = ""
$ ENDIF
$ IF Toke .NES. PAK$Nil
$ THEN QToke = "/TOKEN=''Toke'"
$ ELSE QToke = ""
$ ENDIF
$ IF Vers .NES. PAK$Nil
$ THEN QVers = "/VERSION=''Vers'"
$ ELSE QVers = ""
$ ENDIF
$ ! 
$ IF P8 .EQS. ""           ! Assert: There are always both an Issuer and a Producer...
$ THEN Issu = PAK$Issuer
$      Prod = PAK$Producer
$ ELSE Q0 = F$ELEMENT(0,PAK$Sep,P8)
$      IF ( Q0 .EQS. "" ) .OR. ( Q0 .EQS. PAK$Sep )
$      THEN Issu = PAK$Issuer
$      ELSE Issu = Q0
$      ENDIF
$      Q1 = F$ELEMENT(1,PAK$Sep,P8)
$      IF ( Q1 .EQS. "" ) .OR. ( Q1 .EQS. PAK$Sep )
$      THEN Prod = PAK$Producer
$      ELSE Prod = Q1
$      ENDIF
$ ENDIF
$ QIssu = "/ISSUER=''Issu'"
$ QProd = "/PRODUCER=''Prod'"
$ !
$ IF PAK$Test
$ THEN wso "%PAK$REGISTER-I-ECHO, verifying commands:"
$      wso "  $ LICENSE REGISTER ''PNam' ''QIssu' ''QProd' -"
$      IF ( QAuth .NES. "" ) .OR. ( QUnit .NES. "" ) .OR. ( QTerm .NES. "" ) -
       THEN wso "      ''QAuth' ''QUnit' ''QTerm' -"
$      IF ( QActi .NES. "" ) .OR. ( QAvai .NES. "" ) .OR. ( QHwID .NES. "" ) -
       THEN wso "      ''QActi' ''QAvai' ''QHwID' -"
$      IF ( QToke .NES. "" ) .OR. ( QOpti .NES. "" ) .OR. ( QVers .NES. "" ) -
       THEN wso "      ''QToke' ''QOpti' ''QVers' -"
$      wso "      /CHECKSUM=''Cksm'"
$      wso "  $ LICENSE {DISABLE,UNLOAD,ENABLE} ''PNam' /NOLOG ..."
$      wso "  $ LICENSE LOAD ''PNam' /LOG ''QProd'"
$      wso ""
$ ELSE ! Register and (re)load the license:
$      LICENSE REGISTER 'PNam' 'QIssu' 'QProd' 'QAuth' -
         'QUnit' 'QTerm' 'QActi' 'QAvai' 'QHwID' 'QToke' 'QOpti' 'QVers' -
         /CHECKSUM='Cksm'
$ !
$      LICENSE DISABLE 'PNam' /NOLOG 'QProd' /ALL
$      LICENSE UNLOAD  'PNam' /NOLOG 'QProd'
$      LICENSE ENABLE  'PNam' /NOLOG 'QProd' 'QAuth'
$      LICENSE LOAD    'PNam' /LOG   'QProd'
$ ENDIF
$ EXIT %X01
$ ENDSUBROUTINE  !DoLicense
$ !
$Startup: SUBROUTINE
$ ! P1 = TEST|CONFIRM
$ ! P2 = CONFIRM|TEST
$ !
$ P1 = F$EDIT(F$EXTRACT(0,1,P1),"UPCASE,COLLAPSE")
$ P2 = P2 - "/"
$ P2 = F$EDIT(F$EXTRACT(0,1,P2),"UPCASE,COLLAPSE")
$ PAK$Test    == ( P1 .EQS. "T" ) .OR. ( P2 .EQS. "T" )  ! T[EST]?
$ PAK$Confirm == ( P1 .EQS. "C" ) .OR. ( P2 .EQS. "C" )  ! C[ONFIRM]?
$ !
$ ! Working globals:
$ PAK$Sep == "|"
$ PAK$Nil == "!EMPTY!"
$ EXIT %X01
$ ENDSUBROUTINE  ! Startup
$ !
$ArchTest: SUBROUTINE
$ ! P1 = Calling_FileName (which includes the hw-architecture)
$ !
$ wso = "WRITE sys$output"
$ !
$ FArch = F$ELEMENT(1,"$",P1)    ! Second field from "PAK$arch" or "PAK$arch$env"
$ Arch  = F$GETSYI("ARCH_NAME")  ! What are we actually running on?
$ IF ( .NOT. PAK$Test )          ! Skip arch-test if we're TESTing...
$ THEN IF ( FArch .NES. Arch )
$      THEN msg  = "%''P1'-E-WRONGARCH,"
$           msgl = F$LENGTH(msg)
$           wso "''msg' these PAKs are for ''FArch' only;"
$           wso F$FAO("!#*  cannot apply !AS PAKs on VMS/!AS ...aborting", -
                       msgl, FArch, Arch)
$           EXIT %X2C  ! Abort: Ctrl/Y
$      ENDIF
$ ENDIF
$ PAK$Proc == P1
$ EXIT %X01
$ ENDSUBROUTINE  ! ArchTest
$ !
$Cleanup: SUBROUTINE
$ ! Destroy all PAK$* global symbols:
$ delsym = "DELETE /SYMBOL /GLOBAL"
$ !
$ delsym PAK$Activity
$ delsym PAK$Authorization
$ delsym PAK$Availability
$ delsym PAK$HardwareID
$ delsym PAK$Issuer
$ delsym PAK$Producer
$ delsym PAK$Options
$ delsym PAK$ReleaseDate
$ delsym PAK$TerminationDate
$ delsym PAK$Token
$ delsym PAK$Units
$ delsym PAK$Version
$ !
$ delsym PAK$Sep
$ delsym PAK$Nil
$ delsym PAK$AuthNo
$ delsym PAK$Test
$ delsym PAK$Confirm
$ !
$ delsym PAK$Proc
$ delsym PAK$Reg
$ !
$ EXIT %X01
$ ENDSUBROUTINE  ! Cleanup
$ !
$ !
$ ! ===== Main Dispatch =====
$ !
$ ! Called as:
$ ! $ @RegPak "ProductName" "Checksum" "Authorization" "Units" "TerminationDate|ReleaseDate" -
$ !           "Activity|Availability" "KeyOptions|HardwareID|Token|Version" "Issuer|Producer"
$ !
$ ! or as a dispatch to a service routine: STARTUP, ARCHTEST, CLEANUP
$ !
$ ! ...so just dispatch parameters to subroutine:
$ !
$ IF   ( P1 .EQS. "STARTUP" )  -
  .OR. ( P1 .EQS. "ARCHTEST" ) -
  .OR. ( P1 .EQS. "CLEANUP" )
$ THEN CALL 'P1' "''P2'" "''P3'" "''P4'"
$      EXIT $STATUS
$ ELSE CONTINUE
$ ENDIF
$ !
$ DoIt = "Yes"
$ IF PAK$Confirm
$ THEN READ /END_OF_FILE=PRDone /PROMPT="Register license ""''P1'"" (Y/n)? " sys$command Ans
$      DoIt = F$PARSE(Ans,"Yes",,"NAME","SYNTAX_ONLY")
$ ENDIF
$ !
$ IF DoIt THEN CALL DoLicense "''P1'" "''P2'" "''P3'" "''P4'" "''P5'" "''P6'" "''P7'" "''P8'"
$ !
$ EXIT %X01
$ !
$PRDone:
$ WRITE sys$output "%''PAK$Proc'-E-ABORT, user-requested abort..."
$ EXIT %X2C
