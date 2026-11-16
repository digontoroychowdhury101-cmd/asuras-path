"""Bellwood rock + built A kit (headless lane M2): stairs, retaining walls, paving, edging, rocks, cliffs, side gate, fences,
shrine, bell graves, prayer flags, signposts, well.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b --python tools/blender/overworld/bellwood_built_a.py
  env BB_NORENDER=1 skips the renders (geometry/export only).

Reuses the slice kit's helpers and materials by exec'ing slice_kit.py without its main() (slice_kit.py is not modified), so stone,
timber, bronze and Bell_Granite are the same maps. 1 BU = 1 stud, base-centre pivot (footprint centred, z=0 ground), every sub-mesh
asserted < 18000 tris. Stone blocks are chamfered boxes subdivided once and displaced by noise (hand-hewn silhouettes). Original
procedural work only: no generators, no uploads, no IDs.
"""
import json
import math
import os
import random
import shutil
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
ROOT = HERE.parents[3]
SK = HERE.parent / "slice_kit.py"
OUT = ROOT / "assets/source/overworld/bellwood_built_a"
UP = ROOT / "assets/source/overworld/upload/bellwood_built_a"
CAPD = ROOT / "outputs/claude-open-world-2026-11-14/captures/kit/bellwood_built_a"
NOTE = ROOT / "outputs/claude-open-world-2026-11-14/workers/21b-bell-built-a.md"
NORENDER = bool(os.environ.get("BB_NORENDER"))

_src = SK.read_text()
for a, b in (("S=16.0):\n    \"\"\"Noise-displaced", "S=16.0, extra=()):\n    \"\"\"Noise-displaced"), ("    cuts = []\n", "    cuts = list(extra)\n")):
    assert _src.count(a) == 1, a
    _src = _src.replace(a, b)
assert _src.rstrip().endswith("main()")
_src = _src.rstrip()[:-len("main()")]
G = {"__name__": "slice_kit_lib", "__file__": str(SK)}
exec(compile(_src, str(SK), "exec"), G)
globals().update({k: v for k, v in G.items() if not k.startswith("__")})
G["OUT"] = OUT
G["CAP"] = CAPD
manifest.clear()
manifest.update({"build": "blender -b --python tools/blender/overworld/bellwood_built_a.py", "tri_cap_per_sub_mesh": TRI_CAP,
                 "units": "studs (1 BU = 1 stud)", "pivot": "footprint centre at origin, ground z=0 (buried base down to -1)", "pieces": {}})

_h = NOTE.read_text().split("## PROGRESS")[0] if NOTE.exists() else ""
NOTE.write_text(_h + "## PROGRESS (appended per piece)\n")


def note(line):
    with NOTE.open("a") as f:
        f.write(line + "\n")


