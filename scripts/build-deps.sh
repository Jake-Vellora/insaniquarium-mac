#!/bin/bash
# Build the libraries the game links from pinned sources, for both Mac CPUs
# (Apple Silicon arm64 and Intel x86_64), targeting macOS 12, and merge them into
# one universal prefix:
#
#   build/deps/universal/{include,lib}
#
# Release builds use this instead of Homebrew, whose libraries are arm64-only,
# are built for the newest macOS, and whose "sdl2" is now SDL3 underneath.
#
# The versions are the ones 1.1.11 shipped with. Each download is checked
# against its sha256 before anything is unpacked.
#
# Usage: scripts/build-deps.sh              (re-running reuses finished pieces)
#        scripts/build-deps.sh --clean      (start over, keeping the downloads)
#        scripts/build-deps.sh --fetch-only (download and verify, build nothing)
# Then:  cmake -G Ninja -B build -DINSANIQ_DEPS_DIR="$PWD/build/deps/universal"
set -euo pipefail
cd "$(dirname "$0")/.."

ROOT="${DEPS_ROOT:-$PWD/build/deps}"
MINOS=12.0
ARCHS=(arm64 x86_64)
JOBS="$(sysctl -n hw.ncpu)"

# name|version|url|sha256
SOURCES=(
	"libogg|1.3.6|https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-1.3.6.tar.gz|83e6704730683d004d20e21b8f7f55dcb3383cdf84c0daedf30bde175f774638"
	"libvorbis|1.3.7|https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-1.3.7.tar.xz|b33cc4934322bcbf6efcbacf49e3ca01aadbea4114ec9589d1b1e9d20f72954b"
	"mpg123|1.33.6|https://www.mpg123.de/download/mpg123-1.33.6.tar.bz2|929a7c18ba662b8927aed4de229ad9ae8ab2b4806dd0f30b90113eb1b4e2195a"
	"libopenmpt|0.8.7|https://lib.openmpt.org/files/libopenmpt/src/libopenmpt-0.8.7+release.autotools.tar.gz|275c29ef47be9992f62a35fcc96f7ca05c06d2fd05c9298b8dee9f743f75b089"
	"libpng|1.6.58|https://downloads.sourceforge.net/project/libpng/libpng16/1.6.58/libpng-1.6.58.tar.xz|28eb403f51f0f7405249132cecfe82ea5c0ef97f1b32c5a65828814ae0d34775"
	"libjpeg-turbo|3.2.0|https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.2.0/libjpeg-turbo-3.2.0.tar.gz|6f30092cef9fb839779646608f4ee14ae3cbac989c47fa05e841b0841f09878e"
	"SDL2|2.32.10|https://github.com/libsdl-org/SDL/releases/download/release-2.32.10/SDL2-2.32.10.tar.gz|5f5993c530f084535c65a6879e9b26ad441169b3e25d789d83287040a9ca5165"
)

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }

if [ "${1:-}" = "--clean" ]; then
	rm -rf "$ROOT/work" "$ROOT/universal"
	for a in "${ARCHS[@]}"; do rm -rf "${ROOT:?}/$a"; done
fi
mkdir -p "$ROOT/src"

# --- Download + verify -------------------------------------------------------
fetch() { # name version url sha256
	local file="$ROOT/src/$(basename "$3")"
	if [ ! -f "$file" ]; then
		say "Downloading $1 $2"
		curl -fL --retry 3 -o "$file.part" "$3" && mv "$file.part" "$file"
	fi
	local got; got="$(shasum -a 256 "$file" | awk '{print $1}')"
	[ "$got" = "$4" ] || { mv "$file" "$file.bad"; die "$1: checksum mismatch (got $got) - moved to $file.bad"; }
}
for entry in "${SOURCES[@]}"; do
	IFS='|' read -r name version url sha <<<"$entry"
	fetch "$name" "$version" "$url" "$sha"
