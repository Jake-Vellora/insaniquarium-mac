#!/bin/bash
# Stage assets into Insaniquarium.saver, sign it, optionally install.
# Usage: package-saver.sh [--install]
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD=build
SAVER="$BUILD/Insaniquarium.saver"

[ -d "$SAVER" ] || { echo "error: $SAVER not built"; exit 1; }
[ -d "$BUILD/assets" ] || { echo "error: $BUILD/assets not staged"; exit 1; }

mkdir -p "$SAVER/Contents/Resources"
for d in images sounds music fishsongs data properties; do
	rm -rf "$SAVER/Contents/Resources/$d"
	cp -R "$BUILD/assets/$d" "$SAVER/Contents/Resources/$d"
done
[ -f packaging/Insaniquarium.icns ] && cp packaging/Insaniquarium.icns "$SAVER/Contents/Resources/thumbnail.icns"

codesign --force --deep -s - "$SAVER"
echo "packaged $SAVER"

if [ "${1:-}" = "--install" ]; then
	DEST="$HOME/Library/Screen Savers/Insaniquarium.saver"
	rm -rf "$DEST"
	cp -R "$SAVER" "$DEST"
	echo "installed $DEST"
fi
