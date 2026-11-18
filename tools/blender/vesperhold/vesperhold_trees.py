"""Vesperhold kit group G: withered trees from our own procedural generator (no leaves, no third-party code).

  /Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 -P tools/blender/vesperhold/vesperhold_trees.py -- <out_dir>
  default out_dir: assets/source/vesperhold/trees   env: VESP_ONLY=Piece,Piece  VESP_REUSE_MAPS=1  VESP_NORENDER=1

Generator: recursive branching. Every branch is a skinned, tapered tube (rotation-minimising frames, 5-18 sides by radius) whose
centreline is a smooth-noise random walk with tropism (upward pull, droop) and curl; children leave at 25-65 degrees at random
points along the parent with radius/length ratios per depth. Gnarl = value-noise radial bulges + furrow ridges; broken stubs end in
splintered caps with spike splinters; roots flare from the base. Bark UV runs along the branch (u around, v along, 16 studs per tile).
Meshes are split by height band (Z) under 15.5k tris per sub-mesh, never decimated; Frost = patchy up-facing faces copied to a Frost sub.
Pieces: Dead_Oak_Gnarled_A/B, Dead_Pine_Snapped_A/B, Thorn_Twisted_A/B, Dead_Stump_A/B, Dead_Log_A/B. Pivot: trunk base centre, roots
buried up to ~2.5 studs below z = 0.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
if "--" not in sys.argv or not sys.argv[sys.argv.index("--") + 1:]:
    sys.argv += ["--", str(Path(__file__).resolve().parents[3] / "assets/source/vesperhold/trees")]
import vesp_common as C  # noqa: E402
from vesp_common import K, fbm, vnoise  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

PI = math.pi


def lerp(a, b, t):
    return a + (b - a) * t


def seg_for(r):
    return 18 if r > 3.0 else 14 if r > 1.5 else 10 if r > 0.7 else 7 if r > 0.3 else 5


def bark_mult(seed, amp, ridge):
    return lambda i, a: 1.0 + amp * fbm(a * 1.1 + seed, i * 0.42, seed * 0.7) + ridge * math.cos(5 * a + i * 0.25 + seed)


def splinters(bark, rng, tip, d, r, n=5, ln=(1.6, 5.5)):
    """Sharp splinter spikes standing out of a broken end."""
    tip, d = Vector(tip), Vector(d).normalized()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    a, b = d.cross(ref).normalized(), d.cross(d.cross(ref)).normalized()
    for k in range(n):
        ang = 2 * PI * (k + rng.random() * 0.6) / n
        off = (a * math.cos(ang) + b * math.sin(ang)) * r * rng.uniform(0.35, 0.8)
        L = rng.uniform(*ln)
        lean = (a * math.cos(ang) + b * math.sin(ang)) * rng.uniform(-0.25, 0.5) * L
        pts = [tip + off, tip + off + d * L * 0.5 + lean * 0.4, tip + off + d * L + lean]
        bark.add(C.tube(pts, [r * 0.32, r * 0.2, 0.03], 5, tile=16.0, min_circ=2.0))


class Gen:
    def __init__(self, U, seed, cfg):
        self.bark, self.rng, self.cfg = U["Bark"], random.Random(seed), cfg
        self.seed = seed
        self.thorns = cfg.get("thorns", 0.0)

    def grow(self, p0, d0, length, r0, depth, up=0.0, trunk=False, droop_scale=1.0, rend=None, no_break=False):
        cfg, rng = self.cfg, self.rng
        ds = max(0.42, min(1.5, r0 * 0.55))
        n = max(4, int(length / ds))
        sd = rng.random() * 100
        w = cfg["wobble"][min(depth, len(cfg["wobble"]) - 1)]
        fq = cfg["freq"]
        pts, dirs = [Vector(p0)], []
        d = Vector(d0).normalized()
        curl = cfg.get("curl", 0.0)
        for i in range(n):
            t = i / n
            nv = Vector((vnoise(sd + t * fq, 1.7, 0.3), vnoise(sd + 11 + t * fq, 5.1, 1.1), vnoise(sd + 23 + t * fq, 3.3, 2.2)))
            d = d + nv * w * ds * 0.55 + Vector((0, 0, up * ds * 0.1 * (1 - t) - cfg["droop"][min(depth, len(cfg["droop"]) - 1)] * droop_scale * t * ds * 0.1))
            if curl:
                d = Matrix.Rotation(curl * ds * 0.12 * (1 if (sd % 2 < 1) else -1), 3, "Z") @ d
            d.normalize()
            dirs.append(d.copy())
            pts.append(pts[-1] + d * ds)
        dirs.append(dirs[-1])
        brk = (not no_break) and depth >= 1 and rng.random() < cfg["pbreak"][min(depth, len(cfg["pbreak"]) - 1)]
        rf = rend if rend is not None else (0.5 if brk else cfg["rend"])
        radii = []
        for i in range(n + 1):
            t = i / n
            rr = r0 * (1 - (1 - rf) * t ** cfg["taper_pow"])
            if trunk:
                rr *= 1.0 + cfg.get("flare", 0.55) * math.exp(-i * ds / cfg.get("flare_len", 3.5))
            radii.append(max(rr, 0.04))
        if depth > 0:
            radii[0] *= 1.22
        seg = seg_for(r0)
        mult = bark_mult(sd, cfg["gnarl"] * (1.0 if r0 > 1.0 else 0.5), cfg["ridge"] if r0 > 1.2 else 0.0)
        jag = r0 * 1.3 if brk else 0.0
        self.bark.add(C.tube(pts, radii, seg, mult=mult, tile=16.0, cap1=True, jag=jag, rng=rng))
        if brk and radii[-1] > 0.35:
            splinters(self.bark, rng, pts[-1], dirs[-1], radii[-1], n=rng.randint(3, 6))
        if self.thorns and r0 < 1.6:
            for i in range(2, n, 2):
                if rng.random() < self.thorns:
                    side = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).cross(dirs[i]).normalized()
                    L = rng.uniform(0.9, 2.2) * (0.5 + radii[i])
                    b = pts[i] + side * radii[i] * 0.7
                    self.bark.add(C.tube([b, b + side * L * 0.55 + dirs[i] * L * 0.2, b + side * L + dirs[i] * L * 0.55], [radii[i] * 0.45, radii[i] * 0.28, 0.03], 4,
                                         tile=16.0, min_circ=1.5))
        if depth < cfg["maxdepth"] and not trunk:
            k = rng.randint(*cfg["nchild"][depth])
            for t in sorted(rng.uniform(cfg["t0"][depth], 0.97) for _ in range(k)):
                idx = min(int(t * n), n - 1)
                base, pd = pts[idx], dirs[idx]
                axis = pd.cross(Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))))
                if axis.length < 1e-6:
                    continue
                axis.normalize()
                cd = Matrix.Rotation(math.radians(rng.uniform(*cfg["ang"][depth])), 3, axis) @ pd
                cd.z += cfg["child_up"][depth]
                cd.normalize()
                cl = length * cfg["lfac"][depth] * (1 - t * 0.55) * rng.uniform(0.7, 1.15)
                cr = radii[idx] * cfg["rr"][depth] * rng.uniform(0.8, 1.0)
                if cr < cfg["rmin"] or cl < 1.2:
                    continue
                self.grow(base - cd * cr * 0.35, cd, cl, cr, depth + 1, up=cfg["child_up"][depth] * 2)
        return pts, dirs, radii

    def roots(self, n, r, spread, depth_z=-2.3):
        rng = self.rng
        for k in range(n):
            a = 2 * PI * (k + rng.uniform(-0.3, 0.3)) / n
            L = rng.uniform(0.7, 1.15) * spread
            c, s = math.cos(a), math.sin(a)
            pts = C_bez([(c * r * 0.5, s * r * 0.5, 2.2), (c * (r + L * 0.4), s * (r + L * 0.4), 1.0), (c * (r + L * 0.8), s * (r + L * 0.8), depth_z * 0.5), (c * (r + L), s * (r + L), depth_z)], 12)
            rad = [lerp(r * 0.55, 0.15, (i / 11) ** 0.8) for i in range(12)]
            self.bark.add(C.tube(pts, rad, 10, mult=bark_mult(k * 3.1, 0.14, 0.05), tile=16.0, cap1=True))


def C_bez(ctrl, n):
    ctrl = [Vector(c) for c in ctrl]
    out = []
    for i in range(n):
        t = i / (n - 1)
        p = list(ctrl)
        while len(p) > 1:
            p = [p[j] * (1 - t) + p[j + 1] * t for j in range(len(p) - 1)]
        out.append(p[0])
    return out


# ============================================================================================ species
OAK = dict(maxdepth=5, nchild=[(0, 0), (4, 6), (3, 5), (3, 4), (2, 4), (0, 0)], t0=[0.2, 0.18, 0.25, 0.3, 0.3, 0.3], ang=[(25, 60)] * 6, child_up=[0.0, 0.14, 0.08, 0.04, 0.0, 0.0],
           lfac=[0.6, 0.55, 0.62, 0.62, 0.6, 0.6], rr=[0.5, 0.52, 0.6, 0.64, 0.66, 0.66], rmin=0.11, wobble=[0.2, 0.55, 0.8, 1.0, 1.1, 1.1], freq=1.5,
           droop=[0.0, 0.1, 0.25, 0.4, 0.5, 0.6], taper_pow=0.8, rend=0.30, pbreak=[0, 0.10, 0.2, 0.28, 0.3, 0.3], gnarl=0.16, ridge=0.07)


def dead_oak(S, U, seed, H):
    g = Gen(U, seed, OAK)
    rng = g.rng
    th = H * 0.31
    pts, dirs, radii = g.grow((0, 0, -1.8), Vector((0.06, 0.04, 1.0)), th, 5.6, 0, up=1.2, trunk=True, rend=0.62)
    top, dtop, rtop = pts[-1], dirs[-1], radii[-1]
    g.roots(8, 4.6, 12.0)
    nl = 5
    for k in range(nl):  # main limbs: twisted, broad, some reaching up
        a = 2 * PI * (k + rng.uniform(-0.2, 0.2)) / nl
        z = rng.uniform(0.7, 1.7) if k else 1.8
        d = Vector((math.cos(a), math.sin(a), z))
        r0 = rtop * rng.uniform(0.62, 0.78)
        g.grow(top - Vector((0, 0, 0.5)) + Vector((math.cos(a), math.sin(a), 0)) * rtop * 0.35, d, H * rng.uniform(0.5, 0.64), r0, 1, up=0.8)
    for k in range(3):  # broken side limbs low on the trunk
        i = rng.randint(len(pts) // 4, len(pts) * 3 // 4)
        a = rng.uniform(0, 2 * PI)
        g.grow(pts[i] + Vector((math.cos(a), math.sin(a), 0)) * radii[i] * 0.3, Vector((math.cos(a), math.sin(a), rng.uniform(0.1, 0.5))), H * 0.22, radii[i] * 0.34, 1, no_break=False,
               rend=0.55)


PINE = dict(maxdepth=2, nchild=[(0, 0), (2, 4), (1, 3)], t0=[0.2, 0.25, 0.3], ang=[(30, 70)] * 3, child_up=[0.0, -0.05, -0.1], lfac=[0.5, 0.5, 0.5], rr=[0.5, 0.55, 0.6],
            rmin=0.1, wobble=[0.1, 0.5, 0.8], freq=1.4, droop=[0.0, 0.5, 0.8], taper_pow=0.9, rend=0.1, pbreak=[0, 0.35, 0.4], gnarl=0.10, ridge=0.05)


def dead_pine(S, U, seed, H):
    rng = random.Random(seed)
    g = Gen(U, seed, PINE)
    brk = 0.82 * H
    n = int(brk / 1.4)
    pts, rad = [], []
    for i in range(n + 1):
        z = -1.5 + (brk + 1.5) * i / n
        zt = max(z, 0) / brk
        pts.append(Vector((1.1 * fbm(z * 0.045 + seed, 1.0) * (0.3 + zt), 1.1 * fbm(z * 0.045, seed + 5.0) * (0.3 + zt), z)))
        rad.append(3.4 * (1 - 0.6 * zt ** 0.9) * (1 + 0.5 * math.exp(-(z + 1.5) / 3.2)))
    g.bark.add(C.tube(pts, rad, 16, mult=bark_mult(seed, 0.09, 0.10), tile=16.0, cap1=True, jag=3.4, rng=rng))
    top = pts[-1]
    splinters(g.bark, rng, top, Vector((0.1, 0, 1)), rad[-1], 7, (3.0, 9.0))
    hang = C_bez([top, top + Vector((2.2, 0.6, -1.4)), top + Vector((4.8, 1.2, -6.0)), top + Vector((5.6, 1.4, -13.0))], 14)
    g.bark.add(C.tube(hang, [lerp(rad[-1] * 0.95, rad[-1] * 0.55, i / 13) for i in range(14)], 12, mult=bark_mult(seed + 3, 0.12, 0.08), tile=16.0, cap1=True, jag=2.2, rng=rng))
    g.roots(7, 3.2, 9.0)
    for i in range(48):  # dead branches, long and drooping low, stubs higher
        z = rng.uniform(0.10, 0.80) * H
        zi = min(max(int((z + 1.5) / (brk + 1.5) * n), 0), n)
        a = i * 2.39996 + rng.uniform(-0.3, 0.3)
        c, s = math.cos(a), math.sin(a)
        low = max(0.2, 1.2 - z / H)
        base = pts[zi] + Vector((c, s, 0)) * rad[zi] * 0.5
        if rng.random() < 0.35:
            g.grow(base, Vector((c, s, rng.uniform(0.0, 0.3))), rng.uniform(1.2, 3.2), rng.uniform(0.45, 0.8), 1, no_break=False, rend=0.7)
        else:
            g.grow(base, Vector((c, s, rng.uniform(-0.1, 0.35))), rng.uniform(6, 15) * low, rng.uniform(0.55, 1.1), 1, droop_scale=1.3)


THORN = dict(maxdepth=4, nchild=[(0, 0), (4, 6), (3, 5), (2, 4), (1, 3)], t0=[0.2, 0.15, 0.2, 0.2, 0.3], ang=[(30, 75)] * 5, child_up=[0.0, 0.28, 0.16, 0.08, 0.04],
             lfac=[0.6, 0.55, 0.6, 0.6, 0.6], rr=[0.5, 0.6, 0.66, 0.7, 0.7], rmin=0.08, wobble=[0.5, 0.6, 1.0, 1.3, 1.5], freq=2.2, droop=[0.0, 0.3, 0.5, 0.7, 0.8],
             taper_pow=0.85, rend=0.18, pbreak=[0, 0.1, 0.2, 0.25, 0.25], gnarl=0.2, ridge=0.1, curl=0.5, thorns=0.5)


def thorn(S, U, seed, H):
    g = Gen(U, seed, THORN)
    rng = g.rng
    ns = 4
    for k in range(ns):
        a = 2 * PI * k / ns + rng.uniform(-0.4, 0.4)
        g.grow((math.cos(a) * 1.3, math.sin(a) * 1.3, -1.2), Vector((math.cos(a) * 0.45, math.sin(a) * 0.45, 1.0)), H * rng.uniform(0.8, 1.05), rng.uniform(1.5, 2.1), 1,
               up=1.8, trunk=False, no_break=True)
    g.roots(6, 1.8, 6.0)


def stump(S, U, seed, Hh):
    g = Gen(U, seed, OAK)
    rng = g.rng
    n = 9
    pts = [Vector((0.2 * fbm(i * 0.5 + seed, 1.0), 0.2 * fbm(i * 0.5, seed + 3), -1.5 + (Hh + 1.5) * i / n)) for i in range(n + 1)]
    rad = [5.4 * (1 + 0.6 * math.exp(-(p.z + 1.5) / 2.5)) * (1 - 0.08 * (p.z / Hh)) for p in pts]
    g.bark.add(C.tube(pts, rad, 22, mult=lambda i, a: 1 + 0.2 * fbm(a * 1.3 + seed, i * 0.5, 2.0) + 0.1 * math.cos(6 * a + seed) + (-0.30 * math.exp(-((a - 1.2 - seed) % (2 * PI) - PI) ** 2 * 3) if i > n // 2 else 0),
                    tile=16.0, cap1=True, jag=2.0, rng=rng, min_circ=8.0))
    splinters(g.bark, rng, pts[-1] + Vector((0, 0, 0)), Vector((0, 0, 1)), 4.6, 5, (1.2, 4.0))
    g.roots(8, 4.8, 11.0)
    g.grow(Vector((4.6, 0.8, 3.5)), Vector((1.0, 0.1, 0.35)), 4.2, 1.1, 1, rend=0.7)
    g.grow(Vector((-1.2, 4.7, 4.9)), Vector((-0.2, 1.0, 0.4)), 3.0, 0.8, 1, rend=0.7)


def log(S, U, seed, Ln):
    g = Gen(U, seed, OAK)
    rng = g.rng
    n = int(Ln / 1.8)
    pts = [Vector((-Ln / 2 + Ln * i / n, 0.5 * fbm(i * 0.18 + seed, 1.0), 3.0 + 0.35 * fbm(i * 0.2, seed + 3))) for i in range(n + 1)]
    rad = [lerp(3.4, 2.5, i / n) * (1 + 0.4 * math.exp(-i * 1.8 / 3.0)) for i in range(n + 1)]
    g.bark.add(C.tube(pts, rad, 18, mult=bark_mult(seed, 0.14, 0.09), tile=16.0, cap1=True, cap0=True, jag=2.2, rng=rng))
    splinters(g.bark, rng, pts[-1], Vector((1, 0, 0.1)), rad[-1], 5, (1.2, 4.0))
    for k in range(9):  # root ball splays out of the first end
        a = 2 * PI * k / 9
        c, s = math.cos(a), math.sin(a)
        p0 = pts[0] + Vector((0.5, c * 1.0, s * 1.0))
        rp = C_bez([p0, p0 + Vector((-3.0, c * 3.2, s * 3.2 + 0.6)), p0 + Vector((-6.0, c * 6.0, max(s * 5.0, -0.5) + 1.0)), p0 + Vector((-9.0 - rng.uniform(0, 3), c * 7.5, max(s * 5.0 + 0.3, -1.2)))], 11)
        g.bark.add(C.tube(rp, [lerp(1.1, 0.12, (i / 10) ** 0.8) for i in range(11)], 8, mult=bark_mult(k, 0.15, 0.0), tile=16.0, cap1=True))
    for i in (7, 12, 16):  # snapped branch stubs on top
        base = pts[min(i, n)] + Vector((0, 0, rad[min(i, n)] * 0.6))
        g.grow(base, Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.8, 0.8), 1.0)), rng.uniform(3, 7), rng.uniform(0.6, 1.0), 1, rend=0.5)


# ============================================================================================ plan
FR = dict(frost_uv=("Bark",), frost_area=0.0, frost_nz=0.8, frost_keep=0.55, frost_off=0.03, axis=2, frost_amax=1.3)


def fit_height(U, target):
    """Uniformly scale the generated tree so its crown top sits at `target` studs (random growth gives +-30% height)."""
    top = max(z for sub in U.values() for vs, fs, fuv in sub.prims for x, y, z in vs)
    k = target / top
    for sub in U.values():
        sub.prims = [([(x * k, y * k, z * k) for x, y, z in vs], fs, fuv) for vs, fs, fuv in sub.prims]


def clamp_floor(U, zmin=-2.8):
    """Roots/stems that wander under the ground are flattened at -2.8 studs (pack rule: buried up to 3)."""
    for sub in U.values():
        sub.prims = [([(x, y, max(z, zmin)) for x, y, z in vs], fs, fuv) for vs, fs, fuv in sub.prims]


def piece(fn, *args, fit=None):
    def f(S, U):
        fn(S, U, *args)
        if fit:
            fit_height(U, fit)
        clamp_floor(U)
    f.cfg = FR
    return f


PLAN = [("Dead_Oak_Gnarled_A", "G", piece(dead_oak, 11, 70.0, fit=72.0)), ("Dead_Oak_Gnarled_B", "G", piece(dead_oak, 23, 84.0, fit=86.0)),
        ("Dead_Pine_Snapped_A", "G", piece(dead_pine, 5, 66.0)), ("Dead_Pine_Snapped_B", "G", piece(dead_pine, 9, 78.0)),
        ("Thorn_Twisted_A", "G", piece(thorn, 3, 28.0, fit=30.0)), ("Thorn_Twisted_B", "G", piece(thorn, 8, 38.0, fit=38.0)),
        ("Dead_Stump_A", "G", piece(stump, 4, 7.0)), ("Dead_Stump_B", "G", piece(stump, 6, 9.0)),
        ("Dead_Log_A", "G", piece(log, 2, 34.0)), ("Dead_Log_B", "G", piece(log, 7, 26.0))]
MATS = ["Vesp_DeadBark", "Vesp_Frost"]
SHEETS = [("G1_oaks", [("Dead_Oak_Gnarled_A", 1), ("Dead_Oak_Gnarled_B", 1)], dict(az=14.0)),
          ("G2_pines", [("Dead_Pine_Snapped_A", 1), ("Dead_Pine_Snapped_B", 1)], dict(az=14.0)),
          ("G3_thorns_stumps_logs", [("Thorn_Twisted_A", 2), ("Thorn_Twisted_B", 2), ("Dead_Stump_A", 3), ("Dead_Stump_B", 3), ("Dead_Log_A", 1.6), ("Dead_Log_B", 1.6)], dict(az=16.0))]

if __name__ == "__main__":
    C.run("Vesperhold withered trees (group G)", PLAN, MATS, SHEETS)
