"""Vesperhold kit group G v2 (mac-52): hero withered trees, baked; stumps and logs from CC0 Poly Haven scans.

  /Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 -P tools/blender/vesperhold/vesperhold_trees.py -- [out_dir]
  default out_dir: assets/source/vesperhold/trees   env: VESP_ONLY=Piece,Piece  VESP_TREE_MODE=bake|clay  VESP_BAKE_SIZE=1024

Hero trees (Dead_Oak_Gnarled_A/B, Dead_Pine_Snapped_A/B, Thorn_Twisted_A/B): our own skeleton generator (noise random walk with
tropism/droop/curl, children at 25-70 deg, broken limbs with splinters, root spread) -> numpy tube mesher evaluated twice:
  LOW (shipped): gnarled tube rings, buttress root flare lobes on the trunk, twig ends closed in a single apex (pointed).
  HIGH (bake source): same centrelines/radii at ~0.1-stud rings plus deep vertical bark furrows (periodic ridged noise),
  bark_willow_02 Displacement plates (CC0) on the same UVs as its albedo, and knots.
vesp_bake bakes HIGH -> LOW per role (Trunk, Limbs, Branches, Twigs, Chain): Color/Normal/Roughness/Metal 2048 on the CC0
bark_willow_02 base (UV-mapped along the branch), bleached grey dead wood, frost on up-facing limbs, black Metal. Dead_Oak_Gnarled_A
carries a hanging iron gibbet chain (role Chain, metal). Never decimated: roles over the cap are split into <18k-tri subs.
Stumps/logs (Dead_Stump_A/B, Dead_Log_A/B): Poly Haven CC0 scans tree_stump_01 / dead_tree_trunk_02 / dead_tree_trunk (GLB 2k),
scaled to studs (1 m = 3.57 studs; logs 15-18 studs long), their own 2k maps retoned to the dead-bark palette with baked frost,
black Metal map, split (never decimated) into <18k-tri subs.
Units studs, pivot trunk base centre (roots buried <= 2.8 studs). Writes <Piece>.glb + manifest.json entries + renders.
"""
import json
import math
import os
import random
import shutil
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bpy  # noqa: E402
import numpy as np  # noqa: E402
import vesperhold_figures as FG  # noqa: E402
import vesperhold_gargoyles as GG  # noqa: E402
from vesperhold_figures import MB, circ_noise, log, nrm, sst, vnoise  # noqa: E402

ROOT = HERE.parents[2]
PI = math.pi
BUILDER = "tools/blender/vesperhold/vesperhold_trees.py (mac-52, generated skeleton, high-poly bark, Cycles-baked)"
PH = ROOT / "assets/source/vesperhold/polyhaven"
ZMIN = -2.8


