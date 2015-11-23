$ ! CAPTURE.COM -- captures output to file
$ !
$ IF p1 .EQS. "" -
  THEN  READ /END_OF_FILE=Done /PROMPT="Command? " sys$command p1
$ IF p2 .EQS. "" -
  THEN  READ /END_OF_FILE=Done /PROMPT="Capture file? " sys$command p2
$ IF p2 .EQS. "" THEN p2 = "sys$scratch:capture.tmp"
$ DEFINE /USER_MODE sys$error  'p2'
$ DEFINE /USER_MODE sys$output 'p2'
$ DEFINE /USER_MODE sys$input sys$command
$ 'p1'
$ IF p3 .NES. "" THEN TYPE /PAGE 'p2'
$Done:
$ EXIT
