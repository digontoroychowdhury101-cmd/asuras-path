"""Amberfall landmark: the Broken Ravine Bridge (LANDMARK-BUILD-SPEC section 2; concept amberfall_2_broken_ravine_bridge.webp).

  "C:/Program Files/Blender Foundation/Blender 5.3/blender.exe" -b --python-exit-code 1 -P tools/blender/landmarks/amberfall_broken_bridge.py -- [out_dir]
  default out_dir: assets/source/landmarks/amberfall_bridge     env: BRIDGE_MODE=clay|bake  VESP_RENDER_SAMPLES

A gothic viaduct across the Amberfall chasm (world x -6050, z -2600), seen down the chasm from the AmberfallCrossing 550 studs north.
A pagoda-capped gothic tower stands on each rim; the deck runs through its gate. Past the tower an abutment drops to the upper ledge,
a short pointed bay leaps to a pier founded on the lower ledge, and from the two piers one great pointed arch springs across the gorge
under a stacked lancet arcade that carries the deck. The crown fell long ago: both halves end in broken voussoirs and torn slabs, with
rusted chains swagging across the gap and hanging into the mist, and torn red banners with a gold lotus hanging from them.

Hard-surface LOW (lobby_kit_geo solids) -> HIGH (LOW subdivided, chipped and pitted) -> vesp_bake per role on CC0 Poly Haven bases
(outputs/vesperhold/THIRD_PARTY.md). Each half of the stone is its own role so every 2048 map covers half the bridge, not all of it:
  Tower{W,E}    medieval_blocks_03, pale gold-grey      collision Precise (the deck passes through the gate)
  Deck{W,E}     medieval_blocks_03                      collision Precise (walkable slab and balustrade)
  Arch{W,E}     medieval_blocks_03, darker trim         no collision (voussoirs, ribs, string courses, tracery)
  Pier{W,E}     medieval_blocks_03                      no collision (piers, abutment, spandrel arcade: out of reach in the chasm)
  Tiles         roof_slates_02, dusty grey              no collision
  Lacquer       distressed_painted_planks, vermilion    no collision
  Soffit        distressed_painted_planks, red-brown    no collision
  Iron          metal_plate_02, rust                    no collision
  Banner        distressed_painted_planks, faded red    no collision
  Gilt          metal_plate_02, tarnished gold          no collision
Units studs, Z up. Origin: chasm centre line at deck level (deck top z = 0). X runs across the chasm (+X = east when placed at Yaw 180);
the kit front (+Y) looks up the chasm toward the crossing.
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
from mathutils import Matrix, Vector  # noqa: E402

import bellwood_temple_hall as H  # noqa: E402  (src)
import lobby_kit_roofs as roofs  # noqa: E402
import vesperhold_figures as FG  # noqa: E402
import vesperhold_gargoyles as G  # noqa: E402
from lobby_kit_geo import Mesh, xz_plane  # noqa: E402
from vesperhold_figures import log  # noqa: E402

ROOT = HERE.parents[2]
NAME = "Amberfall_BrokenBridge"
BUILDER = "tools/blender/landmarks/amberfall_broken_bridge.py (win-114, hard-surface + Cycles bake)"
ROLES = ("TowerW", "TowerE", "DeckW", "DeckE", "ArchW", "ArchE", "PierW", "PierE",
         "Tiles", "Lacquer", "Soffit", "Iron", "Banner", "Gilt")
TAU = 2 * math.pi

# ---- the chasm the bridge stands in (Overworld.TerrainDef.Chasm at z -2600, sampled with heightAt; deck = rim 292)
RIM, LEDGE_HI, LEDGE_LO, FLOOR = 0.0, -125.0, -278.0, -445.0
# ---- plan (|X| from the chasm centre line)
TOWER_X, TOWER_W, TOWER_FOOT = 258.0, 48.0, -42.0
ABUT_X0, ABUT_X1 = 200.0, 234.0          # abutment: cliff face to the tower's inner wall
PIER_X, PIER_W, PIER_D, PIER_FOOT = 150.0, 50.0, 54.0, -300.0
SPRING_Z, ARCH_R, RING = -235.0, 200.0, 20.0   # great arch: springline, intrados radius, ring depth
DECK_W, SLAB = 26.0, 3.0                 # deck width (Y) and slab thickness
SPAN_Y = 20.0                            # arch ring and spandrel wall depth
BROKEN = {-1: 46.0, 1: 68.0}             # |X| where each half's deck ends (west reaches further)
SEC_SPRING = -118.0                      # short bay between the pier and the abutment, opening just above the upper ledge (-126..-135)
BAY, BAND = 21.0, 44.0                   # arcade bay width and the height of each band of openings


def side_role(base, s):
    return base + ("W" if s < 0 else "E")


class Piece:
    def __init__(self):
        self.meshes = {}

    def m(self, role):
        role = {"Roof": "Tiles", "Timber": "Soffit"}.get(role, role)
        if role not in self.meshes:
            self.meshes[role] = Mesh(f"{NAME}__{role}", role, 8.0)
        return self.meshes[role]


def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


# ============================================================================================ 2-D outlines (x, z)
def pointed(cx, w, zs, k=1.0, n=8, flip=False):
    """Pointed-arch head from the right springer over to the left one: R = k * w (k = 1 equilateral, < 1 drop, > 1 lancet)."""
    R = max(k * w, w / 2 + 1e-3)
    a = w / 2
    zc = math.sqrt(R * R - (R - a) ** 2)
    pts = []
    # right arc: centre (cx + a - R, zs), from angle 0 up to the apex at x = cx
    t1 = math.atan2(zc, R - a)
    for i in range(n + 1):
        t = t1 * i / n
        pts.append((cx + a - R + R * math.cos(t), zs + R * math.sin(t)))
    for i in range(n - 1, -1, -1):  # left arc mirrors it
        x, z = pts[i]
        pts.append((2 * cx - x, z))
    return pts


def lancet(cx, z0, w, zs, k=1.0, n=8):
    """Closed lancet opening: sill z0, jambs up to springline zs, pointed head."""
    head = pointed(cx, w, zs, k, n)
    return [(cx - w / 2, z0), (cx + w / 2, z0)] + head[1:-1] + [(cx - w / 2, zs)]


def foil(cx, cz, r, lobes=4, n=48, rot=math.pi / 4):
    """Cusped foil (quatrefoil by default): union of `lobes` circles of radius r*0.5 set r*0.5 out, sampled by rays."""
    rr, d = r * 0.52, r * 0.48
    pts = []
    for k in range(n):
        a = TAU * k / n
        ux, uz = math.cos(a), math.sin(a)
        best = 0.0
        for j in range(lobes):
            b = rot + TAU * j / lobes
            px, pz = d * math.cos(b), d * math.sin(b)
            pr = px * ux + pz * uz
            disc = pr * pr - (px * px + pz * pz - rr * rr)
            if disc >= 0:
                best = max(best, pr + math.sqrt(disc))
        pts.append((cx + best * ux, cz + best * uz))
    return pts


def wall(mesh, outline, holes, y, depth):
    """Elevation prism: outline (x, z) with holes, `depth` thick centred on y."""
    mesh.prism(outline, holes, depth, xz_plane(y, depth))


# ============================================================================================ the great arch
def intrados(s, x):
    """Height of the great arch's intrados at |x| on side s (circle centred across the centre line)."""
    cx = s * (PIER_X - PIER_W / 2) - s * ARCH_R
    dx = x - cx
    return SPRING_Z + math.sqrt(max(ARCH_R * ARCH_R - dx * dx, 0.0))


