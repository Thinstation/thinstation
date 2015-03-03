TIMEOUT 0
DEFAULT ifcpu

LABEL ifcpu
	COM32 ifcpu.c32
	APPEND pae -- pae -- standard
LABEL standard
	KERNEL /boot/vmlinuz
	APPEND initrd=/boot/initrd $KERNEL_PARAMETERS
LABEL pae
	KERNEL /boot/vmlinuz1
	APPEND initrd=/boot/initrd $KERNEL_PARAMETERS
