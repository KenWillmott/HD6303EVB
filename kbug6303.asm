* KBUG V 1.03
* Monitor program for the HD6303Y EVB board

* K. Willmott 2023
* tested, working

* minibug originally modified for NMIS-0021

* 2023-03-01 adapt for 6303Y
* 2023-05-18 first clean up, add some comments
* 2023-05-20 add feedback text, write "W", exec command "X"
* 2023-05-21 fixed stack initialization error
* 2023-05-22 add CPU vector jump table
* 2023-05-25 add primitive RAM test
* 2023-06-18 add external baud clock for 3MHz operation
* 2023-06-19 make alpha input case insensitive
* 2023-06-22 add clock stretching
* 2023=07-14 code formatting clean up

* based on the original source
* COPYWRITE 1973, MOTOROLA INC
* REV 004 (USED WITH MIKBUG)

* HD6303Y register definitions (<power on default value>):

RMCR	equ	$10 rate mode control register ($c0)
CC0	equ	$04 set for asynch mode
CC1	equ	$08 set for ext clock
RP5CR	equ	$14
AMRE	equ	$10
MRE	equ	$04

TRCSR1	equ	$11 control status register 1 ($20)
TRCSR2	equ	$1e control status register 2 ($28)
SCREN	equ	$08 RE bit - RX enable
SCTEN	equ	$02 TE bit - TX enable

RDRF	equ	$80 receive data register full flag
TDRE	equ	$20 transmit data register empty flag

RDR	equ	$12 rx data register (0)
TDR	equ	$13 tx data register (undefined)

* Address of boot or test code, RTS to return to monitor

XCALL	equ	$B800		call test code here

* HD8303 internal RAM

INTRAM	equ	$40
EXTRAM	equ	$0140

* memory test variables

ramst	equ	EXTRAM	external ram
ramend	equ	$C000		memory limit


* start of boot ROM area
* EEPROM is actually $E000-$FFFF

	ORG	$FD00

* ENTER POWER ON SEQUENCE

START	equ	*

* set rate and mode

* choose one line for external vs. internal baud clock:

*	ldaa  #CC0+CC1 	asynch, E/16 baud, ext clock
	ldaa	#CC0	asynch, E/16 baud, internal clock

	staa	RMCR

* initialize SCI

	ldaa	#SCREN+SCTEN     enable RX TX
	staa	TRCSR1

* uncomment to configure MR pin
* auto memory ready from MR input P52

*	ldaa	RP5CR
*	oraa	#MRE+AMRE
*	staa	RP5CR

* set up vector jump table

	lds	#EXTRAM-1   SET STACK POINTER
	ldab	#10
	ldaa	#$7E		JMP INSTRUCTION
	ldx	#VECERR

NEXTVC	pshx
	psha
	decb
	bne	NEXTVC

	lds	#STACK   SET STACK POINTER

* run main program

	jmp	KBUG

* Utility routines follow
*

* INPUT ONE CHAR INTO A-REGISTER
GETCH	ldaa	TRCSR1
	anda	#RDRF
	beq	GETCH     RECEIVE NOT READY

	ldaa	RDR   INPUT CHARACTER
	cmpa	#$7F
	beq	GETCH     RUBOUT; IGNORE
	rts

* Make input case insensitive
* From p.718 Hitachi HD6301-3 Handbook

TPR	equ	*	Entry point
	cmpa	#'a
	bcs	TPR1
	cmpa	#'z
	bhi	TPR1
	anda	#$DF	Convert lowercase to uppercase
TPR1	rts

* Input a character with output echo
* implemented as an entry point to OUTCH

INCH	bsr	GETCH
	bsr	TPR
	cmpa	#$0D
	beq	NOECHO

* OUTPUT ONE CHAR in Accumulator A
*

OUTCH	pshb           SAVE B-REG
OUTC1	ldab	TRCSR1
	andb	#TDRE
	beq	OUTC1    XMIT NOT READY

	staa	TDR   OUTPUT CHARACTER
	pulb
NOECHO	rts

* Output a char string
* address of string in X

