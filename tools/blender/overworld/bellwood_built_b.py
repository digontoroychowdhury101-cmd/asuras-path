"""Bellwood built B kit (lane M3): Bell_Tower_Ruined, Hermit_Hut, rope bridge, falls alcove, carts, crates, pots, lanterns.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b -P tools/blender/overworld/bellwood_built_b.py
  (optional: -- <out_dir> <captures_dir> <upload_dir>; env ONLY=Name1,Name2 builds a subset)

Reuses slice_kit.py's materials/geometry helpers by exec (same stone/timber/bronze language). 1 BU = 1 stud, base-centre pivot,
every sub-mesh asserted < 18000 tris, one GLB per piece, maps/, manifest.json, upload pack, per-piece iso + player-height renders
(camera 5 studs, 5.5-stud figure beside the piece). Original procedural work; no uploads, no credits.
"""
import json
import math
import os
import random
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
_src = (ROOT / "tools/blender/overworld/slice_kit.py").read_text(encoding="utf-8")
_head = _src.split("\ndef stair():")[0]
_rocks = _src[_src.index("QUAD = {"):_src.index("def boulders():")]
_rend = _src[_src.index("def bbox(objs):"):_src.index("V = []")] + _src[_src.index("def shoot("):_src.index("def main():")]
_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
exec(_head, globals())
exec(_rocks, globals())
exec(_rend, globals())
OUT = Path(_args[0] if _args else ROOT / "assets/source/overworld/bellwood_built_b").resolve()
CAP = Path(_args[1] if len(_args) > 1 else ROOT / "outputs/claude-open-world-2026-11-14/captures/kit/bellwood_built_b").resolve()
UPL = Path(_args[2] if len(_args) > 2 else ROOT / "assets/source/overworld/upload/bellwood_built_b").resolve()
ONLY = set(os.environ["ONLY"].split(",")) if os.environ.get("ONLY") else None
manifest = {"kit": "bellwood_built_b", "build": "blender -b -P tools/blender/overworld/bellwood_built_b.py", "tri_cap_per_sub_mesh": TRI_CAP,
            "units": "studs (1 BU = 1 stud)", "pivot": "base centre at origin, z=0", "pieces": {}}


# ------------------------------------------------------------------------------------------ extra materials
def clay_mat():
    n = 256
    f1, f2 = field(n, 1.2, 111), field(n, 0.7, 112)
    ring = np.sin(np.linspace(0, 2 * np.pi * 24, n))[:, None] * np.ones((1, n))  # throwing rings along v
    soot = np.clip((field(n, 1.6, 113) - 0.4) * 0.8, 0, 0.6)[..., None]
    col = np.array([0.46, 0.27, 0.16]) * (0.85 + 0.1 * f1[..., None] + 0.04 * ring[..., None])
    col = col * (1 - soot) + np.array([0.12, 0.09, 0.07]) * soot
    h = 0.5 + 0.05 * ring + 0.03 * f2
    return material("Bell_Clay", save("Bell_Clay_Color", col), save("Bell_Clay_Roughness", np.clip(0.55 + 0.1 * f1, 0, 1), True),
                    save("Bell_Clay_Normal", nmap(h, 3.0), True))


def rope_mat():
    n = 256
    y, x = np.mgrid[0:n, 0:n] / n
    twist = np.sin(2 * np.pi * (4 * x + 3 * y))
    fib = field(n, 0.8, 121, 6.0)
    col = np.array([0.46, 0.38, 0.24])[None, None] * (0.8 + 0.18 * twist[..., None] + 0.08 * fib[..., None])
    h = 0.5 + 0.3 * twist + 0.05 * fib
    return material("Bell_Rope", save("Bell_Rope_Color", col), save("Bell_Rope_Roughness", np.full((n, n), 0.9), True),
                    save("Bell_Rope_Normal", nmap(h, 5.0), True))


# ------------------------------------------------------------------------------------------ helpers
def sub(P, name, bm, mat, smooth=False):
    if not bm.faces:
        bm.free()
        return
    obj(P, name, bm, MATS[mat], smooth=smooth)


def xf(bm, builder, M):
    """Build with `builder`, then transform only the newly created verts by 4x4 M."""
    before = set(bm.verts)
    builder()
    bmesh.ops.transform(bm, matrix=M, verts=[v for v in bm.verts if v not in before])


def about(p, ang, axis="Z"):
    p = Vector(p)
    return Matrix.Translation(p) @ Matrix.Rotation(ang, 4, axis) @ Matrix.Translation(-p)


def wall(bm, axis, c, lo, hi, z0, z1, th, opens, hf, rr, ch=(1.7, 2.3), cw=(2.6, 4.4), bev=0.14):
    """Coursed block wall along `axis` ('x' or 'y') at cross-coordinate c, from lo to hi. opens = (a, b, za, zb) holes in
    (along, z); hf(along) -> max height (ruin profile): blocks above are dropped, the cut block is shortened and chipped."""
    z, row = z0, 0
    while z < z1 - 0.05:
        h = min(rr.uniform(*ch), z1 - z)
        if z1 - (z + h) < 1.0:
            h = z1 - z
        zt = z + h
        segs, x = [], lo - (rr.uniform(0, 2.8) if row % 2 else 0)
        while x < hi - 0.2:
            w = rr.uniform(*cw)
            a, b = max(x, lo), min(x + w, hi)
            x += w
            if b - a > 0.45:
                segs.append((a, b))
        for o in opens:
            if z < o[3] and zt > o[2]:
                new = []
                for s, e in segs:
                    if e <= o[0] or s >= o[1]:
                        new.append((s, e))
                    else:
                        if s < o[0]:
                            new.append((s, o[0]))
                        if e > o[1]:
                            new.append((o[1], e))
                segs = new
        for a, b in segs:
            if b - a < 0.45:
                continue
            top = hf((a + b) / 2) if hf else 1e9
            if z >= top - 0.3:
                continue
            hh, jag = h, 0.0
            if zt > top:
                hh, jag = top - z, min(0.7, 0.4 * (top - z))
            gw, jx = b - a - 0.06, rr.uniform(-0.05, 0.05)
            m = (a + b) / 2
            if axis == "x":
                bx(bm, m, c + jx, z, gw, th, hh - 0.04, bev=bev, rz=rr.uniform(-rz_j, rz_j), jag=jag)
            else:
                bx(bm, c + jx, m, z, th, gw, hh - 0.04, bev=bev, rz=rr.uniform(-rz_j, rz_j), jag=jag)
        z, row = zt, row + 1


rz_j = 0.012


def box_walls(bm, H, th, z0, z1, rr, opens=None, hf=None, **kw):
    opens, hf = opens or {}, hf or {}
    c = H - th / 2
    for side in "SNWE":
        if side in "SN":
            wall(bm, "x", -c if side == "S" else c, -H, H, z0, z1, th, opens.get(side, ()), hf.get(side), rr, **kw)
        else:
            wall(bm, "y", -c if side == "W" else c, -(H - th), H - th, z0, z1, th, opens.get(side, ()), hf.get(side), rr, **kw)


def pier(bm, x, y, z0, top, w, rr, jag=0.9):
    z = z0
    while z < top - 0.05:
        h = min(rr.uniform(2.0, 2.7), top - z)
        if top - z - h < 1.0:
            h = top - z
        last = z + h >= top - 0.01
        bx(bm, x + rr.uniform(-0.06, 0.06), y + rr.uniform(-0.06, 0.06), z, w, w, h - 0.03, bev=0.18, rz=rr.uniform(-0.03, 0.03), jag=jag if last else 0.0)
        z += h


def sheet(bm, fn, nu, nv, thick, uvs=12.0):
    """Thick curved sheet: fn(u, v) -> top point (u, v in 0..1); underside = top - thick in z. World-planar UVs."""
    uvl = _uvl(bm)
    top = [[bm.verts.new(fn(i / nu, j / nv)) for j in range(nv + 1)] for i in range(nu + 1)]
    bot = [[bm.verts.new(v.co - Vector((0, 0, thick))) for v in row] for row in top]

    def quad(a, b, c, d):
        f = bm.faces.new((a, b, c, d))
        for l in f.loops:
            l[uvl].uv = (l.vert.co.x / uvs, l.vert.co.y / uvs + l.vert.co.z / uvs)

    for i in range(nu):
        for j in range(nv):
            quad(top[i][j], top[i + 1][j], top[i + 1][j + 1], top[i][j + 1])
            quad(bot[i][j], bot[i][j + 1], bot[i + 1][j + 1], bot[i + 1][j])
        for j in (0, nv):
            quad(top[i][j], top[i + 1][j], bot[i + 1][j], bot[i][j])
    for j in range(nv):
        for i in (0, nu):
            quad(top[i][j], top[i][j + 1], bot[i][j + 1], bot[i][j])


