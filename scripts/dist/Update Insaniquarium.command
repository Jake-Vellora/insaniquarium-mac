#!/bin/bash
# Double-click to update Insaniquarium to the latest build.
# (First time after AirDrop, macOS may block it: right-click > Open instead.)
# This just runs the same one-line updater you can paste into Terminal:
#   curl -fsSL https://github.com/Jake-Vellora/insaniquarium-mac/releases/latest/download/update.sh | bash
set -euo pipefail
echo "Updating Insaniquarium (quit the game first; Steam can stay open)..."
curl -fsSL https://github.com/Jake-Vellora/insaniquarium-mac/releases/latest/download/update.sh | bash
echo
read -r -p "Done. Press Return to close this window. " _
