;   usbdux_firmware.asm
;   Copyright (C) 2010,2011 Bernd Porr, Bernd.Porr@f2s.com
;   For usbduxsigma.c 0.5+
;
;   This program is free software; you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation; either version 2 of the License, or
;   (at your option) any later version.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License
;   along with this program; if not, write to the Free Software
;   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
;
;
; Firmware: usbduxsigma_firmware.asm for usbduxsigma.c
; Description: University of Stirling USB DAQ & INCITE Technology Limited
; Devices: [ITL] USB-DUX-SIGMA (usbduxsigma.ko)
; Author: Bernd Porr <Bernd.Porr@f2s.com>
; Updated: 24 Jul 2011
; Status: testing
;
;;;
;;;
;;;
	
	.inc	fx2-include.asm

;;; a couple of flags
	.equ	CMD_FLAG,80h	; flag for the next in transfer
	.equ	PWMFLAG,81h	; PWM on or off?
	.equ	MAXSMPL,82H	; maximum number of samples, n channellist
	.equ	MUXSG0,83H	; content of the MUXSG0 register

;;; actual code
	.org	0000h		; after reset the processor starts here
	ljmp	main		; jump to the main loop

	.org	0043h		; the IRQ2-vector
	ljmp	jmptbl		; irq service-routine
	
	.org	0100h		; start of the jump table

jmptbl:	ljmp	sudav_isr
	nop
	ljmp	sof_isr
	nop
	ljmp	sutok_isr
	nop
	ljmp	suspend_isr
	nop
	ljmp	usbreset_isr
	nop
	ljmp	hispeed_isr
	nop
	ljmp	ep0ack_isr
	nop
	ljmp	spare_isr
	nop
	ljmp	ep0in_isr
	nop
	ljmp	ep0out_isr
	nop
	ljmp	ep1in_isr
	nop
	ljmp	ep1out_isr
	nop
	ljmp	ep2_isr
	nop
	ljmp	ep4_isr
	nop
	ljmp	ep6_isr
	nop
	ljmp	ep8_isr
	nop
	ljmp	ibn_isr
	nop
	ljmp	spare_isr
	nop
	ljmp	ep0ping_isr
	nop
	ljmp	ep1ping_isr
	nop
	ljmp	ep2ping_isr
	nop
	ljmp	ep4ping_isr
	nop
	ljmp	ep6ping_isr
	nop
	ljmp	ep8ping_isr
	nop
	ljmp	errlimit_isr
	nop
	ljmp	spare_isr
	nop
	ljmp	spare_isr
	nop
	ljmp	spare_isr
	nop
	ljmp	ep2isoerr_isr
	nop
	ljmp	ep4isoerr_isr
	nop
	ljmp	ep6isoerr_isr
	nop
	ljmp	ep8isoerr_isr

	
	;; dummy isr
sudav_isr:	
sutok_isr:	
suspend_isr:	
usbreset_isr:	
hispeed_isr:	
ep0ack_isr:	
spare_isr:	
ep0in_isr:	
ep0out_isr:	
ep1in_isr:	
ibn_isr:	
ep0ping_isr:	
ep1ping_isr:	
ep2ping_isr:	
ep4ping_isr:	
ep6ping_isr:	
ep8ping_isr:	
errlimit_isr:	
ep2isoerr_isr:	
ep4isoerr_isr:	
ep6isoerr_isr:	
ep8isoerr_isr:
ep6_isr:
ep2_isr:
ep4_isr:	

	push	dps
	push	dpl
	push	dph
	push	dpl1
	push	dph1
	push	acc
	push	psw

	;; clear the USB2 irq bit and return
	mov	a,EXIF
	clr	acc.4
	mov	EXIF,a

	pop	psw
	pop	acc 
	pop	dph1 
	pop	dpl1
	pop	dph 
	pop	dpl 
	pop	dps
	
	reti

		
;;; main program
;;; basically only initialises the processor and
;;; then engages in an endless loop
main:
	mov	DPTR,#CPUCS	; CPU control register
	mov	a,#00010000b	; 48Mhz
	lcall	syncdelaywr

        mov     dptr,#REVCTL
        mov     a,#00000011b    ; allows skip
        lcall   syncdelaywr

	mov	IP,#0		; all std 8051 int have low priority
	mov	EIP,#0FFH	; all FX2 interrupts have high priority
	
	mov	dptr,#INTSETUP	; IRQ setup register
	mov	a,#08h		; enable autovector
	lcall	syncdelaywr

	mov	dptr,#PORTCCFG
	mov	a,#0
	lcall	syncdelaywr

	lcall	initAD		; init the ports to the converters

	lcall	initeps		; init the isochronous data-transfer

