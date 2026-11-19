"""Vesperhold hooded statues, hand-modelled (mac-51): Hooded_Statue_A (sleeves joined), Hooded_Statue_B (staff-bearer),
Pedestal_Statue_Staff (cloaked sword-bearer on a stepped gothic pedestal). Replaces the rejected mac-44 statues.

  /Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 -P tools/blender/vesperhold/vesperhold_figures.py -- [out_dir]
  default out_dir: assets/source/vesperhold/props        env: VESP_ONLY=Piece,Piece  VESP_FIG_MODE=bake|clay
  VESP_BAKE_SIZE=1024 (look iterations; final 2048)  VESP_NORENDER=1

Method: every surface is a parametric sheet evaluated twice from the same function: HIGH (~0.8-2.5M tris: crisp crease
folds, belt gathers, rope twist, seams, chips/erosion) and LOW (role subs, macro folds kept in geometry). Plinths: clean low,
voxel-remeshed + chipped high. vesp_bake.py bakes HIGH -> LOW per role (Color/Normal/Roughness/Metal 2048). Never decimated;
roles over the cap are split into <18k-tri chunks that share one map set. Exports <Piece>.glb (no images; vesp_embed.py
embeds maps by material name) and merges ONLY these three entries into <out_dir>/manifest.json.
Units studs, pivot foot centre (z=0), figure faces -Y. Imported by vesperhold_props.py only for manifest preservation.
"""
import json
import math
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bpy  # noqa: E402
import numpy as np  # noqa: E402

ROOT = HERE.parents[2]
PIECES = ("Hooded_Statue_A", "Hooded_Statue_B", "Pedestal_Statue_Staff")
T0 = time.time()
PI = math.pi


def log(*a):
    print(f"[{time.time() - T0:7.1f}s]", *a, flush=True)


# ============================================================================================ math helpers
def sst(e0, e1, x):
    t = np.clip((np.asarray(x, float) - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def nrm(a):
    return a / np.maximum(np.linalg.norm(a, axis=-1, keepdims=True), 1e-9)


def interp(tab, x):
    tab = np.asarray(tab, float)
    return np.interp(x, tab[:, 0], tab[:, 1])


def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761 % 2147483647)
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF).astype(np.float64) / float(0xFFFFFF)


def vnoise(p, seed=0):
    """Value noise in [-1, 1]; p (..., 3)."""
    p = np.asarray(p, float)
    pf = np.floor(p)
    f = p - pf
    i = pf.astype(np.int64)
    w = f * f * (3 - 2 * f)
    acc = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                h = _hash(i[..., 0] + dx, i[..., 1] + dy, i[..., 2] + dz, seed)
                acc = acc + h * (w[..., 0] if dx else 1 - w[..., 0]) * (w[..., 1] if dy else 1 - w[..., 1]) * (w[..., 2] if dz else 1 - w[..., 2])
    return acc * 2 - 1


def fbm(p, oct=4, seed=0):
    s, a, tot = 0.0, 1.0, 0.0
    for o in range(oct):
        s = s + a * vnoise(np.asarray(p) * (2 ** o), seed + o * 17)
        tot += a
        a *= 0.5
    return s / tot


def circ_noise(th, z, sc, seed):
    """Periodic-in-theta noise (no seam)."""
    return vnoise(np.stack([np.cos(th) * sc, np.sin(th) * sc, np.broadcast_to(z, np.shape(th))], -1), seed)


def prof(w):
    """Fold ridge: rounded crest, creased valley at integers. 0..1."""
    return np.sin(PI * (w - np.floor(w))) ** 0.8


def rnd_fold(w, n, seed):
    i = np.mod(np.floor(w), n).astype(np.int64)
    return 0.4 + 1.2 * _hash(i, i * 3 + 1, i * 7 + 2, seed)


def angdiff(a, b):
    return np.angle(np.exp(1j * (a - b)))


def spline(ctrl, n):
    C = np.asarray(ctrl, float)
    P = np.vstack([2 * C[0] - C[1], C, 2 * C[-1] - C[-2]])
    pts = []
    t = np.linspace(0, 1, 64, endpoint=False)[:, None]
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        pts.append(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t ** 2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    pts.append(C[-1][None])
    D = np.vstack(pts)
    L = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(D, axis=0), axis=1))])
    tgt = np.linspace(0, L[-1], n)
    out = np.stack([np.interp(tgt, L, D[:, i]) for i in range(3)], 1)
    ks = np.append(L[np.arange(len(C) - 1) * 64], L[-1]) / L[-1]
    return out, tgt / L[-1], L[-1], ks


def frames(C, ref):
    T = nrm(np.gradient(C, axis=0))
    ref = np.broadcast_to(np.asarray(ref, float), C.shape)
    D = ref - (ref * T).sum(-1, keepdims=True) * T
    bad = np.linalg.norm(D, axis=-1) < 1e-3
    if bad.any():
        alt = np.cross(T, [1.0, 0.0, 0.0])
        D[bad] = alt[bad]
    D = nrm(D)
    return T, D, np.cross(T, D)


def tube_pts(C, D, S, R, phis):
    return C[:, None, :] + R[..., None] * (D[:, None, :] * np.cos(phis)[None, :, None] + S[:, None, :] * np.sin(phis)[None, :, None])


def grid_normals(P, closed_u, nref):
    du = (np.roll(P, -1, 1) - np.roll(P, 1, 1)) if closed_u else np.gradient(P, axis=1)
    dv = np.gradient(P, axis=0)
    n = np.cross(du, dv)
    if (n * nref).sum() < 0:
        n = -n
    bad = np.linalg.norm(n, axis=-1) < 1e-12
    n = nrm(n)
    n[bad] = nrm(nref)[bad]
    return n


def shell_rows(P, N, t, inner_from=0, K=6, lip=0.0, void_inner=None):
    """Thick open edge at the LAST row: outer rows, rolled lip, inner rows (offset -N*t) back to inner_from."""
    Pi = P[inner_from:] - N[inner_from:] * t
    T = nrm(P[-1] - P[-2])
    mid = P[-1] - N[-1] * t / 2
    g = PI * np.arange(1, K) / K
    lipP = mid[None] + N[-1][None] * (t / 2) * np.cos(g)[:, None, None] + T[None] * ((t / 2 + lip) * np.sin(g))[:, None, None]
    lipN = N[-1][None] * np.cos(g)[:, None, None] + T[None] * np.sin(g)[:, None, None]
    vi = np.zeros(len(Pi)) if void_inner is None else np.asarray(void_inner, float)
    rows = np.concatenate([P, lipP, Pi[::-1]])
    nref = np.concatenate([N, lipN, -N[inner_from:][::-1]])
    void = np.concatenate([np.zeros(len(P)), np.zeros(K - 1), vi[::-1]])
    return rows, nref, void


# ============================================================================================ mesh builder
class MB:
    def __init__(self):
        self.V, self.Q, self.T, self.VD, self.MQ, self.MT, self.n = [], [], [], [], [], [], 0

    def _pt(self, p, void):
        self.V.append(np.asarray(p, float).reshape(1, 3))
        self.VD.append(np.array([void], float))
        self.n += 1
        return self.n - 1

    def grid(self, P, nref, closed_u=False, closed_v=False, cap0=False, cap1=False, void=0.0, mat=0):
        P = np.asarray(P, float)
        nr, nc = P.shape[:2]
        nref = np.broadcast_to(nref, P.shape)
        idx = self.n + np.arange(nr * nc).reshape(nr, nc)
        void = np.asarray(void, float)
        vd = np.broadcast_to(void.reshape(-1, 1) if void.ndim == 1 else void, (nr, nc))
        self.V.append(P.reshape(-1, 3))
        self.VD.append(np.array(vd, float).reshape(-1))
        self.n += nr * nc
        jc = np.arange(nc) if closed_u else np.arange(nc - 1)
        j1 = (jc + 1) % nc
        ic = np.arange(nr) if closed_v else np.arange(nr - 1)
        i1 = (ic + 1) % nr
        a, b, c, d = idx[ic][:, jc], idx[ic][:, j1], idx[i1][:, j1], idx[i1][:, jc]
        q = np.stack([a, b, c, d], -1).reshape(-1, 4)
        Pa, Pb, Pd = P[ic][:, jc], P[ic][:, j1], P[i1][:, jc]
        flip = (np.cross(Pb - Pa, Pd - Pa) * nref[ic][:, jc]).sum() < 0
        if flip:
            q = q[:, [0, 3, 2, 1]]
        self.Q.append(q)
        self.MQ.append(np.full(len(q), mat))
        jj = np.arange(nc) if closed_u else np.arange(nc - 1)
        jn = (jj + 1) % nc
        for cap, row in ((cap0, 0), (cap1, nr - 1)):
            if not cap:
                continue
            ci = self._pt(P[row].mean(0), float(vd[row].mean()))
            A, B, Cc = idx[row, jj], idx[row, jn], np.full(len(jj), ci)
            first = (row == 0) != flip
            tri = np.stack([B, A, Cc], -1) if first else np.stack([A, B, Cc], -1)
            self.T.append(tri)
            self.MT.append(np.full(len(tri), mat))

    def build(self, name, M=None, smooth=True):
        V = np.vstack(self.V)
        if M is not None:
            V = V @ M[:3, :3].T + M[:3, 3]
        Q = np.vstack(self.Q) if self.Q else np.zeros((0, 4), int)
        T = np.vstack(self.T) if self.T else np.zeros((0, 3), int)
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
        mats = np.concatenate((self.MQ or [np.zeros(0, int)]) + (self.MT or [np.zeros(0, int)])).astype(np.int32)
        me.polygons.foreach_set("material_index", mats)
        me.update(calc_edges=True)
        vd = np.concatenate(self.VD).astype(np.float32)
        if vd.max() > 0:
            me.attributes.new("void", "FLOAT", "POINT").data.foreach_set("value", vd)
        if smooth:
            me.shade_smooth()
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        return o


