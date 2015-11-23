$!
$! This command procedures defines site-specific logical names.  It 
$! also contains space for user-defined logical names. 
$!
$! NOTE:  If your system has been booted with the sysgen parameter
$!	  STARTUP_P1 set to "MIN" and is a cluster member the devices 
$!	  on other cluster nodes may not be available.
$!
$! NOTE:  It is recommended that use of clusterwide logical names
$!	  (new functionality in OpenVMS V7.2) be deferred until
$!	  the SYSTARTUP_VMS.COM procedure.  The initialization of
$!	  the clusterwide logical name database by the cluster
$!	  server process (CSP) may not be complete at the time
$!	  this SYLOGICALS.COM procedure is executed.  If you must
$!	  use clusterwide logical names here, then use the following
$!	  tests as a guideline for how to take actions:
$!		1. The system must be booted into a cluster:
$!			F$GETSYI("CLUSTER_MEMBER") is TRUE
$!		2. The system must not be booted MINIMUM:
$!			F$GETSYI("STARTUP_P1") is not "MIN"
$!		3. The CSP initialization is complete:
$!			F$GETSYI("CWLOGICALS") is TRUE
$!	  If all these conditions are met, clusterwide logical names
$!	  can be used - otherwise, any clusterwide logical name
$!	  operations may stall or yield unexpected (non-clusterwide)
$!	  results.
$!
$! ------------------------------------------------------------------
$!
$! Define any site-specific logical names below:
$!
$! This section should include any site specific VMScluster core file
$! definitions.  (These logical name definitions were previously defined
$! in the site-specific file SYENVIRON.COM.)
$!
$! Site-specific VMScluster core file definitions are required whenever
$! there is more than one system disk present in the VMScluster, and whenever
$! the standard file naming and/or file location conventions are not used.
$!
$! The user should include definitions for the devices, directories, and file
$! names for the various core VMScluster and DECnet files, typically including
$! all of the logical names and file names shown below.  (The file locations
$! shown below use search list logical names such as SYS$SYSTEM: for clarity
$! -- be aware that the files actually reside in the system disk system-common
$! root, and not in the system-specific root.  eg: the common files reside in
$! SYS$SYSROOT:[SYSEXE], in the case of any files accessable via SYS$SYSTEM:.)
$!
$! The translations of the following list of logical names -- the translations
$! shown here are the default names, device, and directory locations -- should
$! be altered to match the local site-specific location and filename for the
$! core files:
$!
$! In addition to the following list, sites using the VMS Registry MUST
$! have a cluster-wide common definition for logical name SYS$REGISTRY,
$! as described later on in this command procedure. It has no default.
$!
$! DEFINE/SYSTEM/EXECUTIVE SYSUAF                      SYS$SYSTEM:SYSUAF.DAT
$! DEFINE/SYSTEM/EXECUTIVE SYSUAFALT                   SYS$SYSTEM:SYSUAFALT.DAT
$! DEFINE/SYSTEM/EXECUTIVE SYSALF                      SYS$SYSTEM:SYSALF.DAT
$! DEFINE/SYSTEM/EXECUTIVE RIGHTSLIST                  SYS$SYSTEM:RIGHTSLIST.DAT
$! DEFINE/SYSTEM/EXECUTIVE NETPROXY                    SYS$SYSTEM:NETPROXY.DAT
$! DEFINE/SYSTEM/EXECUTIVE NET$PROXY                   SYS$SYSTEM:NET$PROXY.DAT
$! DEFINE/SYSTEM/EXECUTIVE NETOBJECT                   SYS$SYSTEM:NETOBJECT.DAT
$! DEFINE/SYSTEM/EXECUTIVE NETNODE_REMOTE              SYS$SYSTEM:NETNODE_REMOTE.DAT
$! DEFINE/SYSTEM/EXECUTIVE LMF$LICENSE                 SYS$SYSTEM:LMF$LICENSE.LDB
$! DEFINE/SYSTEM/EXECUTIVE VMSMAIL_PROFILE             SYS$SYSTEM:VMSMAIL_PROFILE.DATA
$! DEFINE/SYSTEM/EXECUTIVE VMS$OBJECTS                 SYS$SYSTEM:VMS$OBJECTS.DAT
$! DEFINE/SYSTEM/EXECUTIVE VMS$AUDIT_SERVER            SYS$MANAGER:VMS$AUDIT_SERVER.DAT
$! DEFINE/SYSTEM/EXECUTIVE VMS$PASSWORD_HISTORY        SYS$SYSTEM:VMS$PASSWORD_HISTORY.DATA
$! DEFINE/SYSTEM/EXECUTIVE VMS$PASSWORD_DICTIONARY     SYS$LIBRARY:VMS$PASSWORD_DICTIONARY.DATA
$! DEFINE/SYSTEM/EXECUTIVE NETNODE_UPDATE              SYS$MANAGER:NETNODE_UPDATE.COM
$! DEFINE/SYSTEM/EXECUTIVE VMS$PASSWORD_POLICY         SYS$LIBRARY:VMS$PASSWORD_POLICY.EXE
$! DEFINE/SYSTEM/EXECUTIVE LAN$NODE_DATABASE           SYS$SYSTEM:LAN$NODE_DATABASE.DAT
$!
$! Set up the queue manager.  Defining the queue manager and queue system
$! database is described in the "OpenVMS System Manager's Manual: Essentials"
$! chapter entitled "Managing the Queue Manager and Queue Database".  Below
$! is a summary of the process.  Refer to the documentation for further
$! information.
$!
$! DEFINE/SYSTEM/EXECUTIVE QMAN$MASTER		       device:<directory>
$!
$! By default the queue master file, QMAN$MASTER.DAT is created in
$! SYS$COMMON:<SYSEXE>.  To place the queue master file on a disk other than the
$! system disk, define the logical QMAN$MASTER to the device and directory to
$! contain the file. In an OpenVMS cluster environment, the directory you
$! specify for the master file must be available to all nodes in the cluster and
$! translate to the same physical location on all nodes of the cluster.
$! 
$! The queue manager is normally enabled by default.  If this is an initial
$! installation, the queue files containing the queues, forms, etc.
$! do not yet exist.  You may use the command START/QUEUE/MANAGER/NEW
$! from an interactive terminal to create these files.  NOTE: This command only
$! needs to be done ONCE for a new OpenVMS installation.  It should NOT be
$! placed in this file since it would execute each time the system is
$! booted, creating new queue files each time.  This will cause all current
$! jobs, queues, forms, etc. to be lost each time this procedure executes.
$!
$! The queue database files, SYS$QUEUE_MANAGER.QMAN$QUEUES and
$! SYS$QUEUE_MANAGER.QMAN$JOURNAL are  created in SYS$COMMON:<SYSEXE> by default.
$! To place the queue manager database in another location, enter the
$! START/QUEUE/MANAGER command with a parameter.  For example, to put the queue
$! database files in the same cluster common directory as the queue master file,
$! enter the command:  
$!
$!   $ START/QUEUE/MANAGER/ON=(NodeX,NodeY,NodeZ) QMAN$MASTER
$!
$! Once the queue files have been created you may use the INITIALIZE/QUEUE
$! command from an interactive terminal to create the necessary queues.
$! The START/QUEUE command should then be added to this file for any
$! queues that are not AUTOSTART queues.
$!
$!
$! Include MOUNT/SYSTEM command(s) for the disk(s) on which the above files
$! reside on.   Please see SYS$EXAMPLES:CLU_MOUNT_DISK.COM for the recommended
$! method of performing these MOUNT/SYSTEM operations.
$!
$! ------------------------------------------------------------------
$!
$!
$!
$! The state of the operator on OPA0:, and the state of the operator logfile,
$! can be controlled by defining logical names here in SYLOGICALS.COM.  Any
$! commands to enable or disable operator classes in other system startup
$! procedures should be removed, and the appropriate logical names defined here.
$!
$! By default, the operator states are:
$!
$!	For all systems except workstations in a VAXcluster:
$!
$!		OPA0: is enabled for all classes.
$!		The log file SYS$MANAGER:OPERATOR.LOG is opened for all classes.
$!
$!	For workstations in a VAXcluster:
$!
$!		OPA0: is not enabled.*
$!		No log file is opened.
$!
$!		 * OPA0: will be also be SET TERMINAL/PERMANENT/NOBROADCAST
$!
$! To override the default enabled classes, define the following /SYSTEM
$! logical names.
$!
$!	OPC$OPA0_ENABLE
$!
$!		If defined to be true, then OPA0: is enabled as an operator.  If
$!		defined to be false, then OPA0: is not enabled as an operator.
$!
$!	OPC$OPA0_CLASSES
$!
$!		This logical defines the operator classes to be enabled on
$!		OPA0:.  The logical can be a search list of the allowed	
$!		classes, a list of classes, or a combination of the two, for
$!		example: 
$!
$!			$ DEFINE /SYSTEM OPC$OPA0_CLASSES CENTRAL,DISKS,TAPE 
$!			$ DEFINE /SYSTEM OPC$OPA0_CLASSES "CENTRAL,DISKS,TAPE" 
$!			$ DEFINE /SYSTEM OPC$OPA0_CLASSES "CENTRAL,DISKS",TAPE 
$!
$!	Note that OPC$OPA0_CLASSES can be defined even if OPC$OPA0_ENABLE is
$!	not defined.  In that case, the classes are used for any operators
$!	that are enabled, but the default is used to determine whether or not
$!	to enable the operator.
$!
$!	OPC$LOGFILE_ENABLE
$!
$!		If defined to be true, then an operator log file is opened.
$!		If defined to be false, then no log file is opened.
$!
$!	OPC$LOGFILE_CLASSES
$!
$!		This logical defines the operator classes to be enabled for
$!		the log file.  The logical can be a search list of the allowed
$!		classes, a comma-separated list, or a combination of the two.
$!		OPC$LOGFILE_CLASSES can be defined even if OPC$LOGFILE_ENABLE
$!		is not defined.
$!
$!	OPC$LOGFILE_NAME
$!
$!		This logical supplies information to be used in conjunction
$!		with the default name SYS$MANAGER:OPERATOR.LOG to define the
$!		name of the log file.  If the log file is directed to a disk
$!		other than the system disk, commands to mount that disk should
$!		be included in the command procedure SYLOGICALS.COM.  This
$!		logfile name will be used whenever a logfile is recreated.
$!
$!
$!
$!      The settings of the following two logicals, OPC$ALLOW_INBOUND and
$!      OPC$ALLOW_OUTBOUND, are used to control the OPCOM traffic in and
$!      out of this node.
$!
$!                      ******    WARNING    ******
$!
$!      Setting these logicals to FALSE severs all OPCOM traffic in the
$!      specified direction.  All OPCOM messages as well as any returned
$!      status messages that might be expected will not be delivered.
$!
$!                      ***************************
$!
$!      OPC$ALLOW_INBOUND
$!
$!              This logical allows OPCOM traffic that is inbound to this
$!              node to be turned on or off.  By default, this logical is
$!              set to TRUE.  If this logical is set to FALSE, all OPCOM
$!              messages from other nodes in the cluster will not be
$!              received by this node.
$!
$!      OPC$ALLOW_OUTBOUND
$!
$!              This logical allows OPCOM traffic that is outbound from this
$!              node to be turned on or off.  By default, this logical is
$!              set to TRUE.  If this logical is set to FALSE, all OPCOM
$!              messages from this node will not to be sent to other nodes
$!              in the cluster.
$!
$!	Note that only OPC$LOGFILE_NAME is used for more than the initial
$!	startup of OPCOM.  For example, issuing the command REPLY/LOG will
$!	open a new file with the specified name and with all classes enabled
$!	(OPC$LOGFILE_ENABLE and OPC$LOGFILE_CLASSES are ignored).	
$!
$!  The list of all operator classes is:
$!
$!	CENTRAL,PRINTER,TAPES,DISKS,DEVICES,CARDS,NETWORK,CLUSTER,
$!	SECURITY,LICENSE,OPER1,OPER2,OPER3,OPER4,OPER5,OPER6,
$!	OPER7,OPER8,OPER9,OPER10,OPER11,OPER12
$!
$!  Operator classes can be redefined via logical names.  For example, a site
$!  could decide that the site-specific operator OPER1 should be known as
$!  operator class SYSTEM_MANAGER.  This would be done via:
$!
$!		$ DEFINE /SYSTEM  SYSTEM_MANAGER  OPER1
$!
$!  Thereafter, the system manager could do a REPLY/ENABLE=SYSTEM_MANAGER,
$!  users could do REQUEST /TO=SYSTEM_MANAGER, etc.
$!
$
$!
$!   The EVE editor checks for a logical name to see what the default keypad
$!   should be when you enter the editor.                                   
$!                                                                          
$!   Valid settings are:                                                    
$!                                                                          
$!   EDT, EVE, NUMERIC, VT100 and WPS                                       
$!                                                                          
$!   If you wish to have the default keypad in EVE be something             
$!   other than the EVE keypad, un-comment the line below and               
$!   define the keypad to one of the above values.  The commented out line
$!   defines the keypad to EDT.
$!
$!   DEFINE /SYSTEM /TRANSLATION_ATTRIBUTES=TERMINAL EVE$KEYPAD EDT
$
$!   Make sure that the mail parser uses the phase 5 parser regardless
$!   of whether you are running phase 4 or phase 5
$    DEFINE/SYSTEM/EXEC MAIL$SYSTEM_FLAGS 16
$!
$!   Coordinated Startup
$!
$!   The following Logical Name definitions control whether particular
$!   components are to be started:
$!
$!       True - component should be started
$!       False - component should not be started
$!       Undefined - component may be started if needed by another component.
$!
$!   Uncomment the line of a component you need.
$!
$! DEFINE DCOM$TO_BE_STARTED TRUE			! DCOM
$! DEFINE ACME$TO_BE_STARTED TRUE			! ACM Server
$! DEFINE NTA$TO_BE_STARTED TRUE			! NTA Services
$! DEFINE NTA$AUTHENTICATED_RPC_TO_BE_STARTED TRUE	! Authenticated RPC
$! DEFINE NTA$NT_ACME_TO_BE_STARTED TRUE		! NT ACM Extension
$!
$!   You must define the logical name for the OpenVMS Registry at least
$!   in the LNM$SYSTEM logical name table, and not in the LNM$PROCESS logical
$!   name table. This ensures that the server will not be able to be started by
$!   a different process on a system where this logical is defined to be FALSE.
$!
$  DEFINE/TABLE=LNM$SYSTEM REG$TO_BE_STARTED TRUE	! OVMS Registry
$!
$!   If any component uses the OpenVMS Registry, you must uncomment the
$!   following line and edit it to provide a directory specification which 
$!   is visible to the entire cluster, or a directory specification that 
$!   matches an existing definition of SYS$REGISTRY. There is no default, 
$!   and the OpenVMS Registry will not start without it. You must define
$!   this logical name at least in the LNM$SYSTEM logical name table.
$!
$!!! No!--> $  DEFINE/TABLE=LNM$SYSCLUSTER SYS$REGISTRY sys$sysdevice:[sys$registry]
$!                                   <cluster-visible directory specification>
$!
$ ! NOTE!!! Do this as a /SYSTEM logical, due to hang-problems if/whenever
$ !         bringing a new cluster member up thru its AUTOGEN/1st-bootup steps;
$ !         "DEFINE/CLUSTER" actually hangs if "not yet a cluster"!
$    DEFINE /SYSTEM /EXECUTIVE SYS$REGISTRY sys$sysdevice:[sys$registry]
$ !
$!   End of SYLOGICALS.COM
$!
$	EXIT
