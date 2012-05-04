cd ../../packages

for filename in `find . -name "*.so*"`
do
	if [ ! -h $filename ] ; then
		checkfile=`basename $filename`
		strip --strip-all -R .note -R .comment $filename
	fi
done

for filename in `find . -name "*.dpi"`
do
	if [ ! -h $filename ] ; then
		checkfile=`basename $filename`
		strip --strip-all -R .note -R .comment $filename
	fi
done
