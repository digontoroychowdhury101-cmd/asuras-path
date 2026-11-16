"""Saltreach kit shared library (lane M5, headless Blender). Exec'd by saltreach_veg.py / _rock.py / _built.py / _hero.py, never run alone.

Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Supersedes: nothing (searched tools/blender/** and assets/source/overworld/** for saltreach/salt kit files first: none exist; the hero blockout
Basin_Gate_Statue in hero_silhouettes.py is only replaced by the saltreach_hero.py statue at swap time and is left untouched).
Linked from LEDGER.md: not yet (LEDGER.md is outside this lane's write set; the integrator adds the row for outputs/.../workers/23b-salt-kit.md).
Why a new file: one shared helper/material/export/pack library so each family script is one short run whose finished pieces survive a stop.

Reuses slice_kit.py helpers (exec'd without its main()): field/nmap/save/material, obj (asserts < 18000 tris per sub-mesh), bx/cyl/tube/lathe/leaf, rock().
1 BU = 1 stud, base centre at origin, Blender Z up (glTF export makes it Y up). Per family: GLBs -> assets/source/overworld/saltreach/<fam>/,
family_<fam>.json, merged pack + upload_manifest.json + UPLOAD.md -> assets/source/overworld/upload/saltreach/, eye-height renders beside a 5.5 stud figure
-> outputs/claude-open-world-2026-11-14/captures/kit/saltreach/, one line per piece in workers/23b-salt-kit.md. Original procedural work only.
"""
import json
import math
import os
import random
import shutil
import struct
import sys
import traceback
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, noise

HERE = Path(__file__).resolve()
_src = (HERE.parent / "slice_kit.py").read_text(encoding="utf-8")
exec(compile(_src.rsplit("\nmain()", 1)[0], "slice_kit.py", "exec"), globals())  # helpers; its main() is not run

ROOT = HERE.parents[3]
OUT = ROOT / "assets/source/overworld/saltreach"
UP = ROOT / "assets/source/overworld/upload/saltreach"
CAPD = ROOT / "outputs/claude-open-world-2026-11-14/captures/kit/saltreach"
NOTE = ROOT / "outputs/claude-open-world-2026-11-14/workers/23b-salt-kit.md"
REGISTRY = "assets/SALTREACH_KIT_UPLOADED.json"
ONLY = {s for s in os.environ.get("SALT_ONLY", "").split(",") if s}
NORENDER = bool(os.environ.get("SALT_NORENDER"))
TAU = 2 * math.pi
NEEDLE_PTS = {}


# ------------------------------------------------------------------------------------------ materials
def mk(name, col, h, rough, k=4.0, double=False, metal=None):
    return material(name, save(name + "_Color", np.clip(col, 0, 1)), save(name + "_Roughness", np.clip(rough, 0, 1), True),
                    save(name + "_Normal", nmap(h, k), True), metal=None if metal is None else save(name + "_Metal", np.clip(metal, 0, 1), True),
                    double=double)


