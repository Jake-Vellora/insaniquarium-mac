# Paste and run this in Terminal to install!

```bash
curl -fsSL https://github.com/Dangerous-J-Dev/insaniquarium-mac/releases/latest/download/install.sh | bash
```

**Before you paste it**

- You need a Mac on macOS 12 or later. Apple Silicon and Intel both work.
- Steam is installed and you are signed in, and **Insaniquarium! Deluxe** is in
  your Steam Library (bought, or family-shared: turn on the shared-games filter
  to see it).
- Open the game's page in your Steam Library once. **Don't click Install**; the
  installer does that part.

**What happens when you run it**

1. Open **Terminal** (press Cmd+Space, type `Terminal`, press Return), paste the
   command and press Return.
2. First time on a Mac only: if a box asks to install the **command line
   developer tools**, click **Install**, wait for it to finish, then paste the
   command again.
3. It downloads the Mac version (about 17 MB) and checks the download is intact.
4. If Steam is open, it asks `quit it now? [y/N]`: type `y` and press Return. If
   macOS asks whether Terminal may control Steam, click **OK**.
5. Steam opens by itself and downloads the game files (about 11 MB), then shows a
   **"missing executable"** error. That's expected: close it. When it asks to
   quit Steam again, type `y` and press Return.
6. It asks `Open Full Disk Access settings now? [y/N]`: type `y`. In the window
   that opens, click **+** (enter your password if asked), press
   **Cmd+Shift+G**, type `/Applications/Insaniquarium.app`, press Return and
   click **Open**. Make sure Insaniquarium is switched on, then go back to
   Terminal and press Return.
7. When it says **All set!**, open Steam and click **Play** on
   *Insaniquarium! Deluxe*.

**Optional, the screensaver** (it shows your actual tank): System Settings >
Wallpaper > Screen Saver... > scroll down to Other > Show All > Insaniquarium >
Done. On macOS 13 to 15 it is under System Settings > Screen Saver, and on
macOS 12 under System Preferences > Desktop & Screen Saver.

**Updates** install from inside the game: Options > Check Updates. Pasting the
command again also updates you (quit the game first). **On 1.1.11 or earlier?**
Paste the command once: the updater in those versions cannot reach the
project's new address, so their Update Now does nothing.

If it stops with an error, the message says what to do. Then paste the command
again.

---

## About

Runs the Steam release of **Insaniquarium! Deluxe** (appid 3320) **natively on
a Mac**, Apple Silicon or Intel: a real universal Mac app, no Wine, no
Rosetta, launched from the **real Steam Play button**, with the Steam overlay
(Shift+Tab), playtime tracking, and a native **macOS screensaver** that
renders your actual virtual tank (and pays out its coins back into your game).

## Requirements

- A Mac running macOS 12 Monterey or later, Apple Silicon or Intel (the same
  minimum as the Steam client). The Intel half of the app has been tested
  under Rosetta on Apple Silicon, but not yet on a real Intel Mac.
- **Insaniquarium! Deluxe in your Steam library**, owned or via Family
  Sharing. This repo contains **no game content whatsoever**; during setup
  your own Steam client downloads the game files under your own license.
- Apple's Command Line Tools (the installer asks for them if they are missing).

## Build from source instead