def planks(bm, axis, c, lo, hi, z0, z1, th, opens, rr, pw=(0.85, 1.05)):
    """Vertical siding planks; openings (a, b, za, zb) leave plank stubs above/below."""
    x = lo
    while x < hi - 0.1:
        w = min(rr.uniform(*pw), hi - x)
        a, b = x, x + w
        x += w
        iv = [(z0, z1)]
        for o in opens:
            if a < o[1] and b > o[0]:
                iv = [seg for s, e in iv for seg in ((s, min(e, o[2])), (max(s, o[3]), e)) if seg[1] - seg[0] > 0.01]
        for s, e in iv:
            if e - s < 0.3:
                continue
            e2 = e - (rr.uniform(0, 0.25) if e >= z1 - 0.01 else 0)
            m = (a + b) / 2
            if axis == "x":
                bx(bm, m, c, s, w - 0.05, th, e2 - s, bev=0.03, mode="timber", uvs=4.0)
            else:
                bx(bm, c, m, s, th, w - 0.05, e2 - s, bev=0.03, mode="timber", uvs=4.0)


def barrel(tm, bz, x, y, z0, r=1.3, h=3.2):
    lathe(tm, [(r * 0.8, 0), (r, h * 0.3), (r * 1.08, h * 0.5), (r, h * 0.7), (r * 0.8, h), (r * 0.72, h - 0.15), (r * 0.9, h * 0.7 - 0.05),
               (r, h * 0.5), (r * 0.9, h * 0.3 + 0.05), (r * 0.72, 0.15)], x=x, y=y, z0=z0, seg=16, turns=2, uvs=4.0)
    for k in (0.25, 0.75):
        cyl(bz, x, y, z0 + h * k - 0.12, r * (1.0 if k < 0.5 else 1.0) * 1.07, r * 1.07, 0.26, seg=16, uvs=4.0)


# ------------------------------------------------------------------------------------------ Bell_Tower_Ruined
def tower():
    P, rr = "Bell_Tower_Ruined", random.Random(2101)
    sb, sa, sbb, sf, rub, tm, bz, rf = [bmesh.new() for _ in range(8)]
    front = {"S": [(-4.7, 4.7, -2.0, 7.5)]}
    box_walls(sb, 17.0, 3.5, -1.0, 1.5, rr, opens=front)
    box_walls(sb, 15.5, 3.2, 1.5, 4.0, rr, opens=front)
    box_walls(sb, 14.0, 3.0, 4.0, 6.5, rr)
    bx(sb, 0, 0, -1.0, 28.0, 28.0, 7.5, bev=0.25)
    for i in range(6):  # entry stair climbing +Y onto the plinth
        bx(sb, 0, -14.9 - 1.6 * (5 - i) + 0.0, -1.0, 9.0, 1.65, 7.5 - 1.08 * (i + 1) + 0.0 + 0.0, bev=0.12, rz=rr.uniform(-0.01, 0.01))
    # tier A: heavy base storey, door + slits, NE corner eroded
    ledge = {"N": lambda x: 27.0 if x < 3 else 0, "E": lambda y: 27.0 if y < 1 else 0}
    box_walls(sa, 11.0, 3.0, 6.5, 26.0, rr,
              opens={"S": [(-2.4, 2.4, 6.5, 14.2), (-1.5, 1.5, 14.2, 15.8), (-7.2, -5.8, 17, 21.5), (5.8, 7.2, 17, 21.5)],
                     "N": [(-1.0, 1.0, 15, 21), (-7, -5.6, 17, 21)], "W": [(-1.4, 1.4, 14, 21), (-1.0, 1.0, 21, 22.5)], "E": [(-5.5, -4.1, 17, 21)]},
              hf={"N": lambda x: 26.0 if x < 3 else max(21.0, 26.0 - (x - 3) * 1.0), "E": lambda y: 26.0 if y < 0 else max(20.0, 26.0 - y * 0.9)})
    box_walls(sa, 11.6, 3.4, 26.0, 27.0, rr, ch=(1.0, 1.0), hf=ledge, bev=0.1)
    # tier B: tall windows, N-E face collapsing
    box_walls(sbb, 9.6, 2.7, 27.0, 47.0, rr,
              opens={s: [(-1.8, 1.8, 33, 41), (-1.2, 1.2, 41, 42.8)] for s in "SNWE"},
              hf={"N": lambda x: 47.0 if x < -2 else max(34.0, 47.0 - (x + 2) * 1.5), "E": lambda y: 47.0 if y < -4 else max(35.5, 47.0 - (y + 4) * 1.4)})
    box_walls(sbb, 10.6, 3.2, 47.0, 48.0, rr, ch=(1.0, 1.0), bev=0.1, hf={"N": lambda x: 48.0 if x < -2 else 0, "E": lambda y: 48.0 if y < -4 else 0})
    # belfry: four piers of unequal height, sill panels, W lintel, S half-lintel; the bell shows through the front arch
    for (px, py, top) in ((-8.0, 8.0, 76.0), (-8.0, -8.0, 69.0), (8.0, -8.0, 62.5), (8.0, 8.0, 56.0)):
        pier(sf, px, py, 48.0, top, 4.4, rr)
    wall(sf, "y", -8.0, -5.8, 5.8, 48.0, 66.0, 2.4, [(-5.8, 5.8, 52.0, 63.5)], lambda y: 66.0, rr, ch=(1.5, 2.0))
    wall(sf, "x", -8.0, -5.8, 5.8, 48.0, 64.0, 2.4, [(-4.6, 4.6, 52.0, 62.0)], lambda x: 64.0 if x < 0 else 52.0, rr, ch=(1.5, 2.0))
    wall(sf, "x", 8.0, -5.8, 5.8, 48.0, 55.0, 2.4, [], lambda x: 55.0 if x < -1 else 51.0, rr, ch=(1.5, 2.0))
    wall(sf, "y", 8.0, -5.8, 5.8, 48.0, 52.0, 2.4, [], lambda y: 52.0 if y < 2 else 49.5, rr, ch=(1.5, 2.0))
    # timber: bell beam, floor joists poking out of the broken east face, rafters, door
    bx(tm, -1.75, 0, 61.2, 14.5, 1.5, 1.6, mode="timber", bev=0.1, jag=0.5)
    for y, ln in ((-2.0, 24.0), (3.5, 21.0), (8.0, 15.0)):
        bx(tm, -9.0 + ln / 2, y, 43.6, ln, 1.1, 1.2, mode="timber", bev=0.08, jag=0.4)
    bx(tm, -2.0, 0, 44.8, 1.1, 17.0, 0.9, mode="timber", bev=0.06, jag=0.4)
    for y in (-4.5, 0.5, 5.0):
        ang = math.atan2(7.0, 12.0)
        xf(tm, lambda y=y: bx(tm, -3.2, y, 66.2, 11.0, 0.8, 0.9, mode="timber", bev=0.06, jag=0.6), about((-8.7, y, 66.2), -ang, "Y"))
    for y, w in ((-2.2, 6.0), (2.6, 4.8)):
        xf(rf, lambda y=y, w=w: bx(rf, -3.8, y, 67.0, 8.0, w, 0.4, bev=0.05, jag=0.35, uvs=12.0), about((-8.7, y, 66.2), -math.atan2(7.0, 12.0), "Y"))
    xf(tm, lambda: bx(tm, -2.4 + 0.0, -9.2, 6.5, 0.5, 2.5, 7.4, mode="timber", bev=0.04, uvs=4.0), about((-2.4, -9.0, 6.5), 1.25, "Z"))
    bx(tm, 0, -9.0, 6.5, 4.8, 0.7, 0.5, mode="timber", bev=0.05)  # door sill
    # bronze: bell on a yoke
    S = 1.35
    prof = [(0.45, 4.5), (0.75, 4.35), (1.2, 4.0), (1.65, 3.5), (2.0, 2.5), (2.4, 1.2), (2.85, 0.25), (3.05, 0.0), (2.6, 0.0), (2.2, 1.0), (1.8, 2.3), (1.4, 3.2), (0.7, 3.7), (0.3, 3.9)]
    lathe(bz, [(r * S, z * S) for r, z in prof], x=-1.75, z0=61.2 - 4.5 * S - 0.4, seg=28)
    bx(bz, -1.75, 0, 60.8, 1.0, 1.0, 0.5, bev=0.08, uvs=4.0)
    cyl(bz, -1.75, 0, 61.2 - 4.5 * S - 1.8, 0.28, 0.2, 2.2, seg=8, uvs=4.0)
    for dx in (-1.1, 1.1):
        bx(bz, -1.75 + dx, 0, 60.4, 0.35, 0.35, 0.8, bev=0.05, uvs=4.0)
    # rubble ring + fallen blocks
    for i in range(78):
        a = rr.uniform(0, 6.283) if i > 24 else rr.uniform(0.2, 1.4)
        d = rr.uniform(17.5, 26.0) if i > 24 else rr.uniform(15.0, 30.0)
        s = rr.uniform(1.0, 3.6)
        zz = -0.4
        xf(rub, lambda: bx(rub, math.cos(a) * d, math.sin(a) * d, zz, s * rr.uniform(0.8, 1.4), s * rr.uniform(0.8, 1.2), s * rr.uniform(0.5, 0.9), bev=0.15, jag=0.3, rz=rr.uniform(0, 3)),
           about((math.cos(a) * d, math.sin(a) * d, zz), rr.uniform(-0.25, 0.25), "X"))
    bx(tm, 18.0, 14.0, -0.2, 11.0, 1.1, 1.0, rz=0.6, mode="timber", bev=0.08, jag=0.4)  # fallen beam
    for name, b, m in (("Stone_Base", sb, "Bell_Stone"), ("Stone_A", sa, "Bell_Stone"), ("Stone_B", sbb, "Bell_Stone"), ("Stone_Belfry", sf, "Bell_Stone"),
                       ("Rubble", rub, "Bell_Stone"), ("Timber", tm, "Bell_Timber"), ("Bronze", bz, "Bell_Bronze"), ("Roof", rf, "Bell_Roof")):
        sub(P, name, b, m)


