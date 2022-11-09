#! /bin/sh

rm /lib/libOpenGL.so.0
ln -s libOpenGL-nvidia		/lib/libOpenGL.so.0
rm /lib/libGLX.so.0
ln -s libGLX-nvidia		/lib/libGLX.so.0
rm /lib/libGLdispatch.so.0
ln -s libGLdispatch-nvidia	/lib/libGLdispatch.so.0
rm -f /lib/libGL.so.1
ln -s libGL-nvidia		/lib/libGL.so.1
rm -f /lib/libGLESv1_CM.so.1
ln -s libGLESv1_CM-nvida	/lib/libGLESv1_CM.so.1
rm -f /lib/libEGL.so.1
ln -s libEGL-nvidia		/lib/libEGL.so.1
rm -f /lib/libGLESv2.so.2
ln -s libGLESv2-nvidia		/lib/libGLESv2.so.2
#rm -f /lib/xorg/modules/extensions/libglx.so
#ln -s libglx.so-nvidia		/lib/xorg/modules/extensions/libglx.so

cat <<EOF > /etc/X11/xorg.conf.d/20-nvidia.conf
Section "Device"
  Identifier	"nvidia"
  Driver	"nvidia"
EndSection
EOF

echo "package=\"nvidia-settings\"; needs=\"x11\"; title=\"NVIDIA Display Settings\"; command=\"/bin/nvidia-settings\"; menu=\"Multimedia\"; nodesktop=\"true\"" > /lib/menu/nvidia

exit 0
