#!/bin/sh
#set -x
#exec </dev/null >>/var/log/pre-net.log  2>&1

env |grep -v "^ID" > /var/log/net/$INTERFACE
exit 0
if [ "$(systemctl is-system-running)" = "initializing" ]; then
    echo "Systemd is in the boot phase."
else
	export INTERFACE
	/etc/udev/scripts/net.sh
fi
