#!/bin/bash
# Description: Installs the Thinstation image to the local computer with a central version management for the image on a server.
# Created: Marcus Eyre (marcus at eyre dot se), original script in 2012 but in this form January 2017.

. /etc/thinstation.env
. $TS_GLOBAL

LOGGERTAG="local-install.sh"
TMP_DIR="/tmp/local-install"

#####
# Default values
##

if [ -z ${LOCAL_INSTALL_DEVICEREGEX} ]; then
	deviceRegEx='(sd[a-z]$)|(mmcblk[0-9]$)|(nvme0n[0-9]$)'
	#logger --stderr --tag $LOGGERTAG "LOCAL_INSTALL_DEVICEREGEX is not set, setting it to '$deviceRegEx'"
else
    deviceRegEx=${LOCAL_INSTALL_DEVICEREGEX}
	#logger --stderr --tag $LOGGERTAG "LOCAL_INSTALL_DEVICEREGEX was set in config files to '$deviceRegEx'"
fi


#####
# Functions
##

downloadAndExecute()
{
    if [ -z "${1}" ]; then
        return 1
    fi
    
    # First, delete any previous upgrade script
    rm -f "${TMP_DIR}/${1}"
    
    # Download the post upgrade script
    wget --quiet --timestamping -P ${TMP_DIR} "${LOCAL_INSTALL_URL}${1}"
    
    if [ ${?} -eq 0 ]; then
        # Execute the script
        . "${TMP_DIR}/${1}"
        
        # Clean up...
        rm -f "${TMP_DIR}/${1}"
        
        return 0
    else
        return 2
    fi
}



