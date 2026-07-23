# Changelog

Release notes for the Insaniquarium Mac port. `scripts/release.sh` publishes
the `## <version>` section matching the tag it is about to cut, and refuses to
release without one - write the entry here first, in plain user-facing
language (what changed and why they care, not commit subjects).

## 1.1.1 - 2026-07-23

- Star potions are fixed. Dropping a Star Potion on a big guppy now correctly
  turns it into a star guppy that produces stars, so your starcatcher (Penta)
  actually gets fed instead of starving.
- The game updates itself now. Open Options > Check Updates; if a new version
  is available, click Update Now and the game installs it and restarts on its
  own, no Terminal needed. It also checks about once a week on its own.
- Version number in Options. A small `v1.1.1` shows at the bottom of the
  Options menu so you can tell what you are running.

## r2026-07-22 - 2026-07-22

- First updatable release: the update.sh one-liner installs new versions while
  preserving saves, the Steam Play button, and the screensaver selection.
- Includes the star potion fix in the game code and the release tarball
  pipeline (slim, asset-free tarballs with checksum verification).