# ============================================================================================ skeleton generator
class Tree:
    def __init__(self, seed, cfg):
        self.rng, self.cfg, self.br, self.root_ang, self.flare = random.Random(seed), cfg, [], [], 0.55

    def add(self, P, R, kind, tip, depth):
        self.br.append(dict(P=np.asarray(P, float), R=np.asarray(R, float), kind=kind, tip=tip, depth=depth, seed=self.rng.random() * 500))

    def walk(self, p0, d0, length, ds, w, up, droop, curl=0.0):
        rng = self.rng
        n = max(3, int(length / ds))
        sd = rng.random() * 100
        t = np.arange(n) / n
        fq = self.cfg["freq"] * max(1.0, length / 12.0)  # long limbs kink back and forth instead of drifting into tusk crescents
        nv = np.stack([vnoise(np.stack([sd + t * fq + 31 * k, np.full(n, 1.7 + k), np.full(n, 0.3)], -1), k) for k in range(3)], 1)
        d = nrm(np.asarray(d0, float))
        pts, dirs = [np.asarray(p0, float)], []
        cs = 1 if rng.random() < 0.5 else -1
        h0 = np.array([d[0], d[1], 0.0])
        hn = float(np.linalg.norm(h0))
        h0 = h0 / max(hn, 1e-9)
        for i in range(n):
            d = d + nv[i] * w * ds * 0.55 + np.array([0, 0, (up * (1 - t[i]) - droop * t[i]) * ds * 0.1])
            if hn > 0.3 and d @ h0 < 0.25:  # never double back toward the parent: loops wrapped limbs round the trunk
                d = d + (0.25 - d @ h0) * h0
            if curl:
                a = curl * ds * 0.12 * cs
                d = np.array([d[0] * math.cos(a) - d[1] * math.sin(a), d[0] * math.sin(a) + d[1] * math.cos(a), d[2]])
            if pts[-1][2] < 7.0:  # keep limbs off the ground (no branch sliding along the floor): lift harder the lower it gets
                d[2] = max(d[2], 0.25 + 0.1 * (7.0 - pts[-1][2]))
            d = nrm(d)
            dirs.append(d)
            pts.append(pts[-1] + d * ds)
        dirs.append(dirs[-1])
        return np.array(pts), np.array(dirs)

    def grow(self, p0, d0, length, r0, depth, up=0.0, rend=None, no_break=False, droop_scale=1.0, kind="branch", kids=True, w=None):
        cfg, rng = self.cfg, self.rng
        dl = min(depth, len(cfg["wobble"]) - 1)
        ds = float(np.clip(r0 * 0.55, 0.3, 1.5))
        pts, dirs = self.walk(p0, d0, length, ds, cfg["wobble"][dl] if w is None else w, up, cfg["droop"][dl] * droop_scale, cfg.get("curl", 0.0))
        n = len(pts) - 1
        t = np.linspace(0, 1, n + 1)
        brk = rend is not None or ((not no_break) and depth >= 1 and rng.random() < cfg["pbreak"][dl])
        if brk:
            rf = rend if rend is not None else rng.uniform(0.45, 0.7)
            R = r0 * (1 - (1 - rf) * t ** cfg["taper_pow"])
        else:
            R = r0 * np.maximum(1 - t ** cfg["taper_pow"], 0) ** 0.6
        if depth > 0:
            R[0] *= 1.2
        self.add(pts, R, kind, "broken" if brk else "point", depth)
        if brk and R[-1] > 0.25:
            self.splinters(pts[-1], dirs[-1], R[-1], depth, rng.randint(2, 3) if R[-1] < 0.8 else rng.randint(3, 6),
                           (min(1.2, 2.5 * R[-1]), min(4.5, 6.0 * R[-1])))  # small stubs: short splinters (else a hedgehog)
        if cfg.get("thorns") and r0 < 1.2:
            for i in range(1, n, 1):
                if rng.random() < cfg["thorns"]:
                    side = nrm(np.cross(np.array([rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)]), dirs[i]))
                    L = rng.uniform(0.35, 0.9) * (0.6 + R[i])
                    b = pts[i] + side * R[i] * 0.6
                    self.add([b, b + side * L * 0.6 + dirs[i] * L * 0.15, b + side * L + dirs[i] * L * 0.4], [R[i] * 0.42 + 0.03, R[i] * 0.2 + 0.015, 0.0],
                             "thorn", "point", depth + 1)
        if kids and depth < cfg["maxdepth"]:
            k = rng.randint(*cfg["nchild"][dl])
            for tt in sorted(rng.uniform(cfg["t0"][dl], 0.95) for _ in range(k)):
                idx = min(int(tt * n), n - 1)
                axis = np.cross(dirs[idx], [rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)])
                if np.linalg.norm(axis) < 1e-6:
                    continue
                cd = _rot(dirs[idx], nrm(axis), math.radians(rng.uniform(*cfg["ang"][dl])))
                cd = nrm(cd + [0, 0, cfg["child_up"][dl]])
                cl = length * cfg["lfac"][dl] * (1 - tt * 0.5) * rng.uniform(0.7, 1.15)
                cr = R[idx] * cfg["rr"][dl] * rng.uniform(0.8, 1.0)
                if cr < cfg["rmin"] or cl < 1.0:
                    continue
                self.grow(pts[idx] - cd * cr * 0.35, cd, cl, cr, depth + 1, up=cfg["child_up"][dl] * 2)
        return pts, dirs, R

    def splinters(self, tip, d, r, depth, n, ln=(1.2, 4.5), up=None):
        rng = self.rng
        d = nrm(np.asarray(d, float))
        ref = np.array([0, 0, 1.0]) if abs(d[2]) < 0.9 else np.array([1.0, 0, 0])
        a = nrm(np.cross(d, ref))
        b = np.cross(d, a)
        for k in range(n):
            ang = 2 * PI * (k + rng.random() * 0.6) / n
            rad = a * math.cos(ang) + b * math.sin(ang)
            off = rad * r * rng.uniform(0.45, 0.85)
            L = rng.uniform(*ln)
            lean = rad * rng.uniform(-0.15, 0.35) * L
            w = r * rng.uniform(0.18, 0.34)
            self.add([tip - d * r * 0.3 + off, tip + off + d * L * 0.5 + lean * 0.4, tip + off + d * L + lean], [w, w * 0.6, 0.0], "splinter", "point", depth + 1)

    def roots(self, n, r, spread, depth_z=-2.5, rr=0.55):
        rng = self.rng
        for k in range(n):
            a = 2 * PI * (k + rng.uniform(-0.3, 0.3)) / n
            self.root_ang.append(a)
            L = rng.uniform(0.7, 1.15) * spread
            c, s = math.cos(a), math.sin(a)
            ctrl = [(c * r * 0.45, s * r * 0.45, 2.6), (c * (r + L * 0.25), s * (r + L * 0.25), 1.0), (c * (r + L * 0.6), s * (r + L * 0.6), 0.05),
                    (c * (r + L), s * (r + L), depth_z)]
            P = FG.spline(np.array(ctrl), 16)[0]
            P[:, :2] += np.stack([np.sin(np.linspace(0, 3, 16) + k) * 0.35, np.cos(np.linspace(0, 2.6, 16) + k) * 0.35], 1) * (L / 10)
            R = r * rr * np.maximum(1 - np.linspace(0, 1, 16) ** 0.9, 0) ** 0.7
            self.add(P, R, "root", "point", 1)

    def scale(self, k):
        for b in self.br:
            b["P"] = b["P"] * k
            b["R"] = b["R"] * k

    def top(self):
        return max(float((b["P"][:, 2] + b["R"]).max()) for b in self.br)


def _rot(v, axis, ang):
    v = np.asarray(v, float)
    return v * math.cos(ang) + np.cross(axis, v) * math.sin(ang) + axis * (axis @ v) * (1 - math.cos(ang))


# ============================================================================================ species
OAK = dict(maxdepth=5, nchild=[(0, 0), (4, 6), (3, 5), (3, 4), (2, 4), (0, 0)], t0=[0.2, 0.18, 0.25, 0.3, 0.3, 0.3], ang=[(25, 60)] * 6,
           child_up=[0.0, 0.14, 0.08, 0.04, 0.0, 0.0], lfac=[0.6, 0.55, 0.6, 0.6, 0.62, 0.6], rr=[0.5, 0.5, 0.58, 0.62, 0.64, 0.66], rmin=0.09,
           wobble=[0.2, 0.55, 0.75, 0.85, 0.9, 0.9], freq=1.5, droop=[0.0, 0.1, 0.25, 0.35, 0.4, 0.45], taper_pow=0.8,
           pbreak=[0, 0.12, 0.18, 0.2, 0.12, 0.05])


