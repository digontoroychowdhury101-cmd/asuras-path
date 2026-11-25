"""Bellwood landmark: the ruined stone colonnade standing in the Sunken Temple's lake (LANDMARK-BUILD-SPEC section 1,
concept bellwood_3 midground left).

  /Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 -P tools/blender/landmarks/bellwood_colonnade.py -- [out_dir]
  default out_dir: assets/source/landmarks/bellwood_colonnade     env: COL_MODE=clay|bake  COL_PIECES=Standing,Toppled

Read from the concept: stocky columns about five diameters tall, carved in framed panels over the whole shaft and worn in
patches, on square plinths with heavy torus rings, under a flared capital and abacus; a moulded entablature (architrave,
frieze, cornice) in a few long settled blocks, snapped in steps at the ends, a broken attic course and moss on top; hanging
moss and narrow red cloth tied round the lintels; broken masonry piled at the feet.
  Standing: three columns, each a few degrees off true, under one sagging lintel that overhangs and snaps at both ends, and a
            fourth column broken to a stump with its capital fallen at its foot.
  Toppled:  a pair leaning the same way under a lintel snapped at both ends, a third column leaning hard the other way still
            carrying a snapped stub of its lintel, and a column fallen in drums in front.
Hard-surface LOW -> HIGH (own high(): fine subdivision, light chips, then carved shaft relief) -> vesp_bake per role
on CC0 Poly Haven bases (outputs/vesperhold/THIRD_PARTY.md):
  Stone   medieval_blocks_03, grey-green, heavy moss          (collision: hull, placed by LandmarkWorld)
  Vine    bark_willow_02 under blanket moss, hanging strands  (no collision)
  Ribbon  distressed_painted_planks re-tinted faded vermilion  (no collision)
Units studs, Z up. Pivot: footing centre on the lake bed (z = 0). Columns run along X; the kit front (+Y) faces the viewer.
"""
import math
import os
import random
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE.parent / "vesperhold"))
import bmesh  # noqa: E402
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import bellwood_temple_hall as H  # noqa: E402  (objects / src)
import vesperhold_figures as FG  # noqa: E402
import vesperhold_gargoyles as G  # noqa: E402
from lobby_kit_geo import Mesh  # noqa: E402
from vesperhold_figures import log  # noqa: E402

ROOT = HERE.parents[2]
BUILDER = "tools/blender/landmarks/bellwood_colonnade.py (mac-103, hard-surface + carved relief + Cycles bake)"
ROLES = ("Stone", "Vine", "Ribbon")

PITCH = 8.5  # column spacing along X
COL_H = 17.0  # plinth foot to capital top
R0, R1 = 1.75, 1.58  # shaft radius at foot, at neck (entasis between)
FOOT = 3.3  # shaft starts above plinth + torus
NECK = 2.6  # collar + capital height above the shaft
LH = 3.75  # entablature height
# Entablature cross-section, three courses as [(half-width, z)] up one side: architrave (two fasciae and a fillet), plain
# frieze, cornice (bed moulding, ovolo, corona). A snapped end loses more of each course going up, so breaks read stepped.
COURSES = (
    [(1.75, 0.0), (1.75, 0.75), (1.86, 0.75), (1.86, 1.5), (1.96, 1.5), (1.96, 1.68)],
    [(1.8, 1.68), (1.8, 2.72)],
    [(1.98, 2.72), (2.08, 2.84), (2.3, 3.0), (2.42, 3.2), (2.42, 3.55), (2.28, 3.75)],
)
WRAP = [(1.82, -0.06), (1.92, 0.75), (1.99, 1.6), (1.86, 2.7), (2.5, 3.2), (2.36, 3.82)]  # cloth loop just proud of COURSES


class Piece:
    def __init__(self, name):
        self.name = name
        self.meshes = {}
        self.shafts = []  # (M, z0, z1) per carved shaft, for relief()
        self.hang = []  # (point, length) hanging-moss anchors on lintel edges
        self.mats = []  # (M, radius) moss pads on top surfaces
        self.breaks = []  # (point, radius) snapped stone, roughened in high()

    def m(self, role):
        if role not in self.meshes:
            self.meshes[role] = Mesh(f"{self.name}__{role}", role, 8.0)
        return self.meshes[role]


