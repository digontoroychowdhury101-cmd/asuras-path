"""Amberfall Ravine kit, shared helpers (lane M4). exec'd by amberfall_veg / _rock / _built / _hero (each sets FAMILY first).

Supersedes: nothing (no earlier Amberfall kit scripts exist). Linked via outputs/claude-open-world-2026-11-14/workers/23a-amber-kit.md
(the lane lead links that note from LEDGER.md). New file because the four family scripts share one set of helpers, like bellwood_*.py share slice_kit.py.
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Reuses slice_kit.py helpers (exec'd without its main()). 1 BU = 1 stud, base centre at the origin, Blender Z up (glTF export makes it Y up).
Per piece: GLB -> assets/source/overworld/amberfall/, copy -> .../upload/amberfall/, part entry -> amberfall/parts/<family>.json (merged into the
pack manifest by amberfall_pack.py), eye-height render beside a 5.5 stud figure -> outputs/.../captures/kit/amberfall/, checkpoint line in workers/23a-amber-kit.md.
Env: AMBER_ONLY=Name1,Name2 builds a subset; AMBER_NORENDER=1 skips renders.
"""
import json
import math
import os
import random
import shutil
import struct
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, noise

HERE = Path(__file__).resolve()
_src = (HERE.parent / "slice_kit.py").read_text(encoding="utf-8")
exec(compile(_src.rsplit("\nmain()", 1)[0], "slice_kit.py", "exec"), globals())  # helpers; its main() is not run

ROOT = HERE.parents[3]
OUT = ROOT / "assets/source/overworld/amberfall"
UP = ROOT / "assets/source/overworld/upload/amberfall"
CAP = ROOT / "outputs/claude-open-world-2026-11-14/captures/kit/amberfall"
NOTE = ROOT / "outputs/claude-open-world-2026-11-14/workers/23a-amber-kit.md"
PARTS = OUT / "parts"
REGISTRY = "assets/AMBERFALL_KIT_UPLOADED.json"
ONLY = {s for s in os.environ.get("AMBER_ONLY", "").split(",") if s}
NORENDER = bool(os.environ.get("AMBER_NORENDER"))
TAU = 2 * math.pi
rng = random.Random(23)  # noqa: F811  (slice_kit's rng is rebound here so every helper shares one seeded stream)


# ------------------------------------------------------------------------------------------ materials
def mk(name, col, h, rough, k=4.0, double=False):
    return material(name, save(name + "_Color", np.clip(col, 0, 1)), save(name + "_Roughness", np.clip(rough, 0, 1), True),
                    save(name + "_Normal", nmap(h, k), True), double=double)


def sand_tile(name, base, seed, n=512, k=5.0, band=0.05, streak=0.35):
    """Tileable sandstone: horizontal strata, pitting, vertical rain streaks."""
    yy = np.mgrid[0:n, 0:n][0]
    f1, f2, pit = field(n, 1.4, seed), field(n, 0.9, seed + 1), field(n, 0.5, seed + 2)
    st = np.sin(yy / n * TAU * 7 + f2 * 0.9)
    rain = np.clip((field(n, 1.2, seed + 3, 14.0) - 0.4) * 0.9, 0, 1)
    col = np.array(base) * (0.88 + 0.07 * f1[..., None] + band * st[..., None])
    col = col * (1 - streak * rain[..., None]) + np.array([0.20, 0.12, 0.08]) * streak * rain[..., None] * 0.4
    col *= np.where(pit[..., None] > 1.6, 0.7, 1.0)
    h = 0.5 + 0.1 * f1 + 0.05 * f2 + 0.03 * st - 0.1 * np.clip(pit - 1.4, 0, 2)
    return mk(name, col, h, 0.82 + 0.06 * f2, k)


def bark_tile(name, base, seed, k=6.0, dark=0.55):
    n = 512
    ridge, fine = field(n, 1.0, seed, 9.0), field(n, 1.5, seed + 1, 3.0)
    h = 0.5 + 0.25 * np.tanh(ridge) + 0.06 * fine
    col = np.array(base) * (0.75 + 0.7 * (h[..., None] - 0.5))
    col *= np.where(ridge[..., None] < -1.2, dark, 1.0)
    return mk(name, col, h, 0.85 - 0.1 * h, k)


