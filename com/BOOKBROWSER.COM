$! 
$! BOOKBROWSER.COM
$!
$!	This procedure replaces/registers the DEC BOOKBROWSER license.
$!	This license enables access to all DEC Bookreader books.
$!
$ set noon
$ save_message = f$environment("MESSAGE")
$ set message /NOFACILITY /NOIDENTIFICATION /NOSEVERITY /NOTEXT
$ license unload  BOOKBROWSER /producer=DEC
$ license delete  BOOKBROWSER /producer=DEC /all
$!
$! This PAK was issued on 30-APR-1997 14:32
$ LICENSE REGISTER BOOKBROWSER - 
	/ISSUER=DEC -
	/AUTHORIZATION=AXP-VAX-BOOKBROWSER -
	/PRODUCER=DEC -
	/UNITS=0 -
	/RELEASE_DATE=28-FEB-1998  -
	/ACTIVITY=CONSTANT=100 -
	/CHECKSUM=2-DGPK-INIA-JFKH-CLDF
$ license load BOOKBROWSER /producer=DEC 
$ set message'save_message'
