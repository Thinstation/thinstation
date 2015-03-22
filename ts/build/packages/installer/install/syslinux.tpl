timeout 150
display thinstation.txt

DEFAULT vesamenu.c32
PROMPT 0

LABEL Default
MENU LABEL Standard 
	KERNEL /boot/vmlinuz
	APPEND initrd=/boot/initrd $RES splash=silent,theme:default console=tty1 loglevel=3 LM=2 vt.global_cursor_default=0
LABEL Backup
MENU LABEL Backup 
	KERNEL /boot/vmlinuz-backup
	APPEND initrd=/boot/initrd-backup $RES splash=silent,theme:default console=tty1 loglevel=3 LM=2 vt.global_cursor_default=0