def Mrot_z(deg, tz=0.0):
    a = math.radians(deg)
    M = np.eye(4)
    M[:2, :2] = [[math.cos(a), -math.sin(a)], [math.sin(a), math.cos(a)]]
    M[2, 3] = tz
    return M


# ============================================================================================ statue configs (14-stud units)
ROBE = dict(
    rx=[(0, 1.92), (0.02, 1.72), (0.06, 1.6), (0.3, 1.47), (0.5, 1.32), (0.53, 1.24), (0.58, 1.32), (0.7, 1.38), (0.78, 1.45),
        (0.805, 1.4), (0.83, 1.15), (0.855, 0.66), (0.875, 0.46)],
    ryf=[(0, 1.62), (0.02, 1.42), (0.06, 1.3), (0.3, 1.12), (0.5, 1.0), (0.53, 0.93), (0.58, 1.0), (0.7, 1.0), (0.78, 0.9),
         (0.83, 0.75), (0.855, 0.55), (0.875, 0.42)],
    ryb=[(0, 1.55), (0.06, 1.22), (0.3, 1.0), (0.5, 0.92), (0.53, 0.86), (0.6, 0.95), (0.72, 1.05), (0.8, 1.0), (0.83, 0.85),
         (0.855, 0.58), (0.875, 0.44)],
    cy=[(0, 0.0), (0.5, 0.0), (0.7, -0.05), (0.85, -0.2), (0.875, -0.25)],
    t_top=0.875, belt=0.53, t_sh=0.80, n1=10, amp1=0.28, n2=29, amp2=0.05, n3=5, amp3=0.09, n4=9, amp4=0.08, chest=0.75)

CFG = {
    "Hooded_Statue_A": dict(
        H=14.0, z0=2.0, yaw=0.0, seed=11, knee=1, robe={}, capelet=True, cloak=False,
        hood=dict(c=(0, -0.3, 12.7), axis=(0, -1, -0.3), r=(0.98, 1.25, 0.86), peak=0.45, t=0.11),
        arms=[dict(path=[(-0.85, 0.05, 10.9), (-1.3, 0.1, 10.75), (-1.5, 0.16, 9.85), (-1.46, 0.05, 8.95), (-1.0, -1.05, 8.95), (-0.1, -1.42, 9.1)],
                   r=[0.34, 0.4, 0.42, 0.42, 0.48, 0.54], sag=[0, 0, 0, 0.3, 1.1, 1.35], ref=(0, 0, -1), tail=0.15, hand=None),
              dict(path=[(0.85, 0.05, 10.9), (1.3, 0.1, 10.75), (1.5, 0.16, 9.85), (1.46, 0.05, 8.95), (1.0, -1.05, 8.95), (0.1, -1.42, 9.1)],
                   r=[0.34, 0.4, 0.42, 0.42, 0.48, 0.54], sag=[0, 0, 0, 0.3, 1.1, 1.35], ref=(0, 0, -1), tail=0.15, hand=None)],
        cords=True, staff=None, sword=None, plinth="low"),
    "Hooded_Statue_B": dict(
        H=14.0, z0=2.0, yaw=-12.0, seed=23, knee=-1, robe=dict(n1=9, amp1=0.3), capelet=True, cloak=False,
        hood=dict(c=(0, -0.28, 12.75), axis=(-0.15, -1, -0.22), r=(0.98, 1.25, 0.86), peak=0.48, t=0.11),
        arms=[dict(path=[(-0.85, 0.05, 10.9), (-1.3, 0.1, 10.75), (-1.6, 0.16, 9.85), (-1.74, 0.1, 8.85), (-1.86, -0.18, 8.92), (-1.92, -0.36, 9.0)],
                   r=[0.34, 0.4, 0.44, 0.46, 0.48, 0.5], sag=[0, 0, 0, 0.15, 0.55, 0.8], ref=(0, 0, -1), tail=0.45,
                   hand=dict(c=(-2.05, -1.05, 9.25), axis=(0, 0, 1), back=(-1, -0.25, 0), rg=0.13, forearm=1.1)),
              dict(path=[(0.85, 0.05, 10.9), (1.3, 0.1, 10.75), (1.56, 0.14, 9.7), (1.62, 0.06, 8.5), (1.6, -0.12, 7.4), (1.56, -0.22, 6.55)],
                   r=[0.34, 0.4, 0.44, 0.47, 0.6, 0.8], sag=[0, 0, 0, 0, 0, 0], ref=(0, 1, 0), tail=0.0, hand=None)],
        cords=True, staff=dict(x=-2.05, y=-1.05, top=16.6, r=0.13), sword=None, plinth="low"),
    "Pedestal_Statue_Staff": dict(
        H=16.0, z0=7.0, yaw=0.0, seed=37, knee=1, robe=dict(n1=11, amp4=0.1, chest=1.05), capelet=False, cloak=True,
        hood=dict(c=(0, -0.32, 12.75), axis=(0, -1, -0.28), r=(1.0, 1.27, 0.88), peak=0.46, t=0.11),
        arms=[dict(path=[(-0.85, 0.05, 10.9), (-1.3, 0.1, 10.75), (-1.55, 0.05, 9.9), (-1.5, -0.4, 8.85), (-0.95, -1.18, 7.85), (-0.42, -1.68, 7.5)],
                   r=[0.34, 0.4, 0.44, 0.47, 0.52, 0.58], sag=[0, 0, 0, 0.1, 0.3, 0.45], ref=(0, 0, -1),
                   hand=dict(c=(0, -2.03, 7.42), axis="sword", back=(-1, -0.5, 0), rg=0.12)),
              dict(path=[(0.85, 0.05, 10.9), (1.3, 0.1, 10.75), (1.55, 0.05, 9.9), (1.52, -0.42, 9.0), (0.95, -1.22, 8.4), (0.42, -1.7, 8.22)],
                   r=[0.34, 0.4, 0.44, 0.47, 0.52, 0.58], sag=[0, 0, 0, 0.1, 0.3, 0.45], ref=(0, 0, -1),
                   hand=dict(c=(0, -2.01, 8.12), axis="sword", back=(1, -0.5, 0), rg=0.12))],
        cords=False, staff=None, sword=dict(tip=(0, -2.28, 0.05), top=(0, -1.98, 9.05), guard=7.0, grip=(7.05, 8.62)), plinth="pedestal"),
}

RES = {  # (rows, cols) per level
    "robe": {"lo": (112, 128), "hi": (620, 768)}, "hood": {"lo": (30, 72), "hi": (170, 400)}, "lip": {"lo": 5, "hi": 12},
    "capelet": {"lo": (26, 112), "hi": (150, 640)}, "cloak": {"lo": (90, 72), "hi": (520, 420)},
    "sleeve": {"lo": (56, 36), "hi": (320, 160)}, "belt": {"lo": (120, 10), "hi": (900, 28)}, "cord": {"lo": (40, 8), "hi": (260, 24)},
    "finger": {"lo": (14, 10), "hi": (64, 32)}, "palm": {"lo": (14, 20), "hi": (64, 96)}, "staff": {"lo": (64, 16), "hi": (900, 48)},
    "head": {"lo": (40, 12), "hi": (220, 40)}, "blade": {"lo": (40, 14), "hi": (420, 72)},
}