def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


def rot(rx=0.0, ry=0.0, rz=0.0):
    return Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X")


def shaft_r(z, top):
    t = max(0.0, min(1.0, (z - FOOT) / max(top - FOOT, 1e-3)))
    return R0 + (R1 - R0) * t + 0.06 * math.sin(math.pi * t)  # slight entasis


def capital(s, M, rng, top):
    """Astragal bead, necking, flared echinus and a square abacus above a shaft ending at `top`; NECK tall."""
    rt = shaft_r(top, COL_H - NECK)
    s.lathe([(rt + 0.02, top), (rt + 0.24, top + 0.06), (rt + 0.3, top + 0.2), (rt + 0.24, top + 0.34), (rt, top + 0.4),
             (rt - 0.03, top + 0.95), (rt + 0.1, top + 1.0), (rt + 0.42, top + 1.22), (rt + 0.6, top + 1.52),
             (rt + 0.66, top + 1.85), (0.0, top + 1.85)], 28, M)
    s.box((0, 0, top + 2.225), (4.5, 4.5, 0.75), M @ rot(rz=rng.uniform(-0.05, 0.05)), bevel=0.14)


def column(pc, M, rng, height=COL_H, broken=None):
    """A column with its foot at M's origin, axis +Z. broken = shaft height left standing (ragged top, no capital)."""
    s = pc.m("Stone")
    j = lambda a: rng.uniform(-a, a)  # noqa: E731
    s.box((0, 0, 0.7), (4.8, 4.8, 1.4), M @ rot(rz=j(0.03)), bevel=0.22)  # plinth
    s.box((0, 0, 1.55), (4.1, 4.1, 0.35), M @ rot(rz=j(0.05)), bevel=0.1)
    s.lathe([(2.1, 1.7), (2.2, 1.95), (2.2, 2.25), (2.0, 2.5), (1.95, 2.6), (2.02, 2.75), (2.02, 2.95), (1.9, 3.1), (R0, FOOT)],
            28, M)  # two heavy torus rings
    top = height - NECK if broken is None else broken
    zs = [FOOT + (top - FOOT) * k / 14 for k in range(15)]
    prof = [(shaft_r(z, height - NECK) + rng.uniform(-0.03, 0.03), z) for z in zs]
    s.lathe(prof + [(0.0, top)], 28, M)
    pc.shafts.append((M, FOOT, top))
    if broken is not None:
        rt = shaft_r(top, height - NECK)
        for k in range(7):  # snapped top: ragged shards round the break
            a = 2 * math.pi * k / 7 + j(0.3)
            hgt = rng.uniform(0.4, 1.6)
            R = M @ T(0.62 * rt * math.cos(a), 0.62 * rt * math.sin(a), top + hgt / 2 - 0.15) @ rot(rx=j(0.3), rz=a)
            s.box((0, 0, 0), (0.85 * rt, 0.9, hgt), R, bevel=0.08)
        pc.breaks.append((M @ Vector((0, 0, top)), 2.4))
        return None
    capital(s, M, rng, top)
    return M @ Vector((0, 0, height))


