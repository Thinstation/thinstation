. $TS_RUNTIME

for module in `lsmod |cut -d " " -f 1` ;
 do if [ $module == "Module" ] ;
	then echo $module >/dev/null ;
	else
	mdfile=`modinfo $module |grep -e filename: |cut -d " " -f 8 |cut -d "." -f 1` ;
	echo "module $mdfile" | grep -Ev 'fuse|squashfs|fat|ntfs|nfs|lockd|sunrpc|autofs4|isofs|udf|cifs|reiserfs|exportfs|ext|jbd|jfs|nls|xfs|usb-storage' | sort >>/module.list
     fi
done
tftp -p -l /module.list -r module.list $SERVER_IP
if [ -e /sys/devices/platform/uvesafb.0/vbe_modes ]; then
	cp /sys/devices/platform/uvesafb.0/vbe_modes /vbe_modes.list
	tftp -p -l /vbe_modes.list -r vbe_modes.list $SERVER_IP
fi
if [ -e /var/log/firmware.log ]; then
	cp /var/log/firmware.log /firmware.list
	tftp -p -l /firmware.list -r firmware.list $SERVER_IP
fi
