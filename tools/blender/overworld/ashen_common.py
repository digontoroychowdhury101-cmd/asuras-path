"""Ashen Stair kit, shared helpers (lane M7). exec'd by ashen_veg / _rock / _built / _hero (each sets FAMILY first).

Supersedes: nothing (searched first: no Ashen kit scripts exist; the Amberfall scripts are the pattern copied here, not replaced). Linked via
outputs/claude-open-world-2026-11-14/workers/23d-ashen-kit.md (the lane lead links that note from LEDGER.md). New file because the four family scripts
share one set of helpers, like amberfall_*.py share amberfall_common.py.
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Reuses slice_kit.py helpers (exec'd without its main()). 1 BU = 1 stud, base centre at the origin, Blender Z up (glTF export makes it Y up).
Per piece: GLB -> assets/source/overworld/ashen/, copy -> .../upload/ashen/, part entry -> ashen/parts/<family>.json (merged into the pack manifest
by ashen_pack.py), eye-height render beside a 5.5 stud figure -> outputs/.../captures/kit/ashen/, checkpoint line in workers/23d-ashen-kit.md.
Env: ASH_ONLY=Name1,Name2 builds a subset; ASH_NORENDER=1 skips renders.
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
OUT = ROOT / "assets/source/overworld/ashen"
UP = ROOT / "assets/source/overworld/upload/ashen"
CAP = ROOT / "outputs/claude-open-world-2026-11-14/captures/kit/ashen"
NOTE = ROOT / "outputs/claude-open-world-2026-11-14/workers/23d-ashen-kit.md"
PARTS = OUT / "parts"
REGISTRY = "assets/ASHEN_KIT_UPLOADED.json"
ONLY = {s for s in os.environ.get("ASH_ONLY", "").split(",") if s}
NORENDER = bool(os.environ.get("ASH_NORENDER"))
TAU = 2 * math.pi
rng = random.Random(27)  # noqa: F811  (slice_kit's rng is rebound so every helper shares one seeded stream)


# ------------------------------------------------------------------------------------------ materials
def mk(name, col, h, rough, k=4.0, double=False):
    return material(name, save(name + "_Color", np.clip(col, 0, 1)), save(name + "_Roughness", np.clip(rough, 0, 1), True),
                    save(name + "_Normal", nmap(h, k), True), double=double)


def block_tile(name, base, seed, n=512, rows=4, cols=4, k=5.0, lichen=0.0, soot=0.3):
    """Tileable ashlar: staggered coursed blocks with joints, per-block tone, rain/soot streaks, optional lichen. 8 studs per tile at uvs=8."""
    yy, xx = np.mgrid[0:n, 0:n]
    r = np.random.default_rng(seed)
    f1, f2, li = field(n, 1.4, seed), field(n, 0.9, seed + 1), field(n, 0.8, seed + 3)
    rain = np.clip((field(n, 1.2, seed + 4, 14.0) - 0.4) * 0.9, 0, 1)
    rh, cw = n // rows, n // cols
    ri = yy // rh
    xs = (xx + (ri % 2) * (cw // 2)) % n
    ci = xs // cw
    dy, dx = np.minimum(yy % rh, rh - 1 - yy % rh), np.minimum(xs % cw, cw - 1 - xs % cw)
    d = np.minimum(dy, dx)
    joint = np.clip(1 - d / 5.0, 0, 1)
    tone = r.uniform(0.84, 1.14, (rows, cols))[ri, ci][..., None]
    col = np.array(base) * tone * (0.88 + 0.07 * f1[..., None]) * (1 - 0.45 * joint[..., None])
    col = col * (1 - soot * rain[..., None]) + np.array([0.10, 0.09, 0.09]) * soot * rain[..., None] * 0.4
    if lichen:
        p = np.clip((li - 1.1) * 1.4, 0, 1)[..., None] * lichen
        col = col * (1 - p) + np.array([0.52, 0.55, 0.30]) * p
    h = 0.55 + 0.08 * f1 + 0.04 * np.clip(d / 12.0, 0, 1) - 0.3 * joint
    return mk(name, col, h, 0.85 + 0.06 * f2, k)


def bark_tile(name, base, seed, k=6.0, dark=0.55):
    n = 512
    ridge, fine = field(n, 1.0, seed, 9.0), field(n, 1.5, seed + 1, 3.0)
    h = 0.5 + 0.25 * np.tanh(ridge) + 0.06 * fine
    col = np.array(base) * (0.75 + 0.7 * (h[..., None] - 0.5))
    col *= np.where(ridge[..., None] < -1.2, dark, 1.0)
    return mk(name, col, h, 0.85 - 0.1 * h, k)


def char_tile(name, seed):
    """Charred wood: alligator-cracked charcoal, ash-grey on the ridges, dull brown in the cracks."""
    n = 512
    ridge, fine, ash = field(n, 1.0, seed, 7.0), field(n, 1.5, seed + 1, 2.5), field(n, 1.1, seed + 2)
    h = 0.5 + 0.28 * np.tanh(ridge * 1.2) + 0.05 * fine
    crack = np.clip(-ridge - 0.5, 0, 1.5)[..., None]
    col = np.array([0.10, 0.095, 0.095]) * (0.7 + 0.8 * (h[..., None] - 0.4))
    col = col + np.array([0.20, 0.19, 0.18]) * np.clip(ash - 0.3, 0, 1)[..., None] * (h[..., None] > 0.55)
    col = col * (1 - 0.5 * crack) + np.array([0.18, 0.09, 0.05]) * 0.5 * crack
    return mk(name, col, h, 0.8 + 0.12 * (1 - h), k=6.0)


def wood_end_mat():
    n = 512
    yy, xx = np.mgrid[0:n, 0:n]
    x, y = (xx + 0.5) / n * 2 - 1, (yy + 0.5) / n * 2 - 1
    r, ang = np.hypot(x, y), np.arctan2(y, x)
    wp = field(n, 1.2, 481) * 0.035
    ring = (0.5 + 0.5 * np.sin((r + wp) * TAU * 12)) ** 2
    col = np.array([0.55, 0.50, 0.43]) * (1 - ring[..., None] * 0.34)
    crack = np.exp(-((((ang / TAU * 9 + wp * 20) % 1.0) - 0.5) / 0.025) ** 2) * np.clip((r - 0.12) * 3, 0, 1)
    col *= 1 - 0.55 * crack[..., None]
    bark = np.clip((r - 0.9) / 0.04, 0, 1)[..., None]
    col = col * (1 - bark) + np.array([0.14, 0.12, 0.11]) * bark
    return mk("Ash_WoodEnd", col, 0.5 + 0.05 * ring - 0.25 * crack, 0.88 + 0.04 * field(n, 1.0, 482), 5.0)


PAL = {"pine": [(0.10, 0.19, 0.12), (0.14, 0.25, 0.15), (0.08, 0.15, 0.10), (0.19, 0.30, 0.17), (0.12, 0.21, 0.14)],
       "blue": [(0.14, 0.26, 0.24), (0.18, 0.31, 0.28), (0.10, 0.20, 0.20), (0.24, 0.36, 0.32), (0.13, 0.24, 0.26)],
       "dry": [(0.34, 0.27, 0.14), (0.40, 0.31, 0.16), (0.28, 0.21, 0.11), (0.46, 0.37, 0.20), (0.22, 0.17, 0.09)],
       "ash": [(0.40, 0.39, 0.37), (0.47, 0.45, 0.42), (0.33, 0.32, 0.31), (0.55, 0.53, 0.49), (0.26, 0.25, 0.25)],
       "lichen": [(0.52, 0.55, 0.30), (0.60, 0.60, 0.36), (0.44, 0.47, 0.26), (0.66, 0.50, 0.22), (0.36, 0.40, 0.22)]}
PAL_PTS = {}


def leaf_atlas():
    """Ash_Leaf 1024x1024: five 204 px bands (pine, blue-green, dry, ash-grey, lichen), ~420 painted lanceolate cards each over a dark gap colour.
    PAL_PTS[name] = (u, v) samples inside painted cards; leaf cards read one flat colour from one of them."""
    n, bh = 1024, 204
    r = np.random.default_rng(271)
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
    return mk("Ash_Leaf", col * 1.15, h, 0.62 + 0.1 * field(n, 1.0, 272), 3.0)


def use_pal(*spec):
    """Leaf cards pick colours from LEAF_PTS: spec = ((name, weight), ...)."""
    LEAF_PTS[:] = [p for name, w in spec for p in PAL_PTS[name] * w]


def band_uv(bm, pname):
    """Fold a foliage-pad mesh's (tiling) UVs into one palette band of Ash_Leaf so a pad stays one colour family."""
    uvl = _uvl(bm)
    lo = list(PAL).index(pname) * 204
    for f in bm.faces:
        cu = math.floor(sum(l[uvl].uv.x for l in f.loops) / len(f.loops))
        cv = math.floor(sum(l[uvl].uv.y for l in f.loops) / len(f.loops))
        for l in f.loops:
            l[uvl].uv = (l[uvl].uv.x - cu, (lo + 10 + (l[uvl].uv.y - cv) * 184) / 1024)


