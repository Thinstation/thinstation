#!/bin/sh
set > /var/log/net/$INTERFACE
if [ ! -e /tmp/init ]; then
	export INTERFACE
	/etc/udev/scripts/net.sh
fi