# ============================================================================================ robe
class Robe:
    def __init__(self, cfg, level):
        self.c = dict(ROBE, **cfg.get("robe", {}))
        self.k = cfg["H"] / 14.0
        self.H = cfg["H"]
        self.seed = cfg["seed"]
        self.knee = cfg["knee"]
        self.hi = level == "hi"

    def base(self, TH, T, env=False):
        c, k = self.c, self.k
        rx = interp(c["rx"], T) * k
        if env:  # sleeves widen the shoulders for anything that drapes over them
            rx = rx + 0.12 * k * np.exp(-((T - c["t_sh"]) / 0.03) ** 2)
        ryf, ryb = interp(c["ryf"], T) * k, interp(c["ryb"], T) * k
        cy = interp(c["cy"], T) * k
        ct, st = np.cos(TH), np.sin(TH)
        ry = ryf + (ryb - ryf) * sst(-0.35, 0.35, ct)
        return np.stack([rx * st, cy + ry * ct, T * self.H], -1)

    def folds(self, TH, T):
        c, k, sd = self.c, self.k, self.seed
        vb = c["belt"]
        s = np.clip(T / vb, 0, 1)
        front = 0.85 + 0.15 * (-np.cos(TH))
        w1 = c["n1"] * TH / (2 * PI) + 0.6 * circ_noise(TH, T * 1.4, 1.5, sd) + 0.05 * np.sin(2 * TH + 3 * T)
        r1 = rnd_fold(w1, c["n1"], sd)
        d1 = c["amp1"] * k * sst(1.0, 0.62, s) * (0.8 + 0.2 * (1 - s)) * front * r1 * prof(w1)
        d3 = c["amp3"] * k * (1 - s) * (0.5 + 0.5 * np.sin(c["n3"] * TH + 2.0 + 0.8 * circ_noise(TH, 0.0, 1.0, sd + 5)))
        knee = 0.14 * k * np.exp(-((T - 0.3) / 0.11) ** 2) * np.exp(-(angdiff(TH, PI - self.knee * 0.45) / 0.42) ** 2)
        h = sst(0.045, 0.0, T)
        hem = h * (0.06 * k + 0.08 * k * prof(w1) * r1)
        s2 = np.clip((T - vb) / (c["t_sh"] - vb), 0, 1)
        w4 = c["n4"] * TH / (2 * PI) + 0.5 * circ_noise(TH, T * 2.5, 1.5, sd + 9) + 2.5 * (T - vb) * np.sin(TH)
        d4 = c["amp4"] * k * sst(0, 0.06, s2) * (1 - sst(0.15, c["chest"], s2)) * prof(w4) * rnd_fold(w4, c["n4"], sd + 1)
        blouse = 0.07 * k * np.exp(-((s2 - 0.13) / 0.1) ** 2) * sst(0, 0.05, s2)
        pinch = -0.045 * k * np.exp(-((T - vb) / 0.007) ** 2)
        below = d1 + d3 + knee + hem
        if self.hi:
            w2 = c["n2"] * TH / (2 * PI) + 0.3 * circ_noise(TH, T * 3.0, 2.0, sd + 3)
            below = below + c["amp2"] * k * sst(0.75, 0.93, s) * (1 - sst(0.985, 1.0, s)) * prof(w2) * rnd_fold(w2, c["n2"], sd + 2)
            below = below + h * 0.025 * k * prof(41 * TH / (2 * PI) + 0.4 * circ_noise(TH, 0, 3.0, sd + 4))
        return np.where(T < vb, below, d4 + blouse) + pinch

    def eval(self, TH, T):
        e = 1e-3
        B = self.base(TH, T)
        du = self.base(TH + e, T) - self.base(TH - e, T)
        dv = self.base(TH, T + e) - self.base(TH, T - e)
        N = nrm(np.cross(dv, du))
        d = self.folds(TH, T)
        if self.hi:
            d = d + 0.006 * self.k * fbm(B * 3.0, 3, self.seed + 40)
        return B + N * d[..., None], N, d

    def grid(self, mb, res):
        nr, nc = res
        th = 2 * PI * np.arange(nc) / nc
        t = np.linspace(0, self.c["t_top"], nr)
        TH, T = np.meshgrid(th, t)
        P, N, _ = self.eval(TH, T)
        void = sst(0.845, 0.87, T)  # neck under the hood
        mb.grid(P, N, closed_u=True, cap0=self.hi, cap1=True, void=void)  # low: no hidden hem cap (saves ~15% of the map)

    def env(self, th, t):
        """Radius of anything hanging from above (capelet, cloak): running max of the shoulder-widened body from the top down."""
        tt = np.linspace(0, self.c["t_top"], 400)
        TH, TT = np.meshgrid(th, tt)
        B = self.base(TH, TT, env=True)
        r = np.hypot(B[..., 0], B[..., 1])
        r = np.maximum.accumulate(r[::-1], axis=0)[::-1]
        out = np.empty((len(t), len(th)))
        for j in range(len(th)):
            out[:, j] = np.interp(t[:, j] if np.ndim(t) == 2 else t, tt, r[:, j])
        return out


# ============================================================================================ hood, capelet, cloak
def hood(mb, cfg, level, void_strength=1.0):
    h, k, sd = cfg["hood"], cfg["H"] / 14.0, cfg["seed"]
    nr, nc = RES["hood"][level]
    Hc = np.array(h["c"], float) * k
    a = nrm(np.array(h["axis"], float))
    up = np.array([0, 0, 1.0])
    u0 = nrm(up - up.dot(a) * a)
    sv = np.cross(a, u0)
    beta = 2 * PI * np.arange(nc) / nc - PI
    v = np.linspace(0, 1, nr)
    B, V = np.meshgrid(beta, v)
    a0 = 0.42 + 0.43 * (np.abs(B) / PI) ** 1.2
    al = a0 + V * (PI - 0.035 - a0)
    d = a[None, None] * np.cos(al)[..., None] + (u0[None, None] * np.cos(B)[..., None] + sv[None, None] * np.sin(B)[..., None]) * np.sin(al)[..., None]
    ra, ru, rs = (np.array(h["r"]) * k)
    da, du_, ds = d @ a, d @ u0, d @ sv
    R = 1.0 / np.sqrt((da / ra) ** 2 + (du_ / ru) ** 2 + (ds / rs) ** 2)
    pdir = nrm(-a * 0.6 + u0 * 0.8)
    ang = np.arccos(np.clip(d @ pdir, -1, 1))
    R = R + h["peak"] * k * np.exp(-(ang / 0.28) ** 2)
    P = Hc + d * R[..., None]
    N = grid_normals(P, True, P - Hc)
    w = 7 * (B + PI) / (2 * PI) + 0.35 * circ_noise(B, V, 1.2, sd + 21)
    cheek = 0.35 + 1.6 * np.exp(-((np.abs(B) - 2.1) / 0.5) ** 2)
    disp = 0.045 * k * (1 - V) ** 2.0 * cheek * prof(w) * rnd_fold(w, 7, sd + 22)
    if level == "hi":
        disp = disp + 0.03 * k * np.exp(-(B / 0.05) ** 2) * sst(0.04, 0.2, V)  # crown seam
        disp = disp + 0.004 * k * fbm(P * 3.5, 3, sd + 23)
    P = P + N * disp[..., None]
    t = h["t"] * k
    rows, nref, void = shell_rows(P[::-1], N[::-1], t, 0, RES["lip"][level], lip=0.025 * k,
                                  void_inner=void_strength * sst(0.05, 0.35, v[::-1]))
    mb.grid(rows, nref, closed_u=True, cap0=True, cap1=True, void=void)


def capelet(mb, cfg, robe, level):
    """Shoulder cowl: rounded dome from the neck over the shoulders (quarter ellipse), then a short hang to a wavy hem."""
    k, sd, H = cfg["H"] / 14.0, cfg["seed"], cfg["H"]
    nr, nc = RES["capelet"][level]
    th = 2 * PI * np.arange(nc) / nc
    v = np.linspace(0, 1, nr)
    TH, V = np.meshgrid(th, v)
    vs = 0.55
    om = np.clip(V / vs, 0, 1) * PI / 2
    f2 = np.clip((V - vs) / (1 - vs), 0, 1)
    zn, zs = 12.25, 11.0
    zh = 10.27 - 0.2 * np.cos(2 * TH) + 0.06 * circ_noise(TH, 0, 2, sd + 31)
    (rxn, ryn), (rxs, rys), (rxh, ryh) = (0.74, 0.66), (1.7, 1.18), (1.78, 1.26)
    dome = V < vs
    rx = np.where(dome, rxn + (rxs - rxn) * np.sin(om), rxs + (rxh - rxs) * f2) * k
    ry = np.where(dome, ryn + (rys - ryn) * np.sin(om), rys + (ryh - rys) * f2) * k
    z = np.where(dome, zs + (zn - zs) * np.cos(om), zs + (zh - zs) * f2) * k
    cy = interp(robe.c["cy"], z / H) * k
    P = np.stack([rx * np.sin(TH), cy + ry * np.cos(TH), z], -1)
    N = grid_normals(P, True, np.stack([np.sin(TH), np.cos(TH), np.zeros_like(TH)], -1))
    w = 10 * TH / (2 * PI) + 0.4 * circ_noise(TH, V * 0.8, 1.4, sd + 32)
    disp = 0.12 * k * sst(0.15, 1.0, V) ** 1.3 * prof(w) * rnd_fold(w, 10, sd + 33)
    if level == "hi":
        disp = disp + 0.004 * k * fbm(P * 3.5, 3, sd + 34)
    P = P + N * disp[..., None]
    i0 = int(nr * 0.5)
    rows, nref, void = shell_rows(P, N, 0.08 * k, i0, RES["lip"][level], lip=0.02 * k)
    mb.grid(rows, nref, closed_u=True, void=void)


