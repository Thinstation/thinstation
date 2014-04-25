#!/bin/sh
# /etc/acpi/lid.sh
# Taken from Debian's 2.0.4-1 diff file.  This version handles KDE4.
# Lid Button event handler.
# Checks to see if gnome or KDE are already handling the lid event.
# If not, initiates a suspend.

# getXuser gets the X user belonging to the display in $displaynum.
# If you want the foreground X user, use getXconsole!
# Input:
#   displaynum - X display number
# Output: 
#   XUSER - the name of the user
#   XAUTHORITY - full pathname of the user's .Xauthority file

# if launched through a lid event and lid is open, do nothing
echo "$1" | grep "button/lid" && grep -q open /proc/acpi/button/lid/LID/state && exit 0

getXuser() {
        user=`pinky -fw | awk '{ if ($2 == ":'$displaynum'" || $(NF) == ":'$displaynum'" ) { print $1; exit; } }'`
        if [ x"$user" = x"" ]; then
                startx=`pgrep -n startx`
                if [ x"$startx" != x"" ]; then
                        user=`ps -o user --no-headers $startx`
                fi
        fi
        if [ x"$user" != x"" ]; then
                userhome=`getent passwd $user | cut -d: -f6`
                export XAUTHORITY=$userhome/.Xauthority
        else
                export XAUTHORITY=""
        fi
        export XUSER=$user
}

# Gets the X display number for the active virtual terminal.
# Output:
#   DISPLAY - the X display number
#   See getXuser()'s output.
getXconsole() {
        console=`fgconsole`;
        displaynum=`ps t tty$console | sed -n -re 's,.*/X .*:([0-9]+).*,\1,p'`
        if [ x"$displaynum" != x"" ]; then
                export DISPLAY=":$displaynum"
                getXuser
        fi
}

# Skip if we are just in the middle of resuming.
test -f /var/lock/acpisleep && exit 0

# If the current X console user is running a power management daemon that
# handles suspend/resume requests, let them handle policy.

getXconsole

# A list of power management system process names.
PMS="gnome-power-manager kpowersave xfce4-power-manager"
PMS="$PMS guidance-power-manager.py dalston-power-applet"

# If one of those is running or any of several others,
if pidof x $PMS > /dev/null ||
	( test "$XUSER" != "" && pidof dcopserver > /dev/null && test -x /usr/bin/dcop && /usr/bin/dcop --user $XUSER kded kded loadedModules | grep -q klaptopdaemon) ||
	( test "$XUSER" != "" && test -x /usr/bin/qdbus && test -r /proc/$(pidof kded4)/environ && su - $XUSER -c "eval $(echo -n 'export '; cat /proc/$(pidof kded4)/environ |tr '\0' '\n'|grep DBUS_SESSION_BUS_ADDRESS); qdbus org.kde.kded" | grep -q powerdevil) ; then
	# Get out as the power manager that is running will take care of things.
    exit
fi

# No power managment system appears to be running.  Just initiate a plain 
# shutdown.
/sbin/pm-suspend