;;; main loop, rest is done as interrupts
mloop2:	nop

;;; pwm
	mov	r0,#PWMFLAG	; pwm on?
	mov	a,@r0		; get info
	jz	mloop2		; it's off

	mov	a,GPIFTRIG	; GPIF status
	anl	a,#80h		; done bit
	jz	mloop2		; GPIF still busy

        mov     a,#01h		; WR,EP4, 01 = EP4
        mov     GPIFTRIG,a	; restart it

	sjmp	mloop2		; loop for ever


;;; initialise the ports for the AD-converter
initAD:
	mov	r0,#MAXSMPL	; length of channellist
	mov	@r0,#0		; we don't want to accumlate samples

	mov	OEA,#11100000b	; PortA7,A6,A5 Outputs
	mov	IOA,#01100000b	; /CS = 1 and START = 0
	mov	dptr,#IFCONFIG	; switch on clock on IFCLK pin
	mov	a,#10100000b	; gpif, 30MHz, internal IFCLK -> 15MHz for AD
	lcall	syncdelaywr

	mov	SCON0,#013H	; ser rec en, TX/RX: stop, 48/12MHz=4MHz clock
	
	mov	dptr,#PORTECFG
	mov	a,#00001000b	; special function for port E: RXD0OUT
	lcall	syncdelaywr

	ret


;;; send a byte via SPI
;;; content in a, dptr1 is changed
;;; the lookup is done in dptr1 so that the normal dptr is not affected
;;; important: /cs needs to be reset to 1 by the caller: IOA.5
sendSPI:
	inc	DPS
	
	;; bit reverse
	mov	dptr,#swap_lut	; lookup table
	movc 	a,@a+dptr	; reverse bits

	;; clear interrupt flag, is used to detect
	;; successful transmission
	clr	SCON0.1		; clear interrupt flag

	;; start transmission by writing the byte
	;; in the transmit buffer
	mov	SBUF0,a		; start transmission

	;; wait for the end of the transmission
sendSPIwait:
	mov	a,SCON0		; get transmission status
	jnb     ACC.1,sendSPIwait	; loop until transmitted

	inc	DPS
	
	ret



	
;;; receive a byte via SPI
;;; content in a, dptr is changed
;;; the lookup is done in dptr1 so that the normal dptr is not affected
;;; important: the /CS needs to be set to 1 by the caller via "setb IOA.5"
recSPI:
	inc	DPS
	
	clr	IOA.5		; /cs to 0	

	;; clearning the RI bit starts reception of data
	clr	SCON0.0

recSPIwait:
	;; RI goes back to 1 after the reception of the 8 bits
	mov	a,SCON0		; get receive status
	jnb	ACC.0,recSPIwait; loop until all bits received

	;; read the byte from the buffer
	mov	a,SBUF0		; get byte
	
	;; lookup: reverse the bits
	mov	dptr,#swap_lut	; lookup table
	movc 	a,@a+dptr	; reverse the bits

	inc	DPS
	
	ret



	
;;; reads a register
;;; register address in a
;;; returns value in a
registerRead:
	anl	a,#00001111b	; mask out the index to the register
	orl	a,#01000000b	; 010xxxxx indicates register read
	clr	IOA.5		; ADC /cs to 0
	lcall	sendSPI		; send the command over
	lcall	recSPI		; read the contents back
	setb	IOA.5		; ADC /cs to 1
	ret



;;; writes to a register
;;; register address in a
;;; value in r0
registerWrite:
	push	acc
	anl	a,#00001111b	; mask out the index to the register
	orl	a,#01100000b	; 011xxxxx indicates register write

	clr	IOA.5		; ADC /cs to 0	

	lcall	sendSPI		;
	mov	a,r0
	lcall	sendSPI

	setb	IOA.5		; ADC /cs to 1
	pop	acc

	lcall	registerRead	; check if the data has arrived in the ADC
	mov	0f0h,r0		; register B
	cjne	a,0f0h,registerWrite ; something went wrong, try again
	
	ret



