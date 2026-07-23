#!/bin/bash
# One-step installer for the native Apple Silicon port of Insaniquarium! Deluxe.
#
# Two modes, auto-detected:
#   payload mode  dist tarball with prebuilt asset-free app/saver in payload/
#   source mode   git clone of the repo; builds locally (Xcode CLT + Homebrew)
#
# Both modes get the game's assets from YOUR OWN Steam copy: the script first
# teaches Steam that appid 3320 has a native macOS build, then Steam's normal
# Install button downloads the game files under your own license (works with
# Family Sharing too). Nothing copyrighted ships with this project.
#
# Usage:
#   ./setup.sh                  full install (interactive; run in Terminal)
#   ./setup.sh --assets <dir>   use an existing "Insaniquarium Deluxe" folder
#   ./setup.sh --console-fetch  fetch assets via Steam's console (owners only)
#   ./setup.sh --update         swap app+saver to the newest build (keeps saves)
#   ./setup.sh verify           health-check an existing install
set -euo pipefail

BASE="$(cd "$(dirname "$0")" && pwd)"
STEAM="$HOME/Library/Application Support/Steam"
APPINFO="$STEAM/appcache/appinfo.vdf"
INSTALLDIR="Insaniquarium Deluxe"
GAMEDIR="$STEAM/steamapps/common/$INSTALLDIR"
APP="/Applications/Insaniquarium.app"
SAVER="$HOME/Library/Screen Savers/Insaniquarium.saver"
PORTHOME="$HOME/Library/Application Support/Insaniquarium-port"
ASSET_DIRS=(images sounds music fishsongs data properties)
BREW_DEPS=(cmake ninja sdl2 libpng jpeg-turbo libogg libvorbis libopenmpt mpg123 dylibbundler)

if [ -d "$BASE/payload/Insaniquarium.app" ]; then MODE=payload; else MODE=source; fi
SP=""
for c in "$BASE/scripts/steam-play-button" "$BASE/scripts"; do
  if [ -f "$c/edit_appinfo.py" ]; then SP="$c"; break; fi
done
[ -n "$SP" ] || { echo "error: steam-play-button scripts not found next to setup.sh" >&2; exit 1; }

say()   { printf '\n\033[1m%s\033[0m\n' "$*"; }
die()   { echo "error: $*" >&2; exit 1; }
# In --yes / non-interactive mode (e.g. the game's in-app "Update Now" handoff),
# every yes/no guard auto-proceeds so an EOF stdin can't stall or abort the run.
ask()   { [ "${NONINTERACTIVE:-0}" = 1 ] && return 0; local a; read -r -p "$1 [y/N] " a; [ "$a" = y ] || [ "$a" = Y ]; }
pause() { read -r -p "$1 (press Enter) " _; }

# Copy that never truncates the destination inode: write a temp beside it, then
# rename over. Safe even when the destination is a script currently being read
# (e.g. update.sh refreshing itself), because the old inode survives open fds.
atomic_copy() { # src dest
  local tmp; tmp="$(dirname "$2")/.$(basename "$2").tmp.$$"
  cp "$1" "$tmp" && mv "$tmp" "$2"
}

steam_running() { pgrep -x steam_osx >/dev/null; }

quit_steam() {
  steam_running || return 0
  ask "Steam is running and must be quit - quit it now?" || die "quit Steam, then rerun"
  osascript -e 'quit app "Steam"' >/dev/null 2>&1 || true
  local i
  for i in $(seq 1 30); do steam_running || return 0; sleep 1; done
  die "Steam did not quit; quit it manually and rerun"
}

valid_assets() {
  [ -f "$1/properties/resources.xml" ] || return 1
  local d
  for d in "${ASSET_DIRS[@]}"; do [ -d "$1/$d" ] || return 1; done
}