def _env_at(robe, TH, T):
    tt = np.linspace(0, robe.c["t_top"], 400)
    ths = np.linspace(-PI, PI, 361)
    THs, TTs = np.meshgrid(ths, tt)
    Bs = robe.base(THs, TTs, env=True)
    rs = np.maximum.accumulate(np.hypot(Bs[..., 0], Bs[..., 1])[::-1], axis=0)[::-1]
    fi = np.clip((np.angle(np.exp(1j * TH)) + PI) / (2 * PI) * 360, 0, 359.999)
    fj = np.clip(T / robe.c["t_top"] * 399, 0, 398.999)
    i0, j0 = fi.astype(int), fj.astype(int)
    a, b = fi - i0, fj - j0
    return (rs[j0, i0] * (1 - a) * (1 - b) + rs[j0, i0 + 1] * a * (1 - b) + rs[j0 + 1, i0] * (1 - a) * b + rs[j0 + 1, i0 + 1] * a * b)


def cloak(mb, cfg, robe, level):
    k, sd, H = cfg["H"] / 14.0, cfg["seed"], cfg["H"]
    nr, nc = RES["cloak"][level]
    u = np.linspace(0, 1, nc)
    t = np.linspace(0.862, 0.012, nr)
    U, T = np.meshgrid(u, t)
    tho = interp([(0.0, 1.05), (0.55, 1.35), (0.72, 1.35), (0.8, 0.9), (0.862, 0.3)], T)
    TH = (2 * U - 1) * (PI - tho)
    T = T + 0.006 * circ_noise(TH, 0, 2, sd + 41) * sst(0.05, 0.0, T)
    r = _env_at(robe, TH, T) + 0.1 * k + 0.32 * k * sst(0.75, 0.0, T) ** 1.3
    P = np.stack([r * np.sin(TH), r * np.cos(TH), T * H], -1)
    N = grid_normals(P, False, np.stack([np.sin(TH), np.cos(TH), np.zeros_like(TH)], -1))
    w = 9 * U + 0.4 * vnoise(np.stack([U * 3, T * 1.5, U * 0 + sd], -1), sd + 42)
    A = k * (0.05 + 0.2 * sst(0.82, 0.15, T))
    disp = A * prof(w) * rnd_fold(w, 1000, sd + 43)
    if level == "hi":
        disp = disp + 0.004 * k * fbm(P * 3.5, 3, sd + 44)
    P = P + N * disp[..., None]
    rows, nref, void = shell_rows(P, N, 0.09 * k, 0, RES["lip"][level], lip=0.02 * k)
    mb.grid(rows, nref, closed_u=False, void=void)
    R = len(rows)
    for col in (0, -1):  # flat strips closing the front edges (outer row r <-> its inner twin)
        half = R // 2 + 1
        A_ = rows[:half, col]
        B_ = rows[::-1][:half, col]
        strip = np.stack([A_, B_], 1)
        side = nrm(rows[:half, col] - rows[:half, 1 if col == 0 else -2])
        mb.grid(strip, np.stack([side, side], 1))


# ============================================================================================ sleeves, hands, belt, cords
def sleeve(mb, cfg, arm, level):
    k, sd = cfg["H"] / 14.0, cfg["seed"]
    ns, nphi = RES["sleeve"][level]
    C, s, L, ks = spline(np.array(arm["path"], float) * k, ns)
    r0 = np.interp(s, ks, np.array(arm["r"]) * k)
    sag = np.interp(s, ks, arm["sag"])
    T, D, S = frames(C, arm["ref"])
    phis = 2 * PI * np.arange(nphi) / nphi
    PH, SS = np.meshgrid(phis, s)
    R = r0[:, None] * (1 + sag[:, None] * np.maximum(np.cos(PH), 0) ** 2) * (1 + 0.06 * sst(0.93, 1.0, SS))
    R = R * (1 + 0.05 * sst(0.94, 1.0, SS) * np.sin(3 * PH + sd))
    w = 7 * PH / (2 * PI) + 0.35 * vnoise(np.stack([SS * 3, np.cos(PH), np.sin(PH)], -1), sd + 51)
    disp = 0.09 * k * sst(0.25, 1.0, SS) * (0.25 + 1.0 * np.maximum(np.cos(PH), 0)) * prof(w) * rnd_fold(w, 7, sd + 52)
    if level == "hi":
        kap = np.gradient(T, axis=0) / (L / ns)
        phin = np.arctan2((kap * S).sum(-1), (kap * D).sum(-1))
        curv = np.linalg.norm(kap, axis=-1)
        el = s[int(np.argmax(curv * sst(0.2, 0.35, s) * sst(0.85, 0.7, s)))]
        ring = 0.05 * k * np.exp(-((SS - el) / 0.07) ** 2) * np.maximum(np.cos(PH - phin[:, None]), 0) * prof(SS * L / (0.2 * k))
        disp = disp + ring + 0.004 * k * fbm(C[:, None, :] * 3 + PH[..., None] * 0.3, 3, sd + 53)
    R = R + disp
    P = tube_pts(C, D, S, R, phis)
    P = P + T[:, None, :] * (arm.get("tail", 0.3) * k * sst(0.85, 1.0, SS) * np.maximum(np.cos(PH), 0) ** 2)[..., None]
    N = nrm(P - C[:, None, :])
    i0 = int(ns * 0.75)
    rows, nref, void = shell_rows(P, N, 0.07 * k, i0, RES["lip"][level], lip=0.02 * k, void_inner=sst(0.99, 0.85, s[i0:]))
    mb.grid(rows, nref, closed_u=True, cap1=True, void=void)


def tube_part(mb, path, radii, level, key, ref=(0, 0, 1), closed=False, caps=(True, True), groove=None, mat=0, ell=1.0, void=0.0, n=None):
    ns, nphi = RES[key][level] if n is None else n
    C, s, L, ks = spline(path, ns)
    r = np.interp(s, np.linspace(0, 1, len(radii)), radii) if np.ndim(radii) else np.full(ns, radii)
    T, D, S = frames(C, ref)
    phis = 2 * PI * np.arange(nphi) / nphi
    PH, SS = np.meshgrid(phis, s)
    R = np.repeat(r[:, None], nphi, 1)
    if groove is not None and level == "hi":
        R = R * (1 - groove[0] * prof(groove[1] * PH / (2 * PI) + SS * L / groove[2]))
    P = C[:, None, :] + R[..., None] * (D[:, None, :] * np.cos(PH)[..., None] + ell * S[:, None, :] * np.sin(PH)[..., None])
    mb.grid(P, P - C[:, None, :], closed_u=True, cap0=caps[0], cap1=caps[1], mat=mat, void=void)
    return C


def round_end(r, n, frac=0.12, start=True, end=True):
    s = np.linspace(0, 1, n)
    f = np.ones(n)
    if end:
        f *= np.sqrt(np.clip(1 - (np.clip(s - (1 - frac), 0, None) / frac) ** 2, 0.0, 1))
    if start:
        f *= np.sqrt(np.clip(1 - (np.clip(frac - s, 0, None) / frac) ** 2, 0.0, 1))
    return np.interp(s, np.linspace(0, 1, len(r)), r) * f if np.ndim(r) else r * f


def superq(mb, center, ax_x, ax_y, ax_z, size, e=0.35, res=(16, 24), bend=None, mat=0):
    """Superellipsoid; bend=(c, A, Bk, Fw, rg) maps local (x->angle, y->axial, z->radial) around a grip cylinder."""
    n1, n2 = res
    t1 = np.linspace(-PI / 2, PI / 2, n1)
    t2 = 2 * PI * np.arange(n2) / n2
    T2, T1 = np.meshgrid(t2, t1)
    sp = lambda v, ex: np.sign(v) * np.abs(v) ** ex  # noqa: E731
    x = sp(np.cos(T1), e) * sp(np.cos(T2), e) * size[0]
    y = sp(np.cos(T1), e) * sp(np.sin(T2), e) * size[1]
    z = sp(np.sin(T1), e) * size[2]
    if bend is None:
        P = np.asarray(center) + x[..., None] * ax_x + y[..., None] * ax_y + z[..., None] * ax_z
        ref = P - np.asarray(center)
    else:
        c, A, Bk, Fw, psi0, rho0 = bend
        psi = psi0 + x
        rho = rho0 + z
        P = c + A * y[..., None] + (Bk * np.cos(psi)[..., None] + Fw * np.sin(psi)[..., None]) * rho[..., None]
        cen = c + (Bk * math.cos(psi0) + Fw * math.sin(psi0)) * rho0
        ref = P - cen
    mb.grid(P, ref, closed_u=True, cap0=True, cap1=True, mat=mat)


