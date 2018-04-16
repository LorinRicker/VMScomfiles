$ ! HEX_IP_CONVERTER.COM --
$ !
$ !    use: @HEX_IP_CONVERTER 0A0B0C0D:0F94       ! for example...
$ ! yields: IP address/port: 10.11.12.13/3988
$ !
$ ipaddress  = F$ELEMENT( 0, ":", P1)
$ portnumber = F$ELEMENT( 1, ":", P1)
$ !
$ WRITE sys$output F$FAO( "IP address/port: !UL.!UL.!UL.!UL/!UL", -
    F$INTEGER( "%X''F$EXTRACT( 0, 2, ipaddress )'" ), -
    F$INTEGER( "%X''F$EXTRACT( 2, 2, ipaddress )'" ), -
    F$INTEGER( "%X''F$EXTRACT( 4, 2, ipaddress )'" ), -
    F$INTEGER( "%X''F$EXTRACT( 6, 2, ipaddress )'" ), -
    F$INTEGER( "%X''portnumber'" ) )
$ !
$ EXIT 1
$ !