preflight() {
  say "[0/6] Preflight"
  [ "$(uname -m)" = arm64 ] || die "this port is Apple Silicon (arm64) only"
  [ "${EUID:-$(id -u)}" -ne 0 ] || die "do not run as root"
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "Apple's Command Line Tools are required (python3$([ "$MODE" = source ] && echo ", compilers"))."
    echo "A system dialog will open - click Install, wait for it, then RERUN ./setup.sh."
    xcode-select --install || true
    exit 1
  fi
  python3 -c 'import hashlib' 2>/dev/null || die "python3 not working - reinstall the Command Line Tools"
  [ -f "$APPINFO" ] || die "Steam not found or never signed in ($APPINFO missing) - install Steam, sign in, rerun"
  if ! python3 "$SP/edit_appinfo.py" show "$APPINFO" >/dev/null 2>&1; then
    cat <<'MSG'
Steam has no cached record of Insaniquarium (appid 3320) yet.
Fix: open Steam, find "Insaniquarium! Deluxe" in your Library (enable the
family-sharing filters if it's a shared game), open its page once, quit
Steam, then rerun ./setup.sh.
MSG
    exit 1
  fi
  quit_steam
}

bootstrap_source() {
  say "[0.5/6] Toolchain + source"
  if ! command -v brew >/dev/null 2>&1 && [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required to build. This runs the official installer from brew.sh."
    ask "Install Homebrew now?" || die "install Homebrew (https://brew.sh), then rerun"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  brew install "${BREW_DEPS[@]}"
  # shellcheck source=VERSIONS
  source "$BASE/VERSIONS"
  clone_pin "$WINFISH_REPO" "$WINFISH_REF" "$BASE/WinFish"
  clone_pin "$PVZ_REPO" "$PVZ_REF" "$BASE/PvZ-Portable"
}

clone_pin() { # repo ref dir
  if [ ! -d "$3/.git" ]; then git clone "$1" "$3"; fi
  git -C "$3" fetch --quiet origin
  git -C "$3" checkout --quiet "$2"
}

install_skeletons() {
  say "[1/6] Installing app + screensaver (asset-free skeletons)"
  pgrep -f "Insaniquarium.app/Contents/MacOS|Insaniquarium Deluxe/insaniquarium" >/dev/null \
    && die "Insaniquarium is running - quit it first"
  rm -rf "$APP"
  ditto "$BASE/payload/Insaniquarium.app" "$APP"
  mkdir -p "$HOME/Library/Screen Savers"
  rm -rf "$SAVER"
  ditto "$BASE/payload/Insaniquarium.saver" "$SAVER"
  # AirDrop/download quarantine propagates through extraction; without this
  # Gatekeeper blocks the ad-hoc binaries (including exec via Steam's symlink).
  xattr -dr com.apple.quarantine "$APP" "$SAVER" 2>/dev/null || true
}

install_scripts() {
  mkdir -p "$PORTHOME/sme"
  local f
  # Atomic (temp+rename) so this can safely overwrite an update.sh / reapply.sh
  # that is currently executing.
  for f in edit_appinfo.py inject.sh reapply.sh install-durability.sh update.sh in-app-update.sh \
           com.jake.insaniquarium.steampatch.plist run.sh uninstall.sh; do
    [ -f "$SP/$f" ] && atomic_copy "$SP/$f" "$PORTHOME/$f"
  done
  atomic_copy "$SP/sme/appinfo.py" "$PORTHOME/sme/appinfo.py"
  if [ -f "$SP/sme/NOTICE" ]; then atomic_copy "$SP/sme/NOTICE" "$PORTHOME/sme/NOTICE"; fi
  chmod +x "$PORTHOME"/*.sh
  # Record which release this install came from (drives update.sh's staleness
  # check). Present in release tarballs; absent in ad-hoc/dev builds.
  if [ -f "$BASE/RELEASE" ]; then atomic_copy "$BASE/RELEASE" "$PORTHOME/RELEASE"; fi
}

inject_appinfo() {
  say "[2/6] Teaching Steam that Insaniquarium has a native macOS build"
  quit_steam
  "$PORTHOME/inject.sh" --phase appinfo
}

acquire_assets() {
  say "[3/6] Getting the game files from Steam"
  ASSETS_SRC=""
  if [ -n "$ASSETS" ]; then
    valid_assets "$ASSETS" || die "'$ASSETS' doesn't look like an Insaniquarium Deluxe folder (needs: ${ASSET_DIRS[*]})"
    ASSETS_SRC="$ASSETS"
    return
  fi
  if [ "$CONSOLE" = 1 ]; then
    cat <<'MSG'
Steam console fetch (requires OWNING the game on this account):
  1. Steam's console will open.
  2. Type:  download_depot 3320 3321
  3. Wait for "Depot download ... complete", then QUIT Steam.
MSG
    pause "Ready?"
    open "steam://open/console"
    pause "Finished and Steam is quit?"
    quit_steam
    local d="$STEAM/steamapps/content/app_3320/depot_3321"
    valid_assets "$d" || die "depot not found at '$d' - rerun, or use --assets <dir>"
    ASSETS_SRC="$d"
    return
  fi
  if valid_assets "$GAMEDIR"; then
    echo "Steam already has the game files in '$GAMEDIR' - reusing them."
    ASSETS_SRC="$GAMEDIR"
    return
  fi
  # Path A (default, no clicks): mark the game update-required (StateFlags 2)
  # and trigger steam://run/3320 - Steam's updater downloads depot 3321 itself
  # under your own license (family-shared included). This is the ONLY reliable
  # route: the Install wizard and steam://validate both force a fresh per-app
  # metadata fetch that reverts our appinfo edit before acting ("Invalid
  # platform"), while the run-path updater uses the already-loaded record.
  local attempt
  for attempt in 1 2; do
    quit_steam
    # Platform-tag the depot too (matches the verified flow; the transient tag
    # is dropped again by the durability agent's plain re-inject later).
    python3 "$PORTHOME/edit_appinfo.py" inject "$APPINFO" --with-depot-oslist
    "$PORTHOME/inject.sh" --phase pending
    echo "Starting Steam - it will download the game files (~11 MB) by itself."
    echo "NOTE: Steam will then show 'missing executable' - that's expected at"
    echo "this stage (the launch wiring comes later). Just close that dialog."
    open -a Steam
    local i
    for i in $(seq 1 30); do
      pgrep -x steam_osx >/dev/null && break
      sleep 1
    done
    sleep 15   # let the client finish booting before the run trigger
    open "steam://run/3320" || true
    for i in $(seq 1 60); do
      if valid_assets "$GAMEDIR"; then break; fi
      sleep 3
    done
    if valid_assets "$GAMEDIR"; then ASSETS_SRC="$GAMEDIR"; return; fi
    echo "Game files not in '$GAMEDIR' yet (attempt $attempt) - retrying."
  done
  die "Steam didn't download the game files. Options:
  - rerun ./setup.sh to try again
  - owners (not family-shared): ./setup.sh --console-fetch
  - last resort: ./setup.sh --assets <path to an Insaniquarium Deluxe folder>"
}

graft_assets() {
  say "[4/6] Installing game assets into the app + screensaver"
  local b d
  for b in "$APP" "$SAVER"; do
    for d in "${ASSET_DIRS[@]}"; do
      rm -rf "$b/Contents/Resources/$d"
      cp -R "$ASSETS_SRC/$d" "$b/Contents/Resources/$d"
    done
    codesign --force --deep -s - "$b"
    codesign --verify --deep --strict "$b" || die "codesign verification failed for $b"
  done
  xattr -dr com.apple.quarantine "$APP" "$SAVER" 2>/dev/null || true
}

build_from_source() {
  say "[4/6] Building from source (a few minutes on an M-series Mac)"
  cmake -G Ninja -S "$BASE" -B "$BASE/build" \
    -DINSANIQUARIUM_ASSETS_DIR="$ASSETS_SRC"
  cmake --build "$BASE/build" --target insaniquarium insaniquarium-saver
  "$BASE/scripts/package.sh"
  "$BASE/scripts/package-saver.sh" --install
  rm -rf "$APP"
  ditto "$BASE/build/Insaniquarium.app" "$APP"
  echo "installed $APP"
}

finalize_steam() {
  say "[5/6] Wiring the Steam Play button + keeping it alive"
  quit_steam
  "$PORTHOME/inject.sh" --phase finalize
  "$PORTHOME/install-durability.sh"
}

manual_tail() {
  say "[6/6] Two manual steps (macOS doesn't let scripts do these)"
  cat <<MSG
1) FULL DISK ACCESS - stops a recurring "access data from other apps" prompt
   (the game and the screensaver share your tank through a sandboxed folder):
   System Settings will open on Privacy & Security > Full Disk Access.
   Click "+", press Cmd+Shift+G, type "/Applications/Insaniquarium.app",
   add it, and make sure its toggle is ON.
MSG
  if ask "Open Full Disk Access settings now?"; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" || true
    pause "Done?"
  fi
  cat <<'MSG'
2) SCREENSAVER: System Settings > Screen Saver > pick "Insaniquarium".
   (macOS may ask once to allow the legacy screen saver engine.)

All set! Start Steam and hit Play on Insaniquarium! Deluxe - the native app
launches, Shift+Tab opens the Steam overlay, and the screensaver shows your
actual tank. Run "./setup.sh verify" any time to health-check the install.
MSG
}

# --- Update mode (in-place app+saver swap; no Steam interaction, saves kept) --
UPD_TMPS=()
update_cleanup() { local t; for t in "${UPD_TMPS[@]:-}"; do [ -n "$t" ] && rm -rf "$t"; done; }

# Build the new bundle in a temp dir (ditto payload -> graft stashed assets ->
# sign -> verify), THEN swap it in with a .bak rollback. Nothing destructive
# happens to the live bundle until the new one is fully built and verified.
swap_bundle() { # payload_src stash_dir dest
  local payload_src="$1" stash="$2" dest="$3"
  [ -d "$payload_src" ] || die "payload missing: $payload_src (need a release tarball, not a source checkout)"
  local staged; staged="$(mktemp -d "${TMPDIR:-/tmp}/insaniq-stage.XXXXXX")"
  UPD_TMPS+=("$staged")
  local new="$staged/$(basename "$dest")" d
  ditto "$payload_src" "$new"
  for d in "${ASSET_DIRS[@]}"; do
    rm -rf "$new/Contents/Resources/$d"
    cp -R "$stash/$d" "$new/Contents/Resources/$d"
  done
  codesign --force --deep -s - "$new"
  codesign --verify --deep --strict "$new" || die "codesign verify failed for new $(basename "$dest") - live install untouched"
  xattr -dr com.apple.quarantine "$new" 2>/dev/null || true
  local bak="$dest.bak.$$"
  [ -e "$dest" ] && mv "$dest" "$bak"
  if ! mv "$new" "$dest"; then
    [ -e "$bak" ] && mv "$bak" "$dest"
    die "failed to install new $(basename "$dest") (rolled back)"
  fi
  rm -rf "$bak"
}

update_verify() {
  local ok=1 editpy="$PORTHOME/edit_appinfo.py"
  [ -f "$editpy" ] || editpy="$SP/edit_appinfo.py"
  chk() { if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; else echo "FAIL  $1"; ok=0; fi; }
  # Fatal: these are what make the game actually run.
  chk "app installed"        '[ -x "$APP/Contents/MacOS/insaniquarium" ]'
  chk "app assets present"   'valid_assets "$APP/Contents/Resources"'
  chk "app signature"        'codesign --verify --deep --strict "$APP"'
  chk "saver installed"      '[ -d "$SAVER" ]'
  chk "saver assets present" 'valid_assets "$SAVER/Contents/Resources"'
  [ "$ok" = 1 ] || die "update verification failed - your previous install may still be intact; rerun, or run the full ./setup.sh"
  # Advisory: the Steam wiring self-heals via the durability agent, and
  # 'launchctl list' can't see GUI-session agents from every context - so warn,
  # never fail. 'bash setup.sh verify' in Terminal is the authoritative check.
  launchctl list 2>/dev/null | grep -q insaniquarium.steampatch \
    || echo "note: durability agent not detected from here - confirm with 'bash setup.sh verify' in Terminal"
  python3 "$editpy" show "$APPINFO" 2>/dev/null | grep -q macos \
    || echo "note: Steam Play-button wiring looks incomplete - run the full ./setup.sh if Play doesn't launch the app"
}

update_fda_tail() {
  cat <<'MSG'

Note: updating the app changes its code signature, which clears its Full Disk
Access grant. Until you re-grant it, the game shows an "access data from other
apps" prompt on launch (clicking Allow works each time). To silence it for good:
  System Settings > Privacy & Security > Full Disk Access - if Insaniquarium is
  already listed, toggle it off then on; otherwise click "+", add
  /Applications/Insaniquarium.app, and switch it on.
MSG
  # Never pop System Settings during an unattended in-app update relaunch.
  if [ "${NONINTERACTIVE:-0}" != 1 ] && ask "Open Full Disk Access settings now?"; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" || true
  fi
}

update_install() {
  say "Updating Insaniquarium in place (saves & Steam wiring stay untouched)"
  trap update_cleanup EXIT
  [ "$(uname -m)" = arm64 ] || die "this port is Apple Silicon (arm64) only"
  [ "${EUID:-$(id -u)}" -ne 0 ] || die "do not run as root"
  [ "$MODE" = payload ] || die "update needs a release tarball; for a source checkout: git pull && ./setup.sh"
  [ -x "$APP/Contents/MacOS/insaniquarium" ] || die "no existing install at $APP - run the full ./setup.sh first"
  pgrep -f "Insaniquarium.app/Contents/MacOS|Insaniquarium Deluxe/insaniquarium" >/dev/null \
    && die "Insaniquarium is running - quit the game first (Steam can stay open)"
  if pgrep -f legacyScreenSaver >/dev/null; then
    echo "The screensaver engine is active (a running saver or the System Settings"
    echo "Screen Saver preview) and holds the .saver open."
    ask "Close it and continue? (say n to abort, close it, and rerun)" || die "close the screensaver/preview, then rerun"
  fi

  # The payload is asset-free, so stash the installed game assets and re-graft
  # them onto the fresh bundles - otherwise the swap ships a contentless game.
  local stash src d cand
  stash="$(mktemp -d "${TMPDIR:-/tmp}/insaniq-stash.XXXXXX")"; UPD_TMPS+=("$stash")
  src=""
  for cand in "$APP/Contents/Resources" "$SAVER/Contents/Resources" "$GAMEDIR"; do
    if valid_assets "$cand"; then src="$cand"; break; fi
  done
  [ -n "$src" ] || die "couldn't find installed game assets to preserve - run the full ./setup.sh"
  for d in "${ASSET_DIRS[@]}"; do cp -R "$src/$d" "$stash/$d"; done
  valid_assets "$stash" || die "asset stash failed validation - aborted before changing anything"

  say "[1/3] Swapping the app + screensaver (crash-safe, with rollback)"
  swap_bundle "$BASE/payload/Insaniquarium.app"   "$stash" "$APP"
  swap_bundle "$BASE/payload/Insaniquarium.saver" "$stash" "$SAVER"

  say "[2/3] Refreshing helper scripts + durability agent"
  install_scripts
  "$PORTHOME/install-durability.sh" || echo "warning: could not reload the durability agent (run ./setup.sh verify)"

  say "[3/3] Verifying"
  update_verify
  update_fda_tail
  say "Update complete. Saves, Steam Play button, and screensaver selection are unchanged."
  echo "Health-check any time: bash setup.sh verify"
}

verify_install() {
  echo "port release: $(cat "$PORTHOME/RELEASE" 2>/dev/null || echo '(unversioned / pre-updater install)')"
  local ok=1 editpy="$PORTHOME/edit_appinfo.py"
  [ -f "$editpy" ] || editpy="$SP/edit_appinfo.py"
  chk() { if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; else echo "FAIL  $1"; ok=0; fi; }
  chk "app installed"        '[ -x "$APP/Contents/MacOS/insaniquarium" ]'
  chk "app assets present"   'valid_assets "$APP/Contents/Resources"'
  chk "app signature"        'codesign --verify --deep --strict "$APP"'
  chk "saver installed"      '[ -d "$SAVER" ]'
  chk "saver assets present" 'valid_assets "$SAVER/Contents/Resources"'
  chk "saver relocatable"    '! otool -L "$SAVER/Contents/MacOS/Insaniquarium" | grep -q /opt/homebrew'
  chk "appinfo injected"     'python3 "$editpy" show "$APPINFO" | grep -q macos'
  chk "launch symlink"       '[ -L "$GAMEDIR/insaniquarium" ] && [ -x "$GAMEDIR/insaniquarium" ]'
  chk "app manifest"         'grep -q "\"StateFlags\"[[:space:]]*\"4\"" "$STEAM/steamapps/appmanifest_3320.acf"'
  chk "durability agent"     'launchctl list | grep -q insaniquarium.steampatch'
  if [ "$ok" = 1 ]; then echo "all good"; else exit 1; fi
}

CMD=install ASSETS="" CONSOLE=0 NONINTERACTIVE=0
while [ $# -gt 0 ]; do
  case "$1" in
    verify) CMD=verify; shift;;
    --update) CMD=update; shift;;
    --yes) NONINTERACTIVE=1; shift;;
    --assets) ASSETS="${2:?--assets needs a path}"; shift 2;;
    --console-fetch) CONSOLE=1; shift;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) die "unknown argument: $1 (try --help)";;
  esac
done

if [ "$CMD" = verify ]; then
  verify_install
  exit 0
fi

if [ "$CMD" = update ]; then
  update_install
  exit 0
fi

echo "Insaniquarium native macOS port - one-step setup ($MODE mode)"
preflight
if [ "$MODE" = source ]; then bootstrap_source; fi
if [ "$MODE" = payload ]; then install_skeletons; fi
install_scripts
inject_appinfo
acquire_assets
if [ "$MODE" = payload ]; then graft_assets; else build_from_source; fi
finalize_steam
manual_tail
