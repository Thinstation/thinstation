SOURCE_PATH=`cat ../SOURCE_PATH`
X_PATH=$SOURCE_PATH/`cat ../X_PATH`/exports/lib/locale

for filename in `ls kmaps | grep -v xkm`
do
  mkdir packages/keymaps-$filename/full/x-common
  mkdir packages/keymaps-$filename/full/x-common/lib
  mkdir packages/keymaps-$filename/full/x-common/lib/X11
  mkdir packages/keymaps-$filename/full/x-common/lib/X11/locale
  cp $X_PATH/compose.dir packages/keymaps-$filename/full/x-common/lib/X11/locale
  cp $X_PATH/locale.dir packages/keymaps-$filename/full/x-common/lib/X11/locale
  cp $X_PATH/locale.alias packages/keymaps-$filename/full/x-common/lib/X11/locale
  cp -a localelibs/* packages/keymaps-$filename/full/x-common/lib/X11/locale
done

for filename in pt_br de de_ch da es en_us en_nz en_gb fr fr_be fr_ca fr_ch it nl nl_be nb pt sv sv_fi en_in la
do
  cp -R -L $X_PATH/iso8859-1 packages/keymaps-$filename/full/x-common/lib/X11/locale
done

for filename in cs pl ro sl hr hu
do
  cp -R -L $X_PATH/iso8859-2 packages/keymaps-$filename/full/x-common/lib/X11/locale
done

for filename in et
do
  cp -R -L $X_PATH/iso8859-15 packages/keymaps-$filename/full/x-common/lib/X11/locale
done

for filename in lt lv
do
  cp -R -L $X_PATH/iso8859-13 packages/keymaps-$filename/full/x-common/lib/X11/locale
done

for filename in mk
do
  cp -R -L $X_PATH/iso8859-5 packages/keymaps-$filename/full/x-common/lib/X11/locale
done

for filename in ar
do
  cp -R -L $X_PATH/iso8859-6 packages/keymaps-$filename/full/x-common/lib/X11/locale
done

for filename in ru
do
  cp -R -L $X_PATH/koi8-r packages/keymaps-$filename/full/x-common/lib/X11/locale
done

for filename in th
do
  cp -R -L $X_PATH/th_TH packages/keymaps-$filename/full/x-common/lib/X11/locale
done

for filename in tr
do
  cp -R -L $X_PATH/iso8859-9 packages/keymaps-$filename/full/x-common/lib/X11/locale
done
