#!/bin/sh
#
# /usr/bin/gtk-register: register gdk-pixbuf loaders
#

/usr/bin/gdk-pixbuf-query-loaders > /usr/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache

# End of file
