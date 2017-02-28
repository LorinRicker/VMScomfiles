$ ! ANSISEQ.COM --                                                 'F$VERIFY(0)'
$ !
$ ! Copyright © 1999-2017 by Lorin Ricker.  All rights reserved, with acceptance,
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
$TestOutput:  SUBROUTINE
$ IF ( P4 .EQS. "" )
$ THEN wso F$FAO( "!#* !AS -- !AS!AS!AS", 7, P1, P3, P2, NC )
$ ELSE wso F$FAO( "!#* !AS -- !AS!AS!AS -- visible as !AS!AS!AS", 7, P1, P3, P2, NC, P4, P5, NC )
$ ENDIF
$ EXIT 1
$ ENDSUBROUTINE  ! TestOutput
$ !
$ !
$ !
$ wso = "WRITE sys$output"
$ wso "%ANSISEQ-I-DEFSYM, defining ANSI Escape Sequences, including color..."
$ !
$ esc[0,8]== %X1B                   !  27 decimal,  033 octal - ESCape character
$ csi[0,8]== %X9B                   ! 151 decimal, 0227 octal - CSI character
$ !
$ ! ANSI renditions:
$         NORM == esc + "[0m"       ! Normal rendition
$           NC == NORM              ! No Color
$         BOLD == esc + "[1m"       ! Bold
$        ULINE == esc + "[4m"       ! Underline
$        BLINK == esc + "[5m"       ! "slow", use sparingly, if at all...!
$        REVRS == esc + "[7m"       ! Reverse or inverse
$      CONCEAL == esc + "[8m"       ! no echo
$ !
$ ! Not widely (or ever) supported, here for reference/completeness:
$ !      FAINT == esc + "[2m"       ! faint (dim))
$ !     ITALIC == esc + "[3m"       ! italic
$ ! BLINKRAPID == esc + "[6m"       ! "rapid"
$ !   CROSSOUT == esc + "[9m"       ! characters "marked out"
$ !
$ ! ANSI foreground or "normal intensity" colors (forces normal background)):
$        BLACK == esc + "[0;30m"    ! normal black     [  0,  0,  0] \
$          RED == esc + "[0;31m"    ! normal red       [187,  0,  0] |
$        GREEN == esc + "[0;32m"    ! normal green     [  0,187,  0] | PuTTY
$        BROWN == esc + "[0;33m"    ! normal yellow    [187,187,  0] | RGB
$         BLUE == esc + "[0;34m"    ! normal blue      [  0,  0,187] | values
$       PURPLE == esc + "[0;35m"    ! normal magenta   [187,  0,187] |
$         CYAN == esc + "[0;36m"    ! normal cyan      [  0,187,187] |
$    LIGHTGRAY == esc + "[0;37m"    ! normal white     [187,187,187] /
$ !
$ ! Note: Specify background color before foreground color --
$ !       WRITE sys$output BLUE_BG + WHITE + "This is a test!" + NORM
$ !
$ ! ANSI background colors:
$     BLACK_BG == esc + "[0;40m"    ! normal black     [  0,  0,  0] \
$       RED_BG == esc + "[0;41m"    ! normal red       [187,  0,  0] |
$     GREEN_BG == esc + "[0;42m"    ! normal green     [  0,187,  0] | PuTTY
$     BROWN_BG == esc + "[0;43m"    ! normal yellow    [187,187,  0] | RGB
$      BLUE_BG == esc + "[0;44m"    ! normal blue      [  0,  0,187] | values
$    PURPLE_BG == esc + "[0;45m"    ! normal magenta   [187,  0,187] |
$      CYAN_BG == esc + "[0;46m"    ! normal cyan      [  0,187,187] |
$ LIGHTGRAY_BG == esc + "[0;47m"    ! normal white     [187,187,187] /
$ !
$ ! ANSI foreground or "bright intensity" colors (against reverse background)):
$     DARKGRAY == esc + "[1;30m"    ! bright black     [ 85, 85, 85] \
$     LIGHTRED == esc + "[1;31m"    ! bright red       [255, 85, 85] |
$   LIGHTGREEN == esc + "[1;32m"    ! bright green     [ 85,255, 85] | PuTTY
$       YELLOW == esc + "[1;33m"    ! bright yellow    [255,255, 85] | RGB
$    LIGHTBLUE == esc + "[1;34m"    ! bright blue      [ 85, 85,255] | values
$  LIGHTPURPLE == esc + "[1;35m"    ! bright magenta   [255, 85,255] |
$    LIGHTCYAN == esc + "[1;36m"    ! bright cyan      [ 85,255,255] |
$        WHITE == esc + "[1;37m"    ! bright white     [255,255,255] /
$ !
$ ! --------------------------------
$ ! Define screen-clearing commands:
$     _bckscrL == esc + "[?5h"      ! set background light
$     _bckscrD == esc + "[?5l"      ! set background dark
$     _clrscr  == esc + "[m"  -     ! set rendition normal
                + esc + "[H"  -     ! cursor to 0,0
                + esc + "[2J"       ! clear entire screen
