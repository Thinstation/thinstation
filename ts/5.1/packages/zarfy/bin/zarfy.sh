#!/bin/sh
presize=`xrandr 2>/dev/null |grep -e \* |cut -d " " -f4`
/bin/zarfy
postsize=`xrandr 2>/dev/null |grep -e \* |cut -d " " -f4`
if [ "$presize" != "$postsize" ]; then
	. $TS_GLOBAL
	use_wallpaper
fi