def dead_oak(seed, H, reach, arm_droop=0.4, arm_up=0.5):
    g = Tree(seed, OAK)
    rng = g.rng
    th = H * 0.3
    pts, dirs, R = g.grow((0, 0, -2.0), (0.06, 0.04, 1.0), th, 5.6, 0, up=1.2, rend=0.66, kind="trunk", kids=False)
    g.roots(9, 5.0, 13.0)
    top, rtop = pts[-1], R[-1]
    nl = 5
    for k in range(nl):  # main limbs: broad, twisting, some reaching high
        a = 2 * PI * (k + rng.uniform(-0.2, 0.2)) / nl
        z = rng.uniform(0.7, 1.6) if k else 1.8
        d = np.array([math.cos(a), math.sin(a), z])
        g.grow(top - [0, 0, 0.6] + np.array([math.cos(a), math.sin(a), 0]) * rtop * 0.35, d, H * rng.uniform(0.5, 0.62), rtop * rng.uniform(0.6, 0.74), 1, up=0.8)
    for a in reach:  # long sinuous reaching arms (ref_04 left): low elevation, thin, wandering
        i = rng.randint(len(pts) * 5 // 10, len(pts) * 8 // 10)
        g.grow(pts[i] + np.array([math.cos(a), math.sin(a), 0]) * R[i] * 0.4, (math.cos(a), math.sin(a), 0.32), H * rng.uniform(0.7, 0.85),
               R[i] * 0.36, 1, up=arm_up, no_break=True, droop_scale=arm_droop, w=0.85)
    for _ in range(3):  # broken side limbs low on the trunk
        i = rng.randint(len(pts) // 4, len(pts) * 3 // 4)
        a = rng.uniform(0, 2 * PI)
        g.grow(pts[i] + np.array([math.cos(a), math.sin(a), 0]) * R[i] * 0.3, (math.cos(a), math.sin(a), rng.uniform(0.1, 0.5)), H * 0.12, R[i] * 0.32, 1,
               rend=0.6, kids=False)
    return g


PINE = dict(maxdepth=2, nchild=[(0, 0), (3, 6), (2, 4)], t0=[0.2, 0.2, 0.3], ang=[(35, 70)] * 3, child_up=[0.0, -0.05, -0.1], lfac=[0.5, 0.45, 0.5],
            rr=[0.5, 0.55, 0.6], rmin=0.07, wobble=[0.1, 0.45, 0.8], freq=1.4, droop=[0.0, 0.5, 0.8], taper_pow=0.9, pbreak=[0, 0.25, 0.3])


def dead_pine(seed, H):
    g = Tree(seed, PINE)
    rng = g.rng
    brk = 0.82 * H
    n = int(brk / 1.2)
    z = np.linspace(-2.0, brk, n + 1)
    zt = np.maximum(z, 0) / brk
    lean = np.array([rng.uniform(-1, 1), rng.uniform(-1, 1)]) * 0.04
    P = np.stack([lean[0] * z + 0.9 * vnoise(np.stack([z * 0.04 + seed, np.ones_like(z), z * 0], -1), 1) * zt,
                  lean[1] * z + 0.9 * vnoise(np.stack([z * 0.04, np.ones_like(z) * 5, z * 0 + seed], -1), 2) * zt, z], 1)
    R = 3.3 * (1 - 0.58 * zt ** 0.85)
    g.add(P, R, "trunk", "broken", 0)
    top, d = P[-1], nrm(P[-1] - P[-3])
    g.splinters(top, d, R[-1], 1, 8, (2.5, 8.5))  # snapped crown: tall shards round the break
    g.add([top + [R[-1] * 0.3, 0, -0.5], top + [R[-1] * 0.5, 0.3, 4.0], top + [R[-1] * 0.2, 0.6, 9.5]], [R[-1] * 0.45, R[-1] * 0.28, 0.0], "splinter", "point", 1)
    g.roots(7, 3.3, 9.0, rr=0.6)
    zw = 0.1 * H
    wi = 0
    while zw < brk - 2.0:  # whorls of dead branches: stubs higher up, a few long drooping limbs low down
        zi = int(np.searchsorted(z, zw))
        low = 1 - zw / brk
        for k in range(rng.randint(3, 5)):
            a = 2 * PI * k / 4 + wi * 0.9 + rng.uniform(-0.4, 0.4)
            c, s = math.cos(a), math.sin(a)
            base = P[zi] + np.array([c, s, 0]) * R[zi] * 0.5
            if low > 0.35 and rng.random() < 0.5:
                g.grow(base, (c, s, rng.uniform(-0.15, 0.15)), rng.uniform(8, 16) * low, rng.uniform(0.45, 0.75), 1, droop_scale=1.3, no_break=rng.random() < 0.5)
            else:
                g.grow(base, (c, s, rng.uniform(-0.35, 0.05)), rng.uniform(0.8, 3.0), rng.uniform(0.28, 0.6), 1, rend=rng.uniform(0.5, 0.8), kids=False)
        zw += rng.uniform(2.4, 3.6)
        wi += 1
    return g


THORN = dict(maxdepth=4, nchild=[(0, 0), (4, 6), (3, 5), (2, 4), (1, 3)], t0=[0.2, 0.35, 0.2, 0.2, 0.3], ang=[(30, 75)] * 5, child_up=[0.0, 0.25, 0.14, 0.06, 0.03],
             lfac=[0.6, 0.5, 0.6, 0.6, 0.6], rr=[0.5, 0.6, 0.66, 0.7, 0.7], rmin=0.06, wobble=[0.5, 0.6, 0.9, 1.05, 1.1], freq=2.2,
             droop=[0.0, 0.3, 0.5, 0.7, 0.8], taper_pow=0.85, pbreak=[0, 0.05, 0.12, 0.15, 0.15], curl=0.6, thorns=0.45)


def thorn(seed, H):
    g = Tree(seed, THORN)
    rng = g.rng
    ns = 3 + seed % 2
    hs = 0.62 * H
    for k in range(ns):  # stems wound round each other in a tightening spiral
        z = np.linspace(-1.8, hs, 60)
        u = np.clip(z / hs, 0, 1)
        th = 2 * PI * k / ns + 2 * PI * 1.35 * u
        rh = 1.1 * (1 - 0.55 * u) + 0.6 * u ** 3
        P = np.stack([rh * np.cos(th), rh * np.sin(th), z], 1)
        R = (1.25 - 0.75 * u) * rng.uniform(0.85, 1.05)
        g.add(P, R, "trunk", "point" if k else "broken", 0)
        for t0 in (0.45, 0.62, 0.78, 0.93):  # the crown: stems burst into a thorny twig mass
            i = int(t0 * 59)
            out = nrm(np.array([P[i, 0], P[i, 1], 0]) + 1e-3)
            d = nrm(out * rng.uniform(0.6, 1.1) + [0, 0, 1.0] + np.array([rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0]))
            g.grow(P[i], d, H * rng.uniform(0.32, 0.48), R[i] * 0.75, 1, up=1.2)
    g.roots(6, 1.6, 6.0, rr=0.5)
    g.flare = 0.18  # several stems: a full flare on each makes overlapping skirts
    return g


# ============================================================================================ tube mesher
_WILLOW = {}


def willow():
    if "d" not in _WILLOW:
        im = bpy.data.images.load(str(PH / "bark_willow_02/bark_willow_02_Displacement_2k.jpg"), check_existing=False)
        im.colorspace_settings.name = "Non-Color"
        a = np.empty(im.size[0] * im.size[1] * 4, np.float32)
        im.pixels.foreach_get(a)
        _WILLOW["d"] = a.reshape(im.size[1], im.size[0], 4)[..., 0].copy()
        bpy.data.images.remove(im)
    return _WILLOW["d"]


def sample_wrap(img, u, v):
    h, w = img.shape
    x, y = np.mod(u, 1.0) * w, np.mod(v, 1.0) * h
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - x0, y - y0
    x0, y0, x1, y1 = x0 % w, y0 % h, (x0 + 1) % w, (y0 + 1) % h
    return (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x1] * fx * (1 - fy) + img[y1, x0] * (1 - fx) * fy + img[y1, x1] * fx * fy)


def ptframes(C):
    T = nrm(np.gradient(C, axis=0))
    N = np.zeros_like(C)
    n0 = np.cross(T[0], [0, 0, 1.0]) if abs(T[0][2]) < 0.9 else np.cross(T[0], [1.0, 0, 0])
    N[0] = nrm(n0)
    for i in range(1, len(C)):
        v = N[i - 1] - (N[i - 1] @ T[i]) * T[i]
        ln = np.linalg.norm(v)
        N[i] = v / ln if ln > 1e-8 else N[i - 1]
    return T, N, np.cross(T, N)


def sides_lo(r):
    return 18 if r >= 4 else 14 if r >= 2.5 else 11 if r >= 1.5 else 8 if r >= 0.8 else 6 if r >= 0.4 else 5 if r >= 0.2 else 4


def role_of(b):
    if b["kind"] in ("trunk", "root"):
        return "Trunk"
    r0 = float(b["R"].max())
    return "Limbs" if r0 >= 1.2 else "Branches" if r0 >= 0.33 else "Twigs"


class Acc:
    """Mesh accumulator: vertices, quads/tris with per-corner UVs."""

    def __init__(self):
        self.V, self.Q, self.QU, self.T, self.TU, self.n = [], [], [], [], [], 0

    def build(self, name, smooth=True):
        V = np.vstack(self.V)
        Q = np.vstack(self.Q) if self.Q else np.zeros((0, 4), int)
        T = np.vstack(self.T) if self.T else np.zeros((0, 3), int)
        UV = np.concatenate([np.vstack(self.QU).reshape(-1, 2) if self.QU else np.zeros((0, 2)), np.vstack(self.TU).reshape(-1, 2) if self.TU else np.zeros((0, 2))])
        me = bpy.data.meshes.new(name)
        me.vertices.add(len(V))
        me.vertices.foreach_set("co", V.astype(np.float32).ravel())
        loops = np.concatenate([Q.ravel(), T.ravel()]).astype(np.int32)
        me.loops.add(len(loops))
        me.loops.foreach_set("vertex_index", loops)
        me.polygons.add(len(Q) + len(T))
        me.polygons.foreach_set("loop_start", np.concatenate([np.arange(len(Q)) * 4, len(Q) * 4 + np.arange(len(T)) * 3]).astype(np.int32))
        try:
            me.polygons.foreach_set("loop_total", np.concatenate([np.full(len(Q), 4), np.full(len(T), 3)]).astype(np.int32))
        except (AttributeError, TypeError, RuntimeError):
            pass
        me.update(calc_edges=True)
        me.uv_layers.new(name="UVMap").data.foreach_set("uv", UV.astype(np.float32).ravel())
        if smooth:
            me.shade_smooth()
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        return o


def tube_mesh(acc, b, level, lobes=None, flare=0.55):
    P, R = b["P"], b["R"]
    seg = np.linalg.norm(np.diff(P, axis=0), axis=1)
    Ls = np.concatenate([[0], np.cumsum(seg)])
    L = Ls[-1]
    if L < 1e-3:
        return
    r0 = float(R.max())
    hi = level == "hi"
    if hi:
        step = 0.15 if r0 < 0.33 else float(np.clip(r0 * 0.12, 0.08, 0.25))
        nphi = 8 if r0 < 0.33 else int(np.clip(round(2 * PI * r0 / 0.11), 10, 360))
    else:
        step = float(np.clip(r0 * 1.0, 0.5, 2.2))
        nphi = sides_lo(r0)
    n = max(2, int(math.ceil(L / step))) + 1
    s = np.linspace(0, L, n)
    C = np.stack([np.interp(s, Ls, P[:, k]) for k in range(3)], 1)
    Rs = np.interp(s, Ls, R)
    T, N, B = ptframes(C)
    phi = 2 * PI * np.arange(nphi) / nphi
    dirs = N[:, None, :] * np.cos(phi)[None, :, None] + B[:, None, :] * np.sin(phi)[None, :, None]
    PH_, SS = np.meshgrid(phi, s)
    sd = b["seed"]
    tw = 0.05 if b["kind"] == "trunk" and b.get("twist") else 0.0
    gn = 0.0 if r0 < 0.3 else (0.13 if b["kind"] in ("trunk", "root") else 0.1)
    rad = Rs[:, None] * (1 + gn * (0.7 * circ_noise(PH_ + tw * SS, SS / max(3.0, 2 * r0), 1.1, int(sd)) + 0.3 * circ_noise(PH_, SS / 1.6, 2.3, int(sd) + 1)))
    if b["kind"] == "trunk" and lobes:
        az = np.arctan2(dirs[..., 1], dirs[..., 0])
        lb = np.zeros_like(az)
        for a in lobes:
            lb = np.maximum(lb, np.exp(-(np.angle(np.exp(1j * (az - a))) / 0.32) ** 2))
        hz = C[:, 2][:, None]
        rad = rad * (1 + flare * np.exp(-(hz + 0.5) / 2.6) * (0.35 + lb) + 0.06 * np.exp(-(hz + 0.5) / 7.0))
    if hi and r0 >= 0.33:
        rl = Rs[:, None]
        nrep = max(1, round(2 * PI * r0 / 6.0))
        A_f, A_w = np.minimum(0.1 * rl, 0.5), np.minimum(0.04 * rl, 0.1)
        fz = SS / (2.0 + rl * 0.5)
        n1 = circ_noise(PH_ + tw * SS, fz, max(1.0, r0 * 0.95), int(sd) + 5) + 0.45 * circ_noise(PH_ + tw * SS, fz * 2.2, max(2.0, r0 * 2.0), int(sd) + 6)
        fur = 1 - sst(0.0, 0.2, np.abs(n1))
        wv = sample_wrap(willow(), nrep * PH_ / (2 * PI), SS / 6.0) - 0.55
        knot = np.zeros_like(rad)
        rng = random.Random(int(sd))
        if r0 > 0.7:
            for _ in range(int(L / 10) + rng.randint(0, 2)):
                sk, pk = rng.uniform(0.1, 0.9) * L, rng.uniform(0, 2 * PI)
                rk = float(np.interp(sk, s, Rs))
                sg = 0.35 * rk + 0.2
                d2 = (np.angle(np.exp(1j * (PH_ - pk))) * rk) ** 2 + (SS - sk) ** 2
                knot += min(0.3 * rk, 0.6) * (np.exp(-d2 / sg ** 2) - 1.4 * np.exp(-d2 / (0.35 * sg) ** 2))
        rad = rad + A_f * (0.3 - fur) + A_w * wv * 2.2 + knot
    rad = np.maximum(rad, 0.0)
    V = C[:, None, :] + rad[..., None] * dirs
    pt = b["tip"] == "point"
    if b["tip"] == "broken":
        jag = Rs[-1] * (0.5 + 0.9 * np.abs(circ_noise(phi, sd, 1.4, int(sd) + 9)))
        V[-1] += T[-1] * jag[:, None]
        if n > 2:
            V[-2] += T[-2] * (jag[:, None] * 0.35)
    rows = n - 1 if pt else n
    base = acc.n
    acc.V.append(V[:rows].reshape(-1, 3))
    acc.n += rows * nphi
    j = np.arange(nphi)
    j1 = (j + 1) % nphi
    if hi:
        nrep = max(1, round(2 * PI * r0 / 6.0)) if r0 >= 0.33 else 1
        uj, vs = nrep * np.arange(nphi + 1) / nphi, s / 6.0
    else:
        uj, vs = 2 * PI * r0 * np.arange(nphi + 1) / nphi, s
    if rows > 1:
        I = np.arange(rows - 1)[:, None]
        q = np.stack([base + I * nphi + j, base + I * nphi + j1, base + (I + 1) * nphi + j1, base + (I + 1) * nphi + j], -1).reshape(-1, 4)
        qu = np.stack([np.stack(np.broadcast_arrays(uj[j], vs[I]), -1), np.stack(np.broadcast_arrays(uj[j + 1], vs[I]), -1),
                       np.stack(np.broadcast_arrays(uj[j + 1], vs[I + 1]), -1), np.stack(np.broadcast_arrays(uj[j], vs[I + 1]), -1)], 2).reshape(-1, 4, 2)
        acc.Q.append(q)
        acc.QU.append(qu)
    # tip: apex point (twig ends taper to points) or a splintered cap
    last = base + (rows - 1) * nphi
    cpt = C[-1] if pt else C[-1] + T[-1] * Rs[-1] * 0.25
    ci = acc.n
    acc.V.append(cpt[None])
    acc.n += 1
    acc.T.append(np.stack([last + j, last + j1, np.full(nphi, ci)], 1))
    vt = vs[-1] if pt else vs[rows - 1] + 0.3 * (uj[1] - uj[0])
    acc.TU.append(np.stack([np.stack([uj[j], np.full(nphi, vs[rows - 1])], 1), np.stack([uj[j + 1], np.full(nphi, vs[rows - 1])], 1),
                            np.stack([(uj[j] + uj[j + 1]) / 2, np.full(nphi, vt)], 1)], 1))


def mesh_tree(g, name, level):
    accs = {}
    for b in g.br:
        tube_mesh(accs.setdefault(role_of(b), Acc()), b, level, g.root_ang, g.flare)
    pre = f"{name}__" if level == "lo" else f"HI_{name}__"
    return {r: a.build(pre + r) for r, a in accs.items()}


# ============================================================================================ gibbet chain
def ring(acc, c, X, Y, a, b, r, n=(16, 6), arc=2 * PI):
    th = arc * np.arange(n[0] + (0 if arc >= 2 * PI else 1)) / n[0]
    path = c + a * np.cos(th)[:, None] * X + b * np.sin(th)[:, None] * Y
    closed = arc >= 2 * PI
    Tn = nrm(np.gradient(path, axis=0) if not closed else np.roll(path, -1, 0) - np.roll(path, 1, 0))
    D = nrm(path - c - (((path - c) * Tn).sum(1))[:, None] * Tn)
    S = np.cross(Tn, D)
    ph = 2 * PI * np.arange(n[1]) / n[1]
    V = path[:, None, :] + r * (D[:, None, :] * np.cos(ph)[None, :, None] + S[:, None, :] * np.sin(ph)[None, :, None])
    m, k = V.shape[:2]
    base = acc.n
    acc.V.append(V.reshape(-1, 3))
    acc.n += m * k
    I = np.arange(m if closed else m - 1)[:, None]
    I1 = (I + 1) % m
    j = np.arange(k)
    j1 = (j + 1) % k
    q = np.stack([base + I * k + j, base + I1 * k + j, base + I1 * k + j1, base + I * k + j1], -1).reshape(-1, 4)
    acc.Q.append(q)
    uv = np.stack([np.stack(np.broadcast_arrays(I / m, j / k), -1), np.stack(np.broadcast_arrays((I + 1) / m, j / k), -1),
                   np.stack(np.broadcast_arrays((I + 1) / m, (j + 1) / k), -1), np.stack(np.broadcast_arrays(I / m, (j + 1) / k), -1)], 2)
    acc.QU.append(uv.reshape(-1, 4, 2) * 0.1)


def gibbet_chain(g, H, level):
    """Hang an iron chain + open collar from the underside of a near-horizontal limb ~0.4H up, 10-24 studs out."""
    best = None
    for b in g.br:
        if b["kind"] != "branch" or not (0.7 < b["R"].max() < 3.5):
            continue
        P, R = b["P"], b["R"]
        T = nrm(np.gradient(P, axis=0))
        for i in range(1, len(P) - 1):
            rr = math.hypot(P[i, 0], P[i, 1])
            if abs(T[i, 2]) < 0.4 and 0.3 * H < P[i, 2] < 0.55 * H and 10 < rr < 24 and R[i] > 0.6:
                sc = abs(P[i, 2] - 0.4 * H) + abs(rr - 16) * 0.3
                if best is None or sc < best[0]:
                    best = (sc, P[i], T[i], R[i])
    assert best, "no limb to hang the gibbet chain from"
    _, p, t, r = best
    acc = Acc()
    n = (16, 6) if level == "lo" else (48, 14)
    ax = nrm(np.array([t[0], t[1], 0.0]))
    side = np.cross([0, 0, 1.0], ax)
    ring(acc, p, side, np.array([0, 0, 1.0]), r + 0.16, r + 0.16, 0.14, (24 if level == "lo" else 64, n[1]))  # loop round the limb
    z = p[2] - r - 0.16
    a_, b_, w = 0.3, 0.55, 0.095
    pitch = 2 * b_ - 2.4 * w
    k = 0
    while z - 2 * b_ > 8.5:
        X = side if k % 2 == 0 else ax
        ring(acc, np.array([p[0], p[1], z - b_ + w]), X, np.array([0, 0, 1.0]), a_, b_, w, n)
        z -= pitch
        k += 1
    cz = z - b_ * 0.6
    ring(acc, np.array([p[0], p[1], cz - 0.5]), side, ax, 0.62, 0.62, 0.11, (40 if level == "lo" else 96, n[1]), arc=1.7 * PI)  # open collar
    ring(acc, np.array([p[0], p[1], cz]), side, np.array([0, 0, 1.0]), 0.2, 0.42, 0.09, n)  # shackle
    return acc.build(("" if level == "lo" else "HI_") + "Chain"), k


# ============================================================================================ hero tree build
SPECS = {
    "Dead_Oak_Gnarled_A": dict(fn=dead_oak, args=(11, 70.0, (2.6, -0.9)), H=72.0, chain=True),
    "Dead_Oak_Gnarled_B": dict(fn=dead_oak, args=(23, 84.0, (0.5, 3.6), 0.12, 0.9), H=86.0),  # gentle arms: droop + ground lift swung U-loops
    "Dead_Pine_Snapped_A": dict(fn=dead_pine, args=(5, 66.0), H=None, lean=(0.12, 30.0)),
    "Dead_Pine_Snapped_B": dict(fn=dead_pine, args=(9, 78.0), H=None, lean=(0.17, 200.0)),
    "Thorn_Twisted_A": dict(fn=thorn, args=(3, 30.0), H=30.0, lean=(0.24, 120.0)),
    "Thorn_Twisted_B": dict(fn=thorn, args=(8, 38.0), H=38.0, lean=(0.2, -40.0)),
}
SCANS = {  # CC0 Poly Haven scans: (asset, studs per metre, yaw deg, sink studs)
    "Dead_Stump_A": ("tree_stump_01", 3.57, 0.0, 0.25),
    "Dead_Stump_B": ("tree_stump_01", 5.2, 137.0, 0.35),
    "Dead_Log_A": ("dead_tree_trunk_02", 4.3, 18.0, 0.3),
    "Dead_Log_B": ("dead_tree_trunk", 5.6, -24.0, 0.12),
}
PIECES = tuple(SPECS) + tuple(SCANS)


def bark_hi_material(src):
    import vesp_bake as VB
    m = VB.hi_material("Hi_Bark", src, tile=1.0)
    nt = m.node_tree
    tc = next(n for n in nt.nodes if n.type == "TEX_COORD")
    for n in nt.nodes:
        if n.type == "MAPPING" and n.inputs["Scale"].default_value[2] == 1.0:  # the albedo/roughness mapping (not the streak one)
            nt.links.new(tc.outputs["UV"], n.inputs["Vector"])
        if n.type == "TEX_IMAGE":
            n.projection = "FLAT"
    return m


def hero(name, out, mode):
    import vesp_bake as VB
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sp = SPECS[name]
    t = time.time()
    g = sp["fn"](*sp["args"])
    if sp["H"]:
        g.scale(sp["H"] / g.top())
    if sp.get("lean"):  # bowed lean (offset grows as z^1.5, top moves k*H): upright poles read as props, not haunted trees
        k, az = sp["lean"]
        h0, dv = g.top(), np.array([math.cos(math.radians(az)), math.sin(math.radians(az))])
        for b in g.br:
            z = np.maximum(b["P"][:, 2], 0.0)
            b["P"][:, :2] += dv * (k * z ** 1.5 / h0 ** 0.5)[:, None]
    for b in g.br:
        b["P"][:, 2] = np.maximum(b["P"][:, 2], ZMIN + 0.05)
        b["twist"] = name.startswith("Thorn")
    H = g.top()
    lows = mesh_tree(g, name, "lo")
    highs = mesh_tree(g, name, "hi")
    nlinks = 0
    if sp.get("chain"):
        lc, nlinks = gibbet_chain(g, H, "lo")
        hc, _ = gibbet_chain(g, H, "hi")
        lc.name, hc.name = f"{name}__Chain", f"HI_{name}__Chain"
        FG.weather(hc, chip=0.02, erode=0.008, freq=4.0, seed=5, edge_pct=(80, 99))
        lows["Chain"], highs["Chain"] = lc, hc
    for o in lows.values():
        FG.weighted_normals(o)  # binding rule; must precede the bake (tangent normals are relative to these)
    log(f"{name}: H {H:.1f}  {len(g.br)} branches  low " + " ".join(f"{r}={VB.tris(o)}" for r, o in lows.items()) +
        "  high " + " ".join(f"{r}={VB.tris(o)}" for r, o in highs.items()) + f"  {time.time() - t:.1f}s")
    trunk = next(b for b in g.br if b["kind"] == "trunk")
    rb = float(trunk["R"][0]) * 1.5
    rkw = dict(man_xy=(rb * 0.6 + 2.5, -rb - 2.5), ez=5.5, close=(-35.0, (-rb * 1.8, -rb * 1.8, -1.0), (rb * 1.8, rb * 1.8, min(H * 0.3, rb * 2.6)), 5.5))
    rdir = out / "renders"
    rdir.mkdir(parents=True, exist_ok=True)
    if mode == "clay":
        cm = GG.clay_mat()
        for o in highs.values():
            o.data.materials.append(cm)
        for o in lows.values():
            o.hide_render = True
        return GG.render_set(name, list(highs.values()), rdir, "clayhi", **rkw), None
    maps = out / "maps"
    src = VB.stone_source("Vesp_DeadBark", maps)
    bark = bark_hi_material(src)
    iron = VB.hi_material("Hi_Iron", VB.stone_source("Vesp_Iron", maps), tile=1.0, metal=0.85, rough=0.55)
    for r, o in highs.items():
        o.data.materials.append(iron if r == "Chain" else bark)
    for r, o in lows.items():
        VB.unwrap(o, keep_existing=True)
    wood = VB.Look(base=0.25, grime=0.5, edge=0.55, frost=0.55, streak_dark=0.12, rough_base=0.88, wet_gloss=0.15, sat=0.3, frost_col=(0.7, 0.73, 0.78))
    metal = VB.Look(base=0.1, grime=0.45, edge=1.2, frost=0.2, streak_dark=0.3)
    rays = {"Trunk": (0.32, 0.9), "Limbs": (0.26, 0.65), "Branches": (0.1, 0.26), "Twigs": (0.05, 0.12), "Chain": (0.03, 0.08)}
    extra = {"height_studs": round(H, 1), "branches": len(g.br)}
    if nlinks:
        extra["gibbet_chain_links"] = nlinks
    return GG.finish(name, "G", lows, highs, out, {"*": wood, "Chain": metal}, {r: rays[r] for r in lows}, src["source"], extra, BUILDER, rkw)


# ============================================================================================ CC0 scans: stumps and logs
def scan(name, out, mode):
    import vesp_bake as VB
    from mathutils import Matrix
    bpy.ops.wm.read_factory_settings(use_empty=True)
    aid, k, yaw, sink = SCANS[name]
    glb = PH / "models" / aid / f"{aid}_2k.glb"
    bpy.ops.import_scene.gltf(filepath=str(glb))
    ms = [x for x in bpy.context.scene.objects if x.type == "MESH"]
    for x in ms:
        x.data.transform(x.matrix_world)
        x.parent = None
        x.matrix_world = Matrix.Identity(4)
    o = ms[0]
    if len(ms) > 1:
        VB._only(ms, o)
        bpy.ops.object.join()
    o.data.transform(Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Scale(k, 4))
    lo, hi = FG.bbox([o])
    o.data.transform(Matrix.Translation((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2] - sink)))
    o.name = o.data.name = f"{name}__Bark"
    imgs = {}
    for n in o.data.materials[0].node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image:
            nm = n.image.name.lower()
            kk = "Normal" if "nor" in nm else "Roughness" if ("rough" in nm or "arm" in nm) else "Color" if ("diff" in nm or "col" in nm) else None
            if kk:
                imgs[kk] = n.image
    assert set(imgs) == {"Color", "Normal", "Roughness"}, f"{aid}: scan maps not found: {sorted(imgs)}"
    arr = {}
    for kk, im in imgs.items():
        im.colorspace_settings.name = "Non-Color"  # raw stored values
        a = np.empty(im.size[0] * im.size[1] * 4, np.float32)
        im.pixels.foreach_get(a)
        arr[kk] = a.reshape(im.size[1], im.size[0], 4)[..., :3]
    size = arr["Color"].shape[0]
    rdir = out / "renders"
    rdir.mkdir(parents=True, exist_ok=True)
    lo, hi = FG.bbox([o])
    L = float(max(hi[0] - lo[0], hi[1] - lo[1]))
    rkw = dict(man_xy=(hi[0] + 1.6, lo[1] - 1.0), ez=5.0, close=(-35.0, lo, hi, float(hi[2]) * 0.6 + 1.0))
    # frost mask: bake world normal z + object-space breakup noise onto the scan's own UVs
    VB.cycles(1)
    tmp = bpy.data.materials.new("vb_frost")
    tmp.use_nodes = True
    nt = tmp.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    outn, em = nt.nodes.new("ShaderNodeOutputMaterial"), nt.nodes.new("ShaderNodeEmission")
    nt.links.new(em.outputs[0], outn.inputs["Surface"])
    geo, sep, mr = nt.nodes.new("ShaderNodeNewGeometry"), nt.nodes.new("ShaderNodeSeparateXYZ"), nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -1.0
    nt.links.new(geo.outputs["Normal"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    tco, nz = nt.nodes.new("ShaderNodeTexCoord"), nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 1.2
    nz.inputs["Detail"].default_value = 5.0
    nt.links.new(tco.outputs["Object"], nz.inputs["Vector"])
    cc = nt.nodes.new("ShaderNodeCombineColor")
    nt.links.new(mr.outputs["Result"], cc.inputs[0])
    nt.links.new(nz.outputs["Fac"], cc.inputs[1])
    nt.links.new(cc.outputs[0], em.inputs["Color"])
    im = bpy.data.images.new("vb_frost", size, size, alpha=False, float_buffer=True, is_data=True)
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = im
    nt.nodes.active = tn
    keep = list(o.data.materials)
    o.data.materials.clear()
    o.data.materials.append(tmp)
    rb = bpy.context.scene.render.bake
    rb.use_selected_to_active, rb.margin = False, 8
    VB._only([o], o)
    bpy.ops.object.bake(type="EMIT")
    f = VB._pix(im)[..., :3]
    o.data.materials.clear()
    for m in keep:
        o.data.materials.append(m)
    # retone: stored sRGB values, desaturated bleached-grey dead wood, frost dust on up-facing surfaces
    col = arr["Color"]
    lum = col @ np.array([0.299, 0.587, 0.114], np.float32)
    col = lum[..., None] + 0.3 * (col - lum[..., None])
    col = col * (0.26 / max(float(lum.mean()), 1e-4)) * np.array([1.0, 0.99, 0.97], np.float32)
    fm = sst(0.62, 0.93, f[..., 0] * 2 - 1) * sst(0.42, 0.6, f[..., 1]) * 0.6
    col = col * (1 - fm[..., None]) + np.array([0.7, 0.73, 0.78], np.float32) * fm[..., None]
    rch = 1 if "arm" in imgs["Roughness"].name.lower() else 0  # packed AO/Rough/Metal keeps roughness in G
    rough = np.clip(arr["Roughness"][..., rch] * 0.55 + 0.42 - 0.1 * fm, 0.3, 1.0)
    mname = f"Vesp_{name}__Bark"
    maps = out / "maps"
    maps.mkdir(parents=True, exist_ok=True)
    paths = {kk: maps / f"{mname}_{kk}.png" for kk in VB.KINDS}
    VB.save_png(paths["Color"], np.clip(col, 0, 1), True)
    VB.save_png(paths["Normal"], arr["Normal"], False)
    VB.save_png(paths["Roughness"], rough, False)
    VB.save_png(paths["Metal"], np.zeros(col.shape[:2], np.float32), False)
    o.data.materials.clear()
    o.data.materials.append(VB.low_material(mname, paths))
    subs, objs = {}, []
    for so in VB.split_cap(o, 17500):
        subs[so.name] = VB.tris(so)
        objs.append(so)
    glb_out = out / f"{name}.glb"
    GG.export_glb(objs, glb_out)
    lo, hi = FG.bbox(objs)
    e = {"group": "G", "sub_meshes": subs, "tris_total": sum(subs.values()),
         "size_studs_xyz": [round(float(hi[i] - lo[i]), 1) for i in range(3)],
         "bbox_min": [round(float(c), 2) for c in lo], "bbox_max": [round(float(c), 2) for c in hi],
         "materials": [mname], "file": glb_out.name, "builder": BUILDER.replace("generated skeleton, high-poly bark, Cycles-baked", "CC0 scan, retoned"),
         "no_decimation": True, "decimation": f"none: the {aid} scan is split into <18k-tri subs at full density",
         "source": f"Poly Haven {aid} (CC0), {glb.relative_to(ROOT).as_posix()}", "scale_studs_per_m": k,
         "map_resolution": {"Bark": size}, "maps": {"Bark": {kk: p.relative_to(out).as_posix() for kk, p in paths.items()}},
         "base_layer": f"Poly Haven {aid} 2k maps, retoned"}
    log(f"{name}: {aid} x{k} -> {e['size_studs_xyz']} studs, subs {subs}")
    files = GG.render_set(name, objs, rdir, "baked", **rkw)
    return files, e


# ============================================================================================ main
SHEETS = [("G1_trees_v2_oaks", ("Dead_Oak_Gnarled_A", "Dead_Oak_Gnarled_B")), ("G1_trees_v2_pines", ("Dead_Pine_Snapped_A", "Dead_Pine_Snapped_B")),
          ("G1_trees_v2_thorns", ("Thorn_Twisted_A", "Thorn_Twisted_B")), ("G1_trees_v2_stumps_logs", ("Dead_Stump_A", "Dead_Stump_B", "Dead_Log_A", "Dead_Log_B"))]


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(a[0] if a else ROOT / "assets/source/vesperhold/trees").resolve()
    only = [s for s in os.environ.get("VESP_ONLY", "").split(",") if s] or list(PIECES)
    mode = os.environ.get("VESP_TREE_MODE", "bake")
    tag = "clayhi" if mode == "clay" else "baked"
    entries = {}
    for name in PIECES:
        if name not in only:
            continue
        if name in SCANS and mode == "clay":
            continue
        files, e = (scan if name in SCANS else hero)(name, out, mode)
        if e:
            entries[name] = e
    if entries:
        GG.merge_manifest(out, entries, "Vesperhold withered trees (group G)")
        mf = out / "manifest.json"
        m = json.loads(mf.read_text())
        m.update({"kit": "Vesperhold withered trees (group G) v2", "build": "blender -b -P tools/blender/vesperhold/vesperhold_trees.py",
                  "pivot": "trunk base centre at origin, z=0 ground (Blender Z up, GLB Y up); roots buried <= 2.8 studs"})
        m.pop("textures", None)
        mf.write_text(json.dumps(m, indent=2))
    v2 = Path(os.environ.get("VESP_SHEET_DIR", ROOT / "outputs/vesperhold/kit-renders-v2"))
    v2.mkdir(parents=True, exist_ok=True)
    for sheet_name, names in SHEETS:
        rows = [sorted((out / "renders").glob(f"{n}_{tag}_*.png")) for n in names]
        rows = [r for r in rows if r]
        if rows and any(n in only for n in names):
            dst = out / "renders" / f"{sheet_name}_{tag}.jpg"
            FG.sheet(rows, dst)
            log("sheet", dst)
            if mode != "clay":
                shutil.copy2(dst, v2 / f"{sheet_name}.jpg")


if __name__ == "__main__":
    main()