done
echo "all ${#SOURCES[@]} downloads match their pinned sha256"
[ "${1:-}" = "--fetch-only" ] && exit 0

# --- Per-arch builds ---------------------------------------------------------
# Unpack a fresh copy of a source tree for one arch; prints its path.
unpack() { # name arch
	local entry name version url sha dir
	for entry in "${SOURCES[@]}"; do
		IFS='|' read -r name version url sha <<<"$entry"
		[ "$name" = "$1" ] && break
	done
	dir="$ROOT/work/$2/$name"
	rm -rf "$dir"; mkdir -p "$dir"
	tar -xf "$ROOT/src/$(basename "$url")" -C "$dir" --strip-components 1
	echo "$dir"
}

cmake_build() { # name arch prefix [extra cmake args...]
	local name="$1" arch="$2" prefix="$3"; shift 3
	local src; src="$(unpack "$name" "$arch")"
	cmake -S "$src" -B "$src/_build" -G Ninja -Wno-dev \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_OSX_ARCHITECTURES="$arch" \
		-DCMAKE_OSX_DEPLOYMENT_TARGET="$MINOS" \
		-DCMAKE_INSTALL_PREFIX="$prefix" \
		-DCMAKE_INSTALL_NAME_DIR="$prefix/lib" -DCMAKE_MACOSX_RPATH=OFF \
		-DCMAKE_PREFIX_PATH="$prefix" \
		-DCMAKE_IGNORE_PREFIX_PATH="/opt/homebrew;/usr/local;/opt/local" \
		-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
		-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
		-DBUILD_SHARED_LIBS=OFF \
		"$@" >"$src/_configure.log" 2>&1 || { tail -30 "$src/_configure.log"; die "$name ($arch): configure failed"; }
	cmake --build "$src/_build" -j "$JOBS" >"$src/_build.log" 2>&1 || { tail -30 "$src/_build.log"; die "$name ($arch): build failed"; }
	cmake --install "$src/_build" >"$src/_install.log" 2>&1 || die "$name ($arch): install failed"
}

autotools_build() { # name arch prefix [extra configure args...]
	local name="$1" arch="$2" prefix="$3"; shift 3
	local src host; src="$(unpack "$name" "$arch")"
	case "$arch" in arm64) host=aarch64-apple-darwin;; x86_64) host=x86_64-apple-darwin;; esac
	(
		cd "$src"
		export CC="clang -arch $arch" CXX="clang++ -arch $arch"
		export CFLAGS="-O2 -mmacosx-version-min=$MINOS" CXXFLAGS="-O2 -mmacosx-version-min=$MINOS"
		export LDFLAGS="-mmacosx-version-min=$MINOS" CPPFLAGS="-I$prefix/include"
		./configure --build=aarch64-apple-darwin --host="$host" --prefix="$prefix" "$@" \
			>_configure.log 2>&1 || { tail -30 _configure.log; exit 1; }
		make -j "$JOBS" >_build.log 2>&1 || { tail -30 _build.log; exit 1; }
		make install >_install.log 2>&1
	) || die "$name ($arch): build failed"
}

