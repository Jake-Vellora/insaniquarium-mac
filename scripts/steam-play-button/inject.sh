#!/bin/bash
# Inject the native macOS launch entry for appid 3320 so its real Steam
# library Play button launches /Applications/Insaniquarium.app.
# Steam MUST be quit. Everything here is backed up and reversible (revert.sh /
# uninstall.sh).
#
# Usage: inject.sh [--phase appinfo|pending|finalize|all] [--owner <steamid64>]
#   appinfo   patch appinfo.vdf only (oslist + launch entries). setup.sh runs
#             this BEFORE asset download so Steam treats 3320 as macOS-native.
#   pending   write an update-required appmanifest (StateFlags 2). On the next
#             steam://run/3320, Steam downloads depot 3321 itself — the only
#             asset-acquisition path that works: the install wizard and
#             validate both force a fresh per-app metadata fetch that reverts
#             the appinfo edit before acting ("Invalid platform"), while the
#             run-path updater uses the already-loaded record. Verified live.
#   finalize  install-dir symlink + run.sh fallback + appmanifest (written only
#             if Steam didn't already write a fully-installed one itself).
#   all       appinfo + finalize (default; the original single-shot behavior).
set -euo pipefail
cd "$(dirname "$0")"

STEAM="$HOME/Library/Application Support/Steam"
APPINFO="$STEAM/appcache/appinfo.vdf"
GID="4977529675831131285"       # depot 3321 public manifest (up-to-date => no download)
BUILDID="250752"
INSTALLDIR="Insaniquarium Deluxe"

PHASE=all
OWNER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --phase) PHASE="${2:?}"; shift 2;;
    --owner) OWNER="${2:?}"; shift 2;;
    *) echo "usage: inject.sh [--phase appinfo|pending|finalize|all] [--owner <steamid64>]"; exit 2;;
  esac
done
case "$PHASE" in appinfo|pending|finalize|all) ;; *) echo "error: bad --phase '$PHASE'"; exit 2;; esac

if pgrep -x steam_osx >/dev/null; then
  echo "error: Steam is running — quit it first (osascript -e 'quit app \"Steam\"')"; exit 1
fi
[ -f "$APPINFO" ] || { echo "error: $APPINFO not found — is Steam installed and signed in?"; exit 1; }

# SteamID64 of the local user, for the appmanifest's LastOwner field.
# Prefer loginusers.vdf's MostRecent entry (keys are already SteamID64s);
# fall back to the sole userdata account id + Steam's ID64 base constant.
detect_steamid() {
  if [ -n "$OWNER" ]; then echo "$OWNER"; return; fi
  python3 - "$STEAM" <<'EOF'
import os, re, sys
steam = sys.argv[1]
try:
    txt = open(os.path.join(steam, "config", "loginusers.vdf"),
               encoding="utf-8", errors="replace").read()
    users = re.findall(r'"(\d{17})"\s*\{(.*?)\}', txt, re.S)
    for sid, body in users:
        if re.search(r'"MostRecent"\s*"1"', body):
            print(sid); sys.exit()
    if len(users) == 1:
        print(users[0][0]); sys.exit()
except OSError:
    pass
try:
    ids = [d for d in os.listdir(os.path.join(steam, "userdata"))
           if d.isdigit() and d != "0"]
    if len(ids) == 1:
        print(int(ids[0]) + 76561197960265728)
except OSError:
    pass
EOF
}

do_appinfo() {
  local bak="$APPINFO.bak.$(date +%s)"
  cp "$APPINFO" "$bak"
  [ -f "$APPINFO.orig" ] || cp "$APPINFO" "$APPINFO.orig"
  echo "backed up appinfo.vdf -> $bak"
  python3 edit_appinfo.py inject "$APPINFO"
}

do_pending() {
  local acf="$STEAM/steamapps/appmanifest_3320.acf"
  if [ -f "$acf" ] && grep -q '"StateFlags"[[:space:]]*"4"' "$acf"; then
    echo "appmanifest already fully installed; leaving it alone"
    return
  fi
  local steamid
  steamid="$(detect_steamid)"
  if [ -z "$steamid" ]; then
    echo "error: could not detect your SteamID64 (no loginusers.vdf / userdata)."
    echo "       rerun: inject.sh --phase pending --owner <your steamid64>"
    exit 1
  fi
  cat > "$acf" <<EOF
"AppState"
{
	"appid"		"3320"
	"Universe"		"1"
	"name"		"Insaniquarium! Deluxe"
	"StateFlags"		"2"
	"installdir"		"$INSTALLDIR"
	"buildid"		"0"
	"LastOwner"		"$steamid"
	"AutoUpdateBehavior"		"0"
	"AllowOtherDownloadsWhileRunning"		"0"
	"ScheduledAutoUpdate"		"0"
}
EOF
  echo "wrote pending appmanifest (StateFlags 2) — steam://run/3320 will download the depot"
}

do_finalize() {
  # Direct-exec symlink to the app binary (preserves the Steam overlay's DYLD
  # injection, which a shell wrapper would strip). run.sh kept as a fallback.
  mkdir -p "$STEAM/steamapps/common/$INSTALLDIR"
  ln -sf /Applications/Insaniquarium.app/Contents/MacOS/insaniquarium \
         "$STEAM/steamapps/common/$INSTALLDIR/insaniquarium"
  cp run.sh "$STEAM/steamapps/common/$INSTALLDIR/run.sh"
  chmod +x "$STEAM/steamapps/common/$INSTALLDIR/run.sh"
  echo "installed launch symlink + run.sh fallback into steamapps/common/$INSTALLDIR"

  local acf="$STEAM/steamapps/appmanifest_3320.acf"
  # If Steam wrote a fully-installed manifest itself (the user clicked Install
  # after the appinfo phase), keep it verbatim — Steam's own LastOwner is the
  # ground truth, which matters on Family Sharing machines.
  if [ -f "$acf" ] && grep -q '"StateFlags"[[:space:]]*"4"' "$acf" \
                   && grep -q "\"installdir\"[[:space:]]*\"$INSTALLDIR\"" "$acf"; then
    echo "keeping existing appmanifest_3320.acf (fully installed)"
    return
  fi

  local steamid
  steamid="$(detect_steamid)"
  if [ -z "$steamid" ]; then
    echo "error: could not detect your SteamID64 (no loginusers.vdf / userdata)."
    echo "       rerun: inject.sh --phase finalize --owner <your steamid64>"
    exit 1
  fi
  # Fully-installed manifest (StateFlags 4). Correct gid => Steam sees it as
  # up to date and does not queue a download. No platform_override.
  cat > "$acf" <<EOF
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
	"LastOwner"		"$steamid"
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
  echo "wrote appmanifest_3320.acf (StateFlags 4, LastOwner $steamid)"
}

case "$PHASE" in
  appinfo)  do_appinfo;;
  pending)  do_pending;;
  finalize) do_finalize;;
  all)      do_appinfo; do_finalize;;
esac

if [ "$PHASE" = all ]; then
  echo
  echo "done. Start Steam, check appid 3320 shows Play, click it."
fi
