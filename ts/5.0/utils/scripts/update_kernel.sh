#!/bin/sh

VERSION=`cat ../KERNEL_VERSION`
if [ ! -z "$1" ] ; then VERSION=$1 ; fi

SOURCE_PATH=`cat ../SOURCE_PATH`
MODULE_PATH=$SOURCE_PATH/lib/modules
FIRMWARE_PATH=$SOURCE_PATH/lib/firmware
KERNEL_PATH=$SOURCE_PATH/boot
DEST_PATH=../../kernel

# Copy over the kernel & setup symlinks
cp $KERNEL_PATH/vmlinuz-$VERSION $DEST_PATH/.
cp $KERNEL_PATH/System.map-$VERSION $DEST_PATH/.
cp $KERNEL_PATH/config-$VERSION $DEST_PATH/.

# Setup the new modules
if [ -e $DEST_PATH/$VERSION ] ; then rm $DEST_PATH/$VERSION ; fi
if [ -e $DEST_PATH/modules-$VERSION ] ; then rm -Rf $DEST_PATH/modules-$VERSION ; fi
mkdir $DEST_PATH/modules-$VERSION
cp -a $MODULE_PATH/$VERSION/* $DEST_PATH/modules-$VERSION/.
ln -s modules-$VERSION $DEST_PATH/$VERSION

# Setup the new firmware
if [ -e $DEST_PATH/firmware-$VERSION ] ; then rm -Rf $DEST_PATH/firmware-$VERSION ; fi
mkdir $DEST_PATH/firmware-$VERSION
cp -a $FIRMWARE_PATH/* $DEST_PATH/firmware-$VERSION/.

# Remove unneeded links
rm $DEST_PATH/modules-$VERSION/build
rm $DEST_PATH/modules-$VERSION/source
