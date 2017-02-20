#!/bin/sh

. $TS_GLOBAL
LOGGERTAG="custom-background.sh"

if [ -n "${CUSTOM_BACKGROUND}" ]; then

    # Check if it's a URL or regular file path.
    if [ $(echo $CUSTOM_BACKGROUND | grep 'http://') ]; then

        # Download the file
        wget -O '/tmp/background.jpg' $CUSTOM_BACKGROUND

        if [ ${?} -eq 0 ]; then
            if [ -f '/tmp/background.jpg' ]; then
                cp -f '/tmp/background.jpg' /etc/background.jpg
                rm '/tmp/background.jpg'
                logger --stderr --tag $LOGGERTAG "Copied the file '${CUSTOM_BACKGROUND}' set by CUSTOM_BACKGROUND to /etc/background.jpg"
            else
                logger --stderr --tag $LOGGERTAG "Successfully downloaded the file '${CUSTOM_BACKGROUND}' but it was not found at /tmp/background.jpg when trying to copy it to /etc/background.jpg"
            fi
        else
            logger --stderr --tag $LOGGERTAG "Failed to download the file '${CUSTOM_BACKGROUND}', verify that the URL it exists!"
        fi



    else
        # CUSTOM_BACKGROUND is a regular file path

        # Exit if the background image does not exist.
        if [ ! -f "${CUSTOM_BACKGROUND}" ]; then
            logger --stderr --tag $LOGGERTAG "The background file '${CUSTOM_BACKGROUND}' set by CUSTOM_BACKGROUND was not found."
            exit 1
        fi

        cp -f "${CUSTOM_BACKGROUND}" /etc/background.jpg
        logger --stderr --tag $LOGGERTAG "Copied the file '${CUSTOM_BACKGROUND}' set by CUSTOM_BACKGROUND to /etc/background.jpg"
    fi
else
    logger --stderr --tag $LOGGERTAG "CUSTOM_BACKGROUND parameter not set, exiting."
    exit 0
fi
