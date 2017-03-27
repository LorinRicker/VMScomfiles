$ ! CHECK_SYSGEN_LGI.COM --                                        'F$VERIFY(0)'
$ !
$ ! Copyright © 2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$ ! P1 = value of LGI_BRK_LIM to cross-check
$ !
$ wso  = "WRITE sys$output"
$ !
$ ThisNode    = F$EDIT(F$GETSYI("NODENAME"),"TRIM")
$ Proc        = F$ENVIRONMENT("PROCEDURE")
$ Proc        = Proc - F$PARSE(Proc,,,"VERSION","SYNTAX_ONLY")
$ Fac         = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ RptDir      = F$PARSE(Proc,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(Proc,,,"DIRECTORY","SYNTAX_ONLY")
$ rptdstr     = RptDir + Fac + "_" + F$CVTIME("","COMPARISON","DATE")
$ ThisReport == rptdstr + ".REPORT"
$ !
$ IF ( P1 .NES. "" )
$ THEN Target_LGI_BRK_LIM = P1
$ ELSE Target_LGI_BRK_LIM =  5  ! VMS default
$ ENDIF
$ !
$ DEFINE /NOLOG sys$output 'ThisReport'
$ !
$ wso "System ''ThisNode': Parameter LGI_BRK_LIM should be ''Target_LGI_BRK_LIM' ..."
$ wso ""
$ Active_LGI_BRK_LIM = F$GETSYI("LGI_BRK_LIM")
$ wso "Active LGI_BRK_LIM is: ''Active_LGI_BRK_LIM'"
$ IF ( Active_LGI_BRK_LIM .EQ. Target_LGI_BRK_LIM )
$ THEN wso "Parameter is compliant."
$ ELSE wso "Parameter is NOT compliant!"
$ ENDIF
$ !
$ MCR SYSGEN
USE ACTIVE
SHOW /LGI
USE CURRENT
SHOW /LGI
EXIT
$ !
$ wso ""
$ DEASSIGN sys$output
$ !
$ ! If this com-file is invoked interactively "@CHECK_SYSGEN_LGI"
$ ! then just type out the report, else set-up for emailing by
$ ! caller script:
$ IF ( F$ENVIRONMENT("DEPTH") .EQ. 1 ) .AND. ( F$MODE() .EQS. "INTERACTIVE" )
$ THEN TYPE /PAGE 'ThisReport'
$ ENDIF
$ !
$ EXIT 1  ! 'F$VERIFY(0)'
$ !
