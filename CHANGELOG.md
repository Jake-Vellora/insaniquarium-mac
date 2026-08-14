# Changelog

Release notes for the Insaniquarium Mac port. `scripts/release.sh` publishes
the `## <version>` section matching the tag it is about to cut, and refuses to
release without one - write the entry here first, in plain user-facing
language (what changed and why they care, not commit subjects).

## 1.1.4 - 2026-08-14

- The alien warning no longer repeats itself in Challenge tanks. Every few waves
  the game steps the difficulty up and puts a blinking red banner on screen to
  say so, but the banner was going up with no words of its own, so it showed the
  previous wave's warning again. That is why an attack seemed to be announced a
  second time just after you had cleared one. It now reads WARNING! ALIEN
  DIFFICULTY INCREASED, the way it always should have.
- The Hall of Fame shows your real Adventure times. The Adventure page was
  listing your name against times taken from the Challenge table, so the entries
  were in the right order with the wrong numbers, frozen at the ones the game
  ships with. Your times were being recorded correctly all along, so your
  existing records appear as soon as you open the page.
- The screensaver shows your current tank. It reads the tank from a folder only
  the game can write to, and the game was only writing there when it started and
  when it quit. It now hands the tank over every time it saves, so what you see
  is what you last left in the Virtual Tank.
- Your screensaver's play carries back into the game. The tank the screensaver
  had been playing was kept off to one side and thrown away the next time you
  opened the game. It now continues where the screensaver left it, the way the
  original Windows version worked.
- The game tells you when the screensaver cannot see your tank. Insaniquarium
  needs Full Disk Access to pass the tank across, and installing an update clears
  that permission, which used to leave the screensaver quietly stuck on an old
  tank forever. The game now notices, explains it, and offers to open the right
  settings page for you.
- Deleting a profile no longer leaves its tank behind for the screensaver.

Thanks again to Jakob for finding and reporting all of these.

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
