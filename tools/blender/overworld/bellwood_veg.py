"""Bellwood vegetation kit (lane M1): trees, deadwood, shrubs, ferns, flowers, fungi, vines/moss, reeds, grass.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b -P tools/blender/overworld/bellwood_veg.py
  env VEG_ONLY=Name1,Name2 builds a subset; VEG_NORENDER=1 skips renders.

Reuses the helpers and the bark / leaf / fern / grass materials of slice_kit.py (exec'd without its main()), so the pieces share the
slice kit's visual language (same Bell_Bark / Bell_Leaf maps, ESE wind lean of crowns toward WNW). 1 BU = 1 stud, base centre at the
origin, Blender Z up (glTF export makes it Y up). Every sub-mesh is asserted < 18000 tris (in obj() and again on the exported GLB).
Per piece: GLB -> assets/source/overworld/bellwood_veg/, the upload pack + upload_manifest.json -> .../upload/bellwood_veg/, an eye-height
(5 stud) render beside a 5.5 stud reference figure -> outputs/.../captures/kit/bellwood_veg/, and one progress line in workers/21a-bell-veg.md.
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
exec(compile(_src.rsplit("\nmain()", 1)[0], "slice_kit.py", "exec"), globals())  # helpers + materials; its main() is not run

ROOT = HERE.parents[3]
OUT = ROOT / "assets/source/overworld/bellwood_veg"
UP = ROOT / "assets/source/overworld/upload/bellwood_veg"
CAP = ROOT / "outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg"
NOTE = ROOT / "outputs/claude-open-world-2026-11-14/workers/21a-bell-veg.md"
REGISTRY = "assets/BELLWOOD_KIT_UPLOADED.json"
ONLY = {s for s in os.environ.get("VEG_ONLY", "").split(",") if s}
NORENDER = bool(os.environ.get("VEG_NORENDER"))
TAU = 2 * math.pi


# ------------------------------------------------------------------------------------------ extra materials
def mk(name, col, h, rough, k=4.0, double=False):
    return material(name, save(name + "_Color", np.clip(col, 0, 1)), save(name + "_Roughness", np.clip(rough, 0, 1), True),
                    save(name + "_Normal", nmap(h, k), True), double=double)


def wood_end_mat():
    """Cut / broken end grain, rings centred in the tile (a disc of radius r maps to the whole tile)."""
    n = 512
    yy, xx = np.mgrid[0:n, 0:n]
    x, y = (xx + 0.5) / n * 2 - 1, (yy + 0.5) / n * 2 - 1
    r, ang = np.hypot(x, y), np.arctan2(y, x)
    wp = field(n, 1.2, 81) * 0.035
    ring = (0.5 + 0.5 * np.sin((r + wp) * TAU * 13)) ** 2
    col = np.array([0.64, 0.52, 0.36]) * (1 - ring[..., None] * 0.38)
    heart = np.clip((0.28 - r) / 0.2, 0, 1)[..., None]
    col = col * (1 - heart * 0.2) + np.array([0.5, 0.34, 0.2]) * heart * 0.2
    crack = np.exp(-((((ang / TAU * 9 + wp * 20) % 1.0) - 0.5) / 0.025) ** 2) * np.clip((r - 0.12) * 3, 0, 1)
    col *= 1 - 0.55 * crack[..., None]
    rot = np.clip((field(n, 1.4, 82) - 0.7) * 1.0, 0, 0.75)[..., None]
    col = col * (1 - rot) + np.array([0.26, 0.2, 0.13]) * rot
    bark = np.clip((r - 0.9) / 0.04, 0, 1)[..., None]
    col = col * (1 - bark) + np.array([0.19, 0.14, 0.10]) * bark
    h = 0.5 + 0.05 * ring - 0.25 * crack - 0.05 * rot[..., 0]
    return mk("Bell_WoodEnd", col, h, 0.85 + 0.05 * field(n, 1.0, 88), 5.0)


def moss_mat():
    n = 512
    f1, f2, f3, f4 = field(n, 1.2, 83), field(n, 0.7, 84), field(n, 1.6, 85), field(n, 0.3, 86)
    col = np.array([0.12, 0.26, 0.06]) * (0.78 + 0.22 * f1[..., None])
    tip = np.clip((f2 - 0.5) * 1.6, 0, 1)[..., None]
    col = col * (1 - tip) + np.array([0.32, 0.40, 0.10]) * tip * (0.85 + 0.15 * f1[..., None])
    col *= np.where(f3[..., None] < -0.9, 0.5, 1.0)
    return mk("Bell_Moss", col, 0.5 + 0.15 * f4 + 0.08 * f1, 0.92 - 0.05 * f1, 4.0)


CONIF_PTS = []


def conifer_mat():
    """Painted needle tile: ~1100 two-pixel needle strokes in five dark blue-greens over a near-black gap colour."""
    n = 512
    r = np.random.default_rng(91)
    col = np.zeros((n, n, 3))
    col[:] = (0.05, 0.12, 0.07)
    h = np.full((n, n), 0.3)
    mask = np.zeros((n, n), bool)
    tones = [(0.10, 0.26, 0.13), (0.13, 0.33, 0.16), (0.18, 0.40, 0.19), (0.07, 0.20, 0.12), (0.24, 0.44, 0.20)]
    for i in range(1100):
        cx, cy = r.integers(0, n, 2)
        a, L = r.uniform(0, np.pi), r.uniform(14, 28)
        t = np.linspace(-L / 2, L / 2, int(L) * 2)
        tone = np.array(tones[r.choice(5, p=[0.25, 0.3, 0.2, 0.15, 0.1])])
        for w in (0, 1):
            xs = ((cx + t * np.cos(a) + w * np.sin(a)).astype(int)) % n
            ys = ((cy + t * np.sin(a) - w * np.cos(a)).astype(int)) % n
            col[ys, xs] = tone * (0.75 + 0.35 * (t / L + 0.5))[:, None]
            h[ys, xs] = 0.55 + 0.0002 * i
            mask[ys, xs] = True
    ys, xs = np.nonzero(mask)
    sel = np.random.default_rng(5).choice(len(ys), 600)
    CONIF_PTS.extend(zip(((xs[sel] + 0.5) / n).tolist(), ((ys[sel] + 0.5) / n).tolist()))
    return mk("Bell_Conifer", np.clip(col * 1.2, 0, 1), h, 0.62 + 0.08 * field(n, 1.0, 92), 3.0)


PATCH = {"white": (0, 0, (0.93, 0.92, 0.86)), "yellow": (1, 0, (0.90, 0.68, 0.10)), "purple": (2, 0, (0.46, 0.22, 0.64)),
         "pink": (3, 0, (0.78, 0.32, 0.58)), "red": (0, 1, (0.58, 0.07, 0.08)), "stem": (1, 1, (0.13, 0.31, 0.07)),
         "leaf": (2, 1, (0.21, 0.40, 0.10)), "orange": (3, 1, (0.86, 0.38, 0.08)), "brown": (0, 2, (0.22, 0.12, 0.06)),
         "straw": (1, 2, (0.74, 0.64, 0.32)), "blue": (2, 2, (0.30, 0.40, 0.80))}


def PUV(name):
    c, r, _ = PATCH[name]
    return ((c + 0.5) / 4, (r + 0.5) / 4)


def bloom_mat():
    """Bell_Bloom: 256 px atlas of 4x4 flat-colour patches (petals, centres, berries, stems, cattail brown, straw); cards pick a patch by UV."""
    n = 256
    g = field(n, 1.0, 87)
    col = np.zeros((n, n, 3))
    col[:] = np.array(PATCH["leaf"][2])
    for c, r, rgb in PATCH.values():
        sl = (slice(r * 64, r * 64 + 64), slice(c * 64, c * 64 + 64))
        col[sl] = np.array(rgb) * (0.92 + 0.06 * g[sl][..., None])
    return mk("Bell_Bloom", col, 0.5 + 0.02 * g, 0.5 + 0.1 * g, 2.0)


def mushroom_mat():
    """Bell_Mushroom: 2x2 of 128 px patches: stem (0,0), brown cap (1,0), red spotted cap (0,1), gills (1,1). Caps use a top-down planar UV."""
    n, q = 256, 128
    g, g2 = field(n, 1.0, 96), field(n, 0.4, 97)
    r = np.random.default_rng(95)
    yy, xx = np.mgrid[0:n, 0:n]
    col, h = np.zeros((n, n, 3)), np.full((n, n), 0.5)
    sl = lambda c, rw: (slice(rw * q, rw * q + q), slice(c * q, c * q + q))
    s = sl(0, 0)
    col[s] = np.array([0.82, 0.76, 0.62]) * (0.86 + 0.08 * g[s][..., None] + 0.06 * np.sin(xx[s][..., None] * 1.4))
    h[s] = 0.5 + 0.1 * np.sin(xx[s] * 1.4)
    s = sl(1, 0)
    col[s] = np.array([0.34, 0.20, 0.11]) * (0.85 + 0.12 * g[s][..., None])
    col[s] = np.where(g2[s][..., None] > 1.5, np.array([0.52, 0.39, 0.25]), col[s])
    s = sl(0, 1)
    col[s] = np.array([0.60, 0.09, 0.07]) * (0.9 + 0.08 * g[s][..., None])
    ly, lx = np.mgrid[0:q, 0:q]
    for _ in range(18):
        a, rr_ = r.uniform(0, TAU), r.uniform(0, 48) ** 1.0
        cx, cy, sr = 64 + math.cos(a) * rr_, 64 + math.sin(a) * rr_, r.uniform(4.5, 8.5)
        m = (lx - cx) ** 2 + (ly - cy) ** 2 < sr ** 2
        sub = col[s]
        sub[m] = (0.92, 0.89, 0.80)
        col[s] = sub
    s = sl(1, 1)
    ang = np.arctan2(ly - 64, lx - 64)
    col[s] = np.array([0.52, 0.38, 0.26]) * (0.85 + 0.12 * np.sin(ang * 60)[..., None]) * (0.9 + 0.1 * g[s][..., None])
    return mk("Bell_Mushroom", col, h, 0.7 + 0.1 * g, 3.0)


# ------------------------------------------------------------------------------------------ helpers
def paint(bm, before, uv):
    """Flat-colour every face not in `before` (set(bm.faces) taken before the part was built) from one atlas point.
    Not an index slice: create_cone / create_icosphere free scratch faces, later faces reuse those slots, and bm.faces[n0:]
    then skipped new faces and hit old ones (Reed_Clump_B heads came out candy-striped with green sleeves)."""
    uvl = _uvl(bm)
    for f in bm.faces:
        if f in before:
            continue
        for l in f.loops:
            l[uvl].uv = uv


def disc(bm, c, n, r, sides=16, jit=0.0, bulge=0.0, rr=None):
    """Fan disc (end grain) facing n, rings tile centred; bulge moves the centre along n (negative = rotted hollow), jit roughens the rim."""
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


def cone_at(bm, base, axis, r0, r1, L, seg=6):
    """Closed cone from base along axis (r0 at the base, r1 at the far end)."""
    q = Vector(axis).normalized().to_track_quat("Z", "Y")
    vs = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r0, radius2=r1, depth=L)["verts"]
    for v in vs:
        v.co = Vector(base) + q @ (v.co + Vector((0, 0, L / 2)))


def moss_cushion(bm, c, rx, ry, rz, rr, sub=2):
    uvl = _uvl(bm)
    ox = Vector((rr.uniform(0, 50), rr.uniform(0, 50), rr.uniform(0, 50)))
    vs = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)["verts"]
    for v in vs:
        u = v.co.copy()
        k = 1 + 0.25 * fbm(u * 2.2 + ox, 2)
        v.co = Vector((u.x * rx * k, u.y * ry * k, max(u.z, -0.2) * rz * k)) + Vector(c)
    for f in {f for v in vs for f in v.link_faces}:
        for l in f.loops:
            l[uvl].uv = (l.vert.co.x / 4, l.vert.co.y / 4)


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


def root_arch(bark, a, r_in, reach, h, rad, ph=0.0, sides=6):
    pts, rs = [], []
    for t in (0, 0.14, 0.32, 0.52, 0.72, 0.88, 1.0):
        d = r_in + (reach - r_in) * t
        z = h * (1 - t) ** 1.8 + 0.35 * math.sin(math.pi * t) - 1.1 * t ** 3
        aa = a + 0.22 * math.sin(3 * t + ph)
        pts.append(Vector((math.cos(aa) * d, math.sin(aa) * d, z)))
        rs.append(rad * (1 - 0.72 * t ** 0.7))
    tube(bark, pts, rs, sides=sides)
    return pts


# ------------------------------------------------------------------------------------------ trees
def broadleaf(name, seed, H, zs, radii, sides, tiers, amt=5.0, wob=0.5, sd=3, roots=5, rn=(3.5, 3.5, 1.2, 6.0, 1.2), top=(6.0, 3.2, 1.2), stubs=()):
    rng.seed(seed)
    bark, mass, det = bmesh.new(), bmesh.new(), bmesh.new()
    trunk_tube(bark, trunk_pts(zs, H, amt, wob, sd), radii, sides, [(rn, 0.3 + 0.12 * i) for i in range(roots)], H)
    for z, a in stubs:
        limb(bark, trunk_pts([z], H, amt, wob, sd)[0], a, 4.5, 0.35, 0.8, steps=3, droop=0.3)
    for ti, (z, nb, ln, el, R) in enumerate(tiers):
        tier_limbs(bark, mass, det, H, amt, wob, sd, z, nb, ln, el, 1.1 - 0.12 * ti, R, 2.2, ti * 0.8)
    t = trunk_pts([zs[-1] + 0.5], H, amt, wob, sd)[0]
    crown_pad(mass, det, t, top[0], top[1], top[2], (0, 0), n_top=8)
    tuft(det, t + Vector((0, 0, 3.5)), Vector((0, 0, 1)), n=12, L=3.4)
    obj(name, "Bark", bark, MATS["Bell_Bark"], smooth=True)
    obj(name, "Leaves_Mass", mass, MATS["Bell_Leaf"], smooth=True)
    obj(name, "Leaves_Detail", det, MATS["Bell_Leaf"], recalc=False)


def tree_c():
    broadleaf("Canopy_Tree_C", 211, 44.0, [-1, 4, 10, 18, 26, 34, 42], [3.2, 2.2, 1.8, 1.5, 1.2, 0.9, 0.5], 9,
              ((16.0, 4, 11.0, 0.5, 8.0), (23.0, 4, 10.0, 0.58, 7.2), (30.0, 3, 8.5, 0.62, 6.4), (36.5, 3, 6.5, 0.7, 5.0)),
              amt=5.5, wob=0.5, sd=11, top=(5.2, 3.0, 1.1), stubs=((8.0, 0.4), (12.0, 3.6), (14.5, 5.2)))


def tree_d():
    broadleaf("Canopy_Tree_D", 221, 30.0, [-1, 3, 7, 12, 18, 24, 29], [4.4, 3.0, 2.6, 2.2, 1.7, 1.2, 0.6], 10,
              ((12.0, 5, 15.0, 0.35, 9.0), (18.0, 5, 13.0, 0.45, 8.5), (24.0, 4, 10.0, 0.55, 7.0)),
              amt=4.5, wob=0.75, sd=21, roots=6, rn=(4.0, 4.0, 1.4, 7.0, 1.5), top=(6.4, 3.0, 1.2), stubs=((6.0, 1.0), (9.5, 4.4)))


def needles(det, p, n, L):
    for _ in range(n):
        a, fr = rng.uniform(0, TAU), rng.uniform(0.3, 1.0)
        d = Vector((math.cos(a) * 0.8, math.sin(a) * 0.8, -0.15)) + Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 0))
        leaf(det, pad_pt(p, fr, a) - Vector((0, 0, 0.1)), d, L * rng.uniform(0.8, 1.2), L * 0.2, 0.35, rng.choice(CONIF_PTS), kite=True, tex=0.006)


def conifer():
    rng.seed(41)
    H = 66.0
    bark, mass, det = bmesh.new(), bmesh.new(), bmesh.new()
    zs = [-1, 4, 12, 22, 32, 42, 52, 60, 65.5]
    trunk_tube(bark, trunk_pts(zs, H, 4.0, 0.25, 31), [2.7, 1.9, 1.5, 1.2, 0.95, 0.72, 0.5, 0.28, 0.06], 8,
               [((3.0, 2.6, 0.9, 5.0, 0.9), 0.5 + 0.1 * i) for i in range(5)], H)
    z, k = 8.5, 0
    while z < H - 6:
        f = 1 - z / H
        st = trunk_pts([z], H, 4.0, 0.25, 31)[0]
        nb = 6 if f > 0.5 else 5
        ln = 1.8 + 10.5 * f ** 0.95
        for i in range(nb):
            az = k * 0.7 + i * TAU / nb + rng.uniform(-0.2, 0.2)
            L = ln * rng.uniform(0.85, 1.1)
            pts = limb(bark, st, az, L, -0.12, 0.38 * (0.4 + f), steps=3, droop=0.5, sides=5)
            c = st.lerp(pts[-1], 0.62)
            p = pad_p(c + Vector((0, 0, 0.5)), max(1.6, L * 0.55), 0.5, 1.5 + 3.5 * f, (-0.15 * math.cos(az), -0.15 * math.sin(az)))
            pad(mass, p, nseg=12, rings=3)
            needles(det, p, 18, 2.0 + 2.2 * f)
        z += 3.4 - 0.9 * (1 - f)
        k += 1
    top = trunk_pts([H - 4.0], H, 4.0, 0.25, 31)[0]
    for _ in range(16):
        leaf(det, top + Vector((0, 0, rng.uniform(0, 3.5))), Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 1)), rng.uniform(1.6, 3.0), 0.5,
             0.2, rng.choice(CONIF_PTS), kite=True, tex=0.006)
    obj("Conifer_Tall", "Bark", bark, MATS["Bell_Bark"], smooth=True)
    obj("Conifer_Tall", "Needles_Mass", mass, MATS["Bell_Conifer"], smooth=True)
    obj("Conifer_Tall", "Needles_Detail", det, MATS["Bell_Conifer"], recalc=False)


def gnarled():
    rng.seed(55)
    H = 26.0
    bark, mass, det = bmesh.new(), bmesh.new(), bmesh.new()
    zs = [-1.5, 1.5, 5, 9, 13, 17, 21, 24.5]
    P = trunk_pts(zs, H, 3.0, 1.8, 57)
    trunk_tube(bark, P, [5.4, 4.5, 3.8, 3.3, 2.8, 2.3, 1.6, 0.7], 10,
               [((4.5, 4.5, 1.8, 9.0, 2.1 + 0.3 * (i % 2)), 0.1 * i) for i in range(7)], H)
    for i, (z, az, ln, el) in enumerate(((13, 0.4, 15, 0.35), (16, 2.2, 13, 0.5), (19, 3.9, 12, 0.45), (21.5, 5.4, 10, 0.6), (10, 1.3, 9, 0.2))):
        st = trunk_pts([z], H, 3.0, 1.8, 57)[0]
        pts = limb(bark, st, az, ln, el, 1.9 - 0.15 * i, steps=6, droop=1.1, sides=7)
        for j in (2, 4):
            sub = limb(bark, pts[j], az + rng.choice((-1, 1)) * rng.uniform(0.6, 1.0), ln * 0.5, 0.3, 0.7, steps=4, droop=0.9, sides=6)
            if rng.random() < 0.7:
                crown_pad(mass, det, sub[-1], 3.6, 1.6, 1.4, (0, 0), n_top=5, n_under=2, L=(2.4, 3.6))
            else:
                limb(bark, sub[-2], az + 1.2, 3.5, 0.2, 0.3, steps=3, droop=0.7, sides=5)  # bare dead twig
        if i % 2 == 0:
            crown_pad(mass, det, pts[-1], 4.8, 1.8, 1.6, (0, 0), n_top=6, n_under=2, L=(2.4, 3.8))
    top = trunk_pts([25.0], H, 3.0, 1.8, 57)[0]
    crown_pad(mass, det, top, 3.6, 1.8, 1.0, (0, 0), n_top=5, n_under=1, L=(2.4, 3.4))
    obj("Old_Gnarled_Tree", "Bark", bark, MATS["Bell_Bark"], smooth=True)
    obj("Old_Gnarled_Tree", "Leaves_Mass", mass, MATS["Bell_Leaf"], smooth=True)
    obj("Old_Gnarled_Tree", "Leaves_Detail", det, MATS["Bell_Leaf"], recalc=False)


def sapling():
    rng.seed(66)
    H = 13.0
    bark, mass, det = bmesh.new(), bmesh.new(), bmesh.new()
    zs = [-0.5, 2.5, 6, 9.5, 12.5]
    trunk_tube(bark, trunk_pts(zs, H, 2.5, 0.3, 71), [0.85, 0.6, 0.45, 0.3, 0.12], 6, [((1.6, 1.6, 0.6, 3.0, 0.45), 0.2 + 0.3 * i) for i in range(4)], H)
    tier_limbs(bark, mass, det, H, 2.5, 0.3, 71, 5.5, 3, 5.5, 0.65, 0.35, 3.4, 1.4, 0.4)
    tier_limbs(bark, mass, det, H, 2.5, 0.3, 71, 9.0, 3, 4.0, 0.7, 0.28, 2.6, 1.2, 1.7, fork=False)
    top = trunk_pts([12.8], H, 2.5, 0.3, 71)[0]
    crown_pad(mass, det, top, 2.4, 1.5, 0.6, (0, 0), n_top=6, n_under=2, L=(2.2, 3.2))
    obj("Sapling_Tree", "Bark", bark, MATS["Bell_Bark"], smooth=True)
    obj("Sapling_Tree", "Leaves_Mass", mass, MATS["Bell_Leaf"], smooth=True)
    obj("Sapling_Tree", "Leaves_Detail", det, MATS["Bell_Leaf"], recalc=False)


def dead_trunk():
    rng.seed(77)
    H = 34.0
    bark, ends = bmesh.new(), bmesh.new()
    zs = [-1.5, 3, 9, 15, 21, 27, 31.5]
    P = trunk_pts(zs, H, 1.5, 0.45, 81)
    trunk_tube(bark, P, [3.4, 2.6, 2.2, 1.9, 1.6, 1.35, 1.15], 9, [((3.8, 3.6, 1.2, 6.5, 1.3), 0.3 + 0.12 * i) for i in range(5)], H)
    top = P[-1]
    for i in range(7):  # snapped top: ragged splinters standing on the break
        a = i * TAU / 7 + rng.uniform(-0.2, 0.2)
        ln = rng.uniform(1.5, 6.5) if i % 2 == 0 else rng.uniform(0.6, 2.2)
        b = top + Vector((math.cos(a) * 0.65, math.sin(a) * 0.65, 0))
        tube(bark, [b, b + Vector((math.cos(a) * 0.15, math.sin(a) * 0.15, ln * 0.5)), b + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, ln))],
             [0.62, 0.45, 0.04], sides=4)
    disc(ends, top + Vector((0, 0, 0.04)), (0, 0, 1), 1.05, sides=14, jit=0.5, bulge=-0.5)
    for z, az, ln, el in ((12, 0.5, 9, 0.35), (17, 3.4, 7.5, 0.45), (22, 5.4, 6, 0.5)):  # bare limbs with a bare fork
        pts = limb(bark, trunk_pts([z], H, 1.5, 0.45, 81)[0], az, ln, el, 0.7, steps=4, droop=0.5)
        limb(bark, pts[2], az + 0.8, ln * 0.5, 0.3, 0.3, steps=3, droop=0.5, sides=5)
    for z, az in ((8, 2.0), (25, 1.0), (19, 5.8)):
        limb(bark, trunk_pts([z], H, 1.5, 0.45, 81)[0], az, 2.6, 0.5, 0.45, steps=2, droop=0.2)
    obj("Dead_Standing_Trunk", "Bark", bark, MATS["Bell_Bark"], smooth=True)
    obj("Dead_Standing_Trunk", "Ends", ends, MATS["Bell_WoodEnd"], recalc=False)


# ------------------------------------------------------------------------------------------ deadwood
def log_body(bark, L, r0, r1, seed, sides=10, seg=14, bend=0.8, sink=0.35):
    pts, rad = [], []
    ox = seed * 1.7
    for i in range(seg + 1):
        t = i / seg
        r = (r0 + (r1 - r0) * t) * (1 + 0.07 * noise.noise(Vector((t * 5, ox, 1))))
        y = bend * math.sin(math.pi * t * 1.2 + ox) + 0.5 * noise.noise(Vector((t * 3, ox, 2)))
        z = r * 0.95 - sink + 0.25 * noise.noise(Vector((t * 4, ox, 3)))
        pts.append(Vector((-L / 2 + L * t, y, z)))
        rad.append(r)
    tube(bark, pts, rad, sides=sides, uvs=8.0)
    return pts, rad


def log_break(bark, ends, p, r, n, rr, rotted=False):
    """Splintered break at p facing n: end-grain disc + a few splinters."""
    n = Vector(n).normalized()
    disc(ends, p + n * 0.04, n, r * 0.96, sides=14, jit=0.45, bulge=-0.9 if rotted else 0.1, rr=rr)
    e1 = n.cross(Vector((0, 0, 1))).normalized()
    e2 = n.cross(e1)
    for i in range(4):
        a = rr.uniform(0, TAU)
        b = p + (e1 * math.cos(a) + e2 * math.sin(a)) * r * 0.8
        ln = rr.uniform(0.8, 3.0)
        tube(bark, [b, b + n * ln * 0.5, b + n * ln], [0.5, 0.35, 0.04], sides=4)


def log_piece(name, seed, L, r0, r1, root_end, nstubs, ncush, rotted=False, both_ends=False):
    rng.seed(seed)
    rr = random.Random(seed)
    bark, ends, moss = bmesh.new(), bmesh.new(), bmesh.new()
    pts, rad = log_body(bark, L, r0, r1, seed % 17 + 1)
    tx = (pts[-1] - pts[-2]).normalized()
    if root_end:  # upturned root plate at -X
        base = pts[0]
        uvl, ox = _uvl(bark), Vector((rr.uniform(0, 50), rr.uniform(0, 50), rr.uniform(0, 50)))
        vs = bmesh.ops.create_icosphere(bark, subdivisions=3, radius=1.0)["verts"]  # lifted root ball
        for v in vs:
            u = v.co.copy()
            k = 1 + 0.18 * fbm(u * 2 + ox, 2)
            v.co = Vector((u.x * 1.3 * k, u.y * rad[0] * 1.5 * k, u.z * rad[0] * 1.5 * k)) + base + Vector((-0.6, 0, 0.6))
        for f in {f for v in vs for f in v.link_faces}:
            for l in f.loops:
                l[uvl].uv = (l.vert.co.y / 6 + 0.3, l.vert.co.z / 6 + 0.3)
        for k in range(9):
            a = k * TAU / 9 + rr.uniform(-0.2, 0.2)
            c, s = math.cos(a), math.sin(a)
            p0 = base + Vector((-0.4, c * rad[0] * 1.1, s * rad[0] * 1.1 + 0.6))
            p1 = p0 + Vector((-1.6, c * 2.6, s * 2.6 + 0.6))
            p2 = p1 + Vector((-1.8, c * 2.0, s * 1.6 - 0.2))
            p3 = p2 + Vector((-1.4, c * 1.4, s * 1.0 - 0.8))
            for q in (p1, p2, p3):
                q.z = max(q.z, -0.7)  # roots end buried, not hanging 5 studs under the ground
            tube(bark, [p0, p1, p2, p3], [0.8, 0.6, 0.38, 0.16], sides=6)
    else:
        log_break(bark, ends, pts[0], rad[0], -tx, rr, rotted)
    log_break(bark, ends, pts[-1], rad[-1], tx, rr, rotted)
    for _ in range(nstubs):
        i = rr.randint(2, len(pts) - 3)
        a, ln = rr.uniform(0, TAU), rr.uniform(1.4, 3.2)
        b = Vector((pts[i].x, pts[i].y, pts[i].z + rad[i] * 0.7))
        d = Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 1)).normalized()
        tube(bark, [b - d * 0.4, b + d * ln * 0.5, b + d * ln], [0.8, 0.65, 0.5], sides=6)  # broken branch stub
    for _ in range(ncush):
        i = rr.randint(1, len(pts) - 2)
        moss_cushion(moss, (pts[i].x + rr.uniform(-0.5, 0.5), pts[i].y + rr.uniform(-0.4, 0.4), pts[i].z + rad[i] * 0.88),
                     rr.uniform(1.0, 1.9), rr.uniform(0.8, 1.3), 0.45, rr)
    obj(name, "Bark", bark, MATS["Bell_Bark"], smooth=True)
    obj(name, "Ends", ends, MATS["Bell_WoodEnd"], recalc=False)
    obj(name, "Moss", moss, MATS["Bell_Moss"], smooth=True)


def stump(name, seed, h, r, hollow, nroots, ncush):
    rng.seed(seed)
    rr = random.Random(seed)
    bark, ends, moss = bmesh.new(), bmesh.new(), bmesh.new()
    pts = [Vector((0, 0, -1.0)), Vector((0.1, 0, 0.4)), Vector((0.15, 0.1, h * 0.55)), Vector((0.1, 0, h))]
    tube(bark, pts, [r * 1.35, r * 1.12, r * 1.0, r * 0.96], sides=12)
    for k in range(nroots):
        a = k * TAU / nroots + rr.uniform(-0.2, 0.2)
        root_arch(bark, a, r * 0.7, r * 2.8, h * 0.45, r * 0.42, ph=rr.uniform(0, 6))
    for i in range(4):  # splinters on the rim
        a = rr.uniform(0, TAU)
        b = Vector((0.1 + math.cos(a) * r * 0.85, math.sin(a) * r * 0.85, h))
        ln = rr.uniform(0.7, 2.0)
        tube(bark, [b, b + Vector((0, 0, ln * 0.5)), b + Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, ln))], [0.8, 0.65, 0.12], sides=5)
    disc(ends, Vector((0.1, 0, h + 0.04)), (0, 0, 1), r * 0.92, sides=18, jit=0.4, bulge=-hollow, rr=rr)
    for _ in range(ncush):
        a = rr.uniform(0, TAU)
        d = r * rr.uniform(0.9, 1.9)
        moss_cushion(moss, (math.cos(a) * d, math.sin(a) * d, max(0.1, h * 0.9 if d < r * 1.05 else 0.2)), rr.uniform(0.8, 1.5), rr.uniform(0.7, 1.2), 0.4, rr)
    obj(name, "Bark", bark, MATS["Bell_Bark"], smooth=True)
    obj(name, "Ends", ends, MATS["Bell_WoodEnd"], recalc=False)
    obj(name, "Moss", moss, MATS["Bell_Moss"], smooth=True)


def roots_a():
    rng.seed(151)
    bark = bmesh.new()
    moss = bmesh.new()
    cyl(bark, 0, 0, -0.8, 2.6, 1.9, 3.8, seg=10, uvs=8.0)
    for k in range(8):
        root_arch(bark, k * TAU / 8 + rng.uniform(-0.15, 0.15), 1.2, rng.uniform(8.0, 11.5), 3.0, 1.5, ph=rng.uniform(0, 6))
    for k in range(6):
        a, d = k * TAU / 6 + 0.3, rng.uniform(3.4, 5.0)
        moss_cushion(moss, (math.cos(a) * d, math.sin(a) * d, 0.1), rng.uniform(1.2, 2.0), rng.uniform(1.0, 1.6), 0.45, rng)
    obj("Exposed_Roots_A", "Bark", bark, MATS["Bell_Bark"], smooth=True)
    obj("Exposed_Roots_A", "Moss", moss, MATS["Bell_Moss"], smooth=True)


def roots_b():
    rng.seed(161)
    bark, moss = bmesh.new(), bmesh.new()
    for k in range(11):
        a = k * TAU / 11 + rng.uniform(-0.2, 0.2)
        pts = root_arch(bark, a, 0.4, rng.uniform(7.0, 10.0), 2.0 + rng.uniform(0, 0.8), 1.1, ph=rng.uniform(0, 6), sides=5)
        if k % 3 == 0:  # forked side root
            p = pts[3]
            d = Vector((math.cos(a + 0.9), math.sin(a + 0.9), 0))
            tube(bark, [p, p + d * 2.2 + Vector((0, 0, 0.3)), p + d * 4.4 + Vector((0, 0, -0.4)), p + d * 6.0 + Vector((0, 0, -0.9))],
                 [0.4, 0.32, 0.2, 0.1], sides=5)
    tube(bark, [Vector((0, 0, -0.8)), Vector((0.1, 0, 1.0)), Vector((0, 0.1, 2.4))], [1.7, 1.4, 1.0], sides=8)
    for k in range(5):
        a, d = k * TAU / 5 + 0.5, rng.uniform(2.6, 4.2)
        moss_cushion(moss, (math.cos(a) * d, math.sin(a) * d, 0.1), rng.uniform(1.0, 1.7), rng.uniform(0.9, 1.4), 0.4, rng)
    obj("Exposed_Roots_B", "Bark", bark, MATS["Bell_Bark"], smooth=True)
    obj("Exposed_Roots_B", "Moss", moss, MATS["Bell_Moss"], smooth=True)


# ------------------------------------------------------------------------------------------ shrubs, ferns
def shrub2(name, S, nstems, seed, depth=2, el=(0.85, 1.25), L0=3.4, leafk=1.0, berries=False):
    """slice_kit.shrub with a tunable stem elevation / length / leaf size and optional berries (Bell_Bloom red patch)."""
    rr = random.Random(seed)
    stems, det, ber = bmesh.new(), bmesh.new(), bmesh.new()

    def lf(p, d, L):
        L *= leafk
        leaf(det, p, d, L, L * rr.uniform(0.42, 0.55), rr.uniform(0.15, 0.4), rr.choice(LEAF_PTS), tex=0.006)

    def burst(p, ax, n, L):
        ax = ax.normalized()
        e1 = ax.cross(Vector((0, 0, 1)))
        if e1.length < 0.2:
            e1 = ax.cross(Vector((1, 0, 0)))
        e1.normalize()
        e2 = ax.cross(e1)
        for _ in range(n):
            t, ph = rr.uniform(0.2, 1.1), rr.uniform(0, 6.283)
            lf(p, ax * math.cos(t) + (e1 * math.cos(ph) + e2 * math.sin(ph)) * math.sin(t), L * rr.uniform(0.75, 1.15))

    def berry(c):
        n0 = set(ber.faces)
        vs = bmesh.ops.create_icosphere(ber, subdivisions=1, radius=0.17 * S + 0.06)["verts"]
        for v in vs:
            v.co += c
        paint(ber, n0, PUV("red"))

    def branch(p, d, L, r, dep):
        pts, dd = [p], d.normalized()
        for _ in range(3):
            dd = (dd + Vector((rr.uniform(-0.3, 0.3), rr.uniform(-0.3, 0.3), rr.uniform(-0.3, 0.05)))).normalized()
            pts.append(pts[-1] + dd * (L / 3))
        pts = [q + lean(q.z, 6.0 * S, 0.5 * S) for q in pts]
        tube(stems, pts, [r, r * 0.82, r * 0.64, r * 0.45], sides=5, uvs=4.0)
        if dep > 0:
            for _ in range(rr.choice((2, 3))):
                nd = dd * 0.7 + Vector((rr.uniform(-1, 1), rr.uniform(-1, 1), rr.uniform(-0.2, 0.6)))
                branch(pts[rr.choice((1, 2, 3))], nd, L * 0.62, r * 0.5, dep - 1)
            if dep == depth:
                side = dd.cross(Vector((0, 0, 1))).normalized()
                lf(pts[1], dd * 0.4 + side * 0.9, 1.7 * S)
                lf(pts[1], dd * 0.4 - side * 0.9, 1.7 * S)
        else:
            side = dd.cross(Vector((0, 0, 1))).normalized()
            for i in (2, 3):
                for sg in (-1, 1):
                    lf(pts[i], dd * 0.45 + side * 0.8 * sg + Vector((0, 0, 0.25)), 1.6 * S)
                if berries:
                    for _ in range(2):
                        berry(pts[i] + Vector((rr.uniform(-0.35, 0.35), rr.uniform(-0.35, 0.35), -rr.uniform(0.1, 0.5))) * S)
            burst(pts[-1], dd + Vector((0, 0, 0.3)), 6, 1.9 * S)

    for i in range(nstems):
        az, e = i * TAU / nstems + rr.uniform(-0.3, 0.3), rr.uniform(*el)
        branch(Vector((rr.uniform(-0.3, 0.3) * S, rr.uniform(-0.3, 0.3) * S, -0.3)),
               Vector((math.cos(az) * math.cos(e), math.sin(az) * math.cos(e), math.sin(e))), L0 * S * rr.uniform(0.9, 1.15), 0.45 * S, depth)
    obj(name, "Stems", stems, MATS["Bell_Bark"], smooth=True)
    obj(name, "Leaves", det, MATS["Bell_Leaf"], recalc=False)
    if berries:
        obj(name, "Berries", ber, MATS["Bell_Bloom"], smooth=True)


def fern2(name, seed, nf, Lo, Li, tho, thi, arch, npin, pang, plen, pw, every=3):
    rng.seed(seed)
    bm = bmesh.new()
    uvl = _uvl(bm)
    for i in range(nf):
        az = i * TAU / nf + rng.uniform(-0.2, 0.2)
        out = Vector((math.cos(az), math.sin(az), 0))
        side = Vector((-math.sin(az), math.cos(az), 0))
        inner = i % every == 0
        Lf = rng.uniform(*(Li if inner else Lo))
        th = rng.uniform(*(thi if inner else tho))
        pts = [Vector((0, 0, 0))]
        for k in range(1, 9):
            th_k = th - (k / 8) * arch
            pts.append(pts[-1] + (out * math.cos(th_k) + Vector((0, 0, math.sin(th_k)))) * (Lf / 8))
        pts = [p + lean(p.z, 6.0, 0.5) for p in pts]
        for k in range(8):
            w0, w1 = 0.13 * (1 - k / 9), 0.13 * (1 - (k + 1) / 9)
            q = [bm.verts.new(pts[k] - side * w0), bm.verts.new(pts[k + 1] - side * w1), bm.verts.new(pts[k + 1] + side * w1), bm.verts.new(pts[k] + side * w0)]
            qb = [bm.verts.new(v.co) for v in q]
            uv = ((0.44, k / 8), (0.44, (k + 1) / 8), (0.56, (k + 1) / 8), (0.56, k / 8))
            for f, order in ((bm.faces.new(q), range(4)), (bm.faces.new(qb[::-1]), range(3, -1, -1))):
                for l, j in zip(f.loops, order):
                    l[uvl].uv = uv[j]
        for j in range(npin):
            t = 0.1 + 0.88 * j / (npin - 1)
            kk = min(int(t * 8), 7)
            pos = pts[kk].lerp(pts[kk + 1], t * 8 - kk)
            tan = (pts[kk + 1] - pts[kk]).normalized()
            ln = Lf * plen * max(0.18, math.sin(math.pi * t ** 0.65) ** 0.9)
            for sg in (-1, 1):
                leaf(bm, pos, tan * math.cos(pang) + side * sg * math.sin(pang), ln, ln * pw, 0.45, kite=True, uvf=lambda tt, ss: (0.5 + ss * 0.45, tt))
    obj(name, "Fronds", bm, MATS["Bell_Fern"], smooth=True, recalc=False)


# ------------------------------------------------------------------------------------------ flowers, mushrooms
def flowers_daisy():
    rng.seed(111)
    stems, bl = bmesh.new(), bmesh.new()
    for _ in range(24):
        a, r = rng.uniform(0, TAU), rng.uniform(0, 2.4) ** 1.1
        base = Vector((math.cos(a) * r, math.sin(a) * r, -0.1))
        h = rng.uniform(2.2, 4.0)
        bend = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0.2, 0.7) + WIND * 0.35
        pts = [base + bend * (k / 3) ** 2 * 1.2 + Vector((0, 0, h * k / 3)) for k in range(4)]
        n0 = set(stems.faces)
        tube(stems, pts, [0.09, 0.08, 0.07, 0.06], sides=4, uvs=1.0)
        paint(stems, n0, PUV("stem"))
        top, d = pts[-1], (pts[-1] - pts[-2]).normalized()
        e1 = d.cross(Vector((0, 0, 1))).normalized()
        e2 = d.cross(e1)
        for k in range(9):
            ph = TAU * k / 9
            leaf(bl, top, (e1 * math.cos(ph) + e2 * math.sin(ph)) * 0.95 + d * 0.25, 0.7, 0.34, 0.0, PUV("white"), tex=0.006)
        n0 = set(bl.faces)
        disc(bl, top + d * 0.05, d, 0.32, sides=8, bulge=0.12)
        paint(bl, n0, PUV("yellow"))
        for _ in range(2):  # basal leaves
            ba = rng.uniform(0, TAU)
            leaf(bl, base + Vector((0, 0, 0.1)), Vector((math.cos(ba), math.sin(ba), 0.5)), rng.uniform(1.2, 2.0), 0.4, 0.25, PUV("leaf"), tex=0.006)
    obj("Flowers_Daisy", "Stems", stems, MATS["Bell_Bloom"], smooth=False)
    obj("Flowers_Daisy", "Blooms", bl, MATS["Bell_Bloom"], recalc=False)


def flowers_foxglove():
    rng.seed(121)
    stems, bl = bmesh.new(), bmesh.new()
    for i in range(6):
        a, r = i * TAU / 6 + rng.uniform(-0.3, 0.3), rng.uniform(0.3, 1.8)
        base = Vector((math.cos(a) * r, math.sin(a) * r, -0.1))
        h = rng.uniform(3.8, 6.0)
        bend = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0.1, 0.5) + WIND * 0.3
        pts = [base + bend * (k / 4) ** 2 * 1.2 + Vector((0, 0, h * k / 4)) for k in range(5)]
        n0 = set(stems.faces)
        tube(stems, pts, [0.14, 0.12, 0.1, 0.08, 0.05], sides=5, uvs=1.0)
        paint(stems, n0, PUV("stem"))
        for j in range(14):
            t = 0.45 + 0.55 * j / 13
            kk = min(int(t * 4), 3)
            pos = pts[kk].lerp(pts[kk + 1], t * 4 - kk)
            ang = j * 2.4 + i
            out = Vector((math.cos(ang), math.sin(ang), 0))
            n0 = set(bl.faces)
            cone_at(bl, pos, out * 0.8 - Vector((0, 0, 0.55)), 0.06, 0.3 * (1.0 - 0.35 * t), 0.62, seg=6)
            paint(bl, n0, PUV(rng.choice(("purple", "purple", "pink"))))
        for k in range(8):  # rosette
            ba = k * TAU / 8 + rng.uniform(-0.2, 0.2)
            leaf(bl, base + Vector((0, 0, 0.1)), Vector((math.cos(ba), math.sin(ba), 0.55)), rng.uniform(2.0, 3.0), 0.9, 0.3, PUV("leaf"), tex=0.006)
    obj("Flowers_Foxglove", "Stems", stems, MATS["Bell_Bloom"], smooth=False)
    obj("Flowers_Foxglove", "Blooms", bl, MATS["Bell_Bloom"], recalc=False)


def mushroom(bm, x, y, h, cr, kind, tilt, rr):
    uvl = _uvl(bm)
    sr = cr * 0.22
    ch = cr * 0.55
    n0 = len(bm.faces)
    lathe(bm, [(0.02, 0), (sr * 1.3, 0), (sr * 1.1, h * 0.15), (sr, h * 0.6), (sr * 0.85, h), (0.02, h)], seg=10, turns=1, uvs=4.0)
    n1 = len(bm.faces)
    lathe(bm, [(0.02, h + ch), (cr * 0.45, h + ch * 0.93), (cr * 0.8, h + ch * 0.62), (cr, h + ch * 0.15), (cr * 0.97, h - ch * 0.04),
               (cr * 0.55, h + ch * 0.05), (sr, h + ch * 0.02), (0.02, h + ch * 0.02)], seg=10, turns=1, uvs=4.0)
    bm.faces.ensure_lookup_table()
    cap_c = (0.75, 0.25) if kind == "brown" else (0.25, 0.75)
    for i, f in enumerate(bm.faces[n0:]):
        is_cap = n0 + i >= n1
        under = is_cap and (n0 + i - n1) // 10 >= 4  # lathe face index = profile segment * seg + k; segments 4.. are the gill side
        for l in f.loops:
            co = l.vert.co
            if not is_cap:
                l[uvl].uv = (0.25 + 0.18 * math.atan2(co.y, co.x) / math.pi, 0.25 + 0.2 * (co.z / h - 0.5))
            elif under:
                l[uvl].uv = (0.75 + co.x / cr * 0.2, 0.75 + co.y / cr * 0.2)
            else:
                l[uvl].uv = (cap_c[0] + co.x / cr * 0.22, cap_c[1] + co.y / cr * 0.22)
    M = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(tilt, 4, Vector((rr.uniform(-1, 1), rr.uniform(-1, 1), 0)).normalized())
    for v in {v for f in bm.faces[n0:] for v in f.verts}:
        v.co = M @ v.co


def mushrooms():
    rng.seed(171)
    rr = random.Random(171)
    bm = bmesh.new()
    placed = []
    kinds = [("brown", (2.2, 3.4), (0.9, 1.3))] * 3 + [("red", (1.0, 1.8), (1.0, 1.5))] * 4 + [("brown", (0.6, 1.1), (0.4, 0.6))] * 5
    for kind, hr, cr in kinds:
        for _ in range(40):
            a, d = rr.uniform(0, TAU), rr.uniform(0, 3.4)
            p = (math.cos(a) * d, math.sin(a) * d)
            if all(math.hypot(p[0] - q[0], p[1] - q[1]) > q[2] + 0.9 for q in placed):
                break
        c = rr.uniform(*cr)
        placed.append((p[0], p[1], c))
        mushroom(bm, p[0], p[1], rr.uniform(*hr), c, kind, rr.uniform(0, 0.25), rr)
    obj("Mushroom_Cluster", "Caps", bm, MATS["Bell_Mushroom"], smooth=True)


# ------------------------------------------------------------------------------------------ vines, moss
def support(bark, seed, H=18.0, side=0.3):
    """Dead leaning post with a side branch: returns (trunk points, radii, branch points)."""
    zs, rad = [-1, 3, 8, 13, H], [1.6, 1.2, 1.0, 0.85, 0.6]
    P = trunk_pts(zs, H, 1.2, 0.3, seed)
    trunk_tube(bark, P, rad, 7, [((2.2, 2.2, 0.8, 4.0, 0.7), 0.3 + 0.2 * i) for i in range(3)], H)
    bpts = limb(bark, P[3], side, 10.0, 0.18, 0.95, steps=5, droop=0.15, sides=6)
    return P, zs, rad, bpts


def vine_hanging():
    rng.seed(131)
    rr = random.Random(132)
    bark, det = bmesh.new(), bmesh.new()
    P, zs, rad, bpts = support(bark, 141)
    helix = []
    for i in range(26):  # helical vine up the post
        t = i / 25
        z = 0.5 + 16.0 * t
        c = trunk_pts([z], 18.0, 1.2, 0.3, 141)[0]
        r_ = float(np.interp(z, zs, rad)) + 0.15
        a = TAU * 1.7 * t
        helix.append(Vector((c.x + math.cos(a) * r_, c.y + math.sin(a) * r_, z)))
    tube(bark, helix, [0.17 - 0.06 * i / 25 for i in range(26)], sides=4, uvs=2.0)
    for i in range(2, 26, 2):
        d = Vector((helix[i].x - P[0].x, helix[i].y - P[0].y, 0)).normalized() * 0.8 + Vector((rr.uniform(-0.4, 0.4), rr.uniform(-0.4, 0.4), 0.5))
        leaf(det, helix[i], d, rr.uniform(1.8, 2.6), 1.1, 0.3, rr.choice(LEAF_PTS), tex=0.006)
    for s in range(14):  # hanging strands
        st = bpts[rr.randint(1, 5)] + Vector((rr.uniform(-0.3, 0.3), rr.uniform(-0.3, 0.3), -0.3))
        ln, n = rr.uniform(6.0, 13.0), 8
        ph = rr.uniform(0, 6.28)
        pts = [st + Vector((math.sin(ph + k / n * 2.2) * 0.6 * k / n + WIND.x * 0.3 * (k / n) ** 2, math.cos(ph * 1.3 + k / n * 1.7) * 0.6 * k / n + WIND.y * 0.3 * (k / n) ** 2,
                            -ln * k / n)) for k in range(n + 1)]
        tube(bark, pts, [0.22 - 0.12 * k / n for k in range(n + 1)], sides=4, uvs=2.0)
        for k in range(1, n + 1, 1):
            sg = 1 if k % 2 else -1
            for _ in range(2):
                d = Vector((rr.uniform(-1, 1), rr.uniform(-1, 1), 0.1))
                leaf(det, pts[k], d, rr.uniform(1.5, 2.4), 1.0 * rr.uniform(0.8, 1.2), 0.3, rr.choice(LEAF_PTS), tex=0.006)
    obj("Vine_Hanging", "Bark", bark, MATS["Bell_Bark"], smooth=True)
    obj("Vine_Hanging", "Leaves", det, MATS["Bell_Leaf"], recalc=False)


def moss_drape():
    rng.seed(135)
    rr = random.Random(136)
    bark, mo = bmesh.new(), bmesh.new()
    P, zs, rad, bpts = support(bark, 151, side=2.4)
    uvl = _uvl(mo)
    for s in range(30):
        st = bpts[rr.randint(0, 5)] + Vector((rr.uniform(-0.5, 0.5), rr.uniform(-0.5, 0.5), -0.2))
        ln, n = rr.uniform(5.0, 12.0), 6
        ph, w0 = rr.uniform(0, 6.28), rr.uniform(0.5, 0.9)
        side = Vector((math.cos(ph), math.sin(ph), 0))
        pts = [st + Vector((math.sin(ph + k / n * 2.0) * 0.5 * k / n + WIND.x * 0.4 * (k / n) ** 2, math.cos(ph * 1.3 + k / n) * 0.5 * k / n + WIND.y * 0.4 * (k / n) ** 2,
                            -ln * k / n)) for k in range(n + 1)]
        for k in range(n):
            wa, wb = w0 * (1 - 0.8 * k / n) * rr.uniform(0.85, 1.15), w0 * (1 - 0.8 * (k + 1) / n) * rr.uniform(0.85, 1.15)
            if k < n - 1:
                vs = [mo.verts.new(pts[k] - side * wa), mo.verts.new(pts[k] + side * wa), mo.verts.new(pts[k + 1] + side * wb), mo.verts.new(pts[k + 1] - side * wb)]
                uvs = ((0, k / n), (1, k / n), (1, (k + 1) / n), (0, (k + 1) / n))
            else:
                vs = [mo.verts.new(pts[k] - side * wa), mo.verts.new(pts[k] + side * wa), mo.verts.new(pts[k + 1])]
                uvs = ((0, k / n), (1, k / n), (0.5, 1))
            f = mo.faces.new(vs)
            for l, uv in zip(f.loops, uvs):
                l[uvl].uv = uv
    obj("Moss_Drape", "Bark", bark, MATS["Bell_Bark"], smooth=True)
    obj("Moss_Drape", "Moss", mo, MATS["Bell_HangMoss"], recalc=False)


# ------------------------------------------------------------------------------------------ reeds, grass
def clump(bm, n, hr, wr, spread, br, nseg, rr, wind=0.5, sag=0.12):
    for _ in range(n):
        a, r = rr.uniform(0, TAU), rr.uniform(0, spread) ** 1.2 if spread > 1 else rr.uniform(0, spread)
        base = Vector((math.cos(a) * r, math.sin(a) * r, -0.05))
        bend = Vector((math.cos(a), math.sin(a), 0)) * rr.uniform(*br) + WIND * wind
        blade(bm, base, bend, rr.uniform(*hr), rr.uniform(*wr), nseg, sag)


def reeds_a():
    rr = random.Random(181)
    bm = bmesh.new()
    clump(bm, 46, (4.5, 8.0), (0.22, 0.32), 1.7, (0.3, 1.2), 5, rr, wind=0.6)
    obj("Reed_Clump_A", "Blades", bm, MATS["Bell_Reed"], smooth=True, recalc=False)


def reeds_b():
    rr = random.Random(191)
    bm, hd = bmesh.new(), bmesh.new()
    clump(bm, 30, (3.6, 6.0), (0.38, 0.55), 1.9, (1.0, 2.2), 5, rr, wind=0.6, sag=0.25)
    for _ in range(8):  # cattails
        a, r = rr.uniform(0, TAU), rr.uniform(0, 1.6)
        h = rr.uniform(6.5, 9.0)
        base = Vector((math.cos(a) * r, math.sin(a) * r, -0.1))
        bend = Vector((math.cos(a), math.sin(a), 0)) * rr.uniform(0.2, 0.7) + WIND * 0.4
        pts = [base + bend * (k / 4) ** 2 * 1.2 + Vector((0, 0, h * k / 4)) for k in range(5)]
        n0 = set(hd.faces)
        tube(hd, pts, [0.1, 0.09, 0.08, 0.07, 0.05], sides=4, uvs=1.0)
        paint(hd, n0, PUV("stem"))
        d = (pts[-1] - pts[-2]).normalized()
        n0 = set(hd.faces)
        cone_at(hd, pts[-1] - d * 1.9, d, 0.3, 0.27, 1.6, seg=7)
        paint(hd, n0, PUV("brown"))
        n0 = set(hd.faces)
        cone_at(hd, pts[-1] - d * 0.3, d, 0.09, 0.02, 1.0, seg=5)
        paint(hd, n0, PUV("stem"))
    obj("Reed_Clump_B", "Blades", bm, MATS["Bell_Reed"], smooth=True, recalc=False)
    obj("Reed_Clump_B", "Heads", hd, MATS["Bell_Bloom"], smooth=True)


def grass_piece(name, seed, n, hr, wr, spread, br, nseg, seeds=0):
    rr = random.Random(seed)
    bm, sd = bmesh.new(), bmesh.new()
    clump(bm, n, hr, wr, spread, br, nseg, rr)
    for _ in range(seeds):
        a, r = rr.uniform(0, TAU), rr.uniform(0, spread)
        base = Vector((math.cos(a) * r, math.sin(a) * r, -0.05))
        h = rr.uniform(3.2, 5.0)
        bend = Vector((math.cos(a), math.sin(a), 0)) * rr.uniform(0.3, 0.9) + WIND * 0.4
        pts = [base + bend * (k / 3) ** 2 * 1.2 + Vector((0, 0, h * k / 3)) for k in range(4)]
        n0 = set(sd.faces)
        tube(sd, pts, [0.05, 0.045, 0.04, 0.03], sides=3, uvs=1.0)
        paint(sd, n0, PUV("straw"))
        d = (pts[-1] - pts[-2]).normalized()
        for _ in range(7):
            leaf(sd, pts[-1] - d * rr.uniform(0, 0.9), d + Vector((rr.uniform(-0.5, 0.5), rr.uniform(-0.5, 0.5), 0)), 0.6, 0.15, 0.1, PUV("straw"), kite=True, tex=0.006)
    obj(name, "Blades", bm, MATS["Bell_Grass"], smooth=True, recalc=False)
    if seeds:
        obj(name, "Seeds", sd, MATS["Bell_Bloom"], recalc=False)


# ------------------------------------------------------------------------------------------ build list (priority order)
BUILD = [
    ("Canopy_Tree_C", tree_c), ("Canopy_Tree_D", tree_d), ("Conifer_Tall", conifer), ("Old_Gnarled_Tree", gnarled), ("Sapling_Tree", sapling),
    ("Fallen_Log_A", lambda: log_piece("Fallen_Log_A", 301, 22.0, 1.9, 1.5, True, 4, 8)),
    ("Fallen_Log_B", lambda: log_piece("Fallen_Log_B", 302, 12.0, 2.4, 2.1, False, 2, 5, rotted=True)),
    ("Tree_Stump_A", lambda: stump("Tree_Stump_A", 311, 3.6, 3.2, 0.4, 7, 5)),
    ("Tree_Stump_B", lambda: stump("Tree_Stump_B", 312, 6.0, 2.6, 1.5, 6, 6)),
    ("Dead_Standing_Trunk", dead_trunk), ("Exposed_Roots_A", roots_a), ("Exposed_Roots_B", roots_b),
    ("Shrub_Hazel", lambda: shrub2("Shrub_Hazel", 1.0, 6, 103, el=(0.95, 1.35), L0=3.6, leafk=1.15)),
    ("Shrub_Thicket", lambda: shrub2("Shrub_Thicket", 1.1, 10, 104, el=(1.1, 1.4), L0=4.2, leafk=0.9)),
    ("Shrub_Berry", lambda: shrub2("Shrub_Berry", 0.6, 7, 105, el=(0.5, 0.95), L0=3.0, berries=True)),
    ("Fern_Bracken", lambda: fern2("Fern_Bracken", 401, 9, (6.5, 9.0), (5.0, 7.0), (1.15, 1.35), (1.3, 1.45), 1.7, 14, 1.1, 0.34, 0.42)),
    ("Fern_Sword", lambda: fern2("Fern_Sword", 402, 17, (5.0, 7.5), (4.0, 6.0), (1.0, 1.3), (1.3, 1.45), 1.2, 24, 0.85, 0.22, 0.17)),
    ("Flowers_Daisy", flowers_daisy), ("Flowers_Foxglove", flowers_foxglove), ("Mushroom_Cluster", mushrooms),
    ("Vine_Hanging", vine_hanging), ("Moss_Drape", moss_drape), ("Reed_Clump_A", reeds_a), ("Reed_Clump_B", reeds_b),
    ("Grass_Tall", lambda: grass_piece("Grass_Tall", 501, 70, (3.4, 5.6), (0.2, 0.3), 1.6, (0.5, 1.6), 4)),
    ("Grass_Lush", lambda: grass_piece("Grass_Lush", 502, 90, (1.4, 2.6), (0.18, 0.26), 1.7, (0.4, 1.1), 3)),
    ("Grass_Seed", lambda: grass_piece("Grass_Seed", 503, 48, (2.6, 4.2), (0.16, 0.24), 1.5, (0.4, 1.3), 4, seeds=16)),
]


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


PACK = {}  # name -> upload manifest entry


def write_pack():
    mats = sorted({m for p in PACK.values() for m in p["sub_mesh_materials"].values()})
    materials = {}
    for m in mats:
        maps = {}
        for slot, suf in (("ColorMap", "Color"), ("NormalMap", "Normal"), ("RoughnessMap", "Roughness")):
            f = OUT / "maps" / f"{m}_{suf}.png"
            if f.exists():
                shutil.copy2(f, UP / "maps" / f.name)
                maps[slot] = {"file": "maps/" + f.name, "size_px": list(bpy.data.images[f"{m}_{suf}"].size)}
        materials[m] = maps
    for p in PACK.values():
        p["maps_per_material"] = {m: materials[m] for m in sorted(set(p["sub_mesh_materials"].values()))}
    (UP / "upload_manifest.json").write_text(json.dumps({
        "format": "GLB (glTF 2.0, textures embedded; same maps also loose in maps/)",
        "units": "1 stud = 1 unit, Y up after import",
        "tri_cap_per_sub_mesh": TRI_CAP,
        "registry_file": REGISTRY,
        "registry_shape": {"pieces": {"<Piece>": {"<Piece>__<Sub>": {"MeshId": "rbxassetid://...", "ColorMap": "", "NormalMap": "", "RoughnessMap": ""}}}},
        "no_ids_yet": True,
        "studio_import_notes": ["3D Importer, Scale 1, one MeshPart per sub-mesh (Piece__Sub), pivot at base centre (Y up)",
                                "One SurfaceAppearance per material from maps/ (Color, Normal OpenGL, Roughness)",
                                "Bell_Grass / Bell_Reed blade strips are single sided: set DoubleSided = true on Grass_*__Blades and Reed_*__Blades",
                                "Cards/fronds are real two-sided geometry; Bell_Bloom, Bell_Mushroom, Bell_Conifer are flat-colour atlases: leave StudsPerTile default",
                                "Wind sway from height above the base pivot (no COLOR_0 exported); Leaves_Detail / Needles_Detail may be dropped beyond ~150 studs"],
        "pieces": PACK,
        "materials": materials,
    }, indent=2) + "\n")


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
    size = [round(hi[i] - lo[i], 2) for i in range(3)]
    shutil.copy2(path, UP / path.name)
    PACK[name] = {
        "name": name, "file": path.name, "sub_meshes": {k: v["tris"] for k, v in subs.items()},
        "sub_mesh_materials": {k: v["material"] for k, v in subs.items()}, "tris_total": sum(v["tris"] for v in subs.values()),
        "size_studs_xyz_roblox": size, "file_size_bytes": path.stat().st_size,
        "pivot": "base centre at origin (Y up); " + json.dumps({"min_y": round(lo[1], 3), "centre_x": round((lo[0] + hi[0]) / 2, 3), "centre_z": round((lo[2] + hi[2]) / 2, 3)}),
        "studio_target": f"ServerStorage/BellwoodKit/{name}", "registry_file": REGISTRY,
    }
    write_pack()
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
    next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.85, 0.32, 0.12, 1)
    me.materials.append(m)
    o = bpy.data.objects.new("Ref_Figure_5.5studs", me)
    bpy.context.scene.collection.objects.link(o)
    return o


def render_piece(name, objs, sc, cam, ground, fig):
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
    path = CAP / f"eye_{name}.png"
    shoot(sc, cam, Vector((tx, lo.y - D, 5.0)), Vector((tx, lo.y, tz)), lens, path)
    return path


def note(line):
    with open(NOTE, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def vignettes(sc, cam, ground, fig):
    for o in [o for os_ in PIECES.values() for o in os_]:
        o.hide_render = True
    ground.scale, ground.location = (600, 600, 1), Vector((0, 0, 0))
    fig.location = (3.5, 4.0, 0)
    have = lambda n: n in PIECES
    placements = [("Conifer_Tall", -30, 70, 0.3), ("Canopy_Tree_C", 26, 68, 1.0), ("Canopy_Tree_D", -52, 38, 2.0), ("Old_Gnarled_Tree", 16, 38, 0.5),
                  ("Sapling_Tree", -10, 26, 0.0), ("Dead_Standing_Trunk", 44, 48, 1.2), ("Fallen_Log_A", -20, 22, 0.5), ("Fallen_Log_B", 24, 18, 2.2),
                  ("Tree_Stump_A", -4, 14, 0.0), ("Tree_Stump_B", 12, 28, 0.7), ("Exposed_Roots_A", 6, 40, 0.0), ("Exposed_Roots_B", -36, 30, 1.0),
                  ("Shrub_Hazel", -12, 12, 0.3), ("Shrub_Thicket", 18, 10, 1.1), ("Shrub_Berry", 8, 6, 2.0), ("Fern_Bracken", -6, 8, 0.4),
                  ("Fern_Sword", 14, 20, 0.1), ("Flowers_Daisy", -2, 5, 0.0), ("Flowers_Foxglove", 3, 10, 0.5), ("Mushroom_Cluster", -9, 6, 0.0),
                  ("Vine_Hanging", 34, 28, 0.2), ("Moss_Drape", -26, 40, 0.8), ("Grass_Tall", 0, 16, 0.0), ("Grass_Lush", 6, 3, 0.0),
                  ("Grass_Seed", -14, 4, 0.0), ("Grass_Lush", -8, 16, 1.0), ("Grass_Tall", 20, 14, 2.0)]
    for nm, x, y, rz in placements:
        if have(nm):
            put(nm, x, y, 0, rz)
    shoot(sc, cam, Vector((0, -22, 5.0)), Vector((0, 40, 16)), 26, CAP / "vignette_forest_floor_player.png")
    shoot(sc, cam, Vector((-60, -40, 55)), Vector((0, 40, 12)), 30, CAP / "vignette_forest_high.png")
    clear_put()
    if have("Reed_Clump_A"):
        wm = bpy.data.materials.new("Water")
        try:
            wm.use_nodes = True
        except Exception:
            pass
        p = next(n for n in wm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        p.inputs["Base Color"].default_value = (0.05, 0.18, 0.25, 1)
        p.inputs["Roughness"].default_value = 0.1
        me = bpy.data.meshes.new("Water")
        me.from_pydata([(-80, 8, 0.1), (80, 8, 0.1), (80, 90, 0.1), (-80, 90, 0.1)], [], [(0, 1, 2, 3)])
        me.materials.append(wm)
        w = bpy.data.objects.new("Water", me)
        sc.collection.objects.link(w)
        for i in range(10):
            put("Reed_Clump_A" if i % 2 else "Reed_Clump_B", -36 + i * 8 + (i % 3) * 1.5, 9 + (i % 2) * 3, 0, i * 0.9)
        for nm, x, y, rz in (("Grass_Tall", -10, 3, 0), ("Grass_Lush", 6, 2, 1), ("Grass_Seed", -2, 4, 2), ("Flowers_Daisy", 10, 4, 0), ("Flowers_Foxglove", -16, 5, 0),
                             ("Fern_Sword", 18, 6, 0), ("Shrub_Berry", -22, 5, 0), ("Canopy_Tree_C", 20, 40, 0), ("Conifer_Tall", -28, 36, 0)):
            if have(nm):
                put(nm, x, y, 0, rz)
        shoot(sc, cam, Vector((0, -12, 5.0)), Vector((0, 30, 8)), 30, CAP / "vignette_wet_edge_player.png")
        clear_put()
        bpy.data.objects.remove(w)


def main():
    for d in (OUT / "maps", UP / "maps", CAP):
        d.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bark_mat(), leaf_mat()
    blade_mat("Bell_Fern", 256, 256, (0.08, 0.24, 0.07), (0.30, 0.50, 0.15), 61, double=False)
    blade_mat("Bell_Grass", 128, 256, (0.11, 0.20, 0.06), (0.60, 0.58, 0.30), 62)
    blade_mat("Bell_Reed", 128, 256, (0.14, 0.28, 0.07), (0.66, 0.60, 0.26), 63)
    blade_mat("Bell_HangMoss", 128, 256, (0.28, 0.40, 0.20), (0.58, 0.64, 0.46), 64)
    wood_end_mat(), moss_mat(), conifer_mat(), bloom_mat(), mushroom_mat()
    sc, cam, ground = setup_render()
    fig = make_figure()
    if ONLY and (UP / "upload_manifest.json").exists():  # a subset rebuild keeps the other pieces in the upload pack
        PACK.update(json.loads((UP / "upload_manifest.json").read_text())["pieces"])
    todo = [b for b in BUILD if not ONLY or b[0] in ONLY]
    for name, fn in todo:
        fn()
        info = export_piece(name, PIECES[name])
        png = "-" if NORENDER else str(render_piece(name, PIECES[name], sc, cam, ground, fig).relative_to(ROOT)).replace("\\", "/")
        note(f"- {name}: sub-meshes {json.dumps(info['sub_meshes'])}; tris {info['tris_total']}; size {info['size_studs_xyz_roblox']} studs; "
             f"GLB {info['file_size_bytes'] // 1024} KB; render {png}")
        print("VEG_PIECE", name, info["tris_total"], info["size_studs_xyz_roblox"], flush=True)
    if not NORENDER and len(todo) == len(BUILD):
        vignettes(sc, cam, ground, fig)
    for o in [o for os_ in PIECES.values() for o in os_]:
        o.hide_render = False
    if not ONLY:  # a subset scene would overwrite the whole-kit .blend
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "bellwood_veg_kit.blend"), compress=True)
    print("VEG_OK", len(PACK), "pieces", flush=True)


main()
