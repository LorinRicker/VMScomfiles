$ ! DO_CONTINUOUS.COM --                                           'F$VERIFY(0)'
$ !
$ ! This program is the confidential and proprietary product of LockWorks LLC.
$ ! Unauthorized use, reproduction or transfer of this program is prohibited.
$ !
$ ! Copyright © 2002-2003 by LockWorks LLC.  All rights reserved.
$ ! Copyright © 1999-2002 by Evans & Ricker, Inc.  All rights reserved.
$ !
$ !    use:  @DO_CONTINUOUS [-S:value] Command Arg1 [ArgN] [/Qualifiers]
$ !
$ !  where:  -S is a switch
$ !             -C:(1,0)   -- turns ClearScreen ON (default) or OFF, i.e., the
$ !                           screen is cleared between each execution of
$ !                           Command.
$ !             -D:seconds -- (re)sets the delay between Command executions.
$ !             -W:seconds -- same as -D:seconds.
$ !             -N:n       -- number of iterations (repeats) of Command
$ !                           (default is -N:0, "forever").
$ !             -P:p       -- sets the process base priority to "p" (which is
$ !                           reset to the original base priority upon exit);
$ !                           requires ALTPRI to set priority above base.
$ !             -Q         -- query (prompt) for Command (useful when the
$ !                           Command is long, etc.).
$ !             -T:(1,0)   -- time and display each Command iteration.
$ !
$ !          Command is any DCL command, including "@command-file" which
$ !             is to be periodically repeated.
$ !          Arg1 .. ArgN are DCL command-line arguments (parameters).
$ !          /Qualifiers are DCL command qualifiers.
$ !
$ !   hint:  Some DCL commands, parameters and qualifiers may need to be
$ !          included in (surrounded by) double-quotes: "Command P1 P2 /QUAL"
$ !
$ ON CONTROL_Y THEN GOSUB Ctrl_Y
$ ON ERROR THEN GOTO Done
$ Fac = F$PARSE(F$ENVIRONMENT("PROCEDURE"),,,"NAME","SYNTAX_ONLY")
$ !
$ DCO$Verbose == F$TRNLNM("TOOLS$Debug")     !generic Tools debug flag
$ DCO$Cmd     == ""
$ DCO$N       == -1
$ DCO$NStart  == -1
$ DCO$Prio    == -1
$ BasePrio     = F$GETJPI("","PRIB")
$ DCO$Query   == 0
$ DCO$Timer   == 0
$ DCO$TProg   == "site$utils:dc$datecalc.exe"
$ wso = "WRITE sys$output"
$ !
$ CALL ParseSwitch "-C:TRUE"    !ClearScreen ON
$ CALL ParseSwitch "-D:8"       !default 8-second delay
$ CALL ParseSwitch "-N:-1"      !"infinite repeats"
$ !
$ IF P1 .EQS. "?" THEN GOTO Help
$ !
$ I = 1
$L0:
$ Str = P'I'
$ IF F$EXTRACT(0,1,Str) .NES. "-"
$ THEN DCO$Cmd == DCO$Cmd + " " + Str
$ ELSE CALL ParseSwitch "''Str'"
$ ENDIF
$ I = I + 1
$ IF I .LE. 8 THEN GOTO L0
$ DCO$Cmd == F$EDIT(DCO$Cmd,"TRIM")
$ !
$ IF DCO$Query
$ THEN READ sys$command Answer /END_OF_FILE=Done /PROMPT="[1m''DCO$Prompt'[0m"
$      IF Answer .NES. ""
$      THEN DCO$Cmd == Answer
$      ELSE DCO$Cmd == "CONTINUE"
$      ENDIF
$ ENDIF
$ !
$ ! Check and change Process Priority, if requested:
$ IF ( DCO$Prio .GT. 0 ) .AND. ( DCO$Prio .LT. 9 )
$ THEN BasePrio = F$GETJPI("","PRIB")
$      IF DCO$Prio .GT. BasePrio
$      THEN IF F$PRIVILEGE("ALTPRI")  !got ALTPRI?
$           THEN SET PROCESS /PRIORITY='DCO$Prio'
$           ELSE wso "%''Fac'-F-INSUFPRIV, [1mALTPRI[0m required to increase process priority"
$                GOTO Done
$           ENDIF
$      ELSE IF DCO$Prio .LT. BasePrio
$           THEN SET PROCESS /PRIORITY='DCO$Prio'
$           ELSE wso "%''Fac'-W-NOP, requested priority same as current priority"
$           ENDIF
$      ENDIF
$ IF DCO$Verbose THEN wso "%''Fac'-I-PRIORITY, base priority set to [1m''DCO$Prio'[0m"
$ ENDIF
$ !
$ I = 1
$ !
$Loop: DCO$Cls         !'F$VERIFY(0)'
$ IF Str .EQS. "" THEN WAIT 00:00:00.25
$ IF DCO$Timer THEN Time_0 = F$TIME()  ! Capture elapsed start time
$ 'DCO$Cmd'            !'F$VERIFY(DCO$Verbose)'
$ CONTINUE             !'F$VERIFY(0)'
$ IF DCO$Timer .AND. ( F$TYPE(Time_0) .NES. "" )  !'F$VERIFY(0)'
$ THEN DC$DCALC "''TIme_0'" /DELTA /SYMBOL=Time_0 /SCOPE=LOCAL
$      wso ""
$      wso F$FAO("%!AS-I-ELAPSED, execution time: [1m!AS[0m (iteration !SL)",Fac,Time_0,I)
$ ENDIF
$ I = I + 1
$ IF DCO$N .EQ. 1
$ THEN GOTO Done                                !quit when precisely = 1
$ ELSE IF DCO$N .GT. 0 THEN DCO$N == DCO$N - 1  !else countdown (>0), ignore -1
$ ENDIF
$ DCO$Verbose == F$TRNLNM("TOOLS$Debug")
$ CALL ParseSwitch "-W:''DCO$Delay'"
$ wso ""         !'F$VERIFY(0)'
$ Clk = F$EXTRACT(0,8,F$FAO( "!%T", 0 ))
$ Clk = F$FAO( "!#* (!AS)", 78-F$LENGTH(DCO$Prompt)-F$LENGTH(DCO$Cmd)-8, Clk )
$ wso DCO$Prompt,"[1m",DCO$Cmd,"[0m",Clk
$ READ sys$command Str /PROMPT="''DCO$Prompt'" -
    /ERROR=Loop /END_OF_FILE=Done /TIME_OUT='DCO$Delay'
