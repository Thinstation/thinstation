;   usbduxfast_firmware.asm
;   Copyright (C) 2004,2009 Bernd Porr, Bernd.Porr@f2s.com
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
; Firmware: usbduxfast_firmware.asm for usbdux.c
; Description: Firmware for usbduxfast
; Devices: [ITL] USB-DUX (usbdux.o)
; Author: Bernd Porr <Bernd.Porr@f2s.com>
; Updated: 17 Apr 2009
; Status: stable
;
;;;
;;;
;;;

	.inc	fx2-include.asm

	.equ	WFLOADED,70H	; waveform is loaded

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
sof_isr:
sudav_isr:	
sutok_isr:	
suspend_isr:	
usbreset_isr:	
hispeed_isr:	
ep0ack_isr:	
spare_isr:	
ep0in_isr:	
ep0out_isr:	
ep1out_isr:
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
ep8_isr:

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
	mov	dptr,#REVCTL
	mov	a,#00000011b	; allows skip
	lcall	syncdelaywr

	mov	DPTR,#CPUCS	; CPU control register
	mov	a,#00010000b	; 48Mhz
	lcall	syncdelaywr

	mov	dptr,#IFCONFIG	; switch on IFCLK signal
	mov	a,#10100010b	; gpif, 30MHz
	lcall	syncdelaywr

	mov	dptr,#FIFORESET
	mov	a,#80h
	lcall	syncdelaywr
	mov	a,#8
	lcall	syncdelaywr
	mov	a,#2		
	lcall	syncdelaywr
	mov	a,#4		
	lcall	syncdelaywr
	mov	a,#6		
	lcall	syncdelaywr
	mov	a,#0		
	lcall	syncdelaywr

	mov	dptr,#INTSETUP	; IRQ setup register
	mov	a,#08h		; enable autovector
	lcall	syncdelaywr

	lcall	initeps		; init the isochronous data-transfer

	lcall	initGPIF

;;; main loop

mloop2:
	lcall	gpif_run
	sjmp	mloop2		; do nothing. The rest is done by the IRQs


gpif_run:
	mov	a,WFLOADED
	jz	no_trig		; do not trigger
	mov	a,GPIFTRIG	; GPIF status
	anl	a,#80h		; done bit
	jz	no_trig		; GPIF busy

;;; gpif has stopped
	mov	a,#06h		; RD,EP6
	mov	GPIFTRIG,a
no_trig:
	ret

	

initGPIF:
	mov	DPTR,#EP6CFG	; BLK data from here to the host
	mov	a,#11100000b	; Valid, quad buffering
	lcall	syncdelaywr	; write

	mov	dptr,#EP6FIFOCFG
	mov	a,#00001001b	; autoin, wordwide
	lcall	syncdelaywr

	mov	dptr,#EP6AUTOINLENH
	mov	a,#00000010b	; 512 bytes
	lcall	syncdelaywr	; write

	mov	dptr,#EP6AUTOINLENL
	mov	a,#00000000b	; 0
	lcall	syncdelaywr	; write

	mov	dptr,#GPIFWFSELECT
	mov	a,#11111100b	; waveform 0 for FIFO RD
	lcall	syncdelaywr

	mov	dptr,#GPIFCTLCFG
	mov	a,#10000000b	; tri state for CTRL
	lcall	syncdelaywr

	mov	dptr,#GPIFIDLECTL
	mov	a,#11111111b	; all CTL outputs high
	lcall	syncdelaywr
	mov	a,#11111101b	; reset counter
	lcall	syncdelaywr
	mov	a,#11111111b	; reset to high again
	lcall	syncdelaywr

	mov	a,#00000010b	; abort when full
	mov	dptr,#EP6GPIFFLGSEL
	lcall	syncdelaywr

	mov	a,#00000001b	; stop when buffer overfl
	mov	dptr,#EP6GPIFPDFSTOP
	lcall	syncdelaywr

	mov	a,#0
	mov	dptr,#GPIFREADYCFG
	lcall	syncdelaywr

	mov	a,#0
	mov	dptr,#GPIFIDLECS
	lcall	syncdelaywr

; waveform 1
; this is a dummy waveform which is used
; during the upload of another waveform into
; wavefrom 0
; it branches directly into the IDLE state
	mov	dptr,#0E420H
	mov	a,#00111111b	; branch to IDLE
	lcall	syncdelaywr

	mov	dptr,#0E428H	; opcode
	mov	a,#00000001b	; deceision point
	lcall	syncdelaywr

	mov	dptr,#0E430H
	mov	a,#0FFH		; output is high
	lcall	syncdelaywr

	mov	dptr,#0E438H
	mov	a,#0FFH		; logic function
	lcall	syncdelaywr

; signals that no waveform 0 is loaded so far
	mov	WFLOADED,#0	; waveform flag

	ret



