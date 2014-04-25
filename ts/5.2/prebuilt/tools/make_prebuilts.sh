#! /bin/bash

if [ ! -e "build" ] ; then
    echo "This script needs to be run from the build directory! Exiting...."
    exit 1
fi

. packages/base/etc/thinstation.functions
. packages/base/etc/thinstation.env
verbosity=""

# Check if there are any parameters
until [ -z "$1" ] 
do
    case "$1" in
    LiveCD | netboot | pxe )
	typelist=$typelist" "$1
	shift
	;;
    desktop | OSS | vmview )
	catlist=$catlist" "$1
	shift
	;;
    verbose | quiet )
	verbosity="--$1"
	shift
	;;
    --nobuild)
	nobuild="Y"
	shift
	;;
    --noinstaller)
	noinstaller="Y"
	shift
	;;
    *)
	echo "Options are: (in no particular order)"
	echo "--nobuild              Will NOT build the TS images"
	echo "--noinstaller          Will NOT generate the installers"
	echo "<verbosity>            any of verbose or quiet - passed to installjammer"
	echo "<prebuilt types>       any of LiveCD, netboot or pxe (multiples allowed)"
	echo "<prebuilt categories>  any of desktop, OSS or vmview (multiples allowed)"
	echo "no options will build and generate installers for all types and all categories"
	exit 0
	;;
    esac
done

basedir=`pwd`
# If no parameters set defaults
if [ -z "$typelist" ] ; then
#    typelist="LiveCD netboot pxe"
    typelist="LiveCD"
fi
if [ -z "$catlist" ] ; then
    catlist="desktop OSS vmview"
fi

# Check if installjammer present - if needed
if [ -z "$noinstaller" ] ; then
    if [ ! -e "prebuilt/tools/installjammer" ] ; then
	echo "installjammer is NOT installed and is needed, please install!"
	echo "Do you want to install the version of InstallJammer included? (Y/N)"
	read CHOICE
	if [ `make_caps $CHOICE` == "Y" ] ; then
	    echo "Installing InstallJammer in prebuilt/tools/installjammer"
	    tar zxf installjammer-1.2.15.tar.gz .
	    echo "InstallJammer installed"
	else
	    echo "You will need to install InstallJammer to generate the installers. Exiting..."
	    exit 2
	fi
    fi
fi

for categ in $catlist
do
    for type in $typelist
    do    
	if [ -z $nobuild ] ; then
	    echo "Building: "$type.$categ
	    ln -sf prebuilt/$type/$categ/BuildFiles/$type.$categ.buildtime thinstation.conf.buildtime
	    if [ ! -e "boot-images/iso/source/thinstation.profile" ] ; then mkdir boot-images/iso/source/thinstation.profile ; fi
	    cp -f prebuilt/$type/$categ/BuildFiles/$type.$categ.user boot-images/iso/source/thinstation.profile/thinstation.conf.user
	    ./build prebuilt/$type/$categ/BuildFiles/$type.$categ.build --autodl --license ACCEPT --allmodules
	    ln -sf thinstation.conf.buildtime.sample thinstation.conf.buildtime
	    rm -f boot-images/iso/source/thinstation.profile/thinstation.conf.user
	    if [ "$type" == "LiveCD" ] ; then
    		cp -f boot-images/iso/thinstation.iso prebuilt/$type/$categ/CD/$type.$categ.iso
	    elif [ "$type" == "pxe" ] ; then
    		cp -f boot-images/pxe/vmlinuz prebuilt/$type/$categ/TFtpdRoot/.
		cp -f boot-images/pxe/initrd prebuilt/$type/$categ/TFtpdRoot/.
	    elif [ "$type" == "netboot" ] ; then
		cp -f boot-images/etherboot/thinstation.nbi prebuilt/$type/$categ/TFtpdRoot/.
	    fi
	fi
	if [ -z $noinstaller ] ; then
	    echo "Creating Installers for: "$type.$categ
	    ./prebuilt/tools/installjammer/installjammer -DVersion $TS_VERSION -DTSBaseDir $basedir -DTSType $type -DTSCat $categ $verbosity --output-dir ./prebuilt/installers --build-dir /tmp/$type.$categ --build-for-release --build prebuilt/$type/$categ/BuildFiles/$type.$categ.mpi
	fi
    done
done
