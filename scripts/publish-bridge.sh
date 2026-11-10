#!/bin/bash
# One-time bridge for copies installed before the GitHub account rename.
#
# 1.1.11 and earlier ask GitHub for Jake-Vellora/insaniquarium-mac by NAME and
# only trust downloads under that name; the account is now Dangerous-J-Dev, so
# those copies can no longer install any update. This mirrors one release of the
# real repository into Jake-Vellora/insaniquarium-mac (an account kept only to
# hold the old name), so those copies update themselves once. The version they
# install looks the repository up by its permanent ID from then on.
#
# Run it right after scripts/release.sh, with gh signed in as Jake-Vellora:
#   gh auth login                          (once: adds the second account)
#   gh auth switch --user Jake-Vellora
#   scripts/publish-bridge.sh <tag>        e.g. 1.2.0
#   gh auth switch --user Dangerous-J-Dev
#
#   scripts/publish-bridge.sh <tag> --dry-run   download + verify only
set -euo pipefail

MAIN=Dangerous-J-Dev/insaniquarium-mac
BRIDGE=Jake-Vellora/insaniquarium-mac
TAG="${1:?usage: publish-bridge.sh <release tag> [--dry-run]}"
DRY=0; [ "${2:-}" = --dry-run ] && DRY=1

die() { echo "error: $*" >&2; exit 1; }

if [ "$DRY" = 0 ]; then
	me="$(gh api user -q .login)"
	[ "$me" = Jake-Vellora ] || die "gh is signed in as $me; run: gh auth switch --user Jake-Vellora"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/insaniq-bridge.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# 1. The real release's files, exactly as published (public: no auth needed).
gh release download "$TAG" --repo "$MAIN" --dir "$WORK" \
	--pattern "insaniquarium-mac-$TAG.tar.gz" --pattern "insaniquarium-mac-$TAG.tar.gz.sha256" \
	--pattern update.sh --pattern install.sh
(cd "$WORK" && shasum -a 256 -c "insaniquarium-mac-$TAG.tar.gz.sha256") \
	|| die "the $TAG tarball does not match its checksum"
# The copy every bridged install will run next must be the by-ID updater.
grep -q '^REPO_ID=1304620310$' "$WORK/update.sh" || die "$TAG's update.sh does not look the repo up by ID"
tar -xOzf "$WORK/insaniquarium-mac-$TAG.tar.gz" insaniquarium-mac-dist/scripts/update.sh | grep -q '^REPO_ID=1304620310$' \
	|| die "the updater inside the $TAG tarball does not look the repo up by ID"
echo "verified $TAG: tarball checksum OK, its updater asks GitHub by ID"
ls -l "$WORK" | tail -n +2

if [ "$DRY" = 1 ]; then
	echo "dry run: would create $BRIDGE if missing and publish $TAG there with these files"
	exit 0
fi

# 2. The bridge repository, with a README pointing at the real one. Creating
#    it ends GitHub's redirect from the old name, so old links land here.
if ! gh repo view "$BRIDGE" >/dev/null 2>&1; then
	gh repo create "$BRIDGE" --public --description "Moved to https://github.com/$MAIN"
fi
if ! gh api "repos/$BRIDGE/contents/README.md" >/dev/null 2>&1; then
	cat > "$WORK/README.md" <<MD
# This project moved

**Insaniquarium! Deluxe for Mac now lives at https://github.com/$MAIN**

Install or update from there. This repository only holds one release, so that
copies installed before the move can update themselves; after that they follow
the new address on their own.
MD
	gh api -X PUT "repos/$BRIDGE/contents/README.md" \
		-f message="Point to the project's new home" \
		-f content="$(base64 < "$WORK/README.md" | tr -d '\n')" >/dev/null
fi

# 3. The mirror release (latest by default, which is what old copies ask for).
gh release create "$TAG" \
	"$WORK/insaniquarium-mac-$TAG.tar.gz" \
	"$WORK/insaniquarium-mac-$TAG.tar.gz.sha256" \
	"$WORK/update.sh" "$WORK/install.sh" \
	--repo "$BRIDGE" \
	--title "Insaniquarium Mac $TAG (bridge)" \
	--notes "The project moved to https://github.com/$MAIN. This copy of release $TAG exists so installs from before the move can update themselves; afterwards they follow the new address on their own. To install or update by hand, paste this into Terminal:

\`\`\`
curl -fsSL https://github.com/$MAIN/releases/latest/download/install.sh | bash
\`\`\`"

echo "published $TAG on $BRIDGE"
echo "check: curl -fsSL https://api.github.com/repos/$BRIDGE/releases/latest | grep tag_name"
