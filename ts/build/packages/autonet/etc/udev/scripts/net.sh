#!/bin/sh
. /etc/thinstation.global

valid_interface()
{
	if [ -z "$INTERFACE" ];then
		echo_log "No interface specified"
		exit
	fi
}

last_config()
{
	if [ -e /var/log/net/$INTERFACE ]; then
		. /var/log/net/$INTERFACE
		echo_log "Read a config file for $INTERFACE"
	fi
}

release_dhcp()
{
	if [ -e /run/udhcpc-$INTERFACE.pid ]; then
		echo_log "Found a previous udhcpc session for $INTERFACE"
		UPID=`cat /run/udhcpc-$INTERFACE.pid`
		kill -SIGUSR2 $UPID
		kill -SIGHUP $UPID
		rm /run/udhcpc-$INTERFACE.pid
		if [ "$ACTION" == "remove" ]; then
			echo_log "Removal request for $INTERFACE"
			ifconfig $INTERFACE down
			exit
		fi
	fi
}

echo_dev()
{
	echo_log "Set DEVTYPE for $INTERFACE to $DEVTYPE"
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
		echo_dev
	fi
}

net_use()
{
	NET_USE="`make_caps $NET_USE`"
}

net_use_dhcp()
{
	if [ "$NET_USE_DHCP" == "BOTH" ]; then
		NET_USE_DHCP=true
	elif [ "$DEVTYPE" == "WLAN" ] && [ "$NET_USE_DHCP" == "WLAN" ]; then
		NET_USE_DHCP=true
	elif [ "$DEVTYPE" == "LAN" ] && [ "$NET_USE_DHCP" == "LAN" ]; then
		NET_USE_DHCP=true
	fi
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
	echo "DEVTYPE=$DEVTYPE" > /var/log/net/$INTERFACE
	echo "CLIENT_NAME=$CLIENT_NAME" >> /var/log/net/$INTERFACE
	echo "CLIENT_MAC=$CLIENT_MAC" >> /var/log/net/$INTERFACE
	echo "NET_USE=$NET_USE" >> /var/log/net/$INTERFACE
	echo "NET_DHCP_TIMEOUT=$NET_DHCP_TIMEOUT" >> /var/log/net/$INTERFACE
	echo "CLIENT_IP=$NET_IP_ADDRESS" >> /var/log/net/$INTERFACE
}

manual_config()
{
	echo "nameserver $NET_DNS1" > /etc/resolv.conf
	echo "nameserver $NET_DNS2" >> /etc/resolv.conf
	echo "search $NET_DNS_SEARCH" >> /etc/resolv.conf
	if ifconfig $INTERFACE $NET_IP_ADDRESS netmask $NET_MASK ; then
		NETWORKUP=TRUE
		echo "NETWORKUP=TRUE" >> /var/log/net/$INTERFACE
		echo "NET${IFINDEX}=$INTERFACE" >> $TS_RUNTIME
		route add default gw $NET_GATEWAY
	fi
}

supplicant_test()
{
        if [ -n "$WIRELESS_WPAKEY" ] || [ -n "$CUSTOM_SUPPLICANT_CONF" ] || is_enabled $WIRED_SUPPLICANT; then
                if [ -z "`which wpa_supplicant`" ]; then
                        echo_log "Could not find wpa_supplicant"
                        exit 1
                fi
        fi
}

_lo()
{
	ifconfig lo 127.0.0.1
	route add -net 127.0.0.0 netmask 255.0.0.0 dev lo
	echo "DEVTYPE=lo" > /var/log/net/$INTERFACE
	echo "CLIENT_NAME=localhost" >> /var/log/net/$INTERFACE
	echo "CLIENT_IP=127.0.0.1" >> /var/log/net/$INTERFACE
	echo "NETMASK=255.0.0.0" >>/var/log/net/$INTERFACE
	echo "NET${IFINDEX}=$INTERFACE" >> $TS_RUNTIME
	exit
}

