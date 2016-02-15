$ ! VAST_11_TCPIP.COM --                                          'F$VERIFY(0)'
$ !
$ !  use: @VAST_11_TCPIP
$ !
$ ! Copyright (C) 2012-2013 Lorin Ricker <lorin@rickernet.us>
$ ! Version: 2.0, 05/17/2013
$ !
$ ! This program is free software, under the terms and conditions of the
$ ! GNU General Public License published by the Free Software Foundation.
$ !
$ ! === Main ===
$Main:
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ GOSUB INCLUDE
$ Fac = F$PARSE(Proc,,,"NAME","SYNTAX_ONLY")
$ !
$ ! --- --- --- ---
$ !
$ MajorStep = "11"
$ MajorName = "TCP/IP -- Core Checks"
$ MajorCat  = "TCPIP"
$ !
$ wso F$FAO( "!/!AS!/%!AS-I-CHECKLIST, starting Checklist !AS", HRul, Fac, MajorStep )
$ wso F$FAO( "%!AS-I-COLLDATA, collecting audit data for system !AS!/!AS", Fac, AUD$Node, HRul )
$ !
$ MinorStep = "a"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the TCP/IP version correct?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptLong'" -
    "TCP/IP version" -  ! short description
    "TCPIP SHOW VERSION"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "b"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the TCP/IP Name Service configured correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "TCP/IP Name Service configuration" -  ! short description
    "TCPIP SHOW CONFIGURATION NAME_SERVICE" -
    "TCPIP SHOW NAME_SERVICE"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "c"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the TCP/IP Communication Configuration correct?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "TCP/IP Communication Configuration" -  ! short description
    "TCPIP SHOW CONFIGURATION COMMUNICATION" -
    "TCPIP SHOW COMMUNICATION"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "d"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the TCP/IP Enable Service configured correct?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "TCP/IP Enable Service" -  ! short description
    "TCPIP SHOW CONFIGURATION ENABLE SERVICE" -
    "TCPIP SHOW CONFIGURATION ENABLE SERVICE /COMMON"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "e"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the TCP/IP Services database configured correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "TCP/IP Services database" -  ! short description
    "TCPIP SHOW SERVICE /FULL /PERMANENT" -
    "TCPIP SHOW SERVICE /FULL"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "f"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the TCP/IP Interface configured correctly
  (devices, IP_Address and Network Mask)?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "TCP/IP Interface" -  ! short description
    "TCPIP SHOW INTERFACE" -
    "AUD$IFCONFIG -a"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "g"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the TCP/IP Host Local Database configured correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "TCP/IP Show Host Local database" -  ! short description
    "TCPIP SHOW HOST /LOCAL"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "h"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the TCP/IP Routing database configured correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "TCP/IP Routing database" -  ! short description
    "TCPIP SHOW ROUTE /PERMANENT" -
    "TCPIP SHOW ROUTE"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "i"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Is the TCP/IP Proxy database configured correctly?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "TCP/IP Proxy database" -  ! short description
    "TCPIP SHOW PROXY /PERMANENT"
$ !
$ ! ---
$ ClrScrn
$ MinorStep = "j"
$ DTSonly   = VBAR + ""
$ BPSection = "(NIP)"
$ AUD$BPSections == AUD$BPSections + SEP + BPSection
$ wso F$FAO( "!/  [1mStep !AS.!AS.[0m", MajorStep, MinorStep )
$ TYPE SYS$INPUT
  Do the TCPIP$* logical names all look correct?

$ DoStep "''MajorStep'" "''MinorStep'''DTSonly'" "''PromptShort'" -
    "TCP/IP logical names" -  ! short description
    "SHOW LOGICAL /SYSTEM TCPIP$*"
$ !
$ ! --- --- --- ---
$ !
$Report:
$ @'AUD$PathAcc'VAST_RESULTS
$Done:
$ EXIT 1   !'F$VERIFY(0)'
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ ! ====================================================
$ ! (See VAST_INCLUDE.COM file for purpose/comments...)
$INCLUDE:
$ OPEN /READ InclF 'AUD$IncludeFile'
$INCL0:
$ READ /END_OF_FILE=INCLDONE InclF IncLine
$ IncLine = F$EDIT(IncLine,"UNCOMMENT,COMPRESS")
$ IF F$EXTRACT(0,2,IncLine) .EQS. "$ " -
  THEN IncLine = F$EDIT(F$EXTRACT(2,F$LENGTH(IncLine)-2,IncLine),"TRIM")
$ IF IncLine .EQS. "" THEN GOTO INCL0
$ 'IncLine'
$ IF Debugging THEN wserr F$FAO( "$ [1m!AS[0m", IncLine )
$ GOTO INCL0
$INCLDONE:
$ CLOSE InclF
$ RETURN 1
$ ! end INCLUDE
$ ! --------
$ ! end INCLUDE
$ ! --------
