#!/bin/bash
# Cut a GitHub release of the Insaniquarium Mac port that existing installs can
# auto-update to. Builds the slim (source-free) dist tarball, tags the repo, and
# uploads the tarball + its .sha256 sidecar + update.sh as release assets.
#
# Prereqs: clean git tree on main, in sync with origin (the game source is
# vendored in-tree, so main is the single source of truth); `gh` authed.
# Usage: release.sh [--tag <tag>]
set -euo pipefail
cd "$(dirname "$0")/.."

TAG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tag) TAG="${2:?--tag needs a value}"; shift 2;;
    *) echo "usage: release.sh [--tag <tag>]"; exit 2;;
  esac
done
# Default tag = the port version (single source of truth in PORT_VERSION), so the
# GitHub release tag, the $PORTHOME/RELEASE marker, and the in-Options version
# string all agree. Bump PORT_VERSION before each release.
[ -n "$TAG" ] || TAG="$(tr -d '[:space:]' < PORT_VERSION)"

die() { echo "error: $*" >&2; exit 1; }
[ -n "$TAG" ] || die "PORT_VERSION is empty"

command -v gh >/dev/null || die "gh CLI not found"
gh auth status >/dev/null 2>&1 || die "gh not authenticated (gh auth login)"

# --- Gates -------------------------------------------------------------------
[ -z "$(git status --porcelain)" ] || die "working tree is dirty - commit or stash first"
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || die "not on branch main"
git fetch --quiet origin
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "main is not in sync with origin/main - push/pull first"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG already exists locally"
git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1 && die "tag $TAG already exists on origin"

# Every release must describe itself: the Changes section comes from the
# matching "## <tag>" section of CHANGELOG.md, written before releasing.
CHANGES="$(awk -v tag="$TAG" '
  found && /^## / { exit }
  $0 ~ "^## " tag "( |$)" { found = 1; next }
  found { print }
' CHANGELOG.md)"
[ -n "${CHANGES//[[:space:]]/}" ] || die "CHANGELOG.md has no '## $TAG' section - write the release notes first"

# --- Build the slim dist -----------------------------------------------------
echo "building slim dist for tag $TAG ..."
scripts/make-dist.sh --no-source --release "$TAG"
TARBALL="build/dist/insaniquarium-mac-${TAG}.tar.gz"
[ -f "$TARBALL" ] || die "expected tarball not produced: $TARBALL"
[ -f "$TARBALL.sha256" ] || die "checksum sidecar missing: $TARBALL.sha256"
TARBALL_SHA="$(awk 'NR==1{print $1}' "$TARBALL.sha256")"
[ -n "$TARBALL_SHA" ] || die "could not read sha256 from $TARBALL.sha256"

# --- Release notes -----------------------------------------------------------
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
  echo "### Verify your download"
  echo
  echo '```'
  echo "shasum -a 256 -c insaniquarium-mac-${TAG}.tar.gz.sha256"
  echo "# expected: ${TARBALL_SHA}  insaniquarium-mac-${TAG}.tar.gz"
  echo '```'
  echo "(update.sh checks this automatically before installing.)"
  echo
  echo "### Changes"
  echo "$CHANGES"
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
