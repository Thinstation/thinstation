#!/bin/bash
. /etc/ashrc
. /etc/thinstation.global

set -x
bootdir=/tmp-boot
sourceboot=/boot
tempdir=`mktemp -d 2>/dev/null`
disk=$1

mounted()
{
	if [ "`cat /proc/mounts |grep -e $1 -c`" -ne "0" ] ; then
		return 0
	else
		return 1
	fi
}

un_mount()
{
	umount $bootdir >/dev/null 2>&1
	for i in `mount |grep -e /dev/devstation_vg |cut -d " " -f3` ; do
		while mounted $i; do
			sync
			umount -f $i
			sleep 1
		done
	done
        for i in `mount |grep -e $disk |cut -d " " -f3` ; do
                while mounted $i; do
                        sync
                        umount -f $i
                        sleep 1
                done
        done
	swapoff -a
	sleep 1
}

do_mounts()
{
	sleep 1
	while ! mounted $bootdir ; do
		mkdir -p $bootdir
		mount -t vfat ${disk}${p}1 $bootdir
		sleep 1
	done
	while ! mounted $sourceboot; do
		mkdir -p $sourceboot
		mount -a
	done
	if is_enabled $INSTALLER_DEV ; then
		while ! mounted /tmp-home ; do
			mkdir -p /tmp-home
			mount /dev/devstation_vg/home_lv /tmp-home
			sleep 1
		done
                while ! mounted /tmp-root ; do
                        mkdir -p /tmp-root
                        mount /dev/devstation_vg/root_lv /tmp-root
			chmod 0700 /tmp-root
                        sleep 1
                done
                while ! mounted /tmp-log ; do
                        mkdir -p /tmp-log
                        mount /dev/devstation_vg/log_lv /tmp-log
                        sleep 1
                done
                while ! mounted /tmp-prstnt ; do
                        mkdir -p /tmp-prstnt
                        mount /dev/devstation_vg/prstnt_lv /tmp-prstnt
			chmod 0700 /tmp-prstnt
                        sleep 1
                done
		while ! mounted /thinstation ; do
			mkdir -p /thinstation
			mount /dev/devstation_vg/tsdev_lv /thinstation
			sleep 1
		done
	else
		while ! mounted /tmp-home ; do
			mkdir -p /tmp-home
			mount -t ext4 ${disk}${p}3 /tmp-home
			sleep 1
		done
	fi
}

read_pt()
{
	sync
	blockdev --rereadpt $disk
	sleep 1
}

echo "Starting Partioner"
if echo $disk |grep -q -e nvme; then p=p; else unset p; fi
touch /tmp/nomount
un_mount
dd if=/dev/zero of=$disk bs=1M count=2
disk_size=`blockdev --getsz $disk`
dd if=/dev/zero of=$disk bs=512 count=32 seek=$(($disk_size - 32))
read_pt

# Creates Boot partition
parted -s $disk mklabel msdos
parted -s $disk mkpart primary fat32 "2048s 6293503s" 1>/dev/null
parted -s $disk set 1 boot on

# Creates all needed partitions depending if install is Dev or not
if is_enabled $INSTALLER_DEV; then
	parted -s $disk mkpart primary "6293504s -1"
	pvcreate ${disk}${p}2
	vgcreate devstation_vg ${disk}${p}2
	lvcreate -n prstnt_lv -L 64M devstation_vg
	lvcreate -n root_lv -L 1G devstation_vg
	lvcreate -n swap_lv -L 4G devstation_vg
	lvcreate -n home_lv -L 4G devstation_vg
	lvcreate -n log_lv -L 1G devstation_vg
	lvcreate -n tsdev_lv -l 100%FREE devstation_vg
else
	parted -s $disk mkpart primary linux-swap "6293504s 11g"
	parted -s $disk mkpart primary ext4 "11g -0"
fi

read_pt
un_mount
sleep 1
read_pt
sleep 1

# Creates all needed FileSystems
echo "Making filesystems"
mkfs.vfat -n boot -F 32 -R 32 ${disk}${p}1 || mkfs.vfat -n boot -F -F 32 -R 32 ${disk}${p}1 # Create /boot FileSystem
sleep 1

if is_enabled $INSTALLER_DEV; then
	mkfs.ext4 -L prstnt -F /dev/devstation_vg/prstnt_lv
	mkfs.ext4 -L root -F /dev/devstation_vg/root_lv
	mkfs.ext4 -L home -F /dev/devstation_vg/home_lv
	mkfs.ext4 -L log -F /dev/devstation_vg/log_lv
	mkfs.ext4 -L tsdev -F /dev/devstation_vg/tsdev_lv
        mkswap -f -L swap /dev/devstation_vg/swap_lv
else
	mkswap -f -L swap ${disk}${p}2 #Creates swap FileSystem
	sleep 1
	mkfs.ext4 -L home -F ${disk}${p}3 #Creates /home FileSystem
fi

read_pt
un_mount


# Remounts all partitions
echo "Remounting"
rm /tmp/nomount
read_pt
do_mounts
sleep 1

# Add grub bootloader
mkdir -p $bootdir/boot/grub
mkdir -p $bootdir/EFI/boot
mkdir -p $bootdir/EFI/Microsoft/Boot

cp -a $sourceboot/EFI/boot/* $bootdir/EFI/boot/.
rm $bootdir/EFI/boot/boot.efi
cp -a $bootdir/EFI/boot/* $bootdir/EFI/Microsoft/Boot/.
mv $bootdir/EFI/Microsoft/Boot/bootx64.efi $bootdir/EFI/Microsoft/Boot/bootmgfw.efi

cp -a $sourceboot/boot/grub/devstation/* $bootdir/boot/grub/.

dd if=$sourceboot/boot/grub/boot.img of=$disk bs=446 count=1
dd if=$sourceboot/boot/grub/core.img of=$disk bs=512 seek=1


cd $bootdir/boot

if is_enabled $INSTALLER_DEV || is_enabled $INSTALLER_PROXY_CHECK ; then
	# Setup proxy for wget and git
	proxy-setup
	. /tmp/.proxy
fi

# Install a default boot and backup-boot image into the boot partition
if [ -e $sourceboot/$INSTALLER_ARCHIVE_NAME ]; then
	tar -xvf $sourceboot/$INSTALLER_ARCHIVE_NAME
else
	echo "Downloading Image"
	if ! wget -t 3 -T 30 "$INSTALLER_WEB_ADDRESS/$INSTALLER_ARCHIVE_NAME"; then
		exit 2
	fi
	tar -xvf $INSTALLER_ARCHIVE_NAME
	rm $INSTALLER_ARCHIVE_NAME
fi

cp initrd initrd-backup
cp vmlinuz vmlinuz-backup
cp lib.update lib.squash-backup

if is_enabled $INSTALLER_DEV; then
	cd /thinstation
	rm -rf *

	echo "Gitting thinstation repo"
	COUNTER=3
	while [ ! -e /thinstation/setup-chroot ] && [ "$COUNTER" -gt "0" ]; do
		if [ "$COUNTER" -lt "3" ]; then
			echo "Something went wrong with the clone, retying."
		fi
		git clone --depth 1 https://github.com/Thinstation/thinstation.git -b $TS_VERSION-Stable /thinstation
		let COUNTER-=1
	done

	./setup-chroot -i -a
fi