def extrados(s, x, grow=RING):
    cx = s * (PIER_X - PIER_W / 2) - s * ARCH_R
    dx = x - cx
    return SPRING_Z + math.sqrt(max((ARCH_R + grow) ** 2 - dx * dx, 0.0))


def great_arch(pc, s, rng):
    """Voussoirs from the springer to the break, a recessed inner order and a hood moulding; the last stones crack and sag."""
    a = pc.m(side_role("Arch", s))
    cx = s * (PIER_X - PIER_W / 2) - s * ARCH_R
    x_spring = s * (PIER_X - PIER_W / 2)
    xb = s * (BROKEN[s] + 6.0)  # the ring breaks a little outside the deck's torn end
    t0 = math.atan2(0.0, x_spring - cx)  # 0 on the east half, pi on the west
    t_end = math.acos(max(min((xb - cx) / ARCH_R, 1.0), -1.0))
    n = max(int(abs(t_end - t0) * ARCH_R / 4.2), 8)
    gap = 0.18
    for i in range(n):
        ta, tb = t0 + (t_end - t0) * i / n, t0 + (t_end - t0) * (i + 1) / n
        last = n - i
        sag = 0.0 if last > 4 else (5 - last) * 0.9
        ri, ro = ARCH_R, ARCH_R + RING + (rng.uniform(-0.6, 0.6) if last <= 3 else 0.0)
        da = gap / ARCH_R
        q = [(ta + da * (1 if tb > ta else -1)), (tb - da * (1 if tb > ta else -1))]
        pts = [(cx + ri * math.cos(q[0]), SPRING_Z + ri * math.sin(q[0])), (cx + ri * math.cos(q[1]), SPRING_Z + ri * math.sin(q[1])),
               (cx + ro * math.cos(q[1]), SPRING_Z + ro * math.sin(q[1])), (cx + ro * math.cos(q[0]), SPRING_Z + ro * math.sin(q[0]))]
        pts = [(x, z - sag) for x, z in pts]
        if last == 1:  # the broken keystone end: a jagged face instead of a joint
            mx = (pts[1][0] + pts[2][0]) / 2
            pts.insert(2, (mx + s * rng.uniform(0.5, 2.5), (pts[1][1] + pts[2][1]) / 2 + rng.uniform(-2, 2)))
        depth = SPAN_Y + 2.0 if last > 1 else SPAN_Y - 2.0
        wall(a, pts, (), 0.0, depth)
    # inner (recessed) order: a narrower ring under the voussoirs, and a hood moulding proud of the face
    for grow0, grow1, depth in ((-5.0, 0.0, SPAN_Y - 8.0), (-9.0, -5.0, SPAN_Y - 14.0), (RING, RING + 2.2, SPAN_Y + 4.0)):
        path_i, path_o = [], []
        m = 64
        for k in range(m + 1):
            t = t0 + (t_end - t0 - 0.03 * (1 if t_end > t0 else -1)) * k / m
            path_i.append((cx + (ARCH_R + grow0) * math.cos(t), SPRING_Z + (ARCH_R + grow0) * math.sin(t)))
            path_o.append((cx + (ARCH_R + grow1) * math.cos(t), SPRING_Z + (ARCH_R + grow1) * math.sin(t)))
        wall(a, path_i + path_o[::-1], (), 0.0, depth)
    return xb


# ============================================================================================ piers, abutments, arcade
def batter_block(mesh, cx, cy, z0, z1, w0, d0, w1, d1, bevel=0.15):
    """A tapered block (w0 x d0 at z0 to w1 x d1 at z1) made of stacked courses so the batter steps like masonry."""
    n = max(int((z1 - z0) / 18.0), 1)
    for i in range(n):
        za, zb = z0 + (z1 - z0) * i / n, z0 + (z1 - z0) * (i + 1) / n
        f = (i + 0.5) / n
        w, d = w0 + (w1 - w0) * f, d0 + (d1 - d0) * f
        mesh.box((cx, cy, (za + zb) / 2), (w, d, zb - za), bevel=bevel)


def pier(pc, s, rng):
    p, a = pc.m(side_role("Pier", s)), pc.m(side_role("Arch", s))
    cx = s * PIER_X
    # battered shaft from the lower ledge to the springline, then straight up to the deck
    batter_block(p, cx, 0.0, PIER_FOOT, SPRING_Z, PIER_W + 26, PIER_D + 26, PIER_W + 2, PIER_D + 2)
    p.box((cx, 0.0, (SPRING_Z - SLAB) / 2 + 0.0), (PIER_W, PIER_D, -SPRING_Z - SLAB), bevel=0.2)
    # cutwater buttresses on the up- and down-chasm faces, stepping back as they climb, ending as turrets above the deck
    for sy in (-1, 1):
        y = sy * (PIER_D / 2)
        steps = ((PIER_FOOT, -200.0, 22.0, 13.0), (-200.0, -110.0, 17.0, 10.0), (-110.0, -6.0, 13.0, 7.5))
        for z0, z1, w, d in steps:
            p.box((cx, y + sy * d / 2, (z0 + z1) / 2), (w, d, z1 - z0), bevel=0.2)
            a.box((cx, y + sy * d / 2, z1 + 0.6), (w + 1.2, d + 1.2, 1.2), bevel=0.1)  # weathering
        turret(pc, s, cx, y + sy * 4.2, sy)
    # string courses round the shaft
    for z in (-200.0, -110.0, SPRING_Z - 2.0):
        a.box((cx, 0.0, z), (PIER_W + 3.0, PIER_D + 3.0, 1.6), bevel=0.15)
    # springer block and impost
    a.box((cx, 0.0, SPRING_Z + 1.0), (PIER_W + 4.0, SPAN_Y + 6.0, 2.4), bevel=0.2)


