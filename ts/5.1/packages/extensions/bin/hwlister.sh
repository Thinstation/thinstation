#!/bin/bash

. $TS_RUNTIME

rm -rf /vbe_modes.list /firmware.list /module.list

bday=`stat -c %X /etc/index.html`

firmware_loaded()
{
	if [ -n "`stat -c '%X' $1 | grep -v \"$bday\"`" ]; then
		return 0
	else
		return 1
	fi
}


for firmware in `find /lib/firmware -type f`; do
	if firmware_loaded $firmware; then
		firmware=`basename $firmware`
		echo "firmware $firmware" >> /firmware.list
	fi
done

for module in `lsmod |cut -d " " -f 1`; do
	if [ "$module" != "Module" ]; then
		mdfile=`modinfo $module |grep -e filename: |cut -c 17- |cut -d "." -f 1`;
		mdfile=`basename $mdfile`
		echo "module $mdfile" | grep -Ev 'fuse|squashfs|fat|ntfs|nfs|lockd|sunrpc|autofs4|isofs|udf|cifs|reiserfs|exportfs|ext|jbd|jfs|nls|xfs|usb-storage' | sort >>/module.list
	fi
done
tftp -p -l /module.list -r module.list $SERVER_IP

if [ -e /sys/devices/platform/uvesafb.0/vbe_modes ]; then
	cp /sys/devices/platform/uvesafb.0/vbe_modes /vbe_modes.list
	tftp -p -l /vbe_modes.list -r vbe_modes.list $SERVER_IP
fi

if [ -e /firmware.list ]; then
	tftp -p -l /firmware.list -r firmware.list $SERVER_IP
fi
