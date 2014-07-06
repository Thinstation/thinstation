timeout 150
display thinstation.txt

DEFAULT vesamenu.c32
PROMPT 0

LABEL Default
MENU LABEL Standard 
	KERNEL vmlinuz
	APPEND initrd=initrd intel_iommu=off amd_iommu=off $RES splash=silent,theme:default console=tty1 loglevel=3 LM=2
LABEL Backup
MENU LABEL Backup 
	KERNEL vmlinuz-backup
	APPEND initrd=initrd-backup intel_iommu=off amd_iommu=off $RES splash=silent,theme:default console=tty1 loglevel=3 LM=2



