$ ! TPU.COM -- defines KED/TTK editor environment                  'F$VERIFY(0)'
$ !
$ !  This program is the confidential and proprietary product of
$ !  Lorin Ricker.  Any unauthorized use, reproduction or transfer
$ !  of this program is strictly prohibited.
$ !
$ !  Copyright © 2000-2015 by Lorin Ricker, Inc.  All rights reserved.
$ !  Copyright © 1986-2000 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ ! P1: [ "" | "EVE" ] for TPU$SECTION
$ ! P2: [ "" | "KJ" | "BJ" ] for KED$JOURNAL
$ ! P3: [ "" | "VT" | "PC" | "PCDECW" ] for KED$KEYBOARD
$ !
$ LBase = F$TRNLNM("sys$login_device") -
        + "[" + F$EDIT(F$GETJPI("","USERNAME"),"TRIM")
$ Architecture = F$EDIT(F$GETSYI("ARCH_NAME"),"UPCASE,TRIM")
$ !
$ DEFINE = "DEFINE /JOB /NOLOG "
$ DEFINE tpu$src   'Lbase'.$tpu]
$ DEFINE ked$utils 'F$TRNLNM("tpu$src")',site$utils
$ DEFINE tpu$section ked$section  !for MAIL, etc.
$ DEFINE ked$src   site$sources:[ked]
$ DEFINE tpu$arc   'Lbase'.$tpu.arc]
$ !
$ DEFINE tpu$character_set ISO_LATIN1   !instead of DEC_MCS
$ !
$ IF ( F$EDIT(P1,"UPCASE") .EQS. "EVE" )
$ THEN eve = 1
$      DEASSIGN /NOLOG /JOB tpu$section  ! revert to system logical
$      DEFINE eve$init    sys$login:eve$init.ini
$      DEFINE ked$section eve$section
$      GOTO Common
$ ELSE eve = 0
$ ENDIF
$ !
$ ln = "ked$journal"
$ IF ( P2 .NES. "" )
$ THEN DEFINE 'ln' 'P2'
$ ELSE IF F$TRNLNM(ln,"LNM$JOB") .NES. "" THEN DEASSIGN /JOB 'ln'
$ ENDIF
$ ln = "ked$keyboard"
$ IF ( P3 .NES. "" )
$ THEN DEFINE 'ln' 'P3'
$ !!! ELSE IF F$TRNLNM(ln,"LNM$JOB") .NES. "" THEN DEASSIGN /JOB 'ln'
$ ENDIF
$ !
$ IF F$SEARCH("com:ked.com") .NES. ""
$ THEN ed == "@com:ked.com"
$ ELSE ed == "KED"
$ ENDIF
$ bed == "@tpu$src:ttk$build.com"
$ ro  == "KED /NOSYMBOL /READONLY"

$ sec =  "tpu$src:ttk.tpu$section"
$ IF F$SEARCH(sec) .NES. ""
$ THEN DEFINE ked$section 'sec'
$      GOTO Arch
$ ELSE GOTO Ked
$ ENDIF
$ !
$Ked:
$ IF F$SEARCH("site$utils:ked.tpu$section") .EQS. "" THEN GOTO No_Ed
$ sec = ""
$Done:
$ IF sec .EQS. ""
$ THEN IF F$TRNLNM("ked$section","LNM$JOB") .NES. ""
$      THEN DEASSIGN /JOB ked$section
$      ENDIF
$      sec = "site$utils:ked.tpu$section"
$ ELSE DEFINE ked$section 'sec'
$ ENDIF
$ !
$Arch:
$ IF Architecture .NES. "ALPHA"
$ THEN ! Fallback for when we don't have the right kind of KED*.EXE's:
$      sec  = "tpu$src:tpk.tpu$section"
$      KED == "EDIT /TPU /SECTION=ked$section"
$ ENDIF
$ !
$Common:
$ IF .NOT. eve
$ THEN Term = F$GETJPI("","TERMINAL")
$      IF F$LOCATE("FTA",Term) .LT. F$LENGTH(Term)
$      THEN Keyboard = "PC"
$      ELSE wso ""
$           !! READ sys$command Keyboard /END_OF_FILE=Done /PROMPT="Keyboard ([1mP[0mC,[1mD[0mECWPC,[1mV[0mT) <P>? "
$           READ sys$command Keyboard /END_OF_FILE=Done /PROMPT="Keyboard ([1mP[0mC,[1mV[0mT) <P>? "
$           Keyboard = F$PARSE(Keyboard,"P",,"NAME","SYNTAX_ONLY")
$           !! IF Keyboard .EQS. "D" THEN Keyboard = "PCDECW"
$           IF Keyboard .EQS. "P" THEN Keyboard = "PC"
$           IF Keyboard .EQS. "V" THEN Keyboard = "VT"
$      ENDIF
$      IF F$TRNLNM("RMG$Keyboard","lnm$system") .NES. Keyboard THEN DEFINE /JOB /NOLOG RMG$Keyboard 'Keyboard'
$      IF F$TRNLNM("KED$Keyboard","lnm$system") .NES. Keyboard THEN DEFINE /JOB /NOLOG KED$Keyboard 'Keyboard'
$      Keyboard = " (''F$TRNLNM("ked$keyboard")')"
$ ELSE Keyboard = ""
$ ENDIF
$ !
$ WRITE sys$output ""
$ WRITE sys$output "%TPU-I-KED, editor: [1m''F$TRNLNM("ked$section")'[0m''Keyboard'"
$ EXIT
$ !
$No_Ed:
$ WRITE sys$error "%TPU-W_NOKED, no editor established"
$ EXIT
