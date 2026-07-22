#!/bin/bash
# Cut a GitHub release of the Insaniquarium Mac port that existing installs can
# auto-update to. Builds the slim (source-free) dist tarball, tags the repo, and
# uploads the tarball + its .sha256 sidecar + update.sh as release assets.
#
# Prereqs: clean git tree on main, in sync with origin; the game-code fix already
# committed+pushed to the WinFish/PvZ 'public' forks and pinned in VERSIONS;
# `gh` authed. Usage: release.sh [--tag <tag>] [--force-build]
set -euo pipefail
cd "$(dirname "$0")/.."

TAG=""; FORCE_BUILD=0
while [ $# -gt 0 ]; do
  case "$1" in
    --tag) TAG="${2:?--tag needs a value}"; shift 2;;
    --force-build) FORCE_BUILD=1; shift;;
    *) echo "usage: release.sh [--tag <tag>] [--force-build]"; exit 2;;
  esac
done
[ -n "$TAG" ] || TAG="r$(date +%Y-%m-%d)"

die() { echo "error: $*" >&2; exit 1; }

command -v gh >/dev/null || die "gh CLI not found"
gh auth status >/dev/null 2>&1 || die "gh not authenticated (gh auth login)"

# --- Gates -------------------------------------------------------------------
[ -z "$(git status --porcelain)" ] || die "working tree is dirty - commit or stash first"
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || die "not on branch main"
git fetch --quiet origin
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "main is not in sync with origin/main - push/pull first"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG already exists locally"
git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1 && die "tag $TAG already exists on origin"

# The pinned fork SHAs must exist on the fork ('public') remotes, or a
# source-mode install of this release can't fetch the fix.
# shellcheck source=VERSIONS
source VERSIONS
for pin in "WinFish:$WINFISH_REPO:$WINFISH_REF" "PvZ:$PVZ_REPO:$PVZ_REF"; do
  name="${pin%%:*}"; rest="${pin#*:}"; repo="${rest%:*}"; ref="${rest##*:}"
  git ls-remote "$repo" | grep -q "^$ref" || die "$name pin $ref is not present on $repo - push the fork first"
done
echo "pins OK: WinFish=$WINFISH_REF PvZ=$PVZ_REF"

# --- Build the slim dist -----------------------------------------------------
echo "building slim dist for tag $TAG ..."
scripts/make-dist.sh --no-source --release "$TAG"
TARBALL="build/dist/insaniquarium-mac-${TAG}.tar.gz"
[ -f "$TARBALL" ] || die "expected tarball not produced: $TARBALL"
[ -f "$TARBALL.sha256" ] || die "checksum sidecar missing: $TARBALL.sha256"

# --- Release notes -----------------------------------------------------------
PREV="$(git describe --tags --abbrev=0 2>/dev/null || true)"
NOTES="$(mktemp "${TMPDIR:-/tmp}/insaniq-notes.XXXXXX")"
trap 'rm -f "$NOTES"' EXIT
{
  echo "## Insaniquarium Mac port - $TAG"
  echo
  echo "Update an existing install with one command (quit the game first; Steam can stay open):"
  echo
  echo '```'
  echo "curl -fsSL https://github.com/Jake-Vellora/insaniquarium-mac/releases/latest/download/update.sh | bash"
  echo '```'
  echo
  echo "Your saves, Steam Play button, and screensaver selection are preserved."
  echo "After updating, re-grant Full Disk Access if prompted (the app's signature changed)."
  echo
  echo "### Changes"
  if [ -n "$PREV" ]; then git log --pretty='- %s' "$PREV"..HEAD; else git log --pretty='- %s' -n 20 HEAD; fi
  echo
  echo "Pinned source: WinFish \`$WINFISH_REF\`, PvZ-Portable \`$PVZ_REF\`."
} > "$NOTES"

# --- Tag + publish -----------------------------------------------------------
git tag -a "$TAG" -m "insaniquarium-mac $TAG"
git push origin "$TAG"

gh release create "$TAG" \
  "$TARBALL" \
  "$TARBALL.sha256" \
  "scripts/steam-play-button/update.sh" \
  --repo Jake-Vellora/insaniquarium-mac \
  --title "Insaniquarium Mac $TAG" \
  --notes-file "$NOTES"

echo
echo "released $TAG"
echo "users update with:"
echo "  curl -fsSL https://github.com/Jake-Vellora/insaniquarium-mac/releases/latest/download/update.sh | bash"
