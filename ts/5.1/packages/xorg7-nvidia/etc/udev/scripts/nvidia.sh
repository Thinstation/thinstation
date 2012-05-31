#! /bin/sh

NVGLVER=`echo /lib/nvidia/libGL.so.* | cut -d. -f3-4`

rm -f /lib/libGL.so.1
ln -s nvidia/libGL.so.$NVGLVER /lib/libGL.so.1
rm -f /lib/xorg/modules/extensions/libglx.so
ln -s libglx.so.$NVGLVER /lib/xorg/modules/extensions/libglx.so

echo "package=\"nvidia-settings\"; needs=\"x11\"; title=\"NVIDIA Display Settings\"; command=\"/bin/nvidia-settings\"" > /lib/menu/nvidia

exit 0
