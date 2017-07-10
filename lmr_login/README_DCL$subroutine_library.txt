README for
DCL$SUBROUTINE_LIBRARY.COM

The command file DCL$SUBROUTINE_LIBRARY.COM is a callable library of useful
DCL script-procedures, each of which can be invoked or "called" by other,
user-written command files.

INSTALLATION:
------------
The command file is easy to install, and can be copied to (placed) in any
convenient public or user-private directory or subdirectory:

    $ COPY DCL$SUBROUTINE_LIBRARY.COM disk$<somewhere>:[<somedirectory>]
    $ SET SECURITY /PROT=(S:RWED,O:RWED,G,W:RE) -
        disk$<somewhere>:[<somedirectory>]DCL$SUBROUTINE_LIBRARY.COM

This command-file is "environment aware," meaning that when you activate
it for the first time (in a logged-in/interactive or batch process), it
creates a small group of process logical names and a global symbol to
facilitate additional "calls" to the library's DCL procedures.

USE:
---
To "activate" or "set-up" DCL$SUBROUTINE_LIBRARY, just call it once like
this, either interactively (on your command line), or add this line to
your LOGIN.COM command file for routine use:

    $ @disk$<somewhere>:[<somedirectory>]DCL$SUBROUTINE_LIBRARY setup

The "setup" parameter accomplishes the per-process set-up and definitions
required for subsequent library procedure calls.

If you plan to use this callable library on a regular basis, in particular
in both interactive (login) sessions and batch jobs, be certain to put the
above set-up line in your LOGIN.COM file, in either/both the INTERACTIVE:
and/or the BATCH: stanzas, so that the library's resources are available
to either/both types of VMS process.  DCL$SUBROUTINE_LIBRARY.COM is written
to provide per-process resources only; there is no provision to "install it
system-wide."

For a "verbose" view of setup, call it this way:

    $ @disk$<somewhere>:[<somedirectory>]DCL$SUBROUTINE_LIBRARY setup true

The second parameter "true" just makes the setup "verbose" -- it outputs
several lines to display the logical names and global symbols thus defined.
In particluar, the global symbol DCL$CALL, which itself is based on the
logical name DCL$SLHOME, is relevant:

    $ SHOW SYMBOL /GLOBAL DCL$CALL
      DCL$CALL == "@DCL$SLhome:DCL$SUBROUTINE_LIBRARY"

From this point, all calls or invocations of library procedures are simply
done using this symbol as a command alias -- for example:

    $ DCL$CALL show
      ...
    $ DCL$CALL api
      ...

The above two examples display, respectively:

  a) A list of the currently-available callabled routines in the current
     release of the DCL$SUBROUTINE_LIBRARY, and...
  b) An internally-generated quick-guide to the callable routines' API,
     including each routine's purpose, command line parameters and output.

CURRENT VERSION:
---------------
The correct and only way to review the "current version" of the library, and
to review that version's list of callable routines, is to:

    $ DCL$CALL version    ! Displays the same information that "setup true"
                          ! would show at library set-up...

    $ DCL$CALL show       ! Displays the list of currently callable routines

USE BY OTHER COMMAND SCRIPTS:
----------------------------
Once this DCL$SUBROUTIN_LIBRARY is installed, activated and set-up as described
above, it can be used (routines called) by other DCL command scripts just as
shown above -- for example:

    $ DCL$CALL DiscoverDisks DI$Disks "MNT,SHDW_MEMBER"
      ...
    $ DCL$CALL Thousands DI$maxfiles "''maxfiles'"
      ...
    $ DCL$CALL DeleteGloSyms "DI$Disks,DI$maxfiles"
      ...

See the internal documentation for full information on calling each routine,
including its inputs as command-line parameters, and its output (if any,
usually via a global symbol).

AUTHOR:
------
Lorin Ricker (PARSEC Group)
 email: Lorin(at)RickerNet(dot)us
GitHub: https://github.com/LorinRicker/VMScomfiles
        (in folder-path lmr_login/)

SOFTWARE LICENSE:
----------------
DCL$SUBROUTINE_LIBRARY.COM is copyright by its author, and is licensed by the
GNU Public License, GPL v3, as documented within the source code file itself:

$ ! Copyright © 2012-2017 by Lorin Ricker.  All rights reserved, with acceptance,
$ ! use, modification and/or distribution permissions as granted and controlled
$ ! by and under the GPL described herein.
$ !
$ ! This program (software) is Free Software, licensed under the terms and
$ ! conditions of the GNU General Public License Version 3 as published by
$ ! the Free Software Foundation: http://www.gnu.org/copyleft/gpl.txt,
$ ! which is hereby incorporated into this software and is a non-severable
$ ! part thereof.  You have specific rights and obligations under this GPL
$ ! which are binding if and when you accept, use, modify and/or distribute
$ ! this software program (source code file) and/or derivatives thereof.
$ !

