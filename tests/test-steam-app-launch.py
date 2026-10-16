"""Test launcher migration and link repair without touching a real Steam install.

Run: python3 tests/test-steam-app-launch.py
Steam, Full Disk Access, and the overlay need a native macOS smoke test.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASH = os.environ.get("PACKAGING_TEST_BASH") or shutil.which("bash")


def shell_path(path):
    value = str(path).replace("\\", "/")
    if os.name == "nt" and len(value) > 1 and value[1] == ":":
        value = "/" + value[0].lower() + value[2:]
    return value


# Keep the real launch-entry editor, substituting only its binary-VDF adapter.
# Checksum serialization is unchanged by this PR and belongs to that adapter.
FAKE_APPINFO = '''import json
from pathlib import Path
class Appinfo:
    def __init__(self, path, **kwargs):
        self.path = Path(path)
        self.parsedAppInfo = {3320: {"sections": {"appinfo": json.loads(self.path.read_text())}}}
    def update_app(self, appid):
        pass
    def write_data(self):
        self.path.write_text(json.dumps(self.parsedAppInfo[3320]["sections"]["appinfo"]))
'''


class SteamLauncherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(
            prefix="steam-launch-", dir=os.environ.get("PACKAGING_TEST_TMPDIR"))
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / "checkout with spaces"
        self.scripts = self.repo / "scripts/steam-play-button"
        self.scripts.mkdir(parents=True)
        for name in ("app-launch.sh", "edit_appinfo.py", "inject.sh", "reapply.sh", "run.sh"):
            target = self.scripts / name
            target.write_text((ROOT / "scripts/steam-play-button" / name).read_text())
            target.chmod(0o755)
        (self.scripts / "sme").mkdir()
        (self.scripts / "sme/appinfo.py").write_text(FAKE_APPINFO)
        self.home = self.base / "fake home"
        self.steam = self.home / "Library/Application Support/Steam"
        self.game = self.steam / "steamapps/common/Insaniquarium Deluxe"
        (self.steam / "appcache").mkdir(parents=True)
        self.game.mkdir(parents=True)
        self.appinfo = self.steam / "appcache/appinfo.vdf"
        self.original_metadata = {
            "common": {"oslist": "windows,macos"},
            "config": {"launch": {
                "0": {"executable": "Insaniquarium.exe", "config": {"oslist": "windows"}},
                "1": {"executable": "insaniquarium", "type": "default",
                      "description": "Native macOS", "config": {"oslist": "macos"}},
            }},
        }
        self.appinfo.write_text(json.dumps(self.original_metadata))
        self.manifest = self.steam / "steamapps/appmanifest_3320.acf"
        self.manifest.write_text('"StateFlags" "4"\n"installdir" "Insaniquarium Deluxe"\n')
        self.mockbin = self.base / "mockbin"
        self.mockbin.mkdir()
        mocks = {
            "pgrep": '#!/bin/bash\n[ "${TEST_STEAM_RUNNING:-0}" = 1 ]\n',
            "python3": '#!/bin/bash\nexec "$TEST_PYTHON" "$@"\n',
        }
        for name, contents in mocks.items():
            target = self.mockbin / name
            target.write_text(contents)
            target.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update(HOME=shell_path(self.home), TEST_STEAM_RUNNING="0",
                        TEST_PYTHON=shell_path(sys.executable), PYTHONDONTWRITEBYTECODE="1")
        if os.name == "nt":
            # Git Bash's default copies symlink targets; its sys mode supports
            # POSIX link tests without Windows's native symlink privilege.
            self.env["MSYS"] = "winsymlinks:sys"

    def run_shell(self, command):
        return subprocess.run([BASH, "-c", 'export PATH="$1:$PATH"; ' + command,
                               "test", shell_path(self.mockbin)],
                              cwd=self.repo, env=self.env, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout)

    def check_link(self):
        self.assert_ok(self.run_shell(
            'link="$HOME/Library/Application Support/Steam/steamapps/common/'
            'Insaniquarium Deluxe/Insaniquarium.app"; '
            '[ -L "$link" ] && [ "$(readlink "$link")" = /Applications/Insaniquarium.app ]'))

    def repair_link(self):
        return self.run_shell(
            'set -euo pipefail; source scripts/steam-play-button/app-launch.sh; '
            'STEAM="$HOME/Library/Application Support/Steam"; '
            'INSTALLDIR="Insaniquarium Deluxe"; ensure_app_launch_link')

    def test_finalize_creates_bundle_link_and_preserves_manifest(self):
        manifest = self.manifest.read_bytes()
        self.assert_ok(self.run_shell('bash scripts/steam-play-button/inject.sh --phase finalize'))
        self.check_link()
        self.assertEqual(self.manifest.read_bytes(), manifest)
        self.assertTrue((self.game / "run.sh").is_file())

    def test_metadata_migration_and_idempotence(self):
        self.assert_ok(self.run_shell('bash scripts/steam-play-button/inject.sh --phase appinfo'))
        first = self.appinfo.read_bytes()
        metadata = json.loads(first)
        self.assertEqual(metadata["config"]["launch"]["1"]["executable"], "Insaniquarium.app")
        self.assertEqual(metadata["config"]["launch"]["0"],
                         self.original_metadata["config"]["launch"]["0"])
        self.assert_ok(self.run_shell('bash scripts/steam-play-button/inject.sh --phase appinfo'))
        self.assertEqual(self.appinfo.read_bytes(), first)

    def test_agent_repairs_metadata_and_link_while_steam_runs(self):
        self.env["TEST_STEAM_RUNNING"] = "1"
        manifest = self.manifest.read_bytes()
        self.assert_ok(self.run_shell('bash scripts/steam-play-button/reapply.sh'))
        self.check_link()
        metadata = json.loads(self.appinfo.read_bytes())
        self.assertEqual(metadata["config"]["launch"]["1"]["executable"], "Insaniquarium.app")
        self.assertEqual(self.manifest.read_bytes(), manifest)
        self.assertFalse((self.game / "run.sh").exists())

    def test_agent_finalizes_when_steam_is_closed(self):
        self.assert_ok(self.run_shell('bash scripts/steam-play-button/reapply.sh'))
        self.check_link()
        self.assertTrue((self.game / "run.sh").exists())

    def test_repeated_repair_handles_dangling_bundle_link(self):
        self.assert_ok(self.repair_link())
        self.assert_ok(self.repair_link())
        self.check_link()

    def test_wrong_directory_link_is_replaced_without_touching_target(self):
        target = self.base / "other app"
        target.mkdir()
        (target / "keep-me").write_text("preserve")
        self.env["TEST_LINK_TARGET"] = shell_path(target)
        self.assert_ok(self.run_shell(
            'ln -s "$TEST_LINK_TARGET" "$HOME/Library/Application Support/Steam/'
            'steamapps/common/Insaniquarium Deluxe/Insaniquarium.app"'))
        self.assert_ok(self.repair_link())
        self.check_link()
        self.assertEqual((target / "keep-me").read_text(), "preserve")
        self.assertEqual(list(target.iterdir()), [target / "keep-me"])

    def test_existing_real_directory_is_preserved(self):
        target = self.game / "Insaniquarium.app"
        target.mkdir()
        (target / "keep-me").write_text("preserve")
        result = self.repair_link()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("left untouched", result.stdout)
        self.assertEqual((target / "keep-me").read_text(), "preserve")

    def test_installer_refuses_to_edit_while_steam_runs(self):
        self.env["TEST_STEAM_RUNNING"] = "1"
        original = self.appinfo.read_bytes()
        result = self.run_shell('bash scripts/steam-play-button/inject.sh')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.appinfo.read_bytes(), original)

    def test_setup_copies_link_helper_into_installed_scripts(self):
        setup = (ROOT / "setup.sh").read_text()
        # Load setup's real function definitions without running its CLI.
        definitions = setup.split('\nCMD=install ASSETS=""', 1)[0]
        (self.repo / "setup-fixture.sh").write_text(definitions + '\ninstall_scripts\n')
        self.assert_ok(self.run_shell('bash setup-fixture.sh'))
        installed = self.home / "Library/Application Support/Insaniquarium-port"
        self.assertEqual((installed / "app-launch.sh").read_text(),
                         (self.scripts / "app-launch.sh").read_text())


if __name__ == "__main__":
    unittest.main(verbosity=2)