;;; initilise the endpoints
initeps:
	mov	dptr,#FIFORESET
	mov	a,#80H		
	movx	@dptr,a		; reset all fifos
	mov	a,#2	
	movx	@dptr,a		; 
	mov	a,#4		
	movx	@dptr,a		; 
	mov	a,#6		
	movx	@dptr,a		; 
	mov	a,#8		
	movx	@dptr,a		; 
	mov	a,#0		
	movx	@dptr,a		; normal operat
	
	mov	DPTR,#EP2CFG
	mov	a,#10010010b	; valid, out, double buff, iso
	movx	@DPTR,a

	mov	dptr,#EP2FIFOCFG
	mov	a,#00000000b	; manual
	movx	@dptr,a

	mov	dptr,#EP2BCL	; "arm" it
	mov	a,#00h
	movx	@DPTR,a		; can receive data
	lcall	syncdelay	; wait to sync
	movx	@DPTR,a		; can receive data
	lcall	syncdelay	; wait to sync
	movx	@DPTR,a		; can receive data
	lcall	syncdelay	; wait to sync
	
	mov	DPTR,#EP1OUTCFG
	mov	a,#10100000b	; valid
	movx	@dptr,a

	mov	dptr,#EP1OUTBC	; "arm" it
	mov	a,#00h
	movx	@DPTR,a		; can receive data
	lcall	syncdelay	; wait until we can write again
	movx	@dptr,a		; make shure its really empty
	lcall	syncdelay	; wait

	mov	DPTR,#EP6CFG	; ISO data from here to the host
	mov	a,#11010010b	; Valid
	movx	@DPTR,a		; ISO transfer, double buffering

	mov	DPTR,#EP8CFG	; EP8
	mov	a,#11100000b	; BULK data from here to the host
	movx	@DPTR,a		;

	;; enable interrupts
	mov	dptr,#EPIE	; interrupt enable
	mov	a,#10001000b	; enable irq for ep1out,8
	movx	@dptr,a		; do it

	mov	dptr,#EPIRQ	; clear IRQs
	mov	a,#10001000b
	movx	@dptr,a
	
        mov     DPTR,#USBIE	; USB int enables register
        mov     a,#2            ; enables SOF (1ms/125us interrupt)
        movx    @DPTR,a         ; 

	mov	EIE,#00000001b	; enable INT2/USBINT in the 8051's SFR
	mov	IE,#80h		; IE, enable all interrupts

	ret


;;; Reads one ADC channel from the converter and stores
;;; the result at dptr
readADCch:
	;; we do polling: we wait until DATA READY is zero
	mov	a,IOA		; get /DRDY
	jb	ACC.0,readADCch	; wait until data ready (DRDY=0)
	
	;; reading data is done by just dropping /CS and start reading and
	;; while keeping the IN signal to the ADC inactive
	clr	IOA.5		; /cs to 0
	
	;; 1st byte: STATUS
	lcall	recSPI		; index
	movx	@dptr,a		; store the byte
	inc	dptr		; increment pointer

	;; 2nd byte: MSB
	lcall	recSPI		; data
	movx	@dptr,a
	inc	dptr

	;; 3rd byte: MSB-1
	lcall	recSPI		; data
	movx	@dptr,a
	inc	dptr

	;; 4th byte: LSB
	lcall	recSPI		; data
	movx	@dptr,a
	inc	dptr
	
	;; got all bytes
	setb	IOA.5		; /cs to 1
	
	ret

	

;;; interrupt-routine for SOF
sof_isr:
	push	dps
	push	dpl
	push	dph
	push	dpl1
	push	dph1
	push	acc
	push	psw
	push	00h		; R0
	push	01h		; R1
	push	02h		; R2
	push	03h		; R3
	push	04h		; R4
	push	05h		; R5
	push	06h		; R6
	push	07h		; R7

	clr	IE.7		; make sure that no other int's disturbe us
	
	mov	a,EP2468STAT
	anl	a,#20H		; full?
	jnz	epfull		; EP6-buffer is full

	clr	IOA.7		; stop converter, START = 0

	;; make sure that we are starting with the first channel
	mov	r0,#MUXSG0	;
	mov	a,@r0		; get config of MUXSG0
	mov	r0,a
	mov	a,#04H		; MUXSG0
	lcall	registerWrite	; this resets the channel sequence

	setb	IOA.7		; start converter, START = 1
	
	;; get the data from the ADC as fast as possible and transfer it
	;; to the EP buffer
	mov	dptr,#0f800h	; EP6 buffer
	mov	a,IOD		; get DIO D
	movx	@dptr,a		; store it
	inc	dptr		; next byte
	mov	a,IOC		; get DIO C
	movx	@dptr,a		; store it
	inc	dptr		; next byte
	mov	a,IOB		; get DIO B
	movx	@dptr,a		; store it
	inc	dptr		; next byte
	mov	a,#0		; just zero
	movx	@dptr,a		; pad it up
	inc	dptr		; algin along a 32 bit word

	mov	r0,#MAXSMPL	; number of samples to transmit
	mov	a,@r0		; get them
	mov	r1,a		; counter

	;; main loop, get all the data