PRSTRN	ldaa	,X  Get a char
	beq	PRDONE
	bsr	OUTCH
	inx
	bra	PRSTRN
PRDONE	rts

* Report vector problem

VECERR	ldx	#ERROUT
	jsr	PRSTRN
FREEZE	bra	FREEZE     Suspend via endless loop

* boot time memory test

MEMTST	ldx	#ramst
	stx	memtop

loop	ldaa	0,x	get byte
	tab		save it
	coma
	staa	0,x	save complement same place
	cmpa	0,x
	bne	done	read not same as written
	stab	0,x	restore byte

	inx		look at next byte
	cpx	#ramend
	beq	done
	bra	loop

done	stx	memtop
	rts
*
* end utility routines


* Monitor code begins
*

* INPUT HEX CHAR
*

INHEX	bsr	INCH
	cmpa	#'0
	bmi	C1       NOT HEX
	cmpa	#'9
	ble	IN1HG    IS HEX
	cmpa	#'A
	bmi	C1       NOT HEX
	cmpa	#'F
	bgt	C1       NOT HEX
	suba	#'A-'9-1    MAKE VALUES CONTIGUOUS
IN1HG	rts

* S-record loader
*

LOAD	bsr	INCH
	cmpa	#'S
	bne	LOAD    1ST CHAR NOT (S)
	bsr	INCH
	cmpa	#'9
	beq	C1
	cmpa	#'1
	bne	LOAD    2ND CHAR NOT (1)
	clr	CKSM     ZERO CHECKSUM
	bsr	BYTE     READ BYTE
	suba	#2
	staa	BYTECT   BYTE COUNT

* BUILD ADDRESS
	bsr	BADDR

* STORE DATA
LOAD11	bsr	BYTE
	dec	BYTECT
	beq	LOAD15   ZERO BYTE COUNT
	staa	,X        STORE DATA
	inx
	bra	LOAD11

LOAD15	inc	CKSM
	beq	LOAD
LOAD19	ldaa	#'?      PRINT QUESTION MARK

	jsr	OUTCH
C1	jmp	CONTRL

* BUILD ADDRESS
*

BADDR	bsr	BYTE     READ 2 FRAMES
	staa	XHI
	bsr	BYTE
	staa	XLOW
	ldx	XHI      (X) ADDRESS WE BUILT
	rts

* INPUT BYTE (TWO FRAMES)
*

BYTE	bsr	INHEX    GET HEX CHAR
	asla
	asla
	asla
	asla
	tab
	bsr	INHEX
	anda	#$0F     MASK TO 4 BITS
	aba
	tab
	addb	CKSM
	stab	CKSM
	rts

* CHANGE MEMORY (M AAAA DD NN)
*

CHANGE	bsr	BADDR    BUILD ADDRESS
	bsr	OUTS     PRINT SPACE
	bsr	OUT2HS
	bsr	BYTE
	dex
	staa	,X
	cmpa	,X
	bne	LOAD19   MEMORY DID NOT CHANGE
	bra	CONTRL

* WRITE MEMORY (M AAAA NN)
*

MWRITE	bsr	BADDR    BUILD ADDRESS
	bsr	OUTS     PRINT SPACE
	bsr	BYTE
	staa	,X
	bra	CONTRL

*  formatted output entry points
*

OUTHL	lsra	OUT HEX LEFT BCD DIGIT
	lsra
	lsra
	lsra

OUTHR	anda	#$F	OUT HEX RIGHT BCD DIGIT
	adda	#$30
	cmpa	#$39
	bhi	ISALF
	jmp	OUTCH

ISALF	adda	#$7
	jmp	OUTCH

OUT2H	ldaa	0,X      OUTPUT 2 HEX CHAR
	bsr	OUTHL    OUT LEFT HEX CHAR
	ldaa	0,X
	bsr	OUTHR    OUT RIGHT HEX VHAR
	inx
	rts

OUT2HS	bsr	OUT2H    OUTPUT 2 HEX CHAR + SPACE
OUTS	ldaa	#$20     SPACE
	jmp	OUTCH    (bsr & rts)

* Monitor startup
*