def m_rock():
    """Salt_Rock 1024 atlas, four 512 quadrants in rock()'s QUAD order: weathered limestone, salt bloom (up-facing), wet tide band, rust/lichen stain."""
    n = 512
    g1, g2, grain = field(n, 1.3, 201), field(n, 0.8, 202), field(n, 0.2, 203)
    band = field(n, 1.0, 204).T
    lime = np.array([0.66, 0.60, 0.50]) * (0.86 + 0.08 * g1[..., None] + 0.04 * g2[..., None])
    lime = lime * (1 - 0.14 * np.tanh(band)[..., None]) * np.where(grain[..., None] > 1.4, 0.68, 1.0)
    h_l = 0.5 + 0.1 * g1 + 0.05 * np.tanh(band) - 0.08 * (grain > 1.4)
    pk = np.clip((g1 - 0.8) * 2, 0, 1)[..., None]
    bloom = np.array([0.88, 0.87, 0.81]) * (0.94 + 0.05 * g2[..., None]) * (1 - pk) + lime * pk
    h_b = 0.5 + 0.05 * g2 + 0.03 * grain
    wet = np.array([0.50, 0.47, 0.38]) * (0.8 + 0.2 * g2[..., None])
    alg = np.clip((field(n, 1.6, 205) - 0.6) * 1.2, 0, 0.45)[..., None]
    wet = wet * (1 - alg) + np.array([0.38, 0.46, 0.26]) * alg
    bar = field(n, 0.3, 206) > 2.4
    wet = np.where(bar[..., None], np.array([0.85, 0.84, 0.78]), wet)
    h_w = 0.5 + 0.05 * g2 + 0.12 * bar
    rust = np.array([0.55, 0.40, 0.26]) * (0.85 + 0.1 * g1[..., None])
    rust = np.where((field(n, 0.8, 207) > 1.2)[..., None], np.array([0.72, 0.44, 0.14]), rust)
    h_r = 0.5 + 0.08 * g1
    rg, rb, rw = np.clip(0.86 + 0.05 * g1, 0, 1), np.clip(0.93 + 0.03 * g2, 0, 1), np.clip(0.55 + 0.1 * g2 - 0.2 * bar, 0, 1)
    col, hh, rough = np.zeros((2 * n, 2 * n, 3)), np.zeros((2 * n, 2 * n)), np.zeros((2 * n, 2 * n))
    for (qu, qv), c, h, r in (((0, 0), lime, h_l, rg), ((1, 0), bloom, h_b, rb), ((0, 1), wet, h_w, rw), ((1, 1), rust, h_r, rg)):
        sl = (slice(qv * n, qv * n + n), slice(qu * n, qu * n + n))
        col[sl], hh[sl], rough[sl] = np.clip(c, 0, 1), h, r
    return material("Salt_Rock", save("Salt_Rock_Color", col), save("Salt_Rock_Roughness", rough, True), save("Salt_Rock_Normal", nmap(hh, 5.0), True))


def m_crust():
    n = 512
    r = np.random.default_rng(211)
    pts = r.random((52, 2))
    yy, xx = (np.mgrid[0:n, 0:n] + 0.5) / n
    d1, d2, idx = np.full((n, n), 9.0), np.full((n, n), 9.0), np.zeros((n, n), int)
    for i, (px, py) in enumerate(pts):
        dx, dy = np.abs(xx - px), np.abs(yy - py)
        d = np.hypot(np.minimum(dx, 1 - dx), np.minimum(dy, 1 - dy))
        new1 = d < d1
        d2 = np.where(new1, d1, np.minimum(d2, d))
        idx = np.where(new1, i, idx)
        d1 = np.minimum(d1, d)
    edge = d2 - d1
    tone = r.uniform(0.9, 1.05, 52)[idx][..., None]
    g = field(n, 1.1, 212)
    col = np.array([0.90, 0.89, 0.84]) * tone * (0.94 + 0.04 * g[..., None])
    crack = np.clip(1 - edge / 0.018, 0, 1)[..., None]
    col = col * (1 - 0.5 * crack) + np.array([0.52, 0.47, 0.38]) * 0.5 * crack
    stain = np.clip((field(n, 1.5, 213) - 0.9) * 1.5, 0, 0.5)[..., None]
    col = col * (1 - stain) + np.array([0.7, 0.6, 0.42]) * stain
    h = 0.55 + 0.08 * np.clip(edge / 0.05, 0, 1) - 0.3 * crack[..., 0] + 0.03 * g
    return mk("Salt_Crust", col, h, 0.55 + 0.1 * g, 4.0)