eptrans:	
	lcall	readADCch	; get one reading
	djnz	r1,eptrans	; do until we have all content transf'd

	clr	IOA.7		; stop converter, START = 0

	;; arm the endpoint and send off the data
	mov	DPTR,#EP6BCH	; byte count H
	mov	a,#0		; is zero
	lcall	syncdelaywr	; wait until we can write again
	
	mov	r0,#MAXSMPL	; number of samples to transmit
	mov	a,@r0		; get them
	rl	a		; a=a*2
	rl	a		; a=a*2
	add	a,#4		; four bytes for DIO
	mov	DPTR,#EP6BCL	; byte count L
	lcall	syncdelaywr	; wait until we can write again

epfull:
	;; do the D/A conversion
	mov	a,EP2468STAT
	anl	a,#01H		; empty
	jnz	epempty		; nothing to get

	mov	dptr,#0F000H	; EP2 fifo buffer
	lcall	dalo		; conversion

	mov	dptr,#EP2BCL	; "arm" it
	mov	a,#00h
	lcall	syncdelaywr	; wait for the rec to sync
	lcall	syncdelaywr	; wait for the rec to sync

epempty:	
	;; clear INT2
	mov	a,EXIF		; FIRST clear the USB (INT2) interrupt request
	clr	acc.4
	mov	EXIF,a		; Note: EXIF reg is not 8051 bit-addressable
	
	mov	DPTR,#USBIRQ	; points to the SOF
	mov	a,#2		; clear the SOF
	movx	@DPTR,a

nosof:
	setb	IE.7		; re-enable global interrupts
	
	pop	07h
	pop	06h
	pop	05h
	pop	04h		; R4
	pop	03h		; R3
	pop	02h		; R2
	pop	01h		; R1
	pop	00h		; R0
	pop	psw
	pop	acc 
	pop	dph1 
	pop	dpl1
	pop	dph 
	pop	dpl 
	pop	dps
	reti


reset_ep8:
	;; erase all data in ep8
	mov	dptr,#FIFORESET
	mov	a,#80H		; NAK
	lcall	syncdelaywr
	mov	dptr,#FIFORESET
	mov	a,#8		; reset EP8
	lcall	syncdelaywr
	mov	dptr,#FIFORESET
	mov	a,#0		; normal operation
	lcall	syncdelaywr
	ret


reset_ep6:
	;; throw out old data
	mov	dptr,#FIFORESET
	mov	a,#80H		; NAK
	lcall	syncdelaywr
	mov	dptr,#FIFORESET
	mov	a,#6		; reset EP6
	lcall	syncdelaywr
	mov	dptr,#FIFORESET
	mov	a,#0		; normal operation
	lcall	syncdelaywr
	ret


;;; configure the ADC converter
;;; the dptr points to the init data:
;;; CONFIG 0,1,3,4,5,6
;;; note that CONFIG2 is omitted
configADC:	
	clr	IOA.7		; stops ADC: START line of ADC = L
	setb	IOA.5		; ADC /cs to 1

	;; just in case something has gone wrong
	nop
	nop
	nop

	mov	a,#11000000b	; reset	the ADC
	clr	IOA.5		; ADC /cs to 0	
	lcall	sendSPI
	setb	IOA.5		; ADC /cs to 1	

	movx	a,@dptr		;
	inc	dptr
	mov	r0,a
	mov	a,#00H		; CONFIG0
	lcall	registerWrite

	movx	a,@dptr		;
	inc	dptr
	mov	r0,a
	mov	a,#01H		; CONFIG1
	lcall	registerWrite

	movx	a,@dptr		;
	inc	dptr
	mov	r0,a
	mov	a,#03H		; MUXDIF
	lcall	registerWrite

	movx	a,@dptr		;
	inc	dptr
	mov	r0,#MUXSG0
	mov	@r0,a		; store it for reset purposes
	mov	r0,a
	mov	a,#04H		; MUXSG0
	lcall	registerWrite
	
	movx	a,@dptr		;
	inc	dptr
	mov	r0,a
	mov	a,#05H		; MUXSG1
	lcall	registerWrite
	
	movx	a,@dptr		;
	inc	dptr
	mov	r0,a
	mov	a,#06H		; SYSRED
	lcall	registerWrite

	ret

	
