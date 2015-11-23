$ sv = 'f$verify(0)'
$ ! This is a command file to translate a hex message number
$ ! to the appropriate message text for any number defined in
$ ! any of the message files in SYS$MESSAGE: directory.  The
$ ! command file requires one parameter.  That parameter is
$ ! the message number.  For example:
$ !
$ !     $ @MESSAGE 1077808A
$ !     message found in SYS$COMMON:[SYSMSG]CLIUTLMSG.EXE;1
$ !     %SET-E-NOTSET, error modifying !AS
$ !
$ ! The command file returns the message file in which the
$ ! message was found and the associated text.  The text
$ ! string is standard VMS FAO format as described in the
$ ! system service manual on the $FAO system service.
$ !
$ ! Written by Paul Williams            11-NOV-1987
$ ! and modified a few times since
$ !
$ if p1 .eqs. "" then inquire p1 "Message number (in HEX)"
$ if p1 .eqs. "" then exit 1 + f$verify('sv')
$ set noon                                      ! continue on all errors
$ oldprv = f$setprv("sysprv")                   ! get SYSPRV if possible
$ fl = f$search ("sys$message:sysmgtmsg.exe;")  ! do this file first since
$ set message 'fl                               !       it is most common
$ msg = f$message (%x'p1')                      ! get message text
$ if f$locate ("-NOMSG,", msg) .eq. f$length (msg) then goto found
$again:                                         ! try next file
$ fl = f$search ("sys$message:*.exe;")          ! use all files availible
$ if fl .eqs. "" then goto nomsg                ! no more files?
$ set message 'fl                               ! set message file
$ if $status then goto cont                     ! check for error on above message file
$ write sys$output "file with problem is ''fl'" ! tell user which file is unavailible
$ write sys$output ""                           ! blank line
$ goto again                                    ! continue looking
$cont:
$ msg = f$message (%x'p1')                      ! get message text
$ if f$locate ("-NOMSG,", msg) .ne. f$length (msg) then goto again
$found:                                         ! message was found
$ write sys$output "message found in ''fl'"     !       tell user where
$ write sys$output msg                          !       and what
$done:
$ set proc/priv='oldprv                         ! restore privileges
$ exit 1 + f$verify('sv')                       ! all done
$nomsg:                                         ! message not found
$ write sys$output "message not found, probably a user or 3d party defined message"
$ goto done                                     ! do normal clean up
