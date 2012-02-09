SOURCE_PATH=`cat ../SOURCE_PATH`
LOCALE_PATH=$SOURCE_PATH/glibc-2.3.5-obj
LOCALE_PATH=$SOURCE_PATH/glibc-2.3.5
TOOLS_PATH=../tools

if [ -h ./i18n ] ; then
	rm i18n
fi

if [ ! -e ./locale ] ; then
	mkdir locale
else
	rm -Rf locale/*
fi

I18NPATH=./i18n ; export I18NPATH

ln -s $LOCALE_PATH/localedata i18n

for filename in pt_BR de_DE de_CH da_DK es_ES en_US en_NZ en_GB fr_FR fr_BE fr_CA fr_CH it_IT nl_NL nl_BE nb_NO pt_PT sv_SE sv_FI et_EE
do
$TOOLS_PATH/localedef -i $LOCALE_PATH/localedata/locales/$filename -f $LOCALE_PATH/localedata/charmaps/ISO-8859-1 locale/$filename
done

for filename in en_IN
do
$TOOLS_PATH/localedef -i $LOCALE_PATH/localedata/locales/en_US -f $LOCALE_PATH/localedata/charmaps/ISO-8859-1 locale/$filename
done

for filename in la
do
$TOOLS_PATH/localedef -i $LOCALE_PATH/localedata/locales/it_IT -f $LOCALE_PATH/localedata/charmaps/ISO-8859-1 locale/$filename
done

for filename in cs_CZ pl_PL ro_RO sl_SI hr_HR hu_HU
do
$TOOLS_PATH/localedef -i $LOCALE_PATH/localedata/locales/$filename -f $LOCALE_PATH/localedata/charmaps/ISO-8859-2 locale/$filename
done

for filename in ja_JP
do
$TOOLS_PATH/localedef -i $LOCALE_PATH/localedata/locales/$filename -f $LOCALE_PATH/localedata/charmaps/EUC-JP locale/$filename
done

for filename in lt_LT lv_LV
do
$TOOLS_PATH/localedef -i $LOCALE_PATH/localedata/locales/$filename -f $LOCALE_PATH/localedata/charmaps/ISO-8859-13 locale/$filename
done

for filename in mk_MK ru_RU
do
$TOOLS_PATH/localedef -i $LOCALE_PATH/localedata/locales/$filename -f $LOCALE_PATH/localedata/charmaps/ISO-8859-5 locale/$filename
done

for filename in ar_SA
do
$TOOLS_PATH/localedef -i $LOCALE_PATH/localedata/locales/$filename -f $LOCALE_PATH/localedata/charmaps/ISO-8859-6 locale/$filename
done

for filename in th_TH
do
$TOOLS_PATH/localedef -i $LOCALE_PATH/localedata/locales/$filename -f $LOCALE_PATH/localedata/charmaps/TIS-620 locale/$filename
done

for filename in tr_TR
do
$TOOLS_PATH/localedef -i $LOCALE_PATH/localedata/locales/$filename -f $LOCALE_PATH/localedata/charmaps/ISO-8859-9 locale/$filename
done

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
  mkdir packages/keymaps-$localedir/full
  mkdir packages/keymaps-$localedir/full/base
  mkdir packages/keymaps-$localedir/full/base/lib
  mkdir packages/keymaps-$localedir/full/base/lib/locale
  cp -a locale/$filename packages/keymaps-$localedir/full/base/lib/locale/
  echo "LC_ALL=$filename ; export LC_ALL" > packages/keymaps-$localedir/full/base/lib/locale/$localedir"_locale"
  echo "LANG=$filename ; export LANG" >> packages/keymaps-$localedir/full/base/lib/locale/$localedir"_locale"
done
