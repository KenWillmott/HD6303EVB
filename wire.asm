* PCF8584 interface code for HD6303Y
*
* NON WORKING - SAMPLE CODE
*
* When running, the oscilloscope shows
* a start pulse but no data is sent
*

		org	$B800

OUT2H		equ	$fe19		link manually to monitor output routine

port		equ	$D000		IO port on select

data		equ	port
contrl	equ	port+1

* PCF8584 bit definitions

PIN		equ	$80
BB		equ	$01
LRB		equ	$08

* test framework

		bsr	init
		ldx	#time

mainlo	bsr	txbyte
		bsr	rxbyte
		jsr	OUT2H
		dex
		bra	mainlo

* init PCF8584 for operation

init		equ	*

		ldaa	#$80
		staa	contrl	clear status and select data reg

		ldaa	#$55
		staa	data		set own address to $AA

		ldaa	#$A0
		staa	contrl	select clock control register

		ldaa	#$1C
		staa	data		clock:=12 MHz, SCL:=90 kHz

		ldaa	#$C1
		staa	contrl	see data sheet, sel data register

		rts

* transmit operation

txbyte	equ	*

		bsr	busbsy

		ldaa	sladdr
		staa	data		load slave address

		ldaa	#$C5
		staa	contrl		generate start condition

* begin polling

		bsr	txbusy

a000		bita	#LRB
		bne	a000		freeze if no slave ack

*		bne	donetx	if no slave ack

* send only one byte for now

		ldaa	#2		PCF8563 address reg set to seconds
		staa	data

		bsr	txbusy

donetx	ldaa	#$C3
		staa	contrl		generate stop condition
		rts

* receive operation

rxbyte	equ	*

		ldaa	sladdr
		oraa	#1			set tx/rx bit
		staa	data		load slave address

		bsr	busbsy

		ldaa	#$C5
		staa	contrl	generate start condition

		bsr	txbusy

a001		bita	#LRB
		bne	a001	if no slave ack

* receive only one byte for now

		ldaa	#$40
		staa	contrl	clear ACK bit

		ldaa	data		read I2C device (dummy read)
		staa	time+1

		bsr	txbusy

donerx	ldaa	#$C3
		staa	contrl	generate stop condition

		ldaa	data		read I2C device
		staa	time

		rts

* wait for tx complete

txbusy	ldaa	contrl
		bita	#PIN
		bne	txbusy	wait for tx complete
		rts

* wait for free bus

busbsy	ldaa	contrl
		bita	#BB
		beq	busbsy	wait while bus is busy
		rts

* data section

sladdr		fcb	$A2		PCF8563 slave address

time		rmb	2		seconds returned from RTC

		end

