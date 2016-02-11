README_DCL_EXAMPLES.TXT

Introduction & GPL Licensing

    The VMS zip-file DCL_EXAMPLES.ZIP contains a subdirectory tree
    of DCL command files, examples from various OpenVMS sys-admin
    and scripting classes, and made available as Open Source Software
    under the GNU General Public License.

    Except for the most trivial of example com-files, all of these
    scripts carry the copyright and GNU/GPL notice:

    $ ! Copyright © 1999-2016 by Lorin Ricker.  All rights reserved, with acceptance,
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

    These scripts may be freely shared and used according to the terms
    of the GNU/GPL, including the requirement to include that same
    copyright and license notice in all copies and instances of any of
    these script files.

Zip File

    The file DCL_EXAMPLES.ZIP (the "zip file") is a VMS-zip-file, and
    will not unzip correctly on a non-VMS system (e.g., don't try to
    unzip on Windows, Linux, Unix or Mac/OS-X) -- it must be unzipped
    on an OpenVMS system.

    To unzip the zip file on OpenVMS --

      1. Move (or copy) the zip file to a suitable directory to unzip
         into, and SET DEFAULT to that (sub)directory:

         $ RENAME /LOG dcl_examples.zip [.dcl_examples]*.*
         $ SET DEFAULT [.dcl_examples]
         $ SHOW DEFAULT

      2. The unzip operation will create a sub-tree of directories in
         this location:

         $ unzip dcl_examples.zip
         Archive:  DSA2:[LRICKER.DCL_EXAMPLES]DCL_EXAMPLES.ZIP;1
            creating: [.EXAMPLES.ADVANCED]
           inflating: [.EXAMPLES]ASKFILES.COM
           inflating: [.EXAMPLES]BOOTTIME.COM
           ...
           inflating: [.EXAMPLES.TOYS]FINITE.COM
           inflating: [.EXAMPLES.TOYS]INFINITE.COM
           inflating: [.EXAMPLES.TOYS]MON_DISK.COM
           inflating: [.EXAMPLES.TOYS]PROCPERM_LOGICALS.COM
         $

      3. To list the contents of the zip file:

         $ unzip -l dcl_examples.zip   ! short-form listing
       or
         $ unzip -v dcl_examples.zip   ! slightly longer-form listing

      4. If you suspect problems or corruption has occurred within the
         zip file (e.g., because of problems with emailing it or copying
         it from a non-VMS system), run this test/zip-self-check:

         $ unzip -t dcl_examples.zip

         This file must be FTP'd (e.g., from another system) in binary
         or image mode, not text or ascii mode.

    The HP Freeware ZIP.EXE and UNZIP.EXE executables can be downloaded from

      http://h71000.www7.hp.com/openvms/freeware/freeware.html

    It is common practice (not harmful) to put these into the SYS$SYSTEM
    directory, or they can be put into another (non-system) directory which
    is commonly accessible.  Be sure to download the correct system/server
    image-flavor (VAX, Alpha or Integrity) for your own target system.

    Once downloaded and moved/copied into the right target directory, set up
    DCL foreign command symbols as follows:

        $ zip == "$sys$system:zip.exe"
        $ unzip == "$sys$system:unzip.exe"
      or
        $ zip == "$commonapps:zip.exe"
        $ unzip == "$commonapps:unzip.exe"

    where "commonapps" is a logical name for some other commonly accessible
    directory for applications programs.

    Regardless of where you put these, be sure to set sensible file ownership
    and protection masks:

        $ SET SECURITY /OWNER=SYSTEM /PROTECTION=(S:RWED,O:RWED,G,W:RE) /LOG sys$system:*zip.exe
      or
        $ SET SECURITY /OWNER=SYSTEM /PROTECTION=(S:RWED,O:RWED,G,W:RE) /LOG commonapps:*zip.exe

GitHub Repository

    All script files in this [.DCL_EXAMPLES] directory tree (plus many
    more) are available in my GitHub 'VMScomfiles' repository, here:
    
      https://github.com/LorinRicker/VMScomfiles
    
    As this is a public and open-source repository, you are welcome and
    encouraged to browse and take what you want to share from it; indeed,
    you can clone the whole repo to your desktop or laptop...
    
    The only thing is -- if you make derivatives and/or improvements to
    any of the DCL command files, please share them back by issuing a
    pull-request to me for consideration and possible inclusion in this
    repository.
    
    Since this is VMS and DCL, the community tradition of open-source
    sharing is not (yet) strongly established -- but hey!  Somebody's
    gotta be first, might as well be us!  Thank you!

Enjoy the DCL_EXAMPLES command files!

  -- Lorin // PARSEC Group // LRicker@parsec.com // 720-962-9591

