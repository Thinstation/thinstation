./create_kmaps.sh
./create_rdesktop.sh
./create_locales.sh
./create_ica.sh
./create_x11.sh
./create_fonts.sh
./create_gconv.sh
rm -R ../../packages/keymaps-*
mv packages/* ../../packages
rm -R locale/*
rm -R kmaps/*
