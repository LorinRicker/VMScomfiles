$ ! FILE$ATTRIBUTES.COM --                                         'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 2000-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  use: @FILE$ATTRIBUTES [ fspec[,fspec...] | @filelist ] -
$ !                        [ /ORGANIZATION (D) | /DATETIME | /SIZE -
$ !                          | /FID | /MANAGEMENT | /JOURNALING ] -
$ !                        [ /HIGHLIGHT[=BOLD|UNDERLINE] ] -
$ !                        [ /WIDTH=col_width ]
$ !
$ !  02/08/2002 - Make /DATETIME (/TIME) display of "exipres:" (expiration
$ !               date/time) conditional. LMR
$ !  01/02/2001 - Added conditional check for VMS V7.2, since "VERLIMIT"
$ !               argument for F$FILE_ATTRIBUTE is new with that release. LMR
$ !  12/29/2000 - Base release, using and providing visibility for
$ !               nearly all argument-items of F$FILE_ATTRIBUTE(),
$ !               except "GRP", "MBM" and "DVI" (I think...). LMR
$ !
$MAIN:
$ ON ERROR THEN EXIT 1
$ Util = "@site$utils:utility.com"
$ Util START FIL "" "V2000.03.00"  !Require this minimum version of UTILITY.COM
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ !
$ wso = "WRITE sys$output"
$ DD  = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(DD,,,"NAME","SYNTAX_ONLY")
$ DD  = F$PARSE(DD,,,"DEVICE","SYNTAX_ONLY") + F$PARSE(DD,,,"DIRECTORY","SYNTAX_ONLY")
$ Ver = F$TRNLNM("Tools$Debug")
$ !
$ Dot      = "."
$ Bar      = "|"
$ Slash    = "/"
$ Equal    = "="
$ TimeZero = "17-NOV-1858 00:00:00.00"
$ None     = "<none specified>"
$ NoBackup = "<no backup recorded>"
$ !
$ VMS72 = ( F$GETSYI("VERSION") .GES. "V7.2" )
$ !
$L1:
$ IF P1 .EQS. ""
$ THEN READ /PROMPT="filespec: " /END_OF_FILE=Done sys$command P1
$      GOTO L1
$ ENDIF
$ !
$ FIL$FCount  == 0
$ FIL$ThisDir == ""
$ FIL$LastBLS == -1
$ FIL$TotalSz == 0
$ FIL$TotalAl == 0
$ ScrWidth = F$GETDVI("sys$command","DEVBUFSIZ")
$ IF ScrWidth .GT. 80
$ THEN FIL$FNWidth == 64   !132-col
$ ELSE FIL$FNWidth == 32   !80-col
$ ENDIF
$ !
$ IF F$EXTRACT(0,1,P1) .EQS. "?" THEN GOTO Help
$ !
$ P2 = P2 - "/" - "-"
$ Commands = "ORGANIZATION|" -
           + "DATETIME    |" -
           + "TIME        |" -
           + "FID         |" -
           + "JOURNALING  |" -
           + "MANAGEMENT  |" -
           + "SIZE        "
$ Util CMDPARSE "''P2'" Cmd "ORGANIZATION" "''Commands'"
$ !
$ Quals = P3 + P4 + P5 + P6 + P7 + P8
$ Quals = F$EDIT(Quals,"COMPRESS,TRIM")
$ LQuals = F$LENGTH(Quals)
$ Highlight = ""
$ IF F$LOCATE("/HIGH",Quals) .LT. LQuals
$ THEN i = 1
$QLoop1:
$      Q = F$EDIT(F$ELEMENT(i,Slash,Quals),"COLLAPSE,UPCASE")
$      IF ( Q .EQS. Slash ) .OR. ( Q .EQS. "" ) .OR. ( i .GT. 10 ) THEN GOTO QCont1
$      IF F$EXTRACT(0,4,Q) .EQS. "HIGH" -
       THEN W = F$EXTRACT(0,1,F$ELEMENT(1,Equal,Q)) !Bold or Underline?
$      IF ( W .NES. Equal ) .OR. ( W .EQS. "" )
$      THEN Highlight = W
$      ELSE Highlight = "B"  !default Bold if no value given on /HIGHLIGHT
$      ENDIF
$      i = i + 1
$      GOTO QLoop1
$ ENDIF
$QCont1:
$ IF Highlight .NES. "" THEN FIL$FNWidth == FIL$FNWidth + 8  !video-attributes
$ !
$ IF F$LOCATE("/WID",Quals) .LT. LQuals
$ THEN i = 1
$QLoop2:
$      Q = F$EDIT(F$ELEMENT(i,Slash,Quals),"COLLAPSE,UPCASE")
$      IF ( Q .EQS. Slash ) .OR. ( Q .EQS. "" ) .OR. ( i .GT. 10 ) THEN GOTO QCont2
$      IF F$EXTRACT(0,3,Q) .EQS. "WID"
$      THEN W = F$ELEMENT(1,Equal,Q)
$           W = F$INTEGER(W)
$           IF W .GT. FIL$FNWidth THEN FIL$FNWidth == W
$      ENDIF
$      i = i + 1
$      GOTO QLoop2
$ ENDIF
$QCont2:
$ IF F$EXTRACT(0,1,P1) .EQS. "@" THEN GOTO IndirectSpec
$ !
$DirectSpec:
$ i = 0
$ F0 = "sys$disk:[]"
$DS0:
$ Fl = F$ELEMENT(i,",",P1)
$ IF Fl .EQS. "," THEN GOTO Done               !more files?
$ FS   = F$PARSE(Fl,F0,"*.*",,"SYNTAX_ONLY")   !expand w/sticky dev:[dir]
$ FLen = F$LENGTH(FS)
$ Wild = ( F$LOCATE("*",FS) .LT. FLen ) .OR. ( F$LOCATE("%",FS) .LT. FLen )
$ GotOne = 0
$DS1:
$ F0 = F$PARSE(Fl,F0,,"DEVICE","SYNTAX_ONLY") -  !save sticky dev:[dir]
     + F$PARSE(Fl,F0,,"DIRECTORY","SYNTAX_ONLY")