def veg_mats():
    leaf_atlas()
    bark_tile("Ash_Bark", (0.30, 0.25, 0.21), 401)
    char_tile("Ash_Char", 403)
    bark_tile("Ash_Deadwood", (0.58, 0.55, 0.50), 405, 5.0, 0.6)
    wood_end_mat()
    blade_mat("Ash_Grass", 128, 256, (0.26, 0.28, 0.12), (0.74, 0.70, 0.44), 411)
    n = 512  # lichen crust: pale grey rock under green/yellow/orange rosettes
    g1, g2, g3 = field(n, 1.0, 421), field(n, 0.7, 422), field(n, 1.3, 423)
    col = np.array([0.40, 0.39, 0.37]) * (0.85 + 0.1 * g3[..., None])
    gr = np.clip((g1 - 0.2) * 1.6, 0, 1)[..., None]
    col = col * (1 - gr) + np.array([0.52, 0.56, 0.30]) * (0.85 + 0.15 * g2[..., None]) * gr
    og = np.clip((g2 - 1.1) * 3.0, 0, 1)[..., None]
    col = col * (1 - og) + np.array([0.78, 0.55, 0.18]) * og
    mk("Ash_Lichen", col, 0.5 + 0.12 * np.clip(g1, -1, 2) + 0.05 * g2, 0.9 - 0.1 * gr[..., 0], 4.0)


