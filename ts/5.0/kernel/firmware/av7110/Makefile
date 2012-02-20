CC = arm-linux-gnueabi-gcc
LD = arm-linux-gnueabi-ld
OBJCOPY = arm-linux-gnueabi-objcopy

bootcode.bin: Boot.S
	$(CC) -mbig-endian -c Boot.S
	$(LD) -Ttext 0x2c000000 -EB -o Boot Boot.o
	$(OBJCOPY) -Obinary Boot bootcode.bin

clean:
	rm -f Boot.o Boot bootcode.bin
