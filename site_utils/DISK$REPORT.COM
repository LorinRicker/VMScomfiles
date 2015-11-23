$ ! DISK$REPORT.COM --  Creates a report of dev:[dir] tree sizes,  'F$VERIFY(0)'
$ !                     sorted by size.
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1990-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  Use: @DISK$REPORT [/OUTPUT=outfile] [device] [exclusion_list] [flags]
$ !
$ !  P1: Device or search-list of devices (can be physical device or rooted).
$ !      Default: "Disks$Display".
$ !  P2: Exclusion_list of directories to ignore.  Just root directory names
$ !      as a comma-separated list, no brackets [].  Used to exclude alias or
$ !      "shadow" directories such as the VMScluster directory structures.
$ !      For sys$sysdevice, default exception list is "VMS$COMMON,SYSEXE,SYSn"
$ !      where n > 0 (i.e., only process [SYS0...] VMS directory tree,
$ !      plus any other non-VMS directory trees.)
$ !  P3: [VERBOSE[,HIGHLIGHT]]
$ !       "Verbose" generates an info-message for each directory processed.
$ !       "Highlight" forces rendition to output file (non-terminal output).
$ !
$ ON ERROR THEN GOTO Done
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ Prv = F$SETPRV("READALL")
$ @site$utils:utility START DR
$ D$FF[0,32]= 12
$ D$FF[0,1]:='D$FF'
$ D$Page = 1
$ !
$ ! Determine P3 qualifier settings:
$ D$Ver  = "FALSE"
$ D$Term = F$GETDVI("sys$output","TRM")  !output to TT: or to a file?
$ I = 0
$PLoop:
$ DR$V == F$ELEMENT(I,",",P3)
$ IF DR$V .EQS. "," THEN GOTO P0
$ @site$utils:utility CMDPARSE "''DR$V'" "V" -
                      "NONE" "VERBOSE  |HIGHLIGHT|NONE     "
$ IF DR$V .EQS. "VERBOSE"   THEN D$Ver  = "TRUE"
$ IF DR$V .EQS. "HIGHLIGHT" THEN D$Term = "TRUE"  !force rendition to file
$ I = I + 1
$ GOTO PLoop
$ !
$P0:
$ ! Set up the device(s) to process; is this a rooted directory log-name?
$ IF P1 .EQS. ""
$ THEN P1 = "disks$display"
$ ELSE IF F$LOCATE("[",P1) .LT. F$LENGTH(P1)
$      THEN D = P1 - "]" + ".]"
$           P1 = "DR$Concealed"
$           DEFINE /PROCESS /NOLOG /TRANSLATION=CONCEAL 'P1' 'D'
$      ELSE P1 = P1 - ":"
$      ENDIF
$ ENDIF
$ D$Concealed = ( F$TRNLNM(P1,,,,,"CONCEALED") ) -
                .AND. .NOT. ( F$TRNLNM(P1,,,,,"TERMINAL") )
