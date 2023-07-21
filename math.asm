; math.asm
; routines from Hitachi
;
; 2023-07-17 transcribed K.W.
; 2023-07-21 convert to ASxxxx assembler syntax
;

	.hd6303
        .area   SYS (ABS,OVR)
	.org	0x8000

; Fill constant value p. 694
; Entry:
; ACCA (constant value)
; ACCB (byte count)
; X (start address)
;
; Return: none
;

FILL:	staa	0,x	;store constant
	inx		;increment address
	decb		;decrement counter
	bne	FILL	;loop while counter != 0
	rts

; Move memory blocks p. 698
; Entry:
; X (source address)
; DEA (dest address)
; ACCB (transfer count)
;
; Return: none
;

MOVE:	ldaa	0,x	;load transfer data
	inx		;increment source address
	pshx		;save source address
	ldx	DEA	;load dest address
	staa	0,x	;store transfer data
	inx		;increment dest address
	stx	DEA
	pulx		;restore source address
	decb		;decrement tranfer counter
	bne	MOVE	;loop while counter != 0
	rts

; Move strings p. 703
; Entry:
; X (source address)
; DEA (dest address)
;
; Return: none
;

MOVES:	ldaa	0,x	;Load transfer data
	beq	MOVS1	;branch to end if null found
	inx		;increment source address
	pshx		;save source address
	ldx	DEAS	;load destination address
	staa	0,x	;store transfer data
	inx		;increment dest address
	stx	DEAS	;save it
	pulx		;restore source address
	bra	MOVES
MOVS1:	rts

; Branching from a table p. 708
; Entry:
; ACCA (switch case value)
; X (table address)
;
; Return:
; X (table address)
; CCR C==1 found C==0 not found
;

CCASE:	tst	0,x	;command == 0
	beq	CCAS2	;branch to exit if null
	cmpa	0,x	;command same as command in table?
	beq	CCAS1	;branch if same
	inx
	inx
	inx		;increment table pointer
	bra	CCASE	;loop while not table end
CCAS1:	inx		;increment table pointer
	ldx	0,x	;load code module address
	sec		;load success code CCR C=1
CCAS2:	rts

; Make input case insensitive
; From p.718 Hitachi HD6301-3 Handbook
; Entry:
; ACCA (ASCII value)
;
; Return:
; ACCA (lower case value)
;

TPR:	cmpa	#'a
	bcs	TPR1
	cmpa	#'z
	bhi	TPR1
	anda	#0xDF	;Convert lowercase to uppercase
TPR1:	rts

; Convert ASCII hex to nibble p. 719
; Entry:
; ACCA (ASCII value)
;
; Return:
; ACCA (binary nibble)
; CCR C==1 invalid C==0 valid

