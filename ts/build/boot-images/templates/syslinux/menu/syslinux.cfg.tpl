UI menu.c32
DEFAULT default
DISPLAY product.txt
PROMPT 0
ALLOWOPTIONS 0
NOESCAPE 1

SAY Press Ctrl-C for additional start-up options

MENU SHIFTKEY
MENU TITLE Thinstation

LABEL default
	MENU LABEL Thinstation Standard Mode
	TEXT HELP
	Launches Thinstation with default options.
	ENDTEXT
        COM32 ifcpu.c32
        APPEND pae -- pae -- warn

LABEL warn
	MENU HIDE
	CONFIG nopae.cfg

LABEL pae
	MENU HIDE
	KERNEL /boot/vmlinuz
	APPEND initrd=/boot/initrd $KERNEL_PARAMETERS

LABEL bvm
	MENU LABEL Basic Video Mode
	TEXT HELP
	Launches Thinstation with hardware video drivers disabled.
	Try this option if the screen goes blank during startup.
	ENDTEXT
	KERNEL /boot/vmlinuz
	APPEND initrd=/boot/initrd $KERNEL_PARAMETERS VESAMODE=on

LABEL linux
	MENU LABEL Alternate Boot
	TEXT HELP
	Launches Thinstation image with a special launcher.
	Try this option if booting fails while loading from disc (the dots).
	This was added to work around issues with older BIOS.
	ENDTEXT
	KERNEL linux.c32
	APPEND /boot/vmlinuz initrd=/boot/initrd $KERNEL_PARAMETERS

LABEL harddisk
	MENU LABEL Boot from first fixed hard disk drive
	LOCALBOOT 0x80
	APPEND SLX=0x80