$ Fl = F$SEARCH(FS,1)
$ IF Fl .NES. ""
$ THEN CALL TheProcess "''Fl'" "''FIL$Cmd'"
$     !===============
$      IF Wild
$      THEN GotOne = 1
$           GOTO DS1       !next wildcard
$      ELSE i = i + 1
$           GOTO DS0       !next comma-element
$      ENDIF
$ ELSE IF .NOT. GotOne THEN wso "%''Fac'-E-FNF, cannot find ''FS'"
$      i = i + 1
$      GOTO DS0
$ ENDIF
$ !
$MakeIndirect:
$ @site$utils:FILE$PrepList "''Files'" "" "" "" FIL$XFile /CONFIRM
$ IF F$TYPE(FIL$XFile) .EQS. "" THEN GOTO Done  !user-aborted or error
$ P1 = "@" + FIL$XFile                          !try again...
$ !
$IndirectSpec:
$ Files = P1 - "@"
$ Files = F$PARSE(Files,".lis")
$ OPEN /READ /ERROR=FNF f 'Files'
$IS0:
$ READ /END_OF_FILE=IS1 f Fl
$ Fl = F$EDIT(Fl,"COLLAPSE,UPCASE,UNCOMMENT")
$ IF Fl .EQS. "" THEN GOTO IS0                   !skip blank lines & comments
$!===============
$ CALL TheProcess "''Fl'" "''FIL$Cmd'"
$!===============
$ GOTO IS0
$ !
$IS1:
$ CLOSE f
$ !
$Done:
$ SET NOON
$ IF FIL$FCount .GT. 0
$ THEN wso ""
$      Line = F$FAO("Total of !ZL file!%S", FIL$FCount)
$      IF FIL$TotalSz .GT. 0 -
       THEN Line = Line + F$FAO(", !ZL block!%S used", FIL$TotalSz)
$      IF FIL$TotalAl .GT. 0 -
       THEN Line = Line + F$FAO(", !ZL block!%S allocated", FIL$TotalAl)
$      wso Line
$ ENDIF
$ Util EXIT FIL
$ EXIT
$ !
$FNF:
$ wso "%''Fac'-E-FNF, cannot find @-list ''Files'"
$ wso ""
$ wso "  Creating indirect @-list file ''Files'"
$ wso ""
$ GOTO MakeIndirect
$ !
$ !
$ !          ==========
$TheProcess: SUBROUTINE
$ ! P1 : filespec
$ ! P2 : report option
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO TP$Done
$ !
$ CALL Header "''P1'" "''P2'"
$ Line1 = ""
$ Line2 = ""
$ Line3 = ""
$ Line4 = ""
$ Line5 = ""
$ !
$ Tp = F$PARSE(P1,,,"TYPE","SYNTAX_ONLY")
$ FN = F$PARSE(P1,,,"NAME","SYNTAX_ONLY") -
     + Tp + F$PARSE(P1,,,"VERSION","SYNTAX_ONLY")
$ FNLen = F$LENGTH(FN)  !*before* adding any highlighting
$ IF Highlight .EQS. "B"
$ THEN FN = F$FAO("[1m!AS[0m", FN)       !Bold
$ ELSE IF Highlight .EQS. "U"
$      THEN FN = F$FAO("[4m!AS[0m", FN)  !Underline
$      ENDIF
$ ENDIF
$ HLCorrection = ( 8 * ( Highlight .NES. "" ) )
$ !
$ ! If file's locked by another user/process/program, squelch the noise:
$ DEFINE /PROCESS /NOLOG sys$output nl:
$ DEFINE /PROCESS /NOLOG sys$error  nl:
$ ORG = F$FILE_ATTRIBUTE(P1,"ORG")
$ Stat = $STATUS
$ DEASSIGN /PROCESS sys$error
$ DEASSIGN /PROCESS sys$output
$ !
$ IF Stat .EQ. %X00000800    !%SYSTEM-W-ACCONFLICT, file access conflict
$ THEN Tmp  = "<file access conflict>"
$      IF FNLen .LT. FIL$FNWidth
$      THEN Line1 = F$FAO("!#AS!AS",      FIL$FNWidth, FN, Tmp)
$      ELSE Line1 = F$FAO("!AS!/!#* !AS", FN, FIL$FNWidth, Tmp)
$      ENDIF
$      GOTO TP$Write  !don't check other attributes, just report lock-conflict...
$ ENDIF
$ GOTO TP$'P2'
$ !
$TP$Organization:     ! =====================================================
$ RAT = F$FILE_ATTRIBUTE(P1,"RAT")
$ IF RAT .EQS. "" THEN RAT = """"""  ! literally: ""
$ RFM = F$FILE_ATTRIBUTE(P1,"RFM")
$ !
$ ORGTypes = ",IDX,SEQ,"
$ LRLTypes = ",FIX,VAR,VFC,"
$ IF ( F$LOCATE(",''ORG',",ORGTypes) .LT. F$LENGTH(ORGTypes) ) -
  .AND. ( F$LOCATE(",''RFM',",LRLTypes) .LT. F$LENGTH(LRLTypes) )
