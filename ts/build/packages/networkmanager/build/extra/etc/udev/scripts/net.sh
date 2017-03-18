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
    # Quick fix by Marcus Eyre 2016-11-30 since the following parameters didn't work...
    # Keeping the old parameters as fall back since i'm not quite sure if those are valid in e.g.
    # BIOS mode instead of UEFI...

    
    infofile="/var/lib/NetworkManager/dhclient-*${INTERFACE}.lease"
    if [ -e ${infofile} ]; then
        logger --stderr --tag 'networkmanager net.sh' "we can extract ip-addresses, file exists ${infofile}"
        regexip='((1?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.){3}((1?[0-9]?[0-9]|2[0-4][0-9]|25[0-5]))'

        ip=$(grep -e 'fixed-address' /var/lib/NetworkManager/dhclient-*${INTERFACE}.lease | grep -oE $regexip)
        gw=$(grep -e 'routers' /var/lib/NetworkManager/dhclient-*${INTERFACE}.lease | grep -oE $regexip)
        subnet=$(grep -e 'subnet-mask' /var/lib/NetworkManager/dhclient-*${INTERFACE}.lease | grep -oE $regexip)
        dhcpserver=$(grep -e 'dhcp-server-identifier' /var/lib/NetworkManager/dhclient-*${INTERFACE}.lease | grep -oE $regexip)
        tftpserver=$(grep -e 'tftp-server-name' /var/lib/NetworkManager/dhclient-*${INTERFACE}.lease | grep -oE $regexip)

        #dhcpserver=$(grep -e 'dhcp-server-identifier' /var/lib/NetworkManager/dhclient-*${INTERFACE}.lease | sed 's/.*"\(.*\)"[^"]*$/\1/')
        #tftpserver=$(grep -e 'tftp-server-name' /var/lib/NetworkManager/dhclient-*${INTERFACE}.lease | sed 's/.*"\(.*\)"[^"]*$/\1/')
    else
        logger --stderr --tag 'networkmanager net.sh' "we can't extract the ip-addresses, file does not exist: ${infofile}"
        # Fall back mode to what it was originally...
        #ip was not set here, guess it came from somewhere else...
        #gw was not set here, guess it came from somewhere else...
        #subnet was not set here, guess it came from somewhere else...
        #dhcpserver was not set, I added this since it could be a good thing to have...
        tftpserver=$DHCP4_NEXT_SERVER
    fi



    # Check if we have set an alternative tftp server address in the thinstation.conf files...
    if [ -n "$NET_FILE_ALTERNATE" ] ; then
        SERVER_IP=$NET_FILE_ALTERNATE
    else
        SERVER_IP=$tftpserver
    fi

	echo "DEVTYPE=$DEVTYPE"				> /var/log/net/$INTERFACE
	echo "CLIENT_NAME=$CLIENT_NAME"			>> /var/log/net/$INTERFACE
	echo "CLIENT_MAC=$CLIENT_MAC"			>> /var/log/net/$INTERFACE
	echo "CLIENT_IP=$ip"				>> /var/log/net/$INTERFACE
	echo "CLIENT_GATEWAY=$gw"			>> /var/log/net/$INTERFACE
	echo "SUBNET=$subnet"				>> /var/log/net/$INTERFACE
	echo "DHCP_SERVER=$dhcpserver"	>> /var/log/net/$INTERFACE
	#echo "SERVER_IP=$DHCP4_TFTP_SERVER_NAME"	>> /var/log/net/$INTERFACE
	echo "SERVER_IP=$SERVER_IP"	>> /var/log/net/$INTERFACE
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
