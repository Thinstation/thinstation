#!/bin/bash

tempdir=/tmp/apcollect
scandir=$tempdir/scan
apdir=$tempdir/ap
trap "rm -rf $tempdir ; exit" SIGTERM

if [ ! -d $apdir ]; then
	mkdir -p $apdir
fi

while true; do
find $apdir -type f -mmin +1 -delete
	if [ ! -d $scandir ]; then
		mkdir -p $scandir
	else rm $scandir/*
	fi
	index=""
	iwlist $1 scan 2>/dev/null |grep -v "Unknown" |grep -v ";" |grep -v "Scan complete" |grep -v Frequency > $scandir/result
	if [ "`cat $scandir/result |grep -c -e Cell`" -gt "1" ]; then
		csplit -s -f $scandir/cell $scandir/result '/Cell/' '/Cell/' {*}
		rm $scandir/cell00
	else
		cp $scandir/result $scandir/cell01
	fi
        for i in `ls --color=never $scandir/cell*`; do
                unset ESSID ADDRESS ENCRYPTIONSTATE MODE GROUPCIPHER PAIRWISECIPHER WPAMODE WPA AUTHSUITE CHANNEL QUALITY
                ESSID=`cat $i |grep -e ESSID |cut -d ':' -f2`
                ADDRESS=`cat $i |grep -e Address |cut -d ":" -f2- |cut -d " " -f2 |sed 's/://g'`
                ENCRYPTIONSTATE=`cat $i |grep -e Encryption |cut -d ":" -f2`
                MODE=`cat $i |grep -e Mode |cut -d ":" -f2`
                GROUPCIPHER=`cat $i |grep -e "Group Cipher" |cut -d ":" -f2 |cut -d " " -f2- |head -n 1`
                if [ "$GROUPCIPHER" == "CCMP TKIP" ] || [ "$GROUPCIPHER" == "TKIP CCMP" ] ; then
                        GROUPCIPHER=Mixed
                fi
                PAIRWISECIPHER=`cat $i |grep -e "Pairwise Ciphers" |cut -d ":" -f2 |cut -d " " -f2- |head -n 1`
                if [ "$PAIRWISECIPHER" == "CCMP TKIP" ] || [ "$PAIRWISECIPHER" == "TKIP CCMP" ] ; then
                        PAIRWISECIPHER=Mixed
                fi
                if [ "$PAIRWISECIPHER" == "CCMP" ] || [ "$PAIRWISECIPHER" == "Mixed" ] ; then
                        WPAMODE=2
                elif [ "$PAIRWISECIPHER" == "TKIP" ] ; then
                        WPAMODE=1
                else
                        WPAMODE=""
                fi
                if [ ! -z "$WPAMODE" ]; then
                        WPA=1
                else
                        WPA=""
                fi
                AUTHSUITE=`cat $i |grep -e "Authentication Suites" |cut -d ":" -f2 |cut -d " " -f2- |head -n 1`
                CHANNEL=`cat $i |grep -e "Channel" |cut -d ":" -f2`
                QUALITY=`cat $i |grep -e "Quality" |cut -d "=" -f2 |cut -d / -f1`
                echo "$QUALITY " > $apdir/"$ESSID-$ADDRESS-$ENCRYPTIONSTATE-$MODE-$WPA-$WPAMODE-$GROUPCIPHER-$PAIRWISECIPHER-$AUTHSUITE-$CHANNEL"
	done
	sleep 1
done
