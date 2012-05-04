SOURCE_PATH=`cat ../SOURCE_PATH`
GLIB_PATH=$SOURCE_PATH/glibc-2.3.5-obj

cp -f $GLIB_PATH/elf/ld.so ../../packages/lib/ld-2.3.5.so
cp -f $GLIB_PATH/resolv/libnss_dns.so ../../packages/lib/libnss_dns-2.3.5.so
cp -f $GLIB_PATH/resolv/libnss_dns.so ../../packages/base/lib/libnss_dns-2.3.5.so
cp -f $GLIB_PATH/dlfcn/libdl.so ../../packages/lib/libdl-2.3.5.so
cp -f $GLIB_PATH/nss/libnss_files.so ../../packages/lib/libnss_files-2.3.5.so
cp -f $GLIB_PATH/nss/libnss_files.so ../../packages/base/lib/libnss_files-2.3.5.so
cp -f $GLIB_PATH/resolv/libresolv.so ../../packages/lib/libresolv-2.3.5.so
cp -f $GLIB_PATH/login/libutil.so ../../packages/lib/libutil-2.3.5.so
cp -f $GLIB_PATH/crypt/libcrypt.so ../../packages/lib/libcrypt-2.3.5.so
cp -f $GLIB_PATH/libc.so ../../packages/lib/libc-2.3.5.so
cp -f $GLIB_PATH/nis/libnsl.so ../../packages/lib/libnsl-2.3.5.so
cp -f $GLIB_PATH/math/libm.so ../../packages/lib/libm-2.3.5.so
cp -f $GLIB_PATH/nptl/libpthread.so ../../packages/lib/libpthread-2.3.5.so
cp -f $GLIB_PATH/resolv/libnss_dns.so ../../packages/base/lib/libnss_dns-2.3.5.so
cp -f $GLIB_PATH/nss/libnss_files.so ../../packages/base/lib/libnss_files-2.3.5.so
cp -f $GLIB_PATH/rt/librt.so.1 ../../packages/base/lib/librt-2.3.5.so
cp -f $GLIB_PATH/iconvdata/UNICODE.so ../../packages/ica/lib/gconv