# ------------------------------------------------------------------------------------------ extra material
def flag_mat():
    n = 256
    yy, xx = np.mgrid[0:n, 0:n]
    band = (xx * 5) // n
    cols = np.array([(0.12, 0.22, 0.45), (0.78, 0.74, 0.64), (0.55, 0.15, 0.12), (0.18, 0.38, 0.20), (0.72, 0.55, 0.15)])
    weave = 0.86 + 0.08 * ((xx // 2 + yy // 2) % 2) + 0.06 * field(n, 1.2, 91)
    fade = 0.85 + 0.15 * np.clip(field(n, 1.6, 92), -1, 1)
    col = cols[band] * (weave * fade)[..., None]
    h = 0.5 + 0.1 * ((xx // 2 + yy // 2) % 2) + 0.04 * field(n, 1.0, 93)
    return material("Bell_Flag", save("Bell_Flag_Color", col), save("Bell_Flag_Roughness", np.full((n, n), 0.92), True),
                    save("Bell_Flag_Normal", nmap(h, 4.0), True), double=True)


# ------------------------------------------------------------------------------------------ builders
def blk(bm, x, y, z0, sx, sy, sz, rz=0.0, bev=0.12, disp=0.06, cuts=1, mode="stone", jag=0.0, uvs=8.0):
    """Hand-hewn block: chamfered box, subdivided `cuts` times, noise-displaced along the vertex normal."""
    before = set(bm.faces)
    bx(bm, x, y, z0, sx, sy, sz, rz=rz, mode=mode, bev=bev, jag=jag, uvs=uvs)
    new = [f for f in bm.faces if f not in before]
    if cuts:
        bmesh.ops.subdivide_edges(bm, edges=list({e for f in new for e in f.edges}), cuts=cuts, use_grid_fill=True)
        new = [f for f in bm.faces if f not in before]
    if disp:
        bm.normal_update()
        for v in {v for f in new for v in f.verts}:
            v.co += v.normal * disp * fbm(v.co * 0.9, 2)


def done(name, parts, centre=True):
    """parts: [(sub, bmesh, material name, smooth)]. Centres the footprint on the origin (z untouched) then registers the sub-meshes."""
    if centre:
        vs = [v.co for _, bm, _, _ in parts for v in bm.verts]
        cx = (min(v.x for v in vs) + max(v.x for v in vs)) / 2
        cy = (min(v.y for v in vs) + max(v.y for v in vs)) / 2
        for _, bm, _, _ in parts:
            bmesh.ops.translate(bm, verts=bm.verts[:], vec=Vector((-cx, -cy, 0)))
    for sub, bm, mat, sm in parts:
        obj(name, sub, bm, MATS[mat], smooth=sm)


def course(bm, o, ang, s0, s1, z0, h, depth, rr, wmin, wmax, fr, lat=0.0, jit=0.1, hdr=0.12, first=None, disp=0.06, bev=0.14):
    """One course of stones along direction `ang` from origin o (Vector2), spanning s0..s1; fr = side of the front face (+1 on +n)."""
    d, nn = Vector((math.cos(ang), math.sin(ang))), Vector((-math.sin(ang), math.cos(ang)))
    pos = s0
    while pos < s1 - 0.2:
        w = first if (first and pos == s0) else rr.uniform(wmin, wmax)
        w = min(w, s1 - pos)
        if s1 - pos - w < wmin * 0.5:
            w = s1 - pos
        ex = 0.4 if rr.random() < hdr else 0.0
        c = o + d * (pos + w / 2) + nn * (lat + rr.uniform(-jit, jit) + fr * ex / 2)
        blk(bm, c.x, c.y, z0, w - 0.08, depth + ex, h * rr.uniform(0.94, 1.03) - 0.05, rz=ang + rr.uniform(-0.02, 0.02), bev=bev, disp=disp)
        pos += w


def wall_rows(bm, rr, rows, ch, arms, depth, rlo, rhi, split_bm=None):
    for r in range(rows):
        b = split_bm if (split_bm is not None and r >= rows // 2) else bm
        z0, h = r * ch - (1.0 if r == 0 else 0.0), ch + (1.0 if r == 0 else 0.0)
        for (o, ang, a0, a1, fr, first_odd) in arms:
            f = rr.uniform(0.7, 1.4) if (r % 2 and first_odd) else None
            s0 = a0(r)
            course(b, o, ang, s0, a1, z0, h, depth, rr, 1.8, 3.4, fr, lat=-fr * r * 0.05, first=f)


def wall_caps(bm, rr, o, ang, s0, s1, z, depth, fr):
    course(bm, o, ang, s0, s1, z, 0.5, depth + 0.6, rr, 2.4, 3.6, fr, lat=0.0, jit=0.05, hdr=0.0, disp=0.04, bev=0.1)


def wall_straight(name, L, H, seed, depth=2.6, split=False):
    rr = random.Random(seed)
    rows = max(3, round(H / 1.25))
    ch = H / rows
    a, b = bmesh.new(), (bmesh.new() if split else None)
    arms = [(Vector((0, 0)), 0.0, lambda r: -L / 2, L / 2, -1, True)]
    wall_rows(a, rr, rows, ch, arms, depth, 0, 0, b)
    wall_caps(b or a, rr, Vector((0, 0)), 0.0, -L / 2, L / 2, H, depth, -1)
    for _ in range(2):  # fallen blocks at the foot
        blk(a, rr.uniform(-L / 2 + 1, L / 2 - 1), -depth / 2 - rr.uniform(0.9, 1.6), -0.8, rr.uniform(1.0, 1.7), rr.uniform(0.9, 1.4), rr.uniform(0.9, 1.4),
            rz=rr.uniform(0, 3), bev=0.18, disp=0.07)
    parts = [("Stone", a, "Bell_Stone", False)] + ([("Stone2", b, "Bell_Stone", False)] if b else [])
    done(name, parts)


def wall_corner(name, L, H, seed, depth=2.6):
    rr = random.Random(seed)
    rows = max(3, round(H / 1.25))
    ch = H / rows
    a = bmesh.new()
    o = Vector((0, 0))
    arms = [(o, 0.0, lambda r: -depth / 2 if r % 2 == 0 else depth / 2, L, -1, False),
            (o, math.pi / 2, lambda r: depth / 2 if r % 2 == 0 else -depth / 2, L, 1, False)]
    wall_rows(a, rr, rows, ch, arms, depth, 0, 0)
    wall_caps(a, rr, o, 0.0, -depth / 2 - 0.3, L, H, depth, -1)
    wall_caps(a, rr, o, math.pi / 2, depth / 2 + 0.3, L, H, depth, 1)
    done(name, [("Stone", a, "Bell_Stone", False)])


def stairs_run(bm, o, ang, n, tread, rise, tw, z_base, rr, last_cap=True, broken=False):
    d, nn = Vector((math.cos(ang), math.sin(ang))), Vector((-math.sin(ang), math.cos(ang)))
    for i in range(n):
        top = z_base + (i + 1) * rise
        c = o + d * (i * tread + tread / 2)
        blk(bm, c.x, c.y, -1.0, tw - 0.4, tread - 0.1, top + 1.0 - 0.55, rz=ang - math.pi / 2, bev=0.12, disp=0.04, cuts=0)
        cs = c - d * 0.12 + nn * rr.uniform(-0.12, 0.12)
        blk(bm, cs.x, cs.y, top - 0.55, tw + 0.4 + rr.uniform(-0.4, 0.2), tread + 0.3, 0.55, rz=ang - math.pi / 2 + rr.uniform(-0.02, 0.02),
            bev=0.14, jag=0.1, disp=0.05)
        for sx in (-1, 1):
            cc = c + nn * sx * (tw / 2 + 0.75)
            blk(bm, cc.x, cc.y, -1.0, 1.5, tread - 0.06, top + 2.45 + rr.uniform(-0.1, 0.1), rz=ang - math.pi / 2 + rr.uniform(-0.015, 0.015), bev=0.15, disp=0.06)
            if broken and i == n - 2 and sx == 1:
                continue
            blk(bm, cc.x, cc.y, top + 1.4 + rr.uniform(-0.03, 0.03), 1.9, tread + 0.12, 0.45, rz=ang - math.pi / 2, bev=0.1, disp=0.04)


def stair_straight(name, seed, n, tread, rise, tw, broken=False):
    rr = random.Random(seed)
    s = bmesh.new()
    stairs_run(s, Vector((0, 0)), math.pi / 2, n, tread, rise, tw, 0.0, rr, broken=broken)
    if broken:
        for _ in range(3):
            blk(s, rr.uniform(tw / 2 + 2, tw / 2 + 3.5), rr.uniform(0, n * tread), -0.8, rr.uniform(0.9, 1.6), rr.uniform(0.9, 1.4), rr.uniform(0.7, 1.2), rz=rr.uniform(0, 3), bev=0.2, disp=0.07)
    done(name, [("Stone", s, "Bell_Stone", False)])


def stair_turn(name, seed):
    rr = random.Random(seed)
    s = bmesh.new()
    n1, tread, rise, tw = 4, 1.7, 0.7, 7.0
    stairs_run(s, Vector((0, 0)), math.pi / 2, n1, tread, rise, tw, 0.0, rr)
    ls = tw + 1.6
    ly, ltop = n1 * tread + ls / 2, (n1 + 1) * rise
    blk(s, 0, ly, -1.0, ls, ls, ltop + 1.0, bev=0.18, disp=0.05)
    for yy in (ly + ls / 2 - 0.75,):  # +Y parapet
        course(s, Vector((0, yy)), 0.0, -ls / 2, ls / 2, ltop, 1.8, 1.5, rr, 1.8, 3.0, -1, hdr=0.0)
    course(s, Vector((-ls / 2 + 0.75, ly)), math.pi / 2, -ls / 2, ls / 2 - 0.1, ltop, 1.8, 1.5, rr, 1.8, 3.0, 1, hdr=0.0)
    stairs_run(s, Vector((ls / 2, ly)), 0.0, 4, tread, rise, tw, ltop, rr)
    done(name, [("Stone", s, "Bell_Stone", False)])


def paving(name, seed, kind):
    rr = random.Random(seed)
    s = bmesh.new()
    bx(s, 0, 0, -0.9, 7.98, 7.98, 0.95, bev=0.04)  # bed: gaps show it, flush ground
    g = 0.07
    if kind == "flag":
        edges, y = [-4.0], -4.0
        while y < 4.0 - 1.4:
            y = min(4.0, y + rr.uniform(1.6, 2.9))
            edges.append(y)
        edges[-1] = 4.0
        rows = list(zip(edges, edges[1:]))
        for (y0, y1) in rows:
            xs = [-4.0]
            while xs[-1] < 4.0 - 1.2:
                xs.append(min(4.0, xs[-1] + rr.uniform(1.4, 3.2)))
            xs[-1] = 4.0
            for x0, x1 in zip(xs, xs[1:]):
                blk(s, (x0 + x1) / 2, (y0 + y1) / 2, -0.55, x1 - x0 - 2 * g, y1 - y0 - 2 * g, 0.55 + 0.42 + rr.uniform(0, 0.1), rz=0.0, bev=0.11, disp=0.04,
                    jag=0.05)
    else:
        for r in range(8):
            y0, y1 = -4.0 + r, -3.0 + r
            xs = [-4.0] + ([-4.0 + 0.66] if r % 2 else []) + [-4.0 + 0.66 + 1.33 * k + (0 if r % 2 else -0.66) for k in range(1, 7)] + [4.0]
            xs = sorted(set(round(x, 3) for x in xs if -4.0 <= x <= 4.0))
            for x0, x1 in zip(xs, xs[1:]):
                blk(s, (x0 + x1) / 2, (y0 + y1) / 2, -0.55, x1 - x0 - 2 * g, y1 - y0 - 2 * g, 0.55 + 0.4 + rr.uniform(0, 0.12), bev=0.2, disp=0.035)
    done(name, [("Stone", s, "Bell_Stone", False)], centre=False)


def edging_kerb(name, seed):
    rr = random.Random(seed)
    s = bmesh.new()
    y = -4.0
    while y < 4.0 - 0.1:
        w = min(rr.uniform(2.2, 3.2), 4.0 - y)
        if 4.0 - y - w < 1.2:
            w = 4.0 - y
        blk(s, rr.uniform(-0.06, 0.06), y + w / 2, -0.8, rr.uniform(1.05, 1.3), w - 0.1, 0.8 + 0.85 + rr.uniform(-0.08, 0.1), bev=0.28, disp=0.045, jag=0.08)
        y += w
    done(name, [("Stone", s, "Bell_Stone", False)], centre=False)


def edging_cobble(name, seed):
    rr = random.Random(seed)
    s = bmesh.new()
    y = -3.6
    while y < 3.8:
        r = rr.uniform(0.6, 0.85)
        rock(s, (rr.uniform(-0.1, 0.1), y, 0.1), (r, r * rr.uniform(0.9, 1.1), r * rr.uniform(0.85, 1.1)), rr, sub=3, bottom=-0.6, lump=0.15, rough=0.06,
             rz=rr.uniform(0, 3), moss_bias=-0.5, mud_h=0.3, S=6.0)
        y += r * 1.75 + 0.05
    done(name, [("Stone", s, "Bell_Granite", True)], centre=False)


# ------------------------------------------------------------------------------------------ rocks
def boulder_d():
    rr = random.Random(511)
    a = bmesh.new()
    rock(a, (0, 0, 3.0), (4.0, 3.1, 3.8), rr, sub=5, planes=6, lump=0.2, rough=0.07, rz=0.8, moss_bias=0.05)
    rock(a, (3.6, 2.2, 3.7), (2.6, 2.0, 1.6), rr, sub=4, planes=4, lump=0.14, rough=0.06, rz=1.9, moss_bias=0.2)  # overhanging cap-stone
    rock(a, (-3.8, 2.4, 0.9), (2.0, 1.7, 1.6), rr, sub=4, planes=4, lump=0.16, rough=0.06, moss_bias=-0.2)
    rock(a, (3.0, -3.6, 0.5), (1.5, 1.2, 1.0), rr, sub=3, lump=0.2, moss_bias=-0.4)
    rock(a, (-2.2, -4.0, 0.3), (1.0, 0.9, 0.7), rr, sub=3, lump=0.2, moss_bias=-0.4)
    done("Boulder_Granite_D", [("Stone", a, "Bell_Granite", True)])


def boulder_split():
    seed, c0 = 523, (0, 0, 2.7)
    n = Vector((1.0, 0.14, 0.0)).normalized()
    a = bmesh.new()
    for sgn, rz in ((-1, -0.05), (1, 0.04)):
        rr = random.Random(seed)
        rock(a, (c0[0] + sgn * 0.95, c0[1] + (0.15 if sgn > 0 else 0), c0[2]), (4.6, 4.0, 3.5), rr, sub=5, planes=0, lump=0.2, rough=0.07, rz=rz,
             moss_bias=0.15, extra=[(n * -sgn, 0.12)])
    rr = random.Random(9)
    for p in ((0.2, -1.2, 0.6, 0.9), (-0.3, 1.4, 0.4, 0.7), (0.4, 3.2, 0.2, 1.1)):  # rubble in the cleft
        rock(a, (p[0], p[1], p[2] - 0.2), (p[3] * 0.8, p[3] * 0.7, p[3] * 0.6), rr, sub=3, planes=3, bottom=-0.4, lump=0.12, moss_bias=-0.5)
    rock(a, (-6.0, -2.8, 0.5), (1.8, 1.5, 1.2), rr, sub=3, lump=0.2, moss_bias=0.0)
    done("Boulder_Granite_Split", [("Stone", a, "Bell_Granite", False)])


def scree(name, seed, count, rmax, spread, sub_big):
    rr = random.Random(seed)
    a = bmesh.new()
    for i in range(count):
        ang, rad = rr.uniform(0, 6.283), spread * math.sqrt(rr.random())
        r = rr.uniform(0.22, rmax) * (1.5 if rr.random() < 0.08 else 1.0)
        c = (math.cos(ang) * rad * 1.15, math.sin(ang) * rad * 0.9, r * 0.1)
        rock(a, c, (r * rr.uniform(0.9, 1.5), r * rr.uniform(0.7, 1.2), r * rr.uniform(0.5, 0.85)), rr, sub=3 if (r > 0.7 and sub_big) else 2, planes=3,
             bottom=-0.25, lump=0.1, rough=0.05, rz=rr.uniform(0, 3.14), moss_bias=-1.0, mud_h=0.12, S=4.0)
    done(name, [("Stone", a, "Bell_Granite", False)])


def outcrop():
    rr = random.Random(541)
    a = bmesh.new()
    rock(a, (0, 0, 1.0), (8.0, 5.0, 2.8), rr, sub=5, planes=5, flat_top=2.6, lump=0.14, rough=0.06, moss_bias=0.7)
    rock(a, (-5.0, 2.0, 2.0), (3.6, 2.8, 2.4), rr, sub=4, planes=5, lump=0.14, rough=0.06, moss_bias=0.5)
    rock(a, (4.8, -1.8, 2.6), (3.0, 2.4, 2.2), rr, sub=4, planes=5, lump=0.14, rough=0.06, moss_bias=0.55, rz=0.7)
    rock(a, (1.0, 3.0, 3.2), (2.2, 1.8, 1.8), rr, sub=4, planes=4, lump=0.14, rough=0.06, moss_bias=0.6, rz=2.2)
    rock(a, (-8.2, -1.8, 0.4), (2.0, 1.7, 1.3), rr, sub=3, lump=0.2, moss_bias=0.3)
    rock(a, (7.6, 3.0, 0.4), (1.6, 1.4, 1.1), rr, sub=3, lump=0.2, moss_bias=0.3)
    done("Outcrop_Mossy", [("Stone", a, "Bell_Granite", False)])


def smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def cliff(name, kind, seed):
    rr = random.Random(seed)
    W, H, NX, NZ, D = 16.0, 13.0, 64, 52, 5.4
    o = rr.uniform(0, 50)

    def pn(x, z, k, lam, off=0.0):
        th, rho = 2 * math.pi * x / W, k / (2 * math.pi)
        return noise.noise(Vector((rho * math.cos(th) + o + off, rho * math.sin(th) + o * 0.7, z / lam + o * 1.3 + off)))

    def yf(x, z):
        if kind == "A":  # strata with overhanging ledges
            t = z / 2.3 + 0.5 * pn(x, z, 2, 8) + 0.15 * pn(x, z, 5, 3)
            f = t - math.floor(t)
            y = 1.4 + 1.5 * f ** 1.6 + 0.9 * pn(x, z, 3, 16) + 0.4 * pn(x, z, 9, 4)
            ck = abs(pn(x, z * 0.2, 7, 30))
            y += 0.5 * (1 - ck / 0.06) if ck < 0.06 else 0.0
        elif kind == "B":  # columnar, fissured
            c = pn(x, z, 6, 40)
            y = 0.8 + 1.6 * smooth(-0.25, 0.25, c) + 0.4 * pn(x, z, 4, 8) + 0.18 * pn(x, z, 12, 3)
            y += 0.35 * max(0.0, math.sin(z * math.pi / 3.3 + 2.0 * pn(x, z, 3, 10))) ** 6
        else:  # broken, overhung, talus skirt
            y = 1.6 - 2.4 * smooth(5.5, 9.0, z + 1.5 * pn(x, z, 2, 8)) + 0.7 * pn(x, z, 3, 10) + 0.3 * pn(x, z, 8, 3)
            y -= 1.2 * max(0.0, 1 - z / 2.5)
        return max(-1.4, min(3.6, y))

    def ztop(x):
        return H - 1.1 * max(0.0, pn(x, 0, 3, 10) + 0.3) - 0.5 * abs(pn(x, 0, 9, 4))

    bm = bmesh.new()
    F = []
    for i in range(NX + 1):
        x = -W / 2 + W * i / NX if i < NX else W / 2
        zt = ztop(x if i < NX else -W / 2)  # last column copies the first so both tile edges are identical
        col = []
        for j in range(NZ + 1):
            z = -1.0 + (zt + 1.0) * j / NZ
            col.append(bm.verts.new(Vector((x, yf(x if i < NX else -W / 2, z), z))))
        F.append(col)
    for j in range(NZ + 1):
        assert abs(F[0][j].co.y - F[NX][j].co.y) < 1e-6 and abs(F[0][j].co.z - F[NX][j].co.z) < 1e-6, "tile edge mismatch"
    B0 = [bm.verts.new(Vector((F[i][0].co.x, D, -1.0))) for i in range(NX + 1)]
    B1 = [bm.verts.new(Vector((F[i][NZ].co.x, D, F[i][NZ].co.z))) for i in range(NX + 1)]
    for i in range(NX):
        for j in range(NZ):
            bm.faces.new((F[i][j], F[i + 1][j], F[i + 1][j + 1], F[i][j + 1]))
        bm.faces.new((F[i][0], B0[i], B0[i + 1], F[i + 1][0]))
        bm.faces.new((F[i][NZ], F[i + 1][NZ], B1[i + 1], B1[i]))
        bm.faces.new((B0[i], B1[i], B1[i + 1], B0[i + 1]))
    bm.faces.new([F[0][j] for j in range(NZ + 1)] + [B1[0], B0[0]])
    bm.faces.new([F[NX][j] for j in range(NZ, -1, -1)] + [B0[NX], B1[NX]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    uvl = bm.loops.layers.uv.verify()
    mb = {"A": 0.0, "B": -0.3, "C": 0.3}[kind]
    for f in bm.faces:
        n, c = f.normal, f.calc_center_median()
        if (n.z * 2.2 - 0.8 + 0.8 * fbm(c * 0.2, 2) + mb) > 0:
            q = "moss"
        elif c.z < 1.4 + 0.8 * fbm(c * 0.3, 2):
            q = "mud"
        elif fbm(c * 0.12 + Vector((9, 4, 2)), 2) > 0.7:
            q = "lichen"
        else:
            q = "granite"
        qu, qv = QUAD[q]
        for l in f.loops:
            p = l.vert.co
            u, v = ((p.x + W / 2) / W, p.z / 16.0) if n.y < -0.25 else ((p.x + W / 2) / W, p.y / 16.0) if abs(n.z) > 0.6 else ((p.y + 2) / 16.0, p.z / 16.0)
            l[uvl].uv = ((qu + 0.01 + (u % 1.0 if u not in (0.0, 1.0) else u) * 0.98) * 0.5, (qv + 0.01 + (v % 1.0 if v not in (0.0, 1.0) else v) * 0.98) * 0.5)
    done(name, [("Stone", bm, "Bell_Granite", kind != "A")], centre=False)
    cy = sum(v.co.y for v in bm.verts) if False else 0


# ------------------------------------------------------------------------------------------ built extras
def board(bm, x, y, z, L, h, th, ang, point=True, uvs=4.0):
    uvl = _uvl(bm)
    pr = [(-L / 2, -h / 2), (L / 2 - h * 0.55, -h / 2), (L / 2, 0), (L / 2 - h * 0.55, h / 2), (-L / 2, h / 2)] if point else \
        [(-L / 2, -h / 2), (L / 2, -h / 2), (L / 2, h / 2), (-L / 2, h / 2)]
    c, s = math.cos(ang), math.sin(ang)
    W = lambda u, v, t: Vector((x + u * c - t * s, y + u * s + t * c, z + v))
    fr = [bm.verts.new(W(u, v, -th / 2)) for u, v in pr]
    bk = [bm.verts.new(W(u, v, th / 2)) for u, v in pr]
    k = len(pr)
    faces = [(bm.faces.new(fr[::-1]), pr[::-1]), (bm.faces.new(bk), pr)]
    for f, pp in faces:
        for l, (u, v) in zip(f.loops, pp):
            l[uvl].uv = (u / uvs, v / uvs)
    for i in range(k):
        j = (i + 1) % k
        f = bm.faces.new((fr[i], fr[j], bk[j], bk[i]))
        for l, uv in zip(f.loops, ((0, 0), (1, 0), (1, 0.1), (0, 0.1))):
            l[uvl].uv = (pr[i][0] / uvs + uv[0] * 0.1, uv[1])


BELL_PROF = [(0.45, 4.5), (0.75, 4.35), (1.2, 4.0), (1.65, 3.5), (2.0, 2.5), (2.4, 1.2), (2.85, 0.25), (3.05, 0.0), (2.6, 0.0), (2.2, 1.0), (1.8, 2.3),
             (1.4, 3.2), (0.7, 3.7), (0.3, 3.9)]


def bell(bm, x, y, z_hook, k):
    lathe(bm, [(r * k, z * k) for r, z in BELL_PROF], x=x, y=y, z0=z_hook - 4.5 * k, seg=14, turns=3, uvs=max(1.0, 4.0 * k))


def gate_side():
    t, s, b = bmesh.new(), bmesh.new(), bmesh.new()
    for sx in (-1, 1):
        blk(s, sx * 3.3, 0, -0.8, 2.0, 2.0, 1.3, bev=0.2, disp=0.06)
        cyl(t, sx * 3.3, 0, 0.5, 0.62, 0.5, 8.0, seg=10)
        cyl(b, sx * 3.3, 0, 8.4, 0.7, 0.7, 0.4, seg=10, uvs=4.0)
        cyl(b, sx * 3.3, 0, 0.9, 0.68, 0.68, 0.35, seg=10, uvs=4.0)
    bx(t, 0, 0, 6.3, 7.2, 0.5, 0.75, mode="timber", bev=0.08)
    loft_beam(t, 10.0, 1.3, 0.8, lambda x: 0.9 * max(0, (abs(x) - 3.3) / 1.7) ** 2, z0=8.0, m=12)
    bx(t, 0, 0, 7.15, 7.2, 0.35, 0.3, mode="timber", bev=0.04)
    tube(t, [Vector((0, 0, 6.3)), Vector((0, 0, 5.6))], [0.05, 0.05], sides=5)
    bell(b, 0, 0, 5.7, 0.3)
    da = math.atan2(-math.sin(1.15), -math.cos(1.15))  # one leaf standing open on its hinge post, swung out toward -Y
    for i in range(5):
        px, py = 3.3 - 0.35 + math.cos(da) * 0.55 * (i + 0.5), math.sin(da) * 0.55 * (i + 0.5)
        bx(t, px, py, 0.9, 0.52, 0.25, 4.6 - 0.12 * (i % 2), rz=da, mode="timber", bev=0.05, uvs=4.0)
    done("Bell_Timber_Gate_Side", [("Timber", t, "Bell_Timber", False), ("Stone", s, "Bell_Stone", False), ("Bronze", b, "Bell_Bronze", False)])


def fence_rail(name="Bell_Fence_Rail"):
    rr = random.Random(611)
    t = bmesh.new()
    for x in (-4.0, 0.0, 4.0):
        cyl(t, x, 0, -0.7, 0.3, 0.25, 4.3, seg=8)
        blk(t, x, 0, 3.55, 0.75, 0.75, 0.2, bev=0.06, cuts=0, disp=0, mode="timber", uvs=4.0)
    for zr in (2.7, 1.5):
        pts = [Vector((-4.0 + 8.0 * i / 8, rr.uniform(-0.05, 0.05) + 0.34, zr - 0.16 * math.sin(math.pi * i / 8) + rr.uniform(-0.03, 0.03))) for i in range(9)]
        tube(t, pts, [0.21] * 9, sides=6, uvs=6.0)
    bx(t, -2.0, -0.3, 0.5, 0.2, 0.2, 2.3, rz=0.0, mode="timber", bev=0.03, uvs=4.0)
    done(name, [("Timber", t, "Bell_Timber", False)], centre=False)


def fence_picket(name="Bell_Fence_Picket"):
    rr = random.Random(623)
    t = bmesh.new()
    for x in (-4.0, 0.0, 4.0):
        bx(t, x, 0.35, -0.7, 0.55, 0.55, 4.2, mode="timber", bev=0.08, uvs=4.0)
    for z in (0.8, 2.4):
        bx(t, 0, 0.1, z, 8.3, 0.22, 0.4, mode="timber", bev=0.04, uvs=4.0)
    x = -3.7
    while x < 3.8:
        h = rr.uniform(2.7, 3.3) if rr.random() > 0.08 else rr.uniform(1.2, 1.8)
        bx(t, x, -0.12, 0.0, 0.42, 0.14, h, rz=rr.uniform(-0.03, 0.03), mode="timber", bev=0.03, uvs=4.0)
        cyl(t, x, -0.12, h, 0.3, 0.02, 0.45, seg=4, uvs=4.0)
        x += rr.uniform(0.56, 0.66)
    done(name, [("Timber", t, "Bell_Timber", False)], centre=False)


def fence_post():
    t, s, b = bmesh.new(), bmesh.new(), bmesh.new()
    blk(s, 0, 0, -0.8, 2.3, 2.3, 1.2, bev=0.2, disp=0.06)
    blk(s, 0, 0, 0.3, 1.7, 1.7, 0.45, bev=0.12, disp=0.04)
    cyl(t, 0, 0, 0.6, 0.45, 0.38, 4.3, seg=8)
    bx(t, 0, 0, 4.9, 1.0, 1.0, 0.3, bev=0.08, mode="timber", uvs=4.0)
    cyl(t, 0, 0, 5.2, 0.5, 0.1, 0.55, seg=4, uvs=4.0)
    for z in (1.4, 4.2):
        cyl(b, 0, 0, z, 0.5, 0.5, 0.22, seg=8, uvs=4.0)
    tube(b, [Vector((0.46, 0, 3.8)), Vector((0.9, 0, 3.7)), Vector((1.0, 0, 3.2)), Vector((0.7, 0, 2.9))], [0.07] * 4, sides=5, uvs=2.0)
    bell(b, 0.7, 0, 2.95, 0.25)
    done("Bell_Fence_Post", [("Timber", t, "Bell_Timber", False), ("Stone", s, "Bell_Stone", False), ("Bronze", b, "Bell_Bronze", False)])


def shrine():
    rr = random.Random(701)
    s, t, rf, b = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    blk(s, 0, 0, -1.0, 9.0, 9.0, 1.7, bev=0.22, disp=0.07)
    blk(s, 0, 0, 0.7, 7.0, 7.0, 0.9, bev=0.2, disp=0.06)
    for k in range(3):  # front steps (-Y)
        blk(s, 0, -4.9 - k * 1.1 + 0.6, -1.0, 3.6 - k * 0.2, 1.1, 1.0 + (2 - k) * 0.55 + 0.7 - 0.7, bev=0.14, disp=0.05)
    for sx in (-1, 1):
        blk(s, sx * 2.9, -2.3, 1.6, 0.9, 0.9, 1.6, bev=0.14, disp=0.05)
        blk(s, sx * 2.9, -2.3, 3.2, 1.3, 1.3, 0.4, bev=0.1, disp=0.04)
    base = 1.6
    bx(t, 0, 0, base, 5.0, 4.0, 0.3, mode="timber", bev=0.05)
    for sx, sy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        cyl(t, sx * 2.35, sy * 1.85, base + 0.3, 0.3, 0.27, 3.6, seg=8)
    bx(t, 0, 1.85, base + 0.3, 4.4, 0.25, 3.6, mode="timber", bev=0.04)  # back wall
    for sx in (-1, 1):
        bx(t, sx * 2.35, 0, base + 0.3, 0.25, 3.7, 3.6, mode="timber", bev=0.04)
    for z in (base + 1.0, base + 3.1):  # rail beams, front
        bx(t, 0, -1.85, z, 4.8, 0.3, 0.35, mode="timber", bev=0.04)
    bx(t, 0, -1.75, base + 0.3, 3.0, 0.2, 0.9, mode="timber", bev=0.03)
    bx(t, 0, 0.3, base + 0.3, 1.3, 1.1, 1.2, bev=0.1, uvs=4.0)  # offering plinth
    blk(s, 0, 0.3, base + 0.3, 1.1, 0.9, 1.1, bev=0.16, disp=0.04)
    R = dict(hw=3.9, z0=base + 3.95, h=2.5, flat=0.25, p=1.5, curl=0.9, thick=0.55)
    roof(rf, R, n=12, uvs=8.0)
    cyl(b, 0, 0, base + 3.95 + 2.45, 0.28, 0.12, 0.9, seg=8, uvs=2.0)
    cyl(b, 0, 0, base + 3.95 + 2.2, 0.38, 0.38, 0.2, seg=8, uvs=2.0)
    bell(b, 0, -1.6, base + 3.55, 0.28)
    tube(b, [Vector((0, -1.6, base + 3.55)), Vector((0, -1.6, base + 3.95))], [0.05] * 2, sides=5)
    done("Bell_Shrine_Roadside", [("Stone", s, "Bell_Stone", False), ("Timber", t, "Bell_Timber", False), ("Roof", rf, "Bell_Roof", False),
                                  ("Bronze", b, "Bell_Bronze", False)])


def grave(kind):
    rr = random.Random({"A": 801, "B": 811, "C": 821}[kind])
    s, t, b, g = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    rock(g, (0, 0, -0.1), (2.6, 2.0, 0.55), rr, sub=3, bottom=-0.6, lump=0.12, rough=0.05, moss_bias=0.8, mud_h=0.1, S=6.0)
    if kind == "A":  # tall stele, rounded shoulders, relief bands, bell on a timber bracket
        blk(s, 0, 0, 0.3, 1.9, 0.7, 4.4, bev=0.2, disp=0.05, jag=0.06)
        blk(s, 0, 0, 4.5, 1.5, 0.62, 0.7, bev=0.28, disp=0.04)
        blk(s, 0, 0, 5.1, 1.0, 0.55, 0.45, bev=0.2, disp=0.03)
        for z in (2.2, 2.9, 3.6):
            blk(s, 0, -0.38, z, 1.3, 0.1, 0.12, bev=0.03, cuts=0, disp=0)
        bx(t, 1.1, -0.2, 4.3, 1.5, 0.22, 0.2, mode="timber", bev=0.04, uvs=4.0)
        bx(t, 0.45, -0.2, 3.9, 0.2, 0.2, 0.7, mode="timber", bev=0.03, uvs=4.0)
        tube(b, [Vector((1.65, -0.2, 4.3)), Vector((1.65, -0.2, 3.9))], [0.04] * 2, sides=5)
        bell(b, 1.65, -0.2, 3.95, 0.22)
        tube(b, [Vector((0.0, -0.55, 4.0)), Vector((0.0, -0.55, 3.3))], [0.05] * 2, sides=5)
    elif kind == "B":  # low rounded stone with a bell set on a bronze ring
        rock(s, (0, 0, 1.0), (1.7, 1.3, 1.5), rr, sub=4, planes=2, bottom=-0.3, lump=0.12, rough=0.04, moss_bias=0.2, mud_h=0.4, S=6.0)
        blk(s, 1.9, 0.9, -0.2, 0.9, 0.7, 0.55, bev=0.14, disp=0.04, rz=0.4)
        cyl(b, 0, 0, 2.3, 0.75, 0.75, 0.15, seg=12, uvs=2.0)
        bell(b, 0, 0, 3.15, 0.3)
        tube(b, [Vector((0, 0, 3.15)), Vector((0, 0, 3.5))], [0.06] * 2, sides=5)
        cyl(b, 0, 0, 3.5, 0.2, 0.2, 0.08, seg=8, uvs=2.0)
    else:  # three-tier cairn marker, bell chain from a bent hook
        for z0, w, h in ((0.2, 2.5, 0.8), (1.0, 1.9, 0.8), (1.8, 1.3, 0.9)):
            blk(s, rr.uniform(-0.1, 0.1), rr.uniform(-0.1, 0.1), z0, w, w * 0.8, h, rz=rr.uniform(-0.2, 0.2), bev=0.22, disp=0.05)
        blk(s, 0, 0, 2.7, 0.8, 0.6, 2.2, bev=0.14, disp=0.04, jag=0.15)
        tube(b, [Vector((0, 0, 4.7)), Vector((0.2, 0, 5.3)), Vector((0.9, 0, 5.4)), Vector((1.3, 0, 5.0))], [0.07] * 4, sides=5, uvs=2.0)
        tube(b, [Vector((1.3, 0, 5.0)), Vector((1.3, 0, 4.5))], [0.04] * 2, sides=5)
        bell(b, 1.3, 0, 4.55, 0.24)
    done(f"Bell_Grave_{kind}", [("Stone", s, "Bell_Stone", False), ("Mound", g, "Bell_Granite", True), ("Bronze", b, "Bell_Bronze", False)]
         + ([("Timber", t, "Bell_Timber", False)] if len(t.verts) else []))


def prayer_flags(name, L, sag, seed):
    rr = random.Random(seed)
    t, s, c = bmesh.new(), bmesh.new(), bmesh.new()
    PH = 11.0
    for sx in (-1, 1):
        x = sx * L / 2
        blk(s, x, 0, -0.8, 2.2, 2.2, 1.3, bev=0.2, disp=0.06)
        cyl(t, x, 0, 0.3, 0.42, 0.28, PH, seg=8)
        cyl(t, x, 0, PH + 0.3, 0.2, 0.05, 0.9, seg=6, uvs=4.0)
    P = lambda x: Vector((x, 0, PH - sag * (1 - (2 * x / L) ** 2)))
    tube(t, [P(-L / 2 + L * i / 20) for i in range(21)], [0.07] * 21, sides=5, uvs=4.0)
    uvl = _uvl(c)
    x, k = -L / 2 + 1.0, rr.randrange(5)
    while x < L / 2 - 1.6:
        fw, fh = 1.15, rr.uniform(1.25, 1.55)
        ph = rr.uniform(0, 6.28)
        grid = [[(x + fw * i / 4, 0.18 * math.sin(i * 1.4 + ph) * (j / 3), P(x + fw * i / 4).z - 0.07 - fh * j / 3 + 0.05 * math.sin(i + ph) * j / 3) for i in range(5)]
                for j in range(4)]
        u0 = k / 5 + 0.02
        for side in (0, 1):
            vs = [[bm_v for bm_v in (c.verts.new(Vector(p)) for p in row)] for row in grid]
            for j in range(3):
                for i in range(4):
                    q = (vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]) if side == 0 else (vs[j][i], vs[j + 1][i], vs[j + 1][i + 1], vs[j][i + 1])
                    f = c.faces.new(q)
                    for l in f.loops:
                        ji = [(jj, ii) for jj in range(4) for ii in range(5) if vs[jj][ii] is l.vert][0]
                        l[uvl].uv = (u0 + 0.16 * ji[1] / 4, 0.1 + 0.8 * (1 - ji[0] / 3))
        x += fw + rr.uniform(0.2, 0.32)
        k = (k + 1) % 5
    done(name, [("Timber", t, "Bell_Timber", False), ("Stone", s, "Bell_Stone", False), ("Cloth", c, "Bell_Flag", False)])


def signpost_a():
    rr = random.Random(901)
    t, s, b = bmesh.new(), bmesh.new(), bmesh.new()
    blk(s, 0, 0, -0.8, 2.4, 2.4, 1.3, bev=0.2, disp=0.06)
    cyl(t, 0, 0, 0.3, 0.45, 0.36, 7.6, seg=7)
    cyl(t, 0, 0, 7.9, 0.38, 0.05, 0.7, seg=7, uvs=4.0)
    board(t, 1.45, -0.45, 6.6, 4.2, 1.15, 0.24, 0.12 + 0.0)
    board(t, -1.2, -0.45, 5.2, 3.6, 1.0, 0.22, math.pi - 0.1)
    board(t, 1.0, 0.45, 3.9, 2.8, 0.9, 0.22, -0.2, point=False)
    for z, w in ((6.6, 0.95), (5.2, 0.9), (3.9, 0.85)):
        cyl(b, 0, 0, z - 0.1, w * 0.5, w * 0.5, 0.2, seg=8, uvs=2.0)
    for dx, z in ((2.4, 6.65), (-2.4, 5.2), (1.9, 3.95)):
        cyl(b, dx * 0.9, -0.62 if z != 3.95 else 0.57, z, 0.08, 0.08, 0.1, seg=6, uvs=1.0)
    done("Bell_Signpost_A", [("Timber", t, "Bell_Timber", False), ("Stone", s, "Bell_Stone", False), ("Bronze", b, "Bell_Bronze", False)])


def signpost_b():
    rr = random.Random(911)
    t, s, b = bmesh.new(), bmesh.new(), bmesh.new()
    blk(s, 0, 0, -0.8, 2.2, 2.0, 1.0, bev=0.18, disp=0.06)
    blk(s, 0, 0, 0.2, 1.6, 1.4, 3.2, bev=0.2, disp=0.05, jag=0.08)
    blk(s, 0, 0, 3.4, 1.9, 1.7, 0.45, bev=0.14, disp=0.04)
    blk(s, 0, 0, 3.85, 1.2, 1.1, 0.8, bev=0.28, disp=0.04)
    bx(t, 1.3, -0.95, 2.4, 3.2, 0.2, 0.95, mode="timber", bev=0.04, uvs=4.0)
    board(t, 1.55, -1.1, 2.9, 3.0, 0.95, 0.22, 0.0)
    for z in (2.4, 3.1):
        bx(b, 0.0, -0.95, z, 1.8, 0.14, 0.12, bev=0.02, uvs=2.0)
    tube(b, [Vector((-0.9, -0.95, 3.2)), Vector((-1.4, -1.4, 3.5)), Vector((-1.5, -1.7, 3.0))], [0.05] * 3, sides=5, uvs=2.0)
    bx(t, -1.5, -1.7, 1.9, 0.5, 0.5, 0.8, mode="timber", bev=0.06, uvs=2.0)
    bell(b, 0.9, -1.15, 2.25, 0.2)
    done("Bell_Signpost_B", [("Timber", t, "Bell_Timber", False), ("Stone", s, "Bell_Stone", False), ("Bronze", b, "Bell_Bronze", False)])


def well():
    rr = random.Random(931)
    s, t, rf, b = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    R, N = 2.95, 16
    for c_ in range(4):
        for k in range(N):
            th = 2 * math.pi * k / N + (math.pi / N if c_ % 2 else 0)
            w = 2 * math.pi * R / N
            blk(s, math.cos(th) * R, math.sin(th) * R, -1.0 + c_ * 1.0 if c_ else -1.0, w - 0.08, 1.35, (2.0 if c_ == 0 else 1.0) - 0.04, rz=th + math.pi / 2 + rr.uniform(-0.03, 0.03),
                bev=0.14, disp=0.055)
    for sx in (-1, 1):
        cyl(t, sx * 4.2, 0, -0.3, 0.38, 0.32, 7.3, seg=8)
        blk(s, sx * 4.2, 0, -0.9, 1.4, 1.4, 0.8, bev=0.14, disp=0.04)
    bx(t, 0, 0, 7.0, 9.4, 0.7, 0.6, mode="timber", bev=0.06)
    tube(t, [Vector((-4.2, 0, 5.2)), Vector((0, 0, 5.15)), Vector((4.2, 0, 5.2))], [0.3] * 3, sides=8, uvs=4.0)
    for sx in (-1, 1):
        bx(t, sx * 4.2, 0, 6.3, 0.5, 0.5, 0.9, mode="timber", bev=0.05, rz=0.0)
    tube(t, [Vector((0.8, 0, 5.1)), Vector((0.8, 0, 3.4))], [0.05] * 2, sides=5, uvs=2.0)
    cyl(t, 0.8, 0, 2.7, 0.55, 0.48, 0.75, seg=10, uvs=3.0)
    for z in (2.85, 3.3):
        cyl(b, 0.8, 0, z, 0.58, 0.58, 0.1, seg=10, uvs=2.0)
    tube(b, [Vector((4.2, 0, 5.2)), Vector((4.9, 0.4, 5.2)), Vector((4.9, 1.0, 5.2))], [0.07] * 3, sides=5, uvs=2.0)
    cyl(b, 4.9, 1.05, 4.9, 0.14, 0.14, 0.6, seg=6, uvs=1.0)
    R2 = dict(hw=3.6, z0=7.6, h=3.2, flat=0.15, p=1.4, curl=0.45, thick=0.5)
    roof(rf, R2, n=12, uvs=8.0)
    done("Bell_Well", [("Stone", s, "Bell_Stone", False), ("Timber", t, "Bell_Timber", False), ("Roof", rf, "Bell_Roof", False), ("Bronze", b, "Bell_Bronze", False)])


# ------------------------------------------------------------------------------------------ GLB read + packing (stdlib part reused from make_upload_pack)
_pk = (HERE.parent / "make_upload_pack.py").read_text().split("def pack(")[0]
PK = {"__name__": "pack_lib", "__file__": str(HERE.parent / "make_upload_pack.py")}
exec(compile(_pk, "make_upload_pack.py", "exec"), PK)


def figure():
    bm = bmesh.new()
    for x, y, z0, sx, sy, sz in ((-0.32, 0, 0, 0.55, 0.55, 2.5), (0.32, 0, 0, 0.55, 0.55, 2.5), (0, 0, 2.5, 1.5, 0.8, 1.9),
                                 (-1.0, 0, 2.6, 0.5, 0.5, 1.7), (1.0, 0, 2.6, 0.5, 0.5, 1.7)):
        bmesh.ops.create_cube(bm, size=1.0)
        new = bm.verts[-8:]
        for v in new:
            v.co = Vector((v.co.x * sx + x, v.co.y * sy + y, v.co.z * sz + z0 + sz / 2))
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.45, matrix=Matrix.Translation((0, 0, 5.05)))
    me = bpy.data.meshes.new("fig")
    bm.to_mesh(me)
    bm.free()
    m = bpy.data.materials.new("Fig")
    m.use_nodes = True
    next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.75, 0.2, 0.15, 1)
    me.materials.append(m)
    o = bpy.data.objects.new("Figure_5p5", me)
    bpy.context.scene.collection.objects.link(o)
    return o


def main():
    (OUT / "maps").mkdir(parents=True, exist_ok=True)
    CAPD.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    stone_mat(), timber_mat(), bronze_mat(), roof_mat(), granite_mat(), flag_mat()
    jobs = [
        ("Bell_Stair_Straight_A", lambda: stair_straight("Bell_Stair_Straight_A", 101, 8, 1.7, 0.72, 7.0)),
        ("Bell_Stair_Straight_B", lambda: stair_straight("Bell_Stair_Straight_B", 102, 6, 2.1, 0.9, 9.0, broken=True)),
        ("Bell_Stair_Turn", lambda: stair_turn("Bell_Stair_Turn", 103)),
        ("Bell_Retain_Wall_Short", lambda: wall_straight("Bell_Retain_Wall_Short", 12.0, 6.0, 111)),
        ("Bell_Retain_Wall_Long", lambda: wall_straight("Bell_Retain_Wall_Long", 24.0, 6.5, 112, split=True)),
        ("Bell_Retain_Wall_Corner", lambda: wall_corner("Bell_Retain_Wall_Corner", 9.0, 6.0, 113)),
        ("Bell_Paving_Flag", lambda: paving("Bell_Paving_Flag", 121, "flag")),
        ("Bell_Paving_Sett", lambda: paving("Bell_Paving_Sett", 122, "sett")),
        ("Bell_Edging_Kerb", lambda: edging_kerb("Bell_Edging_Kerb", 131)),
        ("Bell_Edging_Cobble", lambda: edging_cobble("Bell_Edging_Cobble", 132)),
        ("Boulder_Granite_D", boulder_d),
        ("Boulder_Granite_Split", boulder_split),
        ("Scree_Patch_A", lambda: scree("Scree_Patch_A", 141, 95, 0.7, 6.5, False)),
        ("Scree_Patch_B", lambda: scree("Scree_Patch_B", 142, 55, 1.2, 7.0, True)),
        ("Outcrop_Mossy", outcrop),
        ("Cliff_Face_A", lambda: cliff("Cliff_Face_A", "A", 151)),
        ("Cliff_Face_B", lambda: cliff("Cliff_Face_B", "B", 152)),
        ("Cliff_Face_C", lambda: cliff("Cliff_Face_C", "C", 153)),
        ("Bell_Timber_Gate_Side", gate_side),
        ("Bell_Fence_Rail", fence_rail),
        ("Bell_Fence_Picket", fence_picket),
        ("Bell_Fence_Post", fence_post),
        ("Bell_Shrine_Roadside", shrine),
        ("Bell_Grave_A", lambda: grave("A")),
        ("Bell_Grave_B", lambda: grave("B")),
        ("Bell_Grave_C", lambda: grave("C")),
        ("Bell_Prayer_Flags_Short", lambda: prayer_flags("Bell_Prayer_Flags_Short", 10.0, 1.2, 161)),
        ("Bell_Prayer_Flags_Long", lambda: prayer_flags("Bell_Prayer_Flags_Long", 22.0, 2.4, 162)),
        ("Bell_Signpost_A", signpost_a),
        ("Bell_Signpost_B", signpost_b),
        ("Bell_Well", well),
    ]
    failed = []
    for name, fn in jobs:
        try:
            fn()
        except Exception as e:  # keep the lane going; failures are reported in the note and the deliverable
            import traceback
            traceback.print_exc()
            failed.append(name)
            note(f"- {name}: FAILED {type(e).__name__}: {e}")
            continue
        subs = manifest["pieces"][name]["sub_meshes"]
        note(f"- {name}: built, sub-meshes {json.dumps({k.split('__')[1]: v for k, v in subs.items()})}")
    for name, objs in PIECES.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.export_scene.gltf(filepath=str(OUT / f"{name}.glb"), export_format="GLB", use_selection=True, export_apply=False)
        lo, hi = bbox(objs)
        info = manifest["pieces"][name]
        info.update(file=f"{name}.glb", size_studs_xyz=[round(hi.x - lo.x, 1), round(hi.y - lo.y, 1), round(hi.z - lo.z, 1)],
                    materials=sorted({m.name for o in objs for m in o.data.materials}), tris_total=sum(info["sub_meshes"].values()),
                    file_bytes=(OUT / f"{name}.glb").stat().st_size)
    manifest["textures"] = {i.name: list(i.size) for i in bpy.data.images if i.name.startswith("Bell_")}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))
    pack()
    if not NORENDER:
        renders()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "bellwood_built_a.blend"), compress=True)
    print("BB_OK", len(PIECES), "pieces; failed:", failed, flush=True)


