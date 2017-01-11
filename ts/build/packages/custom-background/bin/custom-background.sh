#!/bin/sh

. /etc/thinstation.env
. $TS_GLOBAL
LOGGERTAG="custom-background.sh"

if [ -n "${CUSTOM_BACKGROUND}" ]; then

	# Exit if the background image does not exist.
	if [ ! -f "${CUSTOM_BACKGROUND}" ]; then
		#echo "Exiting custom-background package since the file ${CUSTOM_BACKGROUND} was not found."
		logger --stderr --tag $LOGGERTAG "The background file '${CUSTOM_BACKGROUND}' set by CUSTOM_BACKGROUND was not found."
		exit 0
	fi

	cp "${CUSTOM_BACKGROUND}" /etc/background.jpg
	logger --stderr --tag $LOGGERTAG "Copied the file '${CUSTOM_BACKGROUND}' set by CUSTOM_BACKGROUND to /etc/background.jpg"
else
	#echo "CUSTOM_BACKGROUND parameter not set, exiting."
	logger --stderr --tag $LOGGERTAG "CUSTOM_BACKGROUND parameter not set, exiting."
	exit 0
fi