$ THEN IF ORG .EQS. "IDX"
$      THEN RecL = "MRS"   !maximum record size
$      ELSE RecL = "LRL"   !longest record length
$      ENDIF
$      IF RFM .EQS. "VFC"
$      THEN RFM = F$FAO("!AS(!ZL,!ZL)", RFM, -
                         F$FILE_ATTRIBUTE(P1,RecL), -
                         F$FILE_ATTRIBUTE(P1,"FSZ"))  !fixed-control size
$      ELSE RFM = F$FAO("!AS(!ZL)", RFM, F$FILE_ATTRIBUTE(P1,RecL))
$      ENDIF
$ ENDIF
$ !
$ VLm = ""
$ IF VMS72
$ THEN VLm = F$FILE_ATTRIBUTE(P1,"VERLIMIT") !version limit, if any
$      IF VLm .GE. 32767
$      THEN VLm = F$FAO("!7* ")
$      ELSE VLm = F$FAO("[!#* !AS]", 5 - F$LENGTH(VLm), F$STRING(VLm))
$      ENDIF
$ ENDIF
$ Att  = F$FAO("{!AS, !AS, !AS}", ORG, RAT, RFM)
$ !
$ Rev = F$FILE_ATTRIBUTE(P1,"RVN")      !# of revisions
$ IF Rev .GT. 1
$ THEN FN = FN + F$FAO(" (!ZL)", Rev)
$      FNLen = F$LENGTH(FN)
$ ENDIF
$ !
$ PVN = F$FILE_ATTRIBUTE(P1,"PVN")
$ IF PVN .GT. 0
$ THEN PVN = F$FAO("Prolog !ZL", PVN)
$ ELSE PVN = ""
$ ENDIF
$ !
$ WAtt = 22 - F$LENGTH(Att)
$ IF FNLen .LT. FIL$FNWidth
$ THEN Line1 = F$FAO("!#AS!AS !#* !AS !AS", -
                      FIL$FNWidth, FN, Att, WAtt, VLm, PVN)
$ ELSE Line1 = F$FAO("!AS!/!#* !AS !#* !AS !AS", -
                      FN, FIL$FNWidth - HLCorrection, Att, WAtt, VLm, PVN)
$ ENDIF
$ GOTO TP$Write
$ !
$TP$DateTime:         ! =====================================================
$TP$Time:
$ i = 0
$TP$DT0:
$ IF i .GT. 3 THEN GOTO TP$DT1
$ L0 = F$EXTRACT(i,1,"CRBE")
$ L1 = F$ELEMENT(i,Bar,"created:|revised:| backup:|expires:")
$ 'L0'DT = F$FILE_ATTRIBUTE(P1,"''L0'DT")  !fetch CDT, RDT, BDT & EDT
$ IF 'L0'DT .EQS. TimeZero
$ THEN IF L0 .EQS. "B"
$      THEN 'L0'DT = NoBackup
$      ELSE 'L0'DT = None
$      ENDIF
$ ENDIF
$ IF L0 .EQS. "E"
$ THEN IF EDT .NES. None
$      THEN EDT = L1 + " " + EDT
$      ELSE EDT = ""
$      ENDIF
$ ELSE 'L0'DT = L1 + " " + 'L0'DT
$ ENDIF
$ i = i + 1
$ GOTO TP$DT0
$TP$DT1:
$ Line4 = ""
$ Rev = F$FILE_ATTRIBUTE(P1,"RVN")      !# of revisions
$ IF FNLen .LT. FIL$FNWidth
$ THEN Line1 = F$FAO("!#AS!AS", FIL$FNWidth, FN, CDT)
$      Line2 = F$FAO("!#* !AS (!ZL)", FIL$FNWidth, RDT, Rev)
$      Line3 = F$FAO("!#* !AS", FIL$FNWidth, BDT)
$      IF EDT .NES. "" -  ! conditionally show "expires:"
       THEN Line4 = F$FAO("!#* !AS", FIL$FNWidth, EDT)
$ ELSE Line1 = F$FAO("!AS!/!#* !AS", FN, FIL$FNWidth, CDT)
$      Line2 = F$FAO("!#* !AS (!ZL)", FIL$FNWidth, RDT, Rev)
$      Line3 = F$FAO("!#* !AS", FIL$FNWidth, BDT)
$      IF EDT .NES. "" -  ! conditionally show "expires:"
       THEN Line4 = F$FAO("!#* !AS", FIL$FNWidth, EDT)