;;; initilise the transfer
;;; It is assumed that the USB interface is in alternate setting 1
initeps:
	mov	DPTR,#EP4CFG
	mov	a,#10100000b	; valid, bulk, out
	lcall	syncdelaywr

	mov	dptr,#EP4BCL	; "arm" it
	mov	a,#00h
	lcall	syncdelaywr	; wait until we can write again
	lcall	syncdelaywr	; wait
	lcall	syncdelaywr	; wait

	mov	DPTR,#EP8CFG
	mov	a,#0		; disable EP8, it overlaps with EP6!!
	lcall	syncdelaywr

	mov	dptr,#EPIE	; interrupt enable
	mov	a,#00100000b	; enable irq for ep4
	lcall	syncdelaywr	; do it

	mov	dptr,#EPIRQ	; clear IRQs
	mov	a,#00100100b
	movx	@dptr,a

        mov     DPTR,#USBIE	; USB int enable register
        mov     a,#0            ; SOF etc
        movx    @DPTR,a         ;

        mov     DPTR,#GPIFIE	; GPIF int enable register
        mov     a,#0            ; done IRQ
        movx    @DPTR,a         ;

	mov	EIE,#00000001b	; enable INT2 in the 8051's SFR
	mov	IE,#80h		; IE, enable all interrupts

	ret


;;; interrupt-routine for ep4
;;; receives the channel list and other commands
ep4_isr:
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
		
	mov	dptr,#0f400h	; FIFO buffer of EP4
	movx	a,@dptr		; get the first byte

	mov	dptr,#ep4_jmp	; jump table for the different functions
	rl	a		; multiply by 2: sizeof sjmp
	jmp	@a+dptr		; jump to the jump table

ep4_jmp:
	sjmp	storewaveform	; a=0
	sjmp	init_ep6	; a=1
	
init_ep6:
	; stop ep6
	; just now do nothing

	ljmp	over_wf


storewaveform:
	mov	WFLOADED,#0	; waveform flag

	mov	dptr,#EP6FIFOCFG
	mov	a,#00000000b	;
	lcall	syncdelaywr

	mov	dptr,#GPIFABORT
	mov	a,#0ffh		; abort all transfers
	lcall	syncdelaywr

wait_f_abort:
	mov	a,GPIFTRIG	; GPIF status
	anl	a,#80h		; done bit
	jz	wait_f_abort	; GPIF busy

	mov	dptr,#GPIFWFSELECT
	mov	a,#11111101b	; select dummy waveform
	movx	@dptr,a
	lcall	syncdelay

	mov	dptr,#FIFORESET
	mov	a,#80h		; NAK
	lcall	syncdelaywr
	mov	a,#6		; reset EP6
	lcall	syncdelaywr
	mov	a,#0		; normal op
	lcall	syncdelaywr

; change to dummy waveform 1
	mov	a,#06h		; RD,EP6
	mov	GPIFTRIG,a

; wait a bit
	mov	r2,255
loopx:
	djnz	r2,loopx

; abort waveform if not already so
	mov	dptr,#GPIFABORT
	mov	a,#0ffh		; abort all transfers
	lcall	syncdelaywr

; wait again
	mov	r2,255
loopx2:
	djnz	r2,loopx2

; check for DONE
wait_f_abort2:
	mov	a,GPIFTRIG	; GPIF status
	anl	a,#80h		; done bit
	jz	wait_f_abort2	; GPIF busy

; upload the new waveform into waveform 0
	mov	AUTOPTRH2,#0E4H	; XDATA0H
	lcall	syncdelay
	mov	AUTOPTRL2,#00H	; XDATA0L
	lcall	syncdelay

	mov	AUTOPTRH1,#0F4H	; EP4 high
	lcall	syncdelay
	mov	AUTOPTRL1,#01H	; EP4 low
	lcall	syncdelay

	mov	AUTOPTRSETUP,#7	; autoinc and enable
	lcall	syncdelay

	mov 	r2,#20H		; 32 bytes to transfer

wavetr:
	mov 	dptr,#XAUTODAT1
	movx	a,@dptr
	lcall	syncdelay
	mov	dptr,#XAUTODAT2
	movx	@dptr,a
	lcall	syncdelay
	djnz	r2,wavetr

	mov	dptr,#EP6FIFOCFG
	mov	a,#00001001b	; autoin, wordwide
	lcall	syncdelaywr

	mov	dptr,#GPIFWFSELECT
	mov	a,#11111100b
	movx	@dptr,a
	lcall	syncdelay

	mov	dptr,#FIFORESET
	mov	a,#80h		; NAK
	lcall	syncdelaywr
	mov	a,#6		; reset EP6
	lcall	syncdelaywr
	mov	a,#0		; normal op
	lcall	syncdelaywr

	mov	dptr,#0E400H+10H; waveform 0: first CTL byte
	movx	a,@dptr		; get it
	orl	a,#11111011b	; force all bits to one except the range bit
	mov	dptr,#GPIFIDLECTL
	lcall	syncdelaywr

	mov	WFLOADED,#1	; waveform flag

; do the common things here	
over_wf:	
	mov	dptr,#EP4BCL
	mov	a,#00h
	movx	@DPTR,a		; arm it
	lcall	syncdelay	; wait
	movx	@DPTR,a		; arm it
	lcall	syncdelay	; wait

	;; clear INT2
	mov	a,EXIF		; FIRST clear the USB (INT2) interrupt request
	clr	acc.4
	mov	EXIF,a		; Note: EXIF reg is not 8051 bit-addressable

	mov	DPTR,#EPIRQ	; 
	mov	a,#00100000b	; clear the ep4irq
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
	lcall	syncdelay
	movx	@dptr,a
	ret


.End












