#!/bin/bash
# Undo M11 appinfo injection. Steam MUST be quit. Leaves the non-Steam
# shortcut + Steamworks presence untouched (they are independent).
set -euo pipefail
cd "$(dirname "$0")"

STEAM="$HOME/Library/Application Support/Steam"
APPINFO="$STEAM/appcache/appinfo.vdf"
INSTALLDIR="Insaniquarium Deluxe"

if pgrep -x steam_osx >/dev/null; then
  echo "error: Steam is running — quit it first"; exit 1
fi

# Prefer the pristine .orig; fall back to editing the keys back out.
if [ -f "$APPINFO.orig" ]; then
  cp "$APPINFO.orig" "$APPINFO"
  echo "restored appinfo.vdf from .orig"
else
  python3 edit_appinfo.py revert "$APPINFO"
fi

rm -f "$STEAM/steamapps/appmanifest_3320.acf"
rm -rf "$STEAM/steamapps/common/$INSTALLDIR"
echo "removed appmanifest_3320.acf and install dir"

# Remove durability LaunchAgent if installed
AGENT="$HOME/Library/LaunchAgents/com.jake.insaniquarium.steampatch.plist"
if [ -f "$AGENT" ]; then
  launchctl unload "$AGENT" 2>/dev/null || true
  rm -f "$AGENT"
  echo "removed durability LaunchAgent"
fi
echo "revert complete."
