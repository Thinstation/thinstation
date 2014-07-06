TIMEOUT 0
DEFAULT default
DISPLAY product.txt

LABEL default
	KERNEL vmlinuz
	APPEND initrd=initrd $KERNEL_PARAMETERS
