; KBUG V 1.03
; Monitor program for the HD6303Y EVB board

; K. Willmott 2023
; tested, working

; minibug originally modified for NMIS-0021

; 2023-03-01 adapt for 6303Y
; 2023-05-18 first clean up, add some comments
; 2023-05-20 add feedback text, write "W", exec command "X"
; 2023-05-21 fixed stack initialization error
; 2023-05-22 add CPU vector jump table
; 2023-05-25 add primitive RAM test
; 2023-06-18 add external baud clock for 3MHz operation
; 2023-06-19 make alpha input case insensitive
; 2023-06-22 add clock stretching
; 2023=07-14 code formatting clean up

; based on the original source
; COPYWRITE 1973, MOTOROLA INC
; REV 004 (USED WITH MIKBUG)

; HD6303Y register definitions (<power on default value>):

RMCR	.equ	0x10 ;rate mode control register (0xc0)
CC0	.equ	0x04 ;set for asynch mode
CC1	.equ	0x08 ;set for ext clock
RP5CR	.equ	0x14
AMRE	.equ	0x10
MRE	.equ	0x04

TRCSR1	.equ	0x11 ;control status register 1 (0x20)
TRCSR2	.equ	0x1e ;control status register 2 (0x28)
SCREN	.equ	0x08 ;RE bit - RX enable
SCTEN	.equ	0x02 ;TE bit - TX enable

RDRF	.equ	0x80 ;receive data register full flag
TDRE	.equ	0x20 ;transmit data register empty flag

RDR	.equ	0x12 ;rx data register (0)
TDR	.equ	0x13 ;tx data register (undefined)

; Address of boot or test code, RTS to return to monitor

XCALL	.equ	0xB800		;call test code here

; HD8303 internal RAM

INTRAM	.equ	0x40
EXTRAM	.equ	0x0140

; memory test variables

ramst	.equ	EXTRAM	;external ram
ramend	.equ	0xC000		;memory limit

; start of boot ROM area
; EEPROM is actually 0xE000-0xFFFF

	.area	SYS (ABS,OVR)
	.org	0xFD00

; ENTER POWER ON SequENCE

START:

; set rate and mode

; choose one line for external vs. internal baud clock:

;	ldaa  #CC0+CC1 	asynch, E/16 baud, ext clock
	ldaa	#CC0	;asynch, E/16 baud, internal clock

	staa	RMCR

; initialize SCI

	ldaa	#SCREN+SCTEN     ;enable RX TX
	staa	TRCSR1

; uncomment to configure MR pin
; auto memory ready from MR input P52

;	ldaa	RP5CR
;	oraa	#MRE+AMRE
;	staa	RP5CR

; set up vector jump table

	lds	#EXTRAM-1   ;SET STACK POINTER
	ldab	#10
	ldaa	#0x7E		;JMP INSTRUCTION
	ldx	#VECERR

NEXTVC:	pshx
	psha
	decb
	bne	NEXTVC

	lds	#STACK   ;SET STACK POINTER

; run main program

	jmp	KBUG

; Utility routines follow
;

; INPUT ONE CHAR INTO A-REGISTER
GETCH:	ldaa	TRCSR1
	anda	#RDRF
	beq	GETCH     ;RECEIVE NOT READY

	ldaa	RDR   ;INPUT CHARACTER
	cmpa	#0x7F
	beq	GETCH     ;RUBOUT; IGNORE
	rts

; Make input case insensitive
; From p.718 Hitachi HD6301-3 Handbook

TPR:	cmpa	#'a	;Entry point
	bcs	TPR1
	cmpa	#'z
	bhi	TPR1
	anda	#0xDF	;Convert lowercase to uppercase
TPR1:	rts

; Input a character with output echo
; implemented as an entry point to OUTCH

INCH:	bsr	GETCH
	bsr	TPR
	cmpa	#0x0D
	beq	NOECHO

; OUTPUT ONE CHAR in Accumulator A
;

OUTCH:	pshb           ;SAVE B-REG
OUTC1:	ldab	TRCSR1
	andb	#TDRE
	beq	OUTC1    ;XMIT NOT READY

	staa	TDR   ;OUTPUT CHARACTER
	pulb
NOECHO:	rts

; Output a char string
; address of string in X

PRSTRN:	ldaa	,X  ;Get a char
	beq	PRDONE
	bsr	OUTCH
	inx
	bra	PRSTRN