def grip_hand(mb, hand, F, k, level):
    c = np.asarray(hand["c"], float) * k
    A = nrm(np.asarray(hand["axis_v"], float))
    Bk = np.asarray(hand["back"], float)
    Bk = nrm(Bk - Bk.dot(A) * A)
    Fw = F - F.dot(A) * A - F.dot(Bk) * Bk
    Fw = nrm(Fw)
    rg = hand["rg"] * k
    sc = k
    fw, fr = 0.165 * sc, 0.074 * sc
    dirp = lambda psi: Bk * np.cos(psi) + Fw * np.sin(psi)  # noqa: E731
    psic, psiw = 0.2, 1.05
    rhoc = rg + 0.125 * sc
    pr = RES["palm"][level]
    superq(mb, None, None, None, None, (psiw, 2.15 * fw, 0.13 * sc), e=0.4, res=pr, bend=(c, A, Bk, Fw, psic, rhoc))
    fres = RES["finger"][level]
    for i, (h, Ls) in enumerate(zip((1.5, 0.5, -0.5, -1.5), (1.0, 1.07, 1.0, 0.82))):
        pk = psic + psiw * 0.9
        rho_f = rg + fr * 1.02
        js = [pk, pk + 1.2 * Ls, pk + 2.1 * Ls, pk + 2.85 * Ls]
        hh = h * fw - 0.02 * sc * np.arange(5)
        pts = [c + A * hh[0] + dirp(pk - 0.35) * (rhoc - 0.02 * sc), c + A * hh[1] + dirp(js[0]) * (rho_f + 0.02 * sc)]
        pts += [c + A * hh[j + 2] + dirp(js[j + 1]) * rho_f for j in range(3)]
        n = fres[0] * 3
        rad = np.array([1.05, 1.22, 0.98, 1.14, 0.94, 1.08, 0.9, 0.84]) * fr * (0.92 if i == 3 else 1.0)
        rad = round_end(rad, n, 0.1, start=False)
        tube_part(mb, np.array(pts), rad, level, "finger", ref=A, n=(n, fres[1]), caps=(True, True))
    th = [c + A * 1.25 * fw + dirp(psic - psiw * 0.6) * (rhoc - 0.01 * sc), c + A * 2.0 * fw + dirp(-1.0) * (rg + 0.17 * sc),
          c + A * 1.95 * fw + dirp(-1.65) * (rg + fr * 2.0), c + A * 1.6 * fw + dirp(-2.15) * (rg + fr * 2.05)]
    n = fres[0] * 3
    tube_part(mb, np.array(th), round_end(np.array([1.25, 1.15, 1.08, 1.0, 0.9]) * 0.085 * sc, n, 0.12, start=False), level, "finger",
              ref=A, n=(n, fres[1]))
    superq(mb, c + A * 0.9 * fw + dirp(-0.45) * (rhoc + 0.02 * sc), A, nrm(np.cross(A, dirp(-0.45))), dirp(-0.45),
           (0.2 * sc, 0.13 * sc, 0.1 * sc), e=1.0, res=(fres[1], fres[1] * 2))
    pc = c + dirp(psic - 0.25) * (rhoc + 0.03 * sc)
    tube_part(mb, np.array([pc, pc - F * 0.45 * sc, pc - F * hand.get("forearm", 0.75) * sc]), np.array([0.15, 0.17, 0.19]) * sc, level, "finger",
              ref=A, n=(fres[0], fres[1] * 2), caps=(True, True))


def belt_and_cords(mb, cfg, robe, level):
    k, sd = cfg["H"] / 14.0, cfg["seed"]
    vb = robe.c["belt"]
    ns, nphi = RES["belt"][level]
    th = 2 * PI * np.arange(ns) / ns
    P, N, _ = robe.eval(th, np.full(ns, vb))
    rr = 0.1 * k
    C = P + N * (rr * 0.85)
    T = nrm(np.roll(C, -1, 0) - np.roll(C, 1, 0))
    D = nrm(np.array([0, 0, 1.0]) - (T @ np.array([0, 0, 1.0]))[:, None] * T)
    S = np.cross(T, D)
    phis = 2 * PI * np.arange(nphi) / nphi
    PH, TH = np.meshgrid(phis, th)
    R = np.full(PH.shape, rr)
    if level == "hi":
        Lb = np.linalg.norm(np.diff(np.vstack([C, C[:1]]), axis=0), axis=1).sum()
        R = R * (1 - 0.22 * prof(2 * PH / (2 * PI) + TH / (2 * PI) * Lb / (0.3 * k)))
    Pb = tube_pts(C, D, S, R, phis)
    mb.grid(Pb, Pb - C[:, None, :], closed_u=True, closed_v=True)
    if not cfg.get("cords"):
        return
    thk = PI - cfg["knee"] * 0.5
    Pk, Nk, _ = robe.eval(np.array([thk]), np.array([vb]))
    kc = Pk[0] + Nk[0] * rr * 1.6
    Tk = nrm(np.array([np.cos(thk), -np.sin(thk), 0.0]))
    superq(mb, kc, Tk, np.array([0, 0, 1.0]), Nk[0], (0.17 * k, 0.15 * k, 0.11 * k), e=0.8, res=RES["finger"][level][::-1])
    for j, (dth, t_end) in enumerate(((0.0, 0.27), (0.13 * cfg["knee"], 0.33))):
        nz = RES["cord"][level][0]
        tt = np.linspace(vb - 0.006, t_end, nz)
        thc = thk + dth + 0.03 * np.sin(tt * 9 + j)
        best = None
        for o in np.linspace(-0.06, 0.06, 5):
            Pc, Nc, dc = robe.eval(thc + o, tt)
            best = dc if best is None else np.maximum(best, dc)
        Pc, Nc, dc = robe.eval(thc, tt)
        cr = 0.055 * k
        path = Pc + Nc * (best - dc + cr * 1.3)[:, None]
        path[0] = kc + Nk[0] * 0.02
        tube_part(mb, path, cr, level, "cord", ref=Nc[0], groove=(0.2, 2, 0.14 * k), caps=(True, False))
        end, dn = path[-1], nrm(path[-1] - path[-2])
        superq(mb, end + dn * 0.04 * k, Tk, dn, Nc[-1], (0.1 * k, 0.1 * k, 0.09 * k), e=0.9, res=RES["finger"][level][::-1])
        tp = np.array([end + dn * 0.08 * k, end + dn * 0.28 * k, end + dn * 0.48 * k])
        tube_part(mb, tp, np.array([0.06, 0.1, 0.12]) * k, level, "cord", ref=Nc[-1], groove=(0.35, 10, 10.0 * k), caps=(True, True))


# ============================================================================================ staff, sword
def lathe(mb, center, axis, prof_rz, nphi, mat=0, caps=(True, True)):
    A = nrm(np.asarray(axis, float))
    X = nrm(np.cross(A, [0, 1.0, 0]) if abs(A[1]) < 0.9 else np.cross(A, [1.0, 0, 0]))
    Y = np.cross(A, X)
    pr = np.asarray(prof_rz, float)
    phis = 2 * PI * np.arange(nphi) / nphi
    PH = np.broadcast_to(phis, (len(pr), nphi))
    ax = np.asarray(center, float) + pr[:, 1][:, None, None] * A
    P = ax + pr[:, 0][:, None, None] * (X * np.cos(PH)[..., None] + Y * np.sin(PH)[..., None])
    mb.grid(P, P - ax, closed_u=True, cap0=caps[0], cap1=caps[1], mat=mat)