def lintel(pc, a, b, rng, breaks=(), up=None):
    """Moulded entablature from point a to b (bottom-face centre line), in a few long settled blocks. breaks = 0 (a end) /
    1 (b end): that end is snapped, each course higher up broken further back. up = the beam's up axis (default world Z)."""
    s = pc.m("Stone")
    run = b - a
    length = run.length
    ux = run.normalized()
    uz = (up or Vector((0, 0, 1))).normalized()
    uz = (uz - ux * uz.dot(ux)).normalized()
    uy = uz.cross(ux)
    base = Matrix(((ux.x, uy.x, uz.x, a.x), (ux.y, uy.y, uz.y, a.y), (ux.z, uy.z, uz.z, a.z), (0, 0, 0, 1)))
    j = lambda v: rng.uniform(-v, v)  # noqa: E731
    n = max(1, round(length / 9.0))
    cuts = [0.0] + sorted(length * (k + j(0.15)) / n for k in range(1, n)) + [length]
    lost = [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]  # per end, per course: how far the break eats back
    for end in breaks:
        lost[end] = [rng.uniform(0.1, 0.5), rng.uniform(0.5, 1.2), rng.uniform(1.1, 2.3)]
    for k in range(n):
        xc = (cuts[k] + cuts[k + 1]) / 2
        settle = base @ T(xc, j(0.05), -rng.uniform(0.0, 0.08)) @ rot(rx=j(0.012), ry=j(0.01), rz=j(0.01)) @ T(-xc, 0, 0)
        for ci, course in enumerate(COURSES):
            x0 = cuts[k] + (0.03 if k else lost[0][ci])
            x1 = cuts[k + 1] - (0.03 if k < n - 1 else lost[1][ci])
            prof = [(w, z) for w, z in course] + [(-w, z) for w, z in reversed(course)]
            s.sweep(prof, [settle @ Vector((x0, 0, 0)), settle @ Vector((x1, 0, 0))], up=settle.to_3x3() @ Vector((0, 0, 1)))
    for end in breaks:  # spalls and a loose block at the snapped end
        x = lost[end][1] if end == 0 else length - lost[end][1]
        pc.breaks.append((base @ Vector((x, 0, LH / 2)), 3.2))
        for _ in range(4):
            M = base @ T(x + j(0.6), j(1.6), rng.uniform(0.3, 2.4)) @ rot(j(0.6), j(0.6), j(0.6))
            s.box((0, 0, 0), (rng.uniform(0.5, 1.1), rng.uniform(0.6, 1.2), rng.uniform(0.4, 0.9)), M, bevel=0.08)
    x = 0.4 + lost[0][2]
    while x < length - 1.0 - lost[1][2]:  # broken attic course on the cornice: low irregular stones, gaps where they fell
        w = rng.uniform(1.3, 3.4)
        if rng.random() > 0.28 and x + w < length - lost[1][2]:
            M = base @ T(x + w / 2, j(0.35), LH + 0.22) @ rot(rx=j(0.05), ry=j(0.07), rz=j(0.07))
            s.box((0, 0, 0), (w - 0.18, rng.uniform(2.4, 3.6), rng.uniform(0.35, 0.65)), M, bevel=0.12)
        if rng.random() < 0.45:
            pc.mats.append((base @ T(x + j(0.8), j(1.4), LH + 0.45) @ rot(rx=j(0.15), ry=j(0.15), rz=j(3.0)),
                            rng.uniform(0.7, 1.7)))
        x += w
    for k in range(int(length / 0.7)):  # moss anchors: the cornice drip edge and the architrave soffit, mostly the front
        x = (k + 0.5) * 0.7 + j(0.3)
        if x < lost[0][2] or x > length - lost[1][2]:
            continue
        side = 1 if rng.random() < 0.65 else -1
        drip = rng.random() < 0.55
        at = Vector((x, side * (2.4 if drip else 1.7), 3.2 if drip else 0.05))
        pc.hang.append((base @ at, rng.uniform(3.0, 6.5) if rng.random() < 0.25 else rng.uniform(0.6, 2.6)))
    return base, length


def cloth(pc, base, length, rng, at, tails=3):
    """A red cloth band tied round the lintel at fraction `at`, with narrow tails hanging off the front."""
    rb = pc.m("Ribbon")
    x = length * at
    ring = WRAP + [(-w, z) for w, z in reversed(WRAP)]
    loop = [base @ Vector((x + 0.08 * math.sin(i), w, z)) for i, (w, z) in enumerate(ring + ring[:1])]
    rb.sweep([(-0.28, -0.04), (0.28, -0.04), (0.28, 0.04), (-0.28, 0.04)], loop, up=base.to_3x3() @ Vector((1, 0, 0)))
    for t in range(tails):
        dx = (t - (tails - 1) / 2) * 0.45 + rng.uniform(-0.15, 0.15)
        top = base @ Vector((x + dx, 1.9, 0.2))
        L, sway, ph = rng.uniform(3.0, 11.0), rng.uniform(-0.9, 0.9), rng.uniform(0, 6.28)
        w = rng.uniform(0.18, 0.34)
        pts = [top + Vector((sway * (k / 9) ** 2 + 0.12 * math.sin(k * 1.4 + ph), 0.15 * k / 9 + 0.05 * math.sin(k * 0.9 + ph),
                             -L * k / 9)) for k in range(10)]
        rb.sweep([(-w, -0.035), (w, -0.035), (w, 0.035), (-w, 0.035)], pts, up=Vector((0, 1, 0)),
                 scales=[1.0 - 0.35 * k / 9 for k in range(10)])


