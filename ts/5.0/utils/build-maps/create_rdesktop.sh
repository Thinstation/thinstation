SOURCE_PATH=`cat ../SOURCE_PATH`
RDESKTOP_PATH=$SOURCE_PATH/rdesktop-1.5.0-rc1/keymaps

for filename in `ls kmaps | grep -v xkm`
do
	name=`echo $filename | sed -e 's/\_/-/g'`
  mkdir packages/keymaps-$filename/rdesktop
  mkdir packages/keymaps-$filename/rdesktop/lib
  mkdir packages/keymaps-$filename/rdesktop/lib/kmaps
  mkdir packages/keymaps-$filename/rdesktop/lib/kmaps/keymaps
  ln -s /lib/kmaps packages/keymaps-$filename/rdesktop/lib/kmaps/rdesktop
  cp $RDESKTOP_PATH/common packages/keymaps-$filename/rdesktop/lib/kmaps/keymaps
  cp $RDESKTOP_PATH/modifiers packages/keymaps-$filename/rdesktop/lib/kmaps/keymaps

  case $filename in
  nl_be)
    cp $RDESKTOP_PATH/fr-be packages/keymaps-$filename/rdesktop/lib/kmaps/keymaps/$filename
  ;;
  nl)
    cp $RDESKTOP_PATH/fr-be packages/keymaps-$filename/rdesktop/lib/kmaps/keymaps/$filename
  ;;
  nb)
    cp $RDESKTOP_PATH/no packages/keymaps-$filename/rdesktop/lib/kmaps/keymaps/$filename
  ;;
  sv_fi)
    cp $RDESKTOP_PATH/sv packages/keymaps-$filename/rdesktop/lib/kmaps/keymaps/$filename
  ;;
  en_nz)
    cp $RDESKTOP_PATH/en-gb packages/keymaps-$filename/rdesktop/lib/kmaps/keymaps/$filename
  ;;
  en_in)
    cp $RDESKTOP_PATH/en-us packages/keymaps-$filename/rdesktop/lib/kmaps/keymaps/$filename
  ;;
  *)
  cp $RDESKTOP_PATH/$name packages/keymaps-$filename/rdesktop/lib/kmaps/keymaps/$filename
  ;;
  esac
done

