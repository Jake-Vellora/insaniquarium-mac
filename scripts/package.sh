#!/bin/bash
# Assemble a relocatable Insaniquarium.app from the built binary + staged assets.
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD=${1:-build}
APP="$BUILD/Insaniquarium.app"
BIN="$BUILD/insaniquarium"

[ -f "$BIN" ] || { echo "error: $BIN not built"; exit 1; }
[ -d "$BUILD/assets" ] || { echo "error: $BUILD/assets not staged"; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp packaging/Info.plist "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/insaniquarium"
[ -f packaging/Insaniquarium.icns ] && cp packaging/Insaniquarium.icns "$APP/Contents/Resources/"

# Assets live directly in Contents/Resources (= SDL_GetBasePath in a bundle)
for d in images sounds music fishsongs data properties; do
	cp -R "$BUILD/assets/$d" "$APP/Contents/Resources/$d"
done

# Bundle Homebrew dylibs and re-sign (ad-hoc; required on arm64)
dylibbundler -of -cd -b \
	-x "$APP/Contents/MacOS/insaniquarium" \
	-d "$APP/Contents/Frameworks" \
	-p @executable_path/../Frameworks/ >/dev/null

# Steamworks presence (appid 3320): bundled only if the SDK dylib has been
# dropped in packaging/ (needs a free Steamworks login to download).
if [ -f packaging/libsteam_api.dylib ]; then
	cp packaging/libsteam_api.dylib "$APP/Contents/Frameworks/"
	echo "bundled libsteam_api.dylib (Steam presence enabled)"
else
	echo "note: packaging/libsteam_api.dylib not found — Steam presence disabled"
fi

codesign --force --deep -s - "$APP"

echo "packaged $APP"
