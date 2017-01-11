#!/bin/bash

# Set resolution with setres and save it in local profile for next reboot.

. $TS_GLOBAL
LOGGERTAG="set-resolution.sh"
PROFILE_DIR="${STORAGE_PATH}/thinstation.profile"

if [ -z "$1" ]; then
	# No argument has been given, ask the user what resolution to use...
	
	# Get all available resolutions into an array
	RESOLUTIONS=($(xrandr | cut -d' ' -f4 | grep -P '[0-9]x[0-9]'))

	if [ ${#RESOLUTIONS[@]} -le 0 ]; then
		echo "Unable to get the available resolutions from 'xrandr', exiting."
		sleep 10s
	else
		echo "Your current resolution is $(xrandr | grep \* | cut -d' ' -f4)"

		# Try to check what resolution we have saved for next boot.
		if [ -n "${STORAGE_PATH}" ] && [ -f "${PROFILE_DIR}/thinstation.conf.user" ] ; then
			SAVED_RES=$(grep -P "^SCREEN_RESOLUTION=" ${PROFILE_DIR}/thinstation.conf.user | cut -d'=' -f2)
			if [ -n "${SAVED_RES}" ]; then
				echo 
				echo "The resolution saved in ${PROFILE_DIR}/thinstation.conf.user (that will be used on next restart) is ${SAVED_RES//"\""/""}"
			fi
		fi
			
		echo 
		echo "Your available resolutions are:"

		for r in "${RESOLUTIONS[@]}"
		do
			echo "   $r"
		done

		echo 
		printf "Enter the resolution you want to use: "

		read ANSWER
	
		if [[ " ${RESOLUTIONS[@]} " =~ " ${ANSWER} " ]]; then
			set-resolution.sh $ANSWER
		else
			echo "\"${ANSWER}\" is not a valid resolution. You must enter the resolution exactly as stated above, for example: ${RESOLUTIONS[0]}"
			echo ""
			echo "Exiting..."
			sleep 10s
			# I added the sleep for 10 seconds since this is written to run in a terminal i X without hold
			# and thereby the terminal closes as soon as the script ends, = the user wont see the message without the sleep
		fi
	fi
else
	# The argument $1 has been given, validate that it's a correct formated resolution (e.g. 123x123)
	REGEX="^[0-9]+x[0-9]+$"
	if [[ ! $1  =~ $REGEX ]]; then
		logger --stderr --tag $LOGGERTAG "The argument \"$1\" is not a valid resolution!"
	else
		# Change the resolution
		setres $1

		# Check if the change went well... grep out the current resolution...
		#if [[ "$(xrandr | grep '*')" == *"$1"* ]]; then
		if [[ "$(xrandr | grep \* | cut -d' ' -f4)" == "$1" ]]; then
			if [ -n "${STORAGE_PATH}" ] && [ -d "${STORAGE_PATH}" ]; then
		
				# Create the directory if needed...
				if [ ! -d "${PROFILE_DIR}" ]; then mkdir ${PROFILE_DIR}; fi
		
				if [ -f ${PROFILE_DIR}/thinstation.conf.user ]; then
					grep -q -P '^SCREEN_RESOLUTION=' ${PROFILE_DIR}/thinstation.conf.user && sed -i "/^SCREEN_RESOLUTION=/c\SCREEN_RESOLUTION=\"$1\"" ${PROFILE_DIR}/thinstation.conf.user || echo "SCREEN_RESOLUTION=\"$1\"" >> ${PROFILE_DIR}/thinstation.conf.user
				else
					echo "SCREEN_RESOLUTION=\"$1\"" > ${PROFILE_DIR}/thinstation.conf.user
				fi
		
				logger --stderr --tag $LOGGERTAG "Change the resolution to $1 seams to work well and has been saved to the configuration file\"${PROFILE_DIR}/thinstation.conf.user\""
			else
				logger --stderr --tag $LOGGERTAG "Change the resolution to $1 seams to work well but STORAGE_PATH is not declared or the path does not exist. STORAGE_PATH is \"${STORAGE_PATH}\""
			fi
		else
			logger --stderr --tag $LOGGERTAG "Something went wrong when trying to change the resolution to $1. The resolution might not be available, for available resolutions run \"xrandr\". To see what error message was returned run \"setres $1\""
		fi
	fi
fi
