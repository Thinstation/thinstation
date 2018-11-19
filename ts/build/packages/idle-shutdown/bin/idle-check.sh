#!/bin/sh
#
# ThinStation Anti Idle (idle-check.sh)
# 
# Copyright (C) 2007 Daniel Meyer (eagle@cyberdelia.de)
# Copyright (C) 2013 Jens Maus (mail@jens-maus.de)
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, version 2.
#
#
# script for shutting down thinstation after a certain idle period
# using the following config variables:
#
# SHUTDOWN_IDLE_INTERVAL - every SHUTDOWN_IDLE_INTERVAL minutes 
# the current idle time will be checked via crontab. Default value
# is every 5 minutes
#
# SHUTDOWN_IDLE_TIME - how long is the thinstation allowed to idle.
# default value is 1800 seconds
#
# SHUTDOWN_PROGRAM - which programs to check for. having that program
# running will reset the idle counter.
# default value is "tlclient|xfreerdp|rdesktop|vncviewer|wfica"
#
# SHUTDOWN_MAX_UPTIME - the number of seconds of maximum uptime until
# the idle check is performed. default value is 0 (disabled)
#
# SHUTDOWN_MAX_UPTIME_HOUR - if max uptime check is enabled the value
# stored here is the hour were an immediate shutdown of the system
# is performed if max uptime had been reached.
# default value is 3 (which means during 3:00 till 3:59 am)
#


# get variables
. $TS_GLOBAL

# sanitize config
if [ -z ${SHUTDOWN_IDLE_INTERVAL} ]; then
  SHUTDOWN_IDLE_INTERVAL=5
fi
if [ -z ${SHUTDOWN_IDLE_TIME} ]; then
  SHUTDOWN_IDLE_TIME=1800
fi
if [ -z ${SHUTDOWN_PROGRAM} ]; then
  SHUTDOWN_PROGRAM="tlclient|xfreerdp|rdesktop|vncviewer|wfica"
fi
if [ -z ${SHUTDOWN_MAX_UPTIME} ]; then
  SHUTDOWN_MAX_UPTIME=0
fi
if [ -z ${SHUTDOWN_MAX_UPTIME_HOUR} ]; then
  SHUTDOWN_MAX_UPTIME_HOUR=3
fi

# Get current timestamp
TIMESTAMP=`/bin/date +%s`
STEP=$((${SHUTDOWN_IDLE_INTERVAL}*60))

# 1. we check via "xset -q" the status of the Monitor
# (if it is on or off)
MONITOR_STAT=`/bin/xset -q | grep "Monitor is" | awk '{ print $3 }'`
if [ ${MONITOR_STAT} != "On" ]; then
  # Monitor is either Off, Standby or Sleeping
  CHECK_IDLE_TIME=1
else
  # Monitor is not off

  # 2. we check that none of the programs which are curial are running
  /bin/ps aux | /bin/grep -v grep | /bin/grep -q -E "${SHUTDOWN_PROGRAM}"
  PROGRAM_STAT=$?
  if [ ${PROGRAM_STAT} != 0 ]; then
    # important programs are NOT running
    CHECK_IDLE_TIME=1
  else
    # important programs are running

    # 3. check for max uptime
    CURRENT_UPTIME=`cat /proc/uptime | awk '{ print int($1) }'`
    if [ ${SHUTDOWN_MAX_UPTIME} -gt 0 ] && [ ${CURRENT_UPTIME} -gt ${SHUTDOWN_MAX_UPTIME} ]; then
      # max uptime has been reached
      
      # if we have reached the hour were immediate shutdowns
      # are allowed we set the SHUTDOWN_IDLE_TIME to 1 so that
      # the next run of the idle check shuts down the machine immediately
      if [ ${SHUTDOWN_MAX_UPTIME_HOUR} = `/bin/date +%H` ]; then
        SHUTDOWN_IDLE_TIME=1
      fi

      CHECK_IDLE_TIME=1
    else
      # non of the above conditions (monitor, programs, max uptime) had been reached. So
      # the system is in proper use and we don't perform any idle timeout check

      CHECK_IDLE_TIME=0
      echo ${TIMESTAMP} > /tmp/idle-check.dat
    fi
  fi
fi

# if we are instructed to check the idle time we process
# it now
if [ ${CHECK_IDLE_TIME} = 1 ]; then

  # check for previous timestamp
  if [ -e "/tmp/idle-check.dat" ]; then 
    # timestamp exists, read it
    LASTTIMESTAMP=`/bin/cat /tmp/idle-check.dat`

    # how long did we idle?
    if [ ${LASTTIMESTAMP} -le 86400 ]; then
      # timestamp is < 86400, so the above conditions (monitor, programs, max uptime)
      # were never met. Thus we're increasing the timestemp by checkinterval*60 seconds
      LASTTIMESTAMP=$((${LASTTIMESTAMP}+${STEP}))

      # we're idling since LASTTIMESTAMP seconds
      DIFF=${LASTTIMESTAMP}
    else
      # timestamp is > 86400, so the above conditions (monitor, programs, max uptime)
      # were at least met once and /tmp/idle-check.dat has a valid epoc timestamp.
      # Thus, idle-time is simply current timestamp - last timetamp
      DIFF=$((${TIMESTAMP}-${LASTTIMESTAMP}))
    fi

    # check if we're still below the configured max. idle time
    if [ ${DIFF} -gt ${SHUTDOWN_IDLE_TIME} ]; then
      # nope, we're not -> shutting down the thinclient
      # also checking if we need to inform a ThinStation Management
      # Server
      if [ -e "/bin/sysinfo.sh" ]; then
        /bin/sysinfo.sh idle
      fi

      # poweroff the system
      touch /tmp/shutdown ; clear ; poweroff
    else
      # save current timestamp (epoc or non-epoc)
      echo ${LASTTIMESTAMP} > /tmp/idle-check.dat
    fi
  else
    # no timestamp yet, setting timestamp to 0
    echo 0 > /tmp/idle-check.dat
  fi
fi
