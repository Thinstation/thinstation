;   usbdux_firmware.asm
;   Copyright (C) 2004,2009 Bernd Porr, Bernd.Porr@f2s.com
;   For usbdux.c
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
; Firmware: usbdux_firmware.asm for usbdux.c
; Description: University of Stirling USB DAQ & INCITE Technology Limited
; Devices: [ITL] USB-DUX (usbdux.o)
; Author: Bernd Porr <Bernd.Porr@f2s.com>
; Updated: 17 Apr 2009
; Status: stable
;
;;;
;;;
;;;

	.inc	fx2-include.asm

	.equ	CHANNELLIST,80h	; channellist in indirect memory
	
	.equ	CMD_FLAG,90h	; flag if next IN transf is DIO
	.equ	SGLCHANNEL,91h	; channel for INSN
	.equ	PWMFLAG,92h	; PWM
	
	.equ	DIOSTAT0,98h	; last status of the digital port
	.equ	DIOSTAT1,99h	; same for the second counter
	
	.equ	CTR0,0A0H	; counter 0
	.equ	CTR1,0A2H	; counter 1
			
	.org	0000h		; after reset the processor starts here
	ljmp	main		; jump to the main loop

	.org	000bh		; timer 0 irq
	ljmp	timer0_isr

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

	lcall	initAD		; init the ports to the converters

	lcall	initeps		; init the isochronous data-transfer

	lcall	init_timer
	
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
	mov	a,#10000000b	; gpif, 30MHz, internal IFCLK
	lcall	syncdelaywr
	ret
	

;;; init PWM
startPWM:
	mov	dptr,#IFCONFIG	; switch on IFCLK signal
	mov	a,#10000010b	; gpif, 30MHz, internal IFCLK
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



;;; initialise the ports for the AD-converter
initAD:
	mov	OEA,#27H	;PortA0,A1,A2,A5 Outputs
	mov	IOA,#22H	;/CS = 1, disable transfers to the converters
	ret


;;; init the timer for the soft counters
init_timer:
	;; init the timer for 2ms sampling rate
	mov	CKCON,#00000001b; CLKOUT/12 for timer
	mov	TL0,#010H	; 16
	mov	TH0,#0H		; 256
	mov	IE,#82H		; switch on timer interrupt (80H for all IRQs)
	mov	TMOD,#00000000b	; 13 bit counters
	setb	TCON.4		; enable timer 0
	ret


;;; from here it's only IRQ handling...
	
;;; A/D-conversion:
;;; control-byte in a,
;;; result in r3(low) and r4(high)
;;; this routine is optimised for speed
readAD:				; mask the control byte
	anl	a,#01111100b	; only the channel, gain+pol are left
	orl	a,#10000001b	; start bit, external clock
	;; set CS to low
	clr	IOA.1		; set /CS to zero
	;; send the control byte to the AD-converter
	mov 	R2,#8		; bit-counter
bitlp:	jnb     ACC.7,bitzero	; jump if Bit7 = 0?
	setb	IOA.2		; set the DIN bit
	sjmp	clock		; continue with the clock
bitzero:clr	IOA.2		; clear the DIN bit
clock:	setb	IOA.0		; SCLK = 1
	clr	IOA.0		; SCLK = 0
        rl      a               ; next Bit
        djnz    R2,bitlp

	;; continue the aquisition (already started)
	clr	IOA.2		; clear the DIN bit
	mov 	R2,#5		; five steps for the aquision
clockaq:setb	IOA.0		; SCLK = 1
	clr	IOA.0		; SCLK = 0
        djnz    R2,clockaq	; loop
	
	;; read highbyte from the A/D-converter
	;; and do the conversion
	mov	r4,#0 		; Highbyte goes into R4
	mov	R2,#4		; COUNTER 4 data bits in the MSB
	mov	r5,#08h		; create bit-mask
gethi:				; loop get the 8 highest bits from MSB downw
	setb	IOA.0		; SCLK = 1
	clr	IOA.0		; SCLK = 0
	mov	a,IOA		; from port A
	jnb	ACC.4,zerob	; the in-bit is zero
	mov	a,r4		; get the byte
	orl	a,r5		; or the bit to the result
	mov	r4,a		; save it again in r4
zerob:	mov	a,r5		; get r5 in order to shift the mask
	rr	a		; rotate right
	mov	r5,a		; back to r5
	djnz	R2,gethi
	;; read the lowbyte from the A/D-converter
	mov	r3,#0 		; Lowbyte goes into R3
	mov	r2,#8		; COUNTER 8 data-bits in the LSB
	mov	r5,#80h		; create bit-mask
