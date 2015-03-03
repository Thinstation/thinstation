#!/bin/sh
. $TS_GLOBAL
presize=`get_res`
/bin/zarfy
postsize=`get_res`
if [ "$presize" != "$postsize" ]; then
	use_wallpaper
	use_idesk
fi
