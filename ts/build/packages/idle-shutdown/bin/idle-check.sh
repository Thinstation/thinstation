#!/bin/sh
#
# ThinStation Idle Shutdown (idle-check.sh)
# -----------------------------------------
# 
# script for shutting down thinstation after a certain idle period
# based on the following conditions:
#
# 1. the user hasn't touched the mouse or keyboard for X seconds:
#    ('xprintidle' command vs. SHUTDOWN_IDLE_TIME)
#
# 2. the system has reached a maximum allowed uptime without reboot:
#    ('uptime' command vs. SHUTDOWN_IDLE_MAX_UPTIME)
#
# 3. the current time/weekday is allowed to immediately shutdown the
#    system if condition 1 or 2 is met:
#    (SHUTDOWN_IDLE_HOUR and SHUTDOWN_IDLE_MAX_UPTIME_WDAY)
#
# Variables used:
# --------------
#
# SHUTDOWN_IDLE_INTERVAL - the interval (in minutes) this script
# is being called via crontab to check for idling systems.
#
# SHUTDOWN_IDLE_TIME - how long is thinstation allowed to idle
# (in seconds) before it is flagged to be shutdown at the next allowed
# time or week day (default is 86400).
#
# SHUTDOWN_IDLE_HOUR - if system is flagged to be shutdown due to being
# idling too long or due to max uptime reached it will only be allowed
# to be shutdown at this specific hour of the day (default is '3' which
# means from 3 am till 4 am).
#
# SHUTDOWN_IDLE_MAX_UPTIME - the number of seconds of maximum allowed
# uptime of the system before it is flagged to be shutdown (default
# is '0' - disabled)
#
# SHUTDOWN_IDLE_MAX_UPTIME_WDAY - if a shutdown should be performed due
# to max uptime being reached the shutdown will only be allowed on these
# specific weekdays (default is 'Sat|Sun' which means either Saturday or
# Sunday)
#
#
# Copyright (C) 2007 Daniel Meyer (eagle@cyberdelia.de)
# Copyright (C) 2013-2016 Jens Maus (mail@jens-maus.de)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, version 2.
#

# default config
SHUTDOWN_IDLE_INTERVAL=5
SHUTDOWN_IDLE_TIME=86400
SHUTDOWN_IDLE_HOUR=3
SHUTDOWN_IDLE_MAX_UPTIME=0
SHUTDOWN_IDLE_MAX_UPTIME_WDAY="Sat|Sun"

# get global variables and overwrite our default settings
. $TS_GLOBAL

# assume we should NOT shutdown
SHUTDOWN_NOW=0

# 1. Check if we reached MAX idle time
if [ ${SHUTDOWN_IDLE_TIME} -gt 0 ] &&
   [ $(($(DISPLAY=:0 /bin/xprintidle)/1000)) -gt ${SHUTDOWN_IDLE_TIME} ]; then
  # max idle time reached.
  SHUTDOWN_NOW=1

  echo "max idle time reached"
fi

# 2. Check if we reached MAX uptime
if [ ${SHUTDOWN_NOW} -eq 0 ] &&
   [ ${SHUTDOWN_IDLE_MAX_UPTIME} -gt 0 ] &&
   [ $(awk '{ print int($1) }' /proc/uptime) -gt ${SHUTDOWN_IDLE_MAX_UPTIME} ]; then
  # max uptime has been reached
  SHUTDOWN_NOW=1

  echo "max uptime reached"

  # max uptime shutdowns should only happen on specific weekdays
  if [ -n "${SHUTDOWN_IDLE_MAX_UPTIME_WDAY}" ] && [ -z "$(LANG=C date +%a | grep -E ${SHUTDOWN_IDLE_MAX_UPTIME_WDAY})" ]; then
    SHUTDOWN_NOW=0

    echo "skipping maxuptime shutdown as current weekday is not permitted"
  fi
fi

# 3. Check if we are at a time where a shutdown is permitted
if [ ${SHUTDOWN_NOW} -eq 1 ]; then

  # Check shutdown hour
  if [ -n "${SHUTDOWN_IDLE_HOUR}" ] && [ ${SHUTDOWN_IDLE_HOUR} -ne $(LANG=C /bin/date +%H) ]; then
    SHUTDOWN_NOW=0

    echo "skipping shutdown as current time is not permitted"
  fi
fi

# 4. Check if we still shut shutdown or not
if [ ${SHUTDOWN_NOW} -eq 1 ]; then
  echo "shutting down system!"

  # shutdown forever!
  if [ -e "/bin/sysinfo.sh" ]; then
    /bin/sysinfo.sh idle
  fi

  # poweroff the system
  touch /tmp/shutdown ; clear ; poweroff
fi