def turret(pc, s, cx, cy, sy):
    """Octagonal refuge turret on a pier buttress, rising from the deck's corbel line through the parapet to a spire."""
    st, gilt = pc.m(side_role("Deck", s)), pc.m("Gilt")
    z0 = -6.0
    st.lathe([(5.2, z0), (5.2, 6.5), (5.8, 6.5), (5.8, 8.0), (4.6, 8.0), (4.6, 14.0), (5.2, 14.0), (5.2, 15.2), (4.4, 15.2)],
             8, T(cx, cy, 0.0), phase=math.pi / 8)
    # spire with a ring of lucarnes (small gables) and a gilt finial
    st.lathe([(4.4, 15.2), (3.6, 17.0), (0.25, 27.0), (0.0, 27.2)], 8, T(cx, cy, 0.0), phase=math.pi / 8)
    for k in range(4):
        ang = math.pi / 4 + k * math.pi / 2
        M = T(cx, cy, 0.0) @ Matrix.Rotation(ang, 4, "Z")
        st.prism([(-1.2, 15.0), (1.2, 15.0), (1.2, 17.6), (0.0, 19.6), (-1.2, 17.6)], (), 0.9, M @ T(0, 4.2, 0) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    gilt.lathe([(0.35, 27.0), (0.6, 27.8), (0.0, 29.6)], 8, T(cx, cy, 0.0))


def secondary_bay(pc, s, rng):
    """The short pointed bay from the pier's outer face to the abutment, and the spandrel wall above it."""
    p, a = pc.m(side_role("Pier", s)), pc.m(side_role("Arch", s))
    x0, x1 = PIER_X + PIER_W / 2, ABUT_X0
    w = x1 - x0
    cxa = s * (x0 + x1) / 2
    head = pointed(cxa, w, SEC_SPRING, 0.9, 10)
    zt = max(z for _, z in head)
    # spandrel wall over the bay: the arch head is its lower edge; a tall lancet lights it
    outline = head[::-1] + [(cxa + w / 2, -SLAB - 2.0), (cxa - w / 2, -SLAB - 2.0)]
    wall(p, outline, [lancet(cxa, zt + 14.0, w - 12.0, -40.0, 1.0)], 0.0, SPAN_Y - 2.0)
    # archivolt round the bay and a hood moulding
    ring_i = pointed(cxa, w, SEC_SPRING, 0.9, 14)
    ring_o = pointed(cxa, w + 7.0, SEC_SPRING, 0.9 * w / (w + 7.0) * 1.08, 14)
    wall(a, [(cxa + w / 2 + 3.5, SEC_SPRING - 6.0)] + ring_o + [(cxa - w / 2 - 3.5, SEC_SPRING - 6.0), (cxa - w / 2, SEC_SPRING - 6.0)]
         + ring_i[::-1] + [(cxa + w / 2, SEC_SPRING - 6.0)], (), 0.0, SPAN_Y + 1.5)


def abutment(pc, s, rng):
    """Masonry against the cliff from the upper ledge to the deck, with a tall blind lancet and a rose roundel on each face."""
    p, a = pc.m(side_role("Pier", s)), pc.m(side_role("Arch", s))
    xs = sorted((s * ABUT_X0, s * ABUT_X1))
    cx = (xs[0] + xs[1]) / 2
    w = xs[1] - xs[0]
    batter_block(p, cx, 0.0, LEDGE_HI - 25.0, LEDGE_HI + 10.0, w + 8, DECK_W + 14, w + 2, DECK_W + 6)
    p.box((cx, 0.0, (LEDGE_HI + 10.0 - SLAB) / 2), (w, DECK_W + 4.0, -(LEDGE_HI + 10.0) - SLAB), bevel=0.2)
    for sy in (-1, 1):  # blind lancet panel and roundel on both faces
        y = sy * (DECK_W / 2 + 2.0 + 0.45)
        M = T(0, y, 0)
        a.prism(lancet(cx, LEDGE_HI + 18.0, w - 12.0, -56.0, 1.1), [lancet(cx, LEDGE_HI + 20.0, w - 16.0, -58.0, 1.1)], 0.9,
                M @ xz_plane(0, 0.9))
        a.prism(foil(cx, -18.0, 8.5, 4, 48), [foil(cx, -18.0, 6.2, 4, 48)], 1.0, M @ xz_plane(0, 1.0))
        a.prism(foil(cx, -18.0, 3.6, 4, 32, 0.0), (), 1.2, M @ xz_plane(0, 1.2))


def arcade(pc, s, xb, rng):
    """Stacked lancet arcade on the great arch carrying the deck: wall bays stand on the extrados between colonnettes, each cut into
    bands of pointed openings separated by tie courses. The bay at the break is torn to a ragged edge and left solid."""
    p, a = pc.m(side_role("Pier", s)), pc.m(side_role("Arch", s))
    x_in = PIER_X - PIER_W / 2  # pier inner face
    top = -SLAB - 2.2  # under the corbel course
    edges = [x_in]
    while edges[-1] - BAY > abs(xb) + 6.0:
        edges.append(edges[-1] - BAY)
    edges.append(abs(xb))
    band_tops = [top - 3.0 - BAND * k for k in range(8)]
    for k in range(len(edges) - 1):
        xo, xi = edges[k], edges[k + 1]  # outer (pier side) and inner edge, as |x|
        last = k == len(edges) - 2
        zo, zi = extrados(s, s * xo) - 1.0, extrados(s, s * xi) - 1.0
        if last:  # ragged torn edge on the inner side, from the deck line down to the ring
            rag, zz = [], top
            while zz > zi + 4.0:
                bite = rng.random() < 0.3
                rag.append((s * (xi + (rng.uniform(7.0, 12.0) if bite else rng.uniform(0.0, 5.0))), zz))
                zz -= rng.uniform(2.5, 13.0)
            rag.append((s * (xi + 0.8), zi + 0.5))
            pts = [(s * xo, zo), (s * xo, top)] + rag  # outer bottom, outer top, down the torn edge
        else:
            pts = [(s * xo, zo), (s * xo, top), (s * xi, top), (s * xi, zi)]
        holes = []
        if not last:
            cxb, w = s * (xo + xi) / 2, (xo - xi) - 5.0
            floor_z = max(zo, zi) + 4.0
            head = w * math.sqrt(3) / 2
            for bt in band_tops:
                bb = bt - BAND
                sill = max(bb + 3.0, floor_z)
                spring = bt - 2.0 - head
                if spring - sill < 6.0:
                    break
                holes.append(lancet(cxb, sill, w, spring, 1.0, 8))
        wall(p, pts, holes, 0.0, SPAN_Y - 4.0)
        if k > 0:  # colonnettes on both faces at the bay's outer edge, from the extrados to the corbel course
            for sy in (-1, 1):
                a.box((s * xo, sy * (SPAN_Y / 2 - 1.0), (zo + top) / 2), (3.0, 3.0, top - zo), bevel=0.15)
    for bt in band_tops:  # tie courses at the foot of each band, over the bays whose extrados lies below it
        z = bt - BAND + 1.0
        xs_ = [x for x in edges[:-1] if extrados(s, s * x) < z - 2.0]
        if len(xs_) < 2:
            continue
        x0, x1 = sorted((s * xs_[0], s * xs_[-1]))
        a.box(((x0 + x1) / 2, 0.0, z), (x1 - x0, SPAN_Y - 2.0, 1.2), bevel=0.12)
    return edges[-1]


# ============================================================================================ deck, balustrade, tower
def balustrade(mesh, x0, x1, y, rng, broken_end=None):
    """Plinth, posts every ~8 studs with caps, pierced quatrefoil panels and a moulded top rail (height ~4.8 studs)."""
    L = x1 - x0
    n = max(int(round(L / 8.0)), 1)
    step = L / n
    mesh.box(((x0 + x1) / 2, y, 0.5), (L, 1.8, 1.0), bevel=0.12)
    for i in range(n + 1):
        x = x0 + step * i
        mesh.box((x, y, 2.8), (1.6, 1.6, 3.6), bevel=0.1)
        mesh.box((x, y, 4.85), (2.0, 2.0, 0.5), bevel=0.08)
        mesh.lathe([(0.55, 5.1), (0.65, 5.4), (0.0, 6.2)], 8, T(x, y, 0))
    for i in range(n):
        xa, xb = x0 + step * i + 0.8, x0 + step * (i + 1) - 0.8
        w = xb - xa
        holes = []
        nf = max(int(round(w / 3.0)), 1)
        for j in range(nf):
            holes.append(foil(xa + w * (j + 0.5) / nf, 2.6, min(1.3, w / nf / 2 - 0.15), 4, 24))
        mesh.prism([(xa, 1.0), (xb, 1.0), (xb, 4.1), (xa, 4.1)], holes, 0.7, xz_plane(y, 0.7))
    mesh.box(((x0 + x1) / 2, y, 4.35), (L, 1.5, 0.5), bevel=0.1)


def deck(pc, s, rng):
    d, a = pc.m(side_role("Deck", s)), pc.m(side_role("Arch", s))
    x_out = TOWER_X - TOWER_W / 2  # the tower's inner wall
    xe = BROKEN[s]
    # slab in 6-stud lengths; the last ones crack, tilt and drop toward the break
    x = x_out
    seg = 6.0
    while x - seg > xe - 0.01:
        k = (x - xe) / seg
        drop = 0.0 if k > 3 else (3 - k) * 0.7
        tilt = 0.0 if k > 3 else (3 - k) * 0.035
        M = T(s * (x - seg / 2), 0, -drop) @ Matrix.Rotation(-s * tilt, 4, "Y")
        d.box((0, 0, -SLAB / 2), (seg - 0.12, DECK_W, SLAB), M, bevel=0.15)
        x -= seg
    # ragged last slab stub
    for j in range(5):
        y = -DECK_W / 2 + DECK_W * (j + 0.5) / 5
        ln = rng.uniform(1.0, 6.0)
        d.box((s * (xe - ln / 2 + 0.3), y, -SLAB / 2 - 2.2), (ln, DECK_W / 5 - 0.3, SLAB), Matrix.Rotation(s * rng.uniform(0.04, 0.12), 4, "Y"), bevel=0.12)
    # corbel table and cornice under both edges
    L = x_out - xe
    for sy in (-1, 1):
        y = sy * (DECK_W / 2 - 0.6)
        a.box((s * (x_out + xe) / 2, y, -SLAB - 0.6), (L, 1.6, 1.2), bevel=0.1)
        nc = int(L / 3.0)
        for i in range(nc):
            xc = s * (xe + 1.5 + 3.0 * i)
            a.box((xc, sy * (DECK_W / 2 - 1.4), -SLAB - 2.0), (1.0, 1.4, 1.6), bevel=0.08)
    # balustrades, stopping short of the break with a broken post
    for sy in (-1, 1):
        y = sy * (DECK_W / 2 - 0.9)
        x0, x1 = xe + 7.0 + rng.uniform(0, 5.0), x_out - 0.5
        lo, hi = sorted((s * x0, s * x1))
        balustrade(d, lo, hi, y, rng)
        # torn stubs of panel and post beyond the last whole bay
        d.box((s * (x0 - 2.0), y, 1.4), (3.2, 0.7, 1.8), Matrix.Rotation(rng.uniform(-0.08, 0.08), 4, "Z"), bevel=0.08)


def tower(pc, s, rng):
    """Gothic gate tower on the rim: a vaulted passage carries the deck through; a belfry stage with paired lancets; a parapet with
    corner pinnacles; then a two-tier red-lacquer pagoda with tile roofs and a gilt finial."""
    st, ar = pc.m(side_role("Tower", s)), pc.m(side_role("Arch", s))
    dk = pc.m(side_role("Deck", s))
    cx, w = s * TOWER_X, TOWER_W
    h = w / 2
    th = 4.0
    Z1, Z2, Z3 = 40.0, 80.0, 88.0  # top of the gate stage, of the belfry, of the parapet
    gate_w, gate_s = 18.0, 18.0
    lx, lw = w * 0.15, w * 0.19  # belfry lancet offset and width
    # four walls, base to belfry top, with the gate on the two X faces and lancets above
    for face in ("x-", "x+", "y-", "y+"):
        holes = []
        if face[0] == "x":
            holes.append(lancet(0.0, 0.0, gate_w, gate_s, 1.0, 10))
        else:
            holes.append(lancet(0.0, 8.0, 8.5, 26.0, 1.15, 8))
        for sx_ in (-1, 1):  # paired belfry lancets
            holes.append(lancet(sx_ * lx, Z1 + 7.0, lw, Z1 + 25.0, 1.1, 8))
        outline = [(-h, TOWER_FOOT), (h, TOWER_FOOT), (h, Z2), (-h, Z2)]
        if face[0] == "x":
            M = T(cx + (h - th / 2) * (1 if face[1] == "+" else -1), 0, 0) @ Matrix.Rotation(math.pi / 2, 4, "Z")
        else:
            M = T(cx, (h - th / 2) * (1 if face[1] == "+" else -1), 0)
        ow = [(x, z) for x, z in outline]
        ow[0], ow[1] = (-h + (0 if face[0] == "y" else th), TOWER_FOOT), (h - (0 if face[0] == "y" else th), TOWER_FOOT)
        ow[2], ow[3] = (h - (0 if face[0] == "y" else th), Z2), (-h + (0 if face[0] == "y" else th), Z2)
        st.prism(ow, holes, th, M @ xz_plane(0, th))
        # archivolts round the gate and the belfry lancets, a hood moulding over the lower lancet
        out = th / 2 + 0.6
        sgn = (1 if face[1] == "+" else -1)
        Mo = M @ T(0, sgn * out, 0)
        if face[0] == "x":
            ri, ro = pointed(0.0, gate_w, gate_s, 1.0, 12), pointed(0.0, gate_w + 5.0, gate_s, 1.0 * gate_w / (gate_w + 5) * 1.12, 12)
            ar.prism([(gate_w / 2 + 2.5, 0.0)] + ro + [(-gate_w / 2 - 2.5, 0.0), (-gate_w / 2, 0.0)] + ri[::-1] + [(gate_w / 2, 0.0)],
                     (), 1.4, Mo @ xz_plane(0, 1.4))
            # a rose window over the gate
            ar.prism(foil(0.0, 32.0, 5.0, 6, 60, 0.0), [foil(0.0, 32.0, 3.7, 6, 60, 0.0)], 1.2, Mo @ xz_plane(0, 1.2))
        for sx_ in (-1, 1):
            zs_ = Z1 + 25.0
            ri = pointed(sx_ * lx, lw, zs_, 1.1, 8)
            ro = pointed(sx_ * lx, lw + 2.4, zs_, 1.1 * lw / (lw + 2.4) * 1.1, 8)
            ar.prism([(sx_ * lx + lw / 2 + 1.2, zs_)] + ro + [(sx_ * lx - lw / 2 - 1.2, zs_), (sx_ * lx - lw / 2, zs_)] + ri[::-1]
                     + [(sx_ * lx + lw / 2, zs_)], (), 0.9, Mo @ xz_plane(0, 0.9))
            # tracery: a mullion and a trefoil in each lancet head
            ar.box((sx_ * lx, 0, (Z1 + 7.0 + zs_) / 2), (0.7, 0.5, zs_ - Z1 - 7.0), Mo, bevel=0.05)
            ar.prism(foil(sx_ * lx, zs_ + 3.0, lw * 0.3, 3, 36, math.pi / 2), [foil(sx_ * lx, zs_ + 3.0, lw * 0.19, 3, 36, math.pi / 2)],
                     0.5, Mo @ xz_plane(0, 0.5))
    # passage floor (walkable) and a vault ceiling; the gate stage's floor carries the deck level through
    dk.box((cx, 0.0, -SLAB / 2), (w - 2 * th + 0.2, w - 2 * th + 0.2, SLAB), bevel=0.1)
    st.box((cx, 0.0, Z1 - 1.0), (w - 2 * th + 0.2, w - 2 * th + 0.2, 2.0), bevel=0.1)
    st.box((cx, 0.0, Z2 - 1.0), (w - 2 * th + 0.2, w - 2 * th + 0.2, 2.0), bevel=0.1)
    # plinth, string courses, corbelled cornice
    st.box((cx, 0.0, TOWER_FOOT + 8.0), (w + 4.0, w + 4.0, 16.0), bevel=0.25)
    for z, g, hh in ((-6.0, 2.0, 1.6), (Z1, 1.6, 1.4), (Z2 - 0.6, 2.4, 1.2), (Z2 + 0.6, 3.6, 1.2)):
        ar.box((cx, 0.0, z), (w + g, w + g, hh), bevel=0.12)
    for k in range(int(w / 2.6)):  # corbels under the parapet
        for face in range(4):
            u = -h + 1.3 + 2.6 * k
            px, py = [(u, h + 1.0), (u, -h - 1.0), (h + 1.0, u), (-h - 1.0, u)][face]
            ar.box((cx + px, py, Z2 - 2.2), (1.0 if face < 2 else 1.4, 1.4 if face < 2 else 1.0, 2.0), bevel=0.08)
    # parapet: pierced quatrefoil band on all four sides
    for face in range(4):
        ang = face * math.pi / 2
        M = T(cx, 0, Z2 + 1.2) @ Matrix.Rotation(ang, 4, "Z") @ T(0, h + 1.2, 0)
        holes = [foil(-h + 2.5 + (w - 5.0) * (j + 0.5) / 7, 2.6, 1.3, 4, 24) for j in range(7)]
        st.prism([(-h - 1.8, 0.0), (h + 1.8, 0.0), (h + 1.8, Z3 - Z2 - 1.2), (-h - 1.8, Z3 - Z2 - 1.2)], holes, 1.2, M @ xz_plane(0, 1.2))
    # corner buttresses (setback stages) with pinnacles
    for px in (-1, 1):
        for py in (-1, 1):
            bx, by = cx + px * (h + 1.0), py * (h + 1.0)
            for z0, z1, bw in ((TOWER_FOOT, 0.0, 9.5), (0.0, Z1, 7.5), (Z1, Z2 - 3.0, 6.0)):
                st.box((bx, by, (z0 + z1) / 2), (bw, bw, z1 - z0), bevel=0.2)
                ar.lathe([(bw * 0.72, z1), (bw * 0.5, z1 + 1.6), (0.0, z1 + 1.7)], 4, T(bx, by, 0), phase=math.pi / 4)
            # pinnacle: shaft, gablets, crocketed spire, gilt finial
            st.box((bx, by, Z2 + 4.5), (4.0, 4.0, 9.0), bevel=0.12)
            st.lathe([(2.6, Z2 + 9.0), (2.1, Z2 + 10.0), (0.25, Z2 + 22.0), (0.0, Z2 + 22.2)], 4, T(bx, by, 0), phase=math.pi / 4)
            for k in range(5):
                zz = Z2 + 11.0 + 2.1 * k
                rr = 2.1 * (1 - (zz - Z2 - 10.0) / 12.0)
                for q in range(4):
                    ang = q * math.pi / 2
                    ar.box((bx + (rr + 0.35) * math.cos(ang), by + (rr + 0.35) * math.sin(ang), zz), (0.6, 0.6, 0.6),
                           Matrix.Identity(4), bevel=0.05)
            pc.m("Gilt").lathe([(0.35, Z2 + 22.0), (0.7, Z2 + 23.0), (0.0, Z2 + 25.0)], 8, T(bx, by, 0))
    pagoda(pc, cx, Z3, w, rng)


def pagoda(pc, cx, z0, w, rng):
    """Two-tier red-lacquer pagoda on the tower top: a columned drum, a curved tile roof, a smaller drum and roof, a gilt finial."""
    lq, gilt = pc.m("Lacquer"), pc.m("Gilt")
    z = z0
    for tier, (dw, dh, rw, rh) in enumerate(((w - 12.0, 11.0, w + 16.0, 7.0), (w - 22.0, 9.0, w + 2.0, 6.0))):
        hd = dw / 2
        lq.box((cx, 0.0, z + 0.5), (dw + 2.0, dw + 2.0, 1.0), bevel=0.1)  # floor ring
        n = 4 if tier == 0 else 3
        for i in range(n + 1):
            u = -hd + dw * i / n
            for px, py in ((u, -hd), (u, hd), (-hd, u), (hd, u)):
                lq.lathe([(0.55, z + 1.0), (0.5, z + dh - 1.0), (0.65, z + dh - 0.6)], 8, T(cx + px, py, 0))
        # lattice screens between the columns and a balcony rail on the lower tier
        for face in range(4):
            ang = face * math.pi / 2
            M = T(cx, 0, 0) @ Matrix.Rotation(ang, 4, "Z") @ T(0, hd - 0.4, 0)
            holes = []
            for i in range(n):
                xa = -hd + dw * i / n + 0.8
                xb = -hd + dw * (i + 1) / n - 0.8
                for j in range(3):
                    for k in range(3):
                        cxh = xa + (xb - xa) * (j + 0.5) / 3
                        cz = z + 2.4 + (dh - 4.6) * (k + 0.5) / 3
                        hw, hh = (xb - xa) / 3 / 2 - 0.25, (dh - 4.6) / 3 / 2 - 0.25
                        holes.append([(cxh - hw, cz - hh), (cxh + hw, cz - hh), (cxh + hw, cz + hh), (cxh - hw, cz + hh)])
            lq.prism([(-hd, z + 1.6), (hd, z + 1.6), (hd, z + dh - 1.6), (-hd, z + dh - 1.6)], holes, 0.35, M @ xz_plane(0, 0.35))
            lq.box((0, 0, z + dh - 0.8), (dw + 1.0, 0.9, 1.4), M, bevel=0.08)  # architrave
            if tier == 0:
                lq.box((0, 1.6, z + 2.6), (dw + 3.0, 0.4, 0.35), M, bevel=0.04)
                for i in range(9):
                    lq.box((-hd - 1.5 + (dw + 3.0) * i / 8, 1.6, z + 1.8), (0.35, 0.35, 1.6), M, bevel=0.03)
        sub = Piece()
        roofs.hall(sub, rw, rw, rh, 1.0, 1.8, 1.4, (0.5, 1.0), top="Roof", under="Timber", ridge_scale=0.9, finial=None,
                   nu=30, nt=(8, 8))
        for role, mesh in sub.meshes.items():
            pc.m(role).merge(mesh.bm, T(cx, 0.0, z + dh))
        # bronze bells under the lower roof's corners
        if tier == 0:
            for px in (-1, 1):
                for py in (-1, 1):
                    bxp, byp = cx + px * (rw / 2 - 0.6), py * (rw / 2 - 0.6)
                    gilt.lathe([(0.0, -2.4), (0.95, -2.4), (1.05, -2.1), (0.75, -1.0), (0.55, -0.2), (0.0, 0.0)], 10,
                               T(bxp, byp, z + dh + 0.6))
                    gilt.box((bxp, byp, z + dh + 1.1), (0.12, 0.12, 1.2))
        if tier == 0:  # the next drum stands on this roof where its slope meets the drum's footprint
            t_edge = 1.0 - (w - 22.0 + 2.0) / 2 / (rw / 2)
            z += dh + rh * (0.3 * t_edge + 0.7 * t_edge * t_edge) - 0.3
        else:
            z += dh + rh * 0.8
    gilt.lathe([(0.0, 0.0), (1.5, 0.0), (1.5, 0.8), (0.8, 1.6), (1.2, 2.9), (0.6, 4.2), (1.0, 5.2), (0.4, 6.8), (0.9, 7.6),
                (0.35, 8.6), (0.15, 12.5), (0.0, 13.0)], 12, T(cx, 0.0, z - 0.8))


# ============================================================================================ chains, banners
def link_mesh(mesh, centre, tangent, normal, L=5.0, W=3.0, r=0.62, nu=10, nv=6):
    """One oval chain link: a stadium path swept with a round bar. tangent = chain direction, normal = the link's flat axis."""
    t = tangent.normalized()
    n = normal.normalized()
    b = t.cross(n).normalized()
    half = (L - W) / 2
    path = []
    for i in range(nu):
        a = TAU * i / nu
        x = math.cos(a) * W / 2 + (half if math.cos(a) > 0 else -half)
        y = math.sin(a) * W / 2
        path.append((x, y, a))
    V = []
    for x, y, a in path:
        c = centre + t * x + b * y
        radial = (t * math.cos(a) + b * math.sin(a)).normalized()
        V.append([mesh.bm.verts.new(c + radial * (r * math.cos(TAU * j / nv)) + n * (r * math.sin(TAU * j / nv))) for j in range(nv)])
    for i in range(nu):  # a closed torus: wrap round the path and round the bar
        for j in range(nv):
            mesh._face([V[i][j], V[(i + 1) % nu][j], V[(i + 1) % nu][(j + 1) % nv], V[i][(j + 1) % nv]])


def chain(pc, pts, rng, pitch=3.9):
    """Links along a polyline every `pitch`, alternating 90 degrees."""
    iron = pc.m("Iron")
    seg = []
    for i in range(len(pts) - 1):
        seg.append((pts[i], pts[i + 1], (pts[i + 1] - pts[i]).length))
    total = sum(s_[2] for s_ in seg)
    k, d = 0, pitch / 2
    while d < total:
        acc = 0.0
        for a, b, ln in seg:
            if acc + ln >= d:
                p = a + (b - a) * ((d - acc) / ln)
                tdir = (b - a).normalized()
                up = Vector((0, 0, 1)) if abs(tdir.z) < 0.9 else Vector((1, 0, 0))
                n0 = tdir.cross(up).normalized()
                n = n0 if k % 2 == 0 else tdir.cross(n0).normalized()
                link_mesh(iron, p, tdir, n)
                break
            acc += ln
        d += pitch
        k += 1


def catenary(a, b, sag, n=40):
    return [a.lerp(b, i / n) - Vector((0, 0, sag * 4 * (i / n) * (1 - i / n))) for i in range(n + 1)]


def lotus(cx, cz, r):
    """Gold lotus emblem in the banner's plane: separate pointed petals (centre tallest, pairs fanning out and shortening), a
    shallow bowl of base petals and a ring round it. Returns a list of polygons; they overlap, so each is laid a hair proud."""
    parts = []
    for ang, ln, wd in ((0, 1.0, 0.3), (24, 0.88, 0.28), (-24, 0.88, 0.28), (50, 0.7, 0.26), (-50, 0.7, 0.26), (76, 0.5, 0.22),
                        (-76, 0.5, 0.22)):
        t = math.radians(ang)
        ux, uz = math.sin(t), math.cos(t)
        vx, vz = uz, -ux
        poly = []
        for k in range(13):  # a vesica: two arcs from the base to the tip
            q = k / 12
            half = wd * r * math.sin(math.pi * q) ** 0.8
            along = ln * r * q
            poly.append((along, half))
        poly = poly + [(a_, -h_) for a_, h_ in poly[-2:0:-1]]
        bx, bz = cx, cz - 0.28 * r
        parts.append([(bx + a_ * ux + h_ * vx, bz + a_ * uz + h_ * vz) for a_, h_ in poly])
    bowl = [(cx - 0.75 * r + 1.5 * r * i / 12, cz - 0.28 * r - 0.22 * r * math.sin(math.pi * i / 12)) for i in range(13)]
    parts.append(bowl + [(cx + 0.6 * r, cz - 0.24 * r), (cx - 0.6 * r, cz - 0.24 * r)])
    for k in range(40):  # ring
        a0, a1 = TAU * k / 40, TAU * (k + 1) / 40
        ro, ri = 1.32 * r, 1.2 * r
        oz = cz + 0.2 * r
        parts.append([(cx + ri * math.cos(a0), oz + ri * math.sin(a0)), (cx + ro * math.cos(a0), oz + ro * math.sin(a0)),
                      (cx + ro * math.cos(a1), oz + ro * math.sin(a1)), (cx + ri * math.cos(a1), oz + ri * math.sin(a1))])
    return parts


def banner(pc, top, width, length, facing, rng, sway=0.0):
    """Torn hanging banner from `top` (centre of its pole), hanging down; facing = plane normal (horizontal). Gold lotus both sides."""
    bn, gl = pc.m("Banner"), pc.m("Gilt")
    f = facing.normalized()
    u = Vector((0, 0, 1)).cross(f).normalized()  # across the banner
    nx, nz = 9, 22
    rag = [length * (1 - rng.uniform(0.0, 0.32) * (0.5 + 0.5 * math.sin(i * 1.7 + rng.uniform(0, 3)))) for i in range(nx + 1)]

    def P(i, j):
        x = -width / 2 + width * i / nx
        v = j / nz
        zz = -rag[i] * v
        bulge = 0.6 * math.sin(math.pi * v) * math.sin(math.pi * i / nx) + sway * v * v * length * 0.08
        wave = 0.35 * math.sin(v * 7.0 + i * 0.6)
        return top + u * (x + sway * v * 2.0) + f * (bulge + wave) + Vector((0, 0, zz))

    th = 0.18
    front = [[P(i, j) + f * th / 2 for i in range(nx + 1)] for j in range(nz + 1)]
    back = [[P(i, j) - f * th / 2 for i in range(nx + 1)] for j in range(nz + 1)]
    bn.grid(front, expect=f)
    bn.grid(back, expect=-f)
    bn.grid([front[0], back[0]], expect=Vector((0, 0, 1)))  # top hem
    bn.grid([[front[j][0] for j in range(nz + 1)], [back[j][0] for j in range(nz + 1)]], expect=-u)
    bn.grid([[back[j][nx] for j in range(nz + 1)], [front[j][nx] for j in range(nz + 1)]], expect=u)
    bn.grid([back[nz], front[nz]], expect=Vector((0, 0, -1)))
    # pole
    gl.sweep([(0.35 * math.cos(TAU * k / 6), 0.35 * math.sin(TAU * k / 6)) for k in range(6)],
             [top - u * (width / 2 + 1.0), top + u * (width / 2 + 1.0)], up=f)
    # lotus on both faces, following the cloth at its height
    cz = -length * 0.3
    for sgn in (1, -1):
        for k, outline in enumerate(lotus(0.0, cz, width * 0.27)):
            loop = []
            for x, z in outline:
                i = (x + width / 2) / width * nx
                j = -z / length * nz
                i0, j0 = min(max(int(i), 0), nx - 1), min(max(int(j), 0), nz - 1)
                p = P(i0, j0).lerp(P(i0 + 1, j0), i - i0).lerp(P(i0, j0 + 1).lerp(P(i0 + 1, j0 + 1), i - i0), j - j0)
                loop.append(p + f * sgn * (th / 2 + 0.05 + 0.004 * k))
            gl.poly(loop if sgn > 0 else loop[::-1], open_surface=True)


def broken_ends(pc, rng):
    """Chains across the gap and down into the gorge from both torn ends; banners on the swags and on the towers."""
    xw, xe = -BROKEN[-1], BROKEN[1]
    y0 = DECK_W / 2 - 2.0
    swags = []
    for y, sag in ((y0, 38.0), (-y0 + 3.0, 62.0), (0.0, 22.0)):
        a, b = Vector((xw + 4.0, y, -2.0)), Vector((xe - 4.0, y + rng.uniform(-3, 3), -2.0))
        pts = catenary(a, b, sag)
        chain(pc, pts, rng)
        swags.append(pts)
    for s, x in ((-1, xw), (1, xe)):  # hanging chains: some end in a lump of masonry, one in a ring
        for k, (y, ln) in enumerate(((-8.0, 70.0), (4.0, 46.0), (9.5, 95.0))):
            top = Vector((x - s * (3.0 + 4 * k), y, -SLAB - 1.0))
            bot = top + Vector((s * rng.uniform(-3, 3), rng.uniform(-2, 2), -ln))
            chain(pc, [top, top.lerp(bot, 0.5) + Vector((0, 0, 0.5)), bot], rng)
            if k != 1:
                pc.m(side_role("Arch", s)).box(tuple(bot - Vector((0, 0, 2.2))), (3.6, 3.0, 3.0),
                                                Matrix.Rotation(rng.uniform(0, 1), 4, "Z"), bevel=0.3)
            else:
                link_mesh(pc.m("Iron"), bot - Vector((0, 0, 4.0)), Vector((0, 0, 1)), Vector((1, 0, 0)), L=7.5, W=7.5, r=0.8, nu=16)
    # banners hanging off the swags, facing up the chasm
    for pts, at, ln, wd in ((swags[0], 0.27, 72.0, 17.0), (swags[1], 0.56, 88.0, 19.0), (swags[0], 0.8, 60.0, 16.0)):
        p = pts[int(at * (len(pts) - 1))]
        banner(pc, p - Vector((0, 0, 1.2)), wd, ln, Vector((0, 1, 0)), rng, sway=rng.uniform(-0.6, 0.6))
    for s in (-1, 1):  # tower banners either side of the lower lancet, on both faces, hung under the gate stage's string course
        for sy in (-1, 1):
            for bx in (-14.0, 14.0):
                banner(pc, Vector((s * TOWER_X + bx, sy * (TOWER_W / 2 + 2.2), 37.5)), 10.0, 34.0, Vector((0, sy, 0)), rng,
                       sway=rng.uniform(-0.3, 0.3))


# ============================================================================================ build
def build(pc):
    rng = random.Random(114)
    for s in (-1, 1):
        great_arch(pc, s, rng)
        xb = s * (BROKEN[s] + 6.0)
        arcade(pc, s, xb, rng)
        pier(pc, s, rng)
        secondary_bay(pc, s, rng)
        abutment(pc, s, rng)
        deck(pc, s, rng)
        tower(pc, s, rng)
    broken_ends(pc, rng)


def objects(pc):
    out = {}
    for role in ROLES:
        if role not in pc.meshes:
            continue
        mesh = pc.meshes[role]
        bm = mesh.finish()
        me = bpy.data.meshes.new(mesh.name)
        bm.to_mesh(me)
        bm.free()
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(38))
        me.validate(clean_customdata=False)
        ob = bpy.data.objects.new(mesh.name, me)
        bpy.context.scene.collection.objects.link(ob)
        out[role] = ob
    return out


