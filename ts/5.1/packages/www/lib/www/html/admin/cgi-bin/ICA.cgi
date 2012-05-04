#! /bin/sh
#----------------------------------------------------------------------
#      ___       ___ ___   P X E S   Universal  Linux  Thin  Client
#     /__/\\_// /__ /__    Copyright(C) 2003 by Diego Torres Milano
#    /    // \\/__  __/    All rights reserved.  http://pxes.sf.net
#
# Author: Diego Torres Milano <diego@in3.com.ar>
# $Id: bootmsg.cgi,v 1.2 2003/10/07 03:26:14 diego Exp $
#----------------------------------------------------------------------

. /etc/thinstation.env
. $TS_GLOBAL

header

echo '<pre>'

B=/root/appsrv.ini
C=/root/wfclient.ini
[ -f $B ] && cat $B || echo "ERROR: $B not found"
[ -f $C ] && cat $C || echo "ERROR: $C not found"

echo '</pre>'

trailer
