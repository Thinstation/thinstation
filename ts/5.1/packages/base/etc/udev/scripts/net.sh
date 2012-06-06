#!/bin/sh

. $TS_GLOBAL
if [ -z "$INTERFACE" ];then
	echo_log "No interface specified"
	exit
fi
if echo $INTERFACE |grep -e tun[0-9] ; then
	echo_log "Tunnel Interface - Defering to master"
	exit
fi
. /etc/thinstation.global
if [ -e /var/log/net/$INTERFACE ]; then
	. /var/log/net/$INTERFACE
	echo_log "Read a config file for $INTERFACE"
fi
if [ -e /var/run/udhcpc-$INTERFACE.pid ]; then
	echo_log "Found a previous udhcpc session for $INTERFACE"
        UPID=`cat /var/run/udhcpc-$INTERFACE.pid`
        kill -SIGUSR2 $UPID
       	kill -SIGHUP $UPID
	rm /var/run/udhcpc-$INTERFACE.pid
	if [ "$ACTION" == "remove" ]; then
		echo_log "Removal request for $INTERFACE"
		ifconfig $INTERFACE down
		exit
	fi
fi

NET_USE="`make_caps $NET_USE`"

echo_dev()
{
	if [ -z "$DEVTYPE" ]; then
		DEVTYPE=lan
	fi
	echo_log "Set DEVTYPE for $INTERFACE to $DEVTYPE"
}

if [ "$DEVTYPE" == "wlan" ]; then
	if [ "$NET_USE" != "BOTH" ] && [ "$NET_USE" != "WLAN" ]; then
		echo_log "The NET_USE value does not allow use of $INTERFACE"
		exit
	fi
	if [ "$WIRELESS_ESSID" == "" ]; then
		echo_log "No ESSID specified"
		exit
	fi
	if [ -n "$WIRELESS_WPAKEY" ]; then
		if [ ! -x /bin/wpa_supplicant ]; then
			echo_log "Could not find wpa_supplicant"
			exit
		fi
		if [ "$WIRELESS_DRIVER" == "" ]; then
			echo_log "No Wireless Driver Specified"
			exit
		fi
	fi
fi
if [ "$DEVTYPE" != "wlan" ] && [ "$NET_USE" != "BOTH" ]; then
	if [ "$NET_USE" != "LAN" ] && [ "$INTERFACE" != "lo" ]; then
	echo_log "The NET_USE value does not allow use of $INTERFACE"
	exit
	fi
fi

ifconfig $INTERFACE up

if [ "$INTERFACE" = "lo" ] ; then
ifconfig lo 127.0.0.1
route add -net 127.0.0.0 netmask 255.0.0.0 dev lo
DEVTYPE=lo
echo "DEVTYPE=lo" > /var/log/net/$INTERFACE
echo "CLIENT_NAME=localhost" >> /var/log/net/$INTERFACE
echo "CLIENT_IP=127.0.0.1" >> /var/log/net/$INTERFACE
echo "NETMASK=255.0.0.0" >>/var/log/net/$INTERFACE
echo "NET${IFINDEX}=$INTERFACE" >> $TS_RUNTIME
#echo_dev
exit
fi
#echo_dev

if [ "$DEVTYPE" == "wlan" ]; then
	if [ -n "$WIRELESS_WPAKEY" ];  then
		echo "WIRELESS_WPAKEY=$WIRELESS_WPAKEY" >> /var/log/net/$INTERFACE
		wpa_passphrase "$WIRELESS_ESSID" "$WIRELESS_WPAKEY" >> /etc/wpa_supplicant.conf.tmp
		awk '{print $0;if($0=="network={"){print "\teap=TTLS PEAP TLS"}}' < /etc/wpa_supplicant.conf.tmp > /etc/wpa_supplicant.conf.tmp2
		awk '{print $0;if($0=="network={"){print "\tscan_ssid=1"}}' < /etc/wpa_supplicant.conf.tmp2 > /etc/wpa_supplicant.conf.tmp3
		awk '{print $0;if($0=="network={"){print "\tkey_mgmt=WPA-EAP WPA-PSK NONE"}}' < /etc/wpa_supplicant.conf.tmp3 > /etc/wpa_supplicant.conf.tmp4
		awk '{print $0;if($0=="network={"){print "\tpairwise=CCMP TKIP"}}' < /etc/wpa_supplicant.conf.tmp4 > /etc/wpa_supplicant.conf
		rm -f /etc/wpa_supplicant.conf.tmp*
		wpa_supplicant -B -D`make_lower $WIRELESS_DRIVER` -i$INTERFACE -c/etc/wpa_supplicant.conf
		sleep 1
	fi
	# This appears to be a Wireless device (USB/PCI/PCMCIA). Set specific
        # options. (Code ripped from pcmcia-cs wireless script)
        # Mode need to be first : some settings apply only in a specific mode !
        if [ -n "$WIRELESS_MODE" ] ; then
                iwconfig $INTERFACE mode $WIRELESS_MODE
        fi
	# This is a bit hackish, but should do the job right...
        if [ ! -n "$WIRELESS_NICKNAME" ] ; then
                WIRELESS_NICKNAME=$CLIENT_NAME
        fi
	if [ -n "$WIRELESS_ESSID" -o -n "$WIRELESS_MODE" ] ; then
		echo "WIRELESS_ESSID=$WIRELESS_ESSID" >> /var/log/net/$INTERFACE
                iwconfig $INTERFACE nick "$WIRELESS_NICKNAME" >/dev/null 2>&1
        fi
	# Regular stuff...
        if [ -n "$WIRELESS_NWID" ] ; then
                iwconfig $INTERFACE nwid $WIRELESS_NWID
        fi
	if [ -n "$WIRELESS_FREQ" ] ; then
                iwconfig $INTERFACE freq $WIRELESS_FREQ
        elif [ -n "$WIRELESS_CHANNEL" ] ; then
                iwconfig $INTERFACE channel $WIRELESS_CHANNEL
        fi
	if [ -n "$WIRELESS_SENS" ] ; then
                iwconfig $INTERFACE sens $WIRELESS_SENS
        fi
	if [ -n "$WIRELESS_RATE" ] ; then
                iwconfig $INTERFACE rate $WIRELESS_RATE
        fi
	if [ -n "$WIRELESS_KEY" ] && [ ! -n "$WIRELESS_WPAKEY" ] ; then
		echo "WIRELESS_KEY=$WIRELESS_KEY" >> /var/log/net/$INTERFACE
                iwconfig $INTERFACE key $WIRELESS_KEY
        fi
	if [ -n "$WIRELESS_RTS" ] ; then
                iwconfig $INTERFACE rts $WIRELESS_RTS
        fi
	if [ -n "$WIRELESS_FRAG" ] ; then
                iwconfig $INTERFACE frag $WIRELESS_FRAG
        fi
	# More specific parameters
        if [ -n "$WIRELESS_IWCONFIG" ] ; then
                iwconfig $INTERFACE $WIRELESS_IWCONFIG
	fi
	if [ -n "$WIRELESS_IWSPY" ] ; then
                iwspy $INTERFACE $WIRELESS_IWSPY
        fi
	if [ -n "$WIRELESS_IWPRIV" ] ; then
                iwpriv $INTERFACE $WIRELESS_IWPRIV
        fi
	# ESSID need to be last : most device re-perform the scanning/discovery
        # when this is set, and things like encryption keys are better be
        # defined if we want to discover the right set of APs/nodes.
        if [ -n "$WIRELESS_ESSID" ] && [ ! -n "$WIRELESS_WPAKEY" ] ; then
                iwconfig $INTERFACE essid "$WIRELESS_ESSID"
        fi