$ MaxI = F$TRNLNM(P1,,,,,"MAX_INDEX")
$ !
$ ! Measure space-used for each device/directory root [dir...]:
$ I = 0
$Loop0:     !Outer loop
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ IF ( I .GT. MaxI ) THEN GOTO Done
$ D$Total   = 0
$ D$UsedPct = 0
$ D$Device = F$TRNLNM(P1,,I)    !"next" device
$ ! Device must exist and it must be a disk:
$ IF .NOT. F$GETDVI(D$Device,"EXISTS") THEN GOTO L3
$ IF F$GETDVI(D$Device,"DEVCLASS") .NE. 1 THEN GOTO L3
$ IF D$Device .EQS. ""
$ THEN GOTO L3                  !no such device: skip to next, if any
$ ELSE IF D$Concealed
$      THEN D$Device = P1 + ":"
$      ELSE D$Device = F$PARSE(D$Device,,,"DEVICE","SYNTAX_ONLY")
$      ENDIF
$      D$Root = D$Device + "[000000]"
$ ENDIF
$ !
$ D$Disk     = F$GETDVI(D$Device,"FULLDEVNAM") - "_"
$ D$Capacity = F$GETDVI(D$Device,"MAXBLOCK")
$ IF D$Capacity .EQ. 0 THEN D$Capacity = 1
$ !
$ D$Tmp  = D$Disk - ":"
$ D$Sort = "sys$scratch:DR$''D$Tmp'.sorted"
$ D$Tmp  = "sys$scratch:DR$''D$Tmp'.tmp"
$ OPEN /WRITE DR$Tmp 'D$Tmp'
$ D$Incomplete = "FALSE"
$ !
$Loop1:     !Inner loop
$ ! Measure size for this [dir...]
$ DN = F$SEARCH("''D$Root'*.dir;1")     !"next" [dir...]
$ IF DN .EQS. "" THEN GOTO L1           !Done with this device
$ D$Dir = F$PARSE(DN,,,"NAME","SYNTAX_ONLY")
$ CALL TestExcluDir "''D$Dir'" "''P2'"
$ IF DR$SkipDir
$ THEN IF D$Dir .NES. "000000" .AND. .NOT. D$Incomplete
$      THEN D$Incomplete = "TRUE"
$      ENDIF
$      GOTO Loop1
$ ENDIF
$ D$Dir     = "[" + D$Dir + "...]"
$ D$DirTree = D$Device + D$Dir
$ IF D$Ver THEN WRITE sys$error "%DISK$REPORT-I, ''D$DirTree'"
$ CALL TreeSize 'D$DirTree'
$ siz       = DR$Size / 1000    !Scale values to prevent 32-bit math overflow
$ cap       = D$Capacity / 1000 ! (just want percentages "in the ballpark")
$ D$Pct     = siz * 1000 / cap
$ D$X       = D$Pct / 10
$ D$UsedPct = D$UsedPct + D$Pct
$ D$Total   = D$Total + DR$Size
$ Line = F$FAO("!8SL  !3SL.!1SL%  !44AS", DR$Size, D$X, D$Pct-(D$X*10), D$Dir)
$ WRITE DR$Tmp Line
$ GOTO Loop1
$ !
$L1:
$ ! Measure "overhead" in MFD or rooted-lnm [000000]:
$ IF D$Concealed
$ THEN D$Dir = "Root directory overhead [000000]"
$ ELSE D$Dir = "Disk's MFD overhead [000000]"
$ ENDIF
$ IF D$Term
$ THEN @site$utils:utility HIGHLIGHT "''D$Dir'" BOLD
$      D$Dir = DR$String
$ ENDIF
$ CALL TreeSize 'D$Device'[000000]
$ D$Pct     = DR$Size * 1000 / D$Capacity
$ D$X       = D$Pct / 10
$ D$UsedPct = D$UsedPct + D$Pct
$ D$Total   = D$Total + DR$Size
$ Line = F$FAO("!8SL  !3SL.!1SL%  !44AS", DR$Size, D$X, D$Pct-(D$X*10), D$Dir)
$ WRITE DR$Tmp Line
$ !
$ ! Calculate what's left over as unused:
$ IF D$Concealed
$ THEN D$Dir = "Other directories on disk"
$ ELSE IF D$Incomplete
$      THEN D$Dir = "Unanalyzed disk space"
$      ELSE D$Dir = "Unused disk space"
$      ENDIF
$ ENDIF
$ IF D$Term
$ THEN @site$utils:utility HIGHLIGHT "''D$Dir'" BOLD
$      D$Dir = DR$String
$ ENDIF
$ D$Pct     = 1000 - D$UsedPct
$ D$X       = D$Pct / 10
$ DR$Size  == D$Capacity - D$Total
$ Line = F$FAO("!8SL  !3SL.!1SL%  !44AS", DR$Size, D$X, D$Pct-(D$X*10), D$Dir)
$ WRITE DR$Tmp Line
$ IF F$TRNLNM("DR$Tmp") .NES. "" THEN CLOSE DR$Tmp
$ SORT /KEY=(POS:1,SIZ:8,DESC) 'D$Tmp' 'D$Sort'  !Sort against block-size field
$ DELETE 'D$Tmp';*
$ !
$L0:
$ ! Generate the output report --
$ ! sys$output may be redirected by com-file qualifier "/OUTPUT=outfile":
$ OPEN /READ DR$Srt 'D$Sort'
$ IF D$Page .GT. 1 THEN WRITE sys$output D$FF
$ WRITE sys$output ""
$ WRITE sys$output ""
$ IF D$Concealed
$ THEN L = F$TRNLNM(P1)
$ ELSE L = D$Device
$ ENDIF
$ IF D$Term
$ THEN @site$utils:utility HIGHLIGHT "''L'" BOLD
$      L = DR$String + " (" + D$Disk + ")"
$      N = 73 - ( F$LENGTH(L) - 8 )  !"8" adjusts for rendition-chars
$ ELSE L = L + " (" + D$Disk + ")"
$      N = 73 - F$LENGTH(L)
$ ENDIF
$ WRITE sys$output F$FAO("!AS!#* Page !2SL", L, N, D$Page)
$ WRITE sys$output ""
$ L = "   Space Used   "
$ N = "Directory Tree              "
$ IF D$Term
$ THEN @site$utils:utility HIGHLIGHT "''L'" UNDERLINE
$      L = DR$String
$      @site$utils:utility HIGHLIGHT "''N'" UNDERLINE
$      N = DR$String
$      WRITE sys$output L, "  ", N
$ ELSE WRITE sys$output L, "  ", N
       WRITE sys$output F$FAO("!#*-  !#*-",F$LENGTH(L),F$LENGTH(N))
