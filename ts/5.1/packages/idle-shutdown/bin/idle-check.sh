#!/bin/sh
#
# ThinStation Anti Idle (idle-check.sh)
# 
# Copyright (C) 2007 Daniel Meyer (eagle@cyberdelia.de)
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, version 2.
#
#
# script for shutting down thinstation after a certain idle period
# uses the following config variables:
#
# SHUTDOWN_IDLE_INTERVAL - every SHUTDOWN_IDLE_INTERVAL minutes 
# the current idle time will be checked via crontab. Default value
# is every 5 minutes
#
# SHUTDOWN_IDLE_TIME - how long is the thinstation allowed to idle.
# default value is 1800 seconds
#
# SHUTDOWN_PROGRAM - which program to check for. having that program
# running will reset the idle counter, default value is wfica
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
  SHUTDOWN_PROGRAM="wfica"
fi


# Get current timestamp
TIMESTAMP=`/bin/date +%s`
STEP=$((${SHUTDOWN_IDLE_INTERVAL}*60))

# check if an important program is running
/bin/ps aux | /bin/grep -v grep | /bin/grep -q -E ${SHUTDOWN_PROGRAM}
PROGRAM=$?
if [ ${PROGRAM} = 0 ]; then
  # $Program is running, update timestamp
  echo ${TIMESTAMP} > /tmp/idle-check.dat
else
  # $program is not running, check for previous timestamp
  if [ -e "/tmp/idle-check.dat" ]; then 
    # timestamp exists, read it
    LASTTIMESTAMP=`/bin/cat /tmp/idle-check.dat`
    # how long did we idle?
    if [ ${LASTTIMESTAMP} -le 86400 ]; then
      # timestamp is < 86400, so citrix was never running and we're
      # increasing the timestemp by checkinterval*60 seconds
      LASTTIMESTAMP=$((${LASTTIMESTAMP}+${STEP}))
      # we're idling since LASTTIMESTAMP seconds
      DIFF=${LASTTIMESTAMP}
    else
      # timestamp is > 86400, so we're assuming we've seen citrix
      # active and have a epoc-timestamp 
      # idle-time is simply current timestamp - last timetamp
      DIFF=$((${TIMESTAMP}-${LASTTIMESTAMP}))
    fi
    # save current timetamp
    echo ${LASTTIMESTAMP} > /tmp/idle-check.dat
    # check if we're still below the configured max. idle time
    if [ ${DIFF} -gt ${SHUTDOWN_IDLE_TIME} ]; then
      # nope, we're not -> shutting down the thinclient
      # also checking if we need to inform a ThinStation Management
      # Server
      if [ -e "/bin/sysinfo.sh" ]; then
        /bin/sysinfo.sh idle
      fi
      touch /tmp/shutdown ; clear ; poweroff
    fi
  else
    # no timestamp yet, setting timestamp to 0
    echo 0 > /tmp/idle-check.dat
  fi
fi