def high_copy(lo, seed, max_edge):
    """HIGH = LOW subdivided until no edge exceeds max_edge, then chipped edges and pitting (bellwood_temple_hall.high_copy)."""
    me = lo.data.copy()
    me.name = "HI_" + lo.data.name
    ob = bpy.data.objects.new("HI_" + lo.name, me)
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    bm.from_mesh(me)
    for _ in range(10):
        long = [e for e in bm.edges if e.calc_length() > max_edge]
        if not long:
            break
        bmesh.ops.subdivide_edges(bm, edges=long, cuts=1, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    FG.weather(ob, chip=0.08, erode=0.016, freq=0.6, seed=seed, edge_pct=(88, 99.5))
    G.detail(ob, bump=0.05, pit=0.04, freq=0.9, seed=seed + 1)
    return ob


# ============================================================================================ review renders (chasm context)
def chasm_context():
    """A clay cross-section of the chasm round the bridge (the Overworld shelf profile), extruded up and down the gorge."""
    prof = [(-420, 4), (-226, 2), (-202, -126), (-176, -134), (-153, -279), (-112, -279), (-90, -445), (90, -445), (112, -279),
            (153, -279), (176, -134), (202, -126), (226, 6), (420, 8)]
    m = Mesh("Chasm", "Clay", 8.0)
    rows = []
    for y in range(-900, 901, 60):
        wob = 9.0 * math.sin(y / 97.0)
        rows.append([Vector((x + (wob if abs(x) < 400 else 0), y, z + (2.5 * math.sin(y / 37.0 + x / 50.0) if z < -5 else 0)))
                     for x, z in prof])
    m.grid(rows, expect=Vector((0, 0, 1)), open_surface=True)
    bm = m.finish()
    me = bpy.data.meshes.new("Chasm")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("Chasm", me)
    bpy.context.scene.collection.objects.link(ob)
    mat = bpy.data.materials.new("ChasmClay")
    mat.use_nodes = True
    p = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    p.inputs["Base Color"].default_value = (0.42, 0.3, 0.16, 1)
    p.inputs["Roughness"].default_value = 0.95
    me.materials.append(mat)
    return ob


def cpu_cycles():
    """This PC's AMD card runs out of memory in Cycles' HIP device on the bridge HIGHs (win-114: 300k+ tri roles, exit 127 with no
    maps), as the footings and root grip did (win-112/113), so the bake and its renders run on the CPU."""
    import vesp_bake as VB
    if getattr(VB.cycles, "cpu", False):
        return
    gpu = VB.cycles

    def cycles(samples=4):
        sc = gpu(samples)
        cpu_only()
        return sc
    cycles.cpu = True
    VB.cycles = cycles
    cpu_only()


def cpu_only():
    """The scene device alone is not enough: with HIP still the compute type, Cycles' bake brings HIPRT up anyway (win-114)."""
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "NONE"
        for d in prefs.devices:
            d.use = d.type == "CPU"
    except Exception as e:  # noqa: BLE001
        log(f"cpu_only: {e}")
    bpy.context.scene.cycles.device = "CPU"


def context_render(objs, rdir, tag, samples=24):
    for o in list(bpy.data.objects):  # a fresh stage: drop lights, cameras and props left by an earlier render set
        if o.type in ("LIGHT", "CAMERA") or o.name.startswith(("Ground", "Mannequin")):
            bpy.data.objects.remove(o, do_unlink=True)
    sc, cam, man = FG.setup_scene(samples)
    cpu_only()
    for o in list(bpy.data.objects):
        if o.name in ("Ground",):
            o.hide_render = True
    man.hide_render = True
    bg = next(n for n in sc.world.node_tree.nodes if n.type == "BACKGROUND")  # warm amber haze (concept: golden backlight)
    bg.inputs["Color"].default_value = (0.62, 0.45, 0.26, 1)
    bg.inputs["Strength"].default_value = 0.55
    for L in (o for o in bpy.data.objects if o.type == "LIGHT"):
        L.data.color = (1.0, 0.84, 0.6)
    chasm_context()
    sc.render.resolution_x, sc.render.resolution_y = 1600, 900
    sc.render.image_settings.file_format = "PNG"
    cam.data.lens = 28
    cam.data.clip_end = 6000
    views = {
        # from the crossing, 550 studs up the chasm, eye on the deck line (the acceptance view)
        "crossing": ((25, 560, 8), (0, 0, -60)),
        # the concept's angle: from the west rim, a little below the deck, looking across the gap
        "concept": ((-196, 230, -40), (40, -10, -70)),
        "front": ((0, 700, -120), (0, 0, -150)),
        "deck": ((-262, 0, 5.5), (40, 0, 0)),
        "gap": ((0, 140, -70), (0, 0, -20)),
        "tower": ((-200, 90, 30), (-254, 0, 55)),
    }
    out = []
    for name, (eye, look) in views.items():
        cam.location = eye
        d = Vector(look) - Vector(eye)
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        f = Path(rdir) / f"{NAME}_{tag}_{name}.png"
        sc.render.filepath = str(f)
        bpy.ops.render.render(write_still=True)
        out.append(f)
        log(f"render {f.name}")
    return out


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(a[0] if a else ROOT / "assets/source/landmarks/amberfall_bridge").resolve()
    rdir = out / "renders"
    rdir.mkdir(parents=True, exist_ok=True)
    mode = os.environ.get("BRIDGE_MODE", "clay")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    t = time.time()
    pc = Piece()
    build(pc)
    lows = objects(pc)
    log("LOW " + " ".join(f"{r}={sum(len(p.vertices) - 2 for p in o.data.polygons)}" for r, o in lows.items())
        + f"  total={sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in lows.values())}  {time.time() - t:.1f}s")
    if mode == "clay":
        cm = G.clay_mat()
        for o in lows.values():
            o.data.materials.append(cm)
        files = context_render(list(lows.values()), rdir, "clay", int(os.environ.get("VESP_RENDER_SAMPLES", 24)))
    else:
        import vesp_bake as VB
        cpu_cycles()
        stone, wood = H.src("medieval_blocks_03", "stone"), H.src("distressed_painted_planks", "lacquer")
        tile, metal = H.src("roof_slates_02", "tiles"), H.src("metal_plate_02", "iron")
        srcs = {"Tower": (stone, 6.0, 0.6), "Deck": (stone, 6.0, 0.6), "Arch": (stone, 5.0, 0.6), "Pier": (stone, 8.0, 1.1),
                "Tiles": (tile, 7.0, 0.55), "Lacquer": (wood, 5.0, 0.5), "Soffit": (wood, 5.0, 0.6), "Iron": (metal, 3.0, 0.35),
                "Banner": (wood, 9.0, 0.6), "Gilt": (metal, 3.0, 0.35)}
        highs = {}
        for i, (role, lo) in enumerate(lows.items()):
            s, tl, edge = srcs[role.rstrip("WE") if role[-1] in "WE" and role not in ("Tiles",) else role]
            highs[role] = high_copy(lo, 71 + 7 * i, edge)
            highs[role].data.materials.append(VB.hi_material(f"Hi_Bridge{role}", s, tile=tl))
            VB.unwrap(lo)
            log(f"HIGH {role} {VB.tris(highs[role])} tris")
        gold_moss = (0.42, 0.33, 0.12)
        stone_look = dict(base=0.42, grime=0.4, edge=0.35, sat=0.32, stone_tint=(1.06, 0.92, 0.7), moss=0.55, moss_open=0.45,
                          moss_col=gold_moss, lichen=0.45, lichen_col=(0.78, 0.66, 0.36), cavity=0.6, rough_base=0.86)
        trim_look = dict(stone_look, base=0.34, grime=0.5, cavity=0.75)
        looks = {}
        for r in lows:
            if r.startswith(("Tower", "Deck", "Pier")):
                looks[r] = VB.Look(**stone_look)
            elif r.startswith("Arch"):
                looks[r] = VB.Look(**trim_look)
        looks.update({
            "Tiles": VB.Look(base=0.2, grime=0.5, edge=0.25, sat=0.18, stone_tint=(1.02, 0.96, 0.86), moss=0.5, moss_open=0.6,
                             moss_col=gold_moss, lichen=0.3, lichen_col=(0.78, 0.66, 0.36), cavity=0.7, rough_base=0.8),
            "Lacquer": VB.Look(base=0.34, grime=0.45, edge=0.3, sat=0.62, stone_tint=(1.0, 0.27, 0.18), cavity=0.55, rough_base=0.6,
                               streak_dark=0.25),
            "Soffit": VB.Look(base=0.16, grime=0.6, edge=0.15, sat=0.5, stone_tint=(0.75, 0.32, 0.25), cavity=0.5, rough_base=0.8),
            "Iron": VB.Look(base=0.16, grime=0.55, edge=0.35, sat=0.7, stone_tint=(0.72, 0.36, 0.2), cavity=0.8, rough_base=0.85),
            "Banner": VB.Look(base=0.36, grime=0.4, edge=0.1, sat=0.7, stone_tint=(1.0, 0.2, 0.14), cavity=0.3, rough_base=0.92),
            "Gilt": VB.Look(base=0.5, grime=0.45, edge=0.55, sat=0.75, stone_tint=(1.0, 0.76, 0.36), cavity=0.7, rough_base=0.45),
        })
        rkw = {"views": (("q34", 150.0), ("front", 180.0)), "ez": 6.0, "res": (1600, 1000)}
        files, entry = G.finish(NAME, "Amberfall", lows, highs, out, looks, {r: (0.35, 0.7) for r in lows},
                                "Poly Haven medieval_blocks_03, roof_slates_02, distressed_painted_planks, metal_plate_02 (CC0)",
                                extra={"collision": {"TowerW": "PreciseConvexDecomposition", "TowerE": "PreciseConvexDecomposition",
                                                     "DeckW": "PreciseConvexDecomposition", "DeckE": "PreciseConvexDecomposition"}},
                                builder=BUILDER, render_kw=rkw)
        G.merge_manifest(out, {NAME: entry}, "Amberfall landmark: Broken Ravine Bridge")
        files = files + context_render(list(objs for objs in bpy.data.objects if objs.name.startswith(NAME)), rdir, "baked", 48)
    dst = rdir / f"{NAME}_{mode}_sheet.jpg"
    try:  # the sheet needs a system python with PIL; the renders stand on their own without it
        FG.sheet([files[:3], files[3:6]] if len(files) >= 6 else [files], dst)
        log("sheet", dst)
    except Exception as e:  # noqa: BLE001
        log("sheet skipped:", e)


if __name__ == "__main__":
    main()