def vines(pc, rng):
    """Hanging moss in tufts of thin wavy strands from the recorded anchors, and low moss pads on the top surfaces."""
    v = pc.m("Vine")
    prof = [(math.cos(a), math.sin(a)) for a in [2 * math.pi * k / 4 for k in range(4)]]
    for at, length in pc.hang:
        for _ in range(rng.randint(1, 3)):
            L = length * rng.uniform(0.45, 1.0)
            o = at + Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.12, 0.12), 0))
            sway, ph = Vector((rng.uniform(-0.4, 0.4), rng.uniform(-0.25, 0.25), 0)), rng.uniform(0, 6.28)
            pts = [o + sway * (k / 7) ** 2 + Vector((0.07 * math.sin(k * 2.1 + ph), 0.05 * math.cos(k * 1.7 + ph), -L * k / 7))
                   for k in range(8)]
            v.sweep(prof, pts, scales=[0.13 * (1 - 0.8 * k / 7) + 0.015 for k in range(8)])
    for M, r in pc.mats:
        h = r * 0.28
        v.lathe([(r, -0.1), (r * 0.92, 0.25 * h), (r * 0.68, 0.65 * h), (r * 0.32, 0.92 * h), (0.0, h)], 10,
                M @ Matrix.Diagonal((1.0, rng.uniform(0.5, 0.85), 1.0, 1.0)))


def rubble(pc, rng, cx, cy, spread, n, big=1.0):
    s = pc.m("Stone")
    for _ in range(n):
        w = rng.uniform(0.9, 2.4) * big
        M = T(cx + rng.uniform(-spread, spread), cy + rng.uniform(-spread, spread), w * 0.25) \
            @ rot(rng.uniform(-0.5, 0.5), rng.uniform(-0.4, 0.4), rng.uniform(0, 6.28))
        s.box((0, 0, 0), (w, w * rng.uniform(0.5, 0.9), w * rng.uniform(0.35, 0.7)), M, bevel=0.15)


def standing(pc):
    rng = random.Random(17)
    s = pc.m("Stone")
    s.box((0, 0, -0.8), (4 * PITCH + 6.0, 7.0, 1.6), bevel=0.2)  # footing, top at the bed
    caps = []
    for k, lean in enumerate((-6.0, -2.0, 2.5)):
        caps.append(column(pc, T((k - 1.5) * PITCH, rng.uniform(-0.3, 0.3), 0) @ rot(ry=math.radians(lean)), rng))
    column(pc, T(1.5 * PITCH, 0.2, 0) @ rot(ry=math.radians(3.0)), rng, broken=9.5)
    # one lintel over the three: overhangs the first column and snaps at both ends
    a = caps[0] + (caps[0] - caps[2]).normalized() * 3.8
    b = caps[2] + (caps[2] - caps[0]).normalized() * 2.6
    base, length = lintel(pc, a, b, rng, breaks=(0, 1))
    for at, n in ((0.12, 3), (0.36, 2), (0.6, 4), (0.84, 2)):
        cloth(pc, base, length, rng, at, n)
    # the fourth capital, fallen against its stump
    M = T(1.5 * PITCH + 3.6, 2.4, 0.4) @ rot(0.45, -0.35, 0.6)
    capital(s, M @ T(0, 0, -(COL_H - NECK)), rng, COL_H - NECK)
    rubble(pc, rng, 1.5 * PITCH + 2.0, -1.5, 3.0, 6)
    rubble(pc, rng, -1.5 * PITCH - 3.5, 1.0, 2.5, 5, big=0.8)
    vines(pc, rng)
    return max(c.z for c in caps) + LH + 1.2