# ------------------------------------------------------------------------------------------ Hermit_Hut
def hut():
    P, rr = "Hermit_Hut", random.Random(2201)
    st, tm, rf, bz = [bmesh.new() for _ in range(4)]
    L, hw, WT, ZB = 14.0, 5.6, 10.8, 1.4
    ov, zr, drop = 2.5, 16.8, 6.5
    box_walls(st, 7.6, 1.6, -1.0, ZB, rr, ch=(0.8, 1.2), cw=(1.6, 3.0), bev=0.1)  # replaced below by true rectangle
    st.clear()
    wall(st, "x", -hw, -L / 2 - 0.4, L / 2 + 0.4, -1.0, ZB, 1.4, [(-1.6, 1.6, -2, 0.4)], None, rr, ch=(0.8, 1.2), cw=(1.6, 3.0), bev=0.1)
    wall(st, "x", hw, -L / 2 - 0.4, L / 2 + 0.4, -1.0, ZB, 1.4, [], None, rr, ch=(0.8, 1.2), cw=(1.6, 3.0), bev=0.1)
    for sx in (-1, 1):
        wall(st, "y", sx * (L / 2 + 0.2), -hw, hw, -1.0, ZB, 1.4, [], None, rr, ch=(0.8, 1.2), cw=(1.6, 3.0), bev=0.1)
    for i in range(3):  # chimney stack in the north wall
        pass
    z = -1.0
    while z < 18.8:
        h = rr.uniform(1.1, 1.5)
        for k in (-0.62, 0.62):
            bx(st, 3.0 + k + rr.uniform(-0.04, 0.04), hw + 1.0, z, 1.3, 2.4, h - 0.04, bev=0.1, rz=rr.uniform(-0.02, 0.02), jag=0.35 if z + h > 18.4 else 0)
        z += h
    bx(st, 3.0, hw + 1.0, 18.6, 3.4, 3.4, 0.6, bev=0.1)
    for i in range(2):  # porch steps
        bx(st, 0, -hw - 4.3 - 0.9 * i, -0.8, 4.4 - 0.4 * i, 1.0, 1.6 - 0.5 * i, bev=0.12, rz=rr.uniform(-0.02, 0.02))
    # timber: siding, corner posts, plate, girts, rafter tails, gable infill, door, shutters, porch
    wo = {"S": [(-1.3, 1.3, ZB, 7.8), (-5.4, -2.4, 4.4, 7.2)], "N": [(-5.5, -3.0, 4.4, 7.0)], "W": [(-1.4, 1.4, 4.4, 7.0)], "E": []}
    planks(tm, "x", -hw + 0.1, -L / 2, L / 2, ZB, WT - 0.4, 0.5, wo["S"], rr)
    planks(tm, "x", hw - 0.1, -L / 2, L / 2, ZB, WT - 0.4, 0.5, wo["N"], rr)
    for sx, k in ((-1, "W"), (1, "E")):
        planks(tm, "y", sx * (L / 2 - 0.1), -hw, hw, ZB, WT - 0.4, 0.5, wo[k], rr)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl(tm, sx * (L / 2 + 0.05), sy * (hw + 0.05), ZB - 0.1, 0.55, 0.5, WT - ZB + 0.9, seg=8)
    for sy in (-1, 1):
        bx(tm, 0, sy * (hw + 0.15), WT - 0.6, L + 1.4, 0.9, 0.8, mode="timber", bev=0.08)
        for z in (4.0, 7.6):
            bx(tm, 0, sy * (hw + 0.38), z, L, 0.22, 0.3, mode="timber", bev=0.03, uvs=4.0)
        x = -L / 2 + 0.6
        while x < L / 2:
            bx(tm, x, sy * (hw + 0.35), WT + 0.2, 0.4, 0.55, 1.0, mode="timber", bev=0.04, uvs=4.0)
            x += 1.9
    for sx in (-1, 1):
        bx(tm, sx * (L / 2 + 0.15), 0, WT - 0.6, 0.9, 2 * hw + 1.4, 0.8, mode="timber", bev=0.08)
        z = WT + 0.2
        while z < zr - 0.5:
            wd = hw * (1 - (z - WT) / (zr - WT - 0.2))
            if wd > 0.4:
                bx(tm, sx * (L / 2 - 0.15), 0, z, 0.5, 2 * wd, 0.88, mode="timber", bev=0.03, uvs=4.0)
            z += 0.9
    bx(tm, 0, 0, zr - 0.9, L + 5.2, 0.8, 0.9, mode="timber", bev=0.1)  # ridge beam
    xf(tm, lambda: bx(tm, -1.3, -hw - 0.2, ZB, 2.6, 0.35, 6.4, mode="timber", bev=0.04, uvs=4.0), about((-1.3, -hw - 0.2, 0), 1.1, "Z"))  # door ajar
    for sx in (-1, 1):  # window shutters, one open one hanging
        xf(tm, lambda sx=sx: bx(tm, -3.9 + sx * 1.5, -hw - 0.3, 4.4, 1.4, 0.25, 2.8, mode="timber", bev=0.03, uvs=4.0), about((-3.9 + sx * 1.5, -hw - 0.3, 0), sx * 1.2, "Z"))
    # porch: raised floor, posts, lean-to roof, bench, barrel, firewood
    PY = hw + 4.6
    for i in range(10):
        bx(tm, 0, -hw - 0.1 - PY / 2 + 0.0 + 0.0, 0.5, 12.0, 0.9, 0.3, mode="timber", bev=0.03, uvs=4.0, rz=0) if False else None
    yy = -hw - 0.2
    while yy > -hw - 4.6:
        bx(tm, 0, yy - 0.5, 0.5, 11.6, 0.95, 0.3, mode="timber", bev=0.03, uvs=4.0)
        yy -= 1.0
    for x in (-5.4, -1.8, 1.8, 5.4):
        bx(tm, x, -hw - 2.4, -0.4, 0.5, 4.6, 0.9, mode="timber", bev=0.04, uvs=4.0)
    for sx in (-1, 1):
        cyl(tm, sx * 5.4, -hw - 4.5, 0.8, 0.4, 0.36, 9.0, seg=8)
        cyl(tm, sx * 5.4, -hw - 4.5, 0.8, 0.4, 0.36, 9.0, seg=8) if False else None
        bx(tm, sx * 5.4, -hw - 4.5, 1.1, 0.25, 0.25, 0.5, bev=0.02)
    bx(tm, 0, -hw - 4.5, 9.1, 12.4, 0.7, 0.7, mode="timber", bev=0.06)
    for x in (-4.6, -1.5, 1.5, 4.6):
        bx(tm, x, -hw - 3.4, 8.9, 0.4, 3.0, 0.5, mode="timber", bev=0.04, uvs=4.0)
    bx(tm, 3.2, -hw - 1.6, 1.0, 4.8, 1.1, 0.35, mode="timber", bev=0.05, uvs=4.0)
    for x in (1.2, 5.2):
        bx(tm, x, -hw - 1.6, 0.5, 0.4, 0.8, 1.9, mode="timber", bev=0.04, uvs=4.0)
    for k in range(3):  # firewood stack on the west wall
        for j in range(5 - k):
            cyl(tm, -L / 2 - 1.2 - 0.0, -hw + 0.3 + (j + 0.5 * k) * 0.86 - 0.0 + 0.0, 0.4 + k * 0.75, 0.38, 0.38, 3.0, seg=8) if False else None
    for k in range(3):
        for j in range(5 - k):
            xf(tm, lambda j=j, k=k: cyl(tm, 0, 0, 0, 0.38, 0.38, 2.6, seg=8), Matrix.Translation((-L / 2 - 1.3, -3.3 + (j + 0.5 * k) * 0.86, 0.45 + k * 0.72)) @ Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Translation((0, 0, -1.3)))
    barrel(tm, bz, -L / 2 - 1.8, hw - 1.6, 0.0, r=1.2, h=3.0)
    # roof (curved eaves) + porch lean-to
    def slope(s):
        def fn(u, v):
            x = (u * 2 - 1) * (L / 2 + 0.5 + 2.4)
            y = s * v * (hw + ov)
            return Vector((x, y, zr - drop * v ** 0.9 + 18 * max(0.0, v - 0.78) ** 2 + 1.1 * abs(u * 2 - 1) ** 5))
        return fn
    for s in (-1, 1):
        sheet(rf, slope(s), 18, 10, 0.5)

    def porch(u, v):
        return Vector(((u * 2 - 1) * 6.4, -hw - 0.2 - v * 5.4, 10.4 - 2.0 * v ** 0.9 + 4 * max(0.0, v - 0.8) ** 2))
    sheet(rf, porch, 12, 6, 0.4)
    # bronze: door ring, wind chime
    cyl(bz, 0.9, -hw - 0.55, 3.6, 0.35, 0.35, 0.12, seg=10, uvs=4.0)
    for i, x in enumerate((-1.5, -0.5, 0.5, 1.5)):
        cyl(bz, x, -hw - 4.4, 7.0 - 0.4 * (i % 2), 0.14, 0.14, 1.4 + 0.3 * (i % 2), seg=6, uvs=4.0)
    cyl(bz, 0, -hw - 4.4, 8.4, 1.1, 1.1, 0.12, seg=10, uvs=4.0)
    for name, b, m in (("Stone", st, "Bell_Stone"), ("Timber", tm, "Bell_Timber"), ("Roof", rf, "Bell_Roof"), ("Bronze", bz, "Bell_Bronze")):
        sub(P, name, b, m)


