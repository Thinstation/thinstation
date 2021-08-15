#!/bin/sh

. /etc/thinstation.global

if is_enabled $UDISKS_AUTOMOUNT; then
	for device in `udisksctl dump |grep -e " Device:" |grep -Ev 'ram[0-9]+|loop[0-9]+' |cut -d " " -f26-`; do
		udisksctl mount -b $device
	done
fi