PRDONE:	rts

; Report vector problem

VECERR:	ldx	#ERROUT
	jsr	PRSTRN
FREEZE:	bra	FREEZE     ;Suspend via endless loop

; boot time memory test

MEMTST:	ldx	#ramst
	stx	memtop

loop:	ldaa	0,x	;get byte
	tab		;save it
	coma
	staa	0,x	;save complement same place
	cmpa	0,x
	bne	done	;read not same as written
	stab	0,x	;restore byte

	inx		;look at next byte
	cpx	#ramend
	beq	done
	bra	loop

done:	stx	memtop
	rts
;
; end utility routines


; Monitor code begins
;

; INPUT HEX CHAR
;

INHEX:	bsr	INCH
	cmpa	#'0
	bmi	C1       ;NOT HEX
	cmpa	#'9
	ble	IN1HG    ;IS HEX
	cmpa	#'A
	bmi	C1       ;NOT HEX
	cmpa	#'F
	bgt	C1       ;NOT HEX
	suba	#'A-'9-1    ;MAKE VALUES CONTIGUOUS
IN1HG:	rts

; S-record loader
;

LOAD:	bsr	INCH
	cmpa	#'S
	bne	LOAD    ;1ST CHAR NOT (S)
	bsr	INCH
	cmpa	#'9
	beq	C1
	cmpa	#'1
	bne	LOAD    ;2ND CHAR NOT (1)
	clr	CKSM     ;ZERO CHECKSUM
	bsr	BYTE     ;READ BYTE
	suba	#2
	staa	BYTECT   ;BYTE COUNT

; BUILD ADDRESS
	bsr	BADDR

; STORE DATA
LOAD11:	bsr	BYTE
	dec	BYTECT
	beq	LOAD15   ;ZERO BYTE COUNT
	staa	,X        ;STORE DATA
	inx
	bra	LOAD11

LOAD15:	inc	CKSM
	beq	LOAD
LOAD19:	ldaa	#'?      ;PRINT QUESTION MARK

	jsr	OUTCH
C1:	jmp	CONTRL

; BUILD ADDRESS
;

BADDR:	bsr	BYTE     ;READ 2 FRAMES
	staa	XHI
	bsr	BYTE
	staa	XLOW
	ldx	XHI      ;(X) ADDRESS WE BUILT
	rts

; INPUT BYTE (TWO FRAMES)
;

BYTE:	bsr	INHEX    ;GET HEX CHAR
	asla
	asla
	asla
	asla
	tab
	bsr	INHEX
	anda	#0x0F     ;MASK TO 4 BITS
	aba
	tab
	addb	CKSM
	stab	CKSM
	rts

; CHANGE MEMORY (M AAAA DD NN)
;

CHANGE:	bsr	BADDR    ;BUILD ADDRESS
	bsr	OUTS     ;PRINT SPACE
	bsr	OUT2HS
	bsr	BYTE
	dex
	staa	,X
	cmpa	,X
	bne	LOAD19   ;MEMORY DID NOT CHANGE
	bra	CONTRL

; WRITE MEMORY (M AAAA NN)
;

MWRITE:	bsr	BADDR    ;BUILD ADDRESS
	bsr	OUTS     ;PRINT SPACE
	bsr	BYTE
	staa	,X
	bra	CONTRL

;  formatted output entry points
;

OUTHL:	lsra	;OUT HEX LEFT BCD DIGIT
	lsra
	lsra
	lsra

OUTHR:	anda	#0xF	;OUT HEX RIGHT BCD DIGIT
	adda	#0x30
	cmpa	#0x39
	bhi	ISALF
	jmp	OUTCH

ISALF:	adda	#0x7
	jmp	OUTCH

OUT2H:	ldaa	0,X      ;OUTPUT 2 HEX CHAR
	bsr	OUTHL    ;OUT LEFT HEX CHAR
	ldaa	0,X
	bsr	OUTHR    ;OUT RIGHT HEX VHAR
	inx
	rts

OUT2HS:	bsr	OUT2H    ;OUTPUT 2 HEX CHAR + SPACE
OUTS:	ldaa	#0x20     ;SPACE
	jmp	OUTCH    ;(bsr & rts)

; Monitor startup
;

