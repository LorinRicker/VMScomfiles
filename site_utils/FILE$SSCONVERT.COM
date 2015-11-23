$ ! FILE$SSCONVERT.COM --                                          'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2005 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1999-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !  v3.0 - 02/05/2001, Added trick of reading the save-set header record
$ !                   at bit-offset 320 (32-bit integer) to determine the
$ !                   /BLOCK_SIZE which created the save-set, with fall-back
$ !                   logic and prompting.  This is a much stronger technique
$ !                   which eliminates the built-in assumption that "most"
$ !                   save-sets will be created at /BLOCK_SIZE=8192.  LMR
$ !  v2.0 - 1997-99,  Added use of SET FILE /ATTR=() as primary replacement
$ !                   for COPY /OVERLAY, retaining older trick for pre-VMSv7
$ !                   sites.
$ !  v1.0 - pre-1997, Basic conversion with COPY /OVERLAY trick.  Base
$ !                   assumption is that save-sets created with FILE$XFER.COM
$ !                   and related tools will be at /BLOCK_SIZE=8192.
$ !
$ ! use: @FILE$SSCONVERT Saveset [List_flag] [Block_Size] [Verify]
$ !
$ !  P1: Saveset name
$ !  P2: Listing flag [ YES | LIST | TRUE | 1 ]
$ !  P3: BACKUP block-size (D = /BLOCK_SIZE=8192)
$ !  P4: Verify [ YES | VERIFY | TRUE | 1 ]
$ !
$ ON CONTROL THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ !
$ wso = "WRITE sys$output"
$ Me  = F$ENVIRONMENT("PROCEDURE")
$ Fac = F$PARSE(Me,,,"NAME","SYNTAX_ONLY")
$ DSSet  = "X.BCK"
$ DBSize = "8192"
$ Answer = "No"
$ Lst = P2 .OR. (F$EXTRACT(0,1,P2) .EQS. "L")
$ Ver = P4 .OR. (F$EXTRACT(0,1,P4) .EQS. "V") .OR. F$TRNLNM("TOOLS$Debug")
$ VMSv7 = ( F$GETSYI("VERSION") .GES. "V7." )
$ !
$P10:
$ IF P1 .EQS. ""
$ THEN READ sys$command P1 /END_OF_FILE=Done /PROMPT="Save-set name <''DSSet'>: "
$      IF P1 .EQS. "" THEN P1 = DSSet
$      READ sys$command Answer /END_OF_FILE=D0 /PROMPT="Generate listing for save-set <N>? "
$ ENDIF
$ SaveSet = F$PARSE(P1,DSSet,"sys$disk:[].bck")
$ IF F$SEARCH(SaveSet) .EQS. ""
$ THEN wso "%''Fac'-E-FNF, cannot find save-set ''SaveSet'"
$      GOTO P10
$ ENDIF
$ SSet = F$PARSE(SaveSet,,,"NAME","SYNTAX_ONLY") -
       + F$PARSE(SaveSet,,,"TYPE","SYNTAX_ONLY")
$ Listing = F$PARSE(SaveSet,,,"DEVICE","SYNTAX_ONLY") -
          + F$PARSE(SaveSet,,,"DIRECTORY","SYNTAX_ONLY") -
          + F$PARSE(SaveSet,,,"NAME","SYNTAX_ONLY") -
          + ".LIS"
$ Junk    = F$PARSE("file$ssjunk",SaveSet,"sys$disk:[].bck",,"SYNTAX_ONLY")
$ SSOld   = F$PARSE(SaveSet,,,"DEVICE","SYNTAX_ONLY") -
          + F$PARSE(SaveSet,,,"DIRECTORY","SYNTAX_ONLY") -
          + F$PARSE(SaveSet,,,"NAME","SYNTAX_ONLY") -
          + F$PARSE(SaveSet,,,"TYPE","SYNTAX_ONLY") + "_OLD"
$ !
$ ! BACKUP /BLOCK_SIZE limits: 2048 >= BSize <= 65535
$P30:
$ IF ( P3 .EQS. "" ) .AND. VMSv7
$ THEN ! Try to determine save-set's block-size directly:
$      SET FILE 'SaveSet' /NOLOG -
         /ATTRIBUTES=(ORG:SEQ,RFM:FIX,RAT:NONE,LRL:512,MRS:512)
