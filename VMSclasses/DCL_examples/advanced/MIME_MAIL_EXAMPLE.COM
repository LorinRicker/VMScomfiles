$ ! MIME_MAIL_EXAMPLE.COM --
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
$ ! -----------------------
$EMailIt:  SUBROUTINE
$ ! P1 : Number (string) of search records matched to produce this report
$ ! P2 : Subject-line text
$ ! P3 : Facility name
$ ! P4 : Name of this node
$ ! P5 : Report filename
$ ! P6 : Report date
$ ! P7 : Email Message filename
$ ! P8 : Email "To:" recipient(s) or distr-list (with leading "@")
$ !
$ ON CONTROL_Y THEN GOSUB EMICtrl_Y
$ ON ERROR THEN EXIT %X2C
$ !
$ fspec = F$PARSE( P5, , , , "SYNTAX_ONLY" ) - F$PARSE( P5, , , "VERSION", "SYNTAX_ONLY" )
$ !
$ recmatched = F$INTEGER( P1 )
$ IF ( recmatched .GT. 0 )
$ THEN subjline = P2
$ ELSE subjline = F$FAO( "%!AS-I-NOVIOLATIONS, system !AS, no violations found for this report period", -
                         Fac, P4 )
$      OPEN /WRITE /ERROR=EMIerror emf 'fspec'
$      WRITE emf subjline
$      WRITE emf ""
$      WRITE emf "Report period: ''P6' to ''F$CVTIME(F$TIME(),"ABSOLUTE","DATE")'"
$      WRITE emf ""
$      CLOSE emf
$      PURGE /NOLOG 'fspec'
$ ENDIF
$ !
$ CALL AttachMIME "''P7'" "''P5'" "''subjline'"
$ ! P7-ThisMsg now has attachment P5-ThisReport:
$ MAIL 'P7' /SUBJECT="''subjline'" "''P8'"
$ MailStat = $STATUS
$ msg1 = F$FAO( "%!AS-I-MAILED, report attached:", Fac )
$ msg2 = "subject line:"
$ indL = F$LENGTH( msg1 ) - F$LENGTH( msg2 ) - 3
$ wso F$FAO( "!AS !AS", msg1, P5 )
$ wso F$FAO( "!#* !AS !AS", indL, msg2, subjline )
$ wso ""
$ wso F$FAO( "%!AS-I-STATUS, mail-report status code: !ZL", -
             Fac, MailStat )
$ wso F$FAO( "%!AS-I-STATUS, !AS", -
             Fac, F$MESSAGE( MailStat ) )
$ wso ""
$ EXIT 1
$ !
$EMIerror:
$ wso "%''Fac'-E-OPENERR, cannot open temp-file ''P5'"
$ EXIT %x2C
$EMICtrl_Y:
$ RETURN %X2C
$ ENDSUBROUTINE  ! EMailIt
$ !
$ ! -----------------------
$AttachMIME:  SUBROUTINE
$ ! P1 : Email Message filename
$ ! P2 : Report filespec
$ ! P2 : Subject-line text
$ !
$ ON ERROR THEN EXIT %x2C
$ !
$ TempF = "sys$scratch:" + F$PARSE(P1,,,"NAME","SYNTAX_ONLY") + ".COMTMP"
$ !
$ OPEN /WRITE /ERROR=AMerror tmp 'TempF'
$ wtmp = "WRITE tmp"
$ wtmp "$ ! ''TempF' --       !'F$VERIFY(0)'"
$ wtmp "$ mime = ""$sys$system:mime"""
$ wtmp "$ CREATE /OWNER=PARENT /PROT=(O:RWED) ''ThisMsg'"
$ wtmp P3    ! use the subject line as message-body
$ wtmp "$ ! [EOD]"
$ wtmp "$ DEFINE /USER_MODE sys$output NLA0:"
$ wtmp "$ DEFINE /USER_MODE sys$error  NLA0:"
$ wtmp "$ mime"
$ wtmp "open /draft ''ThisMsg'"
$ wtmp "add /text ''P2'"        ! attach the Audit Report file
$ wtmp "save"
$ wtmp "exit"
$ wtmp "$ ! [EOD]"
$ wtmp "$ EXIT 1"
$ CLOSE tmp
$ !
$ @'TempF'
$ IF ( F$SEARCH(TempF) .NES. "" ) THEN DELETE /NOLOG 'TempF';*
$ !
$ EXIT 1
$AMerror:
$ wso "%''Fac'-E-OPENERR, cannot open temp-file ''TempF'"
$ EXIT %x2C
$ ENDSUBROUTINE  ! AttachMIME
$ !
$ !
$ ! Main:
$ !
$ ! -----
$ ! Dummy up an "example report" here which demonstrates
$ !  call to EMailIt, which in turn calls AttachMime to
$ !  include a MIME attachment, the report itself:
$ !
$ Count$Total = 10  ! "things which matched..."
$ subjline    = "This is a test/dummy report with a MIME-attachment"
$ Fac         = "TEST"
$ ThisNode    = F$EDIT(F$GETSYI("NODENAME"),"TRIM")
$ ReportDate  = F$CVTIME( "", "ABSOLUTE", "DATE" )
$ ThisReport  = "SAMPLE_REPORT.REPORT"  ! We'll create this in a moment...
$ ThisMsg     = "SAMPLE_REPORT.MSG"     ! Name for the MIME'd attachment file
$ Recipients  = "lorin@parsec.com"      ! Comma-separated list of email addresses,
$                                       ! or a distr-list (filename with leading "@")
$ ! -----
$ CREATE 'ThisReport'
This is just a dummy report generated to demonstrate
how to wrap a proper MIME-attachment for emailing as
a true attachment document.

Many dummy lines of data follow...
...

And here's the end of this 8-line dummy report.
$ ! [EOD]
$ !
$ ! -----
$ ! How to email the MIME-attached report:
$ !
$ CALL EMailIt "''Count$Total'" "''subjline'" "''Fac'" -
         "''ThisNode'" "''ThisReport'" "''ReportDate'" "''ThisMsg'" "''Recipients'"
$ !
$ EXIT 1
$ !
