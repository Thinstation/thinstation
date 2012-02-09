#! /bin/sh
#
# Mount an USB-CDROM
#

. /etc/thinstation.env
. $TS_GLOBAL


  if check_module supermount ; then

	case $ACTION in
	add)
  		if [ ! -e /mnt/usbcd ]; then
	       		mkdir /mnt/usbcd
  		fi
		mount -t supermount -o fs=auto,dev=$DEVNAME /mnt/usbcd /mnt/usbcd
	;;
	remove)
		umount /mnt/usbcd
		rmdir /mnt/usbcd
	;;
	esac

  fi

exit 0
