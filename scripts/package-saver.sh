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

# Bundle Homebrew dylibs so the saver loads on Macs without Homebrew.
# @loader_path (not @executable_path): the saver is loaded by legacyScreenSaver,
# so paths must resolve relative to the saver binary itself.
# The bundle is patched in place (unlike the app, which is rebuilt from the
# bare binary each time), so skip when a previous run already patched it —
# a fresh CMake link resets the binary to /opt/homebrew paths and re-triggers.
if otool -L "$SAVER/Contents/MacOS/Insaniquarium" | grep -q /opt/homebrew; then
	dylibbundler -of -cd -b \
		-x "$SAVER/Contents/MacOS/Insaniquarium" \
		-d "$SAVER/Contents/Frameworks" \
		-p @loader_path/../Frameworks/ >/dev/null
fi
if otool -L "$SAVER/Contents/MacOS/Insaniquarium" | grep -q /opt/homebrew; then
	echo "error: saver still links /opt/homebrew dylibs after dylibbundler"; exit 1
fi

codesign --force --deep -s - "$SAVER"
echo "packaged $SAVER"

if [ "${1:-}" = "--install" ]; then
	DEST="$HOME/Library/Screen Savers/Insaniquarium.saver"
	rm -rf "$DEST"
	cp -R "$SAVER" "$DEST"
	echo "installed $DEST"
fi
