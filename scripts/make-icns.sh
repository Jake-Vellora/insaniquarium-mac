#!/bin/bash
# Build packaging/Insaniquarium.icns from the game's Windows .ico (256px PNG rep).
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=WinFish/source/WinFish/Insaniquarium.ico
OUT=packaging/Insaniquarium.icns
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# sips picks the largest representation when converting
sips -s format png "$SRC" --out "$TMP/base.png" >/dev/null

ICONSET="$TMP/Insaniquarium.iconset"
mkdir "$ICONSET"
for sz in 16 32 128 256 512; do
	sips -z $sz $sz "$TMP/base.png" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
	dbl=$((sz * 2))
	sips -z $dbl $dbl "$TMP/base.png" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$OUT"
echo "wrote $OUT"