downloadImage()
{
	# parameter 1:		The device path that we shall do syslinux on. e.g. /dev/sda1
	# parameter 2:		The mount point that we shall copy the image to. e.g. /mnt/disc/sda/part1
	# parameter 3:		The mount point for the thinstation linux partition. e.g. /mnt/disc/sda/part2

	if [ -f $1 ]; then
		logger --stderr --tag $LOGGERTAG "downloadImage: Parameter 1 path for the device that we will run : '$1'"
		return 1
	fi

	if [ -f $2 ]; then
		logger --stderr --tag $LOGGERTAG "downloadImage: Parameter 2 path for where to install the image does not exist: '$2'"
		return 2
	fi

	if [ -f $3 ]; then
		logger --stderr --tag $LOGGERTAG "downloadImage: Parameter 3 path for the thinstation linux partition does not exist: '$3'"
		return 3
	fi
	
	
	#logger --stderr --tag $LOGGERTAG "downloadImage: Downloading image to '${TMP_DIR}' from ${LOCAL_INSTALL_URL}"
    ##wget -nv -nd -N --no-parent --reject "index.htm*,web.config" -P ${TMP_DIR} -r -l 1 ${LOCAL_INSTALL_URL}
    #wget --no-verbose -P ${TMP_DIR} --no-host-directories --cut-dirs=1 --no-parent --recursive --timestamping --reject "index.htm*,web.config" ${LOCAL_INSTALL_URL}
    
    # Check if we are to download refind for UEFI computers or syslinux for BIOS computers
    if [ "$(firmwareType)" = "UEFI" ]; then
        downloadURL="${LOCAL_INSTALL_URL}refind/"
    else
        downloadURL="${LOCAL_INSTALL_URL}syslinux/"
    fi
    
    # Count how many directories we need to ignore. -4 comes for 1 (by defaul so to speak), 2 for '//' in http:// and 1 for the last '/' after 'refind/'
    # e.g. http://myserver/ts6.1/local-install/refind/' will result in 3 and thereby we will only get the directories inside the final path.
    # Otherwise we would end up having the ts6.1/local-install/refind directory structure as well...
    cutDirsCount=$((`echo $LOCAL_INSTALL_URL | sed 's/[^/]//g' | wc -m` -3))

    mkdir -p ${TMP_DIR}/image

    wget --no-verbose -P ${TMP_DIR}/image --no-host-directories --cut-dirs=$cutDirsCount --no-parent --recursive --timestamping --reject "index.htm*,web.config" ${downloadURL}


    if [ ${?} -eq 0 ]; then
        logger --stderr --tag $LOGGERTAG "downloadImage: Download was successful, copying files to boot partition, please wait..."

        #cp -R ${TMP_DIR}/* /mnt/disc/sda/part1
        cp -Rf ${TMP_DIR}/image/* $2
        sync
        
        if [ "$(firmwareType)" = "BIOS" ]; then
            chmod 755 ${TMP_DIR}/image/boot/syslinux/syslinux
            #${TMP_DIR}/boot/syslinux/syslinux /dev/sda1
            ${TMP_DIR}/image/boot/syslinux/syslinux $1
        else
            # UEFI firmware
            # Since some hardware don't follow EFI standard/best practice but is hardcoded to Microsoft
            # we do this ugly quick fix in order to ensure that the boot loader is found by the firmware...
            mkdir -p ${2}/EFI/Microsoft/BOOT
            cp -Rf ${TMP_DIR}/image/EFI/BOOT/* ${2}/EFI/Microsoft/BOOT/
            cp -f ${TMP_DIR}/image/EFI/BOOT/bootx64.efi ${2}/EFI/Microsoft/BOOT/bootmgfw.efi
            sync
        fi


        # Download the version file
        wget --quiet --timestamping -P ${TMP_DIR} ${LOCAL_INSTALL_URL}version

        # Check if we got a version file and it is 1 or higher, otherwise create a version file togehter with the installed image.
        # We need this file to determine what partition the Thinstation boot image is installed on.
        if [ ${?} -eq 0 ] && [ $(getValueFromFile 'LOCAL_INSTALL_VERSION' ${TMP_DIR}/version 0) -ge 1 ] ; then
            # The version file looks ok, copy it
            cp -f ${TMP_DIR}/version $2
            sync
        else
            # The version file does not look ok, create a new one.
            echo 'LOCAL_INSTALL_VERSION=1' > ${2}/version
            sync
        fi
            


        # Create the thinstation.profile directory and thinstation.conf.user file
        # (oterwise the boot-process takes some extra time if the file doesn't exist)
        #mkdir -p /mnt/disc/sda/part2/thinstation.profile
        #touch /mnt/disc/sda/part2/thinstation.profile/thinstation.conf.user
        mkdir -p ${3}/thinstation.profile
        touch ${3}/thinstation.profile/thinstation.conf.user


        echo ""
        echo ""
        #echo "Installation complete. You must reboot if you want to use the new version now."
        logger --stderr --tag $LOGGERTAG "downloadImage: Installation complete. You must reboot to use the new version."
        echo ""
    else
        #echo "Failed to download syslinux over http."
        logger --stderr --tag $LOGGERTAG "downloadImage: Failed to download the local-install image over http from ${downloadURL}"
        return 4
    fi

    rm -rf ${TMP_DIR}/image
    return 0
}



getDeviceForMountPoint()
{
	#if [ -f $1 ]; then
	#	logger --stderr --tag $LOGGERTAG "getMountPointForDevice: Parameter 1 path does not exist: '$1'"
	#	#return 1
	#fi

	echo $(grep ${1} /proc/mounts | cut -d' ' -f1)
}



getMountPointForDevice()
{
	#if [ -f $1 ]; then
	#	logger --stderr --tag $LOGGERTAG "getMountPointForDevice: Parameter 1 path does not exist: '$1'"
	#	#return 1
	#fi

	echo $(grep ${1} /proc/mounts | cut -d' ' -f2)
}



getValueFromFile()
{
	# parameter 1:		The value to look for
	# parameter 2:		The file to extract the value from
    # parameter 3:      Value to return if any error
    
    local returnValue=${3}
    
    # Check that the file exists
    if [ -f ${2} ]; then
        
        # Extract the variable
        #local valueFromFile=$(grep -e "^${1}=" ${2} | cut -d'=' -f2)
        #local valueFromFile=$(grep -e "^${1}=" ${2} | cut -d'=' -f2 | grep -e "^[0-9^]")
        #local valueFromFile=$(grep -E "^${1}=" ${2} | sed 's/\([0-9]*\).*/\1/')

        local valueFromFile=$(grep -E "^${1}=" ${2} | sed 's/[^0-9]*//g')

        # Update returnValue if
        #if [ ${?} -eq 0 ] && [ "${valueFromFile}" -gt 0 ]; then
        if [ ${?} -eq 0 ] && [ -n "$valueFromFile" ]; then
            returnValue=$valueFromFile
        fi
    fi
    echo $returnValue
}