def built_mats():
    block_tile("Ash_Stone", (0.44, 0.42, 0.39), 501, lichen=0.45)
    block_tile("Ash_StoneDark", (0.30, 0.29, 0.29), 511, rows=2, cols=2, soot=0.4)
    n = 512
    yy, xx = np.mgrid[0:n, 0:n]
    grain, tone = field(n, 0.9, 521, 16.0), field(n, 1.6, 522)
    paint = np.clip((field(n, 1.3, 523) - 0.1) * 2.5, 0, 1)[..., None]  # vermilion paint over dark, weathered wood
    col = np.array([0.20, 0.15, 0.12]) * (0.8 + 0.14 * grain[..., None] + 0.08 * tone[..., None])
    col = col * (1 - paint) + np.array([0.56, 0.21, 0.14]) * (0.72 + 0.16 * grain[..., None]) * paint
    mk("Ash_Timber", col, 0.5 + 0.08 * grain, 0.74 + 0.06 * grain, 4.0)
    tw = 0.5 + 0.5 * np.sin((xx / n * 24 + yy / n * 24) * math.pi)  # twisted strands, tiles in both directions
    col = np.array([0.50, 0.42, 0.30]) * (0.65 + 0.35 * tw[..., None]) * (0.9 + 0.08 * field(n, 1.0, 523)[..., None])
    mk("Ash_Rope", col, 0.3 + 0.4 * tw, np.full((n, n), 0.9), 5.0)
    r = np.random.default_rng(57)  # basalt slate roof tiles, staggered rows
    ri, fy = yy // 32, (yy % 32) / 32
    xs = (xx + (ri % 2) * 32) % n
    ti, fx = xs // 64, (xs % 64) / 64
    tone_ = r.uniform(0.8, 1.15, (16, 8))[ri, ti][..., None]
    dust = np.clip((field(n, 1.6, 531) - 0.5) * 1.2, 0, 0.6)[..., None]
    shade = 1 - 0.5 * np.clip((fy - 0.78) / 0.22, 0, 1) - 0.4 * np.clip((0.07 - fx) / 0.07, 0, 1)
    col = (np.array([0.19, 0.19, 0.22]) * tone_ * (1 - dust) + np.array([0.46, 0.45, 0.43]) * dust) * shade[..., None]
    mk("Ash_Roof", col, 0.35 + 0.4 * fy - 0.25 * np.clip((0.07 - fx) / 0.07, 0, 1), np.full((n, n), 0.72), 4.0)
    p = np.clip((field(256, 1.5, 541) - 0.35) * 0.7, 0, 0.85)
    col = np.array([0.50, 0.34, 0.16]) * (1 - p[..., None]) + np.array([0.22, 0.48, 0.40]) * p[..., None]
    material("Ash_Bronze", save("Ash_Bronze_Color", col), save("Ash_Bronze_Roughness", 0.35 + 0.45 * p, True),
             save("Ash_Bronze_Normal", nmap(0.5 + 0.1 * field(256, 1.2, 542), 3.0), True), save("Ash_Bronze_Metal", 1 - 0.85 * p, True))
    g = np.linspace(-1, 1, 128)
    v, u = np.meshgrid(g, g, indexing="ij")
    gl = np.clip(1 - np.sqrt(u ** 2 + v ** 2) * 0.7, 0, 1)[..., None]
    mk("Ash_Glow", np.array([0.60, 0.26, 0.05]) * (1 - gl) + np.array([1.0, 0.76, 0.34]) * gl, np.full((128, 128), 0.5), np.full((128, 128), 0.4), 1.0)
    # prayer-flag cloth: five faded colour cells side by side (a flag maps into one cell), woven
    n = 256
    yy, xx = np.mgrid[0:n, 0:n]
    cells = [(0.30, 0.40, 0.52), (0.78, 0.76, 0.70), (0.62, 0.20, 0.16), (0.30, 0.46, 0.28), (0.78, 0.62, 0.22)]
    weave = 0.5 + 0.5 * np.sin(xx * 1.6) * np.sin(yy * 1.6)
    fade = 0.8 + 0.2 * field(n, 1.4, 551)
    col = np.zeros((n, n, 3))
    for i, c in enumerate(cells):
        sl = slice(i * n // 5, (i + 1) * n // 5)
        col[:, sl] = np.array(c) * (0.85 + 0.15 * weave[:, sl, None]) * fade[:, sl, None]
    mk("Ash_Flag", col, 0.5 + 0.06 * weave, np.full((n, n), 0.9), 2.0, double=True)


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


def brick_h(bm, x0, x1, z0, z1, y, d, rr, bw=(2.4, 3.8), bev=0.1, jag=0.0, uvs=8.0):
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


def place(bm, n0, dx=0.0, dy=0.0, dz=0.0, rz=0.0, rx=0.0):
    """Rotate (about Z then X, through the origin) and translate every face created after index n0."""
    bm.faces.ensure_lookup_table()
    vs = list({v for f in bm.faces[n0:] for v in f.verts})
    if rz:
        bmesh.ops.rotate(bm, verts=vs, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(rz, 3, "Z"))
    if rx:
        bmesh.ops.rotate(bm, verts=vs, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(rx, 3, "X"))
    bmesh.ops.translate(bm, verts=vs, vec=Vector((dx, dy, dz)))


def scale_xy(bm, n0, sx=1.0, sy=1.0):
    """Scale every vert of faces created after index n0 about the Z axis (turns a square roof into a rectangular one)."""
    bm.faces.ensure_lookup_table()
    for v in {v for f in bm.faces[n0:] for v in f.verts}:
        v.co.x *= sx
        v.co.y *= sy


def tails(t, R, nt, tb=0.7):
    """Timber rafter tails under the eave of a slice_kit.roof_pt roof R, nt per side."""
    for q in range(nt):
        u = -0.92 + 1.84 * q / (nt - 1)
        for uu, vv, sw in ((u, -1, 0), (u, 1, 0), (-1, u, 1), (1, u, 1)):
            pt = roof_pt(R, uu, vv)
            o = Vector((math.copysign(1, uu), 0, 0)) if sw else Vector((0, math.copysign(1, vv), 0))
            c = pt - o * 1.0
            bx(t, c.x, c.y, pt.z - R["thick"] * 0.65 - 0.55, 2.4 if sw else tb, tb if sw else 2.4, tb, mode="timber", bev=0)


def horns(b, R, k=1.0):
    """Bronze up-curled hip ornaments on the four eave corners."""
    for sx, sy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        c = roof_pt(R, sx, sy)
        o = Vector((sx, sy, 0)).normalized()
        tube(b, [c - o * 0.6 * k, c + o * 1.8 * k + Vector((0, 0, 2.2 * k)), c + o * 3.4 * k + Vector((0, 0, 5.5 * k))], [1.0 * k, 0.65 * k, 0.15 * k], sides=6, uvs=4.0)


def finial(b, z0, k=1.0, seg=12):
    """Bronze spire: stacked discs and a bulb on a mast, k scales the whole (about 11 studs tall at k = 1)."""
    prof = [(0.05, 0), (2.4, 0), (2.6, 0.5), (2.2, 1.2), (1.0, 1.6), (0.7, 2.0), (1.9, 2.6), (1.9, 3.0), (0.6, 3.3), (0.5, 4.5), (1.6, 5.0), (1.6, 5.3),
            (0.5, 5.7), (0.4, 6.8), (1.3, 7.3), (1.3, 7.6), (0.4, 8.0), (0.35, 9.0), (0.9, 9.6), (0.9, 10.0), (0.4, 10.8), (0.05, 11.2)]
    lathe(b, [(r * k, z * k) for r, z in prof], z0=z0, seg=seg)


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
        "studio_target": f"ServerStorage/AshenKit/{name}", "registry_file": REGISTRY,
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
    sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.66, 0.70, 0.76, 1)  # cold mountain haze
    next(n for n in ground.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.26, 0.25, 0.24, 1)
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


