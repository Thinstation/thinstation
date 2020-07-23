#!/bin/bash

. /etc/thinstation.global

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


if [ -e /fastboot/firmware ]; then
	fdir=/fastboot/firmware
else
	fdir=/lib/firmware
fi
for firmware in `find $fdir -type f`; do
	if firmware_loaded "$firmware"; then
		firmware=`echo $firmware |cut -d "/" -f4-`
		echo "firmware $firmware" >> /firmware.list
	fi
done

IFS=$'\n'
for firm in `journalctl -xe |grep -e "Direct firmware load" |sed -E 's/[[:alnum:][:punct:][:space:]]+Direct firmware load for //g' |sed -E 's/ failed [[:alnum:][:punct:][:space:]]+//g'`; do
	firm=`echo "$firm" |cut -d "/" -f4-`
	echo "firmware $firm" >> /firmware.list
done
unset IFS

for module in `lsmod |cut -d " " -f 1`; do
	if [ "$module" != "Module" ]; then
		mdfile=`modinfo $module |grep -e filename: |cut -c 17-`
		mdfile=`basename $mdfile |cut -d "." -f 1`
		echo "module $mdfile" | grep -Ev 'cache|fuse|squashfs|fat|ntfs|nfs|lockd|sunrpc|autofs4|isofs|udf|cifs|reiserfs|exportfs|ext|jbd|jfs|nls|xfs|usb-storage' | sort >>/module.list
	fi
done

#if [ -e /bin/Xorg ] && [ ! -e /var/log/Xorg.0.log ]; then
#	Xorg -configure
#fi
if [ -e /var/log/Xorg.0.log ]; then
	xdriver=`grep /var/log/Xorg.0.log -e "driver 0" |cut -d\) -f2 |cut -d " " -f3`
	for available in radeon intel geode vmware sis openchrome nv ati nouveau; do
		if [ "$xdriver" == "$available" ]; then
			echo package xorg7-$xdriver >> /package.list
		fi
	done
fi

if [ -e /sys/devices/platform/uvesafb.0/vbe_modes ]; then
	cp /sys/devices/platform/uvesafb.0/vbe_modes /vbe_modes.list
fi

if [ -n "$SERVER_IP" ]; then
	tftp -p -l /module.list -r module.list $SERVER_IP

	if [ -e /package.list ]; then
		tftp -p -l /package.list -r package.list $SERVER_IP
	fi
	if [ -e /vbe_modes.list ]; then
		tftp -p -l /vbe_modes.list -r vbe_modes.list $SERVER_IP
	fi
	if [ -e /firmware.list ]; then
		tftp -p -l /firmware.list -r firmware.list $SERVER_IP
	fi
fi
