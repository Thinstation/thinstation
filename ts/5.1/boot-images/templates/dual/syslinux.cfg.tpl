timeout 0
default ifcpu
label ifcpu
	com32 ifcpu.c32
	append pae -- pae -- standard
label standard
    kernel vmlinuz
    append initrd=initrd $KERNEL_PARAMETERS
label pae
    kernel vmlinuz1
    append initrd=initrd $KERNEL_PARAMETERS
