LABEL hdt
        MENU LABEL Hardware Detection Tool
        KERNEL hdt.c32
LABEL tiny
	MENU LABEL HW Lister
	KERNEL /boot/hwlister/vmlinuz
	APPEND initrd=/boot/hwlister/initrd splash=off console=tty1 loglevel=3 load_ramdisk=1 ramdisk_blocksize=4096 root=/dev/ram0 ramdisk_size=786432 vt.global_cursor_default=0
LABEL harddisk
	MENU LABEL Boot first HDD
	LOCALBOOT 0x80
	APPEND SLX=0x80
LABEL reboot
	MENU LABEL Reboot
	COM32 reboot.c32