;;; interrupt-routine for ep1out
;;; receives the channel list and other commands
ep1out_isr:
	push	dps
	push	dpl
	push	dph
	push	dpl1
	push	dph1
	push	acc
	push	psw
	push	00h		; R0
	push	01h		; R1
	push	02h		; R2
	push	03h		; R3
	push	04h		; R4
	push	05h		; R5
	push	06h		; R6
	push	07h		; R7

	clr	IE.7		; block other interrupts
		
	mov	dptr,#0E780h	; FIFO buffer of EP1OUT
	movx	a,@dptr		; get the first byte
	mov	r0,#CMD_FLAG	; pointer to the command byte
	mov 	@r0,a		; store the command byte for ep8

	mov	dptr,#ep1out_jmp; jump table for the different functions
	rl	a		; multiply by 2: sizeof sjmp
	jmp	@a+dptr		; jump to the jump table
	;; jump table, corresponds to the command bytes defined
	;; in usbdux.c
ep1out_jmp:
	sjmp	startadc	; a=0
	sjmp	single_da	; a=1
	sjmp	config_digital_b; a=2
	sjmp	write_digital_b	; a=3
	sjmp	initsgADchannel	; a=4
	sjmp	nothing		; a=5
	sjmp	nothing		; a=6
	sjmp	pwm_on		; a=7
	sjmp	pwm_off		; a=8

nothing:
	ljmp	over_da

pwm_on:
	lcall	startPWM
	sjmp	over_da

pwm_off:
	lcall	stopPWM
	sjmp	over_da

initsgADchannel:
	mov	dptr,#0e781h	; FIFO buffer of EP1OUT
	lcall	configADC	; configures the ADC esp sel the channel

	lcall	reset_ep8	; reset FIFO: get rid of old bytes
	;; Save new A/D data in EP8. This is the first byte
	;; the host will read during an INSN. If there are
	;; more to come they will be handled by the ISR of
	;; ep8.
	lcall	ep8_ops		; get A/D data
		
	sjmp	over_da

	
;;; config AD:
;;; we write to the registers of the A/D converter
startadc:
	mov	dptr,#0e781h	; FIFO buffer of EP1OUT from 2nd byte

	movx	a,@dptr		; get length of channel list
	inc	dptr
	mov	r0,#MAXSMPL
	mov	@r0,a 		; length of the channel list

	lcall	configADC	; configures all registers

	lcall	reset_ep6	; reset FIFO
	
	;; load new A/D data into EP6
	;; This must be done. Otherwise the ISR is never called.
	;; The ISR is only called when data has _left_ the
	;; ep buffer here it has to be refilled.
	lcall	ep6_arm		; fill with dummy data
	
	sjmp	over_da

;;; Single DA conversion. The 2 bytes are in the FIFO buffer
single_da:
	mov	dptr,#0e781h	; FIFO buffer of EP1OUT
	lcall	dalo		; conversion
	sjmp	over_da

;;; configure the port B as input or output (bitwise)
config_digital_b:
	mov	dptr,#0e781h	; FIFO buffer of EP1OUT
	movx	a,@dptr		; get the second byte
	inc	dptr
	mov	OEB,a		; set the output enable bits
	movx	a,@dptr		; get the second byte
	inc	dptr
	mov	OEC,a
	movx	a,@dptr		; get the second byte
	inc	dptr
	mov	OED,a
	sjmp	over_da
	
;;; Write one byte to the external digital port B
;;; and prepare for digital read
write_digital_b:
	mov	dptr,#0e781h	; FIFO buffer of EP1OUT
	movx	a,@dptr		; command[1]
	inc	dptr
	mov	OEB,a		; output enable
	movx	a,@dptr		; command[2]
	inc	dptr
	mov	OEC,a
	movx	a,@dptr		; command[3]
	inc	dptr
	mov	OED,a 
	movx	a,@dptr		; command[4]
	inc	dptr
	mov	IOB,a		;
	movx	a,@dptr		; command[5]
	inc	dptr
	mov	IOC,a
	movx	a,@dptr		; command[6]
	inc	dptr
	mov	IOD,a

	lcall	reset_ep8	; reset FIFO of ep 8

	;; fill ep8 with new data from port B
	;; When the host requests the data it's already there.
	;; This must be so. Otherwise the ISR is not called.
	;; The ISR is only called when a packet has been delivered
	;; to the host. Thus, we need a packet here in the
	;; first instance.
	lcall	ep8_ops		; get digital data

	;; 
	;; for all commands the same
