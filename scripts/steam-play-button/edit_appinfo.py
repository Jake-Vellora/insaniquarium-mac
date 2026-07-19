#!/usr/bin/env python3
"""Inject / revert a native macOS launch entry for appid 3320 in Steam's
appinfo.vdf, using the vendored v29-aware parser (sme/appinfo.py, GPL, tralph3).

Steam's appinfo.vdf is server-authoritative and guarded by a per-record size
field + two SHA-1 checksums; a raw hex edit is rejected. This uses the parser's
update_app() to recompute size + both checksums. Steam MUST be quit.

Usage:
  edit_appinfo.py inject <appinfo.vdf>   # add macos oslist + native launch/1
  edit_appinfo.py inject <appinfo.vdf> --with-depot-oslist
                                         # + platform-tag depot 3321 (contingency
                                         #   if the Mac client won't offer Install)
  edit_appinfo.py revert <appinfo.vdf>   # remove all of the above
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


# Point Steam directly at the game binary (a symlink in the install dir ->
# the app's Mach-O). A direct exec preserves Steam's injected
# DYLD_INSERT_LIBRARIES so the in-game overlay (Shift+Tab) works, which a
# shell wrapper (#!/bin/sh is SIP-restricted) and `open` both strip.
# Confirmed safe: SDL_GetBasePath resolves the bundle Resources via CFBundle,
# @executable_path/../Frameworks rpath resolves from the real path, and there
# is no single-instance lock (HandleGameAlreadyRunning is never called).
WANT_LAUNCH = {
    "executable": "insaniquarium",
    "type": "default",
    "description": "Native macOS",
    "config": {"oslist": "macos"},
}

# Contingency (inject --with-depot-oslist): explicitly platform-tag depot 3321
# so the Mac client can't filter it out when computing an Install. The depot
# currently ships with NO oslist (= all platforms), so this is normally
# unnecessary - only try it if the library shows "not available on macOS" or
# Install downloads nothing. Transient: only needed until the depot is on disk,
# so the durability reapply (plain inject) not preserving it is fine.
DEPOT = "3321"
WANT_DEPOT_OSLIST = "windows,macos"


def inject(path, with_depot_oslist=False):
    a = Appinfo(path, choose_apps=True, apps=[APPID])
    ai = app_sections(a)
    oslist = ai["common"].get("oslist") or "windows"
    parts = [p for p in oslist.split(",") if p]
    launch = ai["config"].setdefault("launch", {})
    # Valve's original entry 0 (Insaniquarium.exe) has no oslist, so the Mac
    # client treats it as valid too and shows a two-option picker whose first
    # choice crashes. Restrict it to windows so macOS sees exactly one entry.
    entry0_ok = launch.get("0", {}).get("config", {}).get("oslist") == "windows"
    depot_cfg = ai.get("depots", {}).get(DEPOT, {}).get("config", {})
    depot_ok = (not with_depot_oslist
                or depot_cfg.get("oslist") == WANT_DEPOT_OSLIST)
    # Idempotent: no write when already in the desired state, so a file-watch
    # reapply can't loop on its own edits.
    if "macos" in parts and launch.get("1") == WANT_LAUNCH and entry0_ok \
            and depot_ok:
        print("already injected; no change")
        return
    if "macos" not in parts:
        parts.append("macos")
    ai["common"]["oslist"] = ",".join(parts)
    if "0" in launch:
        launch["0"].setdefault("config", {})["oslist"] = "windows"
    launch["1"] = dict(WANT_LAUNCH)
    if with_depot_oslist:
        ai["depots"][DEPOT].setdefault("config", {})["oslist"] = WANT_DEPOT_OSLIST
    a.update_app(APPID)
    a.write_data()
    print("injected: oslist=%s, launch/0=windows-only, launch/1=%s (macos)%s"
          % (ai["common"]["oslist"], WANT_LAUNCH["executable"],
             ", depot %s oslist=%s" % (DEPOT, WANT_DEPOT_OSLIST)
             if with_depot_oslist else ""))


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
    # Restore Valve's original unrestricted entry 0
    if launch.get("0", {}).get("config", {}).get("oslist") == "windows":
        del launch["0"]["config"]["oslist"]
        if not launch["0"]["config"]:
            del launch["0"]["config"]
    # Undo the depot-oslist contingency if it was applied
    depot_cfg = ai.get("depots", {}).get(DEPOT, {}).get("config", {})
    if depot_cfg.get("oslist") == WANT_DEPOT_OSLIST:
        del depot_cfg["oslist"]
        if not depot_cfg:
            del ai["depots"][DEPOT]["config"]
    a.update_app(APPID)
    a.write_data()
    print("reverted 3320 appinfo edits")


if __name__ == "__main__":
    args = sys.argv[1:]
    with_depot = "--with-depot-oslist" in args
    args = [x for x in args if x != "--with-depot-oslist"]
    if len(args) != 2 or args[0] not in ("inject", "revert", "show") \
            or (with_depot and args[0] != "inject"):
        sys.exit(__doc__)
    if args[0] == "inject":
        inject(args[1], with_depot_oslist=with_depot)
    else:
        {"revert": revert, "show": show}[args[0]](args[1])