$ ENDIF
$ GOTO TP$Write
$ !
$TP$Size:             ! =====================================================
$ ALQ = F$FILE_ATTRIBUTE(P1,"ALQ")  !Allocation quantity
$ FIL$TotalAl == FIL$TotalAl + ALQ
$ BLS = F$FILE_ATTRIBUTE(P1,"BLS")  !Block size
$ IF BLS .EQ. FIL$LastBLS
$ THEN BLS = F$FAO("(!ZL byte blocks)",BLS)
$      FIL$LastBLS == BLS
$ ELSE BLS = ""
$ ENDIF
$ CBT = F$FILE_ATTRIBUTE(P1,"CBT")  !Contiguous best-try
$ CTG = F$FILE_ATTRIBUTE(P1,"CTG")  !Contiguous
$ DEQ = F$FILE_ATTRIBUTE(P1,"DEQ")  !Default extension quantity
$ EOF = F$FILE_ATTRIBUTE(P1,"EOF")  !Number of blocks used
$ FIL$TotalSz == FIL$TotalSz + EOF
$ ERA = F$FILE_ATTRIBUTE(P1,"ERASE")  !Erase on delete
$ FFB = F$FILE_ATTRIBUTE(P1,"FFB")  !First free byte
$ FLH = F$FILE_ATTRIBUTE(P1,"FILE_LENGTH_HINT") !(record-count,data-byte-count)
$ GBC = F$FILE_ATTRIBUTE(P1,"GBC")  !Global buffer count
$ IF ORG .EQS. "IDX"
$ THEN MRN = F$FILE_ATTRIBUTE(P1,"MRN")  !Maximum record number
$      MRS = F$FILE_ATTRIBUTE(P1,"MRS")  !Maximum record size
$      NOA = F$FILE_ATTRIBUTE(P1,"NOA")  !Number of areas
$      NOK = F$FILE_ATTRIBUTE(P1,"NOK")  !Number of keys
$ ELSE MRC = 0
$      MRS = 0
$      NOA = 0
$      NOK = 0
$ ENDIF
$ RCK = F$FILE_ATTRIBUTE(P1,"RCK")  !Read-check enabled
$ WCK = F$FILE_ATTRIBUTE(P1,"WCK")  !Write-check enabled
$ !
$ EOF = F$STRING(EOF)
$ LEOF = 10 - F$LENGTH(EOF)
$ Siz = F$FAO("!#* !AS/!ZL", LEOF, EOF, ALQ)
$ IF FNLen .LT. FIL$FNWidth
$ THEN Line1 = F$FAO("!#AS !AS !AS", FIL$FNWidth, FN, Siz, BLS)
$ ELSE Line1 = F$FAO("!AS!/!#* !AS !AS", FN, FIL$FNWidth, Siz, BLS)
$ ENDIF
$ IF DEQ .GT. 0
$ THEN IF ScrWidth .GT. 80
$      THEN FW = ScrWidth - F$LENGTH(Line1) - 40 + HLCorrection
$      ELSE FW = ScrWidth - F$LENGTH(Line1) - 25 + HLCorrection
$      ENDIF
$      IF FW .LT. 0 THEN FW = 0
$      Line1 = Line1 + F$FAO("!#* Extent !ZL block!%S", FW, DEQ)
$ ENDIF
$ FW = 3
$ IF CTG THEN Line2 = F$FAO("!#* !AS", FW, "Contiguous")
$ IF CBT
$ THEN Tmp = "Continguous-best-try"
$      IF Line2 .EQS. ""
$      THEN Line2 = F$FAO("!#* !AS", FW, Tmp)
$      ELSE Line2 = Line2 + F$FAO(", !AS", Tmp)
$      ENDIF
$ ENDIF
$ IF ERA
$ THEN Tmp = "Erase on delete"
$      IF Line2 .EQS. ""
$      THEN Line2 = F$FAO("!#* !AS", FW, Tmp)
$      ELSE Line2 = Line2 + F$FAO(", !AS", Tmp)
$      ENDIF
$ ENDIF
$ IF GBC .GT. 0
$ THEN Tmp = "Global buffer"
$      IF Line2 .EQS. ""
$      THEN Line2 = F$FAO("!#* !ZL !AS!%S", FW, GBC, Tmp)
$      ELSE Line2 = Line2 + F$FAO(", !ZL !AS!%S", GBC, Tmp)
$      ENDIF
$ ENDIF
$ IF FFB .GT. 0
$ THEN Tmp = "First free byte:"
$      IF Line3 .EQS. ""
$      THEN Line3 = F$FAO("!#* !AS !ZL", FW, Tmp, FFB)
$      ELSE Line3 = Line3 + F$FAO(", !AS !ZL", Tmp, FFB)
$      ENDIF
$ ENDIF
$ IF ( FLH .NES. "" ) .AND. ( FLH .NES. "(-1,-1)" )
$ THEN Tmp = "File length hint:"
$      IF Line3 .EQS. ""
$      THEN Line3 = F$FAO("!#* !AS !AS", FW, Tmp, FLH)
$      ELSE Line3 = Line3 + F$FAO(", !AS !AS", Tmp, FLH)
$      ENDIF
$ ENDIF
$ IF ORG .EQS. "IDX"
$ THEN IF MRN .GT. 0
$      THEN Tmp = "Max record #:"
$           IF Line4 .EQS. ""
$           THEN Line4 = F$FAO("!#* !AS !ZL", FW, Tmp, MRN)
$           ELSE Line4 = Line4 + F$FAO(", !AS !ZL", Tmp, MRN)
$           ENDIF
$      ENDIF
$      IF MRS .GT. 0
$      THEN Tmp = "Max record size:"
$           IF Line4 .EQS. ""
$           THEN Line4 = F$FAO("!#* !AS !ZL byte!%S", FW, Tmp, MRS)
$           ELSE Line4 = Line4 + F$FAO(", !AS !ZL byte!%S", Tmp, MRS)
$           ENDIF
$      ENDIF
$      IF NOA .GT. 0
$      THEN Tmp = "Areas:"
$           IF Line4 .EQS. ""
$           THEN Line4 = F$FAO("!#* !AS !ZL", FW, Tmp, NOA)
$           ELSE Line4 = Line4 + F$FAO(", !AS !ZL", Tmp, NOA)
$           ENDIF
$      ENDIF
$      IF NOK .GT. 0
$      THEN Tmp = "Keys:"
$           IF Line4 .EQS. ""
$           THEN Line4 = F$FAO("!#* !AS !ZL", FW, Tmp, NOK)
$           ELSE Line4 = Line4 + F$FAO(", !AS !ZL", Tmp, NOK)
$           ENDIF
$      ENDIF
$ ENDIF
$ IF RCK
$ THEN Tmp = "Read-check enabled"
$      Line5 = F$FAO("!#* !AS", FW, Tmp)
$ ENDIF
$ IF WCK
$ THEN Tmp = "Write-check enabled"
$      IF Line5 .EQS. ""
$      THEN Line5 = F$FAO("!#* !AS", FW, Tmp)
$      ELSE Line5 = Line5 + F$FAO(", !AS", Tmp)
$      ENDIF
$ ENDIF
$ GOTO TP$Write
$ !
$TP$FID:              ! =====================================================
$ FID = F$FILE_ATTRIBUTE(P1,"FID")
$ IF Tp .EQS. ".DIR"
$ THEN IF F$FILE_ATTRIBUTES(P1,"DIRECTORY")
$      THEN FN = FN + " (VMS directory)"
$      ELSE FN = FN + " (not directory)"
$      ENDIF
$ ELSE isDir = ""
$ ENDIF
$ !
$ WFID = 16 - F$LENGTH(FID)
$ IF FNLen .LT. FIL$FNWidth
$ THEN Line1 = F$FAO("!#AS!AS",      FIL$FNWidth, FN, FID)
$ ELSE Line1 = F$FAO("!AS!/!#* !AS", FN, FIL$FNWidth, FID)
$ ENDIF
$ GOTO TP$Write
$ !
$TP$Journaling:       ! =====================================================
$ AI = F$FILE_ATTRIBUTE(P1,"AI")  !After-image journaling enabled
$ BI = F$FILE_ATTRIBUTE(P1,"BI")  !Before-image journaling enabled
$ RU = F$FILE_ATTRIBUTE(P1,"RU")  !Recovery-unit journaling enabled
$ JF = F$FILE_ATTRIBUTE(P1,"JOURNAL_FILE")  ! file is a Journal-file
$ !
$ FW = 3
$ IF JF
$ THEN Jou = "is a Journal-File"
$ ELSE Jou = ""
$ ENDIF
$ IF BI
$ THEN Tmp = "Before-Image"
$      Line2 = F$FAO("!#* !AS", FW, Tmp)
$ ENDIF
$ IF AI
$ THEN Tmp = "After-Image"
$      IF Line2 .EQS. ""
$      THEN Line2 = F$FAO("!#* !AS", FW, Tmp)
$      ELSE Line2 = Line2 + F$FAO(", !AS", Tmp)
$      ENDIF
$ ENDIF
$ IF RU
$ THEN Tmp = "Recovery-Unit"
$      IF Line2 .EQS. ""
$      THEN Line2 = F$FAO("!#* !AS", FW, Tmp)
$      ELSE Line2 = Line2 + F$FAO(", !AS", Tmp)
$      ENDIF
$ ENDIF
$ IF Line2 .NES. "" THEN Line2 = Line2 + " journaling enabled"
$ !
$ IF ( FNLen .LT. FIL$FNWidth ) .OR. ( Jou .EQS. "" )
$ THEN IF Jou .NES. ""
$      THEN Line1 = F$FAO("!#AS!AS", FIL$FNWidth, FN, Jou)
$      ELSE Line1 = F$FAO("!AS", FN)
$      ENDIF
$ ELSE Line1 = F$FAO("!AS!/!#* !AS", FN, FIL$FNWidth, Jou)
$ ENDIF
$ GOTO TP$Write
$ !
$TP$Management:       ! =====================================================
$ UIC = F$FILE_ATTRIBUTE(P1,"UIC")         ! File's owner UIC
$ PRO = F$FILE_ATTRIBUTE(P1,"PRO")         ! Protection string
$ NBU = F$FILE_ATTRIBUTE(P1,"NOBACKUP")    ! File is marked /NOBACKUP
$ MOV = F$FILE_ATTRIBUTE(P1,"MOVE")        ! File is moveable
$ Tmp = P1 - F$PARSE(P1,,,"VERSION","SYNTAX_ONLY") !Strip ;VERS for next test!
$ KNW = F$FILE_ATTRIBUTE(Tmp,"KNOWN")      ! File is a known-image
$ LCK = F$FILE_ATTRIBUTE(P1,"LOCKED")      ! File is deaccess-locked
$ SS  = F$FILE_ATTRIBUTE(P1,"STORED_SEMANTICS")  ! specified by /SEMANTICS=
$ PRE = F$FILE_ATTRIBUTE(P1,"PRESHELVED")  ! File is PreShelved
$ SHV = F$FILE_ATTRIBUTE(P1,"SHELVABLE")   ! File is Shelvable
$ SHD = F$FILE_ATTRIBUTE(P1,"SHELVED")     ! File is Shelved
$ !
$ FW = FIL$FNWidth - HLCorrection
$ PRO = F$EDIT(PRO,"COLLAPSE") - "YSTEM" - "WNER" - "ROUP" - "ORLD"
$ Line2 = F$FAO("!#* (!AS)", FW, PRO)
$ !
$ IF NBU THEN Line3 = F$FAO("!#* !AS", FW, "NoBackup")
$ IF MOV
$ THEN Tmp = "Moveable"
$      IF Line3 .EQS. ""
$      THEN Line3 = F$FAO("!#* !AS", FW, Tmp)
$      ELSE Line3 = Line3 + F$FAO(", !AS", Tmp)
$      ENDIF
$ ENDIF
$ IF KNW
$ THEN Tmp = "Known-Image"
$      IF Line3 .EQS. ""
$      THEN Line3 = F$FAO("!#* !AS", FW, Tmp)
$      ELSE Line3 = Line3 + F$FAO(", !AS", Tmp)
$      ENDIF
$ ENDIF
$ IF LCK
$ THEN Tmp = "Locked"
$      IF Line3 .EQS. ""
$      THEN Line3 = F$FAO("!#* !AS", FW, Tmp)
$      ELSE Line3 = Line3 + F$FAO(", !AS", Tmp)
$      ENDIF
$ ENDIF
$ !
$ IF PRE THEN Line4 = F$FAO("!#* !AS", FW, "PreShelved")
$ IF SHV
$ THEN Tmp = "Shelvable"
$      IF Line4 .EQS. ""
$      THEN Line4 = F$FAO("!#* !AS", FW, Tmp)
$      ELSE Line4 = Line4 + F$FAO(", !AS", Tmp)
$      ENDIF
$ ENDIF
$ IF SHD
$ THEN Tmp = "is Shelved"
$      IF Line4 .EQS. ""
$      THEN Line4 = F$FAO("!#* !AS", FW, Tmp)
$      ELSE Line4 = Line4 + F$FAO(", !AS", Tmp)
$      ENDIF
$ ENDIF
$ !
$ IF SS THEN Line5 = F$FAO("!#* !AS `[4m!AS[0m'", FW, "Semantics:", SS)
$ !
$ IF FNLen .LT. FIL$FNWidth
$ THEN Line1 = F$FAO("!#AS!AS",      FIL$FNWidth, FN, UIC)
$ ELSE Line1 = F$FAO("!AS!/!#* !AS", FN, FIL$FNWidth, UIC)
$ ENDIF
$ GOTO TP$Write
$ !
$TP$Write:
$ wso Line1
$ IF Line2 .NES. "" THEN wso Line2
$ IF Line3 .NES. "" THEN wso Line3
$ IF Line4 .NES. "" THEN wso Line4
$ IF Line5 .NES. "" THEN wso Line5
$ FIL$FCount == FIL$FCount + 1
$ !
$TP$Done:
$ EXIT 1
$ ENDSUBROUTINE  ! TheProcess
$ !
$ !
$Header:  SUBROUTINE
$ ! P1 : filespec
$ ! P2 : report option
$ SET NOON
$ FDev = F$PARSE(P1,,,"DEVICE","SYNTAX_ONLY")
$ FDir = F$PARSE(P1,,,"DIRECTORY","SYNTAX_ONLY")
$ Here = FDev + FDir
$ IF Here .NES. FIL$ThisDir
$ THEN IF P2 .EQS. "FID"
$      THEN i = 0
$           PFN = ""
$           Dir = FDir - "[" - "]"
$TPLoop:
$           Tmp = F$ELEMENT(i,Dot,Dir)
$           IF ( Tmp .EQS. Dot ) .OR. ( Tmp .EQS. "" ) .OR. ( i .GE. 20 )
$           THEN GOTO TPCont
$           ELSE i = i + 1
$                PFN = Tmp
$                GOTO TPLoop
$           ENDIF
$TPCont:
$           IF F$LOCATE(Dot,Dir) .LT. F$LENGTH(Dir)
$           THEN Tmp = Dot + PFN
$           ELSE Tmp = PFN
$           ENDIF
$           Par = Here - Tmp          ! remove ".subdir" from parent directory
$           i = F$LOCATE("[]",Par)  ! If this results in "empty dir []",
$           IF i .LT. F$LENGTH(Par) !   then add "000000" to form MFD
$           THEN Par = F$EXTRACT(0,i+1,Par) + "000000" + F$EXTRACT(i+1,F$LENGTH(Par)-i,Par)
$           ENDIF
$           PDir = Par + PFN + ".dir"
$           IF F$SEARCH(PDir) .NES. ""
$           THEN PFID = " - " + F$FILE_ATTRIBUTE(PDir,"FID")
$           ELSE PFID = ""
$           ENDIF
$      ELSE PFID = ""
$      ENDIF
$ !
$      FIL$ThisDir == Here
$      IF Highlight .EQS. "B"
$      THEN Here = F$FAO("[1m!AS[0m", Here)
$      ELSE IF Highlight .EQS. "U"
$           THEN Here = F$FAO("[4m!AS[0m", Here)
$           ENDIF
$      ENDIF
$      wso ""                   ! write a header
$      wso "Directory ''Here'", PFID
$      wso ""
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! Header
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  FILE$ATTRIBUTES is a special-purpose directory command file which lists
  the file attributes of one or more files.

  use: [1m@FILE$ATTRIBUTES fspec[,fspec...]                        -
                        [ /ORGANIZATION (D) | /DATETIME | /SIZE -
                          | /FID | /JOURNALING | /MANAGEMENT ]  -
                        [ /HIGHLIGHT[=BOLD|UNDERLINE] ]         -
                        [ /WIDTH=col_width ][0m

  where:

    P1 is a single filespec ([1mfname[0m), a file-list ([1mfname,fname,...[0m), or an
      indirection to a list of filespecs, one file per line ([1m@filelist[0m).
      Wildcards are supported for both [1mfname[0m and [1mfname,fname,...[0m forms,
      but not within indirect file lists.

    P2 is one of the following qualifiers:

      [1m/ORGANIZATION[0m (the default display if no qualifier is given) displays
      file organization attributes, including file and record attributes,
      record format, version limit (*), and revision count (*).

      [1m/DATETIME[0m (also [1m/TIME[0m) displays the file's creation date, revision
      date and revision count, last backup date, and date of expiration
      (shown only if expiration date is actually set).

      [1m/SIZE[0m displays various file size attributes, including the numbers of
      disk blocks used, allocated, default extension size (*), contiguous and
      contiguous-best-try (*), erase on delete (*), global buffer count (*),
      first free byte (*), file length hint (*), maximum record count (*),
      maximum record size (*), number of areas (*), and number of keys (*).

      [1m/FID[0m displays File IDentifier information, including the FID of the
      parent (containing) directory and the FID for each file.  Note that
      the FID of the parent directory is the Directory IDentifier (DID) of
      each file contained within that directory.

      [1m/JOURNALING[0m displays file journaling information, including status of
      before-image (*), after-image (*), and recovery-unit (*) journaling,
      and whether the file is itself a journal file (*).

      [1m/MANAGEMENT[0m displays various file management information, including
      the file's owner-UIC, its protection mask, whether the file is marked
      NoBackup (*), Moveable (*), is a Known-Image (*), and if it is deaccess-
      Locked (*).  Shelvable attributes are displayed if enabled, including
      PreShelved (*), Shelvable (*), and Shelved (*).  Stored Semantics (*)
      are displayed if enabled.

      (*) in the lists above denotes items which are displayed only if
          that value is applicable or specified for the file.

    One of the above qualifiers [4mmust[0m appear as P2 if /HIGHLIGHT or /WIDTH
    is also to be used.

    P3 and/or P4 are optional qualifiers:

      [1m/HIGHLIGHT=[BOLD|UNDERLINE][0m displays each filename in [1mbold[0m or
      [4munderline[0m video-rendition.  /HIGHLIGHT without a value means BOLD.

      [1m/WIDTH=col_width[0m specifies a wider filename field-width than
      the default of 32 characters.

    These qualifiers can appear in any order, but must be separated from
    the P2 qualifier by at least one blank (space).

  [1m[4mDisplay formats[0m:

  [1m[4m/ORGANIZATION[0m file attributes are displayed as:

    [1mfilename.typ;v (r)              {ORG, RAT, RFM}    [  ###][0m

  where ORG is the file's organization, RAT is its record attribute, and
  RFM is its record format.  If there is a version-limit set for the file,
  its value follows the attributes in square-brackets "[  ###]".  If the
  number of revisions to the file is greater than one, that revision count
  is displayed in parentheses "(r)" immediately following the filename.

  If the file's organization is either SEQ or IDX [4mand[0m its record format
  is either FIX, VAR or VFC, then the output format is:

    [1mfilename.typ;v (r)              {ORG, RAT, RFM(###)}    [  ###][0m

  For this type of display, if the file's organization is SEQ, then the
  longest record length (LRL) is shown in parentheses "(###)"; if the
  organization is IDX, then the value "(###)" shown is the maximum record
  size (MRS).  The Prolog version number (*) may appear if specified.

  If the file's record format is VFC, then the value "(###,#)" includes the
  size of the fixed-control area of the record.

  The file attribute values are:

      File organization
      ORG:  SEQ - Sequential
            REL - Relative
            IDX - Indexed

      Record attribute
      RAT:  CR  - Carriage return
            FTN - FORTRAN-style
            PRN - Print file
            ""  - None: if this field is empty, there
                  is no record attribute for the file

      Record format
      RFM:  FIX   - Fixed length records
            STM   - Stream (of bytes), each record delimited (terminated)
                    by any one of LF, CR, CR/LF, FF or TAB characters,
                    ignoring any leading zero-bytes (null characters)
            STMCR - Stream with CR (carriage-return) record termination
            STMLF - Stream with LF (line-feed) record termination
            VAR   - Variable length with a two-byte data-length (count)
                    field, data padded to an even number of bytes
            VFC   - Variable length with a fixed-length control field,
                    plus a two-byte data-length (count) field which
                    accounts for both the fixed-length control and the
                    variable data fields in each record, padded to an
                    even number of bytes
            UDF   - Undefined record format, treated as an undifferentiated
                    stream of bytes, with no record termination

  The normal (conventional) file attributes for common VMS file types are:

      Executable program files (binary .EXE),           {SEQ, , FIX}
      backup and Rdb save-sets (.BCK, .RBF),
      PolyCenter product distributions (.PCSI),
      and VMS libraries (.TLB, .HLB, .OLB).

      Object files (binary .OBJ) and VMS directory      {SEQ, , VAR}
      files (.DIR).

      Any text file (such as program source files,      {SEQ, CR, VAR}
      listings, DCL command files, etc.).
      [NOTE: Any text file which deviate from this
       norm (typically because it was created in
       and imported from a non-VMS environment) can
       be readily converted with FILE$EDIT.COM's
       [1m$ FIX TEXT filespec[0m command.]

      Common PC and/or UNIX file formats, including     {SEQ, CR, STM}
      .ZIP and .PDF, and almost any PC- or UNIX-        or {SEQ, CR, STMLF}
      generated text file.

      Attributes for various data files (.DAT, etc.)
      are, of course, application-dependent.

  [1m[4m/DATETIME[0m and [1m[4m/TIME[0m file attributes are displayed as:

    [1mfilename.typ;v                  created: 28-DEC-2001 19:13:41.64
                                    revised: 28-DEC-2001 19:13:42.49 (1)
                                     backup: 29-DEC-2001 05:07:38.03

    or:

    [1mfilename.typ;v                  created: 28-DEC-2001 19:13:41.64
                                    revised: 28-DEC-2001 19:13:42.49 (1)
                                     backup: 29-DEC-2001 05:07:38.03
                                    expires:  1-APR-2012 00:00:00.00[0m

  Creation and revision dates will normally be present, and the revision
  count is always displayed.  If the file has not been recorded as saved
  by the VMS BACKUP utility, that date will show "<no backup recorded>".
  If no expiration date is specified, the "expires:" line is omitted.

  [1m[4m/FID[0m file attributes are displayed as:

    [1mDirectory DEV:[DIR.SUBDIR] - (####,##,#)

    filename.typ;v (r)              (####,##,#)[0m

  where "(####,##,#)" is a triplet of integers which denotes the File
  IDentifier (FID) for the file.  Note that the FID for the parent
  (containing) directory or subdirectory is provided in the display's
  header line; the parent directory's FID is the Directory IDentifier
  (DID) for each file that the directory contains.

  [1m[4m/SIZE[0m file attributes are displayed as:

    [1mfilename.typ;v                         ###/###       Extent ## blocks
       Contiguous, Continguous-best-try, Erase on delete, Global buffers ##
       First free byte: ####, File length hint: (##,##)
       Max record #: ####, Max record size: ### bytes, Areas: #, Keys: #[0m

  [1m[4m/JOURNALING[0m file attributes are displayed as:

    [1mfilename.typ;v                 is a Journal-file
       Before-Image, After-Image, Recovery-Unit journaling enabled[0m

  [1m[4m/MANAGEMENT[0m file attributes are displayed as:

    [1mfilename.typ;v                 [UIC]
                                   (S:RWED,O:RWED,G:RWED,W:RWED)
                                   NoBackup, Moveable, Known-Image, Locked
                                   PreShelved, Shelvable, Shelved
                                   Semantics: `[4mstring[0m'

  From one to five lines are displayed for each file listed, and none, some
  or all of the information on lines two, three, four and five may be present,
  if that attribute is specified for the file.  It is possible that, for a
  particular display, a file has none of the attributes specified or enabled,
  and only the file's name, type and version are listed -- this is OK.

  For any display, if a particular file is locked for exclusive access by
  another process, the message "<file access conflict>" is displayed, and
  no other information is available for that file until it is released by
  the process which has locked it.

  [1m[4mExamples[0m:

  $ FAT == "@site$utils:file$attributes" !defined in SITE$UTILS:FILE$SETUP.COM

  $ [1mFAT ?[0m                                ! displays this help text

  $ [1mFAT login.com[0m                        ! displays /ORGANIZATION attributes,
                                         ! no highlighting, default width

  $ [1mFAT sys$system:*.dat /DATE /HIGH[0m     ! displays date-stamps for all *.DAT
                                         ! in SYS$SYSTEM, with filenames in
                                         ! bold rendition

  $ [1mFAT *.com /SIZE /WIDTH=50[0m            ! displays size attributes, no
                                         ! highlighting, with the filename
                                         ! field-width expanded to 50 columns

  $ [1mFAT [-...]*.dir /FID /HIGH=UNDER[0m     ! displays FID information for all
                                         ! *.DIR directory files in a tree,
                                         ! with underline highlighting

  $ [1mFAT *.com /JOURNAL /HIGH /WIDTH=44[0m   ! yes, you can use all qualifiers
                                         ! at one time...

  $ [1mFAT site$utils:*.exe /MANAGE[0m         ! displays MANAGEMENT information,
                                         ! again with just the defaults

$ !
$ GOTO Done
$ !