NIBBLE:	suba	#'0
	bcs	NIB2	;if A >= 0 {
	adda	#0-'G+'0
	bcs	NIB2	;if A <= 0x0F {
	adda	#0xF+1-0xA
	bpl	NIB1	;if not A->F
	adda	#0xF+1-9
	bcs	NIB2	;if not 0->0xF
NIB1:	adda	#0x0A	;convert ASCII to binary
	clc		;clear carry
NIB2:	rts

; Convert byte to 2 ASCII characters p. 724
; Entry:
; ACCB (byte value)
;
; Return:
; ACCD (ASCII value)

COBYTE:	pshb		;save a copy of B
	
	lsrb
	lsrb
	lsrb
	lsrb		;upper 4 bits
	bsr	CONIB	;convert to ASCII
	tba		;place result in A

	pulb		;get saved copy
	andb	#0x0F	;mask
	bsr	CONIB	;convert to ASCII
	rts

CONIB:	addb	#'0
	cmpb	#'9
	bls	CONIB1		;if B <= 9 {
	addb	#'A-'9-1	;	}
CONIB1:	rts
	
; Count logical 1's in a byte p. 729
; Entry:
; ACCA (byte value)
;
; Return:
; ACCB (bit count)
	
HCNT:	ldx	#8	;load rotation count
	clrb		;clear count
HCNT1:	rola
	bcc	HCNT2	;if C==1 {
	incb		;}
HCNT2:	dex		;decrement count
	bne	HCNT1	;until count==0
	rola		;restore byte
	rts
	
; 32 bit shift right p. 733
; Entry:
; X (upper 16 bits)
; ACCD (lower 16 bits)
;
; Return:
; X (upper 16 bits)
; ACCD (lower 16 bits)

SHR32:	xgdx		;swap upper/lower
	lsrd		;shift upper
	xgdx		;swap
	rora
	rorb		;shift lower
	dec	SFCNTR	;decrement counter
	bne	SHR32	;until count==0
	rts

; 4 digit BCD counter p. 738
; Entry: none
;
; Return:
; DCNTR (2 byte BCD count value)
; CCR C==1 overflow C==0 no overflow

DECNT:	ldx	#2	;load addition counter
	sec		;init carry bit
DECNT1:	ldaa	#0	;clear A
	adca	DCNTR-1,x
	daa		;increment and convert to BCD
	staa	DCNTR-1,x	;store count
	dex		;until addition counter == 0
	bne	DECNT1
	rts

; 32 bit compare p. 743
; Entry:
; X (upper 16 bits)
; ACCD (lower 16 bits)
; CMT (32 bit number to compare)

; Return:
; CCR C & Z

CMP32:	cpx	CMT	;compare x with CMT+3, CMT+2
	bne	CMP1	;if .equal {
	xgdx		;swap X/ACCD
	cpx	CMT+2	;compare x with CMT+1, CMT
	xgdx		;swap X/ACCD
CMP1:	rts

; 32 bit addition p. 749
; Entry:
; X (upper 16 bits)
; ACCD (lower 16 bits)
; ADER (32 bit number to add)

; Return:
; X (upper 16 bits result)
; ACCD (lower 16 bits result)
; CCR C==1 overflow C==0 no overflow

ADD32:	addd	ADER+2
	xgdx		;swap X/ACCD
	adcb	ADER+1
	adca	ADER
	xgdx		;swap X/ACCD
	rts
	
; 32 bit subtraction p. 755
; Entry:
; X (upper 16 bits)
; ACCD (lower 16 bits)
; SBER (32 bit number to subtract)

; Return:
; X (upper 16 bits result)
; ACCD (lower 16 bits result)
; CCR C==1 borrow C==0 no

SUB32:	subd	SBER+2
	xgdx		;swap X/ACCD
	sbcb	SBER+1
	sbca	SBER
	xgdx		;swap X/ACCD
	rts

; 16 bit multiplication p. 761
; Entry:
; X (upper 16 bits)
; ACCD (lower 16 bits)
; SBER (32 bit number to subtract)

; Return:
; X (upper 16 bits result)
; ACCD (lower 16 bits result)
; CCR C==1 borrow C==0 no

MUL16:	clra
	clrb	
	std	PRDCT	;clear product area
	ldaa	MCAND+1
	ldab	MER+1
	mul
	std	PRDCT+2
	ldaa	MCAND
	ldab	MER+1
	mul
	addd	PRDCT+1
	std	PRDCT+1
	ldaa	MCAND+1
	ldab	MER
	mul
	addd	PRDCT+1
	std	PRDCT+1
	rol	PRDCT	;handle carry out
	ldaa	MCAND
	ldab	MER
	mul
	addd	PRDCT
	std	PRDCT
	rts

; 16 bit division p. 768
; Entry:
; X (dividend)
; DVS (divisor)

; Return:
; X (upper 16 bits result)
; ACCD (quotient)
; X (remainder)

DIV16:	ldaa	#16
	staa	DICNTR	;init shift counter
	clra
	clrb
DIV1:	xgdx		;swap X/ACCD
	asld
	xgdx		;swap X/ACCD
	rolb
	rola
	subd	DVS
	inx
	bcc	DIV2
	addd	DVS
	dex
DIV2:	dec	DICNTR
	bne	DIV1
	rts

; 8 digit packed BCD addition p. 774
; Entry:
; ABD (augend)
; ACD (addend)

; Return:
; ABD (augend)
; CCR C==1 overflow C==0 no overflow

ADDBCD:	ldx	#4	;init addition counter
	clc
ADDD1:	ldaa	ABD-1,x
	adca	ABD-1,x	;augend + addend
	daa		;decimal adjust
	staa	ABD-1,x
	dex
	bne	ADDD1
	rts

; 8 digit packed BCD subtraction p. 780
; Entry:
; SUBEDS (minuend)
; SUBERS (subtrahend)

; Return:
; SUBEDS (remainder)
; CCR C==1 true, C==0 borrow

SUBBCD:	ldx	#4		;init addition counter
SUBD1:	ldd	#0x9999
	subd	SUBERS-2,x
	std	SUBERS-2,x
	dex
	dex
	bne	SUBD1
	
	sec
	ldx	#4		;init addition counter
SUBD2:	ldaa	SUBEDS-1,x
	adca	SUBERS-1,x
	daa			;decimal adjust
	staa	SUBEDS-1,x
	dex
	bne	SUBD2
	rts

; 16 bit square root p. 786
; Entry:
; X (integer)

; Return:
; SANS (remainder)

SQRT16:	ldaa	#8
	staa	SCNTR	;initialize shift counter
	clra
	clrb		;D = 0
	std	SANS	;SANS = 0
	xgdx		;swap X/ACCD
SQRT1:	asld		;Rotate upper 2 bits of X to low 2 of ACCD
	xgdx		;swap X/ACCD
	rolb
	rola
	xgdx		;swap X/ACCD
	asld
	xgdx		;swap X/ACCD
	rolb
	rola
	
	sec		;set LSB of SANS
	rol	SANS+1
	rol	SANS
	subd	SANS	;D = D - SANS
	bcs	SQRT3	;branch if minus
	inc	SANS+1	;++SANS
SQRT2:	dec	SCNTR	;decrement shift counter
	xgdx		;swap X/ACCD
	bne	SQRT1
	asr	SANS	;SANS = SANS / 2
	ror	SANS+1
	rts
	
SQRT3:	addd	SANS
	dec	SANS+1	;SANS = SANS - 1
	bra	SQRT2

; 16 bit binary to 5 digit BCD p. 791
; Entry:
; HEXD (16 bit integer)

; Return:
; DECD (5 digit packed BCD in 3 bytes)

HEX:	clra
	clrb
	std	DECD
	staa	DECD+2	;clear result
	ldab	#16	;initialize shift counter
HEX2:	asl	HEXD+1	;MSB TO carry bit
	rol	HEXD
	ldx	#3	;initialize addition counter
HEX1:	ldaa	DECD-1,x
	adca	DECD-1,x	;A = DECD ; 2 + C
	daa
	staa	DECD-1,x	;store in BCD area
	dex
	bne	HEX1
	decb		;decrement shift counter
	bne	HEX2
	rts

; byte array sort p. 803
; Entry:
; ACCD (array size)
; X (start address)

; Return: none

SORT:	staa	SCNT1
SORT1:	staa	SCNT2
	pshx
	ldaa	0,x	;load sort data
SORT2:	inx		;next sort data address
	cmpa	0,x
	bcc	SORT3
	ldab	0,x
	staa	0,x	;exchange data
	tba
SORT3:	dec	SCNT2
	bne	SORT2
	pulx
	staa	0,x	;store max data
	inx		;increment sort data address
	dec	SCNT1
	ldaa	SCNT1
	bne	SORT1	;while sort count != 0
	rts

; Variable Section
;
	.org	0x4000
	
; MOVE
;
DEA:	.rmb	2
DEAS:	.rmb	2

; SHR32

SFCNTR:	.rmb	1

; CMP32, ADD32, SUB32, MUL16...

CMT:	.rmb	4	;number to compare
ADER:	.rmb	4	;number to add
SBER:	.rmb	4	;number to subtract

MCAND:	.rmb	2	;mult vars
MER:	.rmb	2
PRDCT:	.rmb	4

DVS:	.rmb	2	;div vars
DICNTR:	.rmb	1

SANS:	.rmb	2
SCNTR:	.rmb	1

; Sort

SCNT1:	.rmb	1
SCNT2:	.rmb	1


; Direct Page Variables

	.org	0x40

; DCNTR

DCNTR:	.rmb	2	;BCD counter value

; BCD routine data

ABD:	.rmb	4
ACD:	.rmb	4
SUBEDS:	.rmb	4
SUBERS:	.rmb	4
HEXD:	.rmb	2
DECD:	.rmb	3
