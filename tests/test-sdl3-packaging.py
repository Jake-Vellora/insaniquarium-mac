"""Exercise the real packaging scripts with mocked macOS tools.

Run with python3 tests/test-sdl3-packaging.py. This does not validate Mach-O
loading or Apple's code signing; those require a native macOS smoke test.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASH = os.environ.get("PACKAGING_TEST_BASH") or shutil.which("bash")


def shell_path(path):
    value = str(path).replace("\\", "/")
    if os.name == "nt" and len(value) > 1 and value[1] == ":":
        value = "/" + value[0].lower() + value[2:]
    return value


MOCK = r'''#!/bin/bash
set -eu
cmd="$(basename "$0")"
printf '%s %s\n' "$cmd" "$*" >> "$TEST_LOG"
case "$cmd" in
  brew)
    [ "${TEST_NO_BREW:-0}" != 1 ] || exit 1
    printf '%s\n' "$TEST_SDL3_PREFIX" ;;
  lipo)
    if [ "$1" = -archs ]; then
      echo arm64
    else
      [ "${TEST_BAD_ARCH:-0}" != 1 ] || exit 1
    fi ;;
  dylibbundler)
    bin= dest=
    while [ $# -gt 0 ]; do
      case "$1" in
        -x) bin="$2"; shift 2 ;;
        -d) dest="$2"; shift 2 ;;
        -p) shift 2 ;;
        *) shift ;;
      esac
    done
    mkdir -p "$dest"
    if [ "$(basename "$bin")" != libSDL3.dylib ]; then
      printf '%s\n' "$TEST_SDL2_KIND" > "$dest/libSDL2-2.0.0.dylib"
      touch "$bin.relocated"
    fi ;;
  otool)
    if [ ! -f "$2.relocated" ]; then
      echo ' /opt/homebrew/lib/libSDL2-2.0.0.dylib'
    else
      echo ' @loader_path/../Frameworks/libSDL2-2.0.0.dylib'
    fi ;;
  codesign)
    [ "${TEST_BAD_SIGN:-0}" != 1 ] || exit 1
    target="${!#}"
    if [ -d "$target" ] && [ "$TEST_SDL2_KIND" = sdl2-compat ]; then
      [ -f "$target/Contents/Frameworks/libSDL3.dylib" ]
    fi ;;
esac
'''


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(
            prefix="insaniq-packaging-", dir=os.environ.get("PACKAGING_TEST_TMPDIR"))
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / "checkout with spaces"
        (self.repo / "scripts").mkdir(parents=True)
        for name in ("package.sh", "package-saver.sh", "bundle-sdl3.sh"):
            shutil.copyfile(ROOT / "scripts" / name, self.repo / "scripts" / name)
        (self.repo / "packaging").mkdir()
        (self.repo / "packaging/Info.plist").write_text("fixture")
        for name in ("images", "sounds", "music", "fishsongs", "data", "properties"):
            folder = self.repo / "build/assets" / name
            folder.mkdir(parents=True)
            (folder / "asset").write_text(name)
        (self.repo / "build/insaniquarium").write_text("game")
        self.saver = self.repo / "build/Insaniquarium.saver"
        (self.saver / "Contents/MacOS").mkdir(parents=True)
        (self.saver / "Contents/MacOS/Insaniquarium").write_text("saver")
        self.mockbin = self.base / "mockbin"
        self.mockbin.mkdir()
        for name in ("brew", "lipo", "dylibbundler", "otool", "codesign"):
            mock = self.mockbin / name
            with mock.open("w", newline="\n") as output:
                output.write(MOCK)
            mock.chmod(0o755)
        self.prefix = self.base / "homebrew SDL3"
        (self.prefix / "lib").mkdir(parents=True)
        (self.prefix / "lib/libSDL3.dylib").write_bytes(b"SDL3 runtime v1\0")
        self.log = self.base / "commands.log"
        self.env = os.environ.copy()
        self.env.pop("SDL3_DYLIB", None)
        self.env.update(TEST_LOG=shell_path(self.log),
                        TEST_SDL3_PREFIX=shell_path(self.prefix),
                        TEST_SDL2_KIND="sdl2-compat")

    def run_shell(self, command):
        return subprocess.run([BASH, "-c", 'export PATH="$1:$PATH"; ' + command,
                               "test", shell_path(self.mockbin)],
                              cwd=self.repo, env=self.env, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

    def package(self, name):
        return self.run_shell("bash scripts/" + name)

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_compat_both_packagers(self):
        for name, bundle in (("package.sh", "Insaniquarium.app"),
                             ("package-saver.sh", "Insaniquarium.saver")):
            with self.subTest(packager=name):
                self.assert_ok(self.package(name))
                copied = self.repo / "build" / bundle / "Contents/Frameworks/libSDL3.dylib"
                self.assertEqual(copied.read_bytes(), b"SDL3 runtime v1\0")
                self.assertFalse(copied.is_symlink())

    def test_classic_sdl2_needs_no_sdl3(self):
        self.env.update(TEST_SDL2_KIND="classic SDL2", TEST_NO_BREW="1")
        for name in ("package.sh", "package-saver.sh"):
            self.assert_ok(self.package(name))
        self.assertFalse(any(line.startswith("brew ")
                             for line in self.log.read_text().splitlines()))
        self.assertFalse(list(self.repo.glob("build/*/Contents/Frameworks/libSDL3.dylib")))

    def test_repackaged_saver_refreshes_runtime(self):
        self.assert_ok(self.package("package-saver.sh"))
        (self.prefix / "lib/libSDL3.dylib").write_bytes(b"SDL3 runtime v2\0")
        self.assert_ok(self.package("package-saver.sh"))
        self.assertEqual((self.saver / "Contents/Frameworks/libSDL3.dylib").read_bytes(),
                         b"SDL3 runtime v2\0")

    def test_missing_runtime_blocks_install(self):
        (self.prefix / "lib/libSDL3.dylib").unlink()
        self.env["HOME"] = shell_path(self.base / "fake home")
        result = self.package("package-saver.sh --install")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("runtime not found", result.stdout)
        self.assertFalse((self.base / "fake home/Library/Screen Savers").exists())

    def test_custom_runtime_without_brew(self):
        self.env.update(SDL3_DYLIB=shell_path(self.prefix / "lib/libSDL3.dylib"),
                        TEST_NO_BREW="1")
        self.assert_ok(self.package("package.sh"))
        self.assertFalse(any(line.startswith("brew ")
                             for line in self.log.read_text().splitlines()))

    def test_homebrew_symlink_is_dereferenced(self):
        source = self.prefix / "lib/libSDL3.dylib"
        source.rename(self.prefix / "lib/libSDL3.0.dylib")
        self.assert_ok(self.run_shell(
            'ln -s libSDL3.0.dylib "$TEST_SDL3_PREFIX/lib/libSDL3.dylib"'))
        self.assert_ok(self.package("package.sh"))
        copied = self.repo / "build/Insaniquarium.app/Contents/Frameworks/libSDL3.dylib"
        self.assertEqual(copied.read_bytes(), b"SDL3 runtime v1\0")
        self.assertFalse(copied.is_symlink())

    def test_wrong_architecture_fails(self):
        self.env["TEST_BAD_ARCH"] = "1"
        self.assertNotEqual(self.package("package.sh").returncode, 0)

    def test_codesign_failure_fails_packaging(self):
        self.env["TEST_BAD_SIGN"] = "1"
        self.assertNotEqual(self.package("package.sh").returncode, 0)

    def test_framework_runtime_goes_beside_actual_sdl2(self):
        library_dir = self.saver / "Contents/Frameworks/SDL2.framework/Versions/A"
        library_dir.mkdir(parents=True)
        (library_dir / "SDL2").write_bytes(b"diagnostic: sdl2-compat\0")
        self.assert_ok(self.run_shell(
            'set -euo pipefail; source scripts/bundle-sdl3.sh; '
            'bundle_sdl3_runtime build/Insaniquarium.saver'))
        self.assertTrue((library_dir / "libSDL3.dylib").is_file())


if __name__ == "__main__":
    unittest.main(verbosity=2)
