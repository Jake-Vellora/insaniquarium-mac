#!/bin/bash
# Sourced by the packagers and make-dist.sh: checks on every Mach-O we ship.

RELEASE_ARCHS=(arm64 x86_64)
RELEASE_MINOS=12.0

# Libraries a binary loads from outside macOS and outside its own bundle, and
# absolute rpaths. Either one means it only runs on a machine set up like this
# one (Homebrew in /opt/homebrew or /usr/local, a local build folder, ...).
macho_outside_refs() { # file
	otool -L "$1" | awk '/^[ \t]/{print $1}' |
		grep -vE '^(/usr/lib/|/System/Library/|@executable_path/|@loader_path/|@rpath/)' |
		sed 's#^#links outside the bundle: #'
	otool -l "$1" | awk '$2 == "LC_RPATH" {r = 1; next} r && $1 == "path" {print $2; r = 0}' |
		grep -v '^@' | sed 's#^#absolute rpath: #'
	return 0
}

# Release binaries must carry both CPUs and run on macOS 12.
macho_release_problems() { # file
	local f="$1" a minos
	macho_outside_refs "$f"
	for a in "${RELEASE_ARCHS[@]}"; do
		if ! lipo "$f" -verify_arch "$a" 2>/dev/null; then
			echo "missing $a"
			continue
		fi
		minos="$(vtool -arch "$a" -show-build "$f" 2>/dev/null | awk '/minos/{print $2; exit}')"
		if [ -n "$minos" ] && [ "$(printf '%s\n%s\n' "$minos" "$RELEASE_MINOS" | sort -t. -k1,1n -k2,2n | tail -1)" != "$RELEASE_MINOS" ]; then
			echo "$a slice needs macOS $minos (releases target $RELEASE_MINOS)"
		fi
	done
}

# Every Mach-O inside a bundle (executables and dylibs, not resources).
bundle_machos() { # bundle
	find "$1/Contents" -type f \( -path '*/MacOS/*' -o -name '*.dylib' \) -print0 |
		while IFS= read -r -d '' f; do
			file -b "$f" | grep -q 'Mach-O' && printf '%s\0' "$f"
		done
}

# Prints one line per problem across a whole bundle; returns 1 if any.
bundle_release_problems() { # bundle
	local f out bad=0
	while IFS= read -r -d '' f; do
		out="$(macho_release_problems "$f")"
		if [ -n "$out" ]; then
			printf '%s\n' "$out" | sed "s#^#${f#$1/}: #"
			bad=1
		fi
	done < <(bundle_machos "$1")
	return "$bad"
}
