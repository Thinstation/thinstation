#!/bin/bash
#
# Mount Hotplug Device
#

. /etc/thinstation.env
. $TS_GLOBAL

#exec </dev/null >>/var/log/scsi.log  2>&1
#set -x

devpath=`basename $DEVPATH`
name=`echo $devpath | sed -e "s/[0-9]*//g"`
node=`echo $devpath | sed -e "s/[a-z]*//g"`
TYPE=`echo $name | cut -c 1-2`

no_mount()
{
	for diskutil_ in gparted parted fdisk cfdisk; do
		if [ -n "`pidof $diskutil_`" ]; then
			return 0
		fi
	done
	if [ -e /tmp/nomount ]; then
		return 0
	else
		return 1
	fi
}

mounted()
{
	if [ -n "`grep -oe ^"$1" /proc/mounts`" ]; then
		return 0
	else
		return 1
	fi
}

_unmount()
{
	if [ "$ID_FS_TYPE" == "swap" ]; then
		swapoff /dev/$devpath
	else
		while mounted /dev/$devpath; do
			mtdpath=`cat /proc/mounts |grep -e /dev/$devpath |tail -n 1 |cut -d ' ' -f 2`
			systemd-mount -u $mtdpath
			if is_enabled $CLEAN_UMOUNT; then
				rm -f $mtdpath/"Not Mounted"
				rmdir $mtdpath
			fi
		done
	fi
}

# Exit if were 'not' needed, or handle simple umounts or swapon
if [ -n "`busybox pgrep udisksd`" ]; then
	exit 0
elif [ "$ACTION" == "remove" ]; then
	_unmount
	exit 0
elif [ "$TYPE" == "sr" ] \
  && [ "$ID_CDROM_MEDIA" != "1" ]; then
	_unmount
	exit 0
elif no_mount;then
	exit 0
elif [ "$ACTION" == "add" ] \
  && [ "$ID_FS_TYPE" == "swap" ]; then
	swapon /dev/$devpath
	exit 0
fi

# The more complex task of finding a mount point and mounting it.
if ! check_module $ID_FS_TYPE; then
	modprobe $ID_FS_TYPE
fi

cmount()
{
	if [ "`busybox mountpoint -n $1`" == "/dev/$devpath $1" ] \
	&& [ -n "`ls -A $1|grep -v 'Not Mounted'`" ]; then
		return 0
	fi
	return 1
}

do_mounts()
{
	if [ ! -e $mtpath ] \
	  || ! cmount $mtpath; then
		_unmount
		mkdir -p $mtpath
		touch $mtpath/"Not Mounted"
		if [ -n "$mount_opts" ]; then
			systemd-mount --type=$ID_FS_TYPE --no-block --fsck=no -o $mount_opts /dev/$devpath $mtpath
		else
			systemd-mount --type=$ID_FS_TYPE --no-block --fsck=no /dev/$devpath $mtpath
		fi
	fi
	local index=0
	local MOUNT FS_LABEL MT_PATH
	while [ -n "`eval echo '$BIND_MOUNT'$index`" ]; do
		MOUNT=`eval echo '$BIND_MOUNT'$index`
		FS_LABEL=`echo "$MOUNT" | cut -d ":" -f1`
		MT_PATH=`echo "$MOUNT" | cut -d ":" -f2`
		if [ "$ID_FS_LABEL" == "$FS_LABEL" ]; then
			if [ ! -e $MT_PATH ] \
			  || ! cmount $MT_PATH; then
				mkdir -p $MT_PATH
				touch $mtpath/"Not Mounted"
				systemd-mount --no-block --bind $mtpath $MT_PATH
			fi
		fi
		if [ "$PARTNAME" == "$FS_LABEL" ]; then
			if [ ! -e $MT_PATH ] \
			  || ! cmount $MT_PATH; then
				mkdir -p $MT_PATH
				touch $mtpath/"Not Mounted"
				systemd-mount --no-block --bind $mtpath $MT_PATH
			fi
		fi
		let index+=1
	done
}

if [ "$TYPE" == "sr" ] \
&& [ "$ACTION" == "change" ]; then
	for var in `cdrom_id /dev/$devpath`; do
		export $var
	done
	if [ "$ID_CDROM_MEDIA" == "1" ]; then
		if [ -e /proc/sys/dev/cdrom ]; then
			echo 0 > /proc/sys/dev/cdrom/autoclose
		fi
		if is_enabled "$LOCK_CDROM"; then
			echo 0 > /proc/sys/dev/cdrom/lock
		fi
		mtpath=$BASE_MOUNT_PATH/cdrom$node
		mount_opts="$CDROM_MOUNT_OPTIONS"
		do_mounts
	fi
elif ( [ "$TYPE" == "sd" ] || [ "$TYPE" == "mm" ] ) \
    && [ "$ACTION" == "add" ]; then
	if [ "$ID_BUS" == "usb" ] \
	|| [ "$TYPE" == "mm" ]; then
		if is_enabled "$USB_STORAGE_SYNC" \
		&& [ -z "`echo $USB_MOUNT_OPTIONS |grep -e sync`" ]; then
			USB_MOUNT_OPTIONS=$USB_MOUNT_OPTIONS,sync
		fi
		label=$devpath
		if [ -n "$USB_MOUNT_USELABEL" ]; then
			if is_enabled $USB_MOUNT_USELABEL; then
				if [ -n "$ID_FS_LABEL" ]; then
					label=$ID_FS_LABEL
				elif [ -n "$ID_FS_UUID" ]; then
					label=$ID_FS_UUID
				fi
			elif ! is_disabled $USB_MOUNT_USELABEL; then
				if [ -n "$ID_FS_LABEL" ]; then
					label=$ID_FS_LABEL
				else
					label=$USB_MOUNT_USELABEL
				fi
			fi
		fi
		mtpath=$BASE_MOUNT_PATH/$USB_MOUNT_DIR/$label
		index=0
		testmountpoint=$mtpath
		while mounted $testmountpoint; do
			let index+=1
			testmountpoint=$mtpath$index
		done
		if [ "$testmountpoint" != "$mtpath" ]; then
			mtpath=$testmountpoint
		fi
		mount_opts="$USB_MOUNT_OPTIONS"
		do_mounts
	elif ! is_disabled $HD_MOUNT; then
		if is_enabled $DISK_STORAGE_SYNC \
		&& [ -z "`echo $DISK_MOUNT_OPTIONS |grep -e sync`" ]; then
			DISK_MOUNT_OPTIONS=$DISK_MOUNT_OPTIONS,sync
		fi
		mtpath=$BASE_MOUNT_PATH/disc/$name/part$node
		mount_opts="$DISK_MOUNT_OPTIONS"
		do_mounts
	fi
fi

exit 0
