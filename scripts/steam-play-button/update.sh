#!/bin/bash
# Installer and in-place updater for the native Insaniquarium Mac port (Apple
# Silicon and Intel, macOS 12 or later). Every release publishes this same file
# twice, as install.sh and as update.sh. Paste into Terminal:
#
#   curl -fsSL https://github.com/Jake-Vellora/insaniquarium-mac/releases/latest/download/install.sh | bash
#
# Not installed yet: downloads the latest release, checks its checksum, and runs
# its setup.sh, which walks you through the one-time setup.
# Already installed: swaps the app + screensaver to the latest release WITHOUT
# touching your saves, your Steam wiring, or your screensaver selection.
#
# Options:
#   --force              reinstall even if already on the latest release
#   --tarball <path>     use a local dist tarball instead of downloading
#                        (rehearsal/offline; skips the GitHub API + download)
#
# Updating quits nothing: just make sure the GAME is closed (Steam may stay open).
set -euo pipefail

REPO="Jake-Vellora/insaniquarium-mac"
# Test hooks (never set in normal use): point the release lookup at a local
# stand-in for GitHub, and keep a sandbox run away from /Applications.
API="${INSANIQ_TEST_RELEASE_API:-https://api.github.com/repos/$REPO/releases/latest}"
ASSET_PREFIX="${INSANIQ_TEST_ASSET_PREFIX:-https://github.com/$REPO/}"
APP="${INSANIQ_TEST_APPS_DIR:-/Applications}/Insaniquarium.app"
PORTHOME="$HOME/Library/Application Support/Insaniquarium-port"
GAME_PGREP='Insaniquarium.app/Contents/MacOS|Insaniquarium Deluxe/insaniquarium'
LOCK="$PORTHOME/.update-lock"

die()  { echo "error: $*" >&2; exit 1; }
note() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# NOTE: never redirect this shell's own stdin (no `exec < ...`). Under the
# documented `curl ... | bash` one-liner, bash is READING THIS SCRIPT from stdin,
# so swapping fd 0 discards the rest of the script - the run dies silently, exit
# 0, nothing printed. The one prompt-capable child (setup.sh, at the bottom) gets
# the tty through a per-command redirect instead.

FORCE=0 TARBALL="" YES=""
while [ $# -gt 0 ]; do
  case "$1" in
    --force)   FORCE=1; shift;;
    --tarball) TARBALL="${2:?--tarball needs a path}"; shift 2;;
    --yes)     YES=--yes; shift;;   # non-interactive; used by the in-app updater
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) die "unknown argument: $1 (try --help)";;
  esac
done

# --- Preconditions (before touching anything) --------------------------------
case "$(uname -m)" in arm64|x86_64) ;; *) die "unsupported CPU: $(uname -m)";; esac
macos="$(sw_vers -productVersion)"
[ "${macos%%.*}" -ge 12 ] || die "this port needs macOS 12 or later (this Mac has $macos)"
[ "${EUID:-$(id -u)}" -ne 0 ] || die "do not run as root"
# python3 (for the release info, and for setup.sh's Steam edits) comes with
# Apple's Command Line Tools. On a Mac without them, start their installer and
# stop with a plain instruction, rather than failing later with a puzzling one.
if ! xcode-select -p >/dev/null 2>&1; then
  [ -n "$YES" ] || xcode-select --install >/dev/null 2>&1 || true
  echo
  echo "Apple's Command Line Tools are needed first, and a window to install them"
  echo "has opened. Click Install, wait for it to finish, then paste the same"
  echo "command into Terminal again."
  exit 1
fi
INSTALLED=0
[ -x "$APP/Contents/MacOS/insaniquarium" ] && INSTALLED=1
if [ "$INSTALLED" = 0 ] && [ -n "$YES" ]; then
  die "Insaniquarium isn't installed at $APP; a first install has to run in Terminal"
fi
if pgrep -f "$GAME_PGREP" >/dev/null; then
  die "Insaniquarium is running - quit the game first (Steam can stay open)"
fi

# --- Lock (reap a stale one so an aborted run can't block forever) -----------
mkdir -p "$PORTHOME"
if ! mkdir "$LOCK" 2>/dev/null; then
  stale=1
  if [ -f "$LOCK/pid" ]; then
    lp="$(cat "$LOCK/pid" 2>/dev/null || echo)"
    if [ -n "$lp" ] && kill -0 "$lp" 2>/dev/null; then stale=0; fi
  fi
  if [ "$stale" = 1 ]; then
    echo "note: clearing a stale update lock"
    rm -rf "$LOCK"; mkdir "$LOCK" || die "could not acquire update lock ($LOCK)"
  else
    die "another update is already running (lock: $LOCK)"
  fi
fi
echo "$$" > "$LOCK/pid"

WORK=""
cleanup() { [ -n "$WORK" ] && rm -rf "$WORK"; rmdir "$LOCK" 2>/dev/null || rm -rf "$LOCK" 2>/dev/null || true; }
trap cleanup EXIT

WORK="$(mktemp -d "${TMPDIR:-/tmp}/insaniq-update.XXXXXX")"

# --- Obtain the dist tarball --------------------------------------------------
DISTDIR=""
if [ -n "$TARBALL" ]; then
  note "Installing from local tarball"
  [ -f "$TARBALL" ] || die "no such tarball: $TARBALL"
  cp "$TARBALL" "$WORK/dist.tar.gz"
