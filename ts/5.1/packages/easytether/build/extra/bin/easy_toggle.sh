#!/bin/sh

pidofeasytether="`ps x |grep -e 'easytether connect' |grep -v grep |cut -d ' ' -f2`"
if [ -n "$pidofeasytether" ]; then
	kill -HUP $pidofeasytether
elif [ -n "`easytether enumerate 2>&1 |grep -v USB`" ]; then
	easytether connect
else
	Xdialog --title "Error !" --msgbox "No EasyTether Device Detected" 0 0 2> /dev/null
fi
