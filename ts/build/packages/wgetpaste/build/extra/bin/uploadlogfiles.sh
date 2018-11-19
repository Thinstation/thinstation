#!/bin/bash
### upload some simple files for debugging to pastebin
### r.petry
### version 1
echo "starting" >/tmp/logfiles.date
date=`date`

echo "this file will upload some logfiles to pastebin. it will help to get support on the mailinglist" >>/tmp/logfiles.date
echo "### lsmod ###" >>/tmp/logfiles.date
lsmod >>/tmp/logfiles.date
echo "### ifconfig ###" >>/tmp/logfiles.date
ifconfig >>/tmp/logfiles.date
if [ -e /bin/lspci ]
then
echo "#### lspci ### " >>/tmp/logfiles.date
lspci >>/tmp/logfiles.date
fi
for name in "/etc/thinstation.network" "/var/log/*" "/var/log/net/*" "/etc/thinstation.defaults" "/var/log/applications/*"
do
#ls -l $name
echo "###### FILE ### $name #####" >>/tmp/logfiles.date
cat $name >>/tmp/logfiles.date
done
echo " #### packages ####" >>/tmp/logfiles.date
ls -l /var/packages >>/tmp/logfiles.date
