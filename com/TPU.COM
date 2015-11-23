$ ! TPU.COM -- defines KED/TTK editor environment                  'F$VERIFY(0)'
$ !
$ ! P1: [ "" | "KJ" | "BJ" ] for KED$JOURNAL
$ ! P2: [ "" | "VT" | "PC" | "PCDECW" ] for KED$KEYBOARD
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
$ ln = "ked$journal"
$ IF ( P1 .NES. "" )
$ THEN DEFINE 'ln' 'P1'
$ ELSE IF F$TRNLNM(ln,"LNM$JOB") .NES. "" THEN DEASSIGN /JOB 'ln'
$ ENDIF
$ ln = "ked$keyboard"
$ IF ( P2 .NES. "" )
$ THEN DEFINE 'ln' 'P2'
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
$ WRITE sys$error "%TPU-I-KED, editor: [1m",F$TRNLNM("ked$section"), -
                  "[0m (",F$TRNLNM("ked$keyboard"),")"
$ EXIT
$ !
$No_Ed:
$ WRITE sys$error "%TPU-W_NOKED, no editor established"
$ EXIT
