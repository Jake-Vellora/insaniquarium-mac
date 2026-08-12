# Changelog

Release notes for the Insaniquarium Mac port. `scripts/release.sh` publishes
the `## <version>` section matching the tag it is about to cut, and refuses to
release without one - write the entry here first, in plain user-facing
language (what changed and why they care, not commit subjects).

## 1.1.2 - 2026-08-12

- Ultravores and laser upgrades are back in Tank 4. From Tank 4-2 onward,
  buying a Carnivore now unlocks both the Ultravore and the weapon upgrade,
  the way it works in the original game. Before this fix neither ever
  appeared, so the laser was stuck at its starting level for the whole of the
  hardest tank. Time Trial on Tank 4 was affected in the same way and is fixed
  too. If you are partway through a Tank 4 level, both buttons show up as soon
  as you buy your next Carnivore, so there is no need to restart the level.
- Fixed a crash in the Virtual Tank. Opening the Fish screen could read memory
  that had already been freed and take the game down, usually when clicking
  fish or using Hide All and Show All. It no longer does.

Thanks to the player on Reddit who reported all three of these.

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
