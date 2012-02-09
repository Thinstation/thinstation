SOURCE_PATH=`cat ../SOURCE_PATH`
DRIVER_PATH=$SOURCE_PATH/`cat ../X_PATH`/programs/Xserver/hw/xfree86/drivers
LIB_PATH=$SOURCE_PATH/`cat ../X_PATH`/programs/Xserver
END_PATH=/lib/X11/modules/drivers
LIB_END_PATH=/lib/X11/modules
cd ../../packages

cp $DRIVER_PATH/apm/apm_drv.so xorg6-apm$END_PATH
cp $DRIVER_PATH/ark/ark_drv.so xorg6-ark$END_PATH
cp $DRIVER_PATH/ati/ati_drv.so xorg6-ati$END_PATH
cp $DRIVER_PATH/ati/atimisc_drv.so xorg6-ati$END_PATH
cp $DRIVER_PATH/chips/chips_drv.so xorg6-chips$END_PATH
cp $DRIVER_PATH/cirrus/cirrus_drv.so xorg6-cirrus$END_PATH
cp $DRIVER_PATH/cirrus/cirrus_laguna.so xorg6-cirrus$END_PATH
cp $DRIVER_PATH/cirrus/cirrus_alpine.so xorg6-cirrus$END_PATH
cp $DRIVER_PATH/cyrix/cyrix_drv.so xorg6-cyrix$END_PATH
cp $DRIVER_PATH/glint/glint_drv.so xorg6-glint$END_PATH
cp $DRIVER_PATH/i128/i128_drv.so xorg6-i128$END_PATH
cp $DRIVER_PATH/i740/i740_drv.so xorg6-i740$END_PATH
cp $DRIVER_PATH/i810/i810_drv.so xorg6-i810$END_PATH
cp $LIB_PATH/miext/shadow/libshadow.so xorg6-i810$LIB_END_PATH
cp $DRIVER_PATH/../shadowfb/libshadowfb.so xorg6-i810$LIB_END_PATH
cp $DRIVER_PATH/mga/mga_drv.so xorg6-mga$END_PATH
cp $DRIVER_PATH/neomagic/neomagic_drv.so xorg6-neomagic$END_PATH
cp $DRIVER_PATH/nv/nv_drv.so xorg6-nv$END_PATH
cp $DRIVER_PATH/nv/riva128.so xorg6-nv$END_PATH
cp $DRIVER_PATH/ati/r128_drv.so xorg6-r128$END_PATH
cp $DRIVER_PATH/ati/radeon_drv.so xorg6-radeon$END_PATH
cp $DRIVER_PATH/rendition/rendition_drv.so xorg6-rendition$END_PATH
cp $DRIVER_PATH/s3/s3_drv.so xorg6-s3$END_PATH
cp $DRIVER_PATH/s3virge/s3virge_drv.so xorg6-s3virge$END_PATH
cp $DRIVER_PATH/savage/savage_drv.so xorg6-savage$END_PATH
cp $DRIVER_PATH/siliconmotion/siliconmotion_drv.so xorg6-siliconmotion$END_PATH
cp $DRIVER_PATH/sis/sis_drv.so xorg6-sis$END_PATH
cp $DRIVER_PATH/tdfx/tdfx_drv.so xorg6-tdfx$END_PATH
cp $DRIVER_PATH/tga/tga_drv.so xorg6-tga$END_PATH
cp $DRIVER_PATH/trident/trident_drv.so xorg6-trident$END_PATH
cp $DRIVER_PATH/tseng/tseng_drv.so xorg6-tseng$END_PATH
cp $DRIVER_PATH/vesa/vesa_drv.so xorg6-vesa$END_PATH
cp $LIB_PATH/miext/shadow/libshadow.so xorg6-vesa$LIB_END_PATH
cp $DRIVER_PATH/vga/vga_drv.so xorg6-vga$END_PATH
cp $LIB_PATH/hw/xfree86/xf4bpp/libxf4bpp.so xorg6-vga$LIB_END_PATH
cp $DRIVER_PATH/vmware/vmware_drv.so xorg6-vmware$END_PATH
cp $LIB_PATH/miext/shadow/libshadow.so xorg6-vmware$LIB_END_PATH
cp $DRIVER_PATH/../shadowfb/libshadowfb.so xorg6-vmware$LIB_END_PATH
cp $DRIVER_PATH/via/via_drv.so xorg6-via$END_PATH
cp $DRIVER_PATH/nsc/nsc_drv.so xorg6-nsc$END_PATH

for filename in `ls | grep xorg6-`
do
	strip --strip-unneeded -R .note -R .comment $filename$END_PATH/*.so
	echo $filename
done

