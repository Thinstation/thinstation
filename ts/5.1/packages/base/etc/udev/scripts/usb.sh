#! /bin/sh
#
# Mount Hotplug Device
#

. /etc/thinstation.env
. $TS_GLOBAL

# Run post scripts for appropriate action
run_scripts ()
{
    scriptdir=/etc/hotplug/scripts
    if [ -e $scriptdir/usb.$1 ] ; then
	(echo "`ls $scriptdir/usb.$1`") |
	while read script
	do
	    $scriptdir/usb.$1/$script $devname
	done
    fi
}

devname=`basename $DEVNAME`

case $ACTION in
  add)

	if echo $devname | grep "/dev/sd$" > /dev/null ; then
	    echo_log "We don't mount $devname directly"
	    exit 0
	fi

#	add sync option to mount if set
	if [ "`make_caps $USB_STORAGE_SYNC`" == "OFF" ] ; then
	    sync=""
	else
	    sync="sync"
	fi

#	add any of the optional USB mount options if set
	options=""
	if [ -n $USB_MOUNT_OPTIONS ] ; then
	    options="$USB_MOUNT_OPTIONS"
	fi

#	use a defined mount point directory
	mountdir="/mnt/usbdevice"	 # default
	if [ -n "$USB_MOUNT_DIR" ] ; then
	    mountdir=$USB_MOUNT_DIR
	fi
#	create the usbdevice mount point if it doen't exist
	if [ ! -e "$mountdir" ]; then
	    mkdir $mountdir
	fi

#	get the volume info (including file system type and label
	blkid -o udev $DEVNAME > /tmp/volumeinfo
	. /tmp/volumeinfo
	rm /tmp/volumeinfo
	
#	default the label to the device name
	label=$devname
	if [ -n "$USB_MOUNT_USELABEL" ] ;then
	    if [ "`make_caps $USB_MOUNT_USELABEL`" == "YES" ] ; then
#	    if the user has selected to use the volume label use it (if it exists)
		if [ -n "$ID_FS_LABEL" ] ; then
		    label=$ID_FS_LABEL
		fi
#	    if it has a value other than no, use it as the label if no volume label found
	    elif [ "`make_caps $USB_MOUNT_USELABEL`" != "NO" ] ; then
		if [ -n "$ID_FS_LABEL" ] ; then
		    label=$ID_FS_LABEL
		else
		    label=$USB_MOUNT_USELABEL
		fi
	    fi
	fi

	mountpoint=$mountdir/$label

#	cater for same labels etc., by adding a number suffix if it already exists
	let x=0
	testmountpoint=$mountpoint
	while [ -e ${testmountpoint} ]
	do
	    let x=x+1
	    testmountpoint=$mountpoint$x
	done
	if [ "$testmountpoint" != "$mountpoint" ] ; then
	    mountpoint=$testmountpoint
	fi
	mkdir $mountpoint

#	use the found file system type for vfat & ntfs or if supermount is not loaded (supermount has issues with vfat & ntfs)
	case $ID_FS_TYPE in
	vfat|ntfs)
	    mount -t $ID_FS_TYPE -o $sync,$options $DEVNAME $mountpoint
	    ;;
	*)
	    if check_module supermount ; then
	        mount -t supermount -o fs=auto,dev=$DEVNAME,--,$sync,$options none $mountpoint
	    else
	        # Without supermount we'll just see if the FSTYPE is correct
	        mount -t $ID_FS_TYPE -o $sync,$options $DEVNAME $mountpoint
	    fi
	    ;;
	esac
	ls -la $mountpoint

	if [ ! -e ~/.hotplug/${devname} ] ; then
	    if [ ! -e ~/.hotplug ] ; then
		mkdir ~/.hotplug
	    fi
	    touch ~/.hotplug/${devname}
	fi
	echo "HOTPLUGMOUNTPOINT=$mountpoint" > ~/.hotplug/${devname}
	run_scripts $ACTION
  ;;
  remove)
	mountpoint="/mnt/usbdevice/${devname}"
	if [ -e ~/.hotplug/${devname} ] ; then
	    . ~/.hotplug/${devname}
	    mountpoint=$HOTPLUGMOUNTPOINT
	fi
  	if [ -e ${mountpoint} ] ; then
	    run_scripts $ACTION
	    umount ${mountpoint}
	    rmdir ${mountpoint}
	fi
	if [ -e ~/.hotplug/${devname} ] ; then
	    rm ~/.hotplug/${devname}
	fi
  ;;
esac

exit 0