def staff(mb, cfg, level):
    st, k = cfg["staff"], cfg["H"] / 14.0
    x, y, top, r = st["x"] * k, st["y"] * k, st["top"] * k, st["r"] * k
    ns, nphi = RES["staff"][level]
    zs = top - 1.15 * k
    z = np.linspace(0, zs, ns)
    rad = r * (1.08 - 0.12 * z / zs)
    for zc, amp, wd in ((0.12 * k, 0.05, 0.12), (7.6 * k, 0.035, 0.05), (13.0 * k, 0.035, 0.05), (zs - 0.1 * k, 0.04, 0.06)):
        rad = rad + amp * k * sst(wd * k * 1.6, wd * k * 0.6, np.abs(z - zc))
    if level == "hi":
        rad = rad * (1 + 0.012 * fbm(np.stack([z * 4, z * 0 + x, z * 0], -1), 3, cfg["seed"] + 60))
    lathe(mb, (x, y, 0.0), (0, 0, 1), np.stack([rad, z], 1), nphi)
    hr = RES["head"][level]
    sock = np.array([(0.12, 0), (0.16, 0.06), (0.16, 0.16), (0.12, 0.22), (0.12, 0.42), (0.17, 0.48), (0.17, 0.56), (0.09, 0.62)]) * [k, k]
    lathe(mb, (x, y, zs - 0.02 * k), (0, 0, 1), sock, hr[1] * 2, mat=1)
    zc = zs + 0.6 * k
    Rc = 0.62 * k
    ph = np.linspace(-1.3, 1.3, hr[0])
    cpath = np.stack([x + Rc * np.sin(ph), np.full_like(ph, y), zc + Rc - Rc * np.cos(ph)], 1)
    cr = 0.11 * k * np.cos(ph / 1.3 * PI / 2) ** 0.7 + 0.012 * k
    tube_part(mb, cpath, cr, level, "head", ref=(0, 0, 1), ell=0.45, mat=2)
    ring_c = np.array([x, y, zc + 0.62 * k])
    rp = np.linspace(0, 2 * PI, hr[0] + 1)[:-1]
    rpath = ring_c + 0.38 * k * np.stack([np.sin(rp), np.zeros_like(rp), np.cos(rp)], 1)
    Rn = 0.055 * k
    nphi2 = hr[1]
    T = nrm(np.roll(rpath, -1, 0) - np.roll(rpath, 1, 0))
    D = nrm(rpath - ring_c)
    S = np.cross(T, D)
    phis = 2 * PI * np.arange(nphi2) / nphi2
    P = tube_pts(rpath, D, S, np.full((len(rp), nphi2), Rn), phis)
    mb.grid(P, P - rpath[:, None, :], closed_u=True, closed_v=True, mat=1)
    lathe(mb, (x, y, zc + 0.98 * k), (0, 0, 1), np.array([(0.07, 0), (0.05, 0.2), (0.002, 0.55)]) * k, nphi2, mat=1)


