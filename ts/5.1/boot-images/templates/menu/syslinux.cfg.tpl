
UI menu.c32
DEFAULT thinstation
PROMPT 0

LABEL thinstation
MENU LABEL Thinstation
	KERNEL vmlinuz
	APPEND initrd=initrd $KERNEL_PARAMETERS