$ IF Str .EQS. "" THEN GOTO Loop     !just repeat current command immediately
$ IF F$EXTRACT(0,1,Str) .NES. "-"
$ THEN DCO$Cmd == F$EDIT(Str,"COMPRESS,TRIM")
$ ELSE CALL ParseSwitch "''Str'"
$ ENDIF
$ GOTO Loop
$ !
$Done:                 !'F$VERIFY(0)'
$ SET NOON
$ IF ( DCO$Prio .GT. 0 ) .AND. ( F$TYPE(BasePrio) .EQ. "INTEGER" ) -
  THEN SET PROCESS /PRIORITY='BasePrio'
$ IF F$TYPE(DCO$clrscr)  .NES. "" THEN DELETE /SYMBOL /GLOBAL DCO$clrscr
$ IF F$TYPE(DCO$clrscrL) .NES. "" THEN DELETE /SYMBOL /GLOBAL DCO$clrscrL
$ IF F$TYPE(DCO$clrscrD) .NES. "" THEN DELETE /SYMBOL /GLOBAL DCO$clrscrD
$ IF F$TYPE(DCO$Cls)     .NES. "" THEN DELETE /SYMBOL /GLOBAL DCO$Cls
$ IF F$TYPE(DCO$Cmd)     .NES. "" THEN DELETE /SYMBOL /GLOBAL DCO$Cmd
$ IF F$TYPE(DCO$Delay)   .NES. "" THEN DELETE /SYMBOL /GLOBAL DCO$Delay
$ IF F$TYPE(DCO$N)       .NES. "" THEN DELETE /SYMBOL /GLOBAL DCO$N
$ IF F$TYPE(DCO$NStart)  .NES. "" THEN DELETE /SYMBOL /GLOBAL DCO$NStart
$ IF F$TYPE(DCO$Prio)    .NES. "" THEN DELETE /SYMBOL /GLOBAL DCO$Prio
$ IF F$TYPE(DCO$Query)   .NES. "" THEN DELETE /SYMBOL /GLOBAL DCO$Query
$ IF F$TYPE(DCO$Prompt)  .NES. "" THEN DELETE /SYMBOL /GLOBAL DCO$Prompt
$ IF F$TYPE(DCO$Timer)   .NES. "" THEN DELETE /SYMBOL /GLOBAL DCO$Timer
$ IF F$TYPE(DCO$TProg)   .NES. "" THEN DELETE /SYMBOL /GLOBAL DCO$TProg
$ IF F$TYPE(DC$DCALC)    .NES. "" THEN DELETE /SYMBOL /GLOBAL DC$DCALC
$ IF F$TYPE(DCO$Verbose) .NES. "" THEN DELETE /SYMBOL /GLOBAL DCO$Verbose
$ EXIT
$ !
$ !
$ParseSwitch:  SUBROUTINE
$ P1 = P1 - "-"
$ Sw = F$ELEMENT(0,":",P1)
$ Vl = F$ELEMENT(1,":",P1)
$ IF DCO$Verbose THEN wso "Switch: [1m-''Sw'[0m  Value: ""[1m''Vl'[0m"""
$ GOTO 'Sw'$
$ !
$C$:  !Clear-screen (cls) flag
$ IF ( Vl .EQ. 1 ) .OR. ( F$EXTRACT(0,1,Vl) .EQS. "Y" ) .OR. ( F$EXTRACT(0,1,Vl) .EQS. "T" )
$ THEN esc[0,32]= %X1B
$      esc[0,1]:= 'esc'
$      DCO$clrscr  == esc + "[m" + esc + "[H" + esc + "[2J"
$      DCO$clrscrL == esc + "[?5h" !light
$      DCO$clrscrD == esc + "[?5l" !dark
$      DCO$Cls == "WRITE sys$output DCO$clrscr"
$ ELSE DCO$Cls == "CONTINUE"
$ ENDIF
$ EXIT 1
$ !
$D$:
$W$:  !Wait/Delay interval (expressed as pure seconds)
$ DCO$Delay == Vl
$ IF DCO$Verbose
$ THEN DCO$Prompt == "(''DCO$Delay')> "
$ ELSE DCO$Prompt == "> "
$ ENDIF
$ EXIT 1
$ !
$N$:
$ DCO$N == F$INTEGER(Vl)
$ IF DCO$N .GE. 0 THEN DCO$NStart == DCO$N
$ EXIT 1
$ !
$P$:  !set Process Priority
$ DCO$Prio == F$INTEGER(Vl)
$ EXIT 1
$ !
$Q$:   !Query for DCL command (one-shot from $-command line only)
$ DCO$Query == 1
$ EXIT 1
$ !
$T$:   !Timer ON or OFF
$ DCO$Timer == ( Vl .EQ. 1 ) -
               .OR. ( F$EXTRACT(0,1,Vl) .EQS. "Y" ) -
               .OR. ( F$EXTRACT(0,1,Vl) .EQS. "T" ) -
               .AND. ( F$SEARCH(DCO$TProg) .NES. "" )