def wood_end_mat():
    n = 512
    yy, xx = np.mgrid[0:n, 0:n]
    x, y = (xx + 0.5) / n * 2 - 1, (yy + 0.5) / n * 2 - 1
    r, ang = np.hypot(x, y), np.arctan2(y, x)
    wp = field(n, 1.2, 181) * 0.035
    ring = (0.5 + 0.5 * np.sin((r + wp) * TAU * 12)) ** 2
    col = np.array([0.66, 0.54, 0.40]) * (1 - ring[..., None] * 0.36)
    crack = np.exp(-((((ang / TAU * 9 + wp * 20) % 1.0) - 0.5) / 0.025) ** 2) * np.clip((r - 0.12) * 3, 0, 1)
    col *= 1 - 0.55 * crack[..., None]
    bark = np.clip((r - 0.9) / 0.04, 0, 1)[..., None]
    col = col * (1 - bark) + np.array([0.24, 0.15, 0.10]) * bark
    return mk("Amb_WoodEnd", col, 0.5 + 0.05 * ring - 0.25 * crack, 0.88 + 0.04 * field(n, 1.0, 182), 5.0)


PAL = {"scarlet": [(0.62, 0.08, 0.05), (0.74, 0.14, 0.06), (0.50, 0.06, 0.05), (0.82, 0.24, 0.08), (0.42, 0.05, 0.04)],
       "orange": [(0.85, 0.38, 0.07), (0.92, 0.50, 0.10), (0.74, 0.28, 0.06), (0.95, 0.62, 0.14), (0.60, 0.20, 0.05)],
       "gold": [(0.88, 0.66, 0.12), (0.78, 0.55, 0.10), (0.94, 0.76, 0.22), (0.66, 0.46, 0.09), (0.55, 0.40, 0.10)],
       "dry": [(0.58, 0.50, 0.22), (0.66, 0.56, 0.26), (0.46, 0.40, 0.18), (0.72, 0.62, 0.30), (0.40, 0.30, 0.12)],
       "pine": [(0.16, 0.26, 0.10), (0.22, 0.32, 0.12), (0.28, 0.34, 0.12), (0.12, 0.20, 0.08), (0.34, 0.38, 0.14)]}
PAL_PTS = {}


def leaf_atlas():
    """Amb_Leaf 1024x1024: five 204 px bands (scarlet, orange, gold, dry, pine), ~420 painted lanceolate leaves each over a dark gap colour.
    PAL_PTS[name] = (u, v) samples inside painted leaves; leaf cards read one flat colour from one of them."""
    n, bh = 1024, 204
    r = np.random.default_rng(231)
    col, h = np.zeros((n, n, 3)), np.full((n, n), 0.25)
    yy, xx = np.mgrid[-26:27, -26:27]
    for b, (pname, tones) in enumerate(PAL.items()):
        lo = b * bh
        col[lo:lo + bh] = np.array(tones[3]) * 0.35
        pts_h = np.zeros((n, n), bool)
        for i in range(420):
            cx, cy = int(r.integers(0, n)), int(r.integers(lo + 28, lo + bh - 28))
            a, L = r.uniform(0, np.pi), r.uniform(15, 24)
            wd = L * r.uniform(0.32, 0.45)
            u, v = xx * np.cos(a) + yy * np.sin(a), -xx * np.sin(a) + yy * np.cos(a)
            t = u / L
            ins = (np.abs(t) < 1) & (np.abs(v) < wd * np.clip(1 - t ** 2, 0, 1) ** 0.8)
            rows, cols = cy + yy, (cx + xx) % n
            tone = np.array(tones[r.choice(5, p=[0.28, 0.30, 0.22, 0.12, 0.08])])
            shade = 0.8 + 0.3 * (0.5 + 0.5 * t) + np.where(np.abs(v) < 0.9, 0.12, 0.0)
            col[rows[ins], cols[ins]] = tone * shade[ins][:, None]
            h[rows[ins], cols[ins]] = 0.5 + 0.3 * (1 - np.abs(v[ins]) / wd) + 0.02 * i / 420
            pts_h[rows[ins], cols[ins]] = np.abs(v[ins]) > 2.2
        ys, xs = np.nonzero(pts_h[lo + 30:lo + bh - 30])
        sel = np.random.default_rng(b).choice(len(ys), 300)
        PAL_PTS[pname] = list(zip(((xs[sel] + 0.5) / n).tolist(), ((ys[sel] + lo + 30 + 0.5) / n).tolist()))
    return mk("Amb_Leaf", col * 1.15, h, 0.62 + 0.1 * field(n, 1.0, 232), 3.0)