# ------------------------------------------------------------------------------------------ rope bridge
def deck(P, variant):
    rr = random.Random(2301 + variant)
    tm, rp = bmesh.new(), bmesh.new()
    n, pitch = 11, 0.72
    for i in range(n):
        if variant == 1 and i == 4:
            continue
        y = -4.0 + pitch / 2 + i * pitch
        w = 5.4
        if variant == 1 and i == 7:
            w = 2.9
        bx(tm, (-1.25 if (variant == 1 and i == 7) else 0) + rr.uniform(-0.05, 0.05), y, 0.0, w, 0.62, 0.32, bev=0.04, mode="timber", uvs=4.0,
           rz=rr.uniform(-0.015, 0.015), jag=0.05 if variant == 1 and i in (2, 9) else 0.0)
    for sx in (-1, 1):
        y0, y1, rad = -4.2, 4.2, 0.2 if variant == 0 else 0.17
        tube(rp, [Vector((sx * 2.1, y0 + (y1 - y0) * k / 8, -0.35 - 0.04 * math.sin(k / 8 * math.pi))) for k in range(9)], [rad] * 9, sides=6, uvs=2.0)
        tube(rp, [Vector((sx * 2.9, y0 + (y1 - y0) * k / 8, 3.6 - 0.18 * math.sin(k / 8 * math.pi))) for k in range(9)], [rad * 0.9] * 9, sides=6, uvs=2.0)
        for y in (-3.5, -1.2, 1.2, 3.5):
            if variant == 1 and abs(y - 1.2) < 0.1:
                continue
            tube(rp, [Vector((sx * 2.75, y, 0.25)), Vector((sx * 2.82, y, 1.9)), Vector((sx * 2.9, y, 3.55))], [0.1] * 3, sides=5, uvs=2.0)
        tube(rp, [Vector((sx * 2.8, -3.5, 1.7)), Vector((sx * 2.8, -1.2, 1.55)), Vector((sx * 2.8, 1.2, 1.55)), Vector((sx * 2.8, 3.5, 1.7))], [0.09] * 4, sides=5, uvs=2.0)
    sub(P, "Timber", tm, "Bell_Timber")
    sub(P, "Rope", rp, "Bell_Rope")


def anchor():
    P, rr = "Rope_Bridge_Anchor", random.Random(2331)
    tm, st, rp, bz = [bmesh.new() for _ in range(4)]
    yy = -3.2
    while yy < 3.2:
        bx(tm, 0, yy + 0.5, 0.0, 8.4, 0.95, 0.32, bev=0.04, mode="timber", uvs=4.0, rz=rr.uniform(-0.01, 0.01))
        yy += 1.0
    for y in (-2.4, 2.4):
        cyl(tm, 0, y, -1.0, 0.65, 0.65, 1.0, seg=8) if False else None
        xf(tm, lambda y=y: cyl(tm, 0, 0, 0, 0.6, 0.6, 9.6, seg=8), Matrix.Translation((0, y, -0.65)) @ Matrix.Rotation(math.pi / 2, 4, "Y") @ Matrix.Translation((0, 0, -4.8 + 0.0)))
    for sx in (-1, 1):
        cyl(tm, sx * 3.8, 1.6, 0.0, 0.85, 0.7, 13.0, seg=9)
        xf(tm, lambda sx=sx: cyl(tm, 0, 0, 0, 0.55, 0.5, 11.0, seg=8), about((sx * 3.8, -2.2, 0.0), -0.45, "X") @ Matrix.Translation((sx * 3.8, -2.2, 0.0)))
        bx(st, sx * 3.8, 1.6, -1.0, 3.2, 3.2, 1.6, bev=0.2, rz=rr.uniform(-0.1, 0.1))
        bx(st, sx * 3.8, -2.4, -1.0, 2.4, 2.4, 1.2, bev=0.18)
        cyl(bz, sx * 3.8, 1.6, 12.9, 0.95, 0.4, 0.55, seg=9, uvs=4.0)
        for z in (7.5, 10.2):
            r0 = rr.uniform(0.95, 1.05)
            tube(rp, [Vector((sx * 3.8 + r0 * math.cos(a), 1.6 + r0 * math.sin(a), z + 0.05 * a)) for a in [k * 0.5 for k in range(14)]], [0.14] * 14, sides=5, uvs=2.0)
        tube(rp, [Vector((sx * 3.8, 1.6, 10.2)), Vector((sx * 3.5, 6.5, 6.4)), Vector((sx * 2.9, 12.0, 3.6))], [0.2] * 3, sides=6, uvs=2.0)
        tube(rp, [Vector((sx * 3.0, 3.0, 0.6)), Vector((sx * 2.4, 8.0, 0.1)), Vector((sx * 2.1, 12.0, -0.35))], [0.2] * 3, sides=6, uvs=2.0)
    bx(tm, 0, 1.6, 11.0, 10.4, 1.0, 1.1, mode="timber", bev=0.1)
    bx(tm, 0, 1.6, 7.0, 8.0, 0.7, 0.7, mode="timber", bev=0.06)
    for sx in (-1, 1):
        xf(tm, lambda sx=sx: bx(tm, sx * 1.9, 1.6, 7.2, 0.6, 0.5, 5.4, mode="timber", bev=0.05, uvs=4.0), about((sx * 1.9, 1.6, 7.2), -sx * 0.7, "Y"))
    for name, b, m in (("Timber", tm, "Bell_Timber"), ("Stone", st, "Bell_Stone"), ("Rope", rp, "Bell_Rope"), ("Bronze", bz, "Bell_Bronze")):
        sub(P, name, b, m)