fi

if [ "$DEVTYPE" != "wlan" ] ;then
	LINKTOLERANCECOUNTER=0
	while [ $LINKTOLERANCECOUNTER -lt $NET_LINKWAIT ]; do
		link="`cat /sys/class/net/$INTERFACE/carrier`"
                echo ":${SUBSYSTEM}:${ACTION}:${DEVTYPE}:${INTERFACE}:link status ${link}:${ID_BUS}:" >>/var/log/udev-lanlink
		if [ "$link" == "1" ]; then
			LINKTOLERANCECOUNTER=$NET_LINKWAIT
                else
			let LINKTOLERANCECOUNTER=LINKTOLERANCECOUNTER+1
        	        sleep 1
		fi
         done
	if [ "$link" != "1" ]; then
		echo_log "No Cable for $INTERFACE"
		exit
	fi
fi

. /etc/thinstation.global


if is_enabled $NET_USE_DHCP ; then
	NET_USE_DHCP=BOTH
fi

CLIENT_MAC=`cat /sys/class/net/$INTERFACE/address | sed 's/://g'`
if [ -n "`echo $NET_HOSTNAME | sed -n '/\*/p'`" ]; then
	CLIENT_NAME=`echo $NET_HOSTNAME | sed "s/\*/$CLIENT_MAC/"`
else
	CLIENT_NAME=$NET_HOSTNAME
fi
if [ -e /etc/thinstation.hosts ] ; then
	clientname=`cat /etc/thinstation.hosts | grep -i $CLIENT_MAC | cut -d" " -f 1`
		if [ -n "$clientname" ] ; then
			CLIENT_NAME=$clientname
		fi
fi
echo "DEVTYPE=$DEVTYPE" > /var/log/net/$INTERFACE
echo "CLIENT_NAME=$CLIENT_NAME" >> /var/log/net/$INTERFACE
echo "CLIENT_MAC=$CLIENT_MAC" >> /var/log/net/$INTERFACE
echo "NET_USE=$NET_USE" >> /var/log/net/$INTERFACE
echo "NET_DHCP_TIMEOUT=$NET_DHCP_TIMEOUT" >> /var/log/net/$INTERFACE
echo "CLIENT_IP=$NET_IP_ADDRESS" >> /var/log/net/$INTERFACE

manual_config()
{
	echo "nameserver $NET_DNS1" >> /etc/resolv.conf
	echo "nameserver $NET_DNS2" >> /etc/resolv.conf
	echo "search $NET_DNS_SEARCH" >> /etc/resolv.conf
	if ifconfig $INTERFACE $NET_IP_ADDRESS netmask $NET_MASK ; then
		NETWORKUP=TRUE
		NET${IFINDEX}=$INTERFACE
		echo "NETWORKUP=TRUE" >> /var/log/net/$INTERFACE
		echo "NET${IFINDEX}=$INTERFACE" >> $TS_RUNTIME
		route add default gw $NET_GATEWAY
	fi
}

if is_disabled $NET_USE_DHCP ; then
	echo_log "Booting with manually configured network..." $debug
	manual_config
else
	udhcpc -R -b -A $NET_DHCP_TIMEOUT -H $CLIENT_NAME -t 20 -T 3 -i $INTERFACE -C -s /etc/udev/scripts/lease_dhcp -p /var/run/udhcpc-$INTERFACE.pid
fi

# Kernel Network setting
echo 0 > /proc/sys/net/ipv4/tcp_retrans_collapse
