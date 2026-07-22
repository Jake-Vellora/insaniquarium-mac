#!/bin/bash
# In-place updater for the native Insaniquarium Mac port. Swaps the app +
# screensaver to the latest GitHub release WITHOUT touching your saves, your
# Steam wiring, or your screensaver selection.
#
# Usage (the normal path - fetch the latest release from GitHub):
#   curl -fsSL https://github.com/Jake-Vellora/insaniquarium-mac/releases/latest/download/update.sh | bash
# or, from an extracted tarball / installed copy:
#   bash update.sh
#
# Options:
#   --force              reinstall even if already on the latest release
#   --tarball <path>     install a local dist tarball instead of downloading
#                        (rehearsal/offline; skips the GitHub API + download)
#
# It quits nothing. Just make sure the GAME is closed (Steam may stay open).
set -euo pipefail

REPO="Jake-Vellora/insaniquarium-mac"
API="https://api.github.com/repos/$REPO/releases/latest"
PORTHOME="$HOME/Library/Application Support/Insaniquarium-port"
APP="/Applications/Insaniquarium.app"
GAME_PGREP='Insaniquarium.app/Contents/MacOS|Insaniquarium Deluxe/insaniquarium'
LOCK="$PORTHOME/.update-lock"

die()  { echo "error: $*" >&2; exit 1; }
note() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# Prompts (if any downstream) need a real terminal; when piped from curl our
# stdin is the pipe, so best-effort reattach the controlling tty. Never fatal.
[ -t 0 ] || exec < /dev/tty 2>/dev/null || true

FORCE=0 TARBALL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --force)   FORCE=1; shift;;
    --tarball) TARBALL="${2:?--tarball needs a path}"; shift 2;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) die "unknown argument: $1 (try --help)";;
  esac
done

# --- Preconditions (before touching anything) --------------------------------
[ "$(uname -m)" = arm64 ] || die "this port is Apple Silicon (arm64) only"
[ "${EUID:-$(id -u)}" -ne 0 ] || die "do not run as root"
[ -x "$APP/Contents/MacOS/insaniquarium" ] || die \
  "Insaniquarium isn't installed at $APP.
  This updater only upgrades an existing install. For a first-time setup,
  run the full ./setup.sh from a release tarball instead."
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
    404) echo "No release has been published yet - nothing to update to."; exit 0;;
    403) echo "GitHub rate-limited the version check (try again in a bit)."; exit 0;;
    *)   echo "Could not reach GitHub (HTTP $http) - try again later."; exit 0;;
  esac

  # Parse the JSON with python3 (always present via the CLT). It writes shell
  # assignments to a file we source - avoids a heredoc-in-$() that trips the
  # macOS system bash.
  python3 - "$WORK/release.json" > "$WORK/parsed.sh" <<'PY'
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
    if not u.startswith('https://github.com/Jake-Vellora/insaniquarium-mac/'):
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
  if [ "$FORCE" != 1 ] && [ -n "$applied" ] && [ "$applied" = "$TAG" ]; then
    echo "Already on the latest release ($TAG). Use --force to reinstall."
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
      || die "checksum verification failed - download corrupt, install left untouched"
    echo "checksum OK"
  else
    echo "note: release ships no .sha256 sidecar - skipping integrity check"
  fi
fi

xattr -dr com.apple.quarantine "$WORK/dist.tar.gz" 2>/dev/null || true

# --- Extract + hand off to the freshly-shipped setup.sh ----------------------
note "Applying the update"
tar -xzf "$WORK/dist.tar.gz" -C "$WORK"
DISTDIR="$(find "$WORK" -maxdepth 1 -type d -name 'insaniquarium-mac-*' | head -n1)"
[ -n "$DISTDIR" ] && [ -x "$DISTDIR/setup.sh" ] && [ -d "$DISTDIR/payload/Insaniquarium.app" ] \
  || die "tarball is missing setup.sh or the app payload"
xattr -dr com.apple.quarantine "$DISTDIR" 2>/dev/null || true

# Run the NEW tarball's setup.sh (not exec: our EXIT trap must still clean up,
# and setup.sh atomically refreshes this very update.sh in $PORTHOME).
bash "$DISTDIR/setup.sh" --update
