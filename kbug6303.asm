* KBUG
* K. Willmott 2023
* tested, working

* minibug originally modified for NMIS-0021

* 2023-03-01 adapt for 6303Y
* 2023-05-18 first clean up, add some comments
* 2023-05-20 add feedback text, write "W", exec command "X"
* 2023-05-21 fixed stack initialization error
* 2023-05-22 add CPU vector jump table
* 2023-05-25 add primitive RAM test

* based on the original source
* COPYWRITE 1973, MOTOROLA INC
* REV 004 (USED WITH MIKBUG)

* HD6303Y register definitions (<power on default value>):

RMCR   EQU   $10 rate mode control register ($c0)
CC0    EQU   $04 set for asynch mode

TRCSR1 EQU   $11 control status register 1 ($20)
TRCSR2 EQU   $1e control status register 2 ($28)
SCREN  EQU   $08 RE bit - RX enable
SCTEN  EQU   $02 TE bit - TX enable

RDRF   EQU   $80 receive data register full flag
TDRE   EQU   $20 transmit data register empty flag

RDR    EQU   $12 rx data register (0)
TDR    EQU   $13 tx data register (undefined)

* Address of boot or test code, RTS to return to monitor

XCALL			EQU	$B800		call test code here

INTRAM		equ	$40
EXTRAM		EQU    $0140
ramst			equ	EXTRAM	external ram
ramend		equ	$C000		memory limit


* start of boot ROM area
* EEPROM is actually $E000-$FFFF

       ORG    $FD00

* ENTER POWER ON SEQUENCE
START  EQU    *

* set rate and mode
       LDAA  #CC0 	asynch, E/16 baud
       STAA  RMCR

* initialize SCI
       LDAA  #SCREN+SCTEN     enable RX TX
       STAA  TRCSR1

* set up vector jump table

		LDS	#EXTRAM-1   SET STACK POINTER
		LDAB	#10
		LDAA	#$7E		JMP INSTRUCTION
		LDX	#VECERR

NEXTVC	PSHX
		PSHA
		DECB
		BNE	NEXTVC

		LDS    #STACK   SET STACK POINTER

* run main program
       JMP   KBUG

* Utility routines follow
*

* INPUT ONE CHAR INTO A-REGISTER
GETCH  LDAA  TRCSR1
       ANDA  #RDRF
       BEQ    GETCH     RECEIVE NOT READY

       LDAA  RDR   INPUT CHARACTER
       CMPA  #$7F
       BEQ    GETCH     RUBOUT; IGNORE
       RTS

* Input a character with output echo
* implemented as an entry point to OUTCH

INCH   BSR   GETCH
       CMPA  #$0D
       BEQ   NOECHO

* OUTPUT ONE CHAR in Accumulator A
*

OUTCH  PSHB           SAVE B-REG
OUTC1  LDAB  TRCSR1
       ANDB  #TDRE
       BEQ    OUTC1    XMIT NOT READY

       STAA  TDR   OUTPUT CHARACTER
       PULB
NOECHO RTS

* Output a char string
* address of string in X

PRSTRN LDAA ,X  Get a char
       BEQ PRDONE
       BSR OUTCH
       INX
       BRA PRSTRN
PRDONE RTS

* Report vector problem

VECERR LDX	#ERROUT
       JSR PRSTRN
FREEZE BRA FREEZE     Suspend via endless loop

* boot time memory test

MEMTST	ldx	#ramst
		stx	memtop

loop		ldaa	0,x	get byte
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

done		stx	memtop

		rts


*
* end utility routines


* Monitor code begins
*

* INPUT HEX CHAR
*

INHEX  BSR    INCH
       CMPA  #'0
       BMI    C1       NOT HEX
       CMPA  #'9
       BLE    IN1HG    IS HEX
       CMPA  #'A
       BMI    C1       NOT HEX
       CMPA  #'F
       BGT    C1       NOT HEX
       SUBA  #'A-'9-1    MAKE VALUES CONTIGUOUS
IN1HG  RTS

* S-record loader
*

LOAD  BSR    INCH
       CMPA  #'S
       BNE    LOAD    1ST CHAR NOT (S)
       BSR    INCH
       CMPA  #'9
       BEQ    C1
       CMPA  #'1
       BNE    LOAD    2ND CHAR NOT (1)
       CLR    CKSM     ZERO CHECKSUM
       BSR    BYTE     READ BYTE
       SUBA  #2
       STAA  BYTECT   BYTE COUNT

* BUILD ADDRESS
       BSR    BADDR

* STORE DATA
LOAD11 BSR    BYTE
       DEC    BYTECT
       BEQ    LOAD15   ZERO BYTE COUNT
       STAA ,X        STORE DATA
       INX
       BRA    LOAD11

LOAD15 INC    CKSM
       BEQ    LOAD
LOAD19 LDAA  #'?      PRINT QUESTION MARK

       JSR    OUTCH
C1     JMP    CONTRL

* BUILD ADDRESS
*

BADDR  BSR    BYTE     READ 2 FRAMES
       STAA XHI
       BSR    BYTE
       STAA XLOW
       LDX    XHI      (X) ADDRESS WE BUILT
       RTS

* INPUT BYTE (TWO FRAMES)
*

BYTE   BSR    INHEX    GET HEX CHAR
       ASLA
       ASLA
       ASLA
       ASLA
       TAB
       BSR    INHEX
       ANDA  #$0F     MASK TO 4 BITS
       ABA
       TAB
       ADDB  CKSM
       STAB  CKSM
       RTS