def pack():
    UP.mkdir(parents=True, exist_ok=True)
    (UP / "maps").mkdir(exist_ok=True)
    pieces, used, problems = {}, set(), []
    for name, meta in manifest["pieces"].items():
        src = OUT / meta["file"]
        g, subs, lo, hi = PK["inspect"](src)
        for sub, info in subs.items():
            if info["tris"] >= TRI_CAP:
                problems.append(f"{sub} {info['tris']} >= cap")
            if meta["sub_meshes"].get(sub) != info["tris"]:
                problems.append(f"{sub} manifest {meta['sub_meshes'].get(sub)} vs glb {info['tris']}")
        shutil.copy2(src, UP / meta["file"])
        for i in subs.values():
            used.add(i["material"])
        size = [round(hi[i] - lo[i], 2) for i in range(3)]
        pieces[name] = {"name": name, "file": meta["file"], "sub_meshes": {k: v["tris"] for k, v in subs.items()},
                        "sub_mesh_materials": {k: v["material"] for k, v in subs.items()}, "tris_total": sum(v["tris"] for v in subs.values()),
                        "file_bytes": src.stat().st_size, "size_studs_xyz_roblox": size,
                        "pivot": "base centre at origin (Y up); " + json.dumps({"min_y": round(lo[1], 3), "centre_x": round((lo[0] + hi[0]) / 2, 3), "centre_z": round((lo[2] + hi[2]) / 2, 3)}),
                        "studio_target": f"ServerStorage/BellwoodKit/{name}", "registry_file": "assets/BELLWOOD_KIT_UPLOADED.json"}
    mats = {}
    for m in sorted(used):
        maps = {}
        for slot, suf in (("ColorMap", "Color"), ("NormalMap", "Normal"), ("RoughnessMap", "Roughness"), ("MetalnessMap", "Metal")):
            f = OUT / "maps" / f"{m}_{suf}.png"
            if f.exists():
                shutil.copy2(f, UP / "maps" / f.name)
                maps[slot] = {"file": "maps/" + f.name, "size": list(bpy.data.images[f"{m}_{suf}"].size)}
        mats[m] = maps
    for p in pieces.values():
        p["maps_per_material"] = {m: mats[m] for m in sorted(set(p["sub_mesh_materials"].values()))}
    (UP / "upload_manifest.json").write_text(json.dumps({
        "format": "GLB (glTF 2.0, textures embedded; same maps also loose in maps/)", "units": "1 stud = 1 unit, Y up after import",
        "tri_cap_per_sub_mesh": TRI_CAP, "registry_file": "assets/BELLWOOD_KIT_UPLOADED.json", "no_ids_yet": True,
        "import": "Studio 3D Importer (Import As Model, Scale 1, one MeshPart per sub-mesh named Piece__Sub); same steps as assets/source/overworld/upload/slice/UPLOAD.md. "
                  "Bell_Granite is a 1024 atlas, never tiled: leave StudsPerTile default. Bell_Flag cloth pieces are real two-sided geometry. Cliff_Face_A/B/C tile along X every 16 studs (identical edge profile).",
        "registry_shape": {"pieces": {"<Piece>": {"<Piece>__<Sub>": {"MeshId": "rbxassetid://...", "ColorMap": "", "NormalMap": "", "RoughnessMap": "", "MetalnessMap": ""}}}},
        "pieces": pieces, "materials": mats, "manifest_check": "problems: " + (", ".join(problems) if problems else "none")}, indent=2) + "\n")
    print("PACK", len(pieces), "problems:", problems or "none", flush=True)


