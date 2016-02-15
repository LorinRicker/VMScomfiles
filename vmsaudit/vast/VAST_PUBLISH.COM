$ ! VAST_PUBLISH.COM --                                           'F$VERIFY(0)'
$ !
$ ! use: @VAST_PUBLISH [ filespec_to_push ] [ target_for_push ]
$ !
$ ! Copyright (C) 2012-2013 Lorin Ricker <lorin@rickernet.us>
$ ! Version: 2.0, 05/17/2013
$ !
$ ! This program is free software, under the terms and conditions of the
$ ! GNU General Public License published by the Free Software Foundation.
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ IF Debugging
$ THEN wserr F$FAO( "!/%!AS-I-REMEXE, remote execution from !AS", Fac, AUD$NodeAcc )
$      wserr F$FAO( "%!AS-I-PUBLISH, publishing files...!/", Fac )
$ ENDIF
$ !
$ IF F$EXTRACT(0,1,P2) .EQS. "«"  ! as in "«website»", it's a test-spec, not the real thing
$ THEN wserr F$FAO( "%!AS-I-FILE_TEST, !AS", Fac, P1 )
$      wserr F$FAO( "%!AS-I-PUSH_TEST, would push/copy file to !AS", Fac, P2 )
$      EXIT 1
$ ENDIF
$ !
$ ftype = F$PARSE(P1,,,"TYPE","SYNTAX_ONLY") - "."
$ GOTO 'ftype'
$ !
$HTML:
$ ! «» COPY/FTP (push to website or SharePoint) here
$ !
$CSV:
$ ! «» harder... How to push/copy to a PC directory for import into Excel?
$ !
$Done:
$ EXIT 1
$ !
$Ctrl_Y:
$ RETURN %X2C