# ------------------------------------------------------------------------------------------ Falls_Alcove
def falls():
    P, rr = "Falls_Alcove", random.Random(2401)
    back, lip, side, rim, stn, tm = [bmesh.new() for _ in range(6)]
    # cliff: a back plate closing the niche, two shoulders leaving a 6-stud-wide recess, a notched overhang lip the water spills over
    rock(back, (0, 16.5, 10.5), (17.0, 3.6, 11.5), rr, sub=5, planes=9, lump=0.1, rough=0.05, moss_bias=-0.3, S=28.0)
    rock(back, (-10.2, 10.0, 8.8), (6.8, 5.2, 9.6), rr, sub=5, planes=9, lump=0.12, rough=0.05, moss_bias=-0.2, S=24.0)
    rock(back, (10.2, 10.0, 8.8), (6.8, 5.2, 9.6), rr, sub=5, planes=9, lump=0.12, rough=0.05, moss_bias=-0.2, S=24.0)
    for x, R in ((-6.2, (6.0, 5.0, 2.4)), (6.2, (6.0, 5.0, 2.4))):
        rock(lip, (x, 8.2, 19.4), R, rr, sub=4, planes=6, lump=0.1, rough=0.04, flat_top=20.6, moss_bias=-0.1)
    rock(lip, (0, 9.6, 17.6), (2.2, 5.0, 0.9), rr, sub=3, planes=3, flat_top=17.9, lump=0.06, rough=0.03, moss_bias=-1.0)  # chute slab under the water
    for x, z, R in ((-13.5, 17.0, (4.4, 4.0, 3.4)), (13.5, 17.0, (4.4, 4.0, 3.4))):
        rock(lip, (x, 8.0, z), R, rr, sub=4, planes=5, lump=0.15, rough=0.05, moss_bias=-0.4)
    for x, y, z, R in ((-17.5, 6.0, 4.0, (4.2, 4.6, 5.2)), (17.5, 6.0, 4.0, (4.2, 4.6, 5.2)), (15.5, 1.5, 1.4, (3.4, 3.0, 2.6)),
                       (-19.5, 9.0, 7.5, (3.5, 4.0, 6.5)), (19.5, 9.0, 7.5, (3.5, 4.0, 6.5))):
        rock(side, (x, y, z), R, rr, sub=4, planes=5, lump=0.16, rough=0.05, moss_bias=0.1)
    for a in [i * 2 * math.pi / 16 for i in range(16)]:  # plunge-pool rim, open to the front
        if -0.3 < math.sin(a) < 0.9 and False:
            continue
        x, y = math.cos(a) * 9.5, 1.0 + math.sin(a) * 6.5
        if y < -1.2:
            continue
        rock(rim, (x, y, 0.2), (rr.uniform(1.3, 2.1), rr.uniform(1.2, 1.8), rr.uniform(0.8, 1.4)), rr, sub=3, bottom=-0.8, lump=0.2, moss_bias=0.2, rz=rr.uniform(0, 3), S=8.0)
    # shrine niche left of the fall: jamb rocks + lintel + ledge slab, stone shrine on the ledge
    rock(rim, (-14.0, 1.2, 1.2), (5.0, 3.0, 1.1), rr, sub=3, planes=3, flat_top=2.0, bottom=-0.8, lump=0.08, rough=0.04, moss_bias=-0.5, S=12.0)
    bx(stn, -14.0, 1.2, 1.9, 3.4, 2.4, 0.7, bev=0.12)
    bx(stn, -14.0, 1.2, 2.5, 2.2, 1.6, 1.5, bev=0.12)
    bx(stn, -14.0, 1.2, 4.0, 3.4, 2.6, 0.45, bev=0.1)
    xf(stn, lambda: bx(stn, -14.0, 1.2, 4.4, 2.0, 1.5, 0.7, bev=0.1, rz=math.pi / 4), Matrix.Identity(4))
    bx(stn, -12.0, -0.2, 1.9, 0.9, 0.9, 1.1, bev=0.08)
    bx(stn, -12.0, -0.2, 3.0, 1.5, 1.5, 0.4, bev=0.08)
    bx(stn, -12.0, -0.2, 3.4, 0.8, 0.8, 0.8, bev=0.08)
    bx(stn, -12.0, -0.2, 4.2, 1.9, 1.9, 0.35, bev=0.08, rz=math.pi / 4)
    for i in range(3):
        bx(stn, -16.0 + i * 0.9, -0.2, 1.9, 0.55, 0.55, 0.3 + 0.15 * i, bev=0.06, rz=rr.uniform(0, 3))
    bx(tm, -14.0, 1.2, 4.8, 1.0, 0.2, 1.4, mode="timber", bev=0.03, uvs=4.0)  # offering plaque
    for name, b, m, sm in (("Rock_Back", back, "Bell_Granite", True), ("Rock_Lip", lip, "Bell_Granite", False), ("Rock_Sides", side, "Bell_Granite", False),
                           ("Rock_Rim", rim, "Bell_Granite", True), ("Shrine_Stone", stn, "Bell_Stone", False), ("Shrine_Timber", tm, "Bell_Timber", False)):
        sub(P, name, b, m, sm)


# ------------------------------------------------------------------------------------------ carts, crates, pots
def wheel(tm, bz, R, M, th=0.7, spokes=8):
    def build():
        lathe(tm, [(R - 0.6, -th / 2), (R, -th / 2), (R, th / 2), (R - 0.6, th / 2)], seg=28, turns=3, uvs=4.0)
        for k in range(spokes):
            xf(tm, lambda: bx(tm, (R - 0.4) / 2 + 0.2, 0, -0.2, R - 0.8, 0.5, 0.4, mode="timber", bev=0.04, uvs=4.0), Matrix.Rotation(k * 2 * math.pi / spokes, 4, "Z"))
        cyl(tm, 0, 0, -th * 0.7, 0.85, 0.85, th * 1.4, seg=10, uvs=4.0)
        cyl(bz, 0, 0, th * 0.7, 0.9, 0.55, 0.3, seg=10, uvs=4.0)
        cyl(bz, 0, 0, -th * 0.7 - 0.3, 0.55, 0.9, 0.3, seg=10, uvs=4.0)
    xf(tm, build, M)


def sack(rp, x, y, z, r=1.2, sx=1.0):
    bm = rp
    uvl = _uvl(bm)
    vs = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=7, radius=1.0)["verts"]
    for v in vs:
        k = 1 + 0.12 * noise.noise(v.co * 2.0 + Vector((x, y, z)))
        v.co = Vector((v.co.x * r * 1.0 * sx * k, v.co.y * r * 0.9 * k, v.co.z * r * 0.75 * k)) + Vector((x, y, z + r * 0.7))
    for f in {f for v in vs for f in v.link_faces}:
        for l in f.loops:
            l[uvl].uv = (l.vert.co.x / 3.0, l.vert.co.y / 3.0 + l.vert.co.z / 3.0)