def use_pal(*spec):
    """Leaf cards pick colours from LEAF_PTS: spec = ((name, weight), ...)."""
    LEAF_PTS[:] = [p for name, w in spec for p in PAL_PTS[name] * w]


def band_uv(bm, pname):
    """Fold a foliage-pad mesh's (tiling) UVs into one palette band of Amb_Leaf so a pad stays one colour family."""
    uvl = _uvl(bm)
    lo = list(PAL).index(pname) * 204
    for f in bm.faces:
        cu = math.floor(sum(l[uvl].uv.x for l in f.loops) / len(f.loops))
        cv = math.floor(sum(l[uvl].uv.y for l in f.loops) / len(f.loops))
        for l in f.loops:
            l[uvl].uv = (l[uvl].uv.x - cu, (lo + 10 + (l[uvl].uv.y - cv) * 184) / 1024)


def veg_mats():
    leaf_atlas()
    bark_tile("Amb_RedBark", (0.52, 0.27, 0.19), 201, 4.0, 0.7)
    bark_tile("Amb_Bark", (0.34, 0.27, 0.21), 203)
    bark_tile("Amb_Deadwood", (0.60, 0.54, 0.46), 205, 5.0, 0.6)
    wood_end_mat()
    blade_mat("Amb_Grass", 128, 256, (0.50, 0.42, 0.18), (0.90, 0.84, 0.54), 211)
    blade_mat("Amb_Fern", 256, 256, (0.24, 0.16, 0.06), (0.62, 0.42, 0.14), 212, double=False)


def built_mats():
    sand_tile("Amb_Stone", (0.80, 0.60, 0.38), 301)
    sand_tile("Amb_StoneDark", (0.62, 0.43, 0.27), 311)
    n = 512
    grain, tone = field(n, 0.9, 321, 16.0), field(n, 1.6, 322)
    col = np.array([0.36, 0.20, 0.12]) * (0.8 + 0.14 * grain[..., None] + 0.08 * tone[..., None])
    mk("Amb_Timber", col, 0.5 + 0.08 * grain, 0.72 + 0.06 * grain, 4.0)
    yy, xx = np.mgrid[0:n, 0:n]
    tw = 0.5 + 0.5 * np.sin((xx / n * 24 + yy / n * 24) * math.pi)  # twisted strands, tiles in both directions
    col = np.array([0.62, 0.50, 0.30]) * (0.65 + 0.35 * tw[..., None]) * (0.9 + 0.08 * field(n, 1.0, 323)[..., None])
    mk("Amb_Rope", col, 0.3 + 0.4 * tw, np.full((n, n), 0.9), 5.0)
    r = np.random.default_rng(51)
    ri, fy = yy // 32, (yy % 32) / 32
    xs = (xx + (ri % 2) * 32) % n
    ti, fx = xs // 64, (xs % 64) / 64
    tone_ = r.uniform(0.8, 1.15, (16, 8))[ri, ti][..., None]
    shade = 1 - 0.5 * np.clip((fy - 0.78) / 0.22, 0, 1) - 0.4 * np.clip((0.07 - fx) / 0.07, 0, 1)
    col = np.array([0.52, 0.24, 0.13]) * tone_ * shade[..., None]
    mk("Amb_Roof", col, 0.35 + 0.4 * fy - 0.25 * np.clip((0.07 - fx) / 0.07, 0, 1), np.full((n, n), 0.74), 4.0)
    p = np.clip((field(256, 1.5, 341) - 0.35) * 0.7, 0, 0.85)
    col = np.array([0.50, 0.32, 0.15]) * (1 - p[..., None]) + np.array([0.20, 0.50, 0.42]) * p[..., None]
    material("Amb_Bronze", save("Amb_Bronze_Color", col), save("Amb_Bronze_Roughness", 0.35 + 0.45 * p, True),
             save("Amb_Bronze_Normal", nmap(0.5 + 0.1 * field(256, 1.2, 342), 3.0), True), save("Amb_Bronze_Metal", 1 - 0.85 * p, True))
    g = np.linspace(-1, 1, 128)
    v, u = np.meshgrid(g, g, indexing="ij")
    gl = np.clip(1 - np.sqrt(u ** 2 + v ** 2) * 0.7, 0, 1)[..., None]
    mk("Amb_Glow", np.array([0.60, 0.26, 0.05]) * (1 - gl) + np.array([1.0, 0.76, 0.34]) * gl, np.full((128, 128), 0.5), np.full((128, 128), 0.4), 1.0)


