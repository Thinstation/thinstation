TIMEOUT 0
DEFAULT default
DISPLAY product.txt

LABEL default
	KERNEL /boot/vmlinuz
	APPEND initrd=/boot/initrd $KERNEL_PARAMETERS