def toppled(pc):
    rng = random.Random(29)
    s = pc.m("Stone")
    s.box((0, 0, -0.8), (4 * PITCH + 6.0, 8.0, 1.6), bevel=0.2)
    # a pair leaning the same way under one lintel, snapped at both ends
    pair = [column(pc, T(x, 0, 0) @ rot(ry=math.radians(a)), rng) for x, a in ((-0.2 * PITCH, 12.0), (0.8 * PITCH, 14.0))]
    run = (pair[1] - pair[0]).normalized()
    base, length = lintel(pc, pair[0] - run * 2.4, pair[1] + run * 4.4, rng, breaks=(0, 1))
    for at, n in ((0.22, 3), (0.55, 2), (0.8, 3)):
        cloth(pc, base, length, rng, at, n)
    # a third leaning hard the other way, still carrying a snapped stub of its lintel
    Ml = T(-1.3 * PITCH, -0.6, 0) @ rot(rx=math.radians(-3), ry=math.radians(-20))
    lone = column(pc, Ml, rng)
    d, upl = Ml.to_3x3() @ Vector((1, 0, 0)), Ml.to_3x3() @ Vector((0, 0, 1))
    base, length = lintel(pc, lone - d * 2.0, lone + d * 4.8, rng, breaks=(0, 1), up=upl)
    cloth(pc, base, length, rng, 0.45, 3)
    # a column fallen toward the viewer in three drums, capital furthest out
    foot = Vector((1.9 * PITCH, 5.0, 0.0))
    for k, (z0, z1) in enumerate(((FOOT, 7.6), (7.75, 11.2), (11.35, COL_H - NECK))):
        M = T(*(foot + Vector((0.5 * k, 0, 0)))) @ rot(rz=math.radians(100 + 6 * k)) \
            @ T(0, z0 + 0.25 * k, R0 - 0.15) @ rot(rx=-0.5 * math.pi) @ rot(ry=rng.uniform(-0.3, 0.3)) @ T(0, 0, -z0)
        s.lathe([(shaft_r(z0, COL_H - NECK), z0), (shaft_r(z1, COL_H - NECK), z1), (0.0, z1)], 28, M)
        pc.shafts.append((M, z0, z1))
        if k == 2:  # the capital stayed on the top drum
            capital(s, M, rng, z1)
    rubble(pc, rng, 1.6 * PITCH, 1.0, 3.5, 8)
    rubble(pc, rng, -0.5 * PITCH, 2.5, 3.0, 5, big=0.8)
    vines(pc, rng)
    return max(p.z for p in pair) + LH + 1.5


MAX_EDGE = 0.18  # everywhere
FINE = 0.06  # on carved shafts: the relief lines are ~0.11 studs wide


def on_shafts(co, shafts, pad=0.4):
    hit = np.zeros(len(co), bool)
    for M, z0, z1 in shafts:
        inv = np.array(M.inverted())
        loc = co @ inv[:3, :3].T + inv[:3, 3]
        r = R0 + (R1 - R0) * np.clip((loc[:, 2] - FOOT) / (COL_H - NECK - FOOT), 0, 1)
        hit |= (np.abs(np.hypot(loc[:, 0], loc[:, 1]) - r) < pad) & (loc[:, 2] > z0 - 0.1) & (loc[:, 2] < z1 + 0.1)
    return hit