KBUG	jsr	MEMTST	check memory

	ldx	#MOTD		Print start up message
	jsr	PRSTRN

	ldx	#MMSG1	Print memtest results
	jsr	PRSTRN
	ldx	#memtop
	jsr	OUT2H
	jsr	OUT2H
	ldx	#MMSG2
	jsr	PRSTRN

	ldx	#cmdhlp   Print commands message
	jsr	PRSTRN

	bra	CONTRL

     
* PRINT CONTENTS OF STACK

PRINT	ldx	#REGHDR   Print register titles
	jsr	PRSTRN
	tsx
	stx	SP       SAVE STACK POINTER
	ldab	#9
PRINT2	bsr	OUT2HS   OUT 2 HEX & SPCACE
	DECB
	bne	PRINT2

CONTRL	LDS	#STACK   SET STACK POINTER
	ldaa	#$D      CARRIAGE RETURN
	jsr	OUTCH
	ldaa	#$A      LINE FEED
	jsr	OUTCH
	ldx	#PROMPT   Print start up message
	jsr	PRSTRN

	jsr	INCH     READ CHARACTER
	tab
	jsr	OUTS     PRINT SPACE

	cmpb	#'X		Execute stored program
	bne	NOTQ
	jsr	XCALL
	jmp	KBUG

NOTQ	cmpb	#'L		Load S-record
	bne	NOTL
	jmp	LOAD

NOTL	cmpb	#'M		Modify
	bne	NOTM
	jmp	CHANGE

NOTM	cmpb	#'W		Write
	bne	NOTW
	jmp	MWRITE

NOTW	cmpb	#'P		Print
	beq	PRINT
	cmpb	#'G		Go
	bne	CONTRL
	rti			Load registers and run

* Constant data section

MOTD	FCB $0D,$0A
	FCC "*** Kbug 1.03 for HD6303Y EVB 1.0 ***"
	FCB $0D,$0A,0

cmdhlp	FCC "G(o),L(oad),P(roc),M(od),W(rite),X(ecute)?:"
       	FCB $0D,$0A,0

PROMPT	FCC "KBUG->"
	FCB 0

REGHDR	FCB $0D,$0A
	FCC "CC B  A  XH XL PH PL SH SL"
	FCB $0D,$0A,0

ERROUT	FCB $0D,$0A
	FCC "Err - vector table entry no init"
	FCB $0D,$0A,0

MMSG1	FCC "RAM test passed to "
	FCB 0

MMSG2	FCC "."
	FCB $0D,$0A,0

* Processor hardware vectors
* There are ten, not including CPU Reset

	ORG	$FFEA

IRQ2	FDB	VIRQ2
CMI	FDB	VCMI
TRAP	FDB	VTRAP
SIO	FDB	VSIO
TOI	FDB	VTOI
OCI	FDB	VOCI
ICI	FDB	VICI
IRQ1	FDB	VIRQ1
SWI	FDB	VSWI
NMI	FDB	VNMI
RES	FDB	START

* Data Section
* located in internal RAM

	org	INTRAM

memtop	rmb	2

	ORG	EXTRAM-44

STACK	RMB	1        STACK POINTER

* REGISTERS FOR GO command

	RMB	1        CONDITION CODES
	RMB	1        B ACCUMULATOR
	RMB	1        A
	RMB	1        X-HIGH
	RMB	1        X-LOW
	RMB	1        P-HIGH
	RMB	1        P-LOW
SP	RMB	1        S-HIGH
	RMB	1        S-LOW

* END REGISTERS FOR GO command

CKSM	RMB	1        CHECKSUM
BYTECT	RMB	1        BYTE COUNT
XHI	RMB	1        XREG HIGH
XLOW	RMB	1        XREG LOW

* CPU vector jump table
* must be in RAM to be alterable

VIRQ2	RMB	3
VCMI	RMB	3
VTRAP   RMB	3
VSIO    RMB	3
VTOI    RMB	3
VOCI    RMB	3
VICI    RMB	3
VIRQ1   RMB	3
VSWI    RMB	3
VNMI    RMB	3

HERE	equ	*

       END