def renders():
    sc, cam, ground = setup_render()
    fig = figure()
    allobjs = [o for objs in PIECES.values() for o in objs]
    for name, objs in PIECES.items():
        for o in allobjs:
            o.hide_render = o not in objs
        lo, hi = bbox(objs)
        fig.location = Vector((hi.x + 2.2, (lo.y + hi.y) / 2, 0))
        W, Hh = hi.x - lo.x + 4.4, max(hi.z, 5.5)
        cx = (lo.x + hi.x + 4.4) / 2
        cy = (lo.y + hi.y) / 2
        dist = max(1.25 * W, Hh * 1.7, 14.0)
        ground.scale, ground.location = (200, 200, 1), Vector((0, 0, 0))
        az = math.radians(32)  # 3/4 view so run direction and relief read
        shoot(sc, cam, Vector((cx + math.sin(az) * dist, cy - math.cos(az) * dist, 5.0)), Vector((cx, cy, min(Hh / 2, 6.0))), 35, CAPD / f"eye_{name}.png")
    # tiling checks: cliffs side by side, paving 2x2 with kerb, stair + walls
    for o in allobjs:
        o.hide_render = True
    for nm, offs in (("Cliff_Face_A", (-16, 0)), ("Cliff_Face_B", (0, 0)), ("Cliff_Face_C", (16, 0)), ("Cliff_Face_A", (32, 0)), ("Cliff_Face_B", (-32, 0))):
        put(nm, offs[0], offs[1] + 2.0, 0)
    fig.location = Vector((-3, -8, 0))
    shoot(sc, cam, Vector((0, -46, 5)), Vector((0, 0, 6.5)), 35, CAPD / "tiling_cliffs.png")
    clear_put()
    for ix in (-1, 0):
        for iy in (-1, 0):
            put("Bell_Paving_Flag" if (ix + iy) % 2 else "Bell_Paving_Sett", ix * 8 + 4, iy * 8 + 4 + 6, 0)
    for iy in (-1, 0):
        put("Bell_Edging_Kerb", 8.7, iy * 8 + 4 + 6, 0)
    fig.location = Vector((-10, -2, 0))
    shoot(sc, cam, Vector((-4, -26, 5)), Vector((0, 8, 1.5)), 35, CAPD / "tiling_paving_edging.png")
    clear_put()
    put("Bell_Retain_Wall_Long", 0, 6, 0)
    put("Bell_Retain_Wall_Corner", 16.5, 6 + 1.3, 0)
    put("Bell_Stair_Turn", -22, 0, 0)
    put("Bell_Retain_Wall_Short", -4, -8, 0, math.pi)
    fig.location = Vector((8, -14, 0))
    shoot(sc, cam, Vector((0, -34, 5)), Vector((-4, 4, 3)), 35, CAPD / "assembly_walls_stairs.png")
    clear_put()
    for o in allobjs:
        o.hide_render = False


main()
