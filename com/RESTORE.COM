$ ! RESTORE.COM
$ !
$ SET NOON
$ !
$ Rbf  = "DISK$RDB_BCK1:[NTS_DB_RESTORE]nts$1999-02-23.rbf"
$ Rbr  = "DISK$RDB_BCK1:[NTS_DB_RESTORE]nts$database.rbr"
$ DD   = "DISK$DB1:[L_RICKER.NTS]"
$ Root = "nts$database"
$ sql  = "$sys$system:sql$"
$ !
$ DEFINE /NOLOG /PROCESS DB$rbr 'Rbr'
$ SHOW LOGICAL DB$rbr
$ DEFINE /NOLOG /PROCESS NTS$Database 'DD''Root'
$ SHOW LOGICAL NTS$Database
$ !
$ !'F$VERIFY(1,1)'
$ RMU /RESTORE /NEW_VERSION /NOCDD_INTEGRATE /NOAFTER_JOURNAL -
      /DIRECTORY='DD' /ROOT='DD''Root' /NOLOG -
      'Rbf'
$ !
$ sql
DISCONNECT ALL;
EXPORT DATABASE FILENAME NTS$Database INTO DB$rbr WITH EXTENSIONS;
EXIT
$ !'F$VERIFY(0,0)'
$ !
$ EXIT
