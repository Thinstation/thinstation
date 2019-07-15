#!/bin/sh
file=$1
signed=/`basename $1`.signed
set -x

# Sign
rm -f /$1.signed
openssl rsa -in signing.key -pubout -out /tmp/public.key

SIZE=$(stat -c%s $1)
BLOCKS=$(( $SIZE / 512 ))
if [ $(( $BLOCKS * 512 )) -lt $SIZE ]; then
	let BLOCKS+=1
fi
SIZE=$(( $BLOCKS * 512 ))
truncate -s $SIZE $1

openssl dgst -sha512 -sign signing.key -out /tmp/sign.sha512 $1
cat $1 /tmp/sign.sha512 >> $signed

# Verify
SIZE=$(stat -c%s $signed)
let SIZE=$(( SIZE / 512 ))
dd if=$signed of=/tmp/digest bs=512 skip=$((SIZE-1))
dd if=$signed bs=512 count=$((SIZE-1)) | openssl dgst -sha512 -verify /tmp/public.key -signature /tmp/digest
