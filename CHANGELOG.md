# Changelog

Release notes for the Insaniquarium Mac port. `scripts/release.sh` publishes
the `## <version>` section matching the tag it is about to cut, and refuses to
release without one - write the entry here first, in plain user-facing
language (what changed and why they care, not commit subjects).

## 1.1.3 - 2026-08-13

- Presto no longer duplicates himself. Adding Presto to your Virtual Tank used
  to leave his checkbox on the Pets screen looking empty, so ticking it again
  added a second Presto, then a third, with no limit, and there was no way to
  remove any of them. He now shows as present the way every other pet does, and
  unticking him takes him back out.
- Those depressed guppies are gone. Every stray Presto was also appearing on
  the Fish screen as a nameless guppy with a purchase date of 1970, a mood of
  Horribly Depressed and a hometown of Virtual Tank. They were never really
  fish, which is why none of that made sense. Existing tanks repair themselves
  the next time you open them: one Presto is kept, the duplicates are cleared
  out, and your real fish are left alone.
- Fixed a crash when selling a fish. Just moving the mouse onto the Sell button
  on the Fish screen could take the game down instantly, before you even
  clicked it. This one hit ordinary guppies too, not only the stray Prestos.
- Fixed a crash when using Hide All. If one of your fish happened to be singing
  when you opened the Fish screen, Hide All could take the game down. The same
  fault could also strike during normal play when a boxing glove pet punched a
  singing fish.
- Fish are worth what the store promises again. Selling a fish within its first
  day now gives the full refund advertised on the naming screen, instead of
  half price.
- Virtual Tank pets are no longer permanently miserable. They were being created
  without the bookkeeping every fish gets, which pinned their mood at its lowest
  value and quietly made them drop coins as slowly as possible.
- Growing a guppy is worth doing again. A guppy you have fed up to medium, large
  or crowned now sells for two, three or five times the base resale value, the
  way the original game rewards it. Until now every guppy sold for a flat half
  price no matter how big you had grown it.
- The Fish screen responds properly again. Its buttons make the usual click
  sound, and double clicking a fish hides or shows it, which had quietly stopped
  working.
- Double clicking with the scroll wheel button no longer breaks the mouse. It
  used to leave the game ignoring every click afterwards until you right clicked
  somewhere, because the press and the release were reported as two different
  buttons.
- Rapid repeated clicking behaves like the original again. Four quick clicks in
  a row now count as two double clicks rather than one.

Thanks to Jakob for finding and reporting all of these.

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