KBUG:	jsr	MEMTST	;check memory

	ldx	#MOTD		;Print start up message
	jsr	PRSTRN

	ldx	#MMSG1	;Print memtest results
	jsr	PRSTRN
	ldx	#memtop
	jsr	OUT2H
	jsr	OUT2H
	ldx	#MMSG2
	jsr	PRSTRN

	ldx	#cmdhlp   ;Print commands message
	jsr	PRSTRN

	bra	CONTRL

     
; PRINT CONTENTS OF STACK

PRINT:	ldx	#REGHDR   ;Print register titles
	jsr	PRSTRN
	tsx
	stx	SP       ;SAVE STACK POINTER
	ldab	#9
PRINT2:	bsr	OUT2HS   ;OUT 2 HEX & SPCACE
	DECB
	bne	PRINT2

CONTRL:	LDS	#STACK   ;SET STACK POINTER
	ldaa	#0xD      ;CARRIAGE RETURN
	jsr	OUTCH
	ldaa	#0xA      ;LINE FEED
	jsr	OUTCH
	ldx	#PROMPT   ;Print start up message
	jsr	PRSTRN

	jsr	INCH     ;READ CHARACTER
	tab
	jsr	OUTS     ;PRINT SPACE

	cmpb	#'X		;Execute stored program
	bne	NOTQ
	jsr	XCALL
	jmp	KBUG

NOTQ:	cmpb	#'L		;Load S-record
	bne	NOTL
	jmp	LOAD

NOTL:	cmpb	#'M		;Modify
	bne	NOTM
	jmp	CHANGE

NOTM:	cmpb	#'W		;Write
	bne	NOTW
	jmp	MWRITE

NOTW:	cmpb	#'P		;Print
	beq	PRINT
	cmpb	#'G		;Go
	bne	CONTRL
	rti			;Load registers and run

; Constant data section

MOTD:	.fcb 0x0D,0x0A
	.fcc ";;; Kbug 1.03 for HD6303Y EVB 1.0 ;;;"
	.fcb 0x0D,0x0A,0

cmdhlp:	.fcc "G(o),L(oad),P(roc),M(od),W(rite),X(ecute)?:"
       	.fcb 0x0D,0x0A,0

PROMPT:	.fcc "KBUG->"
	.fcb 0

REGHDR:	.fcb 0x0D,0x0A
	.fcc "CC B  A  XH XL PH PL SH SL"
	.fcb 0x0D,0x0A,0

ERROUT:	.fcb 0x0D,0x0A
	.fcc "Err - vector table entry no init"
	.fcb 0x0D,0x0A,0

MMSG1:	.fcc "RAM test passed to "
	.fcb 0

MMSG2:	.fcc "."
	.fcb 0x0D,0x0A,0

; Processor hardware vectors
; There are ten, not including CPU Reset

	.org	0xFFEA

IRQ2:	.fdb	VIRQ2
CMI:	.fdb	VCMI
TRAP:	.fdb	VTRAP
SIO:	.fdb	VSIO
TOI:	.fdb	VTOI
OCI:	.fdb	VOCI
ICI:	.fdb	VICI
IRQ1:	.fdb	VIRQ1
SWI:	.fdb	VSWI
NMI:	.fdb	VNMI
RES:	.fdb	START

; Data Section
; located in internal RAM

	.org	INTRAM

memtop:	.rmb	2

	.org	EXTRAM-44

STACK:	.rmb	1        ;STACK POINTER

; REGISTERS FOR GO command

	.rmb	1        ;CONDITION CODES
	.rmb	1        ;B ACCUMULATOR
	.rmb	1        ;A
	.rmb	1        ;X-HIGH
	.rmb	1        ;X-LOW
	.rmb	1        ;P-HIGH
	.rmb	1        ;P-LOW
SP:	.rmb	1        ;S-HIGH
	.rmb	1        ;S-LOW

; END REGISTERS FOR GO command

CKSM:	.rmb	1        ;CHECKSUM
BYTECT:	.rmb	1        ;BYTE COUNT
XHI:	.rmb	1        ;XREG HIGH
XLOW:	.rmb	1        ;XREG LOW

; CPU vector jump table
; must be in RAM to be alterable

VIRQ2:	.rmb	3
VCMI:	.rmb	3
VTRAP:   .rmb	3
VSIO:    .rmb	3
VTOI:    .rmb	3
VOCI:    .rmb	3
VICI:    .rmb	3
VIRQ1:   .rmb	3
VSWI:    .rmb	3
VNMI:    .rmb	3

HERE	.equ	.

	.END
