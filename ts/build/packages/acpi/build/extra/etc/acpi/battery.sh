#!/bin/sh
#
# /etc/acpid/battery.sh
#
#               written by Frank Dietrich <ablesoft@gmx.de>
#
#               based on default.sh in the acpid package

# Detect AC connector plugged in or unplugged and take appropriated actions.
#
# On my notebook no event triggered if AC connector plugged in or unplugged.
# So I will use the battery event to detect new powerstate.

# get the AC connector state from /proc filesystem.
STATE=`sed -n 's/^.*\(off\|on\)-line.*/\1/p' /proc/acpi/ac_adapter/ACAD/state`

case "$STATE" in
  on)
    # AC connector plugged in
    # make an entry in /var/log/daemon.log
    logger "acpid: AC connector plugged in."
    # deactivate standby (spindown) timeout for the drive
    /sbin/hdparm -q -S 0 /dev/hda
    ;;
  off)
    # AC connector unplugged
    logger "acpid: AC connector unplugged."
    # activate standby (spindown) timeout for the drive
    # timeout 5 minutes (man hdparm, for more informations)
    /sbin/hdparm -q -S 60 /dev/hda 
    ;;
  *)
    # AC connector in undetermined state
    logger "acpid: Could not determine new AC connector state."
    ;;
esac