over_da:	
	mov	dptr,#EP1OUTBC
	mov	a,#00h
	lcall	syncdelaywr	; arm
	lcall	syncdelaywr	; arm
	lcall	syncdelaywr	; arm

	;; clear INT2
	mov	a,EXIF		; FIRST clear the USB (INT2) interrupt request
	clr	acc.4
	mov	EXIF,a		; Note: EXIF reg is not 8051 bit-addressable

	mov	DPTR,#EPIRQ	; 
	mov	a,#00001000b	; clear the ep1outirq
	movx	@DPTR,a

	setb	IE.7		; re-enable interrupts

	pop	07h
	pop	06h
	pop	05h
	pop	04h		; R4
	pop	03h		; R3
	pop	02h		; R2
	pop	01h		; R1
	pop	00h		; R0
	pop	psw
	pop	acc 
	pop	dph1 
	pop	dpl1
	pop	dph 
	pop	dpl 
	pop	dps
	reti


	
;;; all channels
dalo:
	movx	a,@dptr		; number of bytes to send out
	inc	dptr		; pointer to the first byte
	mov	r0,a		; counter
nextDA:	
	movx	a,@dptr		; get the byte
	inc	dptr		; point to the high byte
	mov	r3,a		; store in r3 for writeDA
	movx	a,@dptr		; get the channel number
	inc	dptr		; get ready for the next channel
	lcall	writeDA		; write value to the DAC
	djnz	r0,nextDA	; next channel
	ret



;;; D/A-conversion:
;;; channel number in a
;;; value in r3
writeDA:
	anl	a,#00000011b	; 4 channels
	mov	r1,#6		; the channel number needs to be shifted up
writeDA2:
	rl	a		; bit shift to the left
	djnz	r1,writeDA2	; do it 6 times
	orl	a,#00010000b	; update outputs after write
	mov	r2,a		; backup
	mov	a,r3		; get byte
	anl	a,#11110000b	; get the upper nibble
	mov	r1,#4		; shift it up to the upper nibble
writeDA3:
	rr	a		; shift to the upper to the lower
	djnz	r1,writeDA3
	orl	a,r2		; merge with the channel info
	clr	IOA.6		; /SYNC of the DA to 0
	lcall	sendSPI		; send it out to the SPI
	mov	a,r3		; get data again
	anl	a,#00001111b	; get the lower nibble
	mov	r1,#4		; shift that to the upper
writeDA4:
	rl	a
	djnz	r1,writeDA4
	anl	a,#11110000b	; make sure that's empty
	lcall	sendSPI
	setb	IOA.6		; /SYNC of the DA to 1
noDA:	ret
	


;;; arm ep6: this is just a dummy arm to get things going
ep6_arm:
	mov	DPTR,#EP6BCH	; byte count H
	mov	a,#0		; is zero
	lcall	syncdelaywr	; wait until the length has arrived
	
	mov	DPTR,#EP6BCL	; byte count L
	mov	a,#1		; is one
	lcall	syncdelaywr	; wait until the length has been proc
	ret
	


;;; converts one analog/digital channel and stores it in EP8
;;; also gets the content of the digital ports B,C and D depending on
;;; the COMMAND flag
ep8_ops:
	mov	dptr,#0fc01h	; ep8 fifo buffer
	clr	a		; high byte
	movx	@dptr,a		; set H=0
	mov	dptr,#0fc00h	; low byte
	mov	r0,#CMD_FLAG
	mov	a,@r0
	movx	@dptr,a		; save command byte

	mov	dptr,#ep8_jmp	; jump table for the different functions
	rl	a		; multiply by 2: sizeof sjmp
	jmp	@a+dptr		; jump to the jump table
	;; jump table, corresponds to the command bytes defined
	;; in usbdux.c
ep8_jmp:
	sjmp	ep8_err		; a=0, err
	sjmp	ep8_err		; a=1, err
	sjmp	ep8_err		; a=2, err
	sjmp	ep8_dio		; a=3, digital read
	sjmp	ep8_sglchannel	; a=4, analog A/D
	sjmp	ep8_err		; a=5, err
	sjmp	ep8_err		; a=6, err

	;; read one A/D channel
ep8_sglchannel:
	mov 	DPTR,#0fc01h	; EP8 FIFO
	setb	IOA.7		; start converter, START = 1
	lcall	readADCch	; get one reading
	clr	IOA.7		; stop the converter, START = 0

	sjmp	ep8_send	; send the data

	;; read the digital lines
