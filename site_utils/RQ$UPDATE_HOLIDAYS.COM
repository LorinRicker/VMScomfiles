$ ! RQ$UPDATE_HOLIDAYS.COM -- maintenance for the "rq$holiday" data file
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2003 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1988-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ RQ$Holiday = F$PARSE("rq$holiday","sys$disk:[]holiday.dat;")
$ RQ$Holiday = RQ$Holiday - F$PARSE(RQ$Holiday,,,"VERSION","SYNTAX_ONLY")
$ !
$ DEFINE /USER_MODE sys$input sys$command
$ KED 'RQ$Holiday'
$ !
$ CONVERT /FDL=sys$input 'RQ$Holiday' 'RQ$Holiday'
SYSTEM
	SOURCE			VAX/VMS

FILE
	ORGANIZATION		indexed

RECORD
	CARRIAGE_CONTROL	carriage_return
	FORMAT			variable
	SIZE			64

AREA 0
	ALLOCATION		3
	BEST_TRY_CONTIGUOUS	yes
	BUCKET_SIZE		1
	EXTENSION		1

AREA 1
	ALLOCATION		0
	BEST_TRY_CONTIGUOUS	yes
	BUCKET_SIZE		1
	EXTENSION		1

KEY 0
	CHANGES			no
	DATA_AREA		0
	DATA_FILL		100
	DATA_KEY_COMPRESSION	no
	DATA_RECORD_COMPRESSION	no
	DUPLICATES		no
	INDEX_AREA		1
	INDEX_COMPRESSION	no
	INDEX_FILL		100
	LEVEL1_INDEX_AREA	1
	PROLOG			3
	SEG0_LENGTH		10
	SEG0_POSITION		0
	TYPE			string
$ !
$ PURGE 'RQ$Holiday'
$ !
$Done:
$ EXIT
