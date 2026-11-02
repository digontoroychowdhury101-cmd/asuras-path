"""Write the game pieces' bounding-box centres and sizes in Roblox axes, for binding an imported skin.

    blender -b assets/source/opening_cast/<key>/<Name>_v1.blend -P tools/blender/opening_cast/pieces.py -- <key>

Roblox's 3D Importer centres every MeshPart on its bounds, so a piece's imported position is its bounds centre, not
its Blender origin. bind_skin.luau compares these centres with the imported parts to recover the import offset and
scale, then binds each part to its R15 limb. Output: work/opening_cast_bake/<key>/pieces.json.
"""
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
NAMES = {"monk": "Monk", "swordsman": "Swordsman", "warden": "Warden"}


def roblox(v):
    return [v.x, v.z, -v.y]   # Blender +Y (his front) is Roblox -Z


key = sys.argv[sys.argv.index("--") + 1]
out = {}
for o in bpy.data.collections[f"{NAMES[key]}_Game"].all_objects:
    if o.type != "MESH":
        continue
    pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c, s = (lo + hi) / 2, hi - lo
    out[o.name] = {"bone": o["AsuraBone"], "role": o.get("AsuraRole"), "centre": roblox(c), "size": [s.x, s.z, s.y], "origin": roblox(o.matrix_world.translation)}
dst = ROOT / "work/opening_cast_bake" / key / "pieces.json"
dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_text(json.dumps(out, indent=1))
print("wrote", dst, len(out))
