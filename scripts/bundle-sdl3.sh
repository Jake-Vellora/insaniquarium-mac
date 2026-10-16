#!/bin/bash
# Sourced by both packagers. sdl2-compat dlopens SDL3, so dylibbundler cannot
# discover this dependency by walking the Mach-O load commands from SDL2.

resolve_sdl3_runtime() {
	local prefix
	if [ -n "${SDL3_DYLIB:-}" ]; then
		SDL3_RUNTIME_DYLIB="$SDL3_DYLIB"
	else
		prefix="$(brew --prefix sdl3)" || {
			echo "error: install SDL3 with 'brew install sdl3', or set SDL3_DYLIB" >&2
			return 1
		}
		SDL3_RUNTIME_DYLIB="$prefix/lib/libSDL3.dylib"
	fi
	[ -f "$SDL3_RUNTIME_DYLIB" ] || {
		echo "error: SDL3 runtime not found: $SDL3_RUNTIME_DYLIB" >&2
		return 1
	}
}

bundle_sdl3_runtime() {
	local frameworks="$1/Contents/Frameworks"
	local library runtime runtime_dir arch archs
	[ -d "$frameworks" ] || return 0
	while IFS= read -r -d '' library; do
		# Inspect the actual bundled SDL2, not whichever sdl2-config happens to
		# be on PATH. This embedded diagnostic identifies sdl2-compat without
		# loading it (which would fail when SDL3 is missing). Classic SDL2
		# needs no extra dependency. Avoid a strings|grep -q pipe under pipefail.
		if LC_ALL=C grep -aFq 'sdl2-compat' "$library"; then
			:
		else
			case $? in
				1) continue ;;
				*) echo "error: cannot inspect SDL2 runtime: $library" >&2; return 1 ;;
			esac
		fi
		resolve_sdl3_runtime || return 1
		archs="$(lipo -archs "$library")" || return 1
		for arch in $archs; do
			lipo -verify_arch "$arch" "$SDL3_RUNTIME_DYLIB" || return 1
		done
		runtime_dir="$(dirname "$library")"
		runtime="$runtime_dir/libSDL3.dylib"
		# Dereference Homebrew's symlink and use the exact filename SDL2
		# dlopens beside itself (also handles SDL2.framework/Versions/A/SDL2).
		cp -L "$SDL3_RUNTIME_DYLIB" "$runtime" || return 1
		chmod u+w "$runtime" || return 1
		# Include any non-system dependencies of SDL3 too. @loader_path works
		# in both the app and the macOS screensaver host.
		dylibbundler -of -cd -b -x "$runtime" \
			-d "$runtime_dir" -p @loader_path/ >/dev/null || return 1
		codesign --force -s - "$runtime" || return 1
		codesign --verify --strict "$runtime" || return 1
		echo "bundled libSDL3.dylib in $1"
	done < <(find "$frameworks" -type f \( -name 'libSDL2*.dylib' -o -name SDL2 \) -print0)
}
