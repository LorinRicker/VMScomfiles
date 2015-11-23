$ ! RDB_LOGICALS.COM -- Setup per-site Rdb/VMS logicals            'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2003 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1993-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$RdbLogicals:    ! Rdb/VMS options controlled by logicals:
$                ! Instructions: Activate an option by uncommenting
$                ! and editing an appropriate value for each/any of
$                ! the logical names below.  Consult the Rdb/VMS
$                ! documentation set for details.
$ !
$ SET NOON
$ Prv = F$SETPRV("CMKRNL,SYSNAM,SYSPRV")
$ DEFINE = "DEFINE /SYSTEM /EXECUTIVE_MODE /NOLOG"
$ !
$ @site$utils:utility INSTALL "sys$message:rdbmsgs.exe" "" "/SHARE"
$ !
$ ! Disables two-phase commit protocol       Default: FALSE
$ !!DEFINE SQL$Disable_Context               TRUE
$ !
$ ! Control for contents of a Bugcheck Dump file
$ !  Include the letter(s) to omit from dump:
$ !    C  Clients
$ !    G  Global buffers
$ !    H  Header/root file information
$ !    K  KODA
$ !    L  Locks
$ !    P  Pages (global buffers)
$   DEFINE RDM$Bugcheck_Ignore_Flags         "GLP"
$ !
$ ! Location of user's RUJ files             Default: user's sys$login
$ !!DEFINE RDMS$RUJ                          dev:[RdB_RUJ]
$ !
$ ! Buffer size for network transfers        Default: 2048 bytes
$ !!DEFINE RDB$Remote_Buffer_Size            10000
$ !
$ ! Per-user # of database buffers           Default: NUMBER OF BUFFERS (20)
$ !!DEFINE RDM$Bind_Buffers                  100
$ !
$ ! Per-process checkpoint interval          Default: f(AIJ block size,timeout)
$ !!DEFINE RDM$Bind_Ckpt_Trans_Limit         10  !checkpoint each N transactions
$ !
$ ! Pre-extends RUJ files                    Default: 100 blocks
$ !!DEFINE RDM$Bind_RUJ_Extend_Blkcnt        1000
$ !
$ ! Enables contiguous VM allocations        Default: 0 (disabled, 1 enables)
$ !!DEFINE RDM$Bind_VM_Segment               1
$ !
$ ! Specifies default wait interval          Default: DEADLOCK_WAIT (10 sec)
$ !!DEFINE RDM$Bind_Lock_Timeout_Interval    15
$ !
$ ! Limits # of rows returned by query       Default: no limit
$ !!DEFINE RDM$Bind_QG_Rec_Limit             1000
$ !
$ ! Query compile time limit                 Default: no limit
$ !!DEFINE RDM$Bind_QG_Timeout               15
$ !
$ ! Buffer space for segmented strings       Default: 10,000 bytes, 64 count
$ !!DEFINE RDMS$Bind_Segmented_String_Buffer 2000000  !2 Mbyte
$ !!DEFINE RDMS$Bind_Segmented_String_Count  100
$ !
$ ! # of work files for sorting              Default: 2 files, max 10
$ !!DEFINE RDM$Bind_Sort_Workfiles           3
$ !  DEFINE SortWork0  dev:                  !defaults to SYS$LOGIN,
$ !  DEFINE SortWork1  dev:                  ! but can be pointed at any
$ !  DEFINE SortWork2  dev:                  ! available disk; no directory
$ !  DEFINE SortWork3  dev:                  ! needed, implies hidden file
$ !   ...
$ !  DEFINE SortWork9  dev:
$ !
$ ! Metadata change convert/validates data   Default: 0 (disabled, 1 enables)
$ !!DEFINE RDM$Bind_Validate_Change_Field    1
$ !
$ ! Location of Match workfiles              Default: user's sys$login
$ !!DEFINE RDM$Bind_Work_File                dev:[Rdb_Work]
$ !
$ ! Amount of VM allocated to Matching       Default: 10,000 bytes, max 65,000
$ !!DEFINE RDM$Bind_Work_VM                  25000
$ !
$ Prv = F$SETPRV(Prv)
$ EXIT
