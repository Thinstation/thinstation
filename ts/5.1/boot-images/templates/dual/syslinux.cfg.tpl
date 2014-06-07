TIMEOUT 0
DEFAULT ifcpu

LABEL ifcpu
	com32 ifcpu.c32
	APPEND pae -- pae -- standard
LABEL standard
	KERNEL vmlinuz
	APPEND initrd=initrd $KERNEL_PARAMETERS
LABEL pae
	KERNEL vmlinuz1
	APPEND initrd=initrd $KERNEL_PARAMETERS
