#!/bin/sh

. $TS_GLOBAL
LOGGERTAG="hdd-spindown_logging.sh"


# Write a timestamp if the file dosn't already exist.
if [ ! -f /tmp/hdd-spindown_starttime ]; then
	date +%s > /tmp/hdd-spindown_starttime
fi

# Calculate the times
STARTTIME=$(cat /tmp/hdd-spindown_starttime)
TIME=$(date +%s)
ACTIVE_TIME=$(expr ${TIME} - ${STARTTIME})

if hdparm -C /dev/sda | egrep -q "standby"; then

	if [ ! -f /tmp/hdd-spindown_standby ]; then
		date +%s > /tmp/hdd-spindown_standby
		logger --stderr --tag $LOGGERTAG "The drive is now in standby, it took $(($ACTIVE_TIME / 60)) minutes and $(($ACTIVE_TIME % 60)) seconds."
	else

		STANDBYMARK=$(cat /tmp/hdd-spindown_standby)
		STANDBY_TIME=$(expr ${TIME} - ${STANDBYMARK})

		logger --stderr --tag $LOGGERTAG "The drive state is still in standby and has been so for at least $(($STANDBY_TIME / 60)) minutes and $(($STANDBY_TIME % 60)) seconds."
	fi
	

	#logger --stderr --tag $LOGGERTAG "The drive state is now standby, it took $(($ACTIVE_TIME / 60)) minutes and $(($ACTIVE_TIME % 60)) seconds."
	#rm /tmp/hdd-spindown_starttime
else
	if [ -f /tmp/hdd-spindown_standby ]; then
		logger --stderr --tag $LOGGERTAG "The drive has now change status from standby to active, setting a new the time mark."
		date +%s > /tmp/hdd-spindown_starttime
		rm -f /tmp/hdd-spindown_standby
	else
		logger --stderr --tag $LOGGERTAG "The drive state is not in standby. it has not been so for at least the last $(($ACTIVE_TIME / 60)) minutes and $(($ACTIVE_TIME % 60)) seconds."
	fi
fi
