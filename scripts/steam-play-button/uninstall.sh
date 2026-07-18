#!/bin/bash
# Fully remove the Insaniquarium native-port setup from this Mac:
# app, screensaver, Steam appinfo edits, manifest, install dir, LaunchAgent.
# Steam MUST be quit.
#
# Usage: uninstall.sh [--pristine] [--purge-saves]
#   --pristine     restore appinfo.vdf from the .orig backup instead of
#                  surgically reverting the 3320 edits (both are safe; appinfo
#                  is a cache Steam re-syncs from its servers anyway)
#   --purge-saves  ALSO delete profiles/tanks (PopCap save dirs) — off by default
set -euo pipefail
cd "$(dirname "$0")"

STEAM="$HOME/Library/Application Support/Steam"
APPINFO="$STEAM/appcache/appinfo.vdf"
INSTALLDIR="Insaniquarium Deluxe"

PRISTINE=0; PURGE=0
for arg in "$@"; do
  case "$arg" in
    --pristine) PRISTINE=1;;
    --purge-saves) PURGE=1;;
    *) echo "usage: uninstall.sh [--pristine] [--purge-saves]"; exit 2;;
  esac
done

if pgrep -x steam_osx >/dev/null; then
  echo "error: Steam is running — quit it first (osascript -e 'quit app \"Steam\"')"; exit 1
fi

# 1. Durability agent FIRST — nothing may reapply while we tear down.
AGENT="$HOME/Library/LaunchAgents/com.jake.insaniquarium.steampatch.plist"
if [ -f "$AGENT" ]; then
  launchctl unload "$AGENT" 2>/dev/null || true
  rm -f "$AGENT"
  echo "removed durability LaunchAgent"
fi

# 2. Steam appinfo edits
if [ "$PRISTINE" = 1 ] && [ -f "$APPINFO.orig" ]; then
  cp "$APPINFO.orig" "$APPINFO"
  echo "restored appinfo.vdf from .orig"
elif [ -f "$APPINFO" ]; then
  python3 edit_appinfo.py revert "$APPINFO" || true
fi

# 3. Manifest + install dir (depot files, symlink, run.sh)
rm -f "$STEAM/steamapps/appmanifest_3320.acf"
rm -rf "$STEAM/steamapps/common/$INSTALLDIR"
echo "removed appmanifest_3320.acf and steamapps/common/$INSTALLDIR"

# 4. App, screensaver, installed scripts
rm -rf /Applications/Insaniquarium.app
rm -rf "$HOME/Library/Screen Savers/Insaniquarium.saver"
rm -rf "$HOME/Library/Application Support/Insaniquarium-port"
echo "removed Insaniquarium.app, Insaniquarium.saver, Insaniquarium-port scripts"

# 5. Saves (opt-in). Only the PopCap subpaths — never the saver container itself.
if [ "$PURGE" = 1 ]; then
  rm -rf "$HOME/Library/Application Support/PopCap/Insaniquarium"
  rm -rf "$HOME/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Application Support/PopCap/Insaniquarium"
  echo "purged save data (game + screensaver container)"
else
  echo "saves kept (~/Library/Application Support/PopCap/Insaniquarium); rerun with --purge-saves to delete"
fi

echo
echo "uninstall complete. Two manual leftovers, both harmless:"
echo "  - System Settings > Privacy & Security > Full Disk Access still lists"
echo "    Insaniquarium (dangling row) — remove it with the minus button."
echo "  - If Insaniquarium was your active screensaver, pick another one."
