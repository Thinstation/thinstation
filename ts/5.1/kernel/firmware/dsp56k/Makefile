bootstrap.bin: bootstrap.asm concat-bootstrap.pl
	a56 bootstrap.asm >/dev/null
	perl concat-bootstrap.pl <a56.out >bootstrap.bin

clean:
	rm -f a56.out bootstrap.bin