$ !
$     clr      == "WRITE sys$output _clrscr"
$     cls      == "WRITE sys$output _clrscr"
$     clrd     == "WRITE sys$output _bckscrL,_clrscr"
$     clsd     == "WRITE sys$output _bckscrL,_clrscr"
$     clrl     == "WRITE sys$output _bckscrD,_clrscr"
$     clsl     == "WRITE sys$output _bckscrD,_clrscr"
$ ! --------------------------------
$ !
$ !
$TestMode:
$ IF ( P1 .NES. "" )
$ THEN ! test-output mode
$      IF ( P1 .EQS. "DARK" )
$      THEN wso _clrscrL
$      ELSE wso _clrscrD
$      ENDIF
$                  wso " Frequently supported renditions --"
$                  wso "  Supported? Attribute"
$      CALL TestOutput "Yes : BOLD"        "Bold"            "''BOLD'"
$      CALL TestOutput "Yes : ULINE"       "Underlined"      "''ULINE'"
$      CALL TestOutput " No : BLINK"       "Blinking"        "''BLINK'"
$      CALL TestOutput "Yes : REVRS"       "ReverseVideo"    "''REVRS'"
$      CALL TestOutput " No : CONCEAL"     "concealed"       "''CONCEAL'"
$ !
$                  wso " Rarely supported renditions --"
$                  wso "  Supported? Attribute"
$      CALL TestOutput " No : FAINT"       "faint"           "''FAINT'"
$      CALL TestOutput " No : BLINKRAPID"  "BlinkingRapidly" "''BLINKRAPID'"
$      CALL TestOutput " No : CROSSOUT"    "Crossed Out"     "''CROSSOUT'"
$ !
$ ! Note: Specify background color before foreground color --
$                  wso " Foreground (text) colors --"
$                  wso "  Supported? Attribute"
$      CALL TestOutput "Yes : BLACK"       "Black"           "''BLACK'"
$      CALL TestOutput "Yes : RED"         "Red"             "''RED'"
$      CALL TestOutput "Yes : GREEN"       "Green"           "''GREEN'"
$      CALL TestOutput "Yes : BROWN"       "Brown"           "''BROWN'"
$      CALL TestOutput "Yes : BLUE"        "Blue"            "''BLUE'"
$      CALL TestOutput "Yes : PURPLE"      "Purple"          "''PURPLE'"
$      CALL TestOutput "Yes : CYAN"        "Cyan"            "''CYAN'"
$      CALL TestOutput "Yes : LIGHTGRAY"   "LightGray"       "''LIGHTGRAY'" "''BLACK_BG'''LIGHTGRAY'" "Lightgray-on-Black (error)"
$ !
$                  wso " Background colors --"
$                  wso "  Supported? Attribute"
$      CALL TestOutput "Yes : BLACK_BG"     "Black"          "''BLACK_BG'"  "''BLACK_BG'''WHITE'" "White-on-Black"
$      CALL TestOutput "Yes : RED_BG"       "Red"            "''RED_BG'"
$      CALL TestOutput "Yes : GREEN_BG"     "Green"          "''GREEN_BG'"
$      CALL TestOutput "Yes : BROWN_BG"     "Brown"          "''BROWN_BG'"
$      CALL TestOutput "Yes : BLUE_BG"      "Blue"           "''BLUE_BG'"   "''BLUE_BG'''WHITE'" "White-on-Blue"
$      CALL TestOutput "Yes : PURPLE_BG"    "Purple"         "''PURPLE_BG'"
$      CALL TestOutput "Yes : CYAN_BG"      "Cyan"           "''CYAN_BG'"
$      CALL TestOutput "Yes : LIGHTGRAY_BG" "LightGray"      "''LIGHTGRAY_BG'"
$ !
$                  wso " Foreground bright intensity (text) colors --"
$                  wso "  Supported? Attribute"
$      CALL TestOutput "Yes : DARKGRAY"    "DarkGray"        "''DARKGRAY'"
$      CALL TestOutput "Yes : LIGHTRED"    "LightRed"        "''LIGHTRED'"
$      CALL TestOutput "Yes : LIGHTGREEN"  "LightGreen"      "''LIGHTGREEN'"
$      CALL TestOutput "Yes : YELLOW"      "Yellow"          "''YELLOW'"   "''BLUE_BG'''YELLOW'" "Yellow-on-Blue"
$      CALL TestOutput "Yes : LIGHTBLUE"   "LightBlue"       "''LIGHTBLUE'"
$      CALL TestOutput "Yes : LIGHTPURPLE" "LightPurple"     "''LIGHTPURPLE'"
$      CALL TestOutput "Yes : LIGHTCYAN"   "LightCyan"       "''LIGHTCYAN'"
$      CALL TestOutput "Yes : WHITE"       "White"           "''WHITE'"    "''WHITE_BG'''BLACK'" "Black-on-White"
$ !
       wso ""
       wso "Note: Usability of these renditions, especially color, depend intimately upon"
       wso "      terminal emulator settings (e.g., PuTTY: Window|Colours), and upon the"
       wso "      terminal display's background color (dark or light)."
$ ENDIF
$ !
$ EXIT  ! 'F$VERIFY(0)'
