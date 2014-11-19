#!/bin/sh

if [ -x /usr/bin/dbus-launch ]
then
	eval `dbus-launch --sh-syntax --exit-with-session`
	export DBUS_SESSION_BUS_ADDRESS
	export DBUS_SESSION_BUS_PID
fi