build_arch() { # arch
	local arch="$1" prefix="$ROOT/$1"
	if [ -f "$prefix/.done" ]; then echo "$arch: already built"; return; fi
	rm -rf "$prefix"; mkdir -p "$prefix"
	local mpgcpu; case "$arch" in arm64) mpgcpu=aarch64;; x86_64) mpgcpu=x86-64;; esac
	local P="$prefix"

	# ogg, vorbis and libopenmpt stay dylibs, as in 1.1.11: the framework has
	# its own Tremor decoder with the same ogg_*/ov_*/vorbis_* names, and only
	# separate images keep libopenmpt's calls away from those look-alikes.
	say "[$arch] libogg";        cmake_build libogg "$arch" "$P" -DBUILD_SHARED_LIBS=ON -DINSTALL_DOCS=OFF -DBUILD_TESTING=OFF
	say "[$arch] libvorbis";     cmake_build libvorbis "$arch" "$P" -DBUILD_SHARED_LIBS=ON -DOGG_ROOT="$P"
	say "[$arch] mpg123";        autotools_build mpg123 "$arch" "$P" \
		--enable-shared --disable-static --disable-components --enable-libmpg123 --with-cpu="$mpgcpu"
	# No pkg-config needed: configure takes each library's flags from these
	# variables, but treats an empty one as unset, hence the SDK include path.
	say "[$arch] libopenmpt";    ZLIB_CFLAGS="-I$(xcrun --show-sdk-path)/usr/include" ZLIB_LIBS="-lz" \
		MPG123_CFLAGS="-I$P/include" MPG123_LIBS="-L$P/lib -lmpg123" \
		OGG_CFLAGS="-I$P/include" OGG_LIBS="-L$P/lib -logg" \
		VORBIS_CFLAGS="-I$P/include" VORBIS_LIBS="-L$P/lib -lvorbis -logg" \
		VORBISFILE_CFLAGS="-I$P/include" VORBISFILE_LIBS="-L$P/lib -lvorbisfile -lvorbis -logg" \
		autotools_build libopenmpt "$arch" "$P" \
		--enable-shared --disable-static --disable-openmpt123 --disable-examples --disable-tests \
		--disable-doxygen-doc --without-portaudio --without-portaudiocpp --without-pulseaudio \
		--without-sndfile --without-flac --with-zlib --with-mpg123 --with-ogg --with-vorbis --with-vorbisfile
	# NEON/SSE paths in libpng and libjpeg-turbo pick their code from the HOST
	# CPU, not the target, so a cross build would compile the wrong one. The
	# portable C paths decode the same images; load-time speed is irrelevant here.
	say "[$arch] libpng";        cmake_build libpng "$arch" "$P" -DPNG_SHARED=OFF -DPNG_STATIC=ON \
		-DPNG_TESTS=OFF -DPNG_TOOLS=OFF -DPNG_FRAMEWORK=OFF -DPNG_HARDWARE_OPTIMIZATIONS=OFF
	say "[$arch] libjpeg-turbo"; cmake_build libjpeg-turbo "$arch" "$P" -DENABLE_SHARED=OFF -DENABLE_STATIC=ON \
		-DWITH_SIMD=OFF -DWITH_TURBOJPEG=OFF -DWITH_JAVA=OFF
	say "[$arch] SDL2";          cmake_build SDL2 "$arch" "$P" -DSDL_SHARED=OFF -DSDL_STATIC=ON \
		-DSDL_STATIC_PIC=ON -DSDL_TEST=OFF -DSDL_TESTS=OFF
	touch "$prefix/.done"
}

for a in "${ARCHS[@]}"; do build_arch "$a"; done

# --- Merge into one universal prefix ----------------------------------------
say "Merging arm64 + x86_64 into $ROOT/universal"
U="$ROOT/universal"
rm -rf "$U"; mkdir -p "$U/lib"
A="$ROOT/arm64" X="$ROOT/x86_64"

# Libraries: one fat file per library. SDL2, libpng and libjpeg are static;
# ogg, vorbis, libopenmpt (see above) and mpg123 (LGPL-2.1) are dylibs.
while IFS= read -r -d '' lib; do
	rel="${lib#$A/}"
	[ -f "$X/$rel" ] || die "x86_64 build has no $rel"
	mkdir -p "$(dirname "$U/$rel")"
	lipo -create "$lib" "$X/$rel" -output "$U/$rel"
done < <(find "$A/lib" -maxdepth 1 -type f \( -name '*.a' -o -name '*.dylib' \) -print0)
while IFS= read -r -d '' link; do
	ln -sf "$(readlink "$link")" "$U/lib/$(basename "$link")"
