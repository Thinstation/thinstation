#!/bin/sh

if [ -x /usr/bin/resolvconf ]; then
  /usr/bin/resolvconf -fd ${IFNAME}
else
  [ -e /etc/resolv.conf.backup.${IFNAME} ] && mv /etc/resolv.conf.backup.${IFNAME} /etc/resolv.conf
fi