_wlan()
{
	if [ "$NET_USE" != "BOTH" ] && [ "$NET_USE" != "WLAN" ]; then
		echo_log "The NET_USE value does not allow use of $INTERFACE"
		exit
	fi
	if [ -n "$CUSTOM_SUPPLICANT_CONF" ]; then
                wpa_supplicant -B -D `make_lower $WIRELESS_DRIVER` -i $INTERFACE -c $CUSTOM_SUPPLICANT_CONF
		return 0
	fi
	if [ "$WIRELESS_ESSID" == "" ]; then
		echo_log "No ESSID specified"
		exit
	fi
	if [ -n "$WIRELESS_WPAKEY" ];  then
		echo "WIRELESS_WPAKEY=$WIRELESS_WPAKEY" >> /var/log/net/$INTERFACE
		wpa_passphrase "$WIRELESS_ESSID" "$WIRELESS_WPAKEY" >> /etc/wpa_supplicant.conf.tmp
		awk '{print $0;if($0=="network={"){print "\teap=TTLS PEAP TLS"}}' < /etc/wpa_supplicant.conf.tmp > /etc/wpa_supplicant.conf.tmp2
		awk '{print $0;if($0=="network={"){print "\tscan_ssid=1"}}' < /etc/wpa_supplicant.conf.tmp2 > /etc/wpa_supplicant.conf.tmp3
		awk '{print $0;if($0=="network={"){print "\tkey_mgmt=WPA-EAP WPA-PSK NONE"}}' < /etc/wpa_supplicant.conf.tmp3 > /etc/wpa_supplicant.conf.tmp4
		awk '{print $0;if($0=="network={"){print "\tpairwise=CCMP TKIP"}}' < /etc/wpa_supplicant.conf.tmp4 > /etc/wpa_supplicant.conf
		rm -f /etc/wpa_supplicant.conf.tmp*
		wpa_supplicant -B -D `make_lower $WIRELESS_DRIVER` -i $INTERFACE -c /etc/wpa_supplicant.conf
		sleep 1
		return 0
	fi
	# WEP and UnEncrypted
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
	if [ -n "$WIRELESS_ESSID" ]; then
		iwconfig $INTERFACE essid "$WIRELESS_ESSID"
	fi
}

_eth()
{
	if [ "$NET_USE" != "LAN" ] && [ "$NET_USE" != "BOTH" ]; then
		echo_log "The NET_USE value does not allow use of $INTERFACE"
		exit
	fi
	LINKTOLERANCECOUNTER=0
	while [ $LINKTOLERANCECOUNTER -lt $NET_LINKWAIT ]; do
		link="`cat /sys/class/net/$INTERFACE/carrier`"
		if [ "$link" == "1" ]; then
			LINKTOLERANCECOUNTER=$NET_LINKWAIT
		else
			let LINKTOLERANCECOUNTER+=1
			sleep 1
		fi
	done
	if [ "$link" != "1" ]; then
		echo_log "No Cable for $INTERFACE"
		exit
	fi
	if is_enabled $WIRED_SUPPLICANT; then
	        if [ -n "$CUSTOM_SUPPLICANT_CONF" ]; then
        	        wpa_supplicant -B -D wired -i $INTERFACE -c $CUSTOM_SUPPLICANT_CONF
	                return 0
	        else
			cat <<EOF > /etc/wpa_supplicant.conf
ctrl_interface=/run/wpa_supplicant
ctrl_interface_group=0
eapol_version=2
ap_scan=0
network={
        key_mgmt=IEEE8021X
        eap=TTLS MD5
        identity="$RADIUS_ID"
        anonymous_identity="$RADIUS_ID"
        password="$RADIUS_PSK"
        phase1="auth=MD5"
        phase2="auth=PAP password=$RADIUS_PSK"
        eapol_flags=0
}
EOF
			wpa_supplicant -B -D wired -i $INTERFACE -c /etc/wpa_supplicant.conf
		fi
	fi
}

configure_ip()
{
	if is_disabled $NET_USE_DHCP ; then
		echo_log "Booting with manually configured network..." $debug
		manual_config
	else
		udhcpc -R -b -t $NET_DHCP_TIMEOUT -x hostname:$CLIENT_NAME -T 1 -i $INTERFACE -C -s /etc/udev/scripts/lease_dhcp -p /run/udhcpc-$INTERFACE.pid
	fi
}

kernel_settings()
{
	# Kernel Network setting
	echo 0 > /proc/sys/net/ipv4/tcp_retrans_collapse
}

main()
{
	valid_interface
	last_config
	release_dhcp
	dev_type
	net_use
	net_use_dhcp
	client_name
	ifconfig $INTERFACE up
	supplicant_test
	_$DEVTYPE
	log_interface
	configure_ip
	kernel_settings
}
main