def high(lo, seed, shafts=(), breaks=()):
    """HIGH = LOW subdivided to MAX_EDGE (FINE on the carved shafts) with light edge chips and fine pitting.
    bellwood_temple_hall.high_copy's broad lumps crumpled the round shafts like paper and drowned the carving, so the
    colonnade weathers gently and lets relief() speak."""
    me = lo.data.copy()
    me.name = "HI_" + lo.data.name
    ob = bpy.data.objects.new("HI_" + lo.name, me)
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    bm.from_mesh(me)
    for _ in range(10):
        long = [e for e in bm.edges if e.calc_length() > MAX_EDGE]
        if not long:
            break
        bmesh.ops.subdivide_edges(bm, edges=long, cuts=1, use_grid_fill=True)
    for _ in range(4 if shafts else 0):
        bm.verts.index_update()
        hit = on_shafts(np.array([v.co for v in bm.verts]), shafts)
        long = [e for e in bm.edges if e.calc_length() > FINE and (hit[e.verts[0].index] or hit[e.verts[1].index])]
        if not long:
            break
        bmesh.ops.subdivide_edges(bm, edges=long, cuts=1, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    FG.weather(ob, chip=0.07, erode=0.004, freq=0.8, seed=seed, edge_pct=(92, 99.6))
    G.detail(ob, bump=0.012, pit=0.015, freq=2.4, seed=seed + 1)
    if breaks:  # snapped faces: coarse conchoidal relief, fading out from the break
        co, nr = G._co_nr(ob)
        amp = np.zeros(len(co))
        for p, rad in breaks:
            amp = np.maximum(amp, G.sst(rad, 0.4 * rad, np.linalg.norm(co - np.array(p), axis=1)))
        d = amp * (0.32 * G.fbm(co * 0.7, 3, seed + 3) + 0.12 * G.fbm(co * 2.3, 2, seed + 4))
        ob.data.vertices.foreach_set("co", (co + nr * d[:, None]).astype(np.float32).ravel())
        ob.data.update()
    return ob


def relief(obj, shafts, depth=0.13, seed=0):
    """Carve the shafts of a HIGH Stone mesh in shallow relief: registers of five framed panels round the shaft, raised
    fillets between them, and in each panel a sinuous stem with two opposed spiral scrolls, mirrored panel to panel. The
    field is cut back, the motif and frames stay proud, and worn patches lose the carving. Cut inward along the normal: the
    silhouette stays a column and the carving bakes into the normal and cavity maps."""
    co, nr = G._co_nr(obj)
    out = np.zeros(len(co))
    sst = G.sst
    for M, z0, z1 in shafts:
        inv = np.array(M.inverted())
        loc = co @ inv[:3, :3].T + inv[:3, 3]
        rho, z = np.hypot(loc[:, 0], loc[:, 1]), loc[:, 2]
        r = R0 + (R1 - R0) * np.clip((z - FOOT) / (COL_H - NECK - FOOT), 0, 1)
        on = (np.abs(rho - r) < 0.3) & (z > z0 + 0.3) & (z < z1 - 0.3)
        if not on.any():
            continue
        span = z1 - z0 - 0.6
        reg = span / max(1, round(span / 3.4))  # whole registers, so top and bottom frames close
        zz = z - (z0 + 0.3)
        fv = np.mod(zz, reg) - reg / 2
        P = 5
        u = (np.arctan2(loc[:, 1], loc[:, 0]) / (2 * np.pi) + 0.5) * P
        pw = 2 * np.pi * r / P
        fu = (np.mod(u, 1.0) - 0.5) * pw
        frame = np.maximum(sst(pw / 2 - 0.22, pw / 2 - 0.15, np.abs(fu)), sst(reg / 2 - 0.3, reg / 2 - 0.23, np.abs(fv)))
        flip = np.where((np.floor(u) + np.floor(zz / reg)) % 2 == 0, 1.0, -1.0)
        fu = fu * flip
        A, k = 0.26, 2 * np.pi / (reg - 0.7)
        d = np.abs(fu - A * np.sin(k * fv)) / np.sqrt(1 + (A * k * np.cos(k * fv)) ** 2)
        motif = sst(0.08, 0.045, d) * sst(reg / 2 - 0.4, reg / 2 - 0.5, np.abs(fv))  # stem
        hh = reg / 2 - 0.3
        c = 0.2  # log-spiral growth: about one and a half opening turns, a curl rather than a target
        for cx, cy, hand in ((0.3, 0.5 * hh, 1.0), (-0.3, -0.5 * hh, -1.0)):
            dx, dy = fu - cx, fv - cy
            rad = np.maximum(np.hypot(dx, dy), 1e-3)
            t = np.log(rad / 0.08) / (2 * np.pi * c) - hand * np.arctan2(dy, dx) / (2 * np.pi)
            arm = sst(0.065, 0.04, 2 * np.pi * c * rad * np.abs(t - np.round(t))) * sst(0.56, 0.48, rad)
            motif = np.maximum(motif, np.maximum(arm, sst(0.1, 0.065, rad)))
        raised = np.maximum(frame, motif)
        worn = sst(-0.35, 0.25, G.fbm(loc * 0.25, 3, seed))
        cut = depth * (1.0 - raised) * (0.15 + 0.85 * worn)
        out = np.where(on, np.maximum(out, cut), out)
    obj.data.vertices.foreach_set("co", (co - nr * out[:, None]).astype(np.float32).ravel())
    obj.data.update()


PIECES = {"Standing": ("Bellwood_ColonnadeStanding", standing), "Toppled": ("Bellwood_ColonnadeToppled", toppled)}


def run(key, out, mode):
    name, build = PIECES[key]
    rdir = out / "renders"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    t = time.time()
    pc = Piece(name)
    top = build(pc)
    H.NAME, H.ROLES = name, ROLES  # the hall's objects() iterates its module ROLES
    lows = H.objects(pc)
    log("LOW " + " ".join(f"{r}={sum(len(p.vertices) - 2 for p in o.data.polygons)}" for r, o in lows.items())
        + f"  top={top:.1f}  {time.time() - t:.1f}s")
    lo_b, hi_b = FG.bbox(list(lows.values()))
    rkw = {"views": (("q34", 75.0), ("front", 85.0), ("side", 55.0)), "ez": 4.0, "res": (1600, 1000),
           "close": (60.0, lo_b, hi_b, 8.0)}
    if mode == "clay":  # clay shows the carved HIGH, so the relief is judged before any bake
        cm = G.clay_mat()
        shown = []
        for role, o in lows.items():
            hi = high(o, 61, *((pc.shafts, pc.breaks) if role == "Stone" else ()))
            if role == "Stone":
                relief(hi, pc.shafts, seed=7)
            hi.data.materials.append(cm)
            o.hide_render = True
            shown.append(hi)
        return G.render_set(name, shown, rdir, "clay", **rkw)
    import vesp_bake as VB
    stone, wood, bark = (H.src("medieval_blocks_03", "stone"), H.src("distressed_painted_planks", "cloth"),
                         H.src("bark_willow_02", "vines"))
    highs = {}
    for i, (role, srcmap, tl) in enumerate((("Stone", stone, 6.0), ("Vine", bark, 3.0), ("Ribbon", wood, 3.0))):
        highs[role] = high(lows[role], 61 + 7 * i, *((pc.shafts, pc.breaks) if role == "Stone" else ()))
        if role == "Stone":
            relief(highs[role], pc.shafts, seed=7)
        highs[role].data.materials.append(VB.hi_material(f"Hi_Col{role}", srcmap, tile=tl))
        VB.unwrap(lows[role])
        log(f"HIGH {role} {VB.tris(highs[role])} tris")
    moss = (0.25, 0.32, 0.12)
    looks = {  # Stone and Ribbon match the gate towers, so the colonnade reads as the same quarry and the same cloth
        "Stone": VB.Look(base=0.28, grime=0.45, edge=0.35, sat=0.15, stone_tint=(0.95, 1.0, 0.98), moss=1.0, moss_open=0.6,
                         moss_col=moss, lichen=0.3, cavity=0.75, rough_base=0.86),
        "Vine": VB.Look(base=0.2, grime=0.4, edge=0.1, sat=0.6, stone_tint=(0.55, 0.7, 0.35), moss=1.0, moss_open=0.9,
                        moss_col=moss, cavity=0.6, rough_base=0.92),
        "Ribbon": VB.Look(base=0.42, grime=0.35, edge=0.1, sat=0.75, stone_tint=(1.0, 0.22, 0.16), cavity=0.3, rough_base=0.9),
    }
    files, entry = G.finish(name, "Bellwood", lows, highs, out, looks, {r: (0.35, 0.7) for r in ROLES},
                            "Poly Haven medieval_blocks_03, bark_willow_02, distressed_painted_planks (CC0)",
                            extra={"collision": {"Stone": "Hull"}}, builder=BUILDER, render_kw=rkw)
    G.merge_manifest(out, {name: entry}, "Bellwood landmark: Sunken Temple colonnade")
    return files


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(a[0] if a else ROOT / "assets/source/landmarks/bellwood_colonnade").resolve()
    (out / "renders").mkdir(parents=True, exist_ok=True)
    mode = os.environ.get("COL_MODE", "clay")
    keys = os.environ.get("COL_PIECES", "Standing,Toppled").split(",")
    rows = [run(k, out, mode) for k in keys]
    dst = out / "renders" / f"Bellwood_Colonnade_{mode}_sheet.jpg"
    FG.sheet(rows, dst)
    log("sheet", dst)


if __name__ == "__main__":
    main()