firmwareType()
{
    [ -d /sys/firmware/efi ] && echo UEFI || echo BIOS
}



getVersionLocal()
{
    # Return 0 if no local version is found.

    mkdir -p ${TMP_DIR}

    if [ "$(mountPartitions '/mnt/local-install/part1' '/mnt/local-install/part2')" -eq 1 ]; then
        echo $(getValueFromFile 'LOCAL_INSTALL_VERSION' '/mnt/local-install/part1/version' 0)
    else
        echo 0
    fi
}



getVersionRemote()
{
    # Return 0 if we can't find a version on the remote server.
    local returnValue=0
    
    mkdir -p ${TMP_DIR}

    # Delete the version file if it already exists in the TMP_DIR
    rm -f ${TMP_DIR}/version
    
    # Download the version file
    wget --quiet --timestamping -P ${TMP_DIR} ${LOCAL_INSTALL_URL}version
    
    if [ ${?} -eq 0 ]; then
        returnValue=$(getValueFromFile 'LOCAL_INSTALL_VERSION' ${TMP_DIR}/version 0)
    fi

    # Clean up...
    rm -f ${TMP_DIR}/version
    
    # Finally return the value
    echo $returnValue
}



isMounted()
{
    if [ "$(grep -o ${1} /proc/mounts)" = "${1}" ]; then
        echo 1
    else
        echo 0
    fi
}



