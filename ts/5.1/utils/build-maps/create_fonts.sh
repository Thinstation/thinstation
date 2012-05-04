SOURCE_PATH=`cat ../SOURCE_PATH`
X_PATH=$SOURCE_PATH/`cat ../X_PATH`/fonts/bdf/75dpi
TOOLS_PATH=../tools


for filename in `ls kmaps | grep -v xkm`
do
   mkdir packages/keymaps-$filename/full/x-common/lib/X11/fonts
   mkdir packages/keymaps-$filename/full/x-common/lib/X11/fonts/75dpi
   mkdir packages/keymaps-$filename/full/x-common/bin
   cp $SOURCE_PATH/`cat ../X_PATH`/programs/mkfontscale/mkfontscale packages/keymaps-$filename/full/x-common/bin
   cp ./localefonts/bin/mkfontdir packages/keymaps-$filename/full/x-common/bin
done

for fontname in timR timB timI helvR helvO helvB courB courO courB
do
  for fontsize in 08 10 12 14 18 24
  do
    for filename in pt_br de de_ch da es en_us en_nz en_gb fr fr_be fr_ca fr_ch it nl nl_be nb pt sv sv_fi en_in la et
    do
      cp -R -L $X_PATH/$fontname$fontsize-ISO8859-15.pcf.gz packages/keymaps-$filename/full/x-common/lib/X11/fonts/75dpi
    done

    for filename in cs pl ro sl hr hu
    do
      cp -R -L $X_PATH/$fontname$fontsize-ISO8859-2.pcf.gz packages/keymaps-$filename/full/x-common/lib/X11/fonts/75dpi
    done

    for filename in lt lv
    do
      cp -R -L $X_PATH/$fontname$fontsize-ISO8859-13.pcf.gz packages/keymaps-$filename/full/x-common/lib/X11/fonts/75dpi
    done

    for filename in tr
    do
      cp -R -L $X_PATH/$fontname$fontsize-ISO8859-9.pcf.gz packages/keymaps-$filename/full/x-common/lib/X11/fonts/75dpi
    done
  done
done
