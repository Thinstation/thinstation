CC = gcc
IHEX2FW = ihex2fw

all: keyspan_pda.fw xircom_pgs.fw

%.fw: %.S
	$(CC) -x assembler-with-cpp -P -E -o $*.asm $<
	as31 -l $*.asm
	$(IHEX2FW) $*.hex $@

clean:
	rm -f *.asm *.fw *.hex *.lst *.obj