# ------------------------------------------------------------------------------------------ geometry helpers
def disc(bm, c, n, r, sides=16, jit=0.0, bulge=0.0, rr=None):
    """Fan disc (end grain) facing n; ring tile centred (a disc of radius r maps to the whole tile)."""
    rr = rr or rng
    uvl = _uvl(bm)
    c, n = Vector(c), Vector(n).normalized()
    e1 = n.cross(Vector((0, 0, 1)))
    if e1.length < 0.2:
        e1 = n.cross(Vector((1, 0, 0)))
    e1.normalize()
    e2 = n.cross(e1)
    ring = [bm.verts.new(c + (e1 * math.cos(TAU * k / sides) + e2 * math.sin(TAU * k / sides)) * r + n * rr.uniform(0, jit)) for k in range(sides)]
    cv = bm.verts.new(c + n * bulge)
    for k in range(sides):
        f = bm.faces.new((cv, ring[k], ring[(k + 1) % sides]))
        for l in f.loops:
            d = l.vert.co - c
            l[uvl].uv = (0.5 + d.dot(e1) / (2 * r) * 0.98, 0.5 + d.dot(e2) / (2 * r) * 0.98)


def blade(bm, base, bend, hgt, wid, nseg=4, sag=0.12):
    """Tapering single-sided blade strip bending along `bend`; u across, v along (0 base .. 1 tip)."""
    uvl = _uvl(bm)
    side = Vector((-bend.y, bend.x, 0))
    side = side.normalized() if side.length > 1e-5 else Vector((1, 0, 0))
    P = [base + bend * (k / nseg) ** 2 * 1.4 + Vector((0, 0, hgt * k / nseg - sag * hgt * (k / nseg) ** 2)) for k in range(nseg + 1)]
    for k in range(nseg):
        w0, w1 = wid * (1 - k / nseg), wid * (1 - (k + 1) / nseg)
        if k < nseg - 1:
            vs = [bm.verts.new(P[k] - side * w0), bm.verts.new(P[k] + side * w0), bm.verts.new(P[k + 1] + side * w1), bm.verts.new(P[k + 1] - side * w1)]
            uvs = ((0, k / nseg), (1, k / nseg), (1, (k + 1) / nseg), (0, (k + 1) / nseg))
        else:
            vs = [bm.verts.new(P[k] - side * w0), bm.verts.new(P[k] + side * w0), bm.verts.new(P[nseg])]
            uvs = ((0, k / nseg), (1, k / nseg), (0.5, 1))
        f = bm.faces.new(vs)
        for l, uv in zip(f.loops, uvs):
            l[uvl].uv = uv


def uv_planar(bm, faces, uvs=8.0, off=(0.0, 0.0)):
    """World-stud planar UVs by dominant normal axis (tileable stone/timber materials)."""
    uvl = _uvl(bm)
    bm.normal_update()
    for f in faces:
        n = f.normal
        a = max(range(3), key=lambda i: abs(n[i]))
        ua, va = ((1, 2), (0, 2), (0, 1))[a]
        for l in f.loops:
            c = l.vert.co
            l[uvl].uv = (c[ua] / uvs + off[0], c[va] / uvs + off[1])