$ ENDIF
$ !
$Loop2:
$ ! Copy the sorted output to the final output file:
$ READ /END_OF_FILE=L2 DR$Srt L
$ WRITE sys$output L
$ GOTO Loop2
$ !
$L2:
$ IF F$TRNLNM("DR$Srt") .NES. "" THEN CLOSE DR$Srt
$ DELETE 'D$Sort';*
$ D$Page = D$Page + 1
$L3:   !ready for next device
$ I = I + 1
$ GOTO Loop0
$ !
$Done:
$ Status = $STATUS
$ IF F$TRNLNM("DR$Tmp")       .NES. "" THEN CLOSE DR$Tmp
$ IF F$TRNLNM("DR$Concealed") .NES. "" THEN DEASSIGN /PROCESS DR$Concealed
$ @site$utils:utility EXIT
$ Prv = F$SETPRV(Prv)
$ EXIT Status
$ !
$ !
$TreeSize:  SUBROUTINE
$ ! P1: the directory tree to size-up
$ ON WARNING THEN GOTO TSerror
$ Tmp = "sys$scratch:DR$TreeSize.tmp"
$ DEFINE /USER_MODE sys$output nl: !suppress "%DIRECT-W-NOFILES, no files found"
$ DEFINE /USER_MODE sys$error  nl:
$ DIRECTORY /SIZE=ALLOCATION /GRAND /OUTPUT='Tmp' 'P1'
$ OPEN /READ /ERROR=TS0 f 'Tmp'
$ READ /END_OF_FILE=TS1 f L   !First line is blank
$ READ /END_OF_FILE=TS1 f L   !The data line
$ L = F$ELEMENT(2,",",L)      !"Grand total of X directories, Y files, Z blocks"
$ L = F$ELEMENT(0," ",F$EDIT(L,"TRIM,COMPRESS"))
$ DR$Size == F$INTEGER(L)     !Convert "Z blocks" to an integer
$ Status = 1
$ GOTO TSdone
$ !
$TS0:
$ Status = $STATUS
$ WRITE sys$output "%DISK$REPORT-E-TreeSize, could not open temp-file ''DR$Tmp'"
$ GOTO TSexit
$TS1:
$ Status = $STATUS
$ WRITE sys$output "%DISK$REPORT-E-TreeSize, premature EOF in ''DR$Tmp'"
$ GOTO TSexit
$TSerror:
$ Status = $STATUS
$TSexit:
$ DR$Size == 0  !error, or no files in this particular directory
$ !
$TSdone:
$ IF F$TRNLNM("f") .NES. "" THEN CLOSE f
$ DELETE 'Tmp';*
$ EXIT Status
$ ENDSUBROUTINE  !TreeSize
$ !
$TestExcluDir:  SUBROUTINE
$ ! P1: directory name to test
$ ! P2: list of exclusion-directories for current device
$ ! If device is sys$sysdevice, then exclude "shadow" VMS trees:
$ !  VMS$COMMON, SYSEXE, SYS1, SYS2, ..., SYSFFFF,
$ !  but include SYS0, SYSLOST, and anything else beginning with "SYS".
$ SET NOON
$ IF ( D$Device .EQS. "SYS$SYSDEVICE:" ) -
  .OR. ( D$Disk .EQS. F$TRNLNM("sys$sysdevice") )
$ THEN IF ( P1 .EQS. "VMS$COMMON" ) .OR. ( P1 .EQS. "SYSEXE" )
$      THEN DR$SkipDir == "TRUE"  !but ignore the "shadow" VMS trees
$           EXIT 1
$      ELSE IF F$EXTRACT(0,3,P1) .EQS. "SYS"
$           THEN P1L = F$LENGTH(P1)
$                IF ( P1L .GE. 4 ) .AND. ( P1L .LE. 7 ) !"SYS(0..FFFF)"?
$                THEN X = "%X" + F$EXTRACT(3,P1L-3,P1)  !hex
$                     IF F$INTEGER(X) .EQ. 0
$                     THEN !This is SYS0, SYSLOST, SYS1XX, SYSarb, ...
$                          GOTO T0    !check user's exclude-list
$                     ELSE DR$SkipDir == "TRUE"  !Skip SYS1,...,SYSFFFF
$                          EXIT 1
$                     ENDIF
$                ENDIF
$           ENDIF
$      ENDIF
$ ENDIF
$T0:
$ Dr  = "," + F$EDIT(P1,"COLLAPSE,UPCASE") + ","
$ P2  = "," + F$EDIT(P2,"COLLAPSE,UPCASE") + ",000000,"
$ DR$SkipDir == ( F$LOCATE(Dr,P2) .LT. F$LENGTH(P2) )
$ EXIT 1
$ ENDSUBROUTINE
$ !
$Ctrl_C:
$Ctrl_Y:
$ RETURN %X2C
