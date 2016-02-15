$ ! VAST_INCLUDE.COM --
$ !
$ ! Common local (and a couple of global) symbol definitions
$ !
$ ! Copyright (C) 2012-2013 Lorin Ricker <lorin@rickernet.us>
$ ! Version: 2.0, 05/17/2013
$ !
$ ! This program is free software, under the terms and conditions of the
$ ! GNU General Public License published by the Free Software Foundation.
$ !
$ !   Because DCL is rather ill-conceived regarding global and local symbols --
$ !   scopes can be hidden from lower execution levels, but not shared upwards,
$ !   which makes the notion of "file includes" difficult -- the "INCLUDE" code
$ !   contained in each of the VAST_SYSTEM.COM and VAST_xx_zzz.COM files, does
$ !   a "poor-man's INCLUDE" of the following symbol definitions...
$ !
$ ! Note! -- Each executable DCL command within this file MUST BE A ONE-LINE COMMAND
$ !          or a comment (no multi-lines at all), due to the artificial way in which
$ !          these commands are executed by the INCLUDE gosubroutine.
$ !
$ ! These need to be reset for each (sub)Checklist:
$ AUD$Results    == ""
$ AUD$BPSections == ""
$ AUD$MaxDescrL  == 0
$ !
$ ! This file will be INCLUDEd more than once, but need
$ ! only to define the following symbols one/first time --
$ IF F$TYPE(AUD$Privs) .NES. "" THEN GOTO INCLDONE  ! --- terminate the INCLUDE-loop ---
$ !
$ ! =====
$ AUD$Version    == "v1.16 (15-Apr-2013)"
$ AUD$Banner     == "*** DTV/DTS: VMS Audit System - ''AUD$Version' ***"
$ ! -----
$ AUD$BPTitle    == "Integrity Migration for STMS Billing (v1.2)"
$ AUD$BPSubTitle == "- Migrate Billing to Integrity Platform -"
$ AUD$BPURLTitle == "Billing Upgrade Implementation Plan V1-2 (Gates, Mike)"
$ AUD$BPURL      == "http://teams2.sharepoint.hp.com/teams/hpdtv-techcap/STMS_Upgrade/STMS_BBC/default.aspx"
$ AUD$BPAuthor   == "Mike Gates"
$ AUD$Comment1   == ""
$ AUD$Comment2   == ""
$ AUD$NoComment  == "«.»"  ! Flag for "No Comment", so reporting can omit field
$ ! =====
$ !
$ ! If not running as SYSTEM, gonna need most-all SysMgr-type privileges:
$ AUD$Privs == F$SETPRV("ALL")
$ !
$ DoStep    = "@" + AUD$PathAcc + "VAST_DOSTEP"
$ DoShared  = "@" + AUD$PathAcc + "VAST_SHARED"
$ !
$ wso       = "WRITE sys$output"
$ wserr     = "WRITE sys$error"
$ wcsvf     = "WRITE csvf"   ! actually, SEP-separated (SEMICOLON, not COMMA-separated)
$ whtmlf    = "WRITE htmlf"
$ !
$ BANG      = "!"
$ BSLASH    = "\"
$ COLON     = ":"
$ COMMA     = ","
$ DASH      = "-"
$ DOLLAR    = "$"
$ DOT       = "."
$ DQUOTE    = """"
$ EQUAL     = "="
$ EQUALITY  = "=="
$ GE        = ">="
$ LE        = "<="
$ SQUOTE    = "'"
$ SPC       = " "
$ SEMI      = ";"
$ SEP       = SEMI
$ SLASH     = "/"
$ SPLAT     = "*"
$ TILDE     = "~"
$ UNDERL    = "_"
$ VBAR      = "|"
$ !
$ WSOmark   = "#"
$ WSOprompt = "??>>"
$ HRul      = F$FAO( "!80*-" )
$ DHRul     = F$FAO( "!80*=" )
$ Accept    = "Accept"
$ Reject    = "REJECT"
$ Skip      = "skip"
$ !
$ esc[0,32]= %X1B
$ esc[0,1]:= 'esc'
$ _clrscr  = esc + "[m" + esc + "[H" + esc + "[2J"
$ ClrScrn  = "WRITE sys$output _clrscr"
$ !
$ ! Color codes - non-dithering - vary primary color by (00,33,66,99,CC,FF) --
$ ! (see http://www.htmlgoodies.com/tutorials/colors/article.php/3479001):
$ black    = "#000000"
$ ltgray   = "#CCCCCC"
$ dkgray   = "#999999"
$ red      = "#FF0000"
$ orange   = "#FF9900"
$ ltred    = "#FF9999"
$ yellow   = "#FFFF00"
$ ltyellow = "#FFFF66"
$ green    = "#00FF00"
$ ltgreen  = "#CCFFCC"
$ blue     = "#0000FF"
$ ltblue   = "#99FFFF"
$ purple   = "#FF00FF"
$ violet   = "#FFCCFF"
$ white    = "#FFFFFF"
$ !
$ PromptLong  = "Step !AS.!AS. >> Enter YES if this Step is accepted, otherwise enter NO (yes/NO): "
$ PromptShort = "Step !AS.!AS. >> Accept (yes/NO): "
$ PromptSync  = "Press <Enter> when ready to continue: "
$ SkipFlag    = ">SKIP>"
$ !
$ dirwidth      = "/WIDTH=(FILENAME=20,SIZE=10)"
$ AUD$DIRF     == "DIRECTORY /SIZE /DATE /OWNER /PROTECT ''dirwidth'"
$ AUD$DIRA     == "DIRECTORY /SIZE /DATE /OWNER /PROTECT /ACL ''dirwidth'"
$ AUD$DIRB     == "DIRECTORY /SIZE /DATE ''dirwidth'"
$ AUD$DIRFID   == "DIRECTORY /SIZE /DATE /OWNER /FILE_ID ''dirwidth'"
$ AUD$SYSGEN   == "$SYS$SYSTEM:SYSGEN"
$ AUD$SYSMAN   == "$SYS$SYSTEM:SYSMAN"
$ AUD$LANCP    == "$SYS$SYSTEM:LANCP"
$ AUD$NCL      == "$SYS$SYSTEM:NCL"
$ AUD$NCP      == "$SYS$SYSTEM:NCP"
$ AUD$IFCONFIG == "$SYS$SYSTEM:TCPIP$IFCONFIG"
$ AUD$SEARCH   == "SEARCH sys$input"          ! used with PIPE
$ AUD$TYPE     == "TYPE /PAGE=SAVE sys$input" ! ditto
$ !
$ ! Generate this run's timestamp:
$ AUD$Now       == F$TIME()
$ AUD$Today     == F$CVTIME(AUD$Now,"COMPARISON","MONTH") + SLASH + F$CVTIME(AUD$Now,"COMPARISON","DAY") + SLASH + F$CVTIME(AUD$Now,"COMPARISON","YEAR")
$ AUD$Started   == F$CVTIME(AUD$Now,"COMPARISON","HOUR") + COLON + F$CVTIME(AUD$Now,"COMPARISON","MINUTE")
$ AUD$TimeStamp == F$CVTIME(AUD$Now,"COMPARISON","DATE") + SPC + AUD$Started
$ AUD$WriteRpts == 0
$ !
$ ! Who's auditing, on which system and architecture:
$ AUD$UName   == F$EDIT(F$GETJPI(0,"USERNAME"),"TRIM")
$ AUD$Arch    == F$EDIT(F$GETSYI("ARCH_NAME"),"UPCASE")
$ AUD$Fac     == Fac
$ !
$ AUD$RecStat == "VALID  "  ! fixed-length = 7 chars : "VALID  ,TEST   ,INVALID,DELETED"
$ !
$ AUD$Stat    == %X1  !...just so they have an initial value
$ AUD$Sev     == %X1
$ AUD$Level   == "S"
$ !
$ AUD$Tmp     == ""   ! a temp-variable for utility use...
$ !
$ ! --- End of INCLUDEs ---
