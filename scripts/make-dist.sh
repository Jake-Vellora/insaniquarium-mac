#!/bin/bash
# Build the private distributable tarball (payload mode of setup.sh):
# prebuilt asset-free app + saver skeletons, the Steam-patch scripts, setup.sh,
# README, and (by default) git bundles of all three repos for provenance.
# The tarball contains NO game assets - the recipient's own Steam supplies them.
# Usage: make-dist.sh [--no-source]
set -euo pipefail
cd "$(dirname "$0")/.."

NOSOURCE=0; RELEASE_TAG=""
while [ $# -gt 0 ]; do
	case "$1" in
		--no-source) NOSOURCE=1; shift;;
		--release) RELEASE_TAG="${2:?--release needs a tag}"; shift 2;;
		*) echo "usage: make-dist.sh [--no-source] [--release <tag>]"; exit 2;;
	esac
done
# The release tag is the updater's staleness key (written to $PORTHOME/RELEASE
# on install). release.sh passes the real git tag; dev builds get a throwaway.
TAG="${RELEASE_TAG:-dev-$(date +%Y%m%d-%H%M%S)}"

# 1. Fresh build + packages
cmake --build build --target insaniquarium insaniquarium-saver
scripts/package.sh
scripts/package-saver.sh

DIST=build/dist/insaniquarium-mac-dist
rm -rf build/dist
mkdir -p "$DIST/payload" "$DIST/scripts/sme"

# 2. Asset-free skeletons. Deleting the asset dirs breaks the codesign seal,
#    so each skeleton is re-signed and must verify on its own.
for b in Insaniquarium.app Insaniquarium.saver; do
	ditto "build/$b" "$DIST/payload/$b"
	for d in images sounds music fishsongs data properties; do
		rm -rf "$DIST/payload/$b/Contents/Resources/$d"
	done
	codesign --force --deep -s - "$DIST/payload/$b"
done

# 3. Scripts (exactly what setup.sh needs; sme ships only appinfo.py + notice)
for f in edit_appinfo.py inject.sh reapply.sh install-durability.sh update.sh in-app-update.sh \
         com.jake.insaniquarium.steampatch.plist run.sh uninstall.sh; do
	cp "scripts/steam-play-button/$f" "$DIST/scripts/"
done
cp scripts/steam-play-button/sme/appinfo.py "$DIST/scripts/sme/"
cp scripts/steam-play-button/sme/NOTICE "$DIST/scripts/sme/"
cp setup.sh "$DIST/setup.sh"
cp scripts/dist/README.md "$DIST/README.md"
cp VERSIONS "$DIST/VERSIONS"
cp "scripts/dist/Update Insaniquarium.command" "$DIST/"
printf '%s\n' "$TAG" > "$DIST/RELEASE"
chmod +x "$DIST/setup.sh" "$DIST/scripts/"*.sh "$DIST/Update Insaniquarium.command"

# 4. Source bundles - the only way to rebuild if the dev machine dies
if [ "$NOSOURCE" = 0 ]; then
	mkdir -p "$DIST/src"
	git bundle create "$DIST/src/insaniquarium-mac.bundle" --all
	git -C WinFish bundle create "$PWD/$DIST/src/WinFish.bundle" mac-port
	git -C PvZ-Portable bundle create "$PWD/$DIST/src/PvZ-Portable.bundle" mac-port
	{
		echo "built: $(date '+%Y-%m-%d %H:%M:%S')"
		echo "host: macOS $(sw_vers -productVersion), $(uname -m)"
		echo "insaniquarium-mac: $(git rev-parse HEAD)"
		echo "WinFish: $(git -C WinFish rev-parse mac-port)"
		echo "PvZ-Portable: $(git -C PvZ-Portable rev-parse mac-port)"
	} > "$DIST/src/VERSION"
fi

# 5. Gates: fail loudly rather than ship a broken or non-clean tarball
for b in Insaniquarium.app Insaniquarium.saver; do
	codesign --verify --deep --strict "$DIST/payload/$b"
	if otool -L "$DIST/payload/$b/Contents/MacOS/"* | grep -q /opt/homebrew; then
		echo "error: $b links /opt/homebrew dylibs - not relocatable"; exit 1
	fi
	for d in images sounds music fishsongs data properties; do
		if [ -e "$DIST/payload/$b/Contents/Resources/$d" ]; then
			echo "error: $b still contains asset dir '$d' - must ship asset-free"; exit 1
		fi
	done
done
[ -f "$DIST/payload/Insaniquarium.app/Contents/Frameworks/libsteam_api.dylib" ] || {
	echo "error: libsteam_api.dylib missing from app Frameworks"; exit 1; }

# 6. Checksums + tarball (+ a sidecar that checksums the tarball as a whole,
#    which the updater verifies before installing)
(cd "$DIST" && find . -type f ! -name SHA256SUMS -exec shasum -a 256 {} + > SHA256SUMS)
OUT="build/dist/insaniquarium-mac-${TAG}.tar.gz"
tar -czf "$OUT" -C build/dist insaniquarium-mac-dist
(cd "$(dirname "$OUT")" && shasum -a 256 "$(basename "$OUT")" > "$(basename "$OUT").sha256")
echo
echo "dist ready: $OUT ($(du -h "$OUT" | cut -f1)), release tag: $TAG"
