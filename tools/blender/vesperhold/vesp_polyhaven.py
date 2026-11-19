"""CC0 Poly Haven base layers for the Vesperhold materials (blender-skills polyhaven-texture-apply method).

The maps were fetched with ~/.claude/skills/polyhaven-texture-apply (blender-skills b2f0f816) through the MCP for Blender
addon socket (127.0.0.1:9876) and written to assets/source/vesperhold/polyhaven/<asset_id>/<asset_id>_<map>_2k.jpg.
Licence and IDs: outputs/vesperhold/THIRD_PARTY.md. Re-fetch on another machine: see that file (same IDs, 2k, jpg).

maps(name) -> {"Color","Normal","Roughness","Metal"} float32 (N, N[, 3]) arrays, row 0 = v 0 (Blender pixel order), or None
when the material has no Poly Haven source or the files are missing (callers then use their procedural generator).
Colour is tone-mapped to the castle palette (stored sRGB value targets from mac-40: soot 0.08-0.15, charcoal 0.15-0.25),
desaturated, with vertical grime runs on the masonry. Metal is always returned (black for non-metal: mac-28).
"""
import sys
from pathlib import Path

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
PH = ROOT / "assets/source/vesperhold/polyhaven"
# material -> (asset id, target mean value, saturation kept, grime runs, tint rgb)
SRC = {
    "Vesp_Soot": ("castle_wall_slates", 0.115, 0.25, True, (0.97, 0.99, 1.06)),
    "Vesp_Charcoal": ("medieval_blocks_03", 0.19, 0.25, True, (0.96, 0.99, 1.07)),
    "Vesp_Weathered": ("rock_04", 0.14, 0.2, False, (0.98, 1.0, 1.04)),
    "Vesp_Slate": ("roof_slates_02", 0.09, 0.3, False, (0.95, 1.0, 1.1)),
    "Vesp_Iron": ("metal_plate_02", 0.20, 0.7, False, (1.0, 1.0, 1.0)),
    "Vesp_DeadBark": ("bark_willow_02", 0.15, 0.45, False, (1.0, 0.97, 0.94)),
    "Vesp_Frost": ("snow_02", 0.86, 0.3, False, (0.96, 0.98, 1.02)),
    "Vesp_Rock": ("dark_rock", 0.12, 0.25, False, (0.97, 0.99, 1.05)),
}


def _load(path, n, gray):
    im = bpy.data.images.load(str(path), check_existing=False)
    im.colorspace_settings.name = "Non-Color"  # raw stored values, same space the kit writes
    if im.size[0] != n or im.size[1] != n:
        im.scale(n, n)
    a = np.empty(n * n * 4, np.float32)
    im.pixels.foreach_get(a)
    bpy.data.images.remove(im)
    a = a.reshape(n, n, 4)[..., :3]
    return a[..., 0].copy() if gray else a


def _runs(n):
    """Vertical soot/grime runs (uses the kit's spectral noise when the kit module is loaded)."""
    K = sys.modules.get("vesperhold_kit")
    if K is None or n != K.N:
        return np.zeros((n, n), np.float32)
    return np.clip(K.fld(1.0, 25, 18.0) * 0.5 + 0.05, 0, 1)


def maps(name, n=2048):
    if name not in SRC:
        return None
    aid, target, sat, runs, tint = SRC[name]
    rlift = 0.0 if name == "Vesp_Iron" else 0.45  # matte soot stone; scans read glossy under Roblox lighting
    d = PH / aid
    f = {k: d / f"{aid}_{k}_2k.jpg" for k in ("Diffuse", "nor_gl", "Rough", "Metal")}
    if not all(f[k].exists() for k in ("Diffuse", "nor_gl", "Rough")):
        return None
    col = _load(f["Diffuse"], n, False)
    lum = col @ np.array([0.299, 0.587, 0.114], np.float32)
    col = lum[..., None] + sat * (col - lum[..., None])
    col = col * (target / max(float(lum.mean()), 1e-4)) * np.array(tint, np.float32)
    if runs:
        col = col * (1 - 0.45 * _runs(n))[..., None]
    out = dict(Color=np.clip(col, 0, 1).astype(np.float32), Normal=_load(f["nor_gl"], n, False),
               Roughness=np.clip(_load(f["Rough"], n, True) * (1 - rlift) + rlift, 0.2, 1.0))
    out["Metal"] = _load(f["Metal"], n, True) if f["Metal"].exists() else np.zeros((n, n), np.float32)
    return out