getlo:				; loop get the 8 highest bits from MSB downw
	setb	IOA.0		; SCLK = 1
	clr	IOA.0		; SCLK = 0
	mov	a,IOA		; from port A
	jnb	ACC.4,zerob2	; the in-bit is zero
	mov	a,r3		; get the result-byte
	orl	a,r5		; or the bit to the result
	mov	r3,a		; save it again in r4
zerob2:	mov	a,r5		; get r5 in order to shift the mask
	rr	a		; rotate right
	mov	r5,a		; back to r5
	djnz	R2,getlo
	setb	IOA.1		; set /CS to one
	;;
	ret
	

	
;;; aquires data from A/D channels and stores them in the EP6 buffer
conv_ad:
	mov	AUTOPTRH1,#0F8H	; auto pointer on EP6
	mov	AUTOPTRL1,#00H
	mov	AUTOPTRSETUP,#7
	mov	r0,#CHANNELLIST	; points to the channellist

	mov	a,@r0		; number of channels
	mov	r1,a		; counter

	mov 	DPTR,#XAUTODAT1	; auto pointer
convloop:
	inc	r0
	mov 	a,@r0		; Channel
	lcall 	readAD
	mov 	a,R3		;
	movx 	@DPTR,A
	mov 	a,R4		;
	movx 	@DPTR,A
	djnz	r1,convloop

	ret




;;; initilise the transfer
;;; It is assumed that the USB interface is in alternate setting 3
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

	mov	dptr,#EPIE	; interrupt enable
	mov	a,#10001000b	; enable irq for ep1out,8
	movx	@dptr,a		; do it

	mov	dptr,#EPIRQ	; clear IRQs
	mov	a,#10100000b
	movx	@dptr,a

	;; enable interrups
        mov     DPTR,#USBIE	; USB int enables register
        mov     a,#2            ; enables SOF (1ms/125us interrupt)
        movx    @DPTR,a         ; 

	mov	EIE,#00000001b	; enable INT2 in the 8051's SFR
	mov	IE,#80h		; IE, enable all interrupts

	ret


;;; counter
;;; r0: DIOSTAT
;;; r1:	counter address
;;; r2:	up/down-mask
;;; r3:	reset-mask
;;; r4:	clock-mask
counter:	
	mov	a,IOB		; actual IOB input state
	mov	r5,a		; save in r5
	anl	a,r3		; bit mask for reset
	jz	no_reset	; reset if one
	clr	a		; set counter to zero
	mov	@r1,a
	inc	r4
	mov	@r1,a
	sjmp	ctr_end
no_reset:	
	mov	a,@r0		; get last state
	xrl	a,r5		; has it changed?
	anl	a,r5		; is it now on?
	anl	a,r4		; mask out the port
	jz	ctr_end		; no rising edge
	mov	a,r5		; get port B again
	anl	a,r2		; test if up or down
	jnz	ctr_up		; count up
	mov	a,@r1
	dec	a
	mov	@r1,a
	cjne	a,#0ffh,ctr_end	; underflow?
	inc	r1		; high byte
	mov	a,@r1
	dec	a
	mov	@r1,a
	sjmp	ctr_end
ctr_up:				; count up
	mov	a,@r1
	inc	a
	mov	@r1,a
	jnz	ctr_end
	inc	r1		; high byte
	mov	a,@r1
	inc	a
	mov	@r1,a
ctr_end:
	mov	a,r5
	mov	@r0,a
	ret

;;; implements two soft counters with up/down and reset
timer0_isr:
	push	dps
	push	acc
	push	psw
	push	00h		; R0
	push	01h		; R1
	push	02h		; R2
	push	03h		; R3
	push	04h		; R4
	push	05h		; R5
		
	mov	r0,#DIOSTAT0	; status of port
	mov	r1,#CTR0	; address of counter0
	mov	a,#00000001b	; bit 0
	mov	r4,a		; clock
	rl	a		; bit 1
	mov	r2,a		; up/down
	rl	a		; bit 2
	mov	r3,a		; reset mask
	lcall	counter
	inc	r0		; to DISTAT1
	inc	r1		; to CTR1
	inc	r1
	mov	a,r3
	rl	a		; bit 3
	rl	a		; bit 4
	mov	r4,a		; clock
	rl	a		; bit 5
	mov	r2,a		; up/down
	rl	a		; bit 6
	mov	r3,a		; reset
	lcall	counter
	
	pop	05h		; R5
	pop	04h		; R4
	pop	03h		; R3
	pop	02h		; R2
	pop	01h		; R1
	pop	00h		; R0
	pop	psw
	pop	acc 
	pop	dps

	reti