def solid(bm, pts, uvs=8.0):
    """Hexahedron from 8 points (front quad 0-3 then back quad 4-7 in the same winding); planar UVs."""
    vs = [bm.verts.new(p) for p in pts]
    fs = [bm.faces.new(q) for q in ((vs[0], vs[3], vs[2], vs[1]), (vs[4], vs[5], vs[6], vs[7]), (vs[0], vs[1], vs[5], vs[4]),
                                    (vs[1], vs[2], vs[6], vs[5]), (vs[2], vs[3], vs[7], vs[6]), (vs[3], vs[0], vs[4], vs[7]))]
    uv_planar(bm, fs, uvs, (rng.random(), rng.random()))


def arch(bm, cx, y, zc, r_in, thick, depth, n=11, gap=0.07, uvs=8.0, a0=0.0, a1=math.pi):
    """Voussoir ring in the XZ plane: centre (cx, zc), inner radius r_in, thickness `thick`, extruded `depth` along Y about y."""
    ro = r_in + thick
    yf, yb = y - depth / 2, y + depth / 2
    for i in range(n):
        s, e = a0 + (a1 - a0) * i / n, a0 + (a1 - a0) * (i + 1) / n
        pts = []
        for yy in (yf, yb):
            for ri, ang in ((r_in, s), (ro, s), (ro, e), (r_in, e)):
                # shrink each stone a little toward its own centre so the joints read
                pts.append(Vector((cx + ri * math.cos(ang), yy, zc + ri * math.sin(ang))))
        c = sum(pts, Vector()) / 8
        pts = [c + (p - c) * (1 - gap / max(thick, 0.5)) for p in pts]
        solid(bm, pts, uvs)


def brick_h(bm, x0, x1, z0, z1, y, d, rr, bw=(2.4, 3.8), bev=0.1, mode="stone", jag=0.0, uvs=8.0):
    """Fill the XZ rectangle [x0,x1] x [z0,z1] with one course of random-width blocks of depth d centred at y."""
    x = x0
    while x < x1 - 0.05:
        w = min(rr.uniform(*bw), x1 - x)
        if x1 - (x + w) < 0.9:
            w = x1 - x
        bx(bm, x + w / 2, y + rr.uniform(-0.06, 0.06), z0, w - 0.06, d, z1 - z0 - 0.05, bev=bev, rz=rr.uniform(-0.01, 0.01), jag=jag, uvs=uvs)
        x += w


def rope(bm, pts, r=0.18, sides=5):
    tube(bm, pts, [r] * len(pts), sides=sides, uvs=2.0)


def rot_verts(bm, n0, rz, c=(0, 0, 0)):
    """Rotate every vert of faces created after face index n0 about Z through c."""
    bm.faces.ensure_lookup_table()
    vs = {v for f in bm.faces[n0:] for v in f.verts}
    bmesh.ops.rotate(bm, verts=list(vs), cent=Vector(c), matrix=Matrix.Rotation(rz, 3, "Z"))


# ------------------------------------------------------------------------------------------ export, pack part, render
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


PART_FILE = PARTS / f"{FAMILY}.json"
PACK = json.loads(PART_FILE.read_text())["pieces"] if PART_FILE.exists() else {}


