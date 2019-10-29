#!/bin/bash

unset WIRELESS_REGDOM
. /etc/conf.d/wireless-regdom
[ -n "${WIRELESS_REGDOM}" ] && iw reg set ${WIRELESS_REGDOM}
