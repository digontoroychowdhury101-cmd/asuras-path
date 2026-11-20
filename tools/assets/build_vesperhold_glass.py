#!/usr/bin/env python3
"""Write assets/models/AsuraVesperholdGlass.rbxmx: one SurfaceAppearance per Vesperhold Glass/GlassR sub-mesh.

Each finish repeats the uploaded PBR maps and masks emission with the ColorMap itself, so the stained-glass mosaic glows and
the leading stays dark. A running server cannot set EmissiveMaskContent, so VesperholdKit clones these build-time finishes
onto the glass. Rerun after a Vesperhold re-upload (reads assets/VESPERHOLD_KIT_UPLOADED.json).
"""
import json
import re
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = json.loads((ROOT / "assets/VESPERHOLD_KIT_UPLOADED.json").read_text())
OUT = ROOT / "assets/models/AsuraVesperholdGlass.rbxmx"
STRENGTH = 18  # Studio check: the mosaic reads through Snow haze from the reveal and the rose close-up
MAPS = (("ColorMap", "ColorMapContent"), ("NormalMap", "NormalMapContent"), ("RoughnessMap", "RoughnessMapContent"),
        ("MetalnessMap", "MetalnessMapContent"))


def role(sub):
    return re.sub(r"_\d+$", "", sub.split("__", 1)[1]) if "__" in sub else ""


def finish(i, sub, fields):
    maps = "".join(f'<Content name="{prop}"><uri>{escape(fields[key])}</uri></Content>' for key, prop in MAPS if fields.get(key))
    return (f'<Item class="SurfaceAppearance" referent="G{i}"><Properties><string name="Name">{escape(sub)}</string>'
            f'<token name="AlphaMode">0</token>{maps}'
            f'<Content name="EmissiveMaskContent"><uri>{escape(fields["ColorMap"])}</uri></Content>'
            f'<float name="EmissiveStrength">{STRENGTH}</float>'
            f'<Color3 name="EmissiveTint"><R>1</R><G>1</G><B>1</B></Color3></Properties></Item>')


glass = {sub: fields for piece in REGISTRY["pieces"].values() for sub, fields in piece.items() if role(sub) in ("Glass", "GlassR")}
missing = [sub for sub, fields in glass.items() if not str(fields.get("ColorMap", "")).startswith("rbxassetid://")]
assert glass and not missing, f"glass subs without an uploaded ColorMap: {missing}"
body = "\n".join(finish(i, sub, glass[sub]) for i, sub in enumerate(sorted(glass)))
OUT.write_text('<roblox version="4"><Item class="Folder" referent="G"><Properties><string name="Name">AsuraVesperholdGlass</string>'
               f'</Properties>\n{body}\n</Item></roblox>\n', encoding="utf-8")
print(f"wrote {len(glass)} glass finishes to {OUT.relative_to(ROOT)}")
