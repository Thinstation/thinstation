#!/bin/sh

VERSION="#VER#"
OUT="$1"

echo "const char iw_version[] = \"$VERSION\";" > "$OUT"