def m_driftwood():
    n = 512
    grain, tone, crk = field(n, 0.9, 221, 16.0), field(n, 1.6, 222), field(n, 0.6, 223, 12.0)
    col = np.array([0.58, 0.54, 0.47]) * (0.8 + 0.1 * grain[..., None] + 0.06 * tone[..., None])
    col *= np.where(crk[..., None] > 1.5, 0.55, 1.0)
    salt = np.clip((field(n, 1.4, 224) - 1.0) * 1.5, 0, 0.5)[..., None]
    col = col * (1 - salt) + np.array([0.86, 0.85, 0.80]) * salt
    return mk("Salt_Driftwood", col, 0.5 + 0.1 * grain - 0.1 * (crk > 1.5), 0.88 + 0.04 * grain, 5.0)


def m_timber():
    n = 512
    grain, tone = field(n, 0.9, 231, 16.0), field(n, 1.6, 232)
    col = np.array([0.34, 0.29, 0.23]) * (0.8 + 0.13 * grain[..., None] + 0.08 * tone[..., None])
    streak = np.clip((field(n, 1.0, 233, 10.0) - 0.8) * 1.5, 0, 0.6)[..., None]
    col = col * (1 - streak) + np.array([0.78, 0.76, 0.70]) * streak
    paint = np.clip((field(n, 1.3, 234) - 1.3) * 3, 0, 0.45)[..., None]  # sparse flaked sea-blue paint
    col = col * (1 - paint) + np.array([0.30, 0.42, 0.42]) * paint
    return mk("Salt_Timber", col, 0.5 + 0.08 * grain, 0.8 + 0.06 * grain, 4.0)


def m_stone():
    n = 512
    r = np.random.default_rng(241)
    yy, xx = np.mgrid[0:n, 0:n]
    ri, fy = yy // 64, (yy % 64) / 64
    xs = (xx + (ri % 2) * 64) % n
    bi, fx = xs // 128, (xs % 128) / 128
    tone = r.uniform(0.86, 1.1, (8, 4))[ri, bi][..., None]
    g1, g2 = field(n, 1.4, 242), field(n, 0.9, 243)
    col = np.array([0.66, 0.62, 0.54]) * tone * (0.88 + 0.07 * g1[..., None])
    mort = ((fy < 0.05) | (fx < 0.03))[..., None]
    col = np.where(mort, np.array([0.42, 0.40, 0.35]), col)
    bloom = np.clip((field(n, 1.5, 244) - 0.7) * 1.4, 0, 0.55)[..., None]
    col = col * (1 - bloom) + np.array([0.9, 0.89, 0.84]) * bloom
    h = 0.5 + 0.08 * g1 + 0.04 * g2 - 0.3 * mort[..., 0]
    return mk("Salt_Stone", col, h, 0.8 + 0.06 * g2, 4.0)


def m_iron():
    n = 256
    g = field(n, 1.2, 251)
    rust = np.clip((field(n, 1.0, 252) - 0.2) * 1.2, 0, 1)[..., None]
    col = np.array([0.18, 0.17, 0.17]) * (1 - rust) + np.array([0.48, 0.24, 0.10]) * rust
    return mk("Salt_Iron", col * (0.9 + 0.08 * g[..., None]), 0.5 + 0.1 * g, 0.55 + 0.35 * rust[..., 0], 3.0, metal=0.9 - 0.7 * rust[..., 0])


def m_rope():
    n = 256
    yy, xx = np.mgrid[0:n, 0:n]
    tw = 0.5 + 0.5 * np.sin((xx + yy * 0.7) * TAU / 16)
    g = field(n, 1.0, 261)
    col = np.array([0.52, 0.42, 0.26]) * (0.7 + 0.35 * tw[..., None]) * (0.92 + 0.06 * g[..., None])
    return mk("Salt_Rope", col, 0.4 + 0.4 * tw, np.full((n, n), 0.9), 4.0)


