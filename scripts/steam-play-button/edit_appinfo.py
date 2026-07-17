#!/usr/bin/env python3
"""Inject / revert a native macOS launch entry for appid 3320 in Steam's
appinfo.vdf, using the vendored v29-aware parser (sme/appinfo.py, GPL, tralph3).

Steam's appinfo.vdf is server-authoritative and guarded by a per-record size
field + two SHA-1 checksums; a raw hex edit is rejected. This uses the parser's
update_app() to recompute size + both checksums. Steam MUST be quit.

Usage:
  edit_appinfo.py inject <appinfo.vdf>   # add macos oslist + launch/1 -> run.sh
  edit_appinfo.py revert <appinfo.vdf>   # remove them
  edit_appinfo.py show   <appinfo.vdf>   # print current 3320 oslist + launch
"""
import os
import sys

APPID = 3320
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "sme"))
from appinfo import Appinfo  # noqa: E402


def app_sections(a):
    return a.parsedAppInfo[APPID]["sections"]["appinfo"]


def show(path):
    ai = app_sections(Appinfo(path, choose_apps=True, apps=[APPID]))
    print("oslist:", repr(ai["common"].get("oslist")))
    print("launch:", ai["config"].get("launch"))


WANT_LAUNCH = {"executable": "run.sh", "type": "default", "config": {"oslist": "macos"}}


def inject(path):
    a = Appinfo(path, choose_apps=True, apps=[APPID])
    ai = app_sections(a)
    oslist = ai["common"].get("oslist") or "windows"
    parts = [p for p in oslist.split(",") if p]
    # Idempotent: no write when already in the desired state, so a file-watch
    # reapply can't loop on its own edits.
    if "macos" in parts and ai["config"].get("launch", {}).get("1") == WANT_LAUNCH:
        print("already injected; no change")
        return
    if "macos" not in parts:
        parts.append("macos")
    ai["common"]["oslist"] = ",".join(parts)
    ai["config"].setdefault("launch", {})["1"] = dict(WANT_LAUNCH)
    a.update_app(APPID)
    a.write_data()
    print("injected: oslist=%s, launch/1=run.sh (macos)" % ai["common"]["oslist"])


def revert(path):
    a = Appinfo(path, choose_apps=True, apps=[APPID])
    ai = app_sections(a)
    oslist = ai["common"].get("oslist") or ""
    parts = [p for p in oslist.split(",") if p and p != "macos"]
    if parts:
        ai["common"]["oslist"] = ",".join(parts)
    elif "oslist" in ai["common"]:
        del ai["common"]["oslist"]
    launch = ai["config"].get("launch", {})
    launch.pop("1", None)
    a.update_app(APPID)
    a.write_data()
    print("reverted 3320 appinfo edits")


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("inject", "revert", "show"):
        sys.exit(__doc__)
    {"inject": inject, "revert": revert, "show": show}[sys.argv[1]](sys.argv[2])
