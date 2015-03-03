rem -- isolinux.bin must be writable and lower-case
attrib -r cd-files\isolinux.bin
ren cd-files\ISOLINUX.BIN isolinux.bin

rem -- It will be recreated...
attrib -r cd-files\boot.cat
del cd-files\boot.cat

rem -- rebuild the bootable iso
mkisofs -o LiveCD.desktop.iso -b isolinux.bin -c boot.cat -joliet -no-emul-boot -boot-load-size 4 -boot-info-table cd-files