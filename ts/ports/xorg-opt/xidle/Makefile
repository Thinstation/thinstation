PREFIX = /usr
INSTALL = install
CFLAGS += -Wall -D__dead=
FLAGS = $(shell pkg-config --libs --cflags xscrnsaver xext x11)

xidle:
	$(CC) -o xidle xidle.c $(CFLAGS) $(LDFLAGS) $(FLAGS)

install:
	$(INSTALL) -D -m 0755 xidle $(DESTDIR)/$(PREFIX)/bin/xidle
	$(INSTALL) -D -m 0644 xidle.1 $(DESTDIR)/$(PREFIX)/share/man/man1/xidle.1