* CHANGE MEMORY (M AAAA DD NN)
*

CHANGE BSR    BADDR    BUILD ADDRESS
       BSR    OUTS     PRINT SPACE
       BSR    OUT2HS
       BSR    BYTE
       DEX
       STAA ,X
       CMPA ,X
       BNE    LOAD19   MEMORY DID NOT CHANGE
       BRA    CONTRL

* WRITE MEMORY (M AAAA NN)
*

MWRITE BSR    BADDR    BUILD ADDRESS
       BSR    OUTS     PRINT SPACE
       BSR    BYTE
       STAA ,X
       BRA    CONTRL

*  formatted output entry points
*

OUTHL  LSRA           OUT HEX LEFT BCD DIGIT
       LSRA
       LSRA
       LSRA

OUTHR  ANDA  #$F      OUT HEX RIGHT BCD DIGIT
       ADDA  #$30
       CMPA  #$39
       BHI   ISALF
       JMP    OUTCH

ISALF  ADDA  #$7
       JMP    OUTCH

OUT2H  LDAA  0,X      OUTPUT 2 HEX CHAR
       BSR    OUTHL    OUT LEFT HEX CHAR
       LDAA  0,X
       BSR    OUTHR    OUT RIGHT HEX VHAR
       INX
       RTS

OUT2HS BSR    OUT2H    OUTPUT 2 HEX CHAR + SPACE
OUTS   LDAA  #$20     SPACE
       JMP    OUTCH    (BSR & RTS)

* Monitor startup
*

KBUG		jsr	MEMTST	check memory

		LDX   #MOTD		Print start up message
		JSR   PRSTRN

		ldx	#MMSG1	Print memtest results
		jsr	PRSTRN
		ldx	#memtop
		jsr	OUT2H
		jsr	OUT2H		
		ldx	#MMSG2
		jsr	PRSTRN

		LDX   #cmdhlp   Print commands message
		JSR   PRSTRN

		BRA   CONTRL

     
* PRINT CONTENTS OF STACK
PRINT  LDX   #REGHDR   Print register titles
       JSR   PRSTRN
       TSX
       STX    SP       SAVE STACK POINTER
       LDAB  #9
PRINT2 BSR    OUT2HS   OUT 2 HEX & SPCACE
       DECB
       BNE    PRINT2

CONTRL LDS    #STACK   SET STACK POINTER
       LDAA  #$D      CARRIAGE RETURN
       JSR    OUTCH
       LDAA  #$A      LINE FEED
       JSR    OUTCH
       LDX   #PROMPT   Print start up message
       JSR   PRSTRN

       JSR    INCH     READ CHARACTER
       TAB
       JSR    OUTS     PRINT SPACE

       CMPB  #'X		Execute stored program
       BNE    NOTQ
       JSR    XCALL
       JMP    KBUG

NOTQ   CMPB  #'L		Load S-record
       BNE    NOTL
       JMP    LOAD

NOTL   CMPB  #'M		Modify
       BNE    NOTM
       JMP    CHANGE

NOTM   CMPB  #'W		Write
		BNE NOTW
       JMP    MWRITE

NOTW   CMPB  #'P		Print
       BEQ    PRINT
       CMPB  #'G		Go
       BNE    CONTRL
       RTI             GO

* Constant data section

MOTD		FCB $0D,$0A
		FCC "*** Kbug 1.00 for HD6303Y EVB 1.0 ***"
		FCB $0D,$0A,0

cmdhlp	FCC "G(o),L(oad),P(roc),M(od),W(rite),X(ecute)?:"
       	FCB $0D,$0A,0

PROMPT FCC "KBUG->"
       FCB 0

REGHDR FCB $0D,$0A
       FCC "CC B  A  XH XL PH PL SH SL"
       FCB $0D,$0A,0

ERROUT FCB $0D,$0A
       FCC "Err - vector table entry no init"
       FCB $0D,$0A,0

MMSG1		FCC "RAM test passed to "
		FCB 0

MMSG2		FCC "."
		FCB $0D,$0A,0

* Processor hardware vectors
* There are ten, not including CPU Reset

       ORG    $FFEA

IRQ2   FDB    VIRQ2
CMI    FDB    VCMI
TRAP   FDB    VTRAP
SIO    FDB    VSIO
TOI    FDB    VTOI
OCI    FDB    VOCI
ICI    FDB    VICI
IRQ1   FDB    VIRQ1
SWI    FDB    VSWI
NMI    FDB    VNMI
RES    FDB    START

* Data Section
* located in internal RAM

		org	INTRAM

memtop	rmb	2

       ORG    EXTRAM-44

STACK  RMB    1        STACK POINTER
* REGISTERS FOR GO
       RMB    1        CONDITION CODES
       RMB    1        B ACCUMULATOR
       RMB    1        A
       RMB    1        X-HIGH
       RMB    1        X-LOW
       RMB    1        P-HIGH
       RMB    1        P-LOW
SP     RMB    1        S-HIGH
       RMB    1        S-LOW
* END REGISTERS FOR GO
CKSM   RMB    1        CHECKSUM
BYTECT RMB    1        BYTE COUNT
XHI    RMB    1        XREG HIGH
XLOW   RMB    1        XREG LOW

* CPU vector jump table

VIRQ2   RMB	 3
VCMI    RMB	 3
VTRAP   RMB	 3
VSIO    RMB	 3
VTOI    RMB	 3
VOCI    RMB	 3
VICI    RMB	 3
VIRQ1   RMB	 3
VSWI    RMB	 3
VNMI    RMB	 3

HERE EQU *

       END