mountPartitions()
{
	# return 0 if we failed to mount the partitions
    
    # parameter 1:		Path where to mount the Boot partition (partition 1)
	# parameter 2:		Path where to mount the Userconf partition (partitions 2)
    #partitionBootMount='/mnt/local-install/part1'
    #partitionUserMount='/mnt/local-install/part2'
    
    if [ -z ${1} ]; then
        logger --stderr --tag $LOGGERTAG "mountPartitions: The parameter 1 was not stated."
        exit 1
    fi

    if [ -z ${2} ]; then
        logger --stderr --tag $LOGGERTAG "mountPartitions: The parameter 2 was not stated."
        exit 1
    fi
    
    # assume error
    returnValue=0
    

    if [ "$(firmwareType)" = "UEFI" ]; then
        #echo "This computer uses UEFI firmware, searching for boot image by partition label."
        #partitionBootDevice='/dev/disk/by-partlabel/Thinstation_EFI_Boot'
        #partitionBootMount='/mnt/local-install/part1'
        #partitionUserDevice='/dev/disk/by-partlabel/Thinstation_Userconf'
        #partitionUserMount='/mnt/local-install/part2'
        
        #mkdir -p ${partitionBootMount}
        #mkdir -p ${partitionUserMount}
        #mount ${partitionBootDevice} ${partitionBootMount}
        #mount ${partitionUserDevice} ${partitionUserMount}

        # assume it went well (we set it to 0 if something goes wrong)
        returnValue=1
        
        # Boot partition (partition 1)
        if [ "$(isMounted ${1})" -eq 0 ]; then
            mkdir -p ${1}
            mount '/dev/disk/by-partlabel/Thinstation_EFI_Boot' ${1}
            if [ ${?} -ne 0 ]; then
                returnValue=0
            
                # Clean up the created directory (we don't do rm -rf since that could possibly couse erazing everything
                # on the partition if we mounted the partition but got an error anyway...
                rmdir ${1}
            fi
        fi
        
        # Userconf partition (partition 2)
        if [ "$(isMounted ${2})" -eq 0 ]; then
            mkdir -p ${2}
            mount '/dev/disk/by-partlabel/Thinstation_Userconf' ${2}
            if [ ${?} -ne 0 ]; then
                returnValue=0

                # Clean up the created directory (we don't do rm -rf since that could possibly couse erazing everything
                # on the partition if we mounted the partition but got an error anyway...
                rmdir ${2}
            fi
        fi


    else
        #echo "This computer uses BIOS firmware, searching for boot image by disk"

        # Get all the disks that we shall search on.
        DISKS=$(find /dev/ | grep -E "$deviceRegEx")

        for DISK in ${DISKS}; do
            # Check that we have at least two partitions before mounting it
            if [ -b "${DISK}1" ] && [ -b "${DISK}2" ]; then
                #echo "mounting to check ${DISK}1"
                #if [ $(isMounted ${partitionBootMount}) -eq 1 ]; then
                if [ "$(isMounted ${1})" -eq 1 ]; then
                    #echo "mounted"

                    # OK, we have something mounted, see if it is our Thinstation_Boot partition
                    #if [ "$(getValueFromFile 'LOCAL_INSTALL_VERSION' ${partitionBootMount}/version 0)" -ge 1 ]; then
                    if [ "$(getValueFromFile 'LOCAL_INSTALL_VERSION' ${1}/version 0)" -ge 1 ]; then
                        #returnValue=$(getValueFromFile 'LOCAL_INSTALL_VERSION' ${partitionBootMount}/version 0)
                        returnValue=1

                        partitionBootDevice=${DISK}1
                        partitionUserDevice=${DISK}2

                        # Now exit the for loop since we don't need to analyze anymore partitions.
                        break
                    else
                        # Nope, it is not our boot partition, unmount and continue...
                        sync
                        umount ${1}
                    fi
                #else
                    #echo "${partitionBootMount} is not mounted"
                fi

                # Mount the partition and test it
                #mkdir -p ${partitionBootMount}
                mkdir -p ${1}
                #echo "Mouning ${DISK}1 to ${partitionBootMount}"
                #mount ${DISK}1 ${partitionBootMount}
                mount ${DISK}1 ${1}

                #if [ "$(getValueFromFile 'LOCAL_INSTALL_VERSION' ${partitionBootMount}/version 0)" -ge 1 ]; then
                if [ "$(getValueFromFile 'LOCAL_INSTALL_VERSION' ${1}/version 0)" -ge 1 ]; then
                    #returnValue=$(getValueFromFile 'LOCAL_INSTALL_VERSION' ${partitionBootMount}/version 0)
                    returnValue=1
                    partitionBootDevice=${DISK}1
                    partitionUserDevice=${DISK}2
                    break
                fi
            fi
        done


        # Mount the second partition if it is not already mounted.
        #if [ $(isMounted ${partitionUserMount}) -eq 0 ]; then
        if [ "$(isMounted ${2})" -eq 0 ]; then
            #mkdir -p ${partitionUserMount}
            #mount ${partitionUserDevice} ${partitionUserMount}
            mkdir -p ${2}
            mount ${partitionUserDevice} ${2}
        fi

    fi

    echo $returnValue

}



notifyServer()
{
    returnValue=0
    if [ -z "${LOCAL_INSTALL_TFTP_NOTIFY_PATH}" ]; then
        logger --stderr --tag $LOGGERTAG "Exiting version notification since \$LOCAL_INSTALL_TFTP_NOTIFY_PATH was not set. If you want notification to a server, set \$LOCAL_INSTALL_TFTP_NOTIFY_PATH='/' or \$LOCAL_INSTALL_TFTP_NOTIFY_PATH='/client-versions/' it must however end with a '/'"
        returnValue=1
    fi

    if [ "$returnValue" -eq 0 ] && [ -z "${SERVER_IP}" ]; then
        logger --stderr --tag $LOGGERTAG "Exiting version notification since \$SERVER_IP was not set."
        returnValue=2
    fi

    if [ "$returnValue" -eq 0 ] &&  [ "$(getVersionLocal)" -eq 0 ]; then
        logger --stderr --tag $LOGGERTAG 'Exiting version notification to TFTP server since no local installation was found.'
        returnValue=3
    fi

    if [ "$returnValue" -eq 0 ]; then
        mkdir -p ${TMP_DIR}
        printf $(getVersionLocal) > "${TMP_DIR}/version-local"
        tftp -p -l "${TMP_DIR}/version-local" -r "${LOCAL_INSTALL_TFTP_NOTIFY_PATH}$(/bin/hostname).version" $SERVER_IP

        if [ ${?} -ne 0 ]; then
            returnValue=4
        fi
        rm "${TMP_DIR}/version-local"
    fi

    echo $returnValue
}



