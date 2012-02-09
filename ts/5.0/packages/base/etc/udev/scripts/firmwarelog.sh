#!/bin/sh

if [ "`echo $@ |cut -d '.' -f1 |grep -c -e '/'`" -gt "0" ]; then
	echo "firmware `echo $@ |cut -d '.' -f1 |cut -d '/' -f2`" >> /var/log/firmware.log
else
	echo "firmware `echo $@ |cut -d '.' -f1`" >> /var/log/firmware.log
fi
exit 0
