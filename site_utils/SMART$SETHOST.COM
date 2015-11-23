$ ! SMART$SETHOST.COM --                                           'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 2000-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  Use:  @SMART$SETHOST [ node | 0 | LOCALHOST | $LOGIN ] -
$ !                       [ logfile ] -
$ !                       [ D[ECnet] (default) | T[CPIP] ]
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ wso  = "WRITE sys$output"
$ Fac  = "SETHOST"
$ DCmd = ""
$ TCmd = ""
$ !
$ IF ( P1 .EQS. "?" ) THEN GOTO Help
$ Verbose = F$TRNLNM("TOOLS$Debug")     !generic Tools debug flag
$ !
$ ! Define the foreign command global symbol upon request:
$ IF F$EXTRACT(0,4,P1) .EQS. "$LOG"
$ THEN DD = F$ENVIRONMENT("PROCEDURE")
$      DD = DD - F$PARSE(DD,,,"VERSION","SYNTAX_ONLY")
$      SetH*ost == "@''DD'"
$      IF Verbose THEN SHOW SYMBOL /GLOBAL SetHost
$      EXIT
$ ENDIF
$ !
$ ! DECnet's SET HOST is to be naturally preferred over Telnet,
$ ! unless user or system/user logical name chooses otherwise ---
$ ! Precedence: process or job logical (highest), system logical,
$ !             P3, default = "D[ECnet]" (lowest) ...
$ Preferred = F$EDIT(F$TRNLNM("SMART$SETHOST_PROTOCOL"),"COLLAPSE,UPCASE")
$ IF Preferred .NES. "" THEN P3 = Preferred
$ Preferred = "D"
$ P3 = F$EXTRACT(0,1,P3)
$ IF P3 .NES. "" -
  THEN IF F$LOCATE("/''P3'/","/D/T/") .LT. 5 -
       THEN Preferred = P3
$ !
$ ! Session logfile requested?
$ IF P2 .NES. ""
$ THEN Log = "/LOG=" + F$PARSE(P2,"sys$scratch:.log",,,"SYNTAX_ONLY")
$ ELSE Log = ""
$ ENDIF
$ !
$ ! Determine which is running: DECnet (Phase IV or V) and/or TCP/IP ...
$ DNetDev = "_NET0"
$ IF F$GETDVI(DNetDev,"EXISTS")
$ THEN IF F$GETDVI(DNetDev,"MNT")
$      THEN DECnetVersion = F$GETSYI("DECNET_VERSION")
$           DCmd = "SET HOST"
$           DProtocol = "DECnet Phase-" + F$EXTRACT(3,1,DECnetVersion)
$      ENDIF
$ ENDIF
$ TNetDev = "_BG0"
$ IF F$SEARCH("sys$system:tcpip$inetacp.exe") .NES. "" -
  .OR. F$SEARCH("sys$system:ucx$inetacp.exe") .NES. ""
$ THEN IF F$GETDVI(TNetDev,"EXISTS")
$      THEN IF F$GETDVI(TNetDev,"MNT")
$           THEN !! TCPIPVersion = F$GETSYI("??«»_VERSION")
$                TCmd = "TELNET"
$                TProtocol = "TCP/IP"
$           ENDIF
$      ENDIF
$ ENDIF
$ !
$ ! Sanity check:  If both networks are available, then either user's
$ !                preferrence holds or use the default if don't care;
$ !                else, if only one network is alive, use that one;
$ !                else, if neither's available, complain and abort.
$ IF ( DCmd .EQS. "" ) .AND. ( TCmd .EQS. "" )
$ THEN wso "%''Fac'-F-NO_NETWORK, neither DECnet nor TCP/IP is available"
$      EXIT %X2C
$ ELSE IF ( DCmd .NES. "" ) .AND. ( TCmd .EQS. "" )
$      THEN Preferred = "D"
$      ELSE IF ( TCmd .NES. "" ) .AND. ( DCmd .EQS. "" )
$           THEN Preferred = "T"
$           ENDIF
$      ENDIF
$ ENDIF
$ !
$ ! Now, sort out preferrences, target node and remote command:
$ IF P1 .EQS. ""
$ THEN IF Preferred .EQS. "T"
$      THEN P1 = "LOCALHOST"
$      ELSE P1 = "0"
$      ENDIF
$ ELSE IF ( Preferred .EQS. "T" ) .AND. ( P1 .EQS. "0" )
$      THEN P1 = "LOCALHOST"
$      ELSE IF ( Preferred .EQS. "D" ) .AND. ( P1 .EQS. "LOCALHOST" )
$           THEN P1 = "0"
$           ENDIF
$      ENDIF
$ ENDIF
$ Cmd = 'Preferred'Cmd
$ IF Cmd .EQS. ""
$ THEN wso "%''Fac'-E-NO_COMMAND, procedure failed to select SET HOST/TELNET command"
$      EXIT %X2C
$ ELSE IF Verbose
$      THEN wso "%''Fac'-I-ECHO, $ [1m''Cmd' ''P1' ''Log'[0m"
$           wso "%''Fac'-I-PROTOCOL, using ",'Preferred'Protocol," protocol"
$      ENDIF
$ ENDIF
$ !
$ IF ( P1 .EQS. "0" ) .OR. ( P1 .EQS. "LOCALHOST" )
$ THEN Node = F$EDIT(F$GETSYI("SCSNODE"),"TRIM")
$ ELSE Node = P1
$ ENDIF
$ wso "%''Fac'-I-CONNECT, ''Cmd' to node[7m ''Node' [0mover ", -
      'Preferred'Protocol,"..."
