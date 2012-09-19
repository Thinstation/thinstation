#!/bin/sh

if [ -z "$INTERFACE" ];then
	echo_log "No interface specified"
	exit
fi
DTYPE=$DEVTYPE

. /etc/thinstation.global

if [ -e /var/log/net/$INTERFACE ]; then
	. /var/log/net/$INTERFACE
	echo_log "Read a config file for $INTERFACE"
fi

NET_USE="`make_caps $NET_USE`"

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
echo "NET_DEVICE=$INTERFACE" >> $TS_RUNTIME
exit
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
echo "DEVTYPE=$DTYPE" > /var/log/net/$INTERFACE
echo "CLIENT_NAME=$CLIENT_NAME" >> /var/log/net/$INTERFACE
echo "CLIENT_MAC=$CLIENT_MAC" >> /var/log/net/$INTERFACE
echo "NET_USE=$NET_USE" >> /var/log/net/$INTERFACE
echo "NET_DHCP_TIMEOUT=$NET_DHCP_TIMEOUT" >> /var/log/net/$INTERFACE
echo "NETWORKUP=FALSE" >> /var/log/net/$INTERFACE
echo "NET${IFINDEX}=$INTERFACE" >> $TS_RUNTIME

if [ `hostname` == "(none)" ]; then
  hostname $CLIENT_NAME
fi

# Kernel Network setting
echo 0 > /proc/sys/net/ipv4/tcp_retrans_collapse