ep8_dio:	
	mov 	DPTR,#0fc01h	; store the contents of port B
	mov	a,IOB		; in the next
	movx	@dptr,a		; entry of the buffer
	inc	dptr
	mov	a,IOC		; port C
	movx	@dptr,a		; next byte of the EP
	inc	dptr
	mov	a,IOD
	movx	@dptr,a		; port D
	
ep8_send:	
	mov	DPTR,#EP8BCH	; byte count H
	mov	a,#0		; is zero
	lcall	syncdelaywr
	
	mov	DPTR,#EP8BCL	; byte count L
	mov	a,#10H		; 16 bytes, bec it's such a great number...
	lcall	syncdelaywr	; send the data over to the host

ep8_err:	
	ret



;;; EP8 interrupt is the endpoint which sends data back after a command
;;; The actual command fills the EP buffer already
;;; but for INSNs we need to deliver more data if the count > 1
ep8_isr:	
	push	dps
	push	dpl
	push	dph
	push	dpl1
	push	dph1
	push	acc
	push	psw
	push	00h		; R0
	push	01h		; R1
	push	02h		; R2
	push	03h		; R3
	push	04h		; R4
	push	05h		; R5
	push	06h		; R6
	push	07h		; R7
		
	lcall	ep8_ops
	
	;; clear INT2
	mov	a,EXIF		; FIRST clear the USB (INT2) interrupt request
	clr	acc.4
	mov	EXIF,a		; Note: EXIF reg is not 8051 bit-addressable

	mov	DPTR,#EPIRQ	; 
	mov	a,#10000000b	; clear the ep8irq
	movx	@DPTR,a

	pop	07h
	pop	06h
	pop	05h
	pop	04h		; R4
	pop	03h		; R3
	pop	02h		; R2
	pop	01h		; R1
	pop	00h		; R0
	pop	psw
	pop	acc 
	pop	dph1 
	pop	dpl1
	pop	dph 
	pop	dpl 
	pop	dps
	reti



;;; GPIF waveform for PWM
waveform:
	;;      0     1     2     3     4     5     6     7(not used)
	;; len (gives 50.007Hz)
	.db	195,  195,  195,  195,  195,  195,  1,    1

	;; opcode
	.db	002H, 006H, 002H, 002H, 002H, 002H, 002H, 002H
	
	;; out
	.db	0ffH, 0ffH, 0ffH, 0ffH, 0ffH, 0ffH, 0ffH, 0ffH

	;; log
	.db	000H, 000H, 000H, 000H, 000H, 000H, 000H, 000H


stopPWM:
	mov	r0,#PWMFLAG	; flag for PWM
	mov	a,#0		; PWM (for the main loop)
	mov	@r0,a		; set it

	mov	dptr,#IFCONFIG	; switch off GPIF
	mov	a,#10100000b	; gpif, 30MHz, internal IFCLK
	lcall	syncdelaywr
	ret
	

;;; init PWM
startPWM:
	mov	dptr,#IFCONFIG	; switch on IFCLK signal
	mov	a,#10100010b	; gpif, 30MHz, internal IFCLK
	lcall	syncdelaywr

	mov	OEB,0FFH	; output to port B

	mov	DPTR,#EP4CFG
	mov	a,#10100000b	; valid, out, bulk
	movx	@DPTR,a

	;; reset the endpoint
	mov	dptr,#FIFORESET
	mov	a,#80h		; NAK
	lcall	syncdelaywr
	mov	a,#84h		; reset EP4 + NAK
	lcall	syncdelaywr
	mov	a,#0		; normal op
	lcall	syncdelaywr

	mov	dptr,#EP4BCL
	mov	a,#0H		; discard packets
	lcall	syncdelaywr	; empty FIFO buffer
	lcall	syncdelaywr	; empty FIFO buffer

	;; aborts all transfers by the GPIF
	mov	dptr,#GPIFABORT
	mov	a,#0ffh		; abort all transfers
	lcall	syncdelaywr

	;; wait for GPIF to finish
