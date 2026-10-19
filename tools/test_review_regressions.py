#!/usr/bin/env python3
"""Exercise real fall recovery, contact resolution and profile/arsenal handshake functions."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def section(path, start, end):
    source = (ROOT / path).read_text()
    return source[source.index(start):source.index(end, source.index(start))]


bootstrap = "src/server/Bootstrap.server.luau"
replacements = {
    "-- POLL_INSERT": section("src/server/Services/SanctuaryService.luau", "local function poll()", "\n---"),
    "-- CONTACT_INSERT": section("src/server/CharacterService.luau", "local function resolveContacts(", "\nlocal function finishDuel("),
    "-- LOOT_SYNC_INSERT": section("src/server/Services/LootService.luau", "function Loot.Sync(", "\nlocal function transact("),
    "-- PROFILE_SYNC_INSERT": section(bootstrap, "local function syncProfile(", "\n---"),
    "-- HYDRATE_INSERT": section(bootstrap, "local function hydrate(", "\nlocal function release("),
    "-- SHOP_INSERT": section(bootstrap, "local function onShop(", "\n---"),
}
source = (ROOT / "tools/test_review_regressions.luau").read_text()
for marker, code in replacements.items():
    assert source.count(marker) == 1, marker
    source = source.replace(marker, code)
output = ROOT / "work/test_review_regressions.generated.luau"
output.parent.mkdir(exist_ok=True)
output.write_text(source)
subprocess.run([str(ROOT / "work/bin/luau/luau"), str(output)], cwd=ROOT, check=True)
