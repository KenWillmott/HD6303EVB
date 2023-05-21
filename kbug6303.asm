* KBUG
* K. Willmott 2023
* tested, working

* minibug originally modified for NMIS-0021

* 2023-03-01 adapt for 6303Y
* 2023-05-18 first clean up, add some comments

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


* start of boot ROM area
* EEPROM is actually $E000-$FFFF

       ORG    $FE00

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
INCH   BSR    GETCH
       JMP    OUTCH    ECHO CHAR

* INPUT HEX CHAR
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
       BSR    OUTCH
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

*  formatted output entry points
*

OUTHL  LSRA           OUT HEX LEFT BCD DIGIT
       LSRA
       LSRA
       LSRA

OUTHR  ANDA  #$F      OUT HEX RIGHT BCD DIGIT
       ADDA  #$30
       CMPA  #$39
       BLS    OUTCH
       ADDA  #$7

* OUTPUT ONE CHAR
*

OUTCH  PSHB           SAVE B-REG
OUTC1  LDAB  TRCSR1
       ANDB  #TDRE
       BEQ    OUTC1    XMIT NOT READY

       STAA  TDR   OUTPUT CHARACTER
       PULB
       RTS

OUT2H  LDAA  0,X      OUTPUT 2 HEX CHAR
       BSR    OUTHL    OUT LEFT HEX CHAR
       LDAA  0,X
       BSR    OUTHR    OUT RIGHT HEX VHAR
       INX
       RTS

OUT2HS BSR    OUT2H    OUTPUT 2 HEX CHAR + SPACE
OUTS   LDAA  #$20     SPACE
       BRA    OUTCH    (BSR & RTS)

     
* PRINT CONTENTS OF STACK
PRINT  TSX
       STX    SP       SAVE STACK POINTER
       LDAB  #9
PRINT2 BSR    OUT2HS   OUT 2 HEX & SPCACE
       DECB
       BNE    PRINT2

* ENTER POWER ON SEQUENCE
START  EQU    *

* set rate and mode
       LDAA  #CC0 	asynch, E/16 baud
       STAA  RMCR

* initialize SCI
       LDAA  #SCREN+SCTEN     enable RX TX
       STAA  TRCSR1

CONTRL LDS    #STACK   SET STACK POINTER
       LDAA  #$D      CARRIAGE RETURN
       BSR    OUTCH
       LDAA  #$A      LINE FEED
       BSR    OUTCH

       JSR    INCH     READ CHARACTER
       TAB
       BSR    OUTS     PRINT SPACE
       CMPB  #'L
       BNE    *+5
       JMP    LOAD
       CMPB  #'M
       BEQ    CHANGE
       CMPB  #'P
       BEQ    PRINT    STACK
       CMPB  #'G
       BNE    CONTRL
       RTI             GO

* Initialize processor reset vector
       ORG    $FFFE
       FDB    START

* Data Section
* located in internal RAM

       ORG    $100

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
       END
