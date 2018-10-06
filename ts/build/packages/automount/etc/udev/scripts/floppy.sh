#! /bin/sh
#
# Mount Hotplug Device
#

. /etc/thinstation.env
. $TS_GLOBAL

if [ ! -e /mnt/floppy ]; then
  mkdir /mnt/floppy
fi

if check_module supermount ; then
  case $ACTION in
  add)
  	systemd-mount --no-block -o fs=auto,dev=$DEVNAME /mnt/floppy /mnt/floppy
  ;;
  esac
fi

exit 0