For developers: this builds the game on your Mac with
[Homebrew](https://brew.sh) libraries instead of downloading the release.
Players should use the command at the top.

1. **Steam first**: install Steam, sign in, and make sure *Insaniquarium!
   Deluxe* appears in your Library (owned or family-shared; enable the
   shared-games filter if needed). Open its library page once so Steam caches
   the game's record. **Don't click Install**; the script handles that.
2. Open Terminal and run:
   ```
   git clone https://github.com/Dangerous-J-Dev/insaniquarium-mac.git
   cd insaniquarium-mac
   ./setup.sh
   ```
3. Follow the prompts. Three things are normal:
   - A popup may ask to install the **command line developer tools**: click
     Install, wait for it to finish, then run `./setup.sh` again.
   - The script asks to **quit Steam**: say `y`. (It offers to install
     Homebrew too if you don't have it; the build takes ~5–10 minutes.)
   - Steam reopens and **downloads the game files by itself**, then shows a
     "missing executable" error; that's expected mid-setup, just close it.
4. The script finishes with two things macOS makes you do by hand:
   - **Full Disk Access** for `/Applications/Insaniquarium.app` (System
     Settings opens for you; stops a recurring permission prompt).
   - The **screensaver**: see the screensaver path near the top of this page.
5. Open Steam, hit **Play**. Shift+Tab is the overlay; the screensaver is
   your actual tank, and its coin earnings flow back into the game.

Notes: don't click Install or "Verify integrity" on the game in Steam's own
UI; those force a metadata refresh that undoes the script's work (it
self-heals, but why poke it). If Play ever shows as "Install / Available for
Windows", quit Steam and reopen it. `./setup.sh` and `./setup.sh verify` are
always safe to rerun.

## How it works

1. **The port**: the game code comes from the public
   [WinFish](https://github.com/Vindirect/WinFish) decompilation
   (Insaniquarium's internal codename), transplanted onto the SDL2+OpenGL
   [PvZ-Portable](https://github.com/kyle-sylvestre/PvZ-Portable)
   SexyAppFramework. Both source trees live in this repo (`WinFish/` and
   `PvZ-Portable/`, with the port's patches applied), alongside the missing
   build system (CMake), macOS packaging, the screensaver, and the Steam
   integration.
2. **The Play button**: Steam's macOS client can't launch Windows-only games,
   so `setup.sh` edits Steam's local `appinfo.vdf` cache (checksummed v29
   format) to mark appid 3320 as having a native macOS build with a launch
   entry pointing at an `Insaniquarium.app` symlink in the Steam install
   directory. Steam launches the app bundle rather than the bare executable,
   allowing macOS to use the app's Full Disk Access grant for screensaver save
   sharing. This avoids a Steam-only FDA warning observed with the old binary
   launch path; the app-bundle launch and Shift+Tab overlay were tested on
   Apple Silicon. Steam then treats it like any native game:
   Install button, Play button, overlay, playtime. A LaunchAgent re-applies
   the edit whenever Steam's metadata sync reverts it.
3. **The assets**: because the game "has a Mac build" as far as Steam is
   concerned, **Steam downloads the game files itself** (~11 MB) under your
   license, including family-shared ones. (Mechanically: setup writes an
   update-required manifest and triggers `steam://run/3320`; the run-path
   updater downloads the depot. The Install wizard and validate can't be used;
   both force a fresh metadata fetch that reverts the edit first.) The setup
   script then places the files into the app and screensaver bundles.
4. **The screensaver**: a native `.saver` bundle running the game's Virtual
   Tank, with two-way save sync (screensaver earnings flow back into the game,
   like the original Windows release intended). 

## PLEASE NOTE THAT THE SCREENSAVER IS BURIED IN THE APPLE SETTINGS!

   Path to it is: Settings > Wallpaper > Screen Saver... (Top section of the window, next to the preview) > Scroll all the way down to Other > Show All > Scroll all the way down to Insaniquarium
   
   Click it then click done. Thanks Tim Apple, very cool.

## After setup

- If Steam ever shows Install or "Available for Windows" instead of Play, quit
  Steam and reopen it. Don't click Install or "Verify integrity" on the game.
- `./setup.sh verify` (in a source checkout or an unpacked release folder):
  health-check every piece (also prints the release marker)
- `scripts/steam-play-button/uninstall.sh`: full uninstall (`--purge-saves`
  to also remove save data)
- Don't force-kill the game (Steam will think it's still running); quit it
  normally.

## Updating

All methods preserve saves, Steam wiring, and screensaver selection.

- **In the game (easiest):** on v1.1.1+, open **Options → Check Updates**; if a
  new version is available, click **Update Now** and the game closes, updates
  itself, and reopens, no Terminal needed. (It also prompts weekly on its own.)
- **From a release tarball**, which is also the one-time way to get onto a
  version that has the in-app updater: quit the game and run
  ```
  curl -fsSL https://github.com/Dangerous-J-Dev/insaniquarium-mac/releases/latest/download/update.sh | bash
  ```
  (or double-click `Update Insaniquarium.command`). It downloads the latest
  release, re-grafts your existing game assets onto the new build, and swaps it
  in with a rollback safety net. It asks for **Full Disk Access** again because
  the app's signature changed: remove the app from that list and add it back,
  since switching it off and on does not refresh the old grant.
- **Verify a download:** every release ships a `.sha256` sidecar, and
  `update.sh` checks it automatically before installing anything. To check a
  manually downloaded tarball yourself, put both files in one folder and run
  `shasum -a 256 -c insaniquarium-mac-<tag>.tar.gz.sha256`.
- **Built from source** (this repo): `git pull && ./setup.sh`. The full game
  source is in-tree, so a pull brings every fix.

Maintainer notes: releases are universal builds. Run `scripts/build-deps.sh`
once (it builds SDL2, libpng, libjpeg-turbo, ogg, vorbis, libopenmpt and
mpg123 from pinned, checksummed sources for both CPUs at macOS 12, into
`build/deps/universal`), then configure with
`cmake -G Ninja -B build -DINSANIQ_DEPS_DIR="$PWD/build/deps/universal"`.
`make-dist.sh` refuses any binary that is not universal, needs a macOS newer
than 12, or loads a library from outside macOS and the bundle, so a Homebrew
build (still fine for development) cannot be released by accident.
Updaters from 1.2.0 on find the repository by its permanent ID, so renames
can't break them. Copies installed before the account rename (1.1.11 and
earlier) ask for `Jake-Vellora/insaniquarium-mac` by name and only trust files
listed under it; GitHub has retired that name, so no bridge can be published
there, and those players update by running the install command once.
`scripts/release.sh` cuts a release (gates on a clean `main`
in sync with origin, builds the slim tarball, tags, and uploads the tarball,
`.sha256`, and `update.sh`). Release notes come from the matching
`## <version>` section of `CHANGELOG.md`; the script refuses to release
without one. Checkouts from before 2026-07-23 had `WinFish/`
and `PvZ-Portable/` as separate gitignored clones; on such a checkout run
`rm -rf WinFish PvZ-Portable`, then `git pull` and
`git checkout -- WinFish PvZ-Portable` to switch to the vendored layout.

## SDL runtime packaging

Both packaging scripts inspect the SDL2 library inside their bundle. Classic
SDL2 needs no additional runtime. If the bundled library identifies itself as
`sdl2-compat`, the scripts explicitly include SDL3: that dependency is loaded
with `dlopen`, so it is invisible to the normal dylibbundler dependency walk.
`libSDL3.dylib` is copied beside SDL2, its non-system dependencies are bundled,
and the library and completed bundle are signed and verified. Repackaging a
previously packaged screensaver refreshes SDL3 as well.

The default runtime comes from `brew --prefix sdl3`. For a custom SDL build,
set `SDL3_DYLIB` to the full path of a matching SDL3 dylib when packaging or
running `setup.sh`. The runtime must support every architecture of the bundled
SDL2. If it is missing or incompatible, packaging fails before installation.

## Repository layout

- `CMakeLists.txt`: builds the game, the screensaver, and dev tools
- `setup.sh`: the one-step installer (also ships in the release dist tarball
  made by `scripts/make-dist.sh`)
- `scripts/package.sh`, `scripts/package-saver.sh`: relocatable bundle
  packaging (dylibbundler + ad-hoc codesign)
- `scripts/steam-play-button/`: the Steam `appinfo.vdf` injection, manifest,
  durability agent, uninstaller
- `WinFish/`: the game's C++ source (public decompilation + the port's patches)
- `PvZ-Portable/`: the SDL2/OpenGL SexyAppFramework the game runs on

## Credits & legal

- Game © PopCap Games / Electronic Arts. **Buy it on Steam**; this project
  is useless without a Steam license and distributes **no game assets**. The
  game code included here is the publicly available WinFish decompilation.
- Decompilation lineage: [Vindirect/WinFish](https://github.com/Vindirect/WinFish),
  macOS/SDL2 groundwork by [kyle-sylvestre](https://github.com/kyle-sylvestre)
  (WinFish + PvZ-Portable forks), framework originally from the PvZ-Portable
  project.
- Bug hunting: **Jakob**, whose Virtual Tank testing uncovered the
  infinite Presto duplication glitch, and the horribly depressed guppies born in 1970 most notably.
- `scripts/steam-play-button/sme/appinfo.py` is from
  [Steam-Metadata-Editor](https://github.com/tralph3/Steam-Metadata-Editor)
  (tralph3, GPL-3.0).
- `packaging/libsteam_api.dylib` is Valve's redistributable Steamworks
  library.
- Everything original to this repo (the build system, packaging and installer
  scripts, Steam-integration tooling, and screensaver code) is MIT licensed;
  see `LICENSE`. The MIT license does NOT cover: the game code
  vendored under `WinFish/` and `PvZ-Portable/` (which retains its upstream
  status), Insaniquarium's assets (© PopCap Games / Electronic Arts, never
  distributed here), vendored third-party code (see
  `scripts/steam-play-button/sme/NOTICE`), or Valve's redistributable
  `libsteam_api.dylib`.
