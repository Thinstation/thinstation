#!/bin/sh
#! /bin/sh

SOURCE_PATH=`cat ../SOURCE_PATH`
X_PATH=$SOURCE_PATH/`cat ../X_PATH`/programs/xkbcomp/keymap/xfree86

rm -Rf kmaps/*

for filename in nl_be nl ar be br cz de de_CH dk es us fr fr_CA fr_CH gb hr hu it la lt lv jp106 mk no pl pt ro ru se_SE se_FI sl th tr us_intl en_nz et
do
case $filename in
  de_CH|fr_CA|fr_CH)
    xkbcomp -w0 $X_PATH -xkm -dflts -m $filename kmaps/`echo $filename | tr "[A-Z]" "[a-z]"`.xkm
  ;;
  se_SE)
    xkbcomp -w0 $X_PATH -xkm -dflts -m $filename kmaps/sv.xkm
  ;;
  se_FI)
    xkbcomp -w0 $X_PATH -xkm -dflts -m $filename kmaps/sv_fi.xkm
  ;;
  gb)
    xkbcomp -w0 $X_PATH -xkm -dflts -m $filename kmaps/en_gb.xkm
  ;;
  cz)
    xkbcomp -w0 $X_PATH -xkm -dflts -m $filename kmaps/cs.xkm
  ;;
  be)
    xkbcomp -w0 $X_PATH -xkm -dflts -m $filename kmaps/fr_be.xkm
  ;;
  jp106)
    xkbcomp -w0 $X_PATH -xkm -dflts -m $filename kmaps/ja.xkm
  ;;
  br)
    xkbcomp -w0 $X_PATH -xkm -dflts -m $filename kmaps/pt_br.xkm
  ;;
  dk)
    xkbcomp -w0 $X_PATH -xkm -dflts -m $filename kmaps/da.xkm
  ;;
  us)
    xkbcomp -w0 $X_PATH -xkm -dflts -m $filename kmaps/en_us.xkm
  ;;
  us_intl)
    xkbcomp -w0 $X_PATH -xkm -dflts -m $filename kmaps/en_in.xkm
  ;;
  no)
    xkbcomp -w0 $X_PATH -xkm -dflts -m $filename kmaps/nb.xkm
  ;;
  *)
  xkbcomp -w0 $X_PATH -xkm -dflts -m $filename kmaps/$filename.xkm
  ;;
esac
done

for filename in la-latin1 fr_CH cf be-latin1 es-latin1 br-abnt2 de-latin1-nodeadkeys cz-lat2 dk es us uk fr hu it lt lv-latin4 mk no-latin1 pl pt-latin1 ro ru slovene th trq se-latin1 croat jp106 fi us.uni nl ee-latin9
do
  loadkeys -q $filename
  case $filename in
  de-latin1-nodeadkeys)
    ./dumpkmap > kmaps/de
    ./dumpkmap > kmaps/de_ch
    ;;
  no-latin1)
    ./dumpkmap > kmaps/nb
    ;;
  ee-latin9)
    ./dumpkmap > kmaps/et
    ;;
  la-latin1)
    ./dumpkmap > kmaps/la
    ;;
  fr_CH)
    ./dumpkmap > kmaps/fr_ch
    ;;
  dk)
    ./dumpkmap > kmaps/da
    ;;
  cf)
    ./dumpkmap > kmaps/fr_ca
    ;;
  be-latin1)
    ./dumpkmap > kmaps/fr_be
    ./dumpkmap > kmaps/nl_be
    ;;
  es-latin1)
    ./dumpkmap > kmaps/ar
    ;;
  br-abnt2)
    ./dumpkmap > kmaps/pt_br
    ;;
  cz-lat2)
    ./dumpkmap > kmaps/cs
    ;;
  hu)
    ./dumpkmap > kmaps/hu
    ;;
  croat)
    ./dumpkmap > kmaps/hr
    ;;
  lv-latin4)
    ./dumpkmap > kmaps/lv
    ;;
  jp106)
    ./dumpkmap > kmaps/ja
    ;;
  pt-latin1)
    ./dumpkmap > kmaps/pt
    ;;
  slovene)
    ./dumpkmap > kmaps/sl
    ;;
  trq)
    ./dumpkmap > kmaps/tr
    ;;
  uk)
    ./dumpkmap > kmaps/en_gb
    ;;
  us)
    ./dumpkmap > kmaps/en_us
    ./dumpkmap > kmaps/en_nz
    ;;
  us.uni)
    ./dumpkmap > kmaps/en_in
    ;;
  fi)
    ./dumpkmap > kmaps/sv_fi
    ;;
  se-latin1)
    ./dumpkmap > kmaps/sv
    ;;
  *)
    ./dumpkmap > kmaps/$filename
    ;;

esac
done

loadkeys -q us

rm -Rf packages
mkdir packages

for filename in `ls kmaps | grep -v xkm`
do
	mkdir packages/keymaps-$filename
	mkdir packages/keymaps-$filename/base
	mkdir packages/keymaps-$filename/base/lib
	mkdir packages/keymaps-$filename/base/lib/kmaps
	mkdir packages/keymaps-$filename/base/lib/kmaps/console
	mkdir packages/keymaps-$filename/x-common
	mkdir packages/keymaps-$filename/x-common/lib
	mkdir packages/keymaps-$filename/x-common/lib/kmaps
	mkdir packages/keymaps-$filename/x-common/lib/kmaps/xkb
	cp kmaps/$filename packages/keymaps-$filename/base/lib/kmaps/console
	cp kmaps/$filename.xkm packages/keymaps-$filename/x-common/lib/kmaps/xkb
	if [ -e xmodmap/$filename.xmod ] ; then
		cp xmodmap/$filename.xmod packages/keymaps-$filename/x-common/lib/kmaps
	fi
	echo "base" > packages/keymaps-$filename/dependencies
done
