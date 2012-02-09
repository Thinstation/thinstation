#! /bin/sh
. /etc/thinstation.env
. $TS_GLOBAL

header

lshw -html

echo '</pre>'

trailer
