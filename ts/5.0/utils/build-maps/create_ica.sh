SOURCE_PATH=`cat ../SOURCE_PATH`

for filename in `ls locale`
do
  case $filename in
    pt_BR|fr_BE|fr_CA|fr_CH|nl_BE|sv_FI|en_US|en_NZ|en_GB|de_CH|en_IN)
    localedir=`echo $filename | tr "[A-Z]" "[a-z]"`
  ;;
  *)
    localedir=`echo $filename | cut -d"_" -f1 | tr "[A-Z]" "[a-z]"`
  ;;
  esac
  mkdir packages/keymaps-$localedir/full/ica_wfc
  mkdir packages/keymaps-$localedir/full/ica_wfc/share
  mkdir packages/keymaps-$localedir/full/ica_wfc/share/locale
  mkdir packages/keymaps-$localedir/full/ica_wfc/share/locale/$filename
  cp -a ica/pna.nls packages/keymaps-$localedir/full/ica_wfc/share/locale/$filename
done