;;; interrupt-routine for SOF
;;; is for full speed
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
		
	mov	a,EP2468STAT
	anl	a,#20H		; full?
	jnz	epfull		; EP6-buffer is full

	lcall	conv_ad		; conversion

	mov	DPTR,#EP6BCH	; byte count H
	mov	a,#0		; is zero
	lcall	syncdelaywr	; wait until we can write again
	
	mov	DPTR,#EP6BCL	; byte count L
	mov	a,#10H		; is 8x word = 16 bytes
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
	sjmp	storechannellist; a=0
	sjmp	single_da	; a=1
	sjmp	config_digital_b; a=2
	sjmp	write_digital_b	; a=3
	sjmp	storesglchannel	; a=4
	sjmp	readcounter	; a=5
	sjmp	writecounter	; a=6
	sjmp	pwm_on		; a=7
	sjmp	pwm_off		; a=8

pwm_on:
	lcall	startPWM
	sjmp	over_da

pwm_off:
	lcall	stopPWM
	sjmp	over_da

	;; read the counter
readcounter:
	lcall	reset_ep8	; reset ep8
	lcall	ep8_ops		; fill the counter data in there
	sjmp	over_da		; jump to the end

	;; write zeroes to the counters
writecounter:
	mov	dptr,#0e781h	; buffer
	mov	r0,#CTR0	; r0 points to counter 0
	movx	a,@dptr		; channel number
	jz	wrctr0		; first channel
	mov	r1,a		; counter
wrctrl:
	inc	r0		; next counter
	inc	r0		; next counter
	djnz	r1,wrctrl	; advance to the right counter
wrctr0:
	inc	dptr		; get to the value
	movx	a,@dptr		; get value
	mov	@r0,a		; save in ctr
	inc	r0		; next byte
	inc	dptr
	movx	a,@dptr		; get value
	mov	@r0,a		; save in ctr
	sjmp	over_da		; jump to the end

storesglchannel:
	mov	r0,#SGLCHANNEL	; the conversion bytes are now stored in 80h
	mov	dptr,#0e781h	; FIFO buffer of EP1OUT
	movx	a,@dptr		; 
	mov	@r0,a

	lcall	reset_ep8	; reset FIFO
	;; Save new A/D data in EP8. This is the first byte
	;; the host will read during an INSN. If there are
	;; more to come they will be handled by the ISR of
	;; ep8.
	lcall	ep8_ops		; get A/D data
		
	sjmp	over_da

	
;;; Channellist:
;;; the first byte is zero:
;;; we've just received the channel list
;;; the channel list is stored in the addresses from CHANNELLIST which
;;; are _only_ reachable by indirect addressing
storechannellist:
	mov	r0,#CHANNELLIST	; the conversion bytes are now stored in 80h
	mov	r2,#9		; counter
	mov	dptr,#0e781h	; FIFO buffer of EP1OUT
chanlloop:	
	movx	a,@dptr		; 
	mov	@r0,a
	inc	dptr
	inc	r0
	djnz	r2,chanlloop

	lcall	reset_ep6	; reset FIFO
	
	;; load new A/D data into EP6
	;; This must be done. Otherwise the ISR is never called.
	;; The ISR is only called when data has _left_ the
	;; ep buffer here it has to be refilled.
	lcall	ep6_arm		; fill with the first data byte
	
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
	mov	OEB,a		; set the output enable bits
	sjmp	over_da
	
;;; Write one byte to the external digital port B
;;; and prepare for digital read
write_digital_b:
	mov	dptr,#0e781h	; FIFO buffer of EP1OUT
	movx	a,@dptr		; get the second byte
	mov	OEB,a		; output enable
	inc	dptr		; next byte
	movx	a,@dptr		; bits
	mov	IOB,a		; send the byte to the I/O port

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
	movx	a,@dptr		; number of channels
	inc	dptr		; pointer to the first channel
	mov	r0,a		; 4 channels
