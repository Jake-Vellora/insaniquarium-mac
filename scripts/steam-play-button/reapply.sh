#!/bin/bash
# Durability: keep appid 3320's injected macOS record present so the real
# Steam Play button survives. Two jobs:
#
#  1. Keep the ON-DISK appinfo.vdf injected at ALL times - even while Steam
#     runs. The running client never re-reads the file mid-session, so a disk
#     repair is invisible to it; what it buys is that EVERY Steam start boots
#     from an injected record. (The client can still refetch pristine metadata
#     mid-session - the Play button then degrades until the next Steam
#     restart, which now always heals instantly, with no timing race.)
#  2. When Steam is NOT running, also ensure the manifest via
#     inject.sh --phase finalize (never fight the client over its own acf).
#
# Loop-safe: when the record is already injected the editor changes nothing,
# cmp sees no diff, nothing is written - so the WatchPaths trigger cannot
# loop on our own edits. The write is atomic (edit a temp copy, rename over)
# so a booting Steam can never read a half-written cache.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
STEAM="$HOME/Library/Application Support/Steam"
APPINFO="$STEAM/appcache/appinfo.vdf"
INSTALLDIR="Insaniquarium Deluxe"

[ -f "$APPINFO" ] || exit 0

TMP="$APPINFO.reapply.$$"
trap 'rm -f "$TMP"' EXIT
cp "$APPINFO" "$TMP"
if ! python3 "$DIR/edit_appinfo.py" inject "$TMP" >/dev/null 2>&1; then
  exit 0   # unparseable snapshot (Steam mid-write?) - the next fire retries
fi
if ! cmp -s "$TMP" "$APPINFO"; then
  mv "$TMP" "$APPINFO"
  trap - EXIT
  echo "$(date '+%F %T') re-injected appinfo (steam $(pgrep -x steam_osx >/dev/null && echo running || echo quit))"
fi

# The launch symlink is safe to ensure at any time.
mkdir -p "$STEAM/steamapps/common/$INSTALLDIR"
[ -e "$STEAM/steamapps/common/$INSTALLDIR/insaniquarium" ] || \
  ln -sf /Applications/Insaniquarium.app/Contents/MacOS/insaniquarium \
         "$STEAM/steamapps/common/$INSTALLDIR/insaniquarium"

# Manifest/run.sh (acf writes) only while Steam is closed.
if ! pgrep -x steam_osx >/dev/null; then
  "$DIR/inject.sh" --phase finalize >/dev/null 2>&1 || true
fi
