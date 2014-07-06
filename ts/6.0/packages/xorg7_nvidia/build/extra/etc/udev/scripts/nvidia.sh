#! /bin/sh

NVGLVER=`find /lib -name libGL.so.\*.\* | cut -d. -f3-`

rm -f /lib/libGL.so.1
ln -s libGL.so.$NVGLVER /lib/libGL.so.1

rm -f /lib/xorg/modules/extensions/libglx.so
ln -s libglx.so.$NVGLVER /lib/xorg/modules/extensions/libglx.so

cat <<EOF > /etc/X11/xorg.conf.d/20-nvidia.conf
Section "Device"
  Identifier	"nvidia"
  Driver	"nvidia"
EndSection
EOF

echo "package=\"nvidia-settings\"; needs=\"x11\"; title=\"NVIDIA Display Settings\"; command=\"/bin/nvidia-settings\"; menu=\"Multimedia\"; nodesktop=\"true\"" > /lib/menu/nvidia

exit 0
