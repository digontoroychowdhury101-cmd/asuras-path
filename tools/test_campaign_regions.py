#!/usr/bin/env python3
"""Batches 16-21: walk the authored campaign regions offline (tools/test_campaign_regions.luau).

Injects the unchanged RouteGuide module and the Sanctuary's fall-catch poll into the Luau suite (the
plain Luau CLI has no file access), then runs it with native code generation.
"""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def section(path, start, end):
    source = (ROOT / path).read_text()
    begin = source.index(start)
    return source[begin:source.index(end, begin)]


guide = (ROOT / "src/shared/RouteGuide.luau").read_text()
guide = re.sub(r"^export type", "type", guide, flags=re.M)
# Follow-up 20: the saved place's destroy height and gravity (what Studio actually simulates) and the
# catch's hold/poll, so a catch is proven to fire before the engine deletes a falling body.
project = (ROOT / "default.project.json").read_text()
config = (ROOT / "src/shared/Config.luau").read_text()
bounds = (ROOT / "src/server/Services/CampaignBounds.luau").read_text()
destroy = float(re.search(r'"FallenPartsDestroyHeight": ([-\d.]+)', project).group(1))
gravity = float(re.search(r'"Gravity": ([-\d.]+)', project).group(1))
assert destroy == float(re.search(r"FallenPartsDestroyHeight = ([-\d.]+)", config).group(1)), "Config and saved place destroy heights differ"
hold = float(re.search(r"Bounds.HOLD = ([\d.]+)", bounds).group(1))
poll = float(re.search(r"poll\(task.wait\(([\d.]+)\)\)", bounds).group(1))
replacements = {
    "-- WORLD_INSERT": f"local DESTROY_Y, GRAVITY, HOLD, POLL = {destroy}, {gravity}, {hold}, {poll}",
    "-- ROUTEGUIDE_INSERT": "local function loadGuide(script, require)\n" + guide + "\nend",
    "-- POLL_INSERT": section("src/server/Services/SanctuaryService.luau", "local function poll()", "\n---"),
}
# Batch 24: the layout's Proving Court is built around ColosseumService's ring, not a copy of it.
colosseum = (ROOT / "src/server/Services/ColosseumService.luau").read_text()
ring = re.search(r'Id = "Ring_OctagonOfAsh".*?Center = Vector3.new\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)', colosseum, re.S)
layout = (ROOT / "src/shared/AshColosseumLayout.luau").read_text()
mark = re.search(r'L.mark\(r, "ProvingRing", "[^"]+", ([-\d.]+), ([-\d.]+), ([-\d.]+)\)', layout)
assert ring and mark and tuple(map(float, ring.groups())) == tuple(map(float, mark.groups())), "Proving Court mark must sit on Ring_OctagonOfAsh"
source = (ROOT / "tools/test_campaign_regions.luau").read_text()
for marker, code in replacements.items():
    assert source.count(marker) == 1, marker
    source = source.replace(marker, code)
output = ROOT / "work/test_campaign_regions.generated.luau"
output.parent.mkdir(exist_ok=True)
output.write_text(source)
result = subprocess.run([str(ROOT / "work/bin/luau/luau"), "--codegen", str(output), "-a", *sys.argv[1:]], cwd=ROOT / "tools")
output.unlink()
sys.exit(result.returncode)
