#!/bin/bash
#
# Copyright 2015 VMware, Inc.  All rights reserved.
#
# This script manages the Virutual Printing service
#

# VMWARE_INIT_INFO

# Execute a macro
vmware_exec() {
  local msg="$1"  # IN
  local func="$2" # IN
  shift 2

  # On Caldera 2.2, SIGHUP is sent to all our children when this script exits
  # I wanted to use shopt -u huponexit instead but their bash version
  # 1.14.7(1) is too old
  #
  # Ksh does not recognize the SIG prefix in front of a signal name
  (trap '' HUP; "$func" "$@") >/dev/null 2>&1
  if [ "$?" -gt 0 ]; then
    return 1
  fi

  return 0
}

# Start the Virtual Printing service
vmwareStartVirtualPrinting() {
    # The executable checks for already running instances, so it
    #  is safe to just run it.
    `/usr/bin/thnuclnt -fg &`
}

# Stop the Virtual Printing service
vmwareStopVirtualPrinting() {
   pid=`pgrep -f /usr/bin/thnuclnt`

   if [[ "$pid" = "" ]]; then
      return 0
   fi

   # Kill the virtual printing process
   kill -15 $pid
   # Give it a few seconds to shut down properly
   for f in 1 2 3 4 5 6 7 8 9 10; do
      pid=`pgrep -f /usr/bin/thnuclnt`
      if [ -z "$pid" ]; then
         # No need to wait if it's already down
         break
      fi
      sleep 1
   done

   # Give it a few seconds to shut down after the kill
   for f in 1 2 3 4 5 6 7 8 9 10; do
      pid=`pgrep -f /usr/bin/thnuclnt`
      if [ -z "$pid" ]; then
         # No need to wait if it's already down
         break
      fi
      sleep 1
   done

   pid=`pgrep -f /usr/bin/thnuclnt`
   if [ -n "$pid" ]; then
      # Failed to kill it...
      return 1
   else
      # Success!
      return 0
   fi
}

vmwareService() {
   case "$1" in
      start)
         vmware_exec 'VMware Virtual Printing' vmwareStartVirtualPrinting
         exitcode=$(($exitcode + $?))
         if [ "$exitcode" -gt 0 ]; then
            exit 1
         fi
         ;;
      stop)
         vmware_exec 'VMware Virtual Printing' vmwareStopVirtualPrinting
         exitcode=$(($exitcode + $?))
         if [ "$exitcode" -gt 0 ]; then
            exit 1
         fi
         ;;
      restart)
         "$SCRIPTNAME" stop && "$SCRIPTNAME" start
         ;;
      *)
         echo "Usage: $BASENAME {start|stop|restart}"
         exit 1
   esac
}

SCRIPTNAME="$0"
BASENAME=`basename "$SCRIPTNAME"`

vmwareService "$1"

exit 0
