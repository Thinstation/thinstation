# This file implements the GNOME Build API:
# http://people.gnome.org/~walters/docs/build-api.txt

FIRMWAREDIR = /lib/firmware

all:

install:
	mkdir -p $(DESTDIR)$(FIRMWAREDIR)
	cp -r * $(DESTDIR)$(FIRMWAREDIR)
	rm -f $(DESTDIR)/usbdux/*dux $(DESTDIR)/*/*.asm
	rm $(DESTDIR)$(FIRMWAREDIR)/{WHENCE,LICENSE.*,LICENCE.*}
