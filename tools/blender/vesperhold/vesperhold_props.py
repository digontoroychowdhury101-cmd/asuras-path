"""Vesperhold kit group F: figures and props (hooded statues, gargoyles, candles, braziers, banners + pole with OUR sigil, chains,
gibbet cage, fences, gravestones, tomb, rubble, masonry, ruined arch, waterfall sheets). Built on vesperhold_kit.py via vesp_common.py.

  /Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 -P tools/blender/vesperhold/vesperhold_props.py -- <out_dir>
  default out_dir: assets/source/vesperhold/props   env: VESP_ONLY=Piece,Piece  VESP_REUSE_MAPS=1  VESP_NORENDER=1

Units studs, pivot foot centre (z = 0 at the floor, Blender Z up -> GLB Y up). Pieces face Blender -Y (the contact-sheet camera).
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
if "--" not in sys.argv or not sys.argv[sys.argv.index("--") + 1:]:
    sys.argv += ["--", str(Path(__file__).resolve().parents[3] / "assets/source/vesperhold/props")]
import vesp_common as C  # noqa: E402
from vesp_common import K, USub, cfg, fbm, vnoise  # noqa: E402
import vesperhold_figures  # noqa: E402,F401  (keeps the hand-modelled statues' manifest entries; they are built there)
import vesperhold_gargoyles  # noqa: E402,F401  (keeps the hand-modelled gargoyles' manifest entries; they are built there)
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

K.SUBMAT["Bone"] = "Vesp_Frost"
K.NOFROST.add("Bone")
K.NOFROST.add("FigureSmooth")
PI = math.pi
Tr, Rz, Ry = K.Tr, K.Rz, K.Ry


def Rx(a):
    return Matrix.Rotation(a, 4, "X")


def Sc(sx, sy, sz):
    return Matrix.Diagonal((sx, sy, sz, 1.0))


def lerp(a, b, t):
    return a + (b - a) * t


def sstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def put(sub, prim, T=None, T0=None):
    """Add a prim (2- or 3-tuple) with optional local transform T then piece offset T0."""
    M = T0 if T is None else (T0 @ T if T0 is not None else T)
    if not isinstance(sub, USub):
        prim = prim[:2]  # flat kit sub takes (verts, faces)
    sub.add(prim, M)


def bez(ctrl, n=10):
    """Bezier through control points (degree = len-1)."""
    ctrl = [Vector(c) for c in ctrl]
    out = []
    for i in range(n):
        t = i / (n - 1)
        p = list(ctrl)
        while len(p) > 1:
            p = [p[j] * (1 - t) + p[j + 1] * t for j in range(len(p) - 1)]
        out.append(p[0])
    return out


def taper(n, r0, r1, bulge=0.0):
    return [lerp(r0, r1, i / (n - 1)) * (1 + bulge * math.sin(PI * i / (n - 1))) for i in range(n)]


def ellipsoid(rx, ry, rz, seg=14, rings=9):
    prof = [(0.001, -1.0)] + [(math.sin(PI * i / rings), -math.cos(PI * i / rings)) for i in range(1, rings)] + [(0.0, 1.0)]
    vs, fs, fuv = C.revolve(prof, seg)
    return [(x * rx, y * ry, z * rz) for x, y, z in vs], fs, None


def ring_tube(R, r, nmaj=24, nmin=6, rot=0.0):
    vs, fs = [], []
    for i in range(nmaj):
        a = 2 * PI * i / nmaj
        for k in range(nmin):
            b = rot + 2 * PI * k / nmin
            rr = R + r * math.cos(b)
            vs.append((rr * math.cos(a), rr * math.sin(a), r * math.sin(b)))
    for i in range(nmaj):
        for k in range(nmin):
            i2, k2 = (i + 1) % nmaj, (k + 1) % nmin
            fs.append((i * nmin + k, i2 * nmin + k, i2 * nmin + k2, i * nmin + k2))
    return vs, fs


def loop_tube(path, r, nmin=6):
    """Closed tube along a closed planar polyline (any plane)."""
    P = [Vector(p) for p in path]
    n = len(P)
    nrm = Vector((0, 0, 0))
    for i in range(n):
        a, b = P[i], P[(i + 1) % n]
        nrm += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
    nrm = nrm.normalized() if nrm.length > 1e-9 else Vector((0, 0, 1))
    vs, fs = [], []
    for i in range(n):
        t = (P[(i + 1) % n] - P[i - 1]).normalized()
        rad = nrm.cross(t).normalized()
        for k in range(nmin):
            b = 2 * PI * k / nmin
            vs.append(tuple(P[i] + (rad * math.cos(b) + nrm * math.sin(b)) * r))
    for i in range(n):
        for k in range(nmin):
            i2, k2 = (i + 1) % n, (k + 1) % nmin
            fs.append((i * nmin + k, i2 * nmin + k, i2 * nmin + k2, i * nmin + k2))
    return vs, fs


def hull_prim(pts):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    bmesh.ops.convex_hull(bm, input=vs)
    bm.verts.ensure_lookup_table()
    bm.verts.index_update()
    used = sorted({v.index for f in bm.faces for v in f.verts})
    remap = {o: i for i, o in enumerate(used)}
    vco = [tuple(bm.verts[i].co) for i in used]
    fs = [tuple(remap[v.index] for v in f.verts) for f in bm.faces]
    bm.free()
    return vco, fs


def rock(rng, rx, ry, rz, n=15, jag=0.28):
    pts = []
    for _ in range(n):
        u, v = rng.uniform(-1, 1), rng.uniform(0, 2 * PI)
        s = math.sqrt(1 - u * u)
        k = 1 + rng.uniform(-jag, jag)
        pts.append((rx * s * math.cos(v) * k, ry * s * math.sin(v) * k, rz * u * k))
    return hull_prim(pts)


def block(rng, hx, hy, hz, j=0.12):
    vs, fs = K.box(-hx, hx, -hy, hy, -hz, hz)
    vs = [(x * (1 + rng.uniform(-j, j)), y * (1 + rng.uniform(-j, j)), z * (1 + rng.uniform(-j, j))) for x, y, z in vs]
    return vs, fs


def drop(p):  # (vs, fs, uv) -> (vs, fs) for the kit flat path
    return p[0], p[1]


def moulded_base(st, tr, hw, z0, steps):
    for (h, grow) in steps:
        st.add(K.box(-hw - grow, hw + grow, -hw - grow, hw + grow, z0, z0 + h))
        z0 += h
    return z0


# ============================================================================================ hooded statues
PROFILE = [(0.0, 2.55, 2.25), (0.35, 2.42, 2.10), (1.5, 2.0, 1.75), (3.5, 1.65, 1.45), (5.0, 1.42, 1.22), (6.2, 1.80, 1.30),
           (7.1, 2.25, 1.35), (7.7, 1.70, 1.32), (8.3, 1.45, 1.35), (9.0, 1.28, 1.30), (9.7, 1.05, 1.12), (10.2, 0.60, 0.72), (10.55, 0.0, 0.0)]


def prof_at(z):
    for (z0, a0, b0), (z1, a1, b1) in zip(PROFILE, PROFILE[1:]):
        if z <= z1:
            t = (z - z0) / (z1 - z0)
            t = t * t * (3 - 2 * t) * 0.5 + t * 0.5
            return lerp(a0, a1, t), lerp(b0, b1, t)
    return 0.0, 0.0


def fold_at(th, z, seed, A=1.0):
    amp = (0.05 + 0.15 * max(0.0, 1 - z / 9.0) ** 1.4) * A
    tri = lambda x: 2 * abs((x % 1.0) - 0.5)
    return amp * (0.9 * (1 - 2 * tri(8 * th / (2 * PI) + 0.15 * math.sin(z * 0.5 + seed) + seed)) + 0.35 * math.cos(13 * th + z * 0.6 + seed * 2.1)
                  + 0.25 * math.cos(3 * th - z * 0.3))


def robe_prim(seed, seg=56, dent=True, bow=0.0):
    zs = [i * 0.14 for i in range(0, 38)] + [5.3 + i * 0.15 for i in range(0, 30)] + [9.8 + i * 0.12 for i in range(0, 7)]
    zs = sorted({round(z, 3) for z in zs if z < 10.5}) + [10.5]
    rings = []
    for z in zs:
        ax, ay = prof_at(z)
        row = []
        for k in range(seg):
            th = 2 * PI * k / seg + 0.22 * math.sin(z * 0.45 + seed)
            f = 1 + fold_at(th, z, seed) * (0.6 if z > 8 else 1.0)
            x, y = ax * math.cos(th) * f, ay * math.sin(th) * f
            if dent and z > 7.7:
                d = (th - 1.5 * PI + PI) % (2 * PI) - PI
                g = math.exp(-(abs(d) / 0.92) ** 6) * math.exp(-(abs(z - 9.05) / 1.1) ** 6)
                rim = math.exp(-((abs(d) - 1.0) / 0.22) ** 2) * math.exp(-(abs(z - 9.05) / 1.35) ** 4) * 0.30
                rim += math.exp(-(d / 0.95) ** 2) * math.exp(-((z - 10.1) / 0.28) ** 2) * 0.30
                x, y = x * (1 - 0.95 * g + rim), y * (1 - 0.95 * g + rim)
            y += 0.55 * max(0.0, z - 8.6) ** 2 * 0.25 - bow * max(0.0, z - 7.7) ** 1.6 * 0.22  # hood tip slumps back / head bows
            row.append((x, y, z))
        rings.append(row)
    vs, fs = K.loft(rings, cap0=True, cap1=False, apex=(0.0, 0.55 * (10.55 - 8.6) ** 2 * 0.25 - bow * (10.55 - 7.7) ** 1.6 * 0.22, 10.55))
    return vs, fs, None


def figure(S, U, seed, T0, staff=False, bow=0.0):
    fg, rp = U["Figure"], U["Rope"]
    put(fg, robe_prim(seed, bow=bow), None, T0)
    # shoulder capelet with scalloped hem
    seg = 48
    rows = []
    for z, ax, ay in ((8.1, 1.45, 1.4), (7.6, 2.1, 1.5), (7.0, 2.45, 1.6), (6.6, 2.55, 1.66)):
        rows.append([(ax * math.cos(2 * PI * k / seg) * (1 + 0.05 * math.cos(9 * 2 * PI * k / seg)),
                      ay * math.sin(2 * PI * k / seg) * (1 + 0.05 * math.cos(9 * 2 * PI * k / seg)),
                      z - (0.42 * max(0.0, math.cos(9 * 2 * PI * k / seg + seed)) if z < 7.2 else 0.0)) for k in range(seg)])
    put(fg, K.loft(rows, cap0=True, cap1=True), None, T0)
    # rope belt + hanging ends
    ax, ay = prof_at(5.0)
    belt = [(ax * 1.02 * math.cos(2 * PI * k / 40), ay * 1.02 * math.sin(2 * PI * k / 40), 5.0 + 0.1 * math.sin(2 * PI * k / 40 * 2)) for k in range(40)]
    put(rp, C.tube(belt + [belt[0], belt[1]], [0.17] * 42, 6, cap0=False, cap1=False, tile=3.0), None, T0)
    for dx, ln in ((-0.18, 2.8), (0.2, 2.2)):
        pts = bez([(dx, -ay - 0.05, 5.0), (dx * 2, -ay - 0.35, 4.0), (dx * 3, -ay - 0.2, 5.0 - ln)], 8)
        put(rp, C.tube(pts, [0.14] * 8, 6, tile=3.0), None, T0)
        put(rp, ellipsoid(0.26, 0.26, 0.5, 8, 5), Tr(dx * 3, -ay - 0.2, 5.0 - ln - 0.35), T0)
    # sleeves + hands
    rng = random.Random(seed)
    arms = [(-1, [(-2.0, -0.2, 7.0), (-2.5, -1.4, 5.8), (-0.55, -2.15, 5.0)])]
    if staff:
        arms.append((1, [(2.0, -0.2, 7.0), (2.6, -1.5, 5.9), (2.45, -2.3, 5.1)]))
    else:
        arms.append((1, [(2.0, -0.2, 7.0), (2.5, -1.4, 5.8), (0.55, -2.15, 5.0)]))
    for sx, ctrl in arms:
        pts = bez(ctrl, 12)
        rad = [lerp(0.5, 0.85, (i / 11) ** 2) for i in range(12)]
        put(fg, C.tube(pts, rad, 14, mult=lambda i, a, s=sx: 1 + 0.12 * math.cos(4 * a + i * 0.7 + s) * (i / 11), tile=8.0, cap1=True), None, T0)
        w = pts[-1]
        put(fg, ellipsoid(0.55, 0.45, 0.35, 10, 6), Tr(w.x, w.y - 0.55, w.z - 0.1), T0)
    if staff:
        sp = (2.45, -2.75)
        put(fg, K.lathe([(0.21, -0.6), (0.21, 12.2)], 10), Tr(sp[0], sp[1], 0), T0)  # staff shaft (uses the stone sub: carved wood-stone)
        for zz in (0.9, 5.9, 9.6):
            put(fg, ring_tube(0.27, 0.07, 14, 5), Tr(sp[0], sp[1], zz), T0)
        vg = S["Verdigris"]
        with_M(vg, T0, lambda t: K.finial(t, sp[0], sp[1], 12.2, 0.55))
    else:
        put(fg, block(rng, 0.62, 0.22, 0.85, 0.05), Rx(-0.3) @ Tr(-1.0, -2.2, 5.6), T0)  # book clasped to the chest


def slab(poly, t):
    """Thin closed plate from a (near-)planar 3D polygon (wing membrane)."""
    P = [Vector(p) for p in poly]
    n = (P[1] - P[0]).cross(P[2] - P[0]).normalized()
    c = sum(P, Vector()) / len(P)
    top = [p + n * t / 2 for p in P] + [c + n * t / 2]
    bot = [p - n * t / 2 for p in P] + [c - n * t / 2]
    vs = [tuple(v) for v in top + bot]
    m = len(P)
    fs = [(i, (i + 1) % m, m) for i in range(m)] + [((i + 1) % m + m + 1, i + m + 1, 2 * m + 1) for i in range(m)]
    fs += [(i, (i + 1) % m, (i + 1) % m + m + 1, i + m + 1) for i in range(m)]
    return vs, fs, None


def hooded_statue(seed):
    def fn(S, U):
        figure(S, U, seed, Tr(0, 0, 0.9), bow=0.0 if seed == 1 else 1.0)
        st = S["Stone"]
        st.add(K.box(-3.3, 3.3, -3.0, 3.0, 0.0, 0.9))
        st.add(K.loft([K.rect(0, 0, 0.9, 3.3, 3.0), K.rect(0, 0, 1.15, 3.0, 2.7)]))
    return fn


cfg_stat = dict(frost_uv=("Figure",), frost_area=0.0, frost_nz=0.7, frost_keep=0.72, frost_off=0.05, frost_from=("Stone",))
for _f in (hooded_statue,):
    pass


def pedestal_statue(S, U):
    st, tr = S["Stone"], S["Tracery"]
    z = 0.0
    for h, g in ((0.6, 3.6), (0.5, 3.3), (0.3, 3.0)):
        st.add(K.box(-g, g, -g, g, z, z + h))
        z += h
    st.add(K.frust(0, 0, z, 2.7, 2.7, z + 1.0, 2.55, 2.55))
    zd = z + 1.0
    hole = [(-0.9, zd + 0.4)] + K.arch(0.9, zd + 0.9, 1.8, 0, 7) + [(0.9, zd + 0.4)]
    for k in range(4):
        tr.add(K.prism([[(-1.9, zd + 0.15), (1.9, zd + 0.15), (1.9, zd + 1.6), (-1.9, zd + 1.6)], hole], -2.75, -2.5), Rz(k * PI / 2))
    zt = zd + 1.9
    st.add(K.box(-2.5, 2.5, -2.5, 2.5, zd, zt))
    tr.add(K.loft([K.rect(0, 0, zt, 2.9, 2.9), K.rect(0, 0, zt + 0.35, 3.15, 3.15), K.rect(0, 0, zt + 0.7, 3.1, 3.1)]))
    figure(S, U, 7.0, Tr(0, 0, zt + 0.7) @ Sc(0.76, 0.76, 0.76), staff=True)


# ============================================================================================ gargoyles
def gargoyle(variant):
    def fn(S, U):
        rng = random.Random(40 + variant)
        fg, st = U["Figure"], S["Stone"]
        B = variant == 1
        st.add(K.box(-2.4, 2.4, -2.2, 3.6, 0.0, 1.4))
        st.add(K.loft([K.rect(0, 0.7, 1.4, 2.4, 2.9), K.rect(0, 0.7, 1.9, 2.7, 3.2)]))
        T0 = Tr(0, 0.3, 1.9)
        add = lambda p, T=None: put(fg, p, T, T0)
        add(ellipsoid(1.45, 2.3, 1.35, 16, 10), Tr(0, 0.0, 1.5) @ Rx(0.35 if not B else 0.7))  # torso
        add(ellipsoid(1.0, 1.3, 1.05, 12, 8), Tr(1.3, 1.4, 0.9)), add(ellipsoid(1.0, 1.3, 1.05, 12, 8), Tr(-1.3, 1.4, 0.9))  # haunches
        for sx in (-1, 1):
            hind = bez([(sx * 1.2, 1.5, 1.0), (sx * 1.9, 0.7, 0.2), (sx * 1.5, -0.4, -1.0)], 9)
            add(C.tube(hind, taper(9, 0.62, 0.3, 0.25), 10, mult=lambda i, a: 1 + 0.12 * math.cos(3 * a + i), tile=6.0))
            fore = bez([(sx * 1.05, -1.6, 2.2), (sx * 1.35, -2.6, 1.0), (sx * 1.2, -3.0, -0.9)], 9)
            add(C.tube(fore, taper(9, 0.58, 0.28, 0.3), 10, mult=lambda i, a: 1 + 0.1 * math.cos(3 * a + i * 0.8), tile=6.0))
            for tx in (-0.38, 0, 0.38):  # claws
                tip = fore[-1]
                add(C.tube([(tip.x + tx * 0.6, tip.y, tip.z), (tip.x + tx, tip.y - 0.5, tip.z - 0.12), (tip.x + tx * 1.1, tip.y - 0.95, tip.z - 0.45)],
                           [0.17, 0.12, 0.02], 6, tile=3.0))
        # neck, head, jaw, brow, horns, ears, teeth
        hx, hy, hz = 0.0, -3.6, 3.3 if not B else 2.4
        add(C.tube(bez([(0, -1.6, 2.5), (0, -2.4, 3.3 if not B else 2.5), (0, hy + 0.5, hz)], 8), taper(8, 0.95, 0.8), 12, tile=6.0, cap1=False))
        add(ellipsoid(0.95, 1.3, 0.85, 14, 9), Tr(hx, hy - 0.3, hz))
        jaw_open = 0.55 if not B else 0.8
        add(ellipsoid(0.75, 1.0, 0.38, 12, 7), Tr(0, hy - 0.75, hz - 0.8 - jaw_open * 0.3) @ Rx(jaw_open * 0.5))
        add(ellipsoid(1.0, 0.45, 0.28, 12, 7), Tr(0, hy - 0.9, hz + 0.45))  # heavy brow
        add(ellipsoid(0.55, 0.55, 0.45, 10, 6), Tr(0, hy - 1.6, hz - 0.25))  # snout
        for sx in (-1, 1):
            add(C.tube(bez([(sx * 0.5, hy + 0.1, hz + 0.65), (sx * 1.2, hy + 0.3, hz + 1.8), (sx * (0.9 if not B else 1.7), hy + 1.0, hz + (2.6 if not B else 2.2))], 9),
                       taper(9, 0.3, 0.03), 8, tile=3.0))
            add(ellipsoid(0.12, 0.55, 0.75, 8, 5), Tr(sx * 1.15, hy + 0.3, hz + 0.45) @ Rx(0.2) @ Rz(sx * 0.4))
            for tz, tl in ((-0.45, 0.4), (-0.15, 0.3)):  # fangs
                add(C.tube([(sx * 0.35, hy - 1.4 - tz * 0.3, hz - 0.35), (sx * 0.34, hy - 1.5, hz - 0.35 - tl)], [0.1, 0.01], 5, tile=3.0))
        # spine ridge + tail
        for i in range(7):
            t = i / 6
            add(C.tube([(0, 1.6 - t * 3.6, 2.6 + 0.4 * math.sin(PI * t) - (0.2 if B else 0) * t), (0, 1.55 - t * 3.6, 3.2 + 0.4 * math.sin(PI * t))], [0.22, 0.02], 5, tile=3.0))
        tail = bez([(0, 2.0, 0.6), (-2.6, 3.4, 0.2), (-3.0, 1.2, 0.4), (-1.8, 0.0, 0.5)], 14)
        add(C.tube(tail, taper(14, 0.5, 0.08), 8, tile=5.0))
        # wings: bone arms + membrane shell
        for sx in (-1, 1):
            wr = Vector((sx * 1.2, 0.0, 3.2))
            tips = [Vector((sx * (3.2 if not B else 5.0), 1.2, 6.3 if not B else 5.8)), Vector((sx * (3.8 if not B else 5.6), 2.6, 4.6)),
                    Vector((sx * (3.2 if not B else 4.4), 3.3, 2.2))]
            for tp in tips:
                add(C.tube(bez([wr, wr.lerp(tp, 0.55) + Vector((0, -0.3, 0.5)), tp], 8), taper(8, 0.22, 0.05), 6, tile=3.0))
            add(C.tube(bez([Vector((sx * 0.7, 0.3, 3.0)), wr, wr.lerp(tips[0], 0.55)], 6), taper(6, 0.4, 0.2), 8, tile=3.0))
            for t0, t1 in zip(tips, tips[1:]):
                mid = (t0 + t1) / 2
                mid = mid.lerp(wr, 0.22)
                poly = [wr, t0, mid, t1]
                add(slab(poly, 0.14))
    return fn


gargoyle_A, gargoyle_B = gargoyle(0), gargoyle(1)


# ============================================================================================ candles / braziers
def flame_prim(h=1.3, w=0.16, seg=10, lean=0.0):
    prof = [(0.001, 0.0)] + [(w * math.sin(PI * (t ** 0.62)) ** 0.9 * (1 - 0.2 * t), h * t) for t in [i / 11 for i in range(1, 11)]] + [(0.0, h)]
    vs, fs, fuv = C.revolve(prof, 12)
    return [(x + lean * (z / h) ** 2, y, z) for x, y, z in vs], fs, fuv


def candle(S, U, rng, pos, h, r=0.55, T0=None, flame=True):
    wx, wy = pos
    wax, fl = U["Wax"], U["Flame"]
    top = h
    prof = [(r * 1.25, 0.0), (r * 1.1, 0.25), (r * 0.98, 0.7), (r, h * 0.5), (r * 0.93, h - 0.3), (r * 1.02, h - 0.08), (r * 0.9, h), (r * 0.45, h - 0.22), (0.001, h - 0.34), (0.0, h - 0.34)]
    prof = prof[:-1]
    vs, fs, fuv = C.revolve(prof[:-1] + [(0.0, h - 0.34)], 14, tile=3.0)
    vs = [(x * (1 + 0.1 * vnoise(x * 2 + wx, y * 2 + wy, z * 1.3)), y * (1 + 0.1 * vnoise(x * 2 + 7 + wx, y * 2 + wy, z * 1.3)), z) for x, y, z in vs]
    wax.add((vs, fs, fuv), Tr(wx, wy, 0) if T0 is None else T0 @ Tr(wx, wy, 0))
    for i in range(rng.randint(2, 4)):  # drips run down the side and end in a bulb
        a = rng.uniform(0, 2 * PI)
        ln = rng.uniform(0.7, min(h * 0.8, 2.6))
        rr = r * 0.98
        pts = [(rr * math.cos(a) * s, rr * math.sin(a) * s, h - 0.05 - ln * t) for t, s in ((0, 0.9), (0.15, 1.04), (0.5, 1.07), (0.85, 1.07), (1.0, 1.06))]
        put(wax, C.tube(pts, [0.2, 0.16, 0.13, 0.12, 0.17], 8, tile=3.0, cap0=True), Tr(wx, wy, 0), T0)
    put(U["Rope"], C.tube([(0, 0, h - 0.3), (0.05, 0, h + 0.15), (0.1, 0, h + 0.4)], [0.05, 0.045, 0.03], 5, tile=2.0), Tr(wx, wy, 0), T0)
    if flame:
        fh = rng.uniform(1.1, 1.5)
        put(fl, flame_prim(fh, 0.17, 10, rng.uniform(-0.1, 0.1)), Tr(wx + 0.1, wy, h + 0.35), T0)


def candle_cluster(variant):
    def fn(S, U):
        rng = random.Random(70 + variant)
        iron = S["Iron"]
        R = 3.1 if variant == 0 else 3.6
        iron.add(K.lathe([(0.5, 0.0), (R * 0.85, 0.0), (R, 0.2), (R * 1.05, 0.55), (R * 0.96, 0.62), (R * 0.9, 0.35), (R * 0.2, 0.3)], 24))
        for a in range(3):  # little feet
            iron.add(K.lathe([(0.35, -0.0), (0.2, 0.3)], 6), Tr(R * 0.7 * math.cos(a * 2.09), R * 0.7 * math.sin(a * 2.09), 0))
        # pooled wax + wax over the rim
        vs, fs, fuv = C.revolve([(0.001, 0.62), (R * 0.82, 0.55), (R * 0.9, 0.5), (R * 0.9, 0.3), (R * 0.3, 0.3), (0.0, 0.3)], 22, tile=6.0)
        vs = [(x * (1 + 0.14 * vnoise(x, y, 3.0)), y * (1 + 0.14 * vnoise(x, y, 9.0)), z) for x, y, z in vs]
        U["Wax"].add((vs, fs, fuv))
        n = 7 if variant == 0 else 9
        pos = []
        for i in range(n):
            for _ in range(40):
                rr, aa = R * 0.78 * math.sqrt(rng.random()), rng.uniform(0, 2 * PI)
                p = (rr * math.cos(aa), rr * math.sin(aa))
                if all(math.hypot(p[0] - q[0], p[1] - q[1]) > 1.15 for q in pos):
                    pos.append(p)
                    break
        hs = [rng.uniform(0.8, 3.9) for _ in pos]
        hs[0] = max(hs[0], 3.8)
        for p, hh in zip(pos, hs):
            candle(S, U, rng, p, hh, r=rng.uniform(0.42, 0.62), T0=Tr(0, 0, 0.5))
    return fn


candle_A, candle_B = candle_cluster(0), candle_cluster(1)


def flame_tongues(U, rng, R, z0, n, hmin, hmax, T0=None):
    for i in range(n):
        a = 2 * PI * i / n + rng.uniform(-0.3, 0.3)
        rr = R * math.sqrt(rng.random()) * 0.7
        put(U["Flame"], flame_prim(rng.uniform(hmin, hmax), rng.uniform(0.35, 0.55) * R * 0.45, 10, rng.uniform(-0.4, 0.4)),
            Tr(rr * math.cos(a), rr * math.sin(a), z0), T0)


def brazier_bowl(S, U, R, z0, rng, T0=None):
    iron = S["Iron"]
    outer = [(0.001, z0 - 0.9), (R * 0.25, z0 - 0.85), (R * 0.58, z0 - 0.62), (R * 0.85, z0 - 0.25), (R * 0.98, z0 + 0.1), (R * 1.0, z0 + 0.55), (R * 1.07, z0 + 0.62), (R * 1.07, z0 + 0.8),
             (R * 0.97, z0 + 0.8), (R * 0.93, z0 + 0.5), (R * 0.9, z0 + 0.1), (R * 0.72, z0 - 0.3), (R * 0.4, z0 - 0.55), (0.0, z0 - 0.62)]
    put(iron, K.lathe(outer, 28), None, T0)
    for zz in (z0 + 0.05, z0 + 0.5):  # riveted bands
        put(iron, ring_tube(R * (1.0 if zz < z0 + 0.3 else 1.01) + 0.03, 0.09, 36, 5), Tr(0, 0, zz), T0)
    for i in range(24):
        a = 2 * PI * i / 24
        put(iron, ellipsoid(0.1, 0.1, 0.07, 6, 3), Tr(R * 1.08 * math.cos(a), R * 1.08 * math.sin(a), z0 + 0.71), T0)
    for sx in (-1, 1):
        put(iron, ring_tube(0.45, 0.09, 12, 5), Tr(sx * (R * 1.0 + 0.4), 0, z0 + 0.2) @ Ry(PI / 2), T0)
    # embers: glowing lumps (flame material) + flame tongues
    for i in range(16):
        a, rr = rng.uniform(0, 2 * PI), R * 0.65 * math.sqrt(rng.random())
        put(U["Flame"], ellipsoid(rng.uniform(0.28, 0.5), rng.uniform(0.28, 0.5), 0.22, 7, 4), Tr(rr * math.cos(a), rr * math.sin(a), z0 + 0.48 + rng.uniform(-0.05, 0.1)), T0)
    flame_tongues(U, rng, R, z0 + 0.5, 7, 1.6, 3.1 if R > 2 else 2.4, T0)


def brazier_iron(S, U):
    rng = random.Random(81)
    iron = S["Iron"]
    R, zb = 2.6, 3.6
    for k in range(3):
        a = k * 2 * PI / 3 + 0.4
        ca, sa = math.cos(a), math.sin(a)
        pts = bez([(ca * 1.7, sa * 1.7, zb - 0.6), (ca * 2.7, sa * 2.7, 2.0), (ca * 1.6, sa * 1.6, 0.9), (ca * 2.3, sa * 2.3, 0.15)], 12)
        iron.add(drop(C.tube(pts, taper(12, 0.34, 0.24, 0.2), 6, tile=3.0)))
        iron.add(K.lathe([(0.5, 0.0), (0.38, 0.35)], 8), Tr(ca * 2.4, sa * 2.4, 0))
        for tx in (-0.35, 0, 0.35):
            iron.add(drop(C.tube([(ca * 2.2 - sa * tx, sa * 2.2 + ca * tx, 0.3), (ca * 2.6 - sa * tx * 1.3, sa * 2.6 + ca * tx * 1.3, 0.1)], [0.14, 0.05], 5, tile=2.0)))
    iron.add(ring_tube(2.0, 0.12, 28, 5), Tr(0, 0, 1.35))
    brazier_bowl(S, U, R, zb + 0.0, rng)


def brazier_post(S, U):
    rng = random.Random(82)
    iron, st = S["Iron"], S["Stone"]
    st.add(K.box(-2.0, 2.0, -2.0, 2.0, 0.0, 0.7))
    st.add(K.frust(0, 0, 0.7, 1.7, 1.7, 1.5, 1.35, 1.35))
    # twisted square post
    pts = [(0, 0, 1.4 + i * 0.5) for i in range(14)]
    iron.add(drop(C.tube(pts, [0.34] * 14, 4, twist=0.28, tile=3.0, cap0=True, cap1=False)))
    for zz, rr in ((1.5, 0.55), (4.6, 0.5), (6.9, 0.55)):
        iron.add(ring_tube(rr, 0.12, 14, 5), Tr(0, 0, zz))
        iron.add(K.lathe([(rr * 0.9, zz - 0.2), (rr * 0.9, zz + 0.2)], 12))
    for k in range(4):  # scroll brackets under the bowl
        a = k * PI / 2 + PI / 4
        ca, sa = math.cos(a), math.sin(a)
        iron.add(drop(C.tube(bez([(ca * 0.3, sa * 0.3, 4.9), (ca * 1.8, sa * 1.8, 5.0), (ca * 1.6, sa * 1.6, 6.3), (ca * 1.05, sa * 1.05, 6.75)], 12), taper(12, 0.16, 0.12), 5, tile=3.0)))
        iron.add(ring_tube(0.38, 0.08, 10, 4), Tr(ca * 1.25, sa * 1.25, 5.5) @ Ry(0) @ Rz(a) @ Rx(PI / 2))
    brazier_bowl(S, U, 1.75, 7.6, rng)
    for k in range(8):  # spike crown
        a = k * PI / 4
        iron.add(K.lathe([(0.12, 8.4), (0.0, 9.2)], 5), Tr(1.88 * math.cos(a), 1.88 * math.sin(a), 0))


# ============================================================================================ banners and pole
def banner(variant):
    def fn(S, U):
        rng = random.Random(90 + variant)
        W, H = 8.0, 30.0
        xs = [-4.0 + i * 0.25 for i in range(33)]
        zs = [i * 0.25 for i in range(0, 29)] + [7.0 + i * 0.8 for i in range(1, 30)]
        zs = [z for z in zs if z <= H] + ([H] if zs[-1] < H else [])
        holes = [(-2.4, 5.4, 0.9, 1.3), (2.6, 24.0, 0.7, 1.0), (-2.9, 26.5, 0.55, 0.8)] if variant == 0 else \
                [(2.2, 8.0, 1.1, 1.6), (-2.4, 4.0, 0.6, 0.9), (3.0, 25.5, 0.5, 0.8), (-2.8, 23.5, 0.8, 0.7)]
        slits = [(-1.6, 6.5, 0.18), (1.1, 9.0, 0.14), (3.0, 10.5, 0.2)] if variant == 0 else [(0.7, 8.5, 0.16), (-3.0, 7.0, 0.15), (2.2, 11.0, 0.2)]
        sk = 1.0 if variant == 0 else -1.0

        def hem(x):
            e = 0.5 + 0.45 * fbm(x * 1.9 + variant * 7.0, 1.7) * 2.0
            e += max(0.0, sk * (x - 1.2 * sk) * 0.75) * 1.5 if True else 0.0  # torn corner on one side
            for sx, sz, sw in slits:
                if abs(x - sx) < sw:
                    e = max(e, sz)
            return max(e, 0.1)

        def present(xc, zc):
            if zc < hem(xc):
                return False
            for hx, hz, rx, rz in holes:
                d = ((xc - hx) / rx) ** 2 + ((zc - hz) / rz) ** 2
                if d < 1.0 + 0.4 * fbm(xc * 3.0 + 5, zc * 3.0):
                    return False
            return True

        def disp(x, z):
            t = 1 - z / H
            bil = 0.75 * math.cos(PI * x / W) * (0.25 + 0.75 * t) * (1 if variant == 0 else 0.7)
            wav = 0.42 * t ** 0.8 * math.sin(2 * PI * x / 3.4 + 0.5 * math.sin(z / 5.0) + variant)
            wav += 0.2 * t * math.sin(z * 0.65 + x * 0.9)
            skew = (0.5 + 0.5 * variant) * math.sin(z / 9.0 + variant) * t
            return (skew, bil + wav, 0.0)

        uvf = lambda x, z: ((x + W / 2) / W, z / H)
        C.USub  # noqa
        U["Banner"].add(C.cloth(W, H, xs, zs, present, disp, 0.16, uvf))
        # top rod sleeve (gold band of the texture) + rope ties + iron eyelets
        sl = [(-4.1 + i * 0.41, 0.0, 29.55) for i in range(21)]
        U["Banner"].add(C.tube(sl, [0.62] * 21, 10, uvfn=lambda i, f, d, r: ((d / 8.2), 0.975 + 0.02 * f), cap0=True, cap1=True))
        for x in (-3.0, 0.0, 3.0):
            U["Rope"].add(C.tube([(x - 0.15, -0.25, 29.1), (x, -0.35, 29.9), (x + 0.15, -0.25, 30.6), (x, -0.1, 30.9), (x - 0.12, 0.1, 30.4)], [0.12] * 5, 6, tile=3.0))
    return fn


banner_A, banner_B = banner(0), banner(1)


def banner_pole(S, U):
    iron, st, cr = S["Iron"], S["Stone"], S["Crockets"]
    st.add(K.box(-2.6, 2.6, -2.6, 2.6, 0.0, 1.0))
    st.add(K.frust(0, 0, 1.0, 2.0, 2.0, 2.4, 1.2, 1.2))
    iron.add(K.lathe([(0.7, 2.3), (0.5, 3.0), (0.42, 4.0), (0.34, 30.0), (0.3, 36.0)], 12))
    for z in (4.0, 12.0, 24.0, 32.6, 33.4):
        iron.add(ring_tube(0.45, 0.12, 14, 5), Tr(0, 0, z))
    # crossbar
    iron.add(drop(C.tube([(-5.6, 0, 33.0), (5.6, 0, 33.0)], [0.27, 0.27], 10, tile=3.0, cap0=True)))
    for sx in (-1, 1):
        iron.add(drop(ellipsoid(0.5, 0.5, 0.5, 10, 6)), Tr(sx * 5.7, 0, 33.0))
        iron.add(drop(C.tube(bez([(sx * 0.4, 0, 31.0), (sx * 2.2, 0, 31.6), (sx * 3.4, 0, 32.4)], 10), [0.15] * 10, 6, tile=3.0)))  # brackets
        iron.add(ring_tube(0.55, 0.08, 14, 4), Tr(sx * 2.6, 0, 31.9) @ Rx(PI / 2))
        for x in (3.8,):  # eyelets for the banner ties
            iron.add(ring_tube(0.28, 0.06, 10, 4), Tr(sx * x, 0, 32.5) @ Rx(PI / 2))
    # spear finial: iron shaft + crocketed verdigris head via the kit finial
    iron.add(K.lathe([(0.3, 35.5), (0.5, 36.0), (0.3, 36.6), (0.3, 37.6)], 8))
    K.finial(cr, 0, 0, 37.0, 0.5)
    for x in (-2.0, 2.0):
        U["Rope"].add(C.tube([(x - 0.4, 0, 33.4), (x, 0.3, 33.5), (x + 0.4, 0, 33.4), (x, -0.3, 33.5), (x - 0.4, 0, 33.4)], [0.11] * 5, 6, tile=3.0))
    U["Rope"].add(C.tube([(0.0, 0.45, 33.0 + 0.0), (0.0, 0.55, 32.6), (0.0, 0.5, 32.0), (0.0, 0.5, 31.0)], [0.12] * 4, 6, tile=3.0))


# ============================================================================================ chain, cage, fence
def chain_hang(S, U):
    iron = S["Iron"]
    L, pitch = 24.0, 1.08
    n = int(L / pitch)
    for i in range(n):
        z = L - 0.9 - i * pitch
        a = 0.35
        path = [(a * math.cos(t) * 0.55, 0, z + math.sin(t) * 0.0) for t in ()]
        pts = []
        for k in range(18):  # stadium outline in the XZ plane (even links) or YZ plane (odd links)
            t = 2 * PI * k / 18
            hx, hz = 0.38 * math.cos(t), 0.78 * math.sin(t) * (1.0 if abs(math.sin(t)) < 0.99 else 1)
            pts.append((hx, hz))
        pr = [(p[0], 0.0, z + p[1]) if i % 2 == 0 else (0.0, p[0], z + p[1]) for p in pts]
        iron.add(loop_tube(pr, 0.11, 6))
    iron.add(ring_tube(0.7, 0.16, 16, 6), Tr(0, 0, L + 0.2) @ Rx(PI / 2))
    iron.add(K.box(-1.1, 1.1, -0.15, 0.15, L + 0.55, L + 0.8))
    iron.add(drop(C.tube(bez([(0, 0, 0.9), (0.0, 0.5, 0.4), (0.0, 0.35, -0.5), (0.0, -0.2, -0.3)], 10), [0.14] * 10, 6, tile=3.0, cap0=True)))


def gibbet_cage(S, U):
    iron, bone = S["Iron"], U["Bone"]
    rings = [(10.0, 0.55, 0.45), (9.2, 1.0, 0.85), (8.2, 1.05, 0.9), (7.0, 0.55, 0.5), (6.4, 1.5, 0.9), (5.2, 1.45, 0.9), (4.0, 1.1, 0.8), (2.9, 1.3, 0.85)]
    seg = 12
    for z, ax, ay in rings:
        pts = [(ax * math.cos(2 * PI * k / seg), ay * math.sin(2 * PI * k / seg), z) for k in range(seg)]
        iron.add(loop_tube(pts, 0.11, 5))
    for k in range(seg):  # vertical straps
        a = 2 * PI * k / seg
        pts = [(ax * math.cos(a), ay * math.sin(a), z) for z, ax, ay in rings]
        iron.add(drop(C.tube(pts, [0.1] * len(pts), 4, tile=3.0, cap0=True)))
    for sx in (-1, 1):  # leg cages
        for z0, z1, w in ((2.9, 0.4, 0.52),):
            lp = [(sx * 0.75 + w * math.cos(2 * PI * k / 8), w * math.sin(2 * PI * k / 8), 0) for k in range(8)]
            for zz in (2.2, 1.4, 0.6):
                iron.add(loop_tube([(x, y, zz) for x, y, _ in lp], 0.09, 5))
            for k in range(8):
                iron.add(drop(C.tube([(lp[k][0], lp[k][1], z0), (lp[k][0], lp[k][1], z1)], [0.08, 0.08], 4, tile=3.0, cap0=True)))
    iron.add(K.box(-1.7, 1.7, -1.1, 1.1, 0.0, 0.25))
    iron.add(K.lathe([(0.2, 10.0), (0.6, 10.4), (0.1, 10.9)], 8))
    for i in range(5):  # hanging chain + ring
        iron.add(loop_tube([(0.2 * math.cos(t), 0.0, 11.0 + i * 0.85 + 0.42 * math.sin(t)) if i % 2 == 0 else (0.0, 0.2 * math.cos(t), 11.0 + i * 0.85 + 0.42 * math.sin(t))
                            for t in [2 * PI * k / 12 for k in range(12)]], 0.07, 5))
    iron.add(ring_tube(0.6, 0.11, 14, 5), Tr(0, 0, 15.3) @ Rx(PI / 2))
    # remains: skull, spine, ribs
    bone.add(ellipsoid(0.62, 0.7, 0.6, 12, 8), Tr(0, 0.0, 9.0))
    bone.add(ellipsoid(0.42, 0.5, 0.22, 10, 6), Tr(0, -0.35, 8.45))
    for sx in (-1, 1):
        bone.add(ellipsoid(0.17, 0.12, 0.17, 6, 4), Tr(sx * 0.27, -0.62, 9.1))
    bone.add(C.tube([(0, 0.25, 8.0), (0, 0.4, 7.0), (0, 0.45, 6.0), (0, 0.4, 5.0), (0, 0.3, 4.0)], [0.16] * 5, 8, tile=3.0))
    for zz in (6.8, 6.2, 5.6, 5.0):
        for sx in (-1, 1):
            bone.add(C.tube(bez([(0, 0.42, zz), (sx * 0.9, 0.25, zz - 0.1), (sx * 0.85, -0.45, zz - 0.35)], 7), taper(7, 0.12, 0.07), 5, tile=3.0))


def iron_fence(S, U):
    iron, st = S["Iron"], S["Stone"]
    st.add(K.box(-5.0, 5.0, -0.8, 0.8, 0.0, 0.8))
    st.add(K.box(-5.0, 5.0, -0.65, 0.65, 0.8, 1.0))
    for z in (1.5, 4.6):
        iron.add(K.box(-5.0, 5.0, -0.17, 0.17, z, z + 0.3))
    for i in range(14):
        x = -4.55 + i * 0.7
        iron.add(K.box(x - 0.1, x + 0.1, -0.1, 0.1, 1.0, 5.9))
        iron.add(K.pyr(x, 0, 5.9, 0.16, 0.16, 6.9))
    for px in (-5.0, -2.5, 0.0, 2.5, 5.0):
        px2 = min(max(px, -4.7), 4.7)
        iron.add(K.box(px2 - 0.28, px2 + 0.28, -0.28, 0.28, 1.0, 6.6))
        iron.add(K.lathe([(0.45, 6.5), (0.4, 6.9), (0.3, 7.3), (0.5, 7.6), (0.3, 8.0), (0.0, 8.5)], 8), Tr(px2, 0, 0))
    for i in range(4):  # scroll rings between the rails
        iron.add(ring_tube(0.5, 0.07, 14, 4), Tr(-3.75 + i * 2.5, 0, 3.1) @ Rx(PI / 2))


# ============================================================================================ graves, tomb, rubble, masonry
def with_M(sub, M, fn):
    """Run a kit helper that adds straight into a Sub (foil etc.) and re-add its prims through the matrix M."""
    tmp = K.Sub(sub.mat)
    fn(tmp)
    for pr in tmp.prims:
        sub.add(pr, M)


def gravestone(kind):
    def fn(S, U):
        rng = random.Random(100 + kind)
        fg = S["Figure"]
        w, h, th = [(3.4, 5.4, 0.8), (3.0, 4.6, 0.75), (3.2, 4.4, 0.8), (2.4, 5.0, 0.8)][kind]
        a = w / 2
        R = a * 1.7
        zs = h - K.arch_h(a, R)
        arc = K.arch(a, zs, R, 0, 9)
        if kind == 2:  # broken: ragged diagonal top
            outline = [(-a, 0.0), (a, 0.0), (a, h * 0.58), (a * 0.5, h * 0.7), (a * 0.2, h * 0.55), (-a * 0.35, h * 0.84), (-a, h * 0.7)]
        elif kind == 3:  # gothic cross-headed stone
            c, arm = 0.55, 1.55
            zb = h * 0.58
            outline = [(-1.0, 0.0), (1.0, 0.0), (c, 0.9), (c, zb), (arm, zb), (arm, zb + 0.8), (c, zb + 0.8), (c, h), (-c, h), (-c, zb + 0.8), (-arm, zb + 0.8), (-arm, zb), (-c, zb), (-c, 0.9)]
        else:
            outline = [(-a, 0.0), (a, 0.0)] + arc[::-1]
        M = Rx([0.0, 0.16, -0.1, 0.12][kind]) @ Ry([0.0, 0.14, 0.05, -0.12][kind])
        fg.add(K.prism([outline], -th / 2, th / 2), M)
        fg.add(K.box(-a - 0.5, a + 0.5, -th / 2 - 0.55, th / 2 + 0.55, -1.0, 0.35), M)  # sunken plinth
        fg.add(K.box(-a - 0.25, a + 0.25, -th / 2 - 0.3, th / 2 + 0.3, 0.35, 0.65), M)
        if kind != 3:
            if kind == 2:
                inner = [(-a * 0.7, 0.9), (a * 0.7, 0.9), (a * 0.7, h * 0.42), (-a * 0.7, h * 0.42)]
            else:
                inner = [(-a * 0.78, 0.9), (a * 0.78, 0.9)] + [(x * 0.78, zs * 0.9 + (z - zs) * 0.74) for x, z in arc[::-1]]
            fg.add(K.prism([inner], -th / 2 - 0.1, -th / 2 + 0.05), M)
        if kind in (0, 1):
            with_M(fg, M, lambda t: t.add(K.sweep(K.circle(0.0, h * 0.64, 0.7, 24), K.barf(0.2, 0.16), -th / 2 - 0.05, -1.0, closed=True)))
            zc = h * 0.64
            fg.add(K.box(-0.09, 0.09, -th / 2 - 0.15, -th / 2, zc - 0.5, zc + 0.45), M)
            fg.add(K.box(-0.32, 0.32, -th / 2 - 0.15, -th / 2, zc + 0.08, zc + 0.24), M)
        if kind == 3:
            with_M(fg, M, lambda t: K.foil(t, 0.0, h * 0.58 + 0.4, 0.34, 3, -th / 2 - 0.08, -1.0, 0.12, 0.12))
        if kind == 2:
            fg.add(K.box(-0.7, 0.7, -th / 2 - 0.1, -th / 2, h * 0.26, h * 0.3), M)
            fg.add(rock(rng, 1.0, 0.45, 0.7), Tr(2.4, -1.6, 0.6) @ Rz(0.7))
        for i in range(3 if kind != 3 else 0):  # worn inscription lines
            ww = rng.uniform(0.9, 1.7)
            fg.add(K.box(-ww / 2, ww / 2, -th / 2 - 0.12, -th / 2 - 0.02, 1.1 + i * 0.42, 1.22 + i * 0.42), M)
    return fn


def tomb_slab(S, U):
    rng = random.Random(110)
    fg, tr = S["Figure"], S["Tracery"]
    fg.add(K.box(-5.0, 5.0, -2.8, 2.8, 0.0, 0.7))
    fg.add(K.box(-4.6, 4.6, -2.4, 2.4, 0.7, 2.3))
    hole = [(-0.9, 0.95)] + K.arch(0.9, 1.5, 1.8, 0, 6) + [(0.9, 0.95)]
    for flip in (0, 1):  # blind arched panels on both long sides
        for cx in (-2.7, 0.0, 2.7):
            tr.add(K.prism([[(-1.15, 0.85), (1.15, 0.85), (1.15, 2.1), (-1.15, 2.1)], hole], 2.4, 2.55), Rz(PI * flip) @ Tr(cx, 0, 0))
    fg.add(K.loft([K.rect(0, 0, 2.3, 4.6, 2.4), K.rect(0, 0, 2.6, 5.0, 2.8), K.rect(0, 0, 3.0, 4.9, 2.7)]))
    # recumbent hooded effigy lying on the slab
    U["Figure"].add(ellipsoid(0.75, 0.62, 0.6, 12, 7), Tr(-3.0, 0, 3.6))
    U["Figure"].add(C.tube([(-2.5, 0, 3.4), (-0.5, 0, 3.4), (2.2, 0, 3.3), (3.9, 0, 3.3)], [0.85, 1.05, 0.9, 0.6], 14, mult=lambda i, a: 1 + 0.15 * math.cos(5 * a + i), tile=8.0))
    for sy in (-1, 1):
        U["Figure"].add(C.tube([(-1.8, sy * 0.9, 3.5), (0.2, sy * 0.85, 3.6), (0.3, sy * 0.2, 3.9)], [0.35, 0.3, 0.26], 8, tile=6.0))
    fg.add(rock(rng, 1.1, 0.8, 0.5), Tr(6.3, -3.0, 0.5) @ Rz(0.5))
    fg.add(rock(rng, 0.7, 0.5, 0.4), Tr(5.7, -3.9, 0.35) @ Rz(1.1))


def rubble_pile(S, U):
    rng = random.Random(120)
    st, fg = S["Stone"], S["Figure"]
    for i in range(42):
        r = 6.2 * math.sqrt(rng.random())
        a = rng.uniform(0, 2 * PI)
        hmax = 4.2 * (1 - r / 6.4) ** 1.2
        z = rng.uniform(0.0, 1.0) * hmax
        s = rng.uniform(0.7, 1.9) * (1.25 - 0.4 * r / 6.2)
        pos = Tr(r * math.cos(a), r * math.sin(a), z + 0.3 * s)
        rot = Rz(rng.uniform(0, 2 * PI)) @ Rx(rng.uniform(-0.5, 0.5)) @ Ry(rng.uniform(-0.5, 0.5))
        if rng.random() < 0.45:
            st.add(block(rng, s * rng.uniform(0.7, 1.3), s * rng.uniform(0.5, 0.9), s * rng.uniform(0.4, 0.7), 0.16), pos @ rot)
        else:
            fg.add(rock(rng, s, s * rng.uniform(0.6, 1.0), s * rng.uniform(0.5, 0.9)), pos @ rot)
    for i in range(30):  # gravel skirt
        a, r = rng.uniform(0, 2 * PI), rng.uniform(3.0, 8.0)
        fg.add(rock(rng, 0.45, 0.4, 0.3, 9), Tr(r * math.cos(a), r * math.sin(a), 0.2) @ Rz(a))
    # a broken moulded cornice and a column drum lying in the pile
    st.add(K.xext([(-0.9, 0), (0.9, 0), (0.9, 0.5), (0.5, 0.9), (0.9, 1.1), (-0.9, 1.1)], -2.2, 2.2), Tr(1.8, -1.0, 0.9) @ Rz(0.5) @ Rx(0.18))
    st.add(K.lathe([(1.0, 0.0), (1.0, 2.6)], 12), Tr(-2.6, 1.2, 1.0) @ Ry(PI / 2 - 0.25) @ Tr(0, 0, -1.3))


def masonry_chunk(kind):
    def fn(S, U):
        rng = random.Random(130 + kind)
        st, fg = S["Stone"], S["Figure"]
        if kind == 0:  # broken column drum with a scrap of capital
            prof = [(1.5, 0.0), (1.4, 0.4), (1.2, 0.5), (1.15, 3.0), (1.3, 3.2), (1.55, 3.7), (1.75, 4.2)]
            vs, fs = K.lathe(prof, 12)
            vs = [(x * (1 + rng.uniform(-0.03, 0.03)), y * (1 + rng.uniform(-0.03, 0.03)), z - (0.9 * max(0.0, (x / 1.5)) * (z / 4.0) if z > 2.2 else 0)) for x, y, z in vs]
            st.add((vs, fs))
            fg.add(rock(rng, 0.8, 0.5, 0.45), Tr(2.6, -1.0, 0.4))
            fg.add(rock(rng, 0.5, 0.4, 0.3), Tr(-2.2, 1.6, 0.3))
        else:  # voussoir / cornice block with a moulding and a snapped end
            prof = [(-1.2, 0), (1.2, 0), (1.2, 0.8), (0.8, 1.2), (1.4, 1.5), (1.4, 2.0), (0.6, 2.4), (-0.6, 2.4), (-1.4, 2.0), (-1.4, 1.5), (-0.8, 1.2), (-1.2, 0.8)]
            vs, fs = K.xext(prof, -3.4, 3.4)
            vs = [(x + (rng.uniform(-0.35, 0.35) if abs(x) > 3.0 else 0), y, z + (rng.uniform(-0.25, 0.25) if abs(x) > 3.0 else 0)) for x, y, z in vs]
            st.add((vs, fs), Rz(0.25) @ Tr(0, 0, 0))
            fg.add(rock(rng, 1.0, 0.6, 0.5), Tr(3.9, -1.8, 0.5))
            st.add(block(rng, 0.9, 0.6, 0.5, 0.2), Tr(-3.6, 2.0, 0.5) @ Rz(0.4))
    return fn


masonry_A, masonry_B = masonry_chunk(0), masonry_chunk(1)


def lay(sub, prim, x, y, rz, rx=0.0, ry=0.0, sink=0.15):
    """Drop a prim (centred at the origin) onto the ground at (x, y) with a rotation; its lowest point sinks `sink` into the ground."""
    M = Rz(rz) @ Rx(rx) @ Ry(ry)
    vs = [tuple(M @ Vector(p)) for p in prim[0]]
    z0 = min(v[2] for v in vs)
    sub.add(([(vx + x, vy + y, vz - z0 - sink) for vx, vy, vz in vs], prim[1]))


def shaft(sub, x, y, z0, z1, r, rng=None, jag=0.0, seg=10, cap=True):
    """Engaged shaft with a moulded base; rng + jag give a snapped, jagged top at mean height z1."""
    ring = lambda rr, z: [(x + rr * math.cos(2 * PI * k / seg), y + rr * math.sin(2 * PI * k / seg), z) for k in range(seg)]
    top = [(px, py, pz + (rng.uniform(-jag, jag) if rng else 0.0)) for px, py, pz in ring(r, z1)]
    rings = [ring(r * 1.5, z0), ring(r * 1.5, z0 + 0.5 * r), ring(r * 1.1, z0 + 0.9 * r), ring(r, z0 + 1.3 * r), top]
    if cap and not jag:  # bell capital + abacus on an intact shaft
        rings += [ring(r * 1.1, z1 + 0.25 * r), ring(r * 1.7, z1 + 1.6 * r), ring(r * 1.9, z1 + 1.8 * r), ring(r * 1.9, z1 + 2.3 * r)]
    sub.add(K.loft(rings))


def ruined_arch(S, U):
    """Broken two-order gothic arcade arch: clustered-shaft piers (core + inner, face and corner shafts), the right pier whole with
    bell capitals, the left pier snapped ragged at ~10; the right half of the arch stands past the apex with the inner order stepping
    out beyond the outer at the break, slipped end voussoirs, rolled arrises + hood mould; fallen voussoirs, a capital, shaft drums and
    rubble below the break."""
    rng = random.Random(140)
    st, tr, fg = S["Stone"], S["Tracery"], S["Figure"]
    a, Rr, zs, n = 10.0, 20.0, 16.0, 13
    d1, d2, yi, yo = 1.7, 3.4, 1.8, 2.9
    xi, xo, yc = a + 0.6, a + 4.6, 2.6  # pier core |x| range and half depth
    nseg = 2 * n - 2
    for sx, top in ((1, zs - 2.2), (-1, 10.0)):
        broken = sx < 0
        st.add(K.loft([K.rect(sx * (xi + xo) / 2, 0, 0.0, (xo - xi) / 2 + 0.7, yc + 0.8), K.rect(sx * (xi + xo) / 2, 0, 0.9, (xo - xi) / 2 + 0.7, yc + 0.8),
                       K.rect(sx * (xi + xo) / 2, 0, 1.4, (xo - xi) / 2 + 0.3, yc + 0.4)]))  # chamfered plinth
        xa, xb = sorted((sx * xi, sx * xo))
        z, row = 1.4, 0
        while z < top - 0.3:  # coursed core with offset joints; the broken pier's top course is snapped block by block
            hh = min(rng.uniform(1.5, 2.3), top - z)
            for b in range(2):
                ya, yb = (-yc, 0.35 * (1 if row % 2 else -1)) if b == 0 else (0.35 * (1 if row % 2 else -1), yc)
                cut = rng.uniform(0.3, 2.2) if (broken and z + hh >= top - 0.6) else 0.0
                st.add(K.box(xa + 0.04, xb - 0.04, ya + 0.04, yb - 0.04, z + 0.04, max(z + hh - cut, z + 0.5)))
            z += hh
            row += 1
        brk = lambda h: (h + rng.uniform(-1.5, 1.0)) if broken else top
        shaft(tr, sx * (xi - 0.1), 0.0, 1.4, brk(top), 0.8, rng if broken else None, 0.6 if broken else 0.0)  # inner shaft (inner order)
        for yy in (-1, 1):
            shaft(tr, sx * (xi + xo) / 2, yy * (yc + 0.15), 1.4, brk(top - 1.0), 0.75, rng if broken else None, 0.6 if broken else 0.0)  # face shafts
            for xc in (xi, xo):
                shaft(tr, sx * xc, yy * yc, 1.4, brk(top - 2.0), 0.42, rng if broken else None, 0.4 if broken else 0.0, 8)  # corner shafts
        if not broken:  # impost block the orders spring from
            tr.add(K.loft([K.rect(sx * (xi + xo) / 2 - sx * 0.3, 0, zs - 0.9, (xo - xi) / 2 + 1.2, yc + 1.1),
                           K.rect(sx * (xi + xo) / 2 - sx * 0.3, 0, zs, (xo - xi) / 2 + 1.2, yc + 1.1)]))
    ain, am, aout = K.arch(a, zs, Rr, 0.0, n), K.arch(a, zs, Rr, d1, n), K.arch(a, zs, Rr, d2, n)
    ib_in, ib_out = n - 4, n - 2  # the inner order survives 3 voussoirs past the apex, the outer order 1: a stepped, ragged break

    def vous(pin, pout, i, y, f=0.965):
        q = [pin[i], pout[i], pout[i + 1], pin[i + 1]]
        cx, cz = sum(p[0] for p in q) / 4, sum(p[1] for p in q) / 4
        return K.prism([[(cx + (p[0] - cx) * f, cz + (p[1] - cz) * f) for p in q]], -y, y), (cx, cz)

    for pin, pout, y, ib in ((ain, am, yi, ib_in), (am, aout, yo, ib_out)):
        for i in range(ib, nseg):
            prim, (cx, cz) = vous(pin, pout, i, y - rng.uniform(0.0, 0.15))
            k = ib + 2 - i  # the last two voussoirs at the break have slipped (dropped and twisted on their joints)
            T = Tr(cx, 0, cz - 0.12 * k) @ Ry(0.05 * k * rng.uniform(0.6, 1.4)) @ Rz(0.03 * k * rng.uniform(-1, 1)) @ Tr(-cx, 0, -cz) if k > 0 else None
            st.add(prim, T)
    roll = [(0.4 * math.cos(2 * PI * q / 8), 0.4 * math.sin(2 * PI * q / 8)) for q in range(8)]
    for sgn in (-1, 1):  # rolled arrises on both orders + hood mould over the surviving ring
        tr.add(K.sweep(K.arch(a, zs, Rr, 0.0, n)[ib_in + 1:], roll, sgn * yi, 1.0))
        tr.add(K.sweep(K.arch(a, zs, Rr, d1, n)[ib_out + 1:], roll, sgn * yo, 1.0))
        tr.add(K.sweep(K.arch(a, zs, Rr, d2, n)[ib_out + 1:], K.mould([("roll", 0.5, 0.45), ("cove", 0.4, 0.3)]), sgn * yo, sgn))
    # fallen pieces under the break: voussoirs of both orders, a capital, shaft drums, core blocks, rubble
    for k in range(6):
        prim, (cx, cz) = vous(ain if k < 4 else am, am if k < 4 else aout, n - 5 - k, yi if k < 4 else yo)
        prim = ([(px - cx, py, pz - cz) for px, py, pz in prim[0]], prim[1])
        lay(st, prim, -8.5 + k * 1.9 + rng.uniform(-0.6, 0.6), rng.uniform(-4.6, 4.6), rng.uniform(0, 2 * PI), rng.uniform(-1.2, 1.2), rng.uniform(-0.3, 0.3))
    for k in range(3):  # snapped shaft drums
        r_, ln = (0.8, 3.2) if k == 0 else (0.42, 2.2)
        dr = K.lathe([(r_, -ln / 2), (r_, ln / 2)], 10)
        lay(tr, dr, -6.0 + k * 3.1, -3.8 + k * 2.9 + rng.uniform(-0.5, 0.5), rng.uniform(0, 2 * PI), PI / 2, 0.0, 0.05)
    cap = K.loft([K.rect(0, 0, -1.0, 1.2, 1.2), K.rect(0, 0, 0.2, 2.0, 2.0), K.rect(0, 0, 0.9, 2.0, 2.0)])
    lay(tr, cap, -4.2, 4.4, 0.7, 0.35, 0.2)
    for i in range(30):
        r, ang = rng.uniform(0.0, 7.5), rng.uniform(0, 2 * PI)
        s = rng.uniform(0.45, 1.5) * (1.15 - 0.05 * r)
        x, y = -a - 2.0 + r * math.cos(ang), r * math.sin(ang) * 0.75
        if rng.random() < 0.5:
            lay(st, block(rng, s, s * 0.8, s * 0.55, 0.15), x, y, rng.uniform(0, 7), rng.uniform(-0.4, 0.4), 0.0, s * 0.2)
        else:
            lay(fg, rock(rng, s, s * 0.8, s * 0.7), x, y, rng.uniform(0, 7), 0.0, 0.0, s * 0.25)


# ============================================================================================ waterfalls
K.SUBMAT["Foam"] = "Vesp_Water"
K.NOFROST.add("Foam")


def waterfall(variant):
    """Falling sheet from overlapping, staggered single-sheet cards (front + back faces on shared verts, back-face culled so each side
    draws once). Each card maps its full width to one feathered column of the Vesp_Water map and v to arclength (0 base .. 1 lip), so
    there are no row seams and the soft card edges cross-fade; three layers at >= 1 stud spacing (no near-coplanar transparent sheets)."""
    W, H = (20.0, 80.0) if variant == 0 else (30.0, 160.0)

    def fn(S, U):
        rng = random.Random(150 + variant)
        wa, fo = U["Water"], U["Foam"]
        wa.recalc = False  # open cards: keep the authored front/back winding (recalc may flip a whole island)
        out = lambda z: (6.2 / math.sqrt(H)) * math.sqrt(max(H - z, 0.0))
        zs = [H * (1 - (i / 40) ** 1.5) for i in range(41)][::-1]  # rows dense near the lip, where the sheet curls over
        for li, (gap, wmul) in enumerate(((0.0, 1.0), (1.1, 0.85), (2.3, 0.7))):
            nstr = max(3, int(W / (5.0 - li * 0.6)))
            pitch = W / nstr
            for s in range(nstr + li % 2):
                cx = -W / 2 + pitch * (s + (0.0 if li % 2 else 0.5)) + rng.uniform(-0.6, 0.6)
                w_s = pitch * rng.uniform(1.6, 2.0) * wmul  # neighbours overlap 60-100%: feathered edges cross-fade
                x0, x1 = max(cx - w_s / 2, -W / 2 - 0.5), min(cx + w_s / 2, W / 2 + 0.5)
                if x1 - x0 < 1.5:
                    continue
                col, ph, am = rng.randrange(4), rng.uniform(0, 6.28), rng.uniform(0.15, 0.45) * (1 + variant)
                xs = [x0 + (x1 - x0) * i / 4 for i in range(5)]
                P = lambda x, z: (x + am * math.sin(z * 0.11 + ph) * (1 - z / H) * 1.4,
                                  -(out(z) * (1 + 0.04 * li) + gap + 0.25 * math.sin(x * 0.5 + z * 0.07 + ph)), z)
                cen = [P((x0 + x1) / 2, z) for z in zs]
                arc = [0.0]
                for p, q in zip(cen, cen[1:]):
                    arc.append(arc[-1] + math.dist(p, q))
                vs = [P(x, z) for z in zs for x in xs]
                uv = [((col + i / 4) / 4, arc[j] / arc[-1]) for j in range(len(zs)) for i in range(5)]
                nv, fs, fuv = len(vs), [], []
                for j in range(len(zs) - 1):
                    for i in range(4):
                        q = [j * 5 + i, j * 5 + i + 1, (j + 1) * 5 + i + 1, (j + 1) * 5 + i]  # normal -Y (toward the camera)
                        fs += [tuple(q), tuple(nv + k for k in q[::-1])]  # back face on duplicated verts so smooth normals do not cancel
                        fuv += [[uv[k] for k in q], [uv[k] for k in q[::-1]]]
                wa.add((vs + vs, fs, fuv))
        # foam lip over the edge + foam boils at the base (UVs kept inside column 0's opaque centre)
        lip = [(-W / 2 + W * i / 16, -0.2 - 0.3 * math.sin(i * 1.3), H - 0.4) for i in range(17)]
        fo.add(C.tube(lip, [1.5 + 0.5 * vnoise(i * 0.9, 2.0) for i in range(17)], 10, mult=lambda i, a: 1 + 0.35 * fbm(i * 1.1, a * 1.5, 4.0),
                      uvfn=lambda i, f, d, r: (0.06 + 0.13 * ((d / 30.0) % 1.0), 0.975 + 0.02 * f), cap0=True, cap1=True))
        for i in range(11):
            x = -W / 2 + W * (i + 0.5) / 11 + rng.uniform(-0.8, 0.8)
            rr = rng.uniform(1.6, 3.0)
            vs, fs, fuv = ellipsoid(rr, rr * 0.9, rr * 0.6, 10, 6)
            fuv = [[(0.1 + 0.01 * k, 0.03 + 0.01 * k) for k in range(len(f))] for f in fs]
            fo.add((vs, fs, fuv), Tr(x, -out(0.0) - rng.uniform(0.3, 1.6), rr * 0.25))
    return fn


waterfall_A, waterfall_B = waterfall(0), waterfall(1)

# ============================================================================================ plan / run
ST = dict(frost_uv=("Figure",), frost_area=0.0, frost_nz=0.88, frost_keep=0.4, frost_off=0.02, frost_from=("Stone",))
SF = dict(frost_from=("Stone", "Figure"), frost_area=0.5)
for fn_, c_ in ((hooded_statue(1), ST), (pedestal_statue, ST), (gargoyle_A, ST), (gargoyle_B, ST)):
    fn_.cfg = c_
hs_a, hs_b = hooded_statue(1), hooded_statue(2)
hs_a.cfg = hs_b.cfg = ST
pedestal_statue.cfg = ST
gargoyle_A.cfg = gargoyle_B.cfg = ST
for f_ in (gravestone(0),):
    pass
gs = [gravestone(i) for i in range(4)]
for f_ in gs + [tomb_slab, rubble_pile, masonry_A, masonry_B, ruined_arch, iron_fence, brazier_iron, brazier_post, banner_pole, chain_hang, gibbet_cage]:
    f_.cfg = SF if f_ not in (iron_fence, brazier_iron, brazier_post, banner_pole, chain_hang, gibbet_cage) else dict(frost_from=("Stone",), frost_area=0.5)
for f_ in (candle_A, candle_B, banner_A, banner_B, waterfall_A, waterfall_B):
    f_.cfg = {}
gibbet_cage.cfg = dict(frost_from=("Stone",), frost_area=0.5)
ruined_arch.cfg = dict(SF, weather=0.14)  # mac-53: noise-weathered stone like the kit
SUBST = {"Bone": "Bone"}
K.SUBMAT["Bone"] = "Vesp_Frost"

PLAN = [  # Hooded_Statue_A/B + Pedestal_Statue_Staff: vesperhold_figures.py (mac-51); Gargoyle_A/B: vesperhold_gargoyles.py (mac-52); manifests kept via imports
        ("Candle_Cluster_A", "F", candle_A), ("Candle_Cluster_B", "F", candle_B),
        ("Brazier_Iron", "F", brazier_iron), ("Brazier_Post", "F", brazier_post), ("Banner_Torn_A", "F", banner_A), ("Banner_Torn_B", "F", banner_B),
        ("Banner_Pole", "F", banner_pole), ("Chain_Hang", "F", chain_hang), ("Gibbet_Cage", "F", gibbet_cage), ("Iron_Fence_10", "F", iron_fence),
        ("Gravestone_A", "F", gs[0]), ("Gravestone_B", "F", gs[1]), ("Gravestone_C", "F", gs[2]), ("Gravestone_D", "F", gs[3]),
        ("Tomb_Slab", "F", tomb_slab), ("Rubble_Pile", "F", rubble_pile), ("Masonry_Chunk_A", "F", masonry_A), ("Masonry_Chunk_B", "F", masonry_B),
        ("Ruined_Arch", "F", ruined_arch), ("Waterfall_Sheet_A", "F", waterfall_A), ("Waterfall_Sheet_B", "F", waterfall_B)]

MATS = ["Vesp_Soot", "Vesp_Charcoal", "Vesp_Frost", "Vesp_Iron", "Vesp_Verdigris", "Vesp_Weathered", "Vesp_Wax", "Vesp_Flame", "Vesp_Banner",
        "Vesp_Rope", "Vesp_Water"]
SHEETS = [("F1_statues", [("Hooded_Statue_A", 2), ("Hooded_Statue_B", 2), ("Pedestal_Statue_Staff", 1.6)], dict(az=18.0)),
          ("F2_gargoyles_candles", [("Gargoyle_A", 3), ("Gargoyle_B", 3), ("Candle_Cluster_A", 4), ("Candle_Cluster_B", 4)], dict(az=20.0)),
          ("F3_braziers_chain_cage", [("Brazier_Iron", 3), ("Brazier_Post", 2.2), ("Chain_Hang", 1.0), ("Gibbet_Cage", 1.6)], dict(az=18.0)),
          ("F4_banners_pole", [("Banner_Torn_A", 0.8), ("Banner_Torn_B", 0.8), ("Banner_Pole", 0.7)], dict(az=8.0)),
          ("F5_graves_fence_tomb", [("Gravestone_A", 3), ("Gravestone_B", 3), ("Gravestone_C", 3), ("Gravestone_D", 3), ("Iron_Fence_10", 1.6), ("Tomb_Slab", 1.4)], dict(az=22.0)),
          ("F6_rubble_masonry", [("Rubble_Pile", 1.4), ("Masonry_Chunk_A", 3), ("Masonry_Chunk_B", 3)], dict(az=24.0)),
          ("F7_ruined_arch", [("Ruined_Arch", 1)], dict(az=22.0)),
          ("F8_waterfalls", [("Waterfall_Sheet_A", 1), ("Waterfall_Sheet_B", 0.5)], dict(az=14.0))]

if __name__ == "__main__":
    C.run("Vesperhold props (group F)", PLAN, MATS, SHEETS)
