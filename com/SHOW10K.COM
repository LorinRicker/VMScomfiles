$! SHOW10K.DCL
$!
$! DCL procedure to build and run the SHOW10K.MAR program
$!
$! This procedure creates and runs a test program, and the test
$! program determines if the ALPLIBR05_070 (or later) or the
$! ALPLIBR05_070 (or later) 10Kday delta-time patch has been
$! applied to the local system...
$!
$
$ if f$int(f$getsyi("SID")) .eq. -2147483648
$ then
$   ! SID = %x80000000 if this is not a VAX...
$   macro_opt = "/MIGRATE"
$   link_opt = "/NOSYSEXE"
$   write sys$output "Building test for ALPLIBR05_070 (or later) patch..."
$   write sys$output "(For OpenVMS Alpha V6.1 or later)"
$ else
$   ! SID != %x80000000 if this is a VAX...
$   macro_opt = " "
$   link_opt = "/NOSYSSHR"
$   write sys$output "Building test for VAXLIBR05_070 (or later) patch..."
$   write sys$output "(For OpenVMS VAX V5.5-2 or later)"
$ endif
$
$ macro/object=sys$scratch:show10k.obj sys$input 'macro_opt'
	.TITLE	SHOW10K detects the presence of 10Kday patches
	.IDENT	/SHOW10K/
;
;****************************************************************************
;*                                                                          *
;*  COPYRIGHT (c) 1997 BY                                                   *
;*  DIGITAL EQUIPMENT CORPORATION, MAYNARD, MASSACHUSETTS.                  *
;*  ALL RIGHTS RESERVED.                                                    *
;*                                                                          *
;*  THIS SOFTWARE IS FURNISHED UNDER A LICENSE AND MAY BE USED AND COPIED   *
;*  ONLY IN  ACCORDANCE WITH  THE  TERMS  OF  SUCH  LICENSE  AND WITH THE   *
;*  INCLUSION OF THE ABOVE COPYRIGHT NOTICE. THIS SOFTWARE OR  ANY  OTHER   *
;*  COPIES THEREOF MAY NOT BE PROVIDED OR OTHERWISE MADE AVAILABLE TO ANY   *
;*  OTHER PERSON.  NO TITLE TO AND OWNERSHIP OF  THE  SOFTWARE IS  HEREBY   *
;*  TRANSFERRED.                                                            *
;*                                                                          *
;*  THE INFORMATION IN THIS SOFTWARE IS  SUBJECT TO CHANGE WITHOUT NOTICE   *
;*  AND  SHOULD  NOT  BE  CONSTRUED AS  A COMMITMENT BY DIGITAL EQUIPMENT   *
;*  CORPORATION.                                                            *
;*                                                                          *
;*  DIGITAL ASSUMES NO RESPONSIBILITY FOR THE USE  OR  RELIABILITY OF ITS   *
;*  SOFTWARE ON EQUIPMENT WHICH IS NOT SUPPLIED BY DIGITAL.                 *
;*                                                                          *
;*                                                                          *
;****************************************************************************
;
;++
; FACILITY:
;	OpenVMS
;
;
; FUNCTIONAL DESCRIPTION:
;
;	This code probes for the presence of the 10Kdays patches;
;	the ALPLIBR05_070 and VAXLIBR05_070 (or later) patches.
;
;       Please see the documentation associated with the patches
;       for details, see URL http://www.service.digital.com/, or
;       contact your local DIGITAL customer support center.
;
;	This code is deliberately linked against the STARLET.OLB
;	object library, to check for the existence of the LIB$
;	10K-Days-related patches in the object library.  (Both
;	STARLET.OLB and RTL shareable image changes are involved
;	in the ALPLIBR05_070 and VAXLIBR05_070, and later patches.)
;
;
; ENVIRONMENT: VAX or Alpha, user mode
;
; AUTHOR: Stephen Hoffman, CREATION-DATE: 28-Feb-1997
;         Digital Equipment Corporation
;
; MODIFIED BY:
;         Stephen Hoffman, 17-Mar-1997
;         Added conditional for V5.5-2 PR$_SID_TYP_NOTAVAX
;         behaviour, added the DCL build "wrapper"...
;
; CONSTRUCTION:
;
;   Specification of the OpenVMS VAX /NOSYSSHR or the OpenVMS Alpha
;   /NOSYSEXE qualifier is required for proper operation of the test.
;
;   OpenVMS VAX:
;	$ MACRO SHOW10K
;	$ LINK SHOW10K/NOSYSSHR
;	$ RUN SHOW10K
;
;   OpenVMS Alpha:
;	$ MACRO/MIGRATE SHOW10K
;	$ LINK SHOW10K/NOSYSEXE
;	$ RUN SHOW10K
;--
        .LIBRARY        /SYS$LIBRARY:LIB/
        $LIBDEF
        $LIB$ROUTINESDEF
        $PRDEF
        $SSDEF
        $SYIDEF