def run_family(build, extra=None):
    """build = [(name, fn)]; materials must already exist. Builds (a subset of) pieces, exports, renders, writes the checkpoint.
    extra(name, sc, cam, ground) runs after each piece's render (the hero uses it for the far silhouette shot)."""
    sc, cam, ground, fig = render_setup()
    done = []
    for name, fn in [b for b in build if not ONLY or b[0] in ONLY]:
        fn()
        info = export_piece(name, PIECES[name])
        png = "-" if NORENDER else str(render_piece(name, PIECES[name], sc, cam, ground, fig).relative_to(ROOT)).replace("\\", "/")
        if extra and not NORENDER:
            fig.hide_render = True
            extra(name, sc, cam, ground)
            fig.hide_render = False
        print("ASH_PIECE", name, info["tris_total"], info["size_studs_xyz_roblox"], "max_sub", max(info["sub_meshes"].values()), png, flush=True)
        done.append(info)
    if done:
        big = max(((v, k) for i in done for k, v in i["sub_meshes"].items()))
        note(f"- CHECKPOINT {FAMILY}: {len(done)} pieces ({', '.join(i['name'] for i in done)}); largest sub-mesh {big[1]} = {big[0]} tris")
    for o in [o for os_ in PIECES.values() for o in os_]:
        o.hide_render = False
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"ashen_{FAMILY}_kit.blend"), compress=True)
    print("ASH_OK", FAMILY, len(done), flush=True)


def prep():
    for d in (OUT / "maps", UP / "maps", CAP, PARTS):
        d.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