def m_canvas():
    n = 256
    yy, xx = np.mgrid[0:n, 0:n]
    weave = 0.86 + 0.08 * ((xx // 2 + yy // 2) % 2) + 0.06 * field(n, 1.2, 271)
    fade = 0.8 + 0.2 * np.clip(field(n, 1.6, 272), -1, 1)
    col = np.array([0.76, 0.71, 0.60]) * (weave * fade)[..., None]
    stain = np.clip((field(n, 1.2, 273) - 0.8) * 1.4, 0, 0.6)[..., None]
    col = col * (1 - stain) + np.array([0.45, 0.36, 0.24]) * stain
    return mk("Salt_Canvas", col, 0.5 + 0.1 * ((xx // 2 + yy // 2) % 2), np.full((n, n), 0.92), 4.0, double=True)


def m_bark():
    n = 512
    ridge, fine = field(n, 1.0, 281, 9.0), field(n, 1.5, 282, 3.0)
    h = 0.5 + 0.25 * np.tanh(ridge) + 0.06 * fine
    col = np.array([0.34, 0.30, 0.26]) * (0.7 + 0.8 * (h[..., None] - 0.5))
    col *= np.where(ridge[..., None] < -1.2, 0.5, 1.0)
    lich = np.clip((field(n, 0.6, 283) - 1.4) * 2, 0, 0.7)[..., None]
    col = col * (1 - lich) + np.array([0.62, 0.64, 0.46]) * lich
    return mk("Salt_Bark", col, h, 0.85 - 0.1 * h, 6.0)


def strokes(name, tones, probs, seed, count, Lr, bg, w=2, gain=1.2, rough=0.65, k=3.0):
    """Painted stroke atlas (needles / small leaves) over a dark gap colour; NEEDLE_PTS[name] lists UV points that land on a stroke."""
    n = 512
    r = np.random.default_rng(seed)
    col = np.zeros((n, n, 3))
    col[:] = bg
    h = np.full((n, n), 0.3)
    mask = np.zeros((n, n), bool)
    for i in range(count):
        cx, cy = r.integers(0, n, 2)
        a, L = r.uniform(0, np.pi), r.uniform(*Lr)
        t = np.linspace(-L / 2, L / 2, int(L) * 2)
        tone = np.array(tones[r.choice(len(tones), p=probs)])
        for wv in range(w):
            xs = ((cx + t * np.cos(a) + wv * np.sin(a)).astype(int)) % n
            ys = ((cy + t * np.sin(a) - wv * np.cos(a)).astype(int)) % n
            col[ys, xs] = tone * (0.75 + 0.35 * (t / L + 0.5))[:, None]
            h[ys, xs] = 0.55 + 0.0002 * i
            mask[ys, xs] = True
    ys, xs = np.nonzero(mask)
    sel = np.random.default_rng(5).choice(len(ys), 600)
    NEEDLE_PTS[name] = list(zip(((xs[sel] + 0.5) / n).tolist(), ((ys[sel] + 0.5) / n).tolist()))
    return mk(name, np.clip(col * gain, 0, 1), h, rough + 0.08 * field(n, 1.0, seed + 1), k)


def m_needle():
    return strokes("Salt_Needle", [(0.14, 0.26, 0.20), (0.18, 0.32, 0.24), (0.24, 0.38, 0.28), (0.10, 0.20, 0.17), (0.38, 0.46, 0.34)],
                   [0.25, 0.3, 0.2, 0.15, 0.1], 291, 1100, (14, 28), (0.07, 0.11, 0.09))


def m_scrub():
    return strokes("Salt_Scrub", [(0.40, 0.44, 0.30), (0.50, 0.52, 0.36), (0.58, 0.58, 0.42), (0.30, 0.36, 0.26), (0.70, 0.66, 0.50)],
                   [0.25, 0.3, 0.2, 0.15, 0.1], 301, 900, (10, 20), (0.16, 0.17, 0.12), w=3)


def m_grass():
    return blade_mat("Salt_Grass", 128, 256, (0.34, 0.32, 0.15), (0.82, 0.76, 0.48), 311)


def m_reed():
    return blade_mat("Salt_Reed", 128, 256, (0.30, 0.30, 0.14), (0.74, 0.64, 0.34), 312)


def m_kelp():
    return blade_mat("Salt_Kelp", 128, 256, (0.16, 0.14, 0.06), (0.44, 0.36, 0.13), 313)


def m_glow():
    n = 128
    v, u = np.meshgrid(np.linspace(-1, 1, n), np.linspace(-1, 1, n), indexing="ij")
    g = np.clip(1 - np.sqrt(u ** 2 + v ** 2) * 0.7, 0, 1)[..., None]
    col = np.array([0.62, 0.34, 0.10]) * (1 - g) + np.array([1.0, 0.82, 0.46]) * g
    return mk("Salt_Glow", col, 0.5 * np.ones((n, n)), np.full((n, n), 0.4), 2.0)


MAT_BUILDERS = {"Salt_Rock": m_rock, "Salt_Crust": m_crust, "Salt_Driftwood": m_driftwood, "Salt_Timber": m_timber, "Salt_Stone": m_stone,
                "Salt_Iron": m_iron, "Salt_Rope": m_rope, "Salt_Canvas": m_canvas, "Salt_Bark": m_bark, "Salt_Needle": m_needle, "Salt_Scrub": m_scrub,
                "Salt_Grass": m_grass, "Salt_Reed": m_reed, "Salt_Kelp": m_kelp, "Salt_Glow": m_glow}


# ------------------------------------------------------------------------------------------ helpers
def blk(bm, x, y, z0, sx, sy, sz, rz=0.0, bev=0.12, disp=0.06, cuts=1, mode="stone", uvs=8.0):
    """Hand-hewn block: chamfered box, subdivided `cuts` times, noise-displaced along the vertex normal."""
    before = set(bm.faces)
    bx(bm, x, y, z0, sx, sy, sz, rz=rz, mode=mode, bev=bev, uvs=uvs)
    new = [f for f in bm.faces if f not in before]
    if cuts:
        bmesh.ops.subdivide_edges(bm, edges=list({e for f in new for e in f.edges}), cuts=cuts, use_grid_fill=True)
        new = [f for f in bm.faces if f not in before]
    if disp:
        bm.normal_update()
        for v in {v for f in new for v in f.verts}:
            v.co += v.normal * disp * fbm(v.co * 0.9, 2)


def done(name, parts, centre=True):
    """parts: [(sub, bmesh, material name, smooth)]; centres the footprint on the origin (z untouched) then registers the sub-meshes."""
    if centre:
        vs = [v.co for _, bm, _, _ in parts for v in bm.verts]
        cx, cy = (min(v.x for v in vs) + max(v.x for v in vs)) / 2, (min(v.y for v in vs) + max(v.y for v in vs)) / 2
        for _, bm, _, _ in parts:
            bmesh.ops.translate(bm, verts=bm.verts[:], vec=Vector((-cx, -cy, 0)))
    for sub, bm, mat, sm in parts:
        obj(name, sub, bm, MATS[mat], smooth=sm)


def paint(bm, n0, uv):
    uvl = _uvl(bm)
    bm.faces.ensure_lookup_table()
    for f in bm.faces[n0:]:
        for l in f.loops:
            l[uvl].uv = uv


def wlean(z, h, amount):
    """Shore wind lean: the whole crown streams toward WNW (slice_kit WIND), more with height."""
    return WIND * (max(z, 0) / h) ** 1.6 * amount


# ------------------------------------------------------------------------------------------ export, pack, render
def read_glb(path):
    data = path.read_bytes()
    assert struct.unpack_from("<4sII", data, 0)[0] == b"glTF"
    length = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + length])


def inspect_glb(path):
    g = read_glb(path)
    subs, lo, hi = {}, [1e9] * 3, [-1e9] * 3
    for node in g["nodes"]:
        if "mesh" not in node:
            continue
        t, s = node.get("translation", [0, 0, 0]), node.get("scale", [1, 1, 1])
        tris, mat = 0, ""
        for prim in g["meshes"][node["mesh"]]["primitives"]:
            tris += g["accessors"][prim["indices"]]["count"] // 3
            a = g["accessors"][prim["attributes"]["POSITION"]]
            for i in range(3):
                lo[i], hi[i] = min(lo[i], a["min"][i] * s[i] + t[i]), max(hi[i], a["max"][i] * s[i] + t[i])
            mat = g["materials"][prim["material"]]["name"]
        subs[node.get("name") or g["meshes"][node["mesh"]]["name"]] = {"tris": tris, "material": mat}
    return subs, lo, hi


def note(line):
    with open(NOTE, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def mat_maps():
    out = {}
    for m in MATS:
        if not m.startswith("Salt_"):
            continue
        maps = {}
        for slot, suf in (("ColorMap", "Color"), ("NormalMap", "Normal"), ("RoughnessMap", "Roughness"), ("MetalnessMap", "Metal")):
            if f"{m}_{suf}" in bpy.data.images:
                maps[slot] = {"file": f"maps/{m}_{suf}.png", "size_px": list(bpy.data.images[f"{m}_{suf}"].size)}
        out[m] = maps
    return out


def merge_pack():
    """Merge every family_<fam>.json into upload/saltreach/upload_manifest.json + UPLOAD.md; copies GLBs and the maps they use."""
    UP.mkdir(parents=True, exist_ok=True)
    (UP / "maps").mkdir(exist_ok=True)
    pieces, materials = {}, {}
    for fj in sorted(OUT.glob("family_*.json")):
        d = json.loads(fj.read_text())
        materials.update(d.get("_materials", {}))
        for k, v in d.items():
            if k != "_materials":
                pieces[k] = v
    for name, p in pieces.items():
        shutil.copy2(OUT / p["family"] / p["file"], UP / p["file"])
        p["maps_per_material"] = {m: materials[m] for m in sorted(set(p["sub_mesh_materials"].values())) if m in materials}
    for m, maps in materials.items():
        for slot in maps.values():
            src = OUT / slot["file"]
            if src.exists():
                shutil.copy2(src, UP / slot["file"])
    largest = max(((s, t, n) for n, p in pieces.items() for s, t in p["sub_meshes"].items()), key=lambda x: x[1], default=("-", 0, "-"))
    (UP / "upload_manifest.json").write_text(json.dumps({
        "format": "GLB (glTF 2.0, textures embedded; same maps also loose in maps/)",
        "units": "1 stud = 1 unit, Y up after import",
        "tri_cap_per_sub_mesh": TRI_CAP, "texture_cap_px": 1024, "registry_file": REGISTRY, "no_ids_yet": True,
        "registry_shape": {"pieces": {"<Piece>": {"<Piece>__<Sub>": {"MeshId": "rbxassetid://...", "ColorMap": "", "NormalMap": "", "RoughnessMap": "", "MetalnessMap": ""}}}},
        "pieces_count": len(pieces), "largest_sub_mesh": {"name": largest[0], "tris": largest[1]},
        "pieces": pieces, "materials": materials,
    }, indent=2) + "\n")
    rows = "\n".join(f"| {n} | {p['family']} | {p['tris_total']} | {max(p['sub_meshes'].values())} | {p['size_studs_xyz_roblox']} | {p['file_size_bytes'] // 1024} KB |"
                     for n, p in sorted(pieces.items(), key=lambda kv: (kv[1]["family"], kv[0])))
    (UP / "UPLOAD.md").write_text(f"""# Saltreach kit: by-hand Studio 3D Importer steps

{len(pieces)} GLBs in this folder; per-piece data (sub-mesh list + tris, material per sub-mesh, bbox size in studs [X, Y up, Z], file size, texture px per map) in `upload_manifest.json`.
Rebuild with the family scripts `tools/blender/overworld/saltreach_{{veg,rock,built,hero}}.py` (`blender -b --python <script>`). Nothing is uploaded and no IDs exist yet.
All sub-meshes < {TRI_CAP} tris (largest {largest[1]}: {largest[0]}); all textures <= 1024 px.

1. Open `places/AsurasPath.rbxlx` in Studio. View > Asset Manager > Bulk Import (or Avatar > Import 3D). Creator: Me.
2. Import settings: Scale 1 (GLB is already studs, Y up), Import As: Model (one MeshPart per sub-mesh, named `Piece__Sub`). No auto-fix / simplification.
3. Each MeshPart needs a SurfaceAppearance (Color, Normal OpenGL, Roughness; Salt_Iron also Metalness). If the importer drops one, build it from `maps/<Material>_Color/Normal/Roughness/Metal.png`. Salt_Rock is a 1024 atlas, not tiled: leave StudsPerTile default.
4. Set DoubleSided = true on `Salt_Grass_*__Blades`, `Shore_Reeds__Blades`, `Kelp_Wrack__Blades` and `Boat_Hull_*__Canvas` parts. Mark `*_Detail` sub-meshes as detail (drop past ~150 studs).
5. Parent each Model to `ServerStorage/SaltreachKit/<Piece>` (file name without `.glb`). Pivot is the base centre at ground level (buried bases sit a little below it on purpose).
6. Record IDs in `assets/SALTREACH_KIT_UPLOADED.json` (shape in the manifest). IDs come from the MeshPart/SurfaceAppearance properties; never guess.
7. `Saltreach_Gate_Statue` replaces the `Basin_Gate_Statue` blockout slot in `src/shared/BiomeDressing.luau`; Sea_Stack_* stack Base > Mid > Cap with a small overlap (hide the seam with Tide_Boulder / scree).

| Piece | Family | Tris | Largest sub-mesh | Bbox studs [X, Y, Z] | GLB |
| --- | --- | --- | --- | --- | --- |
{rows}
""", encoding="utf-8")
    return len(pieces), largest


def export_piece(fam, name):
    objs = PIECES[name]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    (OUT / fam).mkdir(parents=True, exist_ok=True)
    path = OUT / fam / f"{name}.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_apply=False)
    subs, lo, hi = inspect_glb(path)
    for k, v in subs.items():
        assert v["tris"] < TRI_CAP, (k, v["tris"])
    size = [round(hi[i] - lo[i], 2) for i in range(3)]
    mm = mat_maps()
    px = max((s for m in {v["material"] for v in subs.values()} for sl in mm.get(m, {}).values() for s in sl["size_px"]), default=0)
    assert px <= 1024, (name, px)
    return {"name": name, "family": fam, "file": path.name, "sub_meshes": {k: v["tris"] for k, v in subs.items()},
            "sub_mesh_materials": {k: v["material"] for k, v in subs.items()}, "tris_total": sum(v["tris"] for v in subs.values()),
            "size_studs_xyz_roblox": size, "bbox_min_max_roblox": [[round(x, 2) for x in lo], [round(x, 2) for x in hi]],
            "file_size_bytes": path.stat().st_size, "max_texture_px": px,
            "pivot": "base centre at origin (Y up); " + json.dumps({"min_y": round(lo[1], 3), "centre_x": round((lo[0] + hi[0]) / 2, 3), "centre_z": round((lo[2] + hi[2]) / 2, 3)}),
            "studio_target": f"ServerStorage/SaltreachKit/{name}", "registry_file": REGISTRY}


def make_figure():
    bm = bmesh.new()
    for sx in (-0.55, 0.55):
        bx(bm, sx, 0, 0, 0.95, 0.95, 2.0, bev=0.05)
    bx(bm, 0, 0, 2.0, 2.2, 1.1, 2.1, bev=0.08)
    for sx in (-1.6, 1.6):
        bx(bm, sx, 0, 2.1, 0.8, 0.8, 2.0, bev=0.05)
    bx(bm, 0, 0, 4.1, 1.3, 1.3, 1.4, bev=0.2)
    me = bpy.data.meshes.new("Ref_Figure")
    bm.to_mesh(me)
    bm.free()
    m = bpy.data.materials.new("RefFig")
    m.use_nodes = True
    next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.85, 0.32, 0.12, 1)
    me.materials.append(m)
    o = bpy.data.objects.new("Ref_Figure_5.5studs", me)
    bpy.context.scene.collection.objects.link(o)
    return o


def render_piece(name, sc, cam, ground, fig):
    objs = PIECES[name]
    for o in [o for os_ in PIECES.values() for o in os_]:
        o.hide_render = o not in objs
    lo, hi = bbox(objs)
    fx = hi.x + 3.2
    fig.location = (fx, lo.y + min(2.0, (hi.y - lo.y) / 2), 0)
    span, Ht = fx + 1.8 - lo.x, max(hi.z, 6.0)
    tz, tx, lens = max(Ht * 0.5, 3.0), (lo.x + fx + 1.8) / 2, 35.0
    tw = 18.0 / lens
    D = max(span * 0.56 / tw, max(Ht - tz, tz) * 1.18 / (tw * 0.75), 10.0)
    ground.scale, ground.location = (300, 300, 1), Vector((0, 0, 0))
    path = CAPD / f"eye_{name}.png"
    shoot(sc, cam, Vector((tx, lo.y - D, 5.0)), Vector((tx, lo.y, tz)), lens, path)
    return path


def run(fam, build, mats):
    """build: [(name, fn)] in priority order; builds, exports, renders and records each piece, merging the pack after every piece."""
    for d in (OUT / "maps", OUT / fam, UP / "maps", CAPD):
        d.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for m in mats:
        MAT_BUILDERS[m]()
    sc, cam, ground = setup_render()
    next(n for n in ground.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.50, 0.44, 0.31, 1)
    fig = make_figure()
    fj = OUT / f"family_{fam}.json"
    data = json.loads(fj.read_text()) if fj.exists() else {}
    done_names, failed = [], []
    for name, fn in build:
        if ONLY and name not in ONLY:
            continue
        try:
            fn()
            info = export_piece(fam, name)
            png = "-" if NORENDER else str(render_piece(name, sc, cam, ground, fig).relative_to(ROOT)).replace("\\", "/")
        except Exception as e:
            traceback.print_exc()
            failed.append(name)
            note(f"- {name}: FAILED {type(e).__name__}: {e}")
            continue
        data[name] = info
        data["_materials"] = {**data.get("_materials", {}), **mat_maps()}
        fj.write_text(json.dumps(data, indent=2) + "\n")
        merge_pack()
        done_names.append(name)
        note(f"- {name} [{fam}]: sub-meshes {json.dumps(info['sub_meshes'])}; tris {info['tris_total']}; bbox {info['size_studs_xyz_roblox']} studs; "
             f"GLB {info['file_size_bytes'] // 1024} KB; max texture {info['max_texture_px']} px; render {png}")
        print("SALT_PIECE", name, info["tris_total"], info["size_studs_xyz_roblox"], flush=True)
    n, largest = merge_pack()
    big = max((v for k, p in data.items() if k != "_materials" for v in p["sub_meshes"].values()), default=0)
    note(f"- CHECKPOINT {fam}: built {len(done_names)} this run ({', '.join(done_names) or '-'}); failed {failed or 'none'}; family total {len(data) - 1 if '_materials' in data else len(data)}; "
         f"largest sub-mesh in family {big} tris; pack now {n} pieces, largest overall {largest[0]} {largest[1]}")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / fam / f"saltreach_{fam}.blend"), compress=True)
    print("SALT_OK", fam, done_names, "failed", failed, flush=True)
    return sc, cam, ground, fig