$ wso F$FAO("!/!78*-!/")
$ !
$ DEFINE /USER_MODE sys$input sys$command
$ 'Cmd' 'P1' 'Log'
$ !
$ wso F$FAO("!/!78*-!/")
$ !
$Done:
$ EXIT
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  This command procedure implements a "smart Set Host/Telnet" command.
  It detects whether DECnet and/or TCP/IP network stacks are present on
  the system, and allows you to use either "the best one" or the one you
  prefer for remote login connections.  The procedure then handles all
  command syntax (e.g., TELNET vs. SET HOST and LOCALHOST vs. 0) for you.

  use:  @SMART$SetHost [ node | 0 | LOCALHOST | $LOGIN ] -
                       [ logfile ] -
                       [ D[ECnet] (default) | T[CPIP] ]

  where:

  SETH*OST == "@site$utils:SMART$SetHost.com"

  P1 -  The [1mnode[0m to which you want to connect; specify one of:

        [1mnode[0m - The name of the remote computer (nodename) to which you
               want to connect (login) a remote session.  This nodename
               must be defined in the local system's database of known
               remote computers by name or IP-number.
           [1m0[0m - Shorthand to connect a remote session to the local system
   [1mLOCALHOST[0m - Synonym for (same as) "0", regardless of whether connection
               is via SET HOST or TELNET command.
      [1m$LOGIN[0m - Special value to define a foreign command symbol "SETH*OST"
               (abbrev. "Seth") to invoke this procedure.  To define the
               SETH*OST command for your sessions, put the following line
               in your personal LOGIN.COM file:

                   [1m$ @site$utils:SMART$sethost $LOGIN[0m

  P2 -  File specification for an [1moptional session log-file[0m.  It's sufficient
        to just provide the file-name part itself; by default, the log-file
        is created in SYS$SCRATCH: with a file extension of .LOG; both the
        device/directory and the file-type can be overridden by entering a
        more complete file-spec.

  P3 -  The [1mprotocol[0m to use; overrides the default, and the protocol specified
        here is used only if that protocol stack is found on the system.
        Enter one of the following:

        [1mD[0mECnet (SET HOST) protocol, using either Phase IV or Phase V
         as available.
        [1mT[0mCP/IP (Telnet) protocol, using either TCP/IP v5.0 (and higher)
         or UCX v4.x as available.

        If the logical name [1mSMART$SETHOST_PROTOCOL[0m is defined, either at the
        /PROCESS, /JOB or /SYSTEM level, it overrides this P3 parameter.
        Logical name translation precedence rules apply, and the availability
        of the system-wide logical name value gives system management the means
        to specify a global preferred protocol for a site, even over a user's
        command-line override value (the logical name(s) trump P3).

        If no protocol override is given, and if both DECnet and TCP/IP
        (UCX) are present, then DECnet (SET HOST) is used by default.
        If only one protocol is present, then that protocol is used,
        regardless of any protocol overrides.  If neither protocol is
        available, then obviously this command procedure will fail to
        connect to any remote node.

  Examples:

  $ [1mseth[0m                   ! connects to LOCALHOST (node 0),
                           !  no session log-file, default protocol

  $ [1mseth outlaw "" D[0m       ! connects to a remote node named OUTLAW,
                           !  no session log-file, using DECnet (SET HOST)

  $ [1mseth 0 local[0m           ! connects to LOCALHOST, with a session
                           !  log-file named SYS$SCRATCH:LOCAL.LOG,
                           !  default protocol

  $ [1mseth bandit session T[0m  ! connects to node BANDIT, with a session
                           !  log-file named SYS$SCRATCH:SESSION.LOG,
                           !   using TCP/IP (Telnet)

$ !
$ SHOW NETWORK
$ wso ""
$ GOTO Done
