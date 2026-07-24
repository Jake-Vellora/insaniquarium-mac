#!/bin/bash
# Detached helper the game spawns when the user clicks "Update Now" in the
# in-app updater. The game quits right after spawning us (an app can't replace
# its own bundle while running), so we: wait for it to fully exit, run the normal
# updater non-interactively, then relaunch the app. Runs headless (no Terminal).
#
# Arg 1: the game's pid (so we can wait for the exact process to exit).
set -uo pipefail

GAMEPID="${1:-}"
PORTHOME="$HOME/Library/Application Support/Insaniquarium-port"
mkdir -p "$PORTHOME"
exec >>"$PORTHOME/in-app-update.log" 2>&1
echo "=== in-app update $(date '+%F %T') pid=$GAMEPID ==="

# Wait for the game to fully exit, so update.sh's "game is running" guard passes.
if [ -n "$GAMEPID" ]; then
  for _ in $(seq 1 100); do kill -0 "$GAMEPID" 2>/dev/null || break; sleep 0.2; done
fi
for _ in $(seq 1 50); do
  pgrep -f 'Insaniquarium.app/Contents/MacOS/insaniquarium' >/dev/null || break
  sleep 0.2
done

if [ -x "$PORTHOME/update.sh" ]; then
  bash "$PORTHOME/update.sh" --yes || echo "update.sh exited $?"
else
  echo "error: $PORTHOME/update.sh missing"
fi

# Always reopen: on 'already latest' or a transient failure the existing install
# is intact (the updater swaps atomically with rollback), so we never leave the
# user without a game.
echo "relaunching"
open "/Applications/Insaniquarium.app" || true
