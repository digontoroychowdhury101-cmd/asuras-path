#!/usr/bin/env python3
"""Write assets/models/AsuraStoneFinish.rbxmx: one non-metal SurfaceAppearance per colossal-temple ColorMap.

The 3D importer gave the Bellwood colossal temple, its guardians and the gate towers metalness maps, so the stone mirrors
the black cave sky and renders black. Each finish repeats the uploaded colour, normal and roughness maps with no
metalness. A running server cannot clear MetalnessMap, so VesperholdKit swaps these in by ColorMap id at placement.
Rerun after a re-upload of those pieces (reads src/shared/LandmarkKitRegistry.luau).
"""
import re
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = (ROOT / "src/shared/LandmarkKitRegistry.luau").read_text(encoding="utf-8")
OUT = ROOT / "assets/models/AsuraStoneFinish.rbxmx"
PIECES = ("Bellwood_Colossal", "Bellwood_GateTowers")
ROW = re.compile(r'\["([^"]+)"\] = \{ MeshId = "[^"]+", Asset = "[^"]+", ColorMap = "(rbxassetid://(\d+))", '
                 r'NormalMap = "(rbxassetid://\d+)", RoughnessMap = "(rbxassetid://\d+)"')

finishes = {}
for sub, colour, number, normal, rough in ROW.findall(REGISTRY):
    if not sub.startswith(PIECES):
        continue
    maps = (colour, normal, rough)
    assert finishes.setdefault(number, maps) == maps, f"{sub}: ColorMap {number} already used with other maps"
assert len(finishes) > 200, f"only {len(finishes)} temple ColorMaps found; did the registry format change?"


def item(i, number, maps):
    props = "".join(f'<Content name="{name}"><uri>{escape(uri)}</uri></Content>'
                    for name, uri in zip(("ColorMapContent", "NormalMapContent", "RoughnessMapContent"), maps))
    return (f'<Item class="SurfaceAppearance" referent="S{i}"><Properties><string name="Name">{number}</string>'
            f'<token name="AlphaMode">0</token>{props}</Properties></Item>')


body = "\n".join(item(i, n, finishes[n]) for i, n in enumerate(sorted(finishes)))
OUT.write_text('<roblox version="4"><Item class="Folder" referent="S"><Properties><string name="Name">AsuraStoneFinish</string>'
               f'</Properties>\n{body}\n</Item></roblox>\n', encoding="utf-8")
print(f"wrote {len(finishes)} stone finishes to {OUT.relative_to(ROOT)}")
