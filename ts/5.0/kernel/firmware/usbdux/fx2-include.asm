; rev 0.91
; (c) Bernd Porr, BerndPorr@f2s.com
; GPL, GNU public license
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
; In conjunction with the as31.
; Include-file for the FX2 by Cypress. The rest of the regs is defined
; by the as31 itself.
;
; from the TRM of the FX2:
;
	;;  CPU control
	.equ	CPUCS,0E600H
	.equ	REVCTL,0E60BH
	;; interface config
	.equ	IFCONFIG,0E601H
	.equ	FIFORESET,0E604H
	;; Endpoint configs
	.equ	EP1OUTCFG,0E610H
	.equ	EP1INCFG,0E611H
	.equ	EP2CFG,0E612H
	.equ	EP4CFG,0E613H
	.equ	EP6CFG,0E614H
	.equ	EP8CFG,0E615H
	;; packets per frame, always one for USB 1.1
	.equ	EP2ISOINPKTS,0E640H
	.equ	EP4ISOINPKTS,0E641H
	.equ	EP6ISOINPKTS,0E642H
	.equ	EP8ISOINPKTS,0E643H
	;; endpoint byte counts
	.equ	EP1OUTBC,0E68DH
	.equ	EP2BCH,0E690H
	.equ	EP2BCL,0E691H
	.equ	EP4BCH,0E694H
	.equ	EP4BCL,0E695H
	.equ	EP6BCH,0E698H
	.equ	EP6BCL,0E699H
	.equ	EP8BCH,0E69CH
	.equ	EP8BCL,0E69DH
	;;
	.equ	EP4AUTOINLENH,0E622H
	.equ	EP4AUTOINLENL,0E623H
	.equ	EP6AUTOINLENH,0E624H
	.equ	EP6AUTOINLENL,0E625H
	.equ	EP2FIFOCFG,0E618H
	.equ	EP4FIFOCFG,0E619H
	.equ	EP6FIFOCFG,0E61AH
	.equ	EP8FIFOCFG,0E61BH
	;; 
	.equ	INPKTEND,0E648H
	.equ	OUTPKTEND,0E649H
	.equ	GPIFCTLCFG,0E6C3H
	.equ	GPIFABORT,0E6F5H
	.equ	GPIFIDLECTL,0E6C2H
	.equ	GPIFWFSELECT,0E6C0H
	.equ	GPIFREADYCFG,0E6F3H
	.equ	GPIFIDLECS,0E6C1H
	.equ	EP6GPIFFLGSEL,0E6E2H
	.equ	EP6GPIFPDFSTOP,0E6E3H
	.equ	EP6GPIFTRIG,0E6E4H
	.equ	GPIFTCB3,0E6CEH
	.equ	GPIFTCB2,0E6CFH
	.equ	GPIFTCB1,0E6D0H
	.equ	GPIFTCB0,0E6D1H
	.equ	EP4GPIFFLGSEL,0E6DAH
	.equ	EP4GPIFPFSTOP,0E6DBH
	;; 
	;; endpoint control
	.equ	EP2CS,0E6A3H
	.equ	EP4CS,0E6A4H
	.equ	EP6CS,0E6A5H
	.equ	EP8CS,0E6A6H
	;; endpoint buffers
	.equ	EP2FIFOBUF,0F000H
	.equ	EP4FIFOBUF,0F400H
	.equ	EP6FIFOBUF,0F800H
	.equ	EP8FIFOBUF,0FC00H
	;; IRQ enable for bulk NAK
	.equ	IBNIE,0E658H
	;; interrupt requ for NAK
	.equ	IBNIRQ,0E659H
	;; USB INT enables
	.equ	USBIE,0E65CH
	;; USB interrupt request
	.equ	USBIRQ,0E65DH
	;; endpoint IRQ enable
	.equ	EPIE,0E65EH
	;; endpoint IRQ requests
	.equ	EPIRQ,0E65FH
	;; USB error IRQ requests
	.equ	USBERRIE,0E662H
	;; USB error IRQ request
	.equ	USBERRIRQ,0E663H
	;; USB interrupt 2 autovector
	.equ	INT2IVEC,0E666H
	;; autovector enable
	.equ	INTSETUP,0E668H
	;; port cfg
	.equ	PORTACFG,0E670H
	.equ	PORTCCFG,0E671H
	.equ	PORTECFG,0E672H
	;; I2C bus
	.equ	I2CS,0E678H
	.equ	I2DAT,0E679H
	.equ	I2CTL,0E67AH
	;; auto pointers, read/write is directed to the pointed address
	.equ	XAUTODAT1,0E67BH
	.equ	XAUTODAT2,0E67CH
	;; USB-control
	.equ	USBCS,0E680H

	.equ	IOA,80H
	.equ	DPL0,82H
	.equ	DPH0,83H
	.equ	DPL1,84H
	.equ	DPH1,85H
	.equ	DPS,86H
	.equ	CKCON,8Eh
	.equ	IOB,90H
	.equ	EXIF,91h
	.equ	MPAGE,92h
	.equ	AUTOPTRH1,9AH
	.equ	AUTOPTRL1,9BH
	.equ	AUTOPTRH2,9DH
	.equ	AUTOPTRL2,9EH
	.equ	IOC,0A0H
	.equ	INT2CLR,0A1H
	.equ	INT4CLR,0A2H
	.equ	EP2468STAT,0AAH
	.equ	EP24FIFOFLGS,0ABH
	.equ	EP68FIFOFLGS,0ACH
	.equ	AUTOPTRSETUP,0AFH
	.equ	IOD,0B0H
	.equ	IOE,0B1H
	.equ	OEA,0B2H
	.equ	OEB,0B3H
	.equ	OEC,0B4H
	.equ	OED,0B5H
	.equ	OEE,0B6H
	.equ	GPIFTRIG,0BBH
	.equ	EIE,0E8h
	.equ	EIP,0F8h
	.equ	GPIFIE,0E660H

;;; serial control
	.equ	SCON0,098h
	.equ	SBUF0,099h

	;;; end of file
	

