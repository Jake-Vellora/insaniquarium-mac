# Insaniquarium! Deluxe: native Apple Silicon port

Run the Steam release of **Insaniquarium! Deluxe** (appid 3320) **natively on
Apple Silicon**: a real ARM64 Mac app, no Wine, no Rosetta, launched from the
**real Steam Play button**, with the Steam overlay (Shift+Tab), playtime
tracking, and a native **macOS screensaver** that renders your actual virtual
tank (and pays out its coins back into your game).

```
git clone https://github.com/Jake-Vellora/insaniquarium-mac.git
cd insaniquarium-mac
./setup.sh
```

One command. It builds everything locally and walks you through the rest.

> **Before you run it:** be signed in to Steam with *Insaniquarium! Deluxe*
> visible in your Library (family-shared counts), and open the game's library
> page once. **Don't click Install**; the script does that part itself.
> Full walkthrough in [Setup, step by step](#setup-step-by-step).

## Requirements

- Apple Silicon Mac (M1 or newer)
- **Insaniquarium! Deluxe in your Steam library**, owned or via Family
  Sharing. This repo contains **no game content whatsoever**; during setup
  your own Steam client downloads the game files under your own license.
- Xcode Command Line Tools and [Homebrew](https://brew.sh) (setup.sh installs
  or prompts for both if missing)

## Setup, step by step

1. **Steam first**: install Steam, sign in, and make sure *Insaniquarium!
   Deluxe* appears in your Library (owned or family-shared; enable the
   shared-games filter if needed). Open its library page once so Steam caches
   the game's record. **Don't click Install**; the script handles that.
2. Open Terminal and run:
   ```
   git clone https://github.com/Jake-Vellora/insaniquarium-mac.git
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
   - **System Settings → Screen Saver** → pick *Insaniquarium*.
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
   entry pointing at the built app. Steam then treats it like any native game:
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

## After setup

- `./setup.sh verify`: health-check every piece (also prints the release marker)
- `scripts/steam-play-button/uninstall.sh`: full uninstall (`--purge-saves`
  to also remove save data)
- Don't force-kill the game (Steam will think it's still running); quit it
  normally.

## Updating

All methods preserve saves, Steam wiring, and screensaver selection.

- **In the game (easiest):** on v1.1.1+, open **Options → Check Updates**; if a
  new version is available, click **Update Now** and the game closes, updates
  itself, and reopens — no Terminal. (It also prompts weekly on its own.)
- **From a release tarball** — and the one-time way to get onto a version that
  has the in-app updater: quit the game and run
  ```
  curl -fsSL https://github.com/Jake-Vellora/insaniquarium-mac/releases/latest/download/update.sh | bash
  ```
  (or double-click `Update Insaniquarium.command`). It downloads the latest
  release, re-grafts your existing game assets onto the new build, and swaps it
  in with a rollback safety net. It asks for **Full Disk Access** again because
  the app's signature changed.
- **Verify a download:** every release ships a `.sha256` sidecar, and
  `update.sh` checks it automatically before installing anything. To check a
  manually downloaded tarball yourself, put both files in one folder and run
  `shasum -a 256 -c insaniquarium-mac-<tag>.tar.gz.sha256`.
- **Built from source** (this repo): `git pull && ./setup.sh`. The full game
  source is in-tree, so a pull brings every fix.

Maintainer notes: `scripts/release.sh` cuts a release (gates on a clean `main`
in sync with origin, builds the slim tarball, tags, and uploads the tarball,
`.sha256`, and `update.sh`). Release notes come from the matching
`## <version>` section of `CHANGELOG.md`; the script refuses to release
without one. Checkouts from before 2026-07-23 had `WinFish/`
and `PvZ-Portable/` as separate gitignored clones; on such a checkout run
`rm -rf WinFish PvZ-Portable`, then `git pull` and
`git checkout -- WinFish PvZ-Portable` to switch to the vendored layout.

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
- `scripts/steam-play-button/sme/appinfo.py` is from
  [Steam-Metadata-Editor](https://github.com/tralph3/Steam-Metadata-Editor)
  (tralph3, GPL-3.0).
- `packaging/libsteam_api.dylib` is Valve's redistributable Steamworks
  library.
- Everything original to this repo — the build system, packaging and
  installer scripts, Steam-integration tooling, and screensaver code — is MIT
  licensed; see `LICENSE`. The MIT license does NOT cover: the game code
  vendored under `WinFish/` and `PvZ-Portable/` (which retains its upstream
  status), Insaniquarium's assets (© PopCap Games / Electronic Arts, never
  distributed here), vendored third-party code (see
  `scripts/steam-play-button/sme/NOTICE`), or Valve's redistributable
  `libsteam_api.dylib`.