else
  note "Checking for the latest release"
  # Fetch the release JSON. Distinguish "no release yet" (404) and rate limits
  # (403) from real content; never proceed or crash on those.
  http="$(curl -fsSL -w '%{http_code}' -o "$WORK/release.json" "$API" 2>/dev/null)" || http="000"
  case "$http" in
    200) : ;;
    404) echo "No release has been published yet - nothing to install."; exit 0;;
    403) echo "GitHub rate-limited the version check (try again in a bit)."; exit 0;;
    *)   echo "Could not reach GitHub (HTTP $http) - try again later."; exit 0;;
  esac

  # Parse the JSON with python3 (always present via the CLT). It writes shell
  # assignments to a file we source - avoids a heredoc-in-$() that trips the
  # macOS system bash.
  python3 - "$WORK/release.json" "$ASSET_PREFIX" > "$WORK/parsed.sh" <<'PY'
import json, sys, re
def q(v): return "'" + str(v).replace("'", "'\\''") + "'"
try:
    r = json.load(open(sys.argv[1]))
except Exception:
    print('PARSE_OK=0'); sys.exit(0)
tag = r.get('tag_name') or ''
tar = sha = ''
for a in r.get('assets', []):
    n = a.get('name', '')
    u = a.get('browser_download_url', '')
    # only trust assets served from this repo's own release download host
    if not u.startswith(sys.argv[2]):
        continue
    if re.fullmatch(r'insaniquarium-mac-.*\.tar\.gz', n):
        tar = u
    elif re.fullmatch(r'insaniquarium-mac-.*\.tar\.gz\.sha256', n):
        sha = u
print('PARSE_OK=1')
print('TAG=' + q(tag))
print('TAR_URL=' + q(tar))
print('SHA_URL=' + q(sha))
PY
  PARSE_OK=0
  # shellcheck source=/dev/null
  . "$WORK/parsed.sh"
  [ "${PARSE_OK:-0}" = 1 ] || { echo "Could not parse the release info - try again later."; exit 0; }
  [ -n "${TAR_URL:-}" ] || { echo "The latest release has no installable asset - try again later."; exit 0; }

  applied="$(cat "$PORTHOME/RELEASE" 2>/dev/null || echo)"
  if [ "$INSTALLED" = 1 ] && [ "$FORCE" != 1 ] && [ -n "$applied" ] && [ "$applied" = "$TAG" ]; then
    echo "Insaniquarium is already up to date ($TAG) - nothing to do."
    exit 0
  fi

  note "Downloading $TAG"
  curl -fL -o "$WORK/dist.tar.gz" "$TAR_URL" || die "download failed"
  if [ -n "${SHA_URL:-}" ]; then
    curl -fL -o "$WORK/dist.tar.gz.sha256" "$SHA_URL" || die "checksum download failed"
    # Compare hashes directly - robust regardless of the sidecar's filename.
    want="$(awk 'NR==1{print $1}' "$WORK/dist.tar.gz.sha256")"
    got="$(shasum -a 256 "$WORK/dist.tar.gz" | awk '{print $1}')"
    [ -n "$want" ] && [ "$want" = "$got" ] \
      || die "checksum verification failed - download corrupt, nothing was installed"
    echo "checksum OK"
  else
    echo "note: release ships no .sha256 sidecar - skipping integrity check"
  fi
fi

xattr -dr com.apple.quarantine "$WORK/dist.tar.gz" 2>/dev/null || true

# --- Extract + hand off to the freshly-shipped setup.sh ----------------------
if [ "$INSTALLED" = 1 ]; then note "Applying the update"; SETUP_MODE=--update
else note "Starting setup"; SETUP_MODE=; fi
tar -xzf "$WORK/dist.tar.gz" -C "$WORK"
DISTDIR="$(find "$WORK" -maxdepth 1 -type d -name 'insaniquarium-mac-*' | head -n1)"
[ -n "$DISTDIR" ] && [ -x "$DISTDIR/setup.sh" ] && [ -d "$DISTDIR/payload/Insaniquarium.app" ] \
  || die "tarball is missing setup.sh or the app payload"
xattr -dr com.apple.quarantine "$DISTDIR" 2>/dev/null || true

# setup.sh's "run it again" advice must name what the user actually ran.
export INSANIQ_RERUN="paste the install command into Terminal again"

# Run the NEW tarball's setup.sh (not exec: our EXIT trap must still clean up,
# and setup.sh atomically refreshes this very update.sh in $PORTHOME).
#
# setup.sh prompts, so it needs a terminal. Under `curl | bash` our stdin is the
# pipe, so hand it the controlling tty - but only if there is one to hand over:
# the in-app updater runs us detached with SETSID, where /dev/tty cannot be
# opened at all. Without a tty setup.sh still finishes; its ask() treats the
# resulting EOF as "no". SETUP_MODE is deliberately unquoted: empty means a
# first install (bash 3.2 cannot expand an empty array under set -u).
if [ -z "$YES" ] && [ ! -t 0 ] && (exec 3< /dev/tty) 2>/dev/null; then
  bash "$DISTDIR/setup.sh" $SETUP_MODE < /dev/tty
else
  bash "$DISTDIR/setup.sh" $SETUP_MODE ${YES:+$YES}
fi
