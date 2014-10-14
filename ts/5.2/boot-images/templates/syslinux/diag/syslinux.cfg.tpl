TIMEOUT 150

DEFAULT vesamenu.c32
PROMPT 0

LABEL default
	MENU LABEL Regular Build
	KERNEL vmlinuz
	APPEND initrd=initrd $KERNEL_PARAMETERS

LABEL diag
	MENU LABEL Hardware Detection Tool
	KERNEL hdt.c32
