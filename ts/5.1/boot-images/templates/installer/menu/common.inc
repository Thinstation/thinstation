LABEL hdt
        MENU LABEL Hardware Detection Tool
        KERNEL hdt.c32
	APPEND pciids=menu/pci.ids modules_alias=menu/modules.alias
LABEL harddisk
	MENU LABEL Boot first HDD
	LOCALBOOT 0x80
	APPEND SLX=0x80
LABEL reboot
	MENU LABEL Reboot
	COM32 reboot.c32
