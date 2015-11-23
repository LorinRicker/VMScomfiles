$ ! ANSISEQ.COM --                                                 'F$VERIFY(0)'
$ !
$ esc[0,32]= %X1B                   ! 27 decimal, 033 octal
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
$     _clrscr  == esc + "[m"  -     ! set rendition normal
                + esc + "[H"  -     ! cursor to 0,0
                + esc + "[2J"       ! clear entire screen
$     _clrscrL == esc + "[?5h"      !light
$     _clrscrD == esc + "[?5l"      !dark
$ !
$ EXIT  ! 'F$VERIFY(0)'
