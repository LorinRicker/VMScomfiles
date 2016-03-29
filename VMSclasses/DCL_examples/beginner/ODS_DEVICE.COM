$ ! ODS_DEVICE.COM --                                              'F$VERIFY(0)'
$ !
$ ON WARNING THEN GOTO Done
$ !
$ IF ( P1 .EQS. "" )
$ THEN DevName = "SYS$SYSDEVICE"
$ ELSE DevName = P1
$ ENDIF
$ !
$ DType = F$GETDVI(DevName,"ACPTYPE")
$ !
$ IF ( DType .EQS. "F11V5" )
$ THEN DeviceType = "ODS-5"
$ ELSE IF ( DType .EQS. "F11V2" )
$      THEN DeviceType = "ODS-2"
$      ELSE DeviceType = "unknown"
$      ENDIF
$ ENDIF
$ WRITE SYS$OUTPUT "Disk ''DevName' on-disk structure is ''DeviceType'"
$ !
$Done:
$ EXIT 1   ! 'F$VERIFY(0)'
$ !
