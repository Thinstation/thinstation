#!/bin/bash
tempdir=`mktemp -d 2>/dev/null`
disk=$1
buggybios=$2

mounted()
{
        if [ "`cat /proc/mounts |grep -e $1 -c`" -ne "0" ]; then
                return 0
        else
                return 1
        fi
}

un_mount()
{
        for i in `mount |grep -e $disk |cut -d " " -f3`; do
                while mounted $i; do
                        umount $i
                done
        done
        swapoff -a
        sleep 1
}

do_mounts()
{
	while ! mounted /boot ; do
		mount -t vfat /dev/${disk}1 /boot
	done
	while ! mounted /root ; do
		mount -t ext4 /dev/${disk}2 /root
	done
	while ! mounted /thinstation ; do
		mount -t ext4 /dev/${disk}4 /thinstation
	done
}

echo "Starting Partioner"
touch /tmp/nomount
un_mount
dd if=/dev/zero of=$disk bs=1M count=32
sleep 1
parted -s $disk mklabel msdos
blockdev --rereadpt $disk
un_mount
if [ "$buggybios" == "true" ]; then
	parted -s $disk mkpart primary fat32 "2s 2101247s" 1>/dev/null
else
	parted -s $disk mkpart primary fat32 "2048s 2101247s" 1>/dev/null
fi
parted -s $disk set 1 boot on
parted -s $disk mkpart primary ext4 "2101248s 4202495s"
parted -s $disk mkpart primary linux-swap "4202496s 6303743s"
parted -s $disk mkpart primary ext4 "6303744s -0"
sleep 1
blockdev --rereadpt $disk
sleep 1
un_mount
echo "Making filesystems"
mkdosfs -n boot -F 32 -R 32 ${disk}1
#progress "Made boot Filesystem" 30
mkfs.ext4 ${disk}2
#progress "Made home Filesystem" 35
mkfs.ext4 ${disk}4
#progress "Made Dev Filesystem" 40
mkswap -L swap ${disk}3
sleep 1
#progress "Made swap Fileystem" 45
blockdev --rereadpt $disk
un_mount
e2label ${disk}2 home
e2label ${disk}4 tsdev
sleep 1
#progress 50
echo "Remounting"
rm /tmp/nomount
blockdev --rereadpt $disk
sleep 4
do_mounts
sleep 1
cd /boot
cp /install/* .
./syslinux -s ${disk}1
./syslinux ${disk}1
if [ "$use_proxy" == "Yes" ] ; then
	proxy-setup
fi
if [ -e /mnt/cdrom0/initrd-dev ]; then
	cp /mnt/cdrom0/initrd-dev /boot/initrd
	cp /mnt/cdrom0/vmlinuz-dev /boot/vmlinuz
	cp /mnt/cdrom0/lib.squash-dev /boot/lib.update
else
	echo "Downloading a Default Image"
	wget http://www.doncuppjr.net/thindev-default.tar.xz
	tar -xvf thindev-default.tar.xz
	rm thindev-default.tar.xz
fi
cp /boot/initrd /boot/initrd-backup
cp /boot/vmlinuz /boot/vmlinuz-backup
cp /boot/lib.update /boot/lib.squash-backup
cd /thinstation
rm -rf *
echo "Gitting thinstation repo"
git clone --depth 1 git://thinstation.git.sourceforge.net/gitroot/thinstation/thinstation-2.5 /thinstation
./setup-chroot -i
