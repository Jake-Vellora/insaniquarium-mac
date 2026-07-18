#!/bin/bash
# M11-B: inject a native macOS launch entry for appid 3320 so its real Steam
# library Play button launches /Applications/Insaniquarium.app.
# Steam MUST be quit. Everything here is backed up and reversible (revert.sh).
set -euo pipefail
cd "$(dirname "$0")"

STEAM="$HOME/Library/Application Support/Steam"
APPINFO="$STEAM/appcache/appinfo.vdf"
STEAMID="76561198055754049"
GID="4977529675831131285"       # depot 3321 public manifest (up-to-date => no download)
BUILDID="250752"
INSTALLDIR="Insaniquarium Deluxe"

if pgrep -x steam_osx >/dev/null; then
  echo "error: Steam is running — quit it first (osascript -e 'quit app \"Steam\"')"; exit 1
fi

# 1. Back up appinfo.vdf (timestamped + a stable .orig for revert)
BAK="$APPINFO.bak.$(date +%s)"
cp "$APPINFO" "$BAK"
[ -f "$APPINFO.orig" ] || cp "$APPINFO" "$APPINFO.orig"
echo "backed up appinfo.vdf -> $BAK"

# 2. Inject oslist + macos launch entry (recomputes size + both SHA-1s)
python3 edit_appinfo.py inject "$APPINFO"

# 3. Install dir + direct-exec symlink to the app binary (preserves the
#    Steam overlay's DYLD injection, which a shell wrapper would strip).
mkdir -p "$STEAM/steamapps/common/$INSTALLDIR"
ln -sf /Applications/Insaniquarium.app/Contents/MacOS/insaniquarium \
       "$STEAM/steamapps/common/$INSTALLDIR/insaniquarium"
cp run.sh "$STEAM/steamapps/common/$INSTALLDIR/run.sh"   # kept as a fallback
chmod +x "$STEAM/steamapps/common/$INSTALLDIR/run.sh"
echo "installed launch symlink + run.sh fallback into steamapps/common/$INSTALLDIR"

# 4. Fully-installed manifest (StateFlags 4). Correct gid => Steam sees it as
#    up to date and does not queue a download. No platform_override.
cat > "$STEAM/steamapps/appmanifest_3320.acf" <<EOF
"AppState"
{
	"appid"		"3320"
	"Universe"		"1"
	"name"		"Insaniquarium! Deluxe"
	"StateFlags"		"4"
	"installdir"		"$INSTALLDIR"
	"LastUpdated"		"$(date +%s)"
	"SizeOnDisk"		"19098646"
	"buildid"		"$BUILDID"
	"LastOwner"		"$STEAMID"
	"AutoUpdateBehavior"		"1"
	"AllowOtherDownloadsWhileRunning"		"0"
	"ScheduledAutoUpdate"		"0"
	"InstalledDepots"
	{
		"3321"
		{
			"manifest"		"$GID"
			"size"		"19098646"
		}
	}
}
EOF
echo "wrote appmanifest_3320.acf (StateFlags 4)"
echo
echo "done. Start Steam, check appid 3320 shows Play, click it."
echo "proof of launch: ~/iq_play_marker.txt"