;
; the following block of print directives is suppressed, as the
; %AMAC-I-GENINFO messages these produce under OpenVMS Alpha
; MACRO/MIGRATE might trouble some users...
;
;	.print 0;Building tool to check for the *LIBR05_070 patch...
;	.print 0;...on OpenVMS VAX, use LINK/NOSYSSHR SHOW10K
;	.print 0;...on OpenVMS Alpha, use LINK/NOSYSEXE SHOW10K
;	.print 0;Then RUN SHOW10K

	.psect	$DATA,WRT,NOSHR,NOEXE,LONG

tenk:		.long	10000
deltatime:	.quad	0
opcode:		.long	LIB$K_DELTA_DAYS
PatchHeader:	.ascid	/Checking the need for the *LIBR05_070 patch.../
PatchLoaded:	.ascid	/...Patch has been applied, or is not required./
PatchAlpha:	.ascid	/...Patch ALPLIBR05_070 (or later) is required./
PatchVAX:	.ascid	/...Patch VAXLIBR05_070 (or later) is required./

	.PSECT	$CODE,NOWRT,SHR,EXE,LONG

	; if the PR$_SID_TYP_NOTAVAX symbol is not currently
	; available, create a local version of it now...  And
	; also assume that this is probably an older OpenVMS
	; VAX release, which means that the CALL_ENTRY macro
	; isn't around and that we should use .entry instead.
	
; SHOW10K main entry point...

        .IF NDF PR$_SID_TYP_NOTAVAX
        PR$_SID_TYP_NOTAVAX=128

	.ENTRY	show10k,^M<R9,R10,R11>
	.IF_FALSE
	.CALL_ENTRY	label=show10k, -
			preserve=<R9,R10,R11>, -
			max_args=0, -
			home_args=false
        .ENDC

	pushaq	PatchHeader		; output the "intro" message
	calls	#1,g^lib$put_output	; Introduce ourself...
	BLBC	R0,10$			; skip on error
	;
	pushaq	deltatime		; see if we can convert 10Kday...
	pushal	tenk			; ...interval to internal time.
	pushal	opcode			;
	calls	#3,g^lib$cvt_to_internal_time
	blbc	R0,20$			; branch on error
	;
	pushaq	deltatime		; see if we can convert 10Kday...
	pushal	tenk			; ...interval from internal time.
	pushal	opcode			;
	calls	#3,g^lib$cvt_from_internal_time
	blbc	R0,20$			; branch on error
	;
	pushaq	PatchLoaded		; output the "safe" message...
	calls	#1,g^lib$put_output	; ...no patch is required.
	BLBC	R0,10$			; skip on error
	movl	#SS$_NORMAL,R0		; force success
10$:	ret				; "leaving, what a good idea..."
20$:	;
	; decide which patch message -- VAX or Alpha -- is needed...
	;
	; Use a run-time $getsyi check to avoid the need for
	; ARCH_DEFS.MAR during the MACRO[/MIGRATE] operation.
	;
	clrl	-(SP)			; Create the buffer
	movl	SP,R11			; save address
	clrq	-(SP)			; null itemlist terminator
        clrl	-(SP)			; return length
        pushl	R11			; buffer address
        pushl	#<SYI$_CPU@16!4>	; Item code and buffer length
        movl    SP, R10                 ; Save the itemlist address.
 	clrq	-(SP)			; create an IOSB
	movl	SP,R9			; save address
        $GETSYIW_S -			; Get the CPU code
		ITMLST=(R10), -         ;   via system service
		IOSB=(R9)		;   at run-time
	blbc	R0,50$			; exit on error
	;
	cmpl	#PR$_SID_TYP_NOTAVAX,-  ; VAX CPU < 128; Alpha
 		(R11)			; (NOTAVAX) CPU = 128.
	beql	30$			; branch if Not A VAX
	pushaq	PatchVAX		; VAX patch needed...
	brb	40$			; branch to common code
30$:	pushaq	PatchAlpha		; Alpha patch needed...
40$:	calls	#1,g^lib$put_output	; display the message
	blbc	R0,50$			; exit on error
	movl	#SS$_NORMAL,R0		; force success
50$:	ret				; return to caller
	.END	show10k			;
$
$ link/execut=sys$scratch:show10k.exe sys$scratch:show10k.obj 'link_opt'
$ delete sys$scratch:show10k.obj;*
$ run sys$scratch:show10k
$ delete sys$scratch:show10k.exe;*
$
$ exit
