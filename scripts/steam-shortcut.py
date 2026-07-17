#!/usr/bin/env python3
"""Add Insaniquarium.app as a Steam non-Steam shortcut with official artwork.

Writes shortcuts.vdf (binary VDF) for the given Steam user and drops the
official appid-3320 library artwork into config/grid/ named by the computed
shortcut appid. Backs up any existing shortcuts.vdf first. Steam must be quit.
"""
import os
import shutil
import struct
import sys
import time
import urllib.request
import zlib

STEAM_USER = "95488321"
APP_NAME = "Insaniquarium! Deluxe"
EXE = "/Applications/Insaniquarium.app"
START_DIR = "/Applications/"
CONFIG = os.path.expanduser(f"~/Library/Application Support/Steam/userdata/{STEAM_USER}/config")
CDN = "https://cdn.cloudflare.steamstatic.com/steam/apps/3320"


def shortcut_appid(exe: str, appname: str) -> int:
    crc = zlib.crc32((f'"{exe}"' + appname).encode("utf-8")) & 0xFFFFFFFF
    return crc | 0x80000000


def s(key: str, val: str) -> bytes:
    return b"\x01" + key.encode() + b"\x00" + val.encode() + b"\x00"


def i(key: str, val: int) -> bytes:
    return b"\x02" + key.encode() + b"\x00" + struct.pack("<I", val & 0xFFFFFFFF)


def build_vdf(appid: int) -> bytes:
    entry = (
        i("appid", appid)
        + s("appname", APP_NAME)
        + s("exe", f'"{EXE}"')
        + s("StartDir", f'"{START_DIR}"')
        + s("icon", "")
        + s("ShortcutPath", "")
        + s("LaunchOptions", "")
        + i("IsHidden", 0)
        + i("AllowDesktopConfig", 1)
        + i("AllowOverlay", 1)
        + i("OpenVR", 0)
        + i("Devkit", 0)
        + s("DevkitGameID", "")
        + i("DevkitOverrideAppID", 0)
        + i("LastPlayTime", int(time.time()))
        + s("FlatpakAppID", "")
        + b"\x00tags\x00" + b"\x08"
    )
    return b"\x00shortcuts\x00" + b"\x000\x00" + entry + b"\x08" + b"\x08" + b"\x08"


def fetch(url: str, dest: str) -> bool:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=30) as r, open(dest, "wb") as f:
            shutil.copyfileobj(r, f)
        print(f"  fetched {os.path.basename(dest)} <- {url}")
        return True
    except Exception as e:
        print(f"  MISSING {url}: {e}")
        return False


def main() -> None:
    appid = shortcut_appid(EXE, APP_NAME)
    print(f"shortcut appid: {appid}")

    vdf_path = os.path.join(CONFIG, "shortcuts.vdf")
    if os.path.exists(vdf_path):
        backup = vdf_path + ".bak." + str(int(time.time()))
        shutil.copy2(vdf_path, backup)
        print(f"backed up existing shortcuts.vdf -> {backup}")
        sys.exit("refusing to merge into an existing shortcuts.vdf; merge manually")

    os.makedirs(CONFIG, exist_ok=True)
    with open(vdf_path, "wb") as f:
        f.write(build_vdf(appid))
    print(f"wrote {vdf_path}")

    grid = os.path.join(CONFIG, "grid")
    os.makedirs(grid, exist_ok=True)
    fetch(f"{CDN}/library_600x900_2x.jpg", os.path.join(grid, f"{appid}p.jpg"))
    fetch(f"{CDN}/library_hero.jpg", os.path.join(grid, f"{appid}_hero.jpg"))
    fetch(f"{CDN}/logo.png", os.path.join(grid, f"{appid}_logo.png"))
    fetch(f"{CDN}/header.jpg", os.path.join(grid, f"{appid}.jpg"))


if __name__ == "__main__":
    main()