nextDA:	
	movx	a,@dptr		; get the first low byte
	mov	r3,a		; store in r3 (see below)
	inc	dptr		; point to the high byte
	movx	a,@dptr		; get the high byte
	mov	r4,a		; store in r4 (for writeDA)
	inc	dptr		; point to the channel number
	movx	a,@dptr		; get the channel number
	inc	dptr		; get ready for the next channel
	lcall	writeDA		; write value to the DAC
	djnz	r0,nextDA	; next channel
	ret



;;; D/A-conversion:
;;; control-byte in a,
;;; value in r3(low) and r4(high)
writeDA:			; mask the control byte
	anl	a,#11000000b	; only the channel is left
	orl	a,#00110000b	; internal clock, bipolar mode, +/-5V
	orl	a,r4		; or the value of R4 to it
	;; set CS to low
	clr	IOA.5		; set /CS to zero
	;; send the first byte to the DA-converter
	mov 	R2,#8		; bit-counter
DA1:    jnb     ACC.7,zeroda	; jump if Bit7 = 0?
	setb	IOA.2		; set the DIN bit
	sjmp	clkda		; continue with the clock
zeroda: clr	IOA.2		; clear the DIN bit
clkda:	setb	IOA.0		; SCLK = 1
	clr	IOA.0		; SCLK = 0
        rl      a               ; next Bit
        djnz    R2,DA1

	
	;; send the second byte to the DA-converter
	mov	a,r3		; low byte
	mov 	R2,#8		; bit-counter
DA2:    jnb     ACC.7,zeroda2	; jump if Bit7 = 0?
	setb	IOA.2		; set the DIN bit
	sjmp	clkda2		; continue with the clock
zeroda2:clr	IOA.2		; clear the DIN bit
clkda2:	setb	IOA.0		; SCLK = 1
	clr	IOA.0		; SCLK = 0
        rl      a               ; next Bit
        djnz    R2,DA2
	;; 
	setb	IOA.5		; set /CS to one
	;; 
noDA:	ret
	


;;; arm ep6
ep6_arm:
	lcall	conv_ad
	
	mov	DPTR,#EP6BCH	; byte count H
	mov	a,#0		; is zero
	lcall	syncdelaywr	; wait until the length has arrived
	
	mov	DPTR,#EP6BCL	; byte count L
	mov	a,#10H		; is one
	lcall	syncdelaywr	; wait until the length has been proc
	ret
	


;;; converts one analog/digital channel and stores it in EP8
;;; also gets the content of the digital ports B and D depending on
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
	sjmp	ep8_readctr	; a=5, read counter
	sjmp	ep8_err		; a=6, write counter

	;; reads all counters
ep8_readctr:
	mov	r0,#CTR0	; points to counter0
	mov	dptr,#0fc02h	; ep8 fifo buffer
	mov	r1,#8		; transfer 4 16bit counters
ep8_ctrlp:
	mov	a,@r0		; get the counter
	movx	@dptr,a		; save in the fifo buffer
	inc	r0		; inc pointer to the counters
	inc	dptr		; inc pointer to the fifo buffer
	djnz	r1,ep8_ctrlp	; loop until ready
	
	sjmp	ep8_send	; send the data
	
	;; read one A/D channel
ep8_sglchannel:		
	mov	r0,#SGLCHANNEL	; points to the channel
	mov 	a,@r0		; Ch0
	
	lcall 	readAD		; start the conversion
		
	mov 	DPTR,#0fc02h	; EP8 FIFO 
	mov 	a,R3		; get low byte
	movx 	@DPTR,A		; store in FIFO
	inc	dptr		; next fifo entry
	mov 	a,R4		; get high byte
	movx 	@DPTR,A		; store in FIFO

	sjmp	ep8_send	; send the data

	;; read the digital lines
ep8_dio:	
	mov 	DPTR,#0fc02h	; store the contents of port B
	mov	a,IOB		; in the next
	movx	@dptr,a		; entry of the buffer

	inc	dptr
	clr	a		; high byte is zero
	movx	@dptr,a		; next byte of the EP
	
ep8_send:	
	mov	DPTR,#EP8BCH	; byte count H
	mov	a,#0		; is zero
	lcall	syncdelaywr
	
	mov	DPTR,#EP8BCL	; byte count L
	mov	a,#10H		; 16 bytes
	lcall	syncdelaywr	; send the data over to the host

ep8_err:	
	ret



;;; EP8 interrupt: gets one measurement from the AD converter and
;;; sends it via EP8. The channel # is stored in address 80H.
;;; It also gets the state of the digital registers B and D.
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


.End