def cart_a():
    P, rr = "Cart_A", random.Random(2501)
    tm, bz, rp = bmesh.new(), bmesh.new(), bmesh.new()
    R = 3.1
    for sy in (-1, 1):
        wheel(tm, bz, R, Matrix.Translation((0, sy * 3.5, R)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    cyl(tm, 0, 0, 0, 0.0, 0.0, 0.0, seg=3) if False else None
    xf(tm, lambda: cyl(tm, 0, 0, 0, 0.32, 0.32, 7.4, seg=8), Matrix.Translation((0, 3.7, R)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    for i in range(8):
        bx(tm, -3.9 + i * 1.12, 0, 3.6, 1.05, 5.0, 0.3, bev=0.03, mode="timber", uvs=4.0, rz=rr.uniform(-0.02, 0.02))
    for sy in (-1, 1):
        for k in range(2):
            bx(tm, 0, sy * 2.45, 3.9 + k * 0.95, 8.4, 0.3, 0.8, bev=0.03, mode="timber", uvs=4.0)
        for x in (-4.0, 0, 4.0):
            bx(tm, x, sy * 2.45, 3.6, 0.45, 0.45, 2.3, bev=0.04, mode="timber", uvs=4.0)
    for sx in (-1, 1):
        bx(tm, sx * 4.1, 0, 3.9, 0.3, 4.8, 0.8, bev=0.03, mode="timber", uvs=4.0)
    for sy in (-1, 1):
        xf(tm, lambda sy=sy: bx(tm, -9.0, sy * 1.7, 3.4, 11.0, 0.5, 0.5, bev=0.06, mode="timber", uvs=4.0, jag=0.0), about((-3.5, sy * 1.7, 3.4), -0.075, "Y"))
    bx(tm, -13.5, 0, 1.8, 0.5, 4.2, 0.5, bev=0.05, mode="timber", uvs=4.0)
    bx(tm, 3.8, 0, 3.2, 1.6, 4.2, 0.4, mode="timber", bev=0.04, uvs=4.0)
    for sy in (-1, 1):
        bx(tm, -12.6, sy * 1.7, 0.0, 0.4, 0.4, 2.2, bev=0.04, mode="timber", uvs=4.0)
    for (x, y, r, sxx) in ((-1.5, -0.8, 1.15, 1.2), (1.3, 0.6, 1.1, 1.1), (-0.1, 1.1, 0.95, 1.0)):
        sack(rp, x, y, 3.9, r, sxx)
    tube(rp, [Vector((-3.2, -2.6, 4.2)), Vector((0, -2.9, 6.2)), Vector((3.2, 2.9, 4.2))], [0.14] * 3, sides=5, uvs=2.0)
    cyl(bz, 3.9, -2.2, 4.3, 0.12, 0.12, 0.4, seg=5, uvs=4.0)
    for name, b, m in (("Timber", tm, "Bell_Timber"), ("Bronze", bz, "Bell_Bronze"), ("Cloth", rp, "Bell_Rope")):
        sub(P, name, b, m)


def cart_b():
    P, rr = "Cart_B", random.Random(2511)
    tm, bz, rp = bmesh.new(), bmesh.new(), bmesh.new()
    R = 2.7
    for sx in (-1, 1):
        for sy in (-1, 1):
            if sx < 0 and sy < 0:
                continue  # rear-left wheel is gone: the corner rests on a prop log
            wheel(tm, bz, R, Matrix.Translation((sx * 3.8, sy * 3.7, R)) @ Matrix.Rotation(math.pi / 2, 4, "X"), th=0.8)
    for sx in (-1, 1):
        xf(tm, lambda sx=sx: cyl(tm, 0, 0, 0, 0.32, 0.32, 8.0, seg=8), Matrix.Translation((sx * 3.8, 4.0, R)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    bx(tm, 0, 0, 3.0, 11.6, 0.9, 0.7, mode="timber", bev=0.06)
    for sy in (-1, 1):
        bx(tm, 0, sy * 2.3, 3.0, 11.6, 0.8, 0.7, mode="timber", bev=0.06)
    for i in range(10):
        bx(tm, -5.4 + i * 1.2, 0, 3.7, 1.12, 6.4, 0.3, bev=0.03, mode="timber", uvs=4.0, rz=rr.uniform(-0.015, 0.015), jag=0.1 if i == 3 else 0.0)
    xf(tm, lambda: bx(tm, 11.5, 0, 3.2, 12.0, 0.6, 0.6, mode="timber", bev=0.06), about((5.8, 0, 3.2), -0.18, "Y"))
    xf(tm, lambda: cyl(tm, -5.6, -3.5, 0, 0.6, 0.6, 5.4, seg=8), about((-5.6, -3.5, 0), 0.8, "X"))
    for sy in (-1, 1):  # canopy hoops, torn
        for x in (-3.8, -0.3, 3.2):
            if sy < 0 and x > 3:
                continue
            pass
    for x in (-3.8, -0.3, 3.2):
        pts = [Vector((x, 3.15 * math.cos(a), 4.0 + 3.6 * math.sin(a))) for a in [k * math.pi / 8 for k in range(9)]]
        tube(tm, pts, [0.2] * 9, sides=5, uvs=4.0)
    for k, x in enumerate((-3.8, 0.0)):
        pts = [Vector((x + 1.7 * (1 + 0.1 * math.sin(a * 3)), 3.1 * math.cos(a), 4.0 + 3.5 * math.sin(a) + 0.0)) for a in [j * math.pi / 8 for j in range(2, 7)]]
    barrel(tm, bz, 4.2, 1.4, 4.0, r=1.4, h=3.3)
    barrel(tm, bz, 4.4, -1.6, 4.0, r=1.4, h=3.3)
    sack(rp, -4.2, 1.0, 4.0, 1.3)
    sack(rp, -4.4, -1.4, 4.0, 1.2, 1.2)
    for i in range(3):  # cloth scraps on the hoops
        bx(rp, -3.8 + i * 3.5, 1.0 * (1 - i), 7.5 - 0.0 * i, 0.1, 2.0, 1.4, bev=0.0, mode="timber", uvs=4.0) if False else None
    for name, b, m in (("Timber", tm, "Bell_Timber"), ("Bronze", bz, "Bell_Bronze"), ("Cloth", rp, "Bell_Rope")):
        sub(P, name, b, m)


def crate(P, sx, sy, sz, kind, seed):
    rr = random.Random(seed)
    tm, bz = bmesh.new(), bmesh.new()
    t = 0.4
    for dx in (-1, 1):
        for dy in (-1, 1):
            bx(tm, dx * (sx / 2 - t / 2), dy * (sy / 2 - t / 2), 0, t, t, sz, mode="timber", bev=0.05, uvs=4.0)
    n = max(3, round(sz / 1.0))
    bh = (sz - 0.1) / n
    for k in range(n):
        z = 0.05 + k * bh
        for dy in (-1, 1):
            if kind == "B" and k == 1 and dy < 0:
                continue  # missing slat
            bx(tm, rr.uniform(-0.04, 0.04), dy * (sy / 2 - t / 4), z, sx - 2 * t + 0.2, t / 2, bh - 0.1, mode="timber", bev=0.03, uvs=4.0, rz=rr.uniform(-0.01, 0.01))
        for dx in (-1, 1):
            bx(tm, dx * (sx / 2 - t / 4), 0, z, t / 2, sy - 2 * t + 0.2, bh - 0.1, mode="timber", bev=0.03, uvs=4.0)
    if kind in ("A", "C"):
        ang = math.atan2(sz - 0.6, sx - 1.0)
        L = math.hypot(sz - 0.6, sx - 1.0)
        for dy in (-1, 1):
            xf(tm, lambda dy=dy: bx(tm, 0, dy * (sy / 2 + 0.02), sz / 2 - L / 2, 0.45, 0.14, L, mode="timber", bev=0.02, uvs=4.0), about((0, dy * sy / 2, sz / 2), ang - math.pi / 2 if False else -(math.pi / 2 - ang), "Y"))
    if kind == "A":
        for i in range(4):
            bx(tm, rr.uniform(-0.03, 0.03), -sy / 2 + (i + 0.5) * sy / 4, sz, sx + 0.3, sy / 4 - 0.08, 0.3, mode="timber", bev=0.03, uvs=4.0)
        for x in (-sx / 2 + 0.2, sx / 2 - 0.2):
            bx(bz, x, 0, sz + 0.25, 0.3, sy + 0.1, 0.12, bev=0.02, uvs=4.0)
    if kind == "B":  # open top, lid leaning on the front
        xf(tm, lambda: [bx(tm, 0, -sy / 4 + i * sy / 2, 0, sx, sy / 2 - 0.08, 0.28, mode="timber", bev=0.03, uvs=4.0) for i in range(2)], about((0, -sy / 2 - 0.1, 0), 1.18, "X") @ Matrix.Translation((0, -sy / 2 - 1.2, 0.0)))
        bx(tm, 0, 0, 0.0, sx - 0.8, sy - 0.8, 0.4, mode="timber", bev=0.03, uvs=4.0)
    if kind == "C":
        for z in (sz * 0.2, sz * 0.7):
            for dy in (-1, 1):
                bx(bz, 0, dy * (sy / 2 + 0.02), z, sx + 0.1, 0.1, 0.28, bev=0.02, uvs=4.0)
        xf(tm, lambda: [bx(tm, 0, -sy / 4 + i * sy / 2, sz, sx + 0.3, sy / 2 - 0.08, 0.3, mode="timber", bev=0.03, uvs=4.0) for i in range(2)], about((0, 0, sz), 0.0, "Z") @ Matrix.Translation((0.9, 0, 0)))
    for name, b, m in (("Timber", tm, "Bell_Timber"), ("Bronze", bz, "Bell_Bronze")):
        sub(P, name, b, m)


def pots():
    for P, prof, kind in (
        ("Pot_A", [(1.2, 0), (1.6, 0.1), (2.1, 0.9), (2.35, 2.0), (2.1, 3.1), (1.45, 3.7), (1.3, 4.0), (1.5, 4.3), (1.55, 4.45), (1.2, 4.4), (1.1, 3.9), (1.7, 3.0), (1.95, 2.0), (1.6, 0.9), (0.9, 0.3)], "A"),
        ("Pot_B", [(0.9, 0), (1.3, 0.2), (1.75, 1.6), (1.85, 2.8), (1.5, 4.2), (0.85, 5.1), (0.8, 5.7), (1.15, 6.1), (1.2, 6.25), (0.85, 6.2), (0.62, 5.7), (0.7, 5.0), (1.3, 4.2), (1.6, 2.8), (1.5, 1.6), (0.8, 0.5)], "B"),
        ("Pot_C", [(1.8, 0), (2.4, 0.2), (2.85, 1.2), (2.7, 2.2), (2.1, 2.9), (1.95, 3.1), (2.05, 3.3), (1.85, 3.3), (1.7, 3.0), (2.3, 2.2), (2.45, 1.2), (2.0, 0.4)], "C")):
        rr = random.Random(hash(P) & 0xFFFF)
        cl, rp = bmesh.new(), bmesh.new()
        lathe(cl, prof, seg=24, turns=3, uvs=4.0)
        if kind == "B":
            for sx in (-1, 1):
                tube(cl, [Vector((sx * 0.8, 0, 5.2)), Vector((sx * 1.35, 0, 5.6)), Vector((sx * 1.95, 0, 4.9)), Vector((sx * 1.95, 0, 4.3)), Vector((sx * 1.62, 0, 3.9))], [0.22, 0.24, 0.24, 0.22, 0.2], sides=6, uvs=2.0)
        if kind == "C":
            lathe(cl, [(0.3, 3.3), (1.9, 3.2), (2.0, 3.5), (1.6, 3.85), (0.9, 4.1), (0.5, 4.5), (0.5, 4.9), (0.3, 4.9), (0.3, 4.5), (0.6, 4.1)], seg=20, turns=3, uvs=4.0)
            tube(rp, [Vector((2.15 * math.cos(a), 2.15 * math.sin(a), 2.55)) for a in [k * 0.5 for k in range(14)]], [0.14] * 14, sides=5, uvs=2.0)
        sub(P, "Clay", cl, "Bell_Clay", smooth=True)
        sub(P, "Rope", rp, "Bell_Rope")


# ------------------------------------------------------------------------------------------ lanterns
def lantern_hanging():
    P = "Lantern_Hanging"
    bz, gl, rp = bmesh.new(), bmesh.new(), bmesh.new()
    z0 = 1.3
    cyl(bz, 0, 0, z0, 1.7, 1.5, 0.35, seg=6, uvs=4.0)
    for k in range(6):
        a = k * math.pi / 3
        cyl(bz, math.cos(a) * 1.35, math.sin(a) * 1.35, z0 + 0.3, 0.14, 0.14, 4.0, seg=5, uvs=4.0)
    for z in (z0 + 1.2, z0 + 2.9):
        cyl(bz, 0, 0, z, 1.42, 1.42, 0.14, seg=6, uvs=4.0)
    cyl(bz, 0, 0, z0 + 4.2, 2.5, 2.0, 0.3, seg=6, uvs=4.0)
    cyl(bz, 0, 0, z0 + 4.45, 2.0, 0.5, 1.5, seg=6, uvs=4.0)
    cyl(bz, 0, 0, z0 + 5.9, 0.5, 0.18, 0.5, seg=6, uvs=4.0)
    for i in range(7):
        bx(bz, 0, 0, z0 + 6.3 + i * 0.55, 0.22 if i % 2 else 0.5, 0.5 if i % 2 else 0.22, 0.6, bev=0.04, uvs=4.0)
    cyl(gl, 0, 0, z0 + 0.4, 0.95, 0.95, 3.7, seg=8, uvs=4.0)
    tube(rp, [Vector((0, 0, z0 + 0.05)), Vector((0.1, 0, z0 - 0.5)), Vector((0, 0.1, 0.1))], [0.12] * 3, sides=5, uvs=2.0)
    bx(rp, 0, 0, 0.0, 0.5, 0.5, 0.5, bev=0.1, uvs=2.0)
    sub(P, "Bronze", bz, "Bell_Bronze")
    sub(P, "Glow", gl, "Bell_LanternGlow")
    sub(P, "Rope", rp, "Bell_Rope")


def lantern_stone():
    P = "Lantern_Stone"
    st, gl = bmesh.new(), bmesh.new()
    bx(st, 0, 0, -0.5, 3.6, 3.6, 1.1, bev=0.18)
    cyl(st, 0, 0, 0.6, 0.9, 0.75, 2.6, seg=8)
    cyl(st, 0, 0, 3.2, 1.9, 1.7, 0.45, seg=8)
    bx(st, 0, 0, 3.65, 2.7, 2.7, 0.35, bev=0.08)
    for dx in (-1, 1):
        for dy in (-1, 1):
            bx(st, dx * 1.0, dy * 1.0, 4.0, 0.5, 0.5, 2.0, bev=0.08)
    bx(gl, 0, 0, 4.1, 1.6, 1.6, 1.8, bev=0.05, uvs=4.0)
    bx(st, 0, 0, 6.0, 3.8, 3.8, 0.4, bev=0.1)
    cone = bmesh.ops.create_cone(st, cap_ends=True, segments=4, radius1=3.9, radius2=0.5, depth=1.7)
    uvl = _uvl(st)
    new = set(f for v in cone["verts"] for f in v.link_faces)
    for v in cone["verts"]:
        v.co = Matrix.Rotation(math.pi / 4, 3, "Z") @ v.co + Vector((0, 0, 6.4 + 0.85))
    for f in new:
        for l in f.loops:
            l[uvl].uv = (l.vert.co.x / 8, l.vert.co.y / 8 + l.vert.co.z / 16)
    cyl(st, 0, 0, 8.1, 0.5, 0.3, 0.5, seg=8)
    cyl(st, 0, 0, 8.6, 0.65, 0.05, 0.9, seg=8)
    sub(P, "Stone", st, "Bell_Stone")
    sub(P, "Glow", gl, "Bell_LanternGlow")


PIECE_FUNCS = [("Bell_Tower_Ruined", tower), ("Hermit_Hut", hut), ("Rope_Bridge_Deck_A", lambda: deck("Rope_Bridge_Deck_A", 0)),
               ("Rope_Bridge_Deck_B", lambda: deck("Rope_Bridge_Deck_B", 1)), ("Rope_Bridge_Anchor", anchor), ("Falls_Alcove", falls),
               ("Cart_A", cart_a), ("Cart_B", cart_b), ("Crate_A", lambda: crate("Crate_A", 4.0, 4.0, 4.0, "A", 31)),
               ("Crate_B", lambda: crate("Crate_B", 6.0, 4.0, 3.0, "B", 32)), ("Crate_C", lambda: crate("Crate_C", 3.4, 3.4, 5.4, "C", 33)),
               ("Pot_A", pots), ("Pot_B", None), ("Pot_C", None), ("Lantern_Hanging", lantern_hanging), ("Lantern_Stone", lantern_stone)]


# ------------------------------------------------------------------------------------------ renders
def make_figure(mat):
    bm = bmesh.new()
    for x in (-0.45, 0.45):
        bx(bm, x, 0, 0, 0.8, 0.8, 2.3, bev=0.05)
    bx(bm, 0, 0, 2.3, 2.1, 1.1, 2.3, bev=0.1)
    for x in (-1.4, 1.4):
        bx(bm, x, 0, 2.5, 0.6, 0.6, 1.9, bev=0.05)
    vs = bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.6)["verts"]
    for v in vs:
        v.co += Vector((0, 0, 4.9))
    me = bpy.data.meshes.new("Figure")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    o = bpy.data.objects.new("Figure", me)
    bpy.context.scene.collection.objects.link(o)
    o.hide_render = True
    return o


def make_trees():
    bm = bmesh.new()
    r = random.Random(77)
    for i in range(46):
        a, d = r.uniform(0, 6.283), r.uniform(30, 110)
        if math.sin(a) * d < -24:  # keep the near-camera side clear so the tower top shows above the canopy
            a = -a
        x, y, h = math.cos(a) * d, math.sin(a) * d, r.uniform(44, 56)
        cyl(bm, x, y, 0, 1.4, 0.9, h * 0.6, seg=6)
        vs = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)["verts"]
        for v in vs:
            v.co = Vector((v.co.x * 9, v.co.y * 9, v.co.z * h * 0.28)) + Vector((x, y, h * 0.72))
    me = bpy.data.meshes.new("StandInTrees")
    bm.to_mesh(me)
    bm.free()
    m = bpy.data.materials.new("StandIn")
    try:
        m.use_nodes = True
    except Exception:
        pass
    next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.08, 0.2, 0.07, 1)
    me.materials.append(m)
    o = bpy.data.objects.new("StandInTrees", me)
    bpy.context.scene.collection.objects.link(o)
    o.hide_render = True
    return o


def main():
    for d in (OUT / "maps", CAP, UPL):
        d.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    stone_mat(), timber_mat(), bronze_mat(), glow_mat(), roof_mat(), granite_mat(), clay_mat(), rope_mat()
    for name, fn in PIECE_FUNCS:
        if fn is None or (ONLY and name not in ONLY and not (name == "Pot_A" and ONLY & {"Pot_A", "Pot_B", "Pot_C"})):
            continue
        fn()
    for name, objs in PIECES.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.export_scene.gltf(filepath=str(OUT / f"{name}.glb"), export_format="GLB", use_selection=True, export_apply=False)
        lo, hi = bbox(objs)
        info = manifest["pieces"][name]
        info["file"] = f"{name}.glb"
        info["size_studs_xyz"] = [round(hi.x - lo.x, 1), round(hi.y - lo.y, 1), round(hi.z - lo.z, 1)]
        info["materials"] = sorted({m.name for o in objs for m in o.data.materials})
        info["tris_total"] = sum(info["sub_meshes"].values())
        info["file_bytes"] = (OUT / f"{name}.glb").stat().st_size
        info["texture_sizes"] = {m: list(bpy.data.images[m + "_Color"].size) for m in info["materials"]}
        info["registry_file"] = "assets/BELLWOOD_KIT_UPLOADED.json"
    manifest["textures"] = {i.name: list(i.size) for i in bpy.data.images if i.name.startswith("Bell_")}
    manifest["studio_import_notes"] = ["3D Importer per GLB; one MeshPart per sub-mesh (Piece__Sub), pivot at origin, base on z=0",
                                       "Per-material PBR in maps/ (Color, Normal OpenGL, Roughness, Metal for Bell_Bronze): one SurfaceAppearance per material",
                                       "Rope_Bridge_Deck_A/B are modular 8-stud segments along Y: chain them, rotate each a little for sag"]
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))

    sc, cam, ground = setup_render()
    figmat = bpy.data.materials.new("Fig")
    try:
        figmat.use_nodes = True
    except Exception:
        pass
    next(n for n in figmat.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.85, 0.42, 0.1, 1)
    fig, trees = make_figure(figmat), make_trees()
    allobjs = [o for objs in PIECES.values() for o in objs]
    shots = {}
    for name, objs in PIECES.items():
        for o in allobjs:
            o.hide_render = o not in objs
        lo, hi = bbox(objs)
        c, d = (lo + hi) / 2, (hi - lo).length
        w, h = max(hi.x - lo.x, hi.y - lo.y), hi.z - lo.z
        ground.scale, ground.location = (d * 0.9 + 8, d * 0.9 + 8, 1), Vector((c.x, c.y, 0))
        shoot(sc, cam, c + Vector((0.75, -1.0, 0.42)).normalized() * d * (0.8 if d < 20 else 1.25), c, 42, CAP / f"{name}.png")
        H = max(h, 5.5)
        D = max(H * 1.7, w + 8, 14)
        fx, fy = lo.x - 2.2 if h < 30 else -22.0, lo.y + 0.8 if h < 30 else -38.0
        eye, tgt, lens = Vector((c.x, lo.y - D, 5.0)), Vector((c.x, c.y, H * 0.45)), 30
        if name == "Bell_Tower_Ruined":
            eye, tgt, lens = Vector((0, -88, 5.0)), Vector((0, 0, 34)), 22
        if name == "Hermit_Hut":
            eye, tgt, lens, fx, fy = Vector((2, -42, 5.0)), Vector((0, 0, 7)), 26, -8.5, -17.5
        ground.scale, ground.location = (300, 300, 1), Vector((0, 0, 0))
        fig.location, fig.hide_render = (fx, fy, 0), False
        shoot(sc, cam, eye, tgt, lens, CAP / f"eye_{name}.png")
        fig.hide_render = True
        shots[name] = str(CAP / f"eye_{name}.png")
        if name == "Bell_Tower_Ruined":  # tree-line read: stand-in 44-56 stud trees, camera 5 studs at 330 studs, Roblox 70 degree vFOV
            trees.hide_render = False
            ground.scale = (2500, 2500, 1)
            shoot(sc, cam, Vector((0, -330, 5.0)), Vector((0, 0, 40)), 12 / math.tan(math.radians(35)), CAP / "Bell_Tower_Ruined_treeline_330.png", res=(1920, 1080), vert=True)
            shoot(sc, cam, Vector((0, -190, 5.0)), Vector((0, 0, 40)), 12 / math.tan(math.radians(35)), CAP / "Bell_Tower_Ruined_treeline_190.png", res=(1920, 1080), vert=True)
            trees.hide_render = True
    manifest["renders"] = shots
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))
    for o in allobjs:
        o.hide_render = False
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "bellwood_built_b.blend"), compress=True)
    # upload pack: reuse make_upload_pack.pack() (stdlib), then retarget registry + add file/texture sizes
    mup = (ROOT / "tools/blender/overworld/make_upload_pack.py").read_text(encoding="utf-8").split("\nsys.exit")[0]
    ns = {"__file__": str(ROOT / "tools/blender/overworld/make_upload_pack.py")}
    exec(mup, ns)
    problems = ns["pack"](OUT, UPL)
    um = json.loads((UPL / "upload_manifest.json").read_text())
    um["registry_file"] = "assets/BELLWOOD_KIT_UPLOADED.json"
    for n, p in um["pieces"].items():
        p["registry_file"] = "assets/BELLWOOD_KIT_UPLOADED.json"
        p["studio_target"] = f"ServerStorage/BellwoodKit/{n}"
        p["file_bytes"] = manifest["pieces"][n]["file_bytes"]
        p["texture_sizes"] = manifest["pieces"][n]["texture_sizes"]
        p["size_studs_xyz_blender"] = manifest["pieces"][n]["size_studs_xyz"]
    (UPL / "upload_manifest.json").write_text(json.dumps(um, indent=2) + "\n")
    print("BUILT_B_OK", json.dumps({k: v["sub_meshes"] for k, v in manifest["pieces"].items()}), "pack problems:", problems, flush=True)


main()
