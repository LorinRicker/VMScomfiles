$ ! TTK$BUILD.COM  -- builds a section-file from source
$ !
$ !     This program is the confidential and proprietary product of
$ !     LockWorks LLC.  Any unauthorized use, reproduction or transfer
$ !     of this program is strictly prohibited.
$ !
$ !     Copyright © 2012-2013 by Lorin Ricker.  All rights reserved.
$ !     Copyright © 2002-2012 by LockWorks LLC.  All rights reserved.
$ !     Copyright © 1990-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  use:  @TTK$BUILD ["toolkit" (D) | "ked" | "release" ]
$ !
$ SET NOON
$ IF P1 .EQS. "" THEN P1 = "TOOLKIT"
$ GOTO 'F$EXTRACT(0,3,P1)'$
$ !
$PUR$:
$ fil = "tpu$src:tpu_purekit.tpu"
$ !target file for TPU compiles
$ DEFINE /NOLOG /PROCESS tpu$work tpu$src:tpk.tpu$section
$ EDIT = "EDIT"
$ EDIT /TPU /NOSECTION /NODISPLAY /COMMAND='fil'
$ status = $STATUS
$ IF .NOT. status THEN GOTO err
$ ! be sure .tpu$section version number tracks the .tpu source:
$ fil = F$SEARCH("''fil';0")
$ ver = F$PARSE(fil,,,"VERSION","SYNTAX_ONLY")
$ IF F$PARSE("ked$section",,,"NAME","SYNTAX_ONLY") .NES. "TPU_PUREKIT" -
  THEN @com:tpu
$ DEASSIGN /PROCESS tpu$work
$ EXIT
$ !
$TOO$:
$ fil = "tpu$src:tpu_toolkit.tpu"
$ !target file for TPU compiles
$ DEFINE /NOLOG /PROCESS tpu$work tpu$src:ttk.tpu$section
$ EDIT = "EDIT"
$ EDIT /TPU /NOSECTION /NODISPLAY /COMMAND='fil'
$ status = $STATUS
$ IF .NOT. status THEN GOTO err
$ ! be sure .tpu$section version number tracks the .tpu source:
$ fil = F$SEARCH("''fil';0")
$ ver = F$PARSE(fil,,,"VERSION","SYNTAX_ONLY")
$ IF F$PARSE("ked$section",,,"NAME","SYNTAX_ONLY") .NES. "TPU_TOOLKIT" -
  THEN @com:tpu
$ DEASSIGN /PROCESS tpu$work
$ EXIT
$ !
$KED$:
$ @ked$src:ked$build TTK
$ fil = "lib:tpu_toolkit.tpu$section"
$ IF F$SEARCH(fil) .NES. ""
$ THEN DELETE /LOG 'fil';*
$      @com:tpu
$ ENDIF
$ EXIT
$ !
$REL$:
$ @ked$src:ked$build RELEASE
$ EXIT
$ !
$err:
$ WRITE sys$error -
    "%TTK$BUILD-W, new LIB:TPU_TOOLKIT.TPU$SECTION''ver' not copied"
$ DEASSIGN /PROCESS tpu$work
$ EXIT 'status'
