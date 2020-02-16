#!/bin/bash
. /etc/ashrc
. /etc/thinstation.global

set -x
bootdir=/boot/boot
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
	umount /boot >/dev/null 2>&1
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
	while ! mounted /boot ; do
		mount -t vfat ${disk}1 /boot
		sleep 1
	done
	if is_enabled $INSTALLER_DEV ; then
		while ! mounted /tmp-home ; do
			mount -t ext4 ${disk}2 /tmp-home
			sleep 1
		done
		while ! mounted /thinstation ; do
			mount -t ext4 ${disk}4 /thinstation
			sleep 1
		done
	else
		while ! mounted /tmp-home ; do
			mount -t ext4 ${disk}3 /tmp-home
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
touch /tmp/nomount
un_mount
dd if=/dev/zero of=$disk bs=1M count=2
read_pt

# Creates Boot partition
parted -s $disk mklabel msdos
parted -s $disk mkpart primary fat32 "2048s 4196351s" 1>/dev/null
parted -s $disk set 1 boot on

# Creates all need partition depending if install is Dev or not
if is_enabled $INSTALLER_DEV; then
	parted -s $disk mkpart primary ext4 "4196352s 8390655s"
	parted -s $disk mkpart primary linux-swap "8390656s 12584959s"
	parted -s $disk mkpart primary ext4 "12584960s -0"
else
	parted -s $disk mkpart primary linux-swap "4196352s 8390655s"
	parted -s $disk mkpart primary ext4 "12584960s -0"
fi

read_pt
un_mount
dd if=/install/bios/mbr.bin of=$disk bs=440b count=1
sleep 1
read_pt
sleep 1

# Creates all needed FileSystems
echo "Making filesystems"
mkfs.vfat -n boot -F 32 -R 32 ${disk}1 ||mkfs.vfat -n boot -F -F 32 -R 32 ${disk}1 # Create /boot FileSystem
sleep 1

if is_enabled $INSTALLER_DEV; then
	mkfs.ext4 -F -F ${disk}2 #Creates /home FileSystem
	sleep 1
	mkswap -f -L swap ${disk}3 #Creates swap FileSystem
	sleep 1
	mkfs.ext4 -F -F ${disk}4 #Creates /thinstation FileSystem
	sleep 1
else
	mkswap -f -L swap ${disk}2 #Creates swap FileSystem
	sleep 1
	mkfs.ext4 -F -F ${disk}3 #Creates /home FileSystem
fi

read_pt
un_mount

# Labels partitions
if is_enabled $INSTALLER_DEV; then
	e2label ${disk}2 home
	e2label ${disk}4 tsdev
else
	e2label ${disk}3 home
fi
sleep 1

# Remounts all partitions
echo "Remounting"
rm /tmp/nomount
read_pt
do_mounts
sleep 1

# Add Syslinux to the boot partition
mkdir -p $bootdir/syslinux
cd $bootdir/syslinux
cp /install/* .
cp /install/bios/* .
./extlinux -i /boot/boot/syslinux

cd /boot
mkdir -p EFI/BOOT
cp /install/efi64/* /boot/EFI/BOOT/.
mv /boot/EFI/BOOT/syslinux.efi /boot/EFI/BOOT/bootx64.efi
cp /install/* /boot/EFI/BOOT/.

cd $bootdir

if is_enabled $INSTALLER_DEV || is_enabled $INSTALLER_PROXY_CHECK ; then
	# Setup proxy for wget and git
	proxy-setup
	. /tmp/.proxy
fi

# Install a default boot and backup-boot image into the boot partition
if [ -e /mnt/cdrom0/$INSTALLER_ARCHIVE_NAME ]; then
	tar -xvf /mnt/cdrom0/$INSTALLER_ARCHIVE_NAME
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

	git clone --depth 1 https://github.com/Thinstation/thinstation.git -b $TS_VERSION-Stable /thinstation

	./setup-chroot -i -a
fi
