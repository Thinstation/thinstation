#! /bin/sh
#
# Mount Hotplug Device
#

. /etc/thinstation.env
. $TS_GLOBAL

if [ ! -e /mnt/disc ]; then
  mkdir /mnt/disc
fi
devpath=`basename $DEVPATH`
name=`echo $devpath | sed -e "s/[0-9]*//g"`
node=`echo $devpath | sed -e "s/[a-z]*//g"`

RESULT=`cat /proc/ide/$name/media`
if [ "$RESULT" = "cdrom" ] ; then
    case $ACTION in
    add)
	if [ -e /proc/sys/dev/cdrom ] ; then
		echo 0 > /proc/sys/dev/cdrom/autoclose
	fi
	if check_module supermount ; then
	  while true
	  do
		if [ ! -e /mnt/cdrom$x ] ; then
		  mkdir /mnt/cdrom$x
		  mount -t supermount -o fs=auto,dev=/dev/$devpath /mnt/cdrom$x /mnt/cdrom$x
		  break 1
		fi
		let x=x+1
	  done
	fi
    esac
else
    case $ACTION in
    add)
	if vol_id /dev/$devpath > /tmp/volumeinfo ; then
		# Check to see if filesystem module is already loaded, if not then loads it
		. /tmp/volumeinfo
		if ! check_module $ID_FS_TYPE ; then
			modprobe $ID_FS_TYPE
		fi
        	if [ ! -e /mnt/disc/$name ] ; then
			mkdir /mnt/disc/$name
		fi
  		if [ -z "$node" ] ; then
			mkdir /mnt/disc/$name/$name
  			mount -t auto /dev/$devpath /mnt/disc/$name/$name
		else
			mkdir /mnt/disc/$name/part$node
  			mount -t auto /dev/$devpath /mnt/disc/$name/part$node
		fi
	fi
	rm /tmp/volumeinfo
    ;;
    esac
fi

exit 0
