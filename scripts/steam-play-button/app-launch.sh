#!/bin/bash
# Shared by the installer and durability agent. Steam launches the .app bundle
# so macOS can attribute protected-file access to the app with the FDA grant.

ensure_app_launch_link() {
	local target=/Applications/Insaniquarium.app
	local link="$STEAM/steamapps/common/$INSTALLDIR/Insaniquarium.app"
	mkdir -p "$(dirname "$link")" || return 1
	if [ -L "$link" ]; then
		[ "$(readlink "$link")" = "$target" ] && return 0
		# Unlink only the symlink; never follow a directory link into the app.
		rm -f "$link" || return 1
	elif [ -e "$link" ]; then
		echo "error: $link exists and is not a symlink; left untouched" >&2
		return 1
	fi
	# Another installer/agent invocation may have created the same link.
	ln -s "$target" "$link" || {
		[ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]
	}
}