$      OPEN /ERROR=SSOpenErr /READ /SHARE=READ ss 'SaveSet'
$      READ /ERROR=SSReadErr /END_OF_FILE=SSReadErr ss Rec
$      CLOSE ss
$      BSize = 0
$      BBH_L_BLOCKSIZE = %X28 * 8                 ! 40 * 8 = 320 (bit offset)
$      BSize = F$CVUI( BBH_L_BLOCKSIZE, 32, Rec ) ! Extract 32 bits at offset
$      IF Ver
$      THEN SHOW SYMBOL BBH_L_BLOCKSIZE
$           SHOW SYMBOL BSize
$           !!! SHOW SYMBOL Rec  ! uncomment for curiosity-testing only...
$      ENDIF
$      IF ( BSize .LT. 2048 ) .OR. ( BSize .GT. 65535)
$      THEN wso "%''Fac'-E-BAD_BLOCKSIZE, attempt to read save-set's internal blocksize"
$           wso F$FAO( "!33* returned illegal BACKUP /BLOCK_SIZE of [1m!SL[0m", BSize )
$           wso F$FAO( "!33* (out of range 2048..65535)" )
$           P3 = "0"  !force interactive prompt...
$           GOTO P30
$      ENDIF
$      !!!BSize = DBSize
$ ELSE IP3 = F$INTEGER(P3)              ! returns zero (0) if P3 = ""
$      IF ( IP3 .GE. 2048 ) .AND. ( IP3 .LE. 65535 )
$      THEN BSize = P3
$      ELSE READ sys$command P3 /END_OF_FILE=Done -
              /PROMPT="Save-set block_size (between 2048 and 65535) <[1m''DBSize'[0m>: "
$           IF P3 .EQS. "" THEN P3 = DBSize
$           GOTO P30
$      ENDIF
$ ENDIF
$ !
$ wso ""
$ wso "%''Fac'-I-CONVERT, converting ''SSet'..."
$ wso ""
$ IF VMSv7
$ THEN ! If SET FILE/ATTR=() syntax exists, use it... alters the file's header:
$      Dummy = F$VERIFY(Ver)
$      SET FILE 'SaveSet' /LOG -
         /ATTRIBUTES=(ORG:SEQ,RFM:FIX,RAT:NONE,LRL='BSize',MRS='BSize')
$      Dummy = 'F$VERIFY(0)'
$ ELSE ! COPY/OVERLAY is much less efficient, but is VMS version-independent:
$      IF F$FILE_ATTRIBUTES(SaveSet,"EOF") .GE. 5000 - ! User may get impatient...
       THEN wso "''Fac'-I-CONVERTING, large ''SSet'... please wait"
$      Dummy = F$VERIFY(Ver)
$      BACKUP /INTERCHANGE /NOCRC /BLOCK_SIZE='BSize' 'Me' 'Junk' /SAVE
$      COPY /OVERLAY 'SaveSet' 'Junk'
$      RENAME /NOLOG 'SaveSet' 'SSOld'
$      RENAME /NOLOG 'Junk' 'SaveSet'  !we don't delete 'Junk', just in case...
$      Dummy = 'F$VERIFY(0)'
$ ENDIF
$ ! This next step tells us if we've been successful:
$ IF F$FILE_ATTRIBUTES(SaveSet,"EOF") .GE. 5000 -   ! User may get impatient...
  THEN wso "''Fac'-I-LISTING, large ''SSet'... please wait"
$ IF Ver
$ THEN wso ""
$      wso "$ BACKUP ''SaveSet' /SAVE /LISTING=''Listing'"
$ ENDIF
$ BACKUP 'SaveSet' /SAVE /LIST='Listing'
$ Stat = $STATUS
$ !
$ IF Stat
$ THEN IF Lst .OR. F$PARSE(Answer,"No",,"NAME","SYNTAX_ONLY")
$      THEN TYPE /PAGE 'Listing'
$      ENDIF
$ ELSE wso F$FAO( "%!AS-E-CVTFAIL, failed to convert !AS to blocksize !SL", -
                   Fac, SSet, BSize )
$ ENDIF
$ !
$D0:
$ IF Ver
$ THEN wso ""
$      wso "''Fac'-S-SUCCESS, conversion of ''SSet' successful"
$      wso ""
$      wso "  You can now restore files to target directories with [1mVMS BACKUP[0m; for example:"
$      wso ""
$      wso "  $ [1mBACKUP ''SSet'/SAVE dev:[*...] /LOG[0m"
$      wso ""
$ ENDIF
$ !
$Done:
$ EXIT  !'F$VERIFY(0)'
$ !
$SSOpenErr:
$ Stat = $STATUS
$ SET NOON
$ wso "%''Fac'-E-OPENERR, error opening save-set ''SaveSet'"
$ EXIT Stat
$ !
$SSReadErr:
$ Stat = $STATUS
$ SET NOON
$ wso "%''Fac'-E-READERR, error reading save-set ''SaveSet'"
$ EXIT Stat
$ !
$Ctrl_Y:
$ RETURN %X2C