#####
# Main script
##


case "$1" in

    version-local)
        getVersionLocal
    ;;



    version-remote)
        getVersionRemote
    ;;



    mount)
        # First unmount the partitions if they are already mounted...
        $0 umount
        
        mountPartitions '/mnt/local-install/part1' '/mnt/local-install/part2'

        if [ $(getVersionLocal) -eq 0 ]; then
            #echo "no local installation found"
            if [ $(isMounted '/mnt/local-install') -eq 0 ]; then
                #echo "mount: /mnt/local-install is not mounted"
                rmdir '/mnt/local-install/part1'
                rmdir '/mnt/local-install/part2'
                rmdir '/mnt/local-install'
            #else
                #echo "mount: /mnt/local-install/ is mounted, will not remove directory"
            fi
            logger --stderr --tag $LOGGERTAG "mount: No local installation was found."
            #exit 1
        fi
    ;;



    umount)
        umount '/mnt/local-install/part1'
        umount '/mnt/local-install/part2'
        rmdir '/mnt/local-install/part1'
        rmdir '/mnt/local-install/part2'
        rmdir '/mnt/local-install'
    ;;



    notify-server)
        notifyServer
    ;;



    upgrade)
        versionLocal=$(getVersionLocal)
        versionRemote=$(getVersionRemote)

        if [ "$versionLocal" -eq 0 ]; then
            logger --stderr --tag $LOGGERTAG "upgrade: Exiting upgrade since no local installation was found."
            exit 1
        fi

        if [ "$versionRemote" -eq 0 ]; then
            logger --stderr --tag $LOGGERTAG "upgrade: Unable to fetch remote version over HTTP at ${LOCAL_INSTALL_URL}version"
            exit 2
        fi

        if [ "$versionLocal" -ge "$versionRemote" ]; then
            logger --stderr --tag $LOGGERTAG "upgrade: No need to upgrade, local version is $versionLocal and remote version is $versionRemote"
            exit 3
        fi

        downloadImage $(getDeviceForMountPoint '/mnt/local-install/part1') '/mnt/local-install/part1' '/mnt/local-install/part2'

        # If download went well, run the after upgrade script
        if [ ${?} -eq 0 ]; then
            downloadAndExecute 'after_upgrade_finished.sh'
        else
            exit 4
        fi
    ;;



    upgrade-force)
        versionLocal=$(getVersionLocal)
        versionRemote=$(getVersionRemote)

        if [ "$versionLocal" -eq 0 ]; then
            logger --stderr --tag $LOGGERTAG "upgrade: Exiting upgrade since no local installation was found."
            exit 1
        fi

        if [ "$versionRemote" -eq 0 ]; then
            logger --stderr --tag $LOGGERTAG "upgrade: Unable to fetch remote version over HTTP at ${LOCAL_INSTALL_URL}version"
            exit 2
        fi

        downloadImage $(getDeviceForMountPoint '/mnt/local-install/part1') '/mnt/local-install/part1' '/mnt/local-install/part2'
    ;;



    install)
        #DISKS_COUNT=$(ls -1 /dev/sd? /dev/mmcblk? | grep -v ^1 | wc -l)
        DISKS_COUNT=$(find /dev/ | grep -E "$deviceRegEx" | wc -l)

        if [ $DISKS_COUNT -eq 1 ]; then
            # We only have one disc so install to that one.
            INSTALL_DISK=$(find /dev/ | grep -E "$deviceRegEx")

        else
            # There are multiple disks, ask the user.

            echo "Select which device to install Thinstation on:"
            # Print out a list of all disks available for installation
            DISKS=$(find /dev/ | grep -E "$deviceRegEx")

            for DISK in ${DISKS}; do
                echo "    ${DISK}"
            done

            echo ""
            echo "If you need more information about the devices use the commands lsblk or blkid"
            echo ""
            echo ""
            printf "Install on device: "

            read ANSWER

            if [ -e "$ANSWER" ]; then
                INSTALL_DISK="$ANSWER"
            else
                echo "The device path you entered does not exist! Type exactly as in the list above."
                exit 0
            fi

        fi


        echo ""
        echo ""
        echo "This script will overwrite any data on the local disk (${INSTALL_DISK}) and install Thinstation."
        echo "Write YES to continue and lose all local data."

        read ANSWER

        if [ "${ANSWER}" != "YES" ]; then
            echo "You did not answer 'YES', exiting!"
            exit 0
        fi


        # Extract the device name into a variable, e.g. if INSTALL_DISK is "/dev/sda" INSTALL_DISK_NAME will be "sda"
        INSTALL_DISK_NAME="$(basename $INSTALL_DISK)"

        #echo "INSTALL_DISK = '$INSTALL_DISK'"
        #echo "INSTALL_DISK_NAME = '$INSTALL_DISK_NAME'"



        # Turn of udev commands so they do not interfear with our installation (eg. package automount and module autofs4)
        udevadm control --stop-exec-queue

        sync
        sleep 3


        # Unmont all partitions
        umount $INSTALL_DISK*

        sync
        sleep 3

        # Count the number of partitions
        #IFS=" " read -a arr <<<$(cat /proc/partitions | grep -e "sda[0-9+]")
        #PARTITIONSCOUNT=$((${#arr[@]} / 4))

        #echo $PARTITIONSCOUNT

        #PARTNUM=1
        #while [ $PARTNUM -le $PARTITIONSCOUNT ]; do
        #    #parted -s /dev/sda rm ${PARTNUM}
        #    #parted -s $INSTALL_DISK rm ${PARTNUM} > /dev/null 2>&1
        #    echo "deleting partition $PARTNUM on $INSTALL_DISK"
        #    parted -s $INSTALL_DISK rm ${PARTNUM} > /dev/null 2>&1
        #
        #    let PARTNUM=PARTNUM+1
        #done


        # Delete all partitions 1-40
        #PARTNUM=1
        #while [ $PARTNUM -le 40 ]; do
        #    #parted -s /dev/sda rm ${PARTNUM}
        #    #parted -s $INSTALL_DISK rm ${PARTNUM} > /dev/null 2>&1
        #    parted -s $INSTALL_DISK rm ${PARTNUM} > /dev/null 2>&1
        #
        #    let PARTNUM=PARTNUM+1
        #done


        # Delete all partitions
        for PARTNUM in $(cat /proc/partitions | grep -e "sda[0-9+]" | cut -d' ' -f12); do
            echo "deleting partition $PARTNUM on $INSTALL_DISK"
            parted -s $INSTALL_DISK rm ${PARTNUM} > /dev/null 2>&1
        done


        if [ "$(firmwareType)" = "UEFI" ]; then
            echo "This computer uses UEFI firmware, setting up gpt partitions for EFI boot"
            parted -s ${INSTALL_DISK} mklabel gpt
            #parted -s ${INSTALL_DISK} mkpart ESP fat32 1MiB 512Mib
            parted -s ${INSTALL_DISK} mkpart ESP fat32 1MiB 1024MiB
            parted -s ${INSTALL_DISK} set 1 boot on
            #parted -s ${INSTALL_DISK} name 1 '"Thinstation EFI Boot"'
            parted -s ${INSTALL_DISK} name 1 Thinstation_EFI_Boot
            parted -s ${INSTALL_DISK} mkpart primary ext4 1028MiB 1128MiB
            parted -s ${INSTALL_DISK} name 2 Thinstation_Userconf

        else
            echo "This computer uses BIOS firmware, setting up msdos partitions for MBR boot"
            # Partition the disk and create filesystems.
            parted -s ${INSTALL_DISK} mklabel msdos
            parted -s ${INSTALL_DISK} mkpart primary fat32 "2048s 2099199s"
            parted -s ${INSTALL_DISK} set 1 boot on
            parted -s ${INSTALL_DISK} mkpart primary ext4 "2099200s 2304000s"
        fi

        # Check what the new partition name is
        # It the disk is mmcblk0 the partition is namned mmcblk0p1 (adding a p before the partition number)
	sleep 3
	blockdev --rereadpt $INSTALL_DISK
        if cat /proc/partitions | egrep -wq "${INSTALL_DISK_NAME}p1"; then
            INSTALL_PARTITION_1="${INSTALL_DISK_NAME}p1"
            INSTALL_PARTITION_1_DEVICE="${INSTALL_DISK}p1"

            INSTALL_PARTITION_2="${INSTALL_DISK_NAME}p2"
            INSTALL_PARTITION_2_DEVICE="${INSTALL_DISK}p2"
        else
            INSTALL_PARTITION_1="${INSTALL_DISK_NAME}1"
            INSTALL_PARTITION_1_DEVICE="${INSTALL_DISK}1"

            INSTALL_PARTITION_2="${INSTALL_DISK_NAME}2"
            INSTALL_PARTITION_2_DEVICE="${INSTALL_DISK}2"
        fi


        # Format the new partitions
        mkfs.vfat ${INSTALL_PARTITION_1_DEVICE}
        mkfs.ext4 ${INSTALL_PARTITION_2_DEVICE}

        # Get the mount point for the partitions
        #INSTALL_PARTITION_1_MOUNT=$(cat /proc/mounts | grep -e ${INSTALL_PARTITION_1_DEVICE} | cut -d' ' -f2)
        #INSTALL_PARTITION_2_MOUNT=$(cat /proc/mounts | grep -e ${INSTALL_PARTITION_2_DEVICE} | cut -d' ' -f2)

        sync
        sleep 3

        # Mount to a temporary folder (don't use /mnt/local-install/partX in case local-install is already installed on
        #  this computer and we are now installing to e.g. a usb flash drive.
        mkdir -p /mnt/local-install/install_part1
        mkdir -p /mnt/local-install/install_part2
        mount ${INSTALL_PARTITION_1_DEVICE} /mnt/local-install/install_part1
        mount ${INSTALL_PARTITION_2_DEVICE} /mnt/local-install/install_part2

        # Download the Thinstation image
        downloadImage $INSTALL_PARTITION_1_DEVICE '/mnt/local-install/install_part1' '/mnt/local-install/install_part2'


        # Clean up
        sync
        sleep 3
        umount /mnt/local-install/install_part1
        umount /mnt/local-install/install_part2
        rmdir /mnt/local-install/install_part1
        rmdir /mnt/local-install/install_part2



        # Resume udev commands
        udevadm control --start-exec-queue
    ;;



    install-force)

        if [ -f $2 ]; then
            logger --stderr --tag $LOGGERTAG "install-force: Parameter 2 path for device to install on is not defined: '$2'"
            exit 1
        fi

        if [ ! -b $2 ]; then
            logger --stderr --tag $LOGGERTAG "install-force: Parameter 2 device does not exist: '$2'"
            exit 2
        fi


        # Set INSTALL_DISK to the device defined by parameter 2
        INSTALL_DISK=$(find $2 | grep -E "$deviceRegEx")


        # Extract the device name into a variable, e.g. if INSTALL_DISK is "/dev/sda" INSTALL_DISK_NAME will be "sda"
        INSTALL_DISK_NAME="$(find $INSTALL_DISK -printf ""%f"")"

        #echo "INSTALL_DISK = '$INSTALL_DISK'"
        #echo "INSTALL_DISK_NAME = '$INSTALL_DISK_NAME'"



        # Turn of udev commands so they do not interfear with our installation (eg. package automount and module autofs4)
        udevadm control --stop-exec-queue


        sync
        sleep 3

        # Unmont all partitions
        umount $INSTALL_DISK*


        sync
        sleep 3


        # Delete all partitions
        for PARTNUM in $(cat /proc/partitions | grep -e "sda[0-9+]" | cut -d' ' -f12); do
            echo "deleting partition $PARTNUM on $INSTALL_DISK"
            parted -s $INSTALL_DISK rm ${PARTNUM} > /dev/null 2>&1
        done


        if [ "$(firmwareType)" = "UEFI" ]; then
            echo "This computer uses UEFI firmware, setting up gpt partitions for EFI boot"
            parted -s ${INSTALL_DISK} mklabel gpt
            #parted -s ${INSTALL_DISK} mkpart ESP fat32 1MiB 512Mib
            parted -s ${INSTALL_DISK} mkpart ESP fat32 1MiB 1024MiB
            parted -s ${INSTALL_DISK} set 1 boot on
            #parted -s ${INSTALL_DISK} name 1 '"Thinstation EFI Boot"'
            parted -s ${INSTALL_DISK} name 1 Thinstation_EFI_Boot
            parted -s ${INSTALL_DISK} mkpart primary ext4 1028MiB 1128MiB
            parted -s ${INSTALL_DISK} name 2 Thinstation_Userconf

        else
            echo "This computer uses BIOS firmware, setting up msdos partitions for MBR boot"
            # Partition the disk and create filesystems.
            parted -s ${INSTALL_DISK} mklabel msdos
            parted -s ${INSTALL_DISK} mkpart primary fat32 "2048s 2099199s"
            parted -s ${INSTALL_DISK} set 1 boot on
            parted -s ${INSTALL_DISK} mkpart primary ext4 "2099200s 2304000s"
        fi

        # Check what the new partition name is
        # It the disk is mmcblk0 the partition is namned mmcblk0p1 (adding a p before the partition number)
        if cat /proc/partitions | egrep -wq "${INSTALL_DISK_NAME}p1"; then
            INSTALL_PARTITION_1="${INSTALL_DISK_NAME}p1"
            INSTALL_PARTITION_1_DEVICE="${INSTALL_DISK}p1"

            INSTALL_PARTITION_2="${INSTALL_DISK_NAME}p2"
            INSTALL_PARTITION_2_DEVICE="${INSTALL_DISK}p2"
        else
            INSTALL_PARTITION_1="${INSTALL_DISK_NAME}1"
            INSTALL_PARTITION_1_DEVICE="${INSTALL_DISK}1"

            INSTALL_PARTITION_2="${INSTALL_DISK_NAME}2"
            INSTALL_PARTITION_2_DEVICE="${INSTALL_DISK}2"
        fi


        # Format the new partitions
        mkfs.vfat ${INSTALL_PARTITION_1_DEVICE}
        mkfs.ext4 ${INSTALL_PARTITION_2_DEVICE}

        # Get the mount point for the partitions
        #INSTALL_PARTITION_1_MOUNT=$(cat /proc/mounts | grep -e ${INSTALL_PARTITION_1_DEVICE} | cut -d' ' -f2)
        #INSTALL_PARTITION_2_MOUNT=$(cat /proc/mounts | grep -e ${INSTALL_PARTITION_2_DEVICE} | cut -d' ' -f2)

        sync
        sleep 3


        # Mount to a temporary folder (don't use /mnt/local-install/partX in case local-install is already installed on
        #  this computer and we are now installing to e.g. a usb flash drive.
        mkdir -p /mnt/local-install/install_part1
        mkdir -p /mnt/local-install/install_part2
        mount ${INSTALL_PARTITION_1_DEVICE} /mnt/local-install/install_part1
        mount ${INSTALL_PARTITION_2_DEVICE} /mnt/local-install/install_part2

        sync
        sleep 3

        # Download the Thinstation image
        downloadImage $INSTALL_PARTITION_1_DEVICE '/mnt/local-install/install_part1' '/mnt/local-install/install_part2'


        # Clean up
        sync
        sleep 3
        umount /mnt/local-install/install_part1
        umount /mnt/local-install/install_part2
        rmdir /mnt/local-install/install_part1
        rmdir /mnt/local-install/install_part2



        # Resume udev commands
        udevadm control --start-exec-queue
    ;;


    *)
        echo "Usage: $0 {install|install-force|version-local|version-remote|mount|umount|notify-server|upgrade|upgrade-force}"
        exit 1
    ;;
esac