done < <(find "$A/lib" -maxdepth 1 -type l -name '*.dylib' -print0)
# Absolute install names under the universal prefix, like Homebrew's, so
# dylibbundler finds and bundles them the way package.sh always has (the
# packaging gates fail any build that still points here). Each slice was
# linked against its own per-arch prefix; point both at the merged files.
while IFS= read -r -d '' dylib; do
	args=(-id "$(otool -D "$dylib" | tail -1 | sed "s#^$A#$U#;s#^$X#$U#")")
	while read -r dep; do
		args+=(-change "$dep" "$(printf '%s' "$dep" | sed "s#^$A#$U#;s#^$X#$U#")")
	done < <(otool -L "$dylib" | awk '/^\t/{print $1}' | grep -E "^($A|$X)/" | sort -u)
	install_name_tool "${args[@]}" "$dylib" 2>/dev/null
	codesign --force -s - "$dylib" >/dev/null 2>&1
done < <(find "$U/lib" -maxdepth 1 -type f -name '*.dylib' -print0)

# Headers: identical files are copied; the few generated ones that differ per
# CPU are merged behind #if defined(__x86_64__).
cp -R "$A/include" "$U/include"
merged=0
while IFS= read -r -d '' h; do
	rel="${h#$X/include/}"
	if ! cmp -s "$h" "$A/include/$rel"; then
		{
			echo "/* universal build: the arm64 and x86_64 versions of this header differ */"
			echo "#if defined(__x86_64__)"; cat "$h"; echo; echo "#else"
			cat "$A/include/$rel"; echo; echo "#endif"
		} > "$U/include/$rel"
		merged=$((merged + 1)); echo "  merged per-CPU header: $rel"
	fi
done < <(find "$X/include" -type f -print0)

# CMake package files and pkg-config files, pointed at the universal prefix.
for d in lib/cmake lib/pkgconfig share/pkgconfig; do
	[ -d "$A/$d" ] || continue
	mkdir -p "$U/$d"; cp -R "$A/$d/." "$U/$d/"
done
for d in "$U/lib/cmake" "$U/lib/pkgconfig" "$U/share/pkgconfig"; do
	[ -d "$d" ] || continue
	grep -rlF "$A" "$d" | while read -r f; do sed -i '' "s#$A#$U#g" "$f"; done || true
done

# --- Gates -------------------------------------------------------------------
say "Checking the universal prefix"
fail=0
while IFS= read -r -d '' lib; do
	if ! lipo "$lib" -verify_arch arm64 x86_64 2>/dev/null; then echo "FAIL  not universal: $lib"; fail=1; fi
	if otool -L "$lib" 2>/dev/null | grep -qE "($A|$X)/"; then echo "FAIL  still points at a per-arch prefix: $lib"; fail=1; fi
	newest="$(otool -l "$lib" 2>/dev/null | awk '/minos/{print $2}' | sort -t. -k1,1n -k2,2n | tail -1)"
	if [ -n "$newest" ] && [ "$(printf '%s\n%s\n' "$newest" "$MINOS" | sort -t. -k1,1n -k2,2n | tail -1)" != "$MINOS" ]; then
		echo "FAIL  $lib needs macOS $newest (target $MINOS)"; fail=1
	fi
done < <(find "$U/lib" -maxdepth 1 -type f \( -name '*.a' -o -name '*.dylib' \) -print0)
[ "$fail" = 0 ] || die "universal prefix failed its checks"

{
	echo "built: $(date '+%Y-%m-%d %H:%M:%S'), macOS $MINOS minimum, arm64 + x86_64"
	for entry in "${SOURCES[@]}"; do IFS='|' read -r name version url sha <<<"$entry"; echo "$name $version $sha"; done
} > "$U/DEPS-VERSIONS.txt"
echo "universal prefix ready: $U ($merged per-CPU headers merged)"
ls -1 "$U/lib" | grep -E '\.(a|dylib)$' | sed 's/^/  /'
