# Insaniquarium! Deluxe: native Mac setup

This gets Insaniquarium running **natively on your Apple Silicon Mac**,
launched from the **real Steam Play button**, with the Steam overlay
(Shift+Tab) and a **macOS screensaver** that shows your actual virtual tank.

This folder contains **no game content**. Your own Steam account (owned or
family-shared) downloads the game files during setup; the script has Steam
do it automatically.

## What you need

- An Apple Silicon Mac (M1 or newer)
- Steam installed and signed in, with **Insaniquarium! Deluxe** visible in
  your Library (family-shared is fine; enable the shared-games filter)
- About 10 minutes

## Setup

1. Open **Terminal** (Cmd+Space, type "Terminal").
2. Drag this folder's `setup.sh` into the Terminal window, or type
   `bash ` (with the trailing space) and then drag it, then press **Return**.
3. Follow the prompts. The script will:
   - install the app and the screensaver
   - teach Steam that the game has a native Mac build
   - start Steam and have it **download the game files by itself** (~11 MB).
     Steam will pop up a "missing executable" error right after; that's
     expected at this stage; just close it.
   - finish the wiring so the Play button launches the native app
4. Two things macOS makes you do by hand (the script walks you through both):
   - **Full Disk Access** for Insaniquarium (stops a repeating permission
     popup; the game and screensaver share your tank data)
   - **System Settings > Screen Saver**: pick "Insaniquarium"

If the Command Line Tools dialog appears at the start: click Install, wait,
then run `setup.sh` again. That's normal on a fresh Mac.

## Afterwards

- Steam > Play launches the game; Shift+Tab is the overlay; playtime counts.
- The screensaver shows the fish you actually own; coins it earns while
  saving your screen are credited next time you open the game.
- Health-check any time: `bash setup.sh verify`
- Uninstall everything: `bash scripts/uninstall.sh` (add `--purge-saves`
  to also delete profiles/tanks). Steam must be quit first.

## If something goes wrong

- **The download never starts**: quit Steam, run `setup.sh` again (it
  re-applies its Steam edit and retries; the script already retries once on
  its own).
- **Don't click Install or "verify integrity" in Steam's own UI during
  setup**: those force a metadata refresh that undoes the script's work.
  Let the script drive; it uses a path that survives.
- **Game won't launch from Play**: run `bash setup.sh verify` and read the
  FAIL lines. Never force-kill the game; quit it normally, or Steam will
  think it's still running until you restart Steam.
- Family Sharing rules still apply: if the owner is playing from the same
  shared library, Steam may make you wait.

## What's in here

- `payload/`: prebuilt app + screensaver, **without** game assets
- `scripts/`: the Steam-integration scripts (`appinfo.py` is from
  tralph3's Steam-Metadata-Editor, GPL; see `scripts/sme/NOTICE`)
- `src/`: git bundles of the full source (for rebuilding; you can ignore)
- `SHA256SUMS`: file checksums
