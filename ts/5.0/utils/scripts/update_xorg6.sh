SOURCE_PATH=`cat ../SOURCE_PATH`
X_PATH=$SOURCE_PATH/`cat ../X_PATH`
END_PATH=../../packages

PACKAGE=/lib
cp $X_PATH/exports/lib/libICE.so.6.4 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libSM.so.6.0 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libX11.so.6.2 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXaw.so.6.1 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libGL.so.1.2 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXext.so.6.4 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXmu.so.6.2 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXmuu.so.1.0 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXau.so.6.0 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXdmcp.so.6.0 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXt.so.6.0 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXtst.so.6.1 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXpm.so.4.11 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXp.so.6.2 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libfreetype.so.6.3.7 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXft.so.2.1.2 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libexpat.so.0.4.0 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libfontconfig.so.1.0.4 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libfontenc.so.1.0 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXinerama.so.1.0 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXrandr.so.2.0 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXrender.so.1.2.2 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXRes.so.1.0 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXxf86vm.so.1.0 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXxf86misc.so.1.1 $END_PATH$PACKAGE
cp $X_PATH/exports/lib/libXi.so.6.0 $END_PATH$PACKAGE
PACKAGE=/xorg6/lib/X11/modules
cp $X_PATH/exports/lib/modules/libmfb.so $END_PATH$PACKAGE
cp $X_PATH/exports/lib/modules/librac.so $END_PATH$PACKAGE
cp $X_PATH/exports/lib/modules/libddc.so $END_PATH$PACKAGE
cp $X_PATH/exports/lib/modules/libfb.so $END_PATH$PACKAGE
cp $X_PATH/exports/lib/modules/libi2c.so $END_PATH$PACKAGE
cp $X_PATH/exports/lib/modules/libpcidata.so $END_PATH$PACKAGE
cp $X_PATH/exports/lib/modules/libramdac.so $END_PATH$PACKAGE
strip --strip-unneeded $END_PATH$PACKAGE/libpcidata.so
cp $X_PATH/exports/lib/modules/libvgahw.so $END_PATH$PACKAGE
cp $X_PATH/exports/lib/modules/libxaa.so $END_PATH$PACKAGE
cp $X_PATH/exports/lib/modules/libvbe.so $END_PATH$PACKAGE
PACKAGE=/xorg6/lib/X11/modules/linux
cp $X_PATH/exports/lib/modules/linux/libint10.so $END_PATH$PACKAGE
PACKAGE=/xorg6/lib/X11/modules/input
cp $X_PATH/exports/lib/modules/input/mouse_drv.so $END_PATH$PACKAGE
cp $X_PATH/exports/lib/modules/input/kbd_drv.so $END_PATH$PACKAGE
cp $X_PATH/exports/lib/modules/input/evdev_drv.so $END_PATH$PACKAGE
PACKAGE=/xorg6/lib/X11/modules/fonts
cp $X_PATH/exports/lib/modules/fonts/libbitmap.so $END_PATH$PACKAGE
PACKAGE=/xorg6/lib/X11/modules/extensions.tmp
cp $X_PATH/exports/lib/modules/extensions/libextmod.so $END_PATH$PACKAGE
cp $X_PATH/exports/lib/modules/extensions/libdbe.so $END_PATH$PACKAGE
PACKAGE=/xorg6/bin
cp $X_PATH/programs/xmodmap/xmodmap $END_PATH$PACKAGE
cp $X_PATH/programs/Xserver/Xorg $END_PATH$PACKAGE
cp $X_PATH/programs/xauth/xauth $END_PATH$PACKAGE
PACKAGE=/ica/bin
cp $X_PATH/programs/xset/xset $END_PATH$PACKAGE
PACKAGE=/xnest/bin
cp $X_PATH/programs/Xserver/Xnest $END_PATH$PACKAGE
PACKAGE=/xterm/bin
cp $X_PATH/programs/xterm/xterm $END_PATH$PACKAGE
PACKAGE=/fonts-type1/X11/fonts/Type1
cp $X_PATH/fonts/scaled/Type1/*.afm $END_PATH$PACKAGE
cp $X_PATH/fonts/scaled/Type1/*.pfa $END_PATH$PACKAGE
cp $X_PATH/fonts/scaled/Type1/fonts.* $END_PATH$PACKAGE

