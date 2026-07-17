#!/bin/bash
# Install the LaunchAgent that keeps appid 3320's macOS launch entry alive
# across Steam's appinfo re-syncs. Run once, after inject.sh has succeeded.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
STEAM="$HOME/Library/Application Support/Steam"
APPINFO="$STEAM/appcache/appinfo.vdf"
AGENT="$HOME/Library/LaunchAgents/com.jake.insaniquarium.steampatch.plist"

chmod +x "$DIR/reapply.sh"
mkdir -p "$HOME/Library/LaunchAgents"
sed -e "s#__REAPPLY_SH__#$DIR/reapply.sh#" \
    -e "s#__APPINFO__#$APPINFO#" \
    "$DIR/com.jake.insaniquarium.steampatch.plist" > "$AGENT"

launchctl unload "$AGENT" 2>/dev/null || true
launchctl load "$AGENT"
echo "installed + loaded $AGENT"
echo "log: /tmp/insaniquarium-steampatch.log"