def sword(mb, cfg, level):
    sw, k = cfg["sword"], cfg["H"] / 14.0
    tip, top = np.array(sw["tip"]) * k, np.array(sw["top"]) * k
    A = nrm(top - tip)
    X = np.array([1.0, 0, 0])
    Fv = nrm(np.cross(A, X))
    zg = sw["guard"] * k
    sg = (zg - tip[2]) / A[2]
    nl, nq = RES["blade"][level]
    s = np.linspace(0, sg, nl)
    wmax, th0 = 0.3 * k, 0.07 * k
    w = wmax * np.minimum(1, s / (0.2 * sg)) ** 0.8 * (1 - 0.12 * sst(0.9 * sg, sg, s))
    q = np.concatenate([np.linspace(-1, 1, nq // 2 + 1), np.linspace(1, -1, nq // 2 + 1)[1:-1]])
    side = np.concatenate([np.ones(nq // 2 + 1), -np.ones(nq - nq // 2 - 1)])
    Q, S_ = np.meshgrid(q, s)
    SD = np.broadcast_to(side, Q.shape)
    thk = th0 * (1 - np.abs(Q)) ** 0.9 * np.minimum(1, S_ / (0.1 * sg)) ** 0.5
    if level == "hi":
        thk = thk - 0.35 * th0 * np.exp(-(Q / 0.12) ** 2) * sst(0.22 * sg, 0.3 * sg, S_) * sst(0.95 * sg, 0.88 * sg, S_)
    C = tip + S_[..., None] * A
    P = C + (Q * w[:, None])[..., None] * X + (SD * thk)[..., None] * Fv
    mb.grid(P, P - C, closed_u=True, cap1=True)
    gc = tip + sg * A
    gx = np.linspace(-1, 1, 9)
    gpath = gc + gx[:, None] * 1.25 * k * X - (gx[:, None] ** 2) * 0.18 * k * A
    tube_part(mb, gpath, round_end(np.array([0.13, 0.09, 0.085, 0.09, 0.11, 0.09, 0.085, 0.09, 0.13]) * k, 60, 0.06), level, "head",
              ref=A, n=(60 if level == "hi" else 24, RES["head"][level][1]))
    g0, g1 = sw["grip"]
    sg0, sg1 = (g0 * k - tip[2]) / A[2], (g1 * k - tip[2]) / A[2]
    gp = np.array([tip + sg0 * A, tip + sg1 * A])
    tube_part(mb, gp, 0.115 * k, level, "head", ref=X, groove=(0.12, 1, 0.12 * k), n=(120 if level == "hi" else 16, RES["head"][level][1]))
    pc = tip + (sg1 + 0.2 * k) * A
    superq(mb, pc, X, A, Fv, (0.3 * k, 0.3 * k, 0.13 * k), e=0.75, res=(RES["head"][level][1], RES["head"][level][1] * 2))


# ============================================================================================ plinths
def square_lathe(mb, prof, rc=0.03, nc=3, mat=0):
    rows = []
    for d, z in prof:
        pts = []
        for cx, cy, a0 in ((1, 1, 0), (-1, 1, PI / 2), (-1, -1, PI), (1, -1, 1.5 * PI)):
            for a in np.linspace(a0, a0 + PI / 2, nc):
                pts.append((cx * (d - rc) + rc * math.cos(a), cy * (d - rc) + rc * math.sin(a), z))
        rows.append(pts)
    P = np.array(rows)
    mb.grid(P, P * [1.0, 1.0, 0.0], closed_u=True, cap0=True, cap1=True, mat=mat)


def plinth_low(mb, level):
    prof = [(2.42, 0.0), (2.42, 0.12), (2.5, 0.2), (2.5, 1.45), (2.56, 1.52), (2.56, 1.7), (2.5, 1.78), (2.38, 1.86), (2.3, 2.0)]
    square_lathe(mb, prof, 0.04, 4 if level == "hi" else 3)


def torus(mb, c, X, Y, R, r, n=(40, 10)):
    a = 2 * PI * np.arange(n[0]) / n[0]
    path = c + R * (np.cos(a)[:, None] * X + np.sin(a)[:, None] * Y)
    T = nrm(np.roll(path, -1, 0) - np.roll(path, 1, 0))
    D = nrm(path - c)
    S = np.cross(T, D)
    phis = 2 * PI * np.arange(n[1]) / n[1]
    P = tube_pts(path, D, S, np.full((n[0], n[1]), r), phis)
    mb.grid(P, P - path[:, None, :], closed_u=True, closed_v=True)


def pedestal(mb, level):
    prof = [(3.0, 0), (3.0, 0.45), (2.9, 0.5), (2.9, 0.55), (2.78, 0.6), (2.78, 0.95), (2.64, 1.0), (2.68, 1.06), (2.68, 1.14), (2.6, 1.2),
            (2.44, 1.25), (2.4, 1.3), (2.4, 5.5), (2.46, 5.55), (2.46, 5.62), (2.4, 5.66), (2.44, 5.72), (2.6, 5.9), (2.8, 6.15),
            (2.95, 6.25), (2.95, 6.62), (2.88, 6.68), (2.78, 6.72), (2.72, 6.85), (2.68, 7.0)]
    square_lathe(mb, prof, 0.04, 4 if level == "hi" else 3)
    tr = (40, 10) if level == "hi" else (24, 6)
    for q in range(4):
        a = q * PI / 2
        nf = np.array([math.cos(a), math.sin(a), 0.0])
        ax = np.array([-math.sin(a), math.cos(a), 0.0])
        up = np.array([0, 0, 1.0])
        o = nf * 2.4
        pts = []
        zs_, tha = 3.4, math.acos(0.55 / 2.0)  # lancet: springing 3.4, radius 2.0, centres +-0.55 -> apex 5.32
        pts = [(-1.45, 1.75), (1.45, 1.75), (1.45, zs_)]
        pts += [(-0.55 + 2.0 * math.cos(th), zs_ + 2.0 * math.sin(th)) for th in np.linspace(0, tha, 14)[1:]]
        pts += [(0.55 - 2.0 * math.cos(th), zs_ + 2.0 * math.sin(th)) for th in np.linspace(tha, 0, 14)[1:]]
        pts = np.array(pts)
        dense = []
        for i in range(len(pts)):
            p0, p1 = pts[i], pts[(i + 1) % len(pts)]
            m = max(2, int(np.linalg.norm(p1 - p0) / 0.08))
            for t in np.linspace(0, 1, m, endpoint=False):
                dense.append(p0 + (p1 - p0) * t)
        dense = np.array(dense)
        path = o + dense[:, 0:1] * ax + dense[:, 1:2] * up + nf * 0.05
        T = nrm(np.roll(path, -1, 0) - np.roll(path, 1, 0))
        S = np.cross(T, nf)
        nphi = 8 if level == "hi" else 6
        phis = 2 * PI * np.arange(nphi) / nphi + PI / nphi
        sp = lambda v: np.sign(v) * np.abs(v) ** 0.5  # noqa: E731
        P = path[:, None, :] + 0.1 * (nf[None, None] * sp(np.cos(phis))[None, :, None] + S[:, None, :] * sp(np.sin(phis))[None, :, None])
        mb.grid(P, P - path[:, None, :], closed_u=True, closed_v=True)
        cz = 3.3
        cc = o + up * cz + nf * 0.04
        torus(mb, cc, ax, up, 0.85, 0.07, tr)
        for dx, dz in ((0.36, 0), (-0.36, 0), (0, 0.36), (0, -0.36)):
            torus(mb, cc + ax * dx + up * dz, ax, up, 0.36, 0.06, tr)
        superq(mb, cc + nf * 0.05, ax, up, nf, (0.18, 0.18, 0.1), e=0.9, res=(10, 20) if level == "hi" else (6, 10))
    for sx, sy in ((1, 1), (-1, 1), (-1, -1), (1, -1)):
        lathe(mb, (sx * 2.4, sy * 2.4, 0.0), (0, 0, 1),
              [(0.24, 1.3), (0.24, 1.38), (0.2, 1.45), (0.17, 1.5), (0.16, 1.55), (0.16, 5.25), (0.2, 5.33), (0.24, 5.42), (0.24, 5.5)],
              24 if level == "hi" else 12)


# ============================================================================================ build one statue
def build(name, level):
    cfg = CFG[name]
    k = cfg["H"] / 14.0
    robe = Robe(cfg, level)
    roles = {r: MB() for r in ("Robe", "Hood", "Arms", "Plinth")}
    robe.grid(roles["Robe"], RES["robe"][level])
    belt_and_cords(roles["Robe"], cfg, robe, level)
    hood(roles["Hood"], cfg, level)
    if cfg["capelet"]:
        capelet(roles["Hood"], cfg, robe, level)
    if cfg["cloak"]:
        cloak(roles["Hood"], cfg, robe, level)
    for arm in cfg["arms"]:
        sleeve(roles["Arms"], cfg, arm, level)
        if arm["hand"]:
            h = dict(arm["hand"])
            if h["axis"] == "sword":
                sw = cfg["sword"]
                h["axis_v"] = nrm(np.array(sw["top"]) - np.array(sw["tip"]))
            else:
                h["axis_v"] = h["axis"]
            p = np.array(arm["path"], float) * k
            F = nrm(np.asarray(h["c"]) * k - p[-2])
            grip_hand(roles["Arms"], h, F, k, level)
    if cfg["staff"]:
        roles["Staff"] = MB()
        staff(roles["Staff"], cfg, level)
    if cfg["sword"]:
        roles["Sword"] = MB()
        sword(roles["Sword"], cfg, level)
    if cfg["plinth"] == "low":
        plinth_low(roles["Plinth"], level)
    else:
        pedestal(roles["Plinth"], level)
    M = Mrot_z(cfg["yaw"], cfg["z0"])
    objs = {}
    for r, mb in roles.items():
        nm = f"{name}__{r}" if level == "lo" else f"HI_{name}__{r}"
        objs[r] = mb.build(nm, None if r == "Plinth" else M)
    return objs


# ============================================================================================ weathering (high)
def weather(obj, chip=0.04, erode=0.008, freq=1.6, seed=0, edge_pct=(75, 98)):
    me = obj.data
    n = len(me.vertices)
    co = np.zeros(n * 3, np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3).astype(np.float64)
    nr = np.zeros(n * 3, np.float32)
    try:
        me.vertex_normals.foreach_get("vector", nr)
    except AttributeError:
        me.vertices.foreach_get("normal", nr)
    nr = nr.reshape(-1, 3).astype(np.float64)
    e = np.zeros(len(me.edges) * 2, np.int32)
    me.edges.foreach_get("vertices", e)
    e = e.reshape(-1, 2)
    deg = np.bincount(e.ravel(), minlength=n).astype(np.float64)
    s = np.stack([np.bincount(e[:, 0], co[e[:, 1], i], n) + np.bincount(e[:, 1], co[e[:, 0], i], n) for i in range(3)], 1)
    lap = s / np.maximum(deg, 1)[:, None] - co
    el = np.linalg.norm(co[e[:, 0]] - co[e[:, 1]], axis=1).mean()
    conv = -(lap * nr).sum(1) / el
    lo, hi = np.percentile(conv, edge_pct)
    edge = sst(lo, hi, conv)
    chips = sst(0.42, 0.5, fbm(co * freq, 3, seed) * 0.5 + 0.5) * edge
    pits = fbm(co * 6.0, 3, seed + 7)
    d = -chip * chips - erode * (0.5 + 0.5 * pits)
    co += nr * d[:, None]
    me.vertices.foreach_set("co", co.astype(np.float32).ravel())
    me.update()


def remesh_hi(obj, voxel):
    m = obj.modifiers.new("rm", "REMESH")
    m.mode, m.voxel_size, m.use_smooth_shade = "VOXEL", voxel, True
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.view_layer.objects:
        o.select_set(o is obj)
    bpy.ops.object.modifier_apply(modifier=m.name)


def weighted_normals(obj):
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.view_layer.objects:
        o.select_set(o is obj)
    m = obj.modifiers.new("wn", "WEIGHTED_NORMAL")
    m.keep_sharp = True
    bpy.ops.object.modifier_apply(modifier=m.name)


# ============================================================================================ render
def clay():
    m = bpy.data.materials.new("Clay")
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    p.inputs["Base Color"].default_value = (0.05, 0.05, 0.055, 1)
    p.inputs["Roughness"].default_value = 0.75
    return m


def bbox(objs):
    from mathutils import Vector
    pts = np.array([tuple(o.matrix_world @ Vector(c)) for o in objs for c in o.bound_box])
    return pts.min(0), pts.max(0)


def setup_scene(samples=64):
    import vesp_bake as VB
    sc = VB.cycles(samples)
    sc.cycles.use_denoising = True
    try:
        sc.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        pass
    sc.view_settings.exposure = float(os.environ.get("VESP_EXPOSURE", 1.0))
    w = sc.world
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.055, 0.06, 0.07, 1)
    bg.inputs["Strength"].default_value = 1.0
    for nm, e, ang, rot, col in (("overcast", 1.4, 50.0, (math.radians(35), 0, math.radians(-25)), (0.78, 0.84, 0.95)),
                                 ("rim", 4.5, 3.0, (math.radians(70), 0, math.radians(150)), (1.0, 0.62, 0.34))):
        L = bpy.data.objects.new(nm, bpy.data.lights.new(nm, "SUN"))
        L.data.energy, L.data.color, L.rotation_euler = e, col, rot
        L.data.angle = math.radians(ang)
        sc.collection.objects.link(L)
    gm = bpy.data.materials.new("Ground")
    gm.use_nodes = True
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.02, 0.021, 0.023, 1)
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Roughness"].default_value = 1.0
    mb = MB()
    mb.grid(np.array([[[-80, -80, 0], [80, -80, 0]], [[-80, 80, 0], [80, 80, 0]]], float), np.array([0, 0, 1.0]))
    g = mb.build("Ground", smooth=False)
    g.data.materials.append(gm)
    mm = bpy.data.materials.new("Mannequin")
    mm.use_nodes = True
    next(n for n in mm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.32, 0.32, 0.32, 1)
    mbm = MB()
    lathe(mbm, (0, 0, 0), (0, 0, 1), [(0.55, 0.0), (0.55, 3.9)], 32)
    superq(mbm, np.array([0, 0, 4.45]), np.array([1.0, 0, 0]), np.array([0, 1.0, 0]), np.array([0, 0, 1.0]), (0.55, 0.55, 0.55), e=1.0,
           res=(16, 32))
    man = mbm.build("Mannequin_5stud")
    man.data.materials.append(mm)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 50
    cam.data.sensor_fit = "VERTICAL"
    sc.collection.objects.link(cam)
    sc.camera = cam
    return sc, cam, man


def look_at(cam, eye, target):
    from mathutils import Vector
    cam.location = Vector(eye)
    cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()


def render_views(name, objs, out_dir, tag, focus):
    """focus: (z_lo, z_hi, xy) world box for the close-up (hood + hands)."""
    sc, cam, man = setup_scene(int(os.environ.get("VESP_RENDER_SAMPLES", 64)))
    lo, hi = bbox(objs)
    ctr = (lo + hi) / 2
    hgt = hi[2]
    out = []
    for view, az, res in (("q34", -28.0, (1000, 1400)), ("side", 90.0, (1000, 1400)), ("close", -18.0, (1000, 1000))):
        sc.render.resolution_x, sc.render.resolution_y = res
        a = math.radians(az)
        dirv = np.array([math.sin(a), -math.cos(a), 0.0])
        right = np.array([math.cos(a), math.sin(a), 0.0])
        if view == "close":
            zl, zh = focus
            half = (zh - zl) / 2 * 1.15
            tgt = np.array([ctr[0], ctr[1] - 0.6, (zl + zh) / 2])
        else:
            half = hgt / 2 * 1.08
            tgt = np.array([ctr[0], ctr[1], hgt / 2])
        dist = half / math.tan(cam.data.angle_y / 2) + 2.0
        eye = tgt + dirv * dist
        if view == "close":
            eye[2] -= 0.18 * dist  # slightly below, like a player looking up into the hood
        look_at(cam, eye, tgt)
        mpos = ctr + right * (max(hi[0] - lo[0], hi[1] - lo[1]) / 2 + 1.6)
        man.location = (mpos[0], mpos[1], 0.0)
        man.hide_render = view == "close"
        f = Path(out_dir) / f"{name}_{tag}_{view}.png"
        sc.render.filepath = str(f)
        sc.render.image_settings.file_format = "PNG"
        bpy.ops.render.render(write_still=True)
        out.append(f)
        log(f"render {f.name}")
    return out


# ============================================================================================ main
def statue(name, out, mode):
    import vesp_bake as VB
    bpy.ops.wm.read_factory_settings(use_empty=True)
    t = time.time()
    lows = build(name, "lo")
    log(f"{name}: low built " + " ".join(f"{r}={VB.tris(o)}" for r, o in lows.items()) + f"  {time.time() - t:.1f}s")
    t = time.time()
    highs = build(name, "hi")
    log(f"{name}: high built " + " ".join(f"{r}={VB.tris(o)}" for r, o in highs.items()) + f"  {time.time() - t:.1f}s")
    HIGH_TRIS[name] = {}
    t = time.time()
    remesh_hi(highs["Plinth"], 0.03)
    for r, o in highs.items():
        if r == "Plinth":
            weather(o, chip=0.06, erode=0.004, freq=1.4, seed=CFG[name]["seed"], edge_pct=(88, 99.5))
        elif r in ("Staff", "Sword"):
            weather(o, chip=0.015, erode=0.004, freq=3.0, seed=CFG[name]["seed"] + 1, edge_pct=(85, 99))
        else:
            weather(o, chip=0.02, erode=0.004, freq=2.2, seed=CFG[name]["seed"] + 2, edge_pct=(88, 99.5))
    HIGH_TRIS[name] = {r: VB.tris(o) for r, o in highs.items()}
    log(f"{name}: weathered highs {time.time() - t:.1f}s; high total {sum(VB.tris(o) for o in highs.values())} tris")
    rdir = out / "renders"
    rdir.mkdir(parents=True, exist_ok=True)
    cfg = CFG[name]
    k = cfg["H"] / 14.0
    focus = (cfg["z0"] + 6.6 * k, cfg["z0"] + 14.6 * k)
    if mode == "clay":
        cm = clay()
        for o in highs.values():
            o.data.materials.append(cm)
        for o in lows.values():
            o.hide_render = True
        return render_views(name, list(highs.values()), rdir, "clayhi", focus), None
    maps = out / "maps"
    src_stone = VB.stone_source("Vesp_Weathered", maps)
    stone = VB.hi_material("Hi_Stone", src_stone, tile=4.0)
    iron = VB.hi_material("Hi_Iron", VB.stone_source("Vesp_Iron", maps), tile=1.2, metal=0.85, rough=0.5)
    verd = VB.hi_material("Hi_Verdigris", VB.stone_source("Vesp_Verdigris", maps), tile=1.2, metal=0.25, rough=0.6)
    for r, o in highs.items():
        o.data.materials.append(stone)
        if r == "Staff":
            o.data.materials.append(iron)
            o.data.materials.append(verd)
    for r, o in lows.items():
        weighted_normals(o)
        VB.unwrap(o)
    look = VB.Look(frost=0.45, base=0.13)
    rays = {"Robe": (0.08, 0.2), "Hood": (0.05, 0.14), "Arms": (0.045, 0.12), "Plinth": (0.1, 0.25), "Staff": (0.04, 0.1), "Sword": (0.04, 0.1)}
    metal_look = VB.Look(frost=0.2, base=0.1, grime=0.45, edge=1.3, streak_dark=0.3)
    looks = {"*": look, "Staff": metal_look, "Sword": metal_look}
    res = VB.bake(name, {r: (lows[r], [highs[r]]) for r in lows}, maps, size=2048, look=looks, log=log, rays=rays)
    for o in list(highs.values()):
        bpy.data.meshes.remove(o.data)
    subs, maps_rec = {}, {}
    objs = []
    for r, o in lows.items():
        for so in VB.split_cap(o, 17500):
            subs[so.name] = VB.tris(so)
            objs.append(so)
        maps_rec[r] = res[r]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    glb = out / f"{name}.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_apply=False, export_image_format="NONE")
    lo, hi = bbox(objs)
    entry = {"group": "F", "sub_meshes": subs, "tris_total": sum(subs.values()),
             "size_studs_xyz": [round(float(hi[i] - lo[i]), 1) for i in range(3)],
             "bbox_min": [round(float(c), 2) for c in lo], "bbox_max": [round(float(c), 2) for c in hi],
             "materials": sorted({m.name for o in objs for m in o.data.materials}), "file": glb.name,
             "builder": "tools/blender/vesperhold/vesperhold_figures.py (mac-51, hand-modelled, Cycles-baked)",
             "no_decimation": True, "map_resolution": res[next(iter(res))]["size"],
             "maps": {r: v["maps"] for r, v in maps_rec.items()},
             "base_layer": src_stone["source"],
             "high_poly_tris": {r: n for r, n in HIGH_TRIS.get(name, {}).items()}}
    log(f"{name}: exported {glb.name} {glb.stat().st_size / 1e6:.1f} MB; subs {subs}")
    files = render_views(name, objs, rdir, "baked", focus)
    return files, entry


HIGH_TRIS = {}


def merge_manifest(out, entries):
    mf = out / "manifest.json"
    m = json.loads(mf.read_text()) if mf.exists() else {"kit": "Vesperhold props (group F)", "pieces": {}}
    for n, e in entries.items():
        m["pieces"][n] = e
    mf.write_text(json.dumps(m, indent=2))
    log("manifest merged:", list(entries))


def sheet(files_by_piece, dst):
    """Compose with the system python (PIL); Blender's python has none."""
    code = r'''
import sys, json
from PIL import Image, ImageDraw
rows = json.loads(sys.argv[1]); dst = sys.argv[2]
ims = [[Image.open(f).convert("RGB") for f in r] for r in rows]
H = 700
rr = []
for r in ims:
    sc = [im.resize((int(im.width * H / im.height), H), Image.LANCZOS) for im in r]
    w = sum(i.width for i in sc) + 8 * (len(sc) - 1)
    row = Image.new("RGB", (w, H), (14, 14, 16)); x = 0
    for i in sc:
        row.paste(i, (x, 0)); x += i.width + 8
    rr.append(row)
W = max(r.width for r in rr)
out = Image.new("RGB", (W, sum(r.height for r in rr) + 8 * (len(rr) - 1)), (14, 14, 16)); y = 0
for r in rr:
    out.paste(r, (0, y)); y += r.height + 8
out.save(dst, quality=90)
'''
    subprocess.run(["/usr/bin/env", "python3", "-c", code, json.dumps([[str(f) for f in fs] for fs in files_by_piece]), str(dst)], check=True)


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(a[0] if a else ROOT / "assets/source/vesperhold/props").resolve()
    only = [s for s in os.environ.get("VESP_ONLY", "").split(",") if s] or list(PIECES)
    mode = os.environ.get("VESP_FIG_MODE", "bake")
    renders, entries = [], {}
    tag = "clayhi" if mode == "clay" else "baked"
    for name in PIECES:
        if name not in only:
            old = [out / "renders" / f"{name}_{tag}_{v}.png" for v in ("q34", "side", "close")]
            if all(f.exists() for f in old):  # keep the sheet complete on a VESP_ONLY run
                renders.append(old)
            continue
        files, entry = statue(name, out, mode)
        renders.append(files)
        if entry:
            entries[name] = entry
    if entries:
        merge_manifest(out, entries)
    if renders:
        tag = "clay" if mode == "clay" else "baked"
        dst = out / "renders" / f"F1_statues_v2_{tag}.jpg"
        sheet(renders, dst)
        log("sheet", dst)


def keep_in_props_manifest(K):
    """vesperhold_props.py imports this module and no longer builds the statues: re-seed its manifest with our entries so
    a props run (which rewrites manifest.json from K.manifest) keeps them instead of dropping them."""
    mf = Path(K.OUT) / "manifest.json"
    if mf.exists():
        old = json.loads(mf.read_text()).get("pieces", {})
        for n in PIECES:
            if n in old and old[n].get("builder", "").startswith("tools/blender/vesperhold/vesperhold_figures.py"):
                K.manifest["pieces"].setdefault(n, old[n])


if __name__ == "__main__":
    main()
elif "vesperhold_kit" in sys.modules:  # imported by vesperhold_props.py
    keep_in_props_manifest(sys.modules["vesperhold_kit"])