wait_f_abort:
	mov	a,GPIFTRIG	; GPIF status
	anl	a,#80h		; done bit
	jz	wait_f_abort	; GPIF busy

        mov     dptr,#GPIFCTLCFG
        mov     a,#10000000b    ; tri state for CTRL
        lcall   syncdelaywr

        mov     dptr,#GPIFIDLECTL
        mov     a,#11110000b    ; all CTL outputs low
        lcall   syncdelaywr

	;; abort if FIFO is empty
        mov     a,#00000001b    ; abort if empty
        mov     dptr,#EP4GPIFFLGSEL
        lcall   syncdelaywr

	;; 
        mov     a,#00000001b    ; stop if GPIF flg
        mov     dptr,#EP4GPIFPFSTOP
        lcall   syncdelaywr

	;; transaction counter
	mov	a,#0ffH
	mov	dptr,#GPIFTCB3
	lcall	syncdelaywr

	;; transaction counter
	mov	a,#0ffH
	mov	dptr,#GPIFTCB2
	lcall	syncdelaywr

	;; transaction counter
	mov	a,#0ffH		; 512 bytes
	mov	dptr,#GPIFTCB1
	lcall	syncdelaywr

	;; transaction counter
	mov	a,#0ffH
	mov	dptr,#GPIFTCB0
	lcall	syncdelaywr

	;; RDY pins. Not used here.
        mov     a,#0
        mov     dptr,#GPIFREADYCFG
        lcall   syncdelaywr

	;; drives the output in the IDLE state
        mov     a,#1
        mov     dptr,#GPIFIDLECS
        lcall   syncdelaywr

	;; direct data transfer from the EP to the GPIF
	mov	dptr,#EP4FIFOCFG
	mov	a,#00010000b	; autoout=1, byte-wide
	lcall	syncdelaywr

	;; waveform 0 is used for FIFO out
	mov	dptr,#GPIFWFSELECT
	mov	a,#00000000b
	movx	@dptr,a
	lcall	syncdelay

	;; transfer the delay byte from the EP to the waveform
	mov	dptr,#0e781h	; EP1 buffer
	movx	a,@dptr		; get the delay
	mov	dptr,#waveform	; points to the waveform
	mov	r2,#6		; fill 6 bytes
timloop:
	movx	@dptr,a		; save timing in a xxx
	inc	dptr
	djnz	r2,timloop	; fill the 6 delay bytes

	;; load waveform
        mov     AUTOPTRH2,#0E4H ; XDATA0H
        lcall   syncdelay
        mov     AUTOPTRL2,#00H  ; XDATA0L
        lcall   syncdelay

	mov	dptr,#waveform	; points to the waveform
	
        mov     AUTOPTRSETUP,#7 ; autoinc and enable
        lcall   syncdelay

        mov     r2,#20H         ; 32 bytes to transfer

wavetr:
        movx    a,@dptr
	inc	dptr
	push	dpl
	push	dph
	push	dpl1
	push	dph1
        mov     dptr,#XAUTODAT2
        movx    @dptr,a
        lcall   syncdelay
	pop	dph1 
	pop	dpl1
	pop	dph 
	pop	dpl
        djnz    r2,wavetr

	mov	dptr,#OUTPKTEND
	mov	a,#084H
	lcall	syncdelaywr
	lcall	syncdelaywr

	mov	r0,#PWMFLAG	; flag for PWM
	mov	a,#1		; PWM (for the main loop)
	mov	@r0,a		; set it

	ret

	

;; need to delay every time the byte counters
;; for the EPs have been changed.

syncdelay:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	ret

syncdelaywr:
	movx	@dptr,a
	lcall	syncdelay
	ret



	.org	1F00h		; lookup table at the end of memory

swap_lut:
.db 0,128,64,192,32,160,96,224,16,144,80,208,48,176,112,240,8,136
.db 72,200,40,168,104,232,24,152,88,216,56,184,120,248,4,132,68,196,36,164,100
.db 228,20,148,84,212,52,180,116,244,12,140,76,204,44,172,108,236,28,156,92,220
.db 60,188,124,252,2,130,66,194,34,162,98,226,18,146,82,210,50,178,114,242,10
.db 138,74,202,42,170,106,234,26,154,90,218,58,186,122,250,6,134,70,198,38,166
.db 102,230,22,150,86,214,54,182,118,246,14,142,78,206,46,174,110,238,30,158,94
.db 222,62,190,126,254,1,129,65,193,33,161,97,225,17,145,81,209,49,177,113,241,9
.db 137,73,201,41,169,105,233,25,153,89,217,57,185,121,249,5,133,69,197,37,165
.db 101,229,21,149,85,213,53,181,117,245,13,141,77,205,45,173,109,237,29,157,93
.db 221,61,189,125,253,3,131,67,195,35,163,99,227,19,147,83,211,51,179,115,243,11
.db 139,75,203,43,171,107,235,27,155,91,219,59,187,123,251,7,135,71,199,39,167
.db 103,231,23,151,87,215,55,183,119,247,15,143,79,207,47,175,111,239,31,159,95
.db 223,63,191,127,255



	
.End