def export_piece(name, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    path = OUT / f"{name}.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_apply=False)
    subs, lo, hi = inspect_glb(path)
    for k, v in subs.items():
        assert v["tris"] < TRI_CAP, (k, v["tris"])
    shutil.copy2(path, UP / path.name)
    tex = {}
    for m in sorted({v["material"] for v in subs.values()}):
        for suf in ("Color", "Normal", "Roughness"):
            im = bpy.data.images.get(f"{m}_{suf}")
            if im:
                tex[f"{m}_{suf}"] = list(im.size)
    PACK[name] = {
        "name": name, "family": FAMILY, "file": path.name, "sub_meshes": {k: v["tris"] for k, v in subs.items()},
        "sub_mesh_materials": {k: v["material"] for k, v in subs.items()}, "tris_total": sum(v["tris"] for v in subs.values()),
        "size_studs_xyz_roblox": [round(hi[i] - lo[i], 2) for i in range(3)],
        "bbox_studs_xyz_roblox": {"min": [round(x, 2) for x in lo], "max": [round(x, 2) for x in hi]},
        "texture_px": tex, "texture_max_px": max((max(v) for v in tex.values()), default=0), "file_size_bytes": path.stat().st_size,
        "pivot": "base centre at origin (Y up); " + json.dumps({"min_y": round(lo[1], 3), "centre_x": round((lo[0] + hi[0]) / 2, 3), "centre_z": round((lo[2] + hi[2]) / 2, 3)}),
        "studio_target": f"ServerStorage/AmberfallKit/{name}", "registry_file": REGISTRY,
    }
    PARTS.mkdir(parents=True, exist_ok=True)
    PART_FILE.write_text(json.dumps({"family": FAMILY, "pieces": PACK}, indent=2) + "\n")
    return PACK[name]


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
    try:
        m.use_nodes = True
    except Exception:
        pass
    next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.1, 0.35, 0.85, 1)
    me.materials.append(m)
    o = bpy.data.objects.new("Ref_Figure_5.5studs", me)
    bpy.context.scene.collection.objects.link(o)
    return o


def render_setup():
    sc, cam, ground = setup_render()
    sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.86, 0.68, 0.52, 1)  # peach ravine haze
    next(n for n in ground.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.36, 0.25, 0.13, 1)
    return sc, cam, ground, make_figure()


def render_piece(name, objs, sc, cam, ground, fig):
    for o in [o for os_ in PIECES.values() for o in os_]:
        o.hide_render = o not in objs
    lo, hi = bbox(objs)
    fx = hi.x + max(3.2, (hi.x - lo.x) * 0.04)
    fig.location = (fx, lo.y + min(2.0, (hi.y - lo.y) / 2), 0)
    span, Ht = fx + 1.8 - lo.x, max(hi.z, 6.0)
    tz, tx, lens = max(Ht * 0.5, 3.0), (lo.x + fx + 1.8) / 2, 35.0
    tw = 18.0 / lens
    D = max(span * 0.56 / tw, max(Ht - tz, tz) * 1.18 / (tw * 0.75), 10.0)
    ground.scale, ground.location = (400, 400, 1), Vector((0, 0, 0))
    path = CAP / f"eye_{name}.png"
    shoot(sc, cam, Vector((tx, lo.y - D, 5.0)), Vector((tx, lo.y, tz)), lens, path)
    return path


def note(line):
    with open(NOTE, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def run_family(build):
    """build = [(name, fn)]; materials must already exist. Builds (a subset of) pieces, exports, renders, writes the checkpoint."""
    sc, cam, ground, fig = render_setup()
    done = []
    for name, fn in [b for b in build if not ONLY or b[0] in ONLY]:
        fn()
        info = export_piece(name, PIECES[name])
        png = "-" if NORENDER else str(render_piece(name, PIECES[name], sc, cam, ground, fig).relative_to(ROOT)).replace("\\", "/")
        print("AMBER_PIECE", name, info["tris_total"], info["size_studs_xyz_roblox"], "max_sub", max(info["sub_meshes"].values()), png, flush=True)
        done.append(info)
    if done:
        big = max(((v, k) for i in done for k, v in i["sub_meshes"].items()))
        note(f"- CHECKPOINT {FAMILY}: {len(done)} pieces ({', '.join(i['name'] for i in done)}); largest sub-mesh {big[1]} = {big[0]} tris")
    for o in [o for os_ in PIECES.values() for o in os_]:
        o.hide_render = False
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"amberfall_{FAMILY}_kit.blend"), compress=True)
    print("AMBER_OK", FAMILY, len(done), flush=True)


def prep():
    for d in (OUT / "maps", UP / "maps", CAP, PARTS):
        d.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
