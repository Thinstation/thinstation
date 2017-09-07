#!/bin/sh
. /etc/thinstation.global

last_config()
{
	if [ -e /var/log/net/$INTERFACE ]; then
		. /var/log/net/$INTERFACE
	fi
}

dev_type()
{
	if echo $INTERFACE |grep -e tun[0-9] ; then
		echo_log "Tunnel Interface - Defering to master"
		DEVTYPE=tunnel
		exit
	fi
	if [ -z "$DEVTYPE" ]; then
		if [ "$INTERFACE" = "lo" ] ; then
			DEVTYPE=lo
		elif [ -e /sys/$DEVPATH/wireless ]; then
			DEVTYPE=wlan
		else
			DEVTYPE=eth
		fi
	fi
}

net_use()
{
	NET_USE="`make_caps $NET_USE`"
}

client_name()
{
	CLIENT_MAC=`cat /sys/class/net/$INTERFACE/address | sed 's/://g'`
	if [ -n "`echo \"$NET_HOSTNAME\" | sed -n '/\*/p'`" ]; then
		CLIENT_NAME=`echo "$NET_HOSTNAME" | sed "s/\*/$CLIENT_MAC/"`
	else
		CLIENT_NAME=$NET_HOSTNAME
	fi
	if [ -e /etc/thinstation.hosts ] ; then
		clientname=`cat /etc/thinstation.hosts | grep -i $CLIENT_MAC | cut -d" " -f 1`
		if [ -n "$clientname" ] ; then
			CLIENT_NAME=$clientname
		fi
	fi
}

log_interface()
{
	echo "DEVTYPE=$DEVTYPE"				> /var/log/net/$INTERFACE
	echo "CLIENT_NAME=$CLIENT_NAME"			>> /var/log/net/$INTERFACE
	echo "CLIENT_MAC=$CLIENT_MAC"			>> /var/log/net/$INTERFACE
	echo "CLIENT_IP=$ip"				>> /var/log/net/$INTERFACE
	echo "CLIENT_GATEWAY=$gw"			>> /var/log/net/$INTERFACE
	echo "SUBNET=$subnet"				>> /var/log/net/$INTERFACE
	echo "SERVER_IP=$DHCP4_TFTP_SERVER_NAME"	>> /var/log/net/$INTERFACE
	echo "NETWORKUP=$NETWORKUP"			>> /var/log/net/$INTERFACE
	echo "NETMASK_SIZE=$mask"			>> /var/log/net/$INTERFACE
	echo "SERVER_NAME=$saddr"			>> /var/log/net/$INTERFACE
	echo "NET_USE=$NET_USE"				>> /var/log/net/$INTERFACE
	echo "NET_DHCP_TIMEOUT=$NET_DHCP_TIMEOUT"	>> /var/log/net/$INTERFACE
}

_lo()
{
	echo "DEVTYPE=lo"		> /var/log/net/$INTERFACE
	echo "CLIENT_NAME=localhost"	>> /var/log/net/$INTERFACE
	echo "CLIENT_IP=127.0.0.1"	>> /var/log/net/$INTERFACE
	echo "NETMASK=255.0.0.0"	>> /var/log/net/$INTERFACE
}

main()
{
	last_config
	dev_type
	net_use
	client_name
	ifconfig $INTERFACE up
	case $DEVTYPE in
		lo)		_lo;;
		*)	log_interface;;
	esac
}
main
