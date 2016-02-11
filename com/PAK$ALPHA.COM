$ ! PAK$ALPHA.COM                                           'F$VERIFY(0)'
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
$ !   usage:  @PAK$arch [ TEST | CONFIRM ]...
$ !
$ !   where:  T[EST] means to run comfile in test-mode:
$ !             LICENSE REGISTER, DISABLE, UNLOAD, ENABLE and LOAD
$ !             commands are echoed only, not actually applied;
$ !             also, the architecture test (are we executing this
$ !             on the right kind of VMS system: IA64, ALPHA or VAX?)
$ !             is skipped, just so that echoing will always display
$ !             regardless of system type).
$ !           C[ONFIRM] means to ask/confirm before applying or echo-
$ !             displaying each license/PAK.
$ !           Note that only the first letter "T" or "C" is needed to
$ !           invoke these options, case-insensitive, and that these
$ !           options can appear in either order.
$ !
$ ! ====== Main ======
$ ON ERROR   THEN EXIT
$ ON CONTROL THEN EXIT
$ !
$ CommonProc = "PAK$REGISTER.COM"
$ !
$ Fac      = F$ENVIRONMENT("PROCEDURE")
$ Fdd      = F$PARSE(Fac,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(Fac,,,"DIRECTORY","SYNTAX_ONLY")
$ Fnam     = F$PARSE(Fac,,,"NAME","SYNTAX_ONLY")
$ Proc     = F$PARSE(CommonProc,Fdd,F$ENVIRONMENT("DEFAULT"))
$ Proc     = Proc - ".COM" - F$PARSE(Proc,,,"VERSION","SYNTAX_ONLY")
$ PAK$Reg == "@''Proc'"
$ !
$ PAK$Reg STARTUP  "''P1'" "''P2'"
$ !
$ PAK$Reg ARCHTEST "''FNam'"
$ ! If ARCHTEST triggers an abort (%X2C), we'll head straight to Done for CLEANUP and exit
$ !
$ ON ERROR   THEN GOTO Done
$ ON CONTROL THEN GOTO Done
$ !
$ !
$ ! ==================================================================================
$ ! --- Edit Section ---
$ ! --- Manually update the values below for each new set of PAKs as issued:
$ ! --- Note: These are global symbols, but are deleted at end of procedure.
$ !
$ ! These values change with each release... edit/fix them:
$ PAK$AuthNo          == "-130531"
$ PAK$Authorization   == "INTERNAL-VAX-ALPHA-PAKS''PAK$AuthNo'"
$ PAK$TerminationDate == "31-JUL-2013"
$ !
$ ! These values are relatively common, constant & stable for most HP-issued PAKs;
$ ! any override values should be provided in a particular PAK$Reg-call parameter:
$ PAK$Issuer       == "DEC"
$ PAK$Producer     == "DEC"
$ PAK$Units        == "0"
$ !
$ ! Default values here must be "plugged-in" explicitly into PAK$Reg-call parameters:
$ PAK$Activity     == "CONSTANT=100"
$ PAK$Availability == PAK$Nil
$ PAK$Options      == PAK$Nil
$ PAK$HardwareID   == PAK$Nil
$ PAK$ReleaseDate  == PAK$Nil
$ PAK$Token        == PAK$Nil
$ PAK$Version      == PAK$Nil
$ !
$ ! ==================================================================================
$ ! === Register individual PAKs ===
$ ! Prototype:
$ !   $ PAK$Reg "ProductName" "Checksum" "Authorization" "Units" -       ! P1,P2,P3,P4
$ !             "TerminationDate|ReleaseDate" "Activity|Availability" -  ! P5,P6
$ !             "KeyOptions|HardwareID|Token|Version" "Issuer|Producer"  ! P7,P8
$ !
$ ! Parameters -- Specify P1 and P2 for each product/license (different for each PAK).
$ !               Specify P3 and P4 only if different from globals, else let 'em default.
$ !               Specify P5 thru P8 explicitly for each value-component -- for each of
$ !               these parameter components, "" (or PAK$Nil) means that the LICENSE
$ !               qualifier is not generated...
$ !
$ PAK$Reg "OPENVMS-ALPHA-USER" "2-KLCI-ONEC-BBME-LHFA" "" "" -
         "''PAK$TerminationDate'" "''PAK$Activity'"
$ !
$ PAK$Reg "PASCAL" "2-FCMF-CNKJ-JIBG-DLMF" "" "" -
         "''PAK$TerminationDate'" "''PAK$Activity'"
$ !
$ PAK$Reg "PASCAL-USER" "2-GGDF-MDBD-CJKF-CKBH" "" "" -
         "''PAK$TerminationDate'" "''PAK$Activity'"
$ !
$!!$ PAK$Reg "ABS-CLIENT-ALPHA" "2-LPAI-NLIH-OEDL-KNGK" "" "" -
$!!         "''PAK$TerminationDate'" "''PAK$Activity'"
$!!$ !
$!!$ PAK$Reg "ACMS-RT" "2-EKNA-LLBJ-BMHF-LKNO" "" "" -
$!!         "''PAK$TerminationDate'" "''PAK$Activity'"
$!!$ !
$!!$ PAK$Reg "DFG" "2-EJLB-PIJB-NEHI-BPPF" "" "" -
$!!         "''PAK$TerminationDate'" "''PAK$Activity'"
$!!$ !
$!!$ PAK$Reg "FORMS-RT" "2-PJDF-LFNI-HECO-GPHB" "" "" -
$!!         "''PAK$TerminationDate'" "''PAK$Activity'"
$ !
$ ! ==================================================================================
$Done:  ! Cleanup...
$ PAK$Reg CLEANUP
$ EXIT
