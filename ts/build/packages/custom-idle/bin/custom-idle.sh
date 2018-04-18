#!/bin/sh

. $TS_GLOBAL
LOGGERTAG="custom-idle.sh"

#Convert the IDLE_SHUTDOWN_MINUTES into seconds...
IDLE_TIMEOUT=$((${IDLE_SHUTDOWN_MINUTES} * 60))


# Check that IDLE_TIMEOUT has been given...
if [ -z "$IDLE_SHUTDOWN_MINUTES" -o $IDLE_TIMEOUT -le 60 ]; then
	logger --stderr --tag $LOGGERTAG "IDLE_SHUTDOWN_MINUTES is not set or less then 1." 
fi


# Check that IDLE_CHECK_FOR_PROCESSES has been given
if [ -z "$IDLE_CHECK_FOR_PROCESSES" ]; then
	logger --stderr --tag $LOGGERTAG "IDLE_CHECK_FOR_PROCESSES is empty"
fi

# Write a timestamp if the file dosn't already exist.
if [ ! -f /tmp/idle_alive ]; then
	date +%s > /tmp/idle_alive
fi

# Check if any of our processes are running and if so, update the timestamp.
#if ps -o comm | egrep -q "ica|wfcmgr|chrome|xterm|gnome-mplayer"; then
if ps -o comm | egrep -qw "$IDLE_CHECK_FOR_PROCESSES"; then
	date +%s > /tmp/idle_alive
	logger --stderr --tag $LOGGERTAG "The following processes defined in IDLE_CHECK_FOR_PROCESSES ($IDLE_CHECK_FOR_PROCESSES) are still running: $(ps -o comm | egrep "$IDLE_CHECK_FOR_PROCESSES" | sort | uniq)"
	return
fi


# Get the last timestamp when the processes was running
ALIVE=$(cat /tmp/idle_alive)

# Calculate the time difference
TIME=$(date +%s)
IDLE=$(expr ${TIME} - ${ALIVE})

if [ ${IDLE} -gt ${IDLE_TIMEOUT} ]; then
	if [ -e "/bin/sysinfo.sh" ]; then
		/bin/sysinfo.sh idle
	fi
	logger --stderr --tag $LOGGERTAG "None of the processes in IDLE_CHECK_FOR_PROCESSES has been running during the IDLE_SHUTDOWN_MINUTES, beginning shutdown"
	
	# Check if shall make a reboot or a poweroff
	if [ "$IDLE_SHUTDOWN_ACTION" = "reboot" ]; then
		touch /tmp/shutdown ; clear ; reboot
	else
		touch /tmp/shutdown ; clear ; poweroff
	fi
	
else
	logger --stderr --tag $LOGGERTAG "None of the processes in IDLE_CHECK_FOR_PROCESSES are currently running but the IDLE_SHUTDOWN_MINUTES (${IDLE_SHUTDOWN_MINUTES} min) has not been exceeded yet. All processes has currently been inactive for $(($IDLE / 60)) minutes."
fi
