#!/bin/sh
# Steam launch wrapper for the real appid-3320 macOS launch entry.
# Steam resolves this executable relative to the install dir
# (steamapps/common/Insaniquarium Deluxe/). It hands off to the native app
# and blocks (open -W) so Steam sees the game as running for the whole session.
date "+%Y-%m-%d %H:%M:%S launched via Steam appid 3320" >> "$HOME/iq_play_marker.txt"
exec open -W -a /Applications/Insaniquarium.app
