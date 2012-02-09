SOURCE_PATH=`cat ../SOURCE_PATH`
GCONV_PATH=$SOURCE_PATH/glibc-2.3.5-obj/iconvdata
TOOLS_PATH=../tools

for filename in pt_br de de_ch da es en_us en_nz en_gb fr fr_be fr_ca fr_ch it nl nl_be nb pt sv sv_fi et en_in la
do
	mkdir packages/keymaps-$filename/full/base/lib/gconv
	cp $GCONV_PATH/ISO8859-1.so packages/keymaps-$filename/full/base/lib/gconv
	cp ./gconv-modules packages/keymaps-$filename/full/base/lib/gconv
done


for filename in cs pl ro sl hr hu
do
	mkdir packages/keymaps-$filename/full/base/lib/gconv
	cp $GCONV_PATH/ISO8859-2.so packages/keymaps-$filename/full/base/lib/gconv
	cp ./gconv-modules packages/keymaps-$filename/full/base/lib/gconv
done

for filename in ja
do
	mkdir packages/keymaps-$filename/full/base/lib/gconv
	cp $GCONV_PATH/EUC-JP.so packages/keymaps-$filename/full/base/lib/gconv
	cp ./gconv-modules packages/keymaps-$filename/full/base/lib/gconv
done

for filename in lt lv
do
	mkdir packages/keymaps-$filename/full/base/lib/gconv
	cp $GCONV_PATH/ISO8859-13.so packages/keymaps-$filename/full/base/lib/gconv
	cp ./gconv-modules packages/keymaps-$filename/full/base/lib/gconv
done

for filename in mk ru
do
	mkdir packages/keymaps-$filename/full/base/lib/gconv
	cp $GCONV_PATH/ISO8859-5.so packages/keymaps-$filename/full/base/lib/gconv
	cp ./gconv-modules packages/keymaps-$filename/full/base/lib/gconv
done

for filename in ar
do
	mkdir packages/keymaps-$filename/full/base/lib/gconv
	cp $GCONV_PATH/ISO8859-6.so packages/keymaps-$filename/full/base/lib/gconv
	cp ./gconv-modules packages/keymaps-$filename/full/base/lib/gconv
done

for filename in th
do
	mkdir packages/keymaps-$filename/full/base/lib/gconv
	cp $GCONV_PATH/TIS-620.so packages/keymaps-$filename/full/base/lib/gconv
	cp ./gconv-modules packages/keymaps-$filename/full/base/lib/gconv
done

for filename in tr
do
	mkdir packages/keymaps-$filename/full/base/lib/gconv
	cp $GCONV_PATH/ISO8859-9.so packages/keymaps-$filename/full/base/lib/gconv
	cp ./gconv-modules packages/keymaps-$filename/full/base/lib/gconv
done

