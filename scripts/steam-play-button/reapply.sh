#!/bin/bash
# Durability: keep appid 3320's macOS launch entry present so its real Steam
# Play button survives Steam's appinfo re-sync. Only acts when Steam is NOT
# running (editing appinfo mid-session is pointless — Steam has it cached and
# rewrites on exit). Idempotent: writes only when the edit is actually missing,
# so a file-watch trigger cannot loop on its own edits.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
STEAM="$HOME/Library/Application Support/Steam"
APPINFO="$STEAM/appcache/appinfo.vdf"
INSTALLDIR="Insaniquarium Deluxe"

# Don't touch appinfo while Steam is running.
pgrep -x steam_osx >/dev/null && exit 0
[ -f "$APPINFO" ] || exit 0

# edit_appinfo directly (not inject.sh --phase appinfo) to avoid a .bak file
# per WatchPaths fire; the .orig from the first inject already exists.
python3 "$DIR/edit_appinfo.py" inject "$APPINFO" >/dev/null 2>&1 || exit 0

# Ensure symlink + manifest are present (idempotent; keeps a Steam-written acf).
"$DIR/inject.sh" --phase finalize >/dev/null 2>&1 || true
