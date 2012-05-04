for filename in `find ../../packages`
do
  file $filename | grep "ELF 32-bit LSB executable" | grep -v "busybox" | grep -v tclkit > /dev/null
  if [ $? = 0 ]; then
	  echo $filename
		strip --strip-all -R .note -R .comment $filename
  fi
done
