$ ! ICO$START.COM -- Start the X-Windows Icosahedron display.      'F$VERIFY(0)'
$ !
$ ! P1: Object to draw [cube | tetrahedron | icosahedron (default) | STOP]
$ ! P2: Subprocess/invocation control
$ !
$ ! use: @ICO$START [object]  or  @ICO$START STOP (to stop the window)
$ !
$ ON CONTROL_Y       THEN GOTO Ico_Stop
$ ON ERROR           THEN GOTO Ico_Stop
$ IF P1 .EQS. "STOP" THEN GOTO Ico_Stop
$ IF P2 .EQS. ""
$ THEN SPAWN /NOWAIT /PROCESS=DECW$_ico @com:ico$start "''P1'" SUBPROCESS
$      WAIT 00:00:02.00
$      SET PROCESS /PRIORITY=2 DECW$_ico
$ ELSE ico = "$decw$examples:ico"
$      IF P1 .NES. "" THEN P1 = "-obj " + P1
$      display = F$EDIT(F$GETSYI("NODENAME"),"COLLAPSE")
$      SET DISPLAY /CREATE /NODE='display' /SERVER=0 /SCREEN=0
$      ico 'P1'
$ ENDIF
$Done:
$ EXIT
$ !
$Ico_Stop:
$ SET NOON
$ STOP DECW$_ico
$ EXIT
$ !
$ ! * SYNOPSIS
$ ! *   ico [-display display] [-geometry geometry]
$ ! *   [-r] [-d pattern] [-i] [-dbl] [-faces] [-noedges]
$ ! *   [-sleep n] [-obj object] [-objhelp] [-colors color-list]
$ ! * 
$ ! * OPTIONS
$ ! *   -r * Display on the root window instead of creating a new window.
$ ! * 
$ ! *   -d pattern * Specify a bit pattern for drawing dashed lines for wire frames.
$ ! * 
$ ! *   -i * Use inverted colors for wire frames.
$ ! *
$ ! *   -dbl *  Use double buffering on the display. This works for either wire
$ ! *   frame or solid fill drawings. For solid fill drawings, using this
$ ! *   switch results in substantially smoother movement. Note that this
$ ! *   requires twice as many bit planes as without double buffering. Since
$ ! *   some colors are typically allocated by other programs, most
$ ! *   eight-bit-plane displays will probably be limited to eight colors
$ ! *   when using double buffering.
$ ! * 
$ ! *   -faces * Draw filled faces instead of wire frames.
$ ! * 
$ ! *   -noedges *  Don't draw the wire frames.  Typically used only when -faces is used.
$ ! * 
$ ! *   -sleep n * Sleep n seconds between each move of the object.
$ ! * 
$ ! *   -obj object *  Specify what object to draw.
$ ! *   If no object is specified, an icosahedron is drawn.
$ ! * 
$ ! *   -objhelp * Print out a list of the available objects, along with information about each object.
$ ! * 
$ ! *   -colors color color ... 
$ ! *   Specify what colors should be used to draw the filled faces of the
$ ! *   object. If less colors than faces are given, the colors are reused.
