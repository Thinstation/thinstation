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
	if mountpoint $1 ; then
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
disk_size=`blockdev --getsz $disk`
for lv in `systemctl status | grep -o 'lvm-activate-[^ ]*\.service'`; do
	systemctl stop $lv
done
dmsetup remove_all
dd if=/dev/zero of=$disk bs=1M count=2
dd if=/dev/zero of=$disk bs=512 count=32 seek=$(($disk_size - 32))
read_pt

# Creates Boot partition
parted -s $disk mklabel msdos
parted -s $disk mkpart primary fat32 "1MiB 4GiB" 1>/dev/null
parted -s $disk set 1 boot on

# Create swap partition
parted -s $disk mkpart primary linux-swap "4GiB 8GiB"

# Creates all additional partitions depending if install is Dev or not
if is_enabled $INSTALLER_DEV; then
	parted -s $disk mkpart primary "8GiB 100%"
	pvcreate -ff -y ${disk}${p}3
	vgcreate devstation_vg ${disk}${p}3
	lvcreate -y -n prstnt_lv -L 64MiB devstation_vg
	lvcreate -y -n root_lv -L 1GiB devstation_vg
	lvcreate -y -n home_lv -L 4GiB devstation_vg
	lvcreate -y -n log_lv -L 1GiB devstation_vg
	lvcreate -y -n tsdev_lv -l 100%FREE devstation_vg
else
	parted -s $disk mkpart primary ext4 "8GiB 100%"
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

#Create swap FileSystem
mkswap -f -L swap ${disk}${p}2

# Creates all additional FileSystems depending if install is Dev or not
if is_enabled $INSTALLER_DEV; then
	mkfs.ext4 -L prstnt -F /dev/devstation_vg/prstnt_lv
	mkfs.ext4 -L root -F /dev/devstation_vg/root_lv
	mkfs.ext4 -L home -F /dev/devstation_vg/home_lv
	mkfs.ext4 -L log -F /dev/devstation_vg/log_lv
	mkfs.ext4 -L tsdev -F /dev/devstation_vg/tsdev_lv
else
	mkfs.ext4 -L home -F ${disk}${p}3
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
mkdir -p $bootdir/boot/grub2
mkdir -p $bootdir/EFI/BOOT
mkdir -p $bootdir/EFI/Microsoft/Boot
mkdir -p $bootdir/EFI/fedora

cp -a $sourceboot/EFI/BOOT/* $bootdir/EFI/BOOT/.
rm $bootdir/EFI/BOOT/CDBOOT.EFI
cp -a $bootdir/EFI/BOOT/* $bootdir/EFI/Microsoft/Boot/.
mv $bootdir/EFI/Microsoft/Boot/bootx64.efi $bootdir/EFI/Microsoft/Boot/bootmgfw.efi
cp -a $sourceboot/EFI/fedora/* $bootdir/EFI/fedora/.

cp -a $sourceboot/boot/grub2/devstation/* $bootdir/boot/grub2/.
cp -a $bootdir/boot/grub2/grub.cfg $bootdir/EFI/fedora/.

dd if=$sourceboot/boot/grub2/boot.img of=$disk bs=446 count=1
dd if=$sourceboot/boot/grub2/core.img of=$disk bs=512 seek=1


cd $bootdir/boot
echo "machine_id=`dbus-uuidgen`" > machine-id

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

mkdir /tmp-log/journal

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