$ IF DCO$Timer THEN DC$DCALC == "$''DCO$TProg'"
$ EXIT 1
$ !
$ ENDSUBROUTINE  ! ParseSwitch
$ !
$Ctrl_Y:
$ RETURN %X2C
$ !
$ !
$Help:
$ TYPE /PAGE sys$input

  DO_CONTINUOUS.COM provides a means to repeat a DCL command, either indefi-
  nitely, or a fixed number of times, with a fixed delay interval (8 seconds
  by default) between each iteration of the command.

  Between each iteration of the repeating DCL command, a command line prompt
  ">" appears.  This prompt can accept any additional (or changed) switch
  value(s), or a new or revised DCL command.  If you simply enter a <Return>
  (empty command line) at this prompt, the current command is repeated immedi-
  ately, and the fixed iteration delay resets at that point.

    use:  [1m@DO_CONTINUOUS [-S:value] Command Arg1 [ArgN] [/Qualifiers][0m

    where [1m-S:value[0m is one of the following switches:

             -C:(1,0)   -- turns ClearScreen ON (default) or OFF; by default,
                           the screen is cleared between each execution of
                           Command.
             -D:seconds -- (re)sets the delay between Command executions.
             -N:n       -- number of iterations (repeats) of Command
                           (default is -N:0, "forever").
             -P:p       -- sets the process base priority to "p" (which is
                           reset to the original base priority upon exit);
                           requires ALTPRI to set priority above base.
             -Q         -- query (prompt) for Command (useful when the
                           Command is long, etc.).
             -T:(1,0)   -- time and display each Command iteration.

    [1mCommand[0m is any DCL command, including "@command-file" which
    is to be periodically repeated.

    [1mArg1 .. ArgN[0m are DCL command-line arguments (parameters).

    [1m/Qualifiers[0m are DCL command qualifiers.

    Notes: The Command plus any of its arguments and/or qualifiers must appear
           consecutively on the command line; -S switches must appear as a
           group at the beginning or end of the command line.
           
           Some DCL commands, parameters and qualifiers may best be surrounded
           by double-quotes: "Command P1 P2 /QUAL".  In this form, the complete
           command consumes only one command-file parameter position, which
           may be an advantage.
           
           In other situations, it may be better to omit the DCL command
           from the command-file line and instead use the -Q switch, which
           then provides a command line prompt ">" for Command input.

           You can use any combination of switches as needed.  Each switch
           must appear preceded by its dash "-", separated from any other
           switch by a space.

$ !
$ GOTO Done
