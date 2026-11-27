"""Bellwood landmark kit: lotus flowers and lily pads for the Sunken Temple lake (LANDMARK-BUILD-SPEC section 1 "Water",
concept bellwood_3 foreground: dark olive pads with a slit, a few curled and yellowed, pink lotus standing just clear of
the water, petals drifting).

  "C:/Program Files/Blender Foundation/Blender 5.3/blender.exe" -b --python-exit-code 1 -P tools/blender/landmarks/bellwood_lotus.py -- [out_dir]
  default out_dir: assets/source/landmarks/bellwood_lotus      env: LOTUS_PIECES=ClusterA,ClusterB,Drift,Bloom  LOTUS_NORENDER=1

All procedural: geometry is built here and the two 2048 atlases are painted with numpy (no third-party sources).
  Pad    quadrants: fresh lily-pad top | aged top (yellowing, necrotic rim) | maroon underside | lotus leaf (glaucous)
  Bloom  quadrants: inner petal | outer petal and sepal | seed pod disc | stem strip, stamens, spent pod
Every card is real two-sided geometry (no alpha, no DoubleSided reliance); pads have a thin rim so their edges catch light.
Units studs, Z up. Pivot: the water surface at the cluster centre (z = 0). Pads float at z 0.02-0.05, stems end 0.6 below.
Exports <Piece>.glb (no images; vesp_embed embeds the maps by material name), maps/, renders/ and manifest.json.
"""
import json
import math
import os
import random
import sys
import time
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BUILDER = "tools/blender/landmarks/bellwood_lotus.py (win-104, procedural cards + numpy-painted 2048 atlases)"
TAU = 2 * math.pi
Z = Vector((0, 0, 1))
N = 2048
Q = N // 2
QM = 0.03  # quadrant margin, so mips never mix neighbouring quadrants
MAT = {"Pad": "Vesp_Bellwood_Lotus__Pad", "Bloom": "Vesp_Bellwood_Lotus__Bloom"}
TRI_CAP = 17500
T0 = time.time()


def log(*a):
    print(f"[{time.time() - T0:7.1f}s]", *a, flush=True)


def sst(e0, e1, x):
    t = np.clip((np.asarray(x, float) - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def sst1(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


# ============================================================================================ textures
def field(n, beta, seed):
    fu, fv = np.meshgrid(np.fft.fftfreq(n) * n, np.fft.fftfreq(n) * n)
    spec = np.fft.fft2(np.random.default_rng(seed).standard_normal((n, n)))
    out = np.real(np.fft.ifft2(spec / (np.sqrt(fu ** 2 + fv ** 2) + 1.0) ** beta))
    return (out - out.mean()) / out.std()


def qgrid():
    """Quadrant-local coordinates lu, lv in 0..1 (rows = v), matching quv()."""
    p = ((np.arange(Q) + 0.5) / Q - QM) / (1 - 2 * QM)
    lv, lu = np.meshgrid(p, p, indexing="ij")
    return lu, lv


def quv(q, lu, lv):
    return ((q[0] + QM + lu * (1 - 2 * QM)) / 2, (q[1] + QM + lv * (1 - 2 * QM)) / 2)


def mix(a, b, t):
    return a + (np.asarray(b, float) - a) * np.asarray(t)[..., None]


def veins(r, a, n, width, warp):
    """Radial veins from the petiole: Gaussian in arc distance to the nearest of n spokes (warped)."""
    k = (a + warp) * n / TAU
    d = np.abs(k - np.round(k)) * TAU / n * np.maximum(r, 1e-3)
    return np.exp(-(d / width) ** 2)


def pad_top(seed, old):
    lu, lv = qgrid()
    x, y = lu * 2 - 1, lv * 2 - 1
    r, a = np.hypot(x, y), np.arctan2(y, x)
    f1, f2, f3, f4 = field(Q, 1.7, seed), field(Q, 1.0, seed + 1), field(Q, 0.45, seed + 2), field(Q, 1.2, seed + 3)
    warp = 0.06 * f1
    v1 = veins(r, a, 22, 0.011 * (0.35 + 0.65 * r), warp) * sst(0.02, 0.12, r)
    v2 = veins(r, a + TAU / 44, 44, 0.008 * (0.4 + 0.6 * r), warp * 1.3) * sst(0.33, 0.5, r)
    v3 = veins(r, a + TAU / 176, 88, 0.0055, warp * 1.6) * sst(0.6, 0.78, r)
    vs = np.clip(v1 + 0.7 * v2 + 0.45 * v3, 0, 1)
    net = np.exp(-(f3 / 0.3) ** 2)  # fine reticulate mesh between the veins
    col = mix(np.zeros(r.shape + (3,)) + (0.33, 0.42, 0.19), (0.27, 0.36, 0.15), np.clip(r, 0, 1))
    col *= (1 + 0.08 * f2)[..., None]
    col *= (1 - 0.14 * sst(0.5, 1.6, f1))[..., None]  # broad darker mottling
    col = mix(col, (0.46, 0.25, 0.13), 0.5 * sst(2.0, 2.7, f4))  # rust freckles
    col = mix(col, (0.47, 0.54, 0.27), 0.55 * vs)
    col *= (1 - 0.05 * net)[..., None]
    col = mix(col, (0.36, 0.30, 0.14), 0.55 * sst(0.9, 0.99, r))  # browned rim
    h = 0.5 - 0.22 * vs - 0.04 * net + 0.03 * f3
    rough = 0.36 + 0.05 * f2 + 0.12 * vs + 0.18 * sst(0.9, 0.99, r)
    if old:
        g1, g2 = field(Q, 1.5, seed + 7), field(Q, 1.1, seed + 8)
        yel = sst(0.45, 1.05, r + 0.3 * g1)
        col = mix(col, (0.66, 0.58, 0.24) * (0.92 + 0.08 * g2)[..., None], 0.75 * yel)
        col = mix(col, (0.66, 0.62, 0.30), 0.35 * vs * yel)  # veins stay paler as the blade yellows
        nec = sst(0.95, 1.35, g2 + 1.3 * r - 0.75)
        col = mix(col, (0.33, 0.20, 0.09), 0.85 * nec)
        col = mix(col, (0.30, 0.17, 0.08), 0.7 * sst(0.84, 0.97, r))
        h -= 0.08 * nec
        rough = rough + 0.2 * yel + 0.25 * nec
    return col, h, np.clip(rough, 0, 1)


def pad_under(seed):
    lu, lv = qgrid()
    x, y = lu * 2 - 1, lv * 2 - 1
    r, a = np.hypot(x, y), np.arctan2(y, x)
    f1, f2 = field(Q, 1.6, seed), field(Q, 0.8, seed + 1)
    vs = np.clip(veins(r, a, 22, 0.02 * (0.4 + 0.6 * r), 0.05 * f1) * sst(0.02, 0.1, r)
                 + 0.6 * veins(r, a + TAU / 44, 44, 0.012, 0.07 * f1) * sst(0.35, 0.5, r), 0, 1)
    col = mix(np.zeros(r.shape + (3,)) + (0.40, 0.34, 0.16), (0.47, 0.17, 0.17), sst(0.05, 0.35, r))
    col *= (1 + 0.07 * f2)[..., None]
    col = mix(col, (0.58, 0.27, 0.22), 0.6 * vs)
    return col, 0.5 + 0.3 * vs + 0.02 * f2, np.clip(0.62 + 0.05 * f2, 0, 1)


def lotus_leaf(seed):
    lu, lv = qgrid()
    x, y = lu * 2 - 1, lv * 2 - 1
    r, a = np.hypot(x, y), np.arctan2(y, x)
    f1, f2, f3 = field(Q, 1.6, seed), field(Q, 1.0, seed + 1), field(Q, 0.5, seed + 2)
    warp = 0.07 * f1
    vs = np.clip(veins(r, a, 19, 0.012 * (0.35 + 0.65 * r), warp) * sst(0.06, 0.16, r)
                 + 0.7 * veins(r, a + TAU / 38, 38, 0.008, warp * 1.3) * sst(0.45, 0.6, r), 0, 1)
    col = mix(np.zeros(r.shape + (3,)) + (0.44, 0.55, 0.40), (0.36, 0.48, 0.33), np.clip(r, 0, 1))
    col *= (1 + 0.07 * f2)[..., None]
    col = mix(col, (0.52, 0.62, 0.44), 0.45 * vs)
    col = mix(col, (0.62, 0.62, 0.36), sst(0.075, 0.035, r))  # pale navel over the petiole
    col = mix(col, (0.40, 0.38, 0.22), 0.45 * sst(0.9, 0.99, r))
    return col, 0.5 - 0.18 * vs + 0.03 * f3, np.clip(0.6 + 0.05 * f2 + 0.1 * vs, 0, 1)


def petal(seed, outer):
    lu, lv = qgrid()
    f1, f2, f3 = field(Q, 1.4, seed), field(Q, 0.6, seed + 1), field(Q, 1.0, seed + 2)
    edge = np.abs(lu - 0.5) * 2
    line = (0.5 + 0.5 * np.cos(TAU * (lu * 23 + 0.15 * f1))) ** 10  # longitudinal veins (converge to the tip on the card)
    if not outer:
        pink = np.clip(sst(0.12, 0.98, lv) * 0.85 + 0.4 * edge ** 3 * sst(0.1, 0.6, lv), 0, 1)
        col = mix(np.zeros(lu.shape + (3,)) + (0.98, 0.90, 0.92), (0.91, 0.40, 0.62), pink)
        col = mix(col, (0.97, 0.93, 0.72), sst(0.24, 0.02, lv))  # cream heart
        col = mix(col, (0.80, 0.33, 0.55), 0.22 * line * (0.3 + 0.7 * pink))
        rough = 0.5 + 0.04 * f3
    else:
        pink = np.clip(sst(0.35, 1.0, lv) + 0.3 * edge ** 3 * sst(0.3, 0.8, lv), 0, 1)
        col = mix(np.zeros(lu.shape + (3,)) + (0.78, 0.80, 0.56), (0.93, 0.78, 0.80), sst(0.15, 0.5, lv))
        col = mix(col, (0.74, 0.34, 0.46), pink)
        col = mix(col, (0.52, 0.56, 0.30), 0.2 * line * sst(0.5, 0.1, lv))
        spot = sst(1.9, 2.4, f2) * sst(0.4, 0.7, lv)  # weathered blemishes
        col = mix(col, (0.50, 0.32, 0.22), 0.8 * spot)
        rough = 0.56 + 0.04 * f3 + 0.2 * spot
    col *= (1 + 0.035 * f3)[..., None]
    return col, 0.5 + 0.05 * line + 0.02 * f1, np.clip(rough, 0, 1)


def seed_disc(x, y, holes, top, hole_col, side):
    """Seed-pod top: flat disc of `top` colour, sunken seed holes, side colour past r 0.88 (the pod's wall band)."""
    r = np.hypot(x, y)
    col = np.zeros(x.shape + (3,)) + top
    col = mix(col, np.asarray(top) * 0.9, sst(0.3, 0.85, r))
    h = np.full(x.shape, 0.5)
    for cx, cy in holes:
        d = np.hypot(x - cx, y - cy)
        hole = sst(0.085, 0.06, d)
        col = mix(col, hole_col, hole)
        col = mix(col, np.asarray(hole_col) * 0.6, sst(0.04, 0.0, d))
        h -= 0.35 * hole
    col = mix(col, side, sst(0.84, 0.9, r))
    return col, h


HOLES = [(0.0, 0.0)] + [(0.33 * math.cos(TAU * k / 6), 0.33 * math.sin(TAU * k / 6)) for k in range(6)] + \
        [(0.63 * math.cos(TAU * k / 11 + 0.3), 0.63 * math.sin(TAU * k / 11 + 0.3)) for k in range(11)]


def pod_quadrant(seed):
    lu, lv = qgrid()
    f = field(Q, 1.2, seed)
    col, h = seed_disc(lu * 2 - 1, lv * 2 - 1, HOLES, (0.82, 0.80, 0.42), (0.40, 0.48, 0.18), (0.48, 0.58, 0.24))
    col *= (1 + 0.04 * f)[..., None]
    return col, h + 0.02 * f, np.clip(0.55 + 0.05 * f, 0, 1)


def misc_quadrant(seed):
    """Left half: stem strip (v along). Right top: stamens. Right bottom: spent seed pod disc (centre 0.75, 0.25, r 0.22)."""
    lu, lv = qgrid()
    f1, f2 = field(Q, 1.0, seed), field(Q, 0.4, seed + 1)
    streak = 0.5 + 0.5 * np.sin(TAU * (lu * 14 + 0.2 * f1))
    stem = np.zeros(lu.shape + (3,)) + (0.33, 0.44, 0.20)
    stem *= (0.88 + 0.12 * streak + 0.04 * f1)[..., None]
    stem = mix(stem, (0.30, 0.22, 0.12), sst(2.3, 2.7, f2))  # prickle specks
    stam = mix(np.zeros(lu.shape + (3,)) + (0.96, 0.76, 0.26), (0.99, 0.93, 0.66), sst(0.6, 0.98, lv))
    sx, sy = (lu - 0.75) / 0.22, (lv - 0.25) / 0.22
    spent, sh = seed_disc(sx, sy, HOLES, (0.42, 0.31, 0.17), (0.12, 0.08, 0.05), (0.34, 0.25, 0.13))
    spent *= (1 + 0.06 * f1)[..., None]
    right = np.where((lv >= 0.5)[..., None], stam, spent)
    col = np.where((lu < 0.5)[..., None], stem, right)
    h = np.where(lu < 0.5, 0.5 + 0.06 * streak, np.where(lv >= 0.5, 0.5, sh))
    rough = np.where(lu < 0.5, 0.6, np.where(lv >= 0.5, 0.7, 0.8)) + 0.04 * f1
    return col, h, np.clip(rough, 0, 1)


def nmap(h, k):
    dx = np.roll(h, -1, 1) - np.roll(h, 1, 1)
    dy = np.roll(h, -1, 0) - np.roll(h, 1, 0)
    nm = np.dstack([-dx * k, -dy * k, np.ones_like(dx)])
    nm /= np.linalg.norm(nm, axis=2, keepdims=True)
    return nm * 0.5 + 0.5


def save_png(path, name, arr, data):
    h, w = arr.shape[:2]
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, 2)
    im = bpy.data.images.new(name, w, h, alpha=False, is_data=data)
    rgba = np.concatenate([np.clip(arr, 0, 1), np.ones((h, w, 1))], 2).astype(np.float32)
    im.pixels.foreach_set(rgba.ravel())
    im.filepath_raw = str(path)
    im.file_format = "PNG"
    im.save()
    return im


def atlas(quads, k):
    col, h, rough = np.zeros((N, N, 3)), np.zeros((N, N)), np.zeros((N, N))
    for (qx, qy), (c, hh, rr) in quads.items():
        sl = (slice(qy * Q, qy * Q + Q), slice(qx * Q, qx * Q + Q))
        col[sl], h[sl], rough[sl] = c, hh, rr
    return np.clip(col, 0, 1), nmap(h, k), rough


def make_materials(maps):
    maps.mkdir(parents=True, exist_ok=True)
    built = {
        "Pad": atlas({(0, 0): pad_top(11, False), (1, 0): pad_top(23, True), (0, 1): pad_under(37), (1, 1): lotus_leaf(41)}, 3.0),
        "Bloom": atlas({(0, 0): petal(51, False), (1, 0): petal(61, True), (0, 1): pod_quadrant(71), (1, 1): misc_quadrant(81)}, 3.0),
    }
    mats, files = {}, {}
    for role, (col, nrm, rough) in built.items():
        mname = MAT[role]
        f = {s: maps / f"{mname}_{s}.png" for s in ("Color", "Normal", "Roughness", "Metal")}
        ims = {"Color": save_png(f["Color"], mname + "_Color", col, False),
               "Normal": save_png(f["Normal"], mname + "_Normal", nrm, True),
               "Roughness": save_png(f["Roughness"], mname + "_Roughness", rough, True),
               "Metal": save_png(f["Metal"], mname + "_Metal", np.zeros((N, N)), True)}
        m = bpy.data.materials.new(mname)
        try:
            m.use_nodes = True
        except (AttributeError, TypeError):
            pass
        m.use_backface_culling = True  # cards are real two-sided geometry, as Roblox culls back faces
        nt = m.node_tree
        p = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        for slot, sock in (("Color", "Base Color"), ("Roughness", "Roughness"), ("Metal", "Metallic")):
            t = nt.nodes.new("ShaderNodeTexImage")
            t.image = ims[slot]
            nt.links.new(t.outputs["Color"], p.inputs[sock])
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = ims["Normal"]
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
        mats[role] = m
        files[role] = {s: Path(v).relative_to(maps.parent).as_posix() for s, v in f.items()}
        log(f"maps {mname} {N}x{N}")
    return mats, files


# ============================================================================================ geometry
class MB:
    """Vertices + faces with per-loop UVs (no shared-vertex smoothing across separately built parts)."""

    def __init__(self):
        self.V, self.F, self.UV = [], [], []

    def v(self, p):
        self.V.append((float(p[0]), float(p[1]), float(p[2])))
        return len(self.V) - 1

    def f(self, idx, uvs):
        """Quads are split on their 0-2 diagonal here, so a two-sided card's back (given as c, b, a, d) shares the front's
        diagonal; letting the exporter pick diagonals made the 0.02-stud-apart sheets of cupped petals cross in squares."""
        if len(idx) == 4:
            self.F += [(idx[0], idx[1], idx[2]), (idx[0], idx[2], idx[3])]
            self.UV += [[uvs[0], uvs[1], uvs[2]], [uvs[0], uvs[2], uvs[3]]]
        else:
            self.F.append(tuple(idx))
            self.UV.append(list(uvs))

    def build(self, name, mat):
        me = bpy.data.meshes.new(name)
        me.from_pydata(self.V, [], self.F)
        uvl = me.uv_layers.new(name="UVMap")
        uvl.data.foreach_set("uv", np.array([c for f in self.UV for uv in f for c in uv], np.float32))
        me.materials.append(mat)
        me.validate()
        me.shade_smooth()
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        return o


def sheet(P, ns, T, fn, q_top, q_bot, closed, thick, skip=lambda i, j: False):
    """Polar sheet with thickness: fn(t, phi) -> (pos, lu, lv); ring T[0] = 0 is the centre. Top faces +Z, a reversed
    underside `thick` below, an outer rim, and side walls wherever a face column is missing (the slit, tears)."""
    nj = ns if closed else ns + 1
    G = [[fn(t, j / ns) for j in range(nj)] for t in T]
    J = (lambda j: j % nj) if closed else (lambda j: j)
    dn = Z * thick
    top = [[P.v(G[0][0][0])]] + [[P.v(g[0]) for g in row] for row in G[1:]]
    bot = [[P.v(G[0][0][0] - dn)]] + [[P.v(g[0] - dn) for g in row] for row in G[1:]]
    uvT = lambda i, j: quv(q_top, *G[i][J(j)][1:])  # noqa: E731
    uvB = lambda i, j: quv(q_bot, *G[i][J(j)][1:])  # noqa: E731
    L = len(T) - 1

    def has(i, j):
        return (closed or 0 <= j < ns) and not skip(i, j % ns if closed else j)

    for i in range(L):
        for j in range(ns):
            if not has(i, j):
                continue
            if i == 0:
                P.f((top[0][0], top[1][J(j)], top[1][J(j + 1)]), (uvT(0, 0), uvT(1, j), uvT(1, j + 1)))
                P.f((bot[0][0], bot[1][J(j + 1)], bot[1][J(j)]), (uvB(0, 0), uvB(1, j + 1), uvB(1, j)))
            else:
                q = ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))
                P.f([top[a][J(b)] for a, b in q], [uvT(a, b) for a, b in q])
                qb = (q[2], q[1], q[0], q[3])
                P.f([bot[a][J(b)] for a, b in qb], [uvB(a, b) for a, b in qb])

    def wall(pts_t, pts_b, uvs):  # quad top0, top1, bot1, bot0 (new vertices: the rim shades on its own)
        P.f([P.v(pts_t[0]), P.v(pts_t[1]), P.v(pts_b[1]), P.v(pts_b[0])], [uvs[0], uvs[1], uvs[1], uvs[0]])

    for j in range(ns):  # outer rim, facing out
        if has(L - 1, j):
            a, b = G[L][J(j)][0], G[L][J(j + 1)][0]
            P.f([P.v(a), P.v(a - dn), P.v(b - dn), P.v(b)], [uvB(L, j), uvB(L, j), uvB(L, j + 1), uvB(L, j + 1)])
    for i in range(L):  # radial walls at missing columns
        for j in range(ns + (0 if closed else 1)):
            left, right = has(i, j - 1), has(i, j)
            if left == right:
                continue
            a = G[0][0][0] if i == 0 else G[i][J(j)][0]
            b = G[i + 1][J(j)][0]
            uv = (uvB(i, j), uvB(i + 1, j))
            if left:  # gap at larger angle: wall faces +theta
                wall((a, b), (a - dn, b - dn), uv)
            else:
                P.f([P.v(a), P.v(a - dn), P.v(b - dn), P.v(b)], [uv[0], uv[0], uv[1], uv[1]])


def lily_pad(P, c, R, yaw, rng, old=False, curl=0.0, curl_dir=0.0, ragged=0.0, tear=None, z0=0.03):
    """Floating Nymphaea pad: a slit from rim to petiole (narrowing inward, rounded lobe tips), upturned rim, a slow
    ripple; old pads yellow, fray (ragged) and roll up on one side (curl toward curl_dir); tear = (angle, depth) cuts a V."""
    ns, T = 32, (0.0, 0.2, 0.42, 0.62, 0.78, 0.9, 1.0)
    notch = rng.uniform(0.16, 0.26)
    ph, ph2 = rng.uniform(0, TAU), rng.uniform(0, TAU)

    def fn(t, phi):
        half = notch / 2 * (0.2 + 0.8 * t)
        al = half + phi * (TAU - 2 * half)
        k = 1.0
        if t > 0.6:
            k -= 0.08 * (math.exp(-(phi / 0.04) ** 2) + math.exp(-((1 - phi) / 0.04) ** 2)) * sst1(0.6, 1, t)
            k -= ragged * abs(math.sin(al * 7 + ph) * math.sin(al * 3.3 + ph2)) * sst1(0.8, 1, t)
        cf = curl * sst1(0.45, 1.0, t) ** 2 * max(0.0, math.cos(al + yaw - curl_dir)) ** 2
        k *= 1 - 0.18 * cf
        a = al + yaw
        z = z0 + R * 0.04 * sst1(0.75, 1, t) + R * 0.5 * cf + 0.03 * R * math.sin(5 * al + ph) * t * t
        rr = R * t * k
        return Vector((c[0] + rr * math.cos(a), c[1] + rr * math.sin(a), z)), 0.5 + 0.5 * t * k * math.cos(al), 0.5 + 0.5 * t * k * math.sin(al)

    skip = lambda i, j: False  # noqa: E731
    if tear:
        tj, tr = int(tear[0] / TAU * 32) % 32, len(T) - 1 - tear[1]
        skip = lambda i, j: j == tj and i >= tr  # noqa: E731
    sheet(P, ns, T, fn, (1, 0) if old else (0, 0), (0, 1), False, 0.05, skip)


def lotus_leaf_geo(P, B, c, R, h, rng, tilt=0.18, base=None):
    """Emergent Nelumbo leaf: a shallow bowl with a wavy rim and a dimple over the petiole, tilted, on a stalk from the water."""
    ns, T = 32, (0.0, 0.12, 0.3, 0.5, 0.7, 0.86, 1.0)
    ph, td = rng.uniform(0, TAU), rng.uniform(0, TAU)
    M = Matrix.Translation((c[0], c[1], h)) @ Matrix.Rotation(tilt, 4, Vector((math.cos(td), math.sin(td), 0)))

    def fn(t, phi):
        a = phi * TAU
        rr = R * t * (1 + 0.03 * math.sin(7 * a + ph))
        z = R * 0.24 * t ** 1.7 + 0.06 * R * math.sin(7 * a + ph) * t ** 3 - 0.05 * R * (1 - t) ** 6
        return M @ Vector((rr * math.cos(a), rr * math.sin(a), z)), 0.5 + 0.5 * t * math.cos(a), 0.5 + 0.5 * t * math.sin(a)

    sheet(P, ns, T, fn, (1, 1), (1, 1), True, 0.045)
    foot = Vector(base) if base else Vector((c[0] + rng.uniform(-0.4, 0.4), c[1] + rng.uniform(-0.4, 0.4), -0.6))
    top = M @ Vector((0, 0, -0.05 * R))
    stem(B, foot, top, 0.11)


def stem(B, a, b, r, sides=6, bow=None):
    """Tapered stalk a -> b with a gentle bow, stem strip of the Bloom atlas."""
    rng_bow = bow if bow is not None else Vector((0.25, -0.15, 0))
    pts = [a.lerp(b, k / 5) + rng_bow * math.sin(math.pi * k / 5) for k in range(6)]
    rings, length = [], [0.0]
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, 5)] - pts[max(i - 1, 0)]).normalized()
        sd = t.cross(Vector((1, 0, 0)))
        sd = sd if sd.length > 0.1 else t.cross(Vector((0, 1, 0)))
        sd.normalize()
        up = t.cross(sd)
        rr = r * (1 - 0.25 * i / 5)
        rings.append([B.v(p + (sd * math.cos(TAU * k / sides) + up * math.sin(TAU * k / sides)) * rr) for k in range(sides + 1)])
        if i:
            length.append(length[-1] + (p - pts[i - 1]).length)
    tot = length[-1]
    for i in range(5):
        for k in range(sides):
            q = ((i, k), (i, k + 1), (i + 1, k + 1), (i + 1, k))
            B.f([rings[a][b] for a, b in q], [quv((1, 1), 0.04 + 0.42 * b / sides, 0.03 + 0.94 * length[a] / tot) for a, b in q])


def petal_geo(B, base, out, L, W, th0, th1, cup, q, nu=5, nv=10, lift=0.0):
    """Boat-shaped two-sided petal from `base`, `out` horizontal; tilt from vertical th0 at the base to th1 at the tip.
    Edges cup toward the flower axis (the concave inner side); UV u across (0..1), v base -> tip."""
    out = Vector((out.x, out.y, 0)).normalized()
    side = Z.cross(out)
    C, D = [Vector(base)], []
    for k in range(nv):
        t = k / (nv - 1)
        th = th0 + (th1 - th0) * t ** 1.4
        D.append(Z * math.cos(th) + out * math.sin(th))
        if k:
            C.append(C[-1] + (D[k - 1] + D[k]).normalized() * L / (nv - 1))
    rows_f, rows_b = [], []
    for k in range(nv):
        t = k / (nv - 1)
        w = W * max(0.02, math.sin(math.pi * (0.06 + 0.94 * t))) ** 0.55  # broad blade, short point
        n_in = D[k].cross(side)
        rf, rb = [], []
        for i in range(nu):
            s = -1 + 2 * i / (nu - 1)
            p = C[k] + side * (s * w / 2) + n_in * (cup * W * 0.5 * s * s) + Z * lift * t * t
            rf.append(p)
            rb.append(p + n_in * 0.02)
        rows_f.append([B.v(p) for p in rf])  # shared vertices: the petal shades smooth
        rows_b.append([B.v(p) for p in rb])
    for k in range(nv - 1):
        for i in range(nu - 1):
            qd = ((i, k), (i + 1, k), (i + 1, k + 1), (i, k + 1))
            uvs = [quv(q, a / (nu - 1), b / (nv - 1)) for a, b in qd]
            B.f([rows_f[b][a] for a, b in qd], uvs)
            B.f([rows_b[b][a] for a, b in (qd[2], qd[1], qd[0], qd[3])], [uvs[2], uvs[1], uvs[0], uvs[3]])


def card(B, base, d, L, W, uvq, uvr):
    """Small two-sided kite card (stamens): base, direction d; UVs in quadrant uvq at local rect uvr = (u0, v0, u1, v1)."""
    d = d.normalized()
    sd = Z.cross(d)
    sd = sd.normalized() if sd.length > 0.1 else Vector((1, 0, 0))
    pts = [base, base + d * L * 0.4 - sd * W / 2, base + d * L, base + d * L * 0.4 + sd * W / 2]
    u0, v0, u1, v1 = uvr
    uv = [quv(uvq, (u0 + u1) / 2, v0), quv(uvq, u0, v0 + 0.4 * (v1 - v0)), quv(uvq, (u0 + u1) / 2, v1), quv(uvq, u1, v0 + 0.4 * (v1 - v0))]
    B.f([B.v(p) for p in pts], uv)
    B.f([B.v(p) for p in pts[::-1]], uv[::-1])


def pod(B, M, rp, hgt, q, cx, cy, rad, seg=20):
    """Lotus seed pod (receptacle): flat top disc, flared rim, tapering under-side to the stalk; local frame M (top at origin)."""
    prof = [(rp * 0.97, 0.0), (rp, -0.06 * hgt), (rp * 0.86, -0.4 * hgt), (rp * 0.5, -0.8 * hgt), (rp * 0.28, -hgt)]
    ring = lambda r_, z_: [M @ Vector((r_ * math.cos(TAU * k / seg), r_ * math.sin(TAU * k / seg), z_)) for k in range(seg + 1)]  # noqa: E731
    uvd = lambda rr, k: quv(q, cx + rad * rr * math.cos(TAU * k / seg), cy + rad * rr * math.sin(TAU * k / seg))  # noqa: E731
    centre = M @ Vector((0, 0, 0.02 * hgt))
    top = ring(*prof[0])
    for k in range(seg):
        B.f([B.v(centre), B.v(top[k]), B.v(top[k + 1])], [quv(q, cx, cy), uvd(0.97 * 0.86, k), uvd(0.97 * 0.86, k + 1)])
    rings = [[B.v(v) for v in ring(*p)] for p in prof]
    for i in range(len(prof) - 1):
        for k in range(seg):
            qd = ((i, k), (i + 1, k), (i + 1, k + 1), (i, k + 1))
            B.f([rings[a][b] for a, b in qd], [uvd(0.9 + 0.1 * a / (len(prof) - 1), b) for a, b in qd])


WHORLS = (  # n, th0, th1, L, W, cup, quadrant, phase   (L, W in units of S)
    (7, 0.30, 0.10, 0.55, 0.40, 0.62, (0, 0), 0.0),
    (8, 0.60, 0.42, 0.66, 0.44, 0.55, (0, 0), 0.5),
    (8, 0.92, 0.98, 0.72, 0.46, 0.46, (0, 0), 0.25),
    (4, 1.45, 1.85, 0.46, 0.30, 0.35, (1, 0), 0.12),
)


def lotus_flower(B, c, S, z_top, rng, openness=1.0, yaw=0.0, foot=None):
    rp = 0.24 * S
    pod(B, Matrix.Translation((c[0], c[1], z_top)), rp, 0.3 * S, (0, 1), 0.5, 0.5, 0.5)
    for k in range(26):  # stamens: a gold fringe round the pod
        a = yaw + TAU * k / 26 + rng.uniform(-0.08, 0.08)
        o = Vector((math.cos(a), math.sin(a), 0))
        el = rng.uniform(0.55, 0.95)
        card(B, Vector((c[0], c[1], z_top - 0.05 * S)) + o * rp * 0.9, Z * math.cos(el) + o * math.sin(el), 0.2 * S, 0.05 * S,
             (1, 1), (0.55, 0.55, 0.95, 0.95))
    for w, (n, th0, th1, L, W, cup, q, phase) in enumerate(WHORLS):
        for k in range(n):
            a = yaw + TAU * (k + phase) / n + rng.uniform(-0.1, 0.1)
            o = Vector((math.cos(a), math.sin(a), 0))
            j = rng.uniform(-0.07, 0.07)
            petal_geo(B, Vector((c[0], c[1], z_top - (0.2 + 0.03 * w) * S)) + o * rp * (0.75 + 0.06 * w), o,
                      L * S * rng.uniform(0.92, 1.06), W * S * rng.uniform(0.92, 1.06), (th0 + j) * openness, (th1 + j) * openness, cup, q)
    stem(B, Vector(foot) if foot else Vector((c[0] + rng.uniform(-0.4, 0.4), c[1] + rng.uniform(-0.4, 0.4), -0.6)),
         Vector((c[0], c[1], z_top - 0.3 * S)), 0.075 * S)


def lotus_bud(B, c, S, z_top, rng):
    for n, th0, th1, L, W, cup, ph in ((6, 0.24, -0.26, 0.8, 0.5, 0.95, 0.0), (4, 0.12, -0.2, 0.72, 0.46, 0.9, 0.5)):
        for k in range(n):
            a = TAU * (k + ph) / n + rng.uniform(-0.08, 0.08)
            o = Vector((math.cos(a), math.sin(a), 0))
            petal_geo(B, Vector((c[0], c[1], z_top)) + o * 0.06 * S, o, L * S, W * S, th0, th1, cup, (1, 0))
    stem(B, Vector((c[0] + rng.uniform(-0.4, 0.4), c[1] + rng.uniform(-0.4, 0.4), -0.6)), Vector((c[0], c[1], z_top + 0.02)), 0.07 * S)


def spent_pod(B, c, S, z_top, rng):
    """Seed head after the petals fell: a brown pod nodding on its stalk, one withered petal still hanging."""
    nod = Matrix.Translation((c[0], c[1], z_top)) @ Matrix.Rotation(0.45, 4, Vector((1, 0.3, 0)).normalized())
    pod(B, nod, 0.3 * S, 0.34 * S, (1, 1), 0.75, 0.25, 0.22)
    o = Vector((0.6, -0.8, 0))
    petal_geo(B, nod @ Vector((0.2 * S, -0.2 * S, -0.25 * S)), o, 0.55 * S, 0.3 * S, 2.3, 2.75, 0.5, (1, 0))
    stem(B, Vector((c[0] - 0.3, c[1] + 0.2, -0.6)), nod @ Vector((0, 0, -0.34 * S)), 0.07 * S)


def drift_petal(B, c, S, yaw, rng):
    o = Vector((math.cos(yaw), math.sin(yaw), 0))
    petal_geo(B, Vector((c[0], c[1], 0.035)), o, 0.62 * S, 0.38 * S, 1.5, 1.25, 0.3, (0, 0) if rng.random() < 0.6 else (1, 0))


def relax(items, fixed=(), gap=0.06, it=300):
    """Push pads (x, y, R, ...) apart so no two overlap (overlapping floating pads would z-fight); fixed = (x, y, r) stems."""
    xs = [[it_[0], it_[1]] for it_ in items]
    for _ in range(it):
        moved = False
        for i in range(len(items)):
            for j in range(i + 1, len(items)):
                dx, dy = xs[j][0] - xs[i][0], xs[j][1] - xs[i][1]
                d = math.hypot(dx, dy) or 1e-3
                need = items[i][2] + items[j][2] + gap
                if d < need:
                    m = (need - d) / 2 / d
                    xs[i][0] -= dx * m; xs[i][1] -= dy * m; xs[j][0] += dx * m; xs[j][1] += dy * m  # noqa: E702
                    moved = True
            for fx, fy, fr in fixed:
                dx, dy = xs[i][0] - fx, xs[i][1] - fy
                d = math.hypot(dx, dy) or 1e-3
                if d < items[i][2] + fr:
                    m = (items[i][2] + fr - d) / d
                    xs[i][0] += dx * m; xs[i][1] += dy * m  # noqa: E702
                    moved = True
        if not moved:
            break
    return [(x, y) + tuple(it_[2:]) for (x, y), it_ in zip(xs, items)]


# ============================================================================================ pieces
def build_piece(spec, seed):
    """spec: pads [(x, y, R, old, curl, ragged, tear)], flowers [(x, y, S, z_top)], buds, pods, leaves [(x, y, R, h)], drifts n."""
    rng = random.Random(seed)
    P, B = MB(), MB()
    stems = [(x, y, 0.35) for x, y, *_ in spec.get("flowers", []) + spec.get("buds", []) + spec.get("pods", [])]
    stems += [(x, y, 0.3) for x, y, *_ in spec.get("leaves", [])]
    for x, y, R, old, curl, ragged, tear in relax(spec["pads"], stems):
        lily_pad(P, (x, y), R, rng.uniform(0, TAU), rng, old=old, curl=curl, curl_dir=rng.uniform(0, TAU), ragged=ragged,
                 tear=(rng.uniform(0, TAU), tear) if tear else None, z0=rng.uniform(0.02, 0.05))
    for x, y, S, zt in spec.get("flowers", []):
        lotus_flower(B, (x, y), S, zt, rng, yaw=rng.uniform(0, TAU), openness=rng.uniform(0.92, 1.05))
    for x, y, S, zt in spec.get("buds", []):
        lotus_bud(B, (x, y), S, zt, rng)
    for x, y, S, zt in spec.get("pods", []):
        spent_pod(B, (x, y), S, zt, rng)
    for x, y, R, h in spec.get("leaves", []):
        lotus_leaf_geo(P, B, (x, y), R, h, rng)
    pts = [(p[0], p[1], p[2]) for p in spec["pads"]]
    for _ in range(spec.get("drifts", 0)):
        x, y, R = rng.choice(pts)
        a = rng.uniform(0, TAU)
        d = R + rng.uniform(0.3, 1.0)
        drift_petal(B, (x + d * math.cos(a), y + d * math.sin(a)), rng.uniform(1.5, 1.9), rng.uniform(0, TAU), rng)
    return P, B


PIECES = {
    "ClusterA": ("Bellwood_LotusClusterA", 301, {  # hero clump: open flower, bud, one emergent leaf
        "pads": [(0, 0, 2.0, False, 0.0, 0.0, 0), (-3.4, 1.0, 1.5, False, 0.0, 0.0, 0), (2.9, 1.6, 1.7, False, 0.15, 0.0, 0),
                 (-1.4, -3.0, 1.3, False, 0.35, 0.0, 0), (2.7, -2.4, 1.9, True, 0.55, 0.06, 2), (-4.0, -1.9, 1.0, False, 0.0, 0.0, 0),
                 (0.6, 3.5, 1.1, False, 0.0, 0.0, 0), (4.9, -0.2, 0.8, False, 0.0, 0.0, 0)],
        "flowers": [(0.9, -1.0, 1.9, 1.15)], "buds": [(-1.7, 1.6, 1.4, 1.9)], "leaves": [(-1.0, 4.6, 1.8, 2.6)], "drifts": 2}),
    "ClusterB": ("Bellwood_LotusClusterB", 302, {  # wider, older stand: two flowers, a spent pod, two emergent leaves
        "pads": [(0, 0, 2.2, False, 0.0, 0.0, 0), (-4.0, 1.5, 1.8, True, 0.5, 0.08, 2), (4.2, 1.0, 1.6, False, 0.0, 0.0, 0),
                 (-2.0, -3.6, 1.5, False, 0.2, 0.0, 0), (2.5, -3.4, 1.4, True, 0.3, 0.05, 0), (-6.3, -1.4, 1.2, False, 0.0, 0.0, 0),
                 (6.4, -1.8, 1.3, True, 0.7, 0.1, 3), (0.5, 4.2, 1.6, False, 0.1, 0.0, 0), (-3.0, 4.6, 1.0, False, 0.0, 0.0, 0),
                 (5.3, 4.0, 0.9, False, 0.0, 0.0, 0)],
        "flowers": [(-1.4, 1.6, 1.8, 1.4), (3.4, -1.2, 1.4, 0.9)], "pods": [(-4.6, -2.0, 1.4, 1.7)],
        "leaves": [(1.8, 5.6, 1.9, 3.4), (-6.0, 3.2, 1.4, 1.6)], "drifts": 3}),
    "Drift": ("Bellwood_LilyPadsDrift", 303, {  # pads only, for wide sparse scatter
        "pads": [(0, 0, 1.9, False, 0.0, 0.0, 0), (-3.6, 0.8, 1.4, True, 0.35, 0.06, 0), (3.5, 1.2, 1.6, False, 0.0, 0.0, 0),
                 (-1.2, -3.2, 1.2, False, 0.0, 0.0, 0), (2.2, -2.9, 1.0, True, 0.6, 0.08, 2), (-5.8, -1.6, 1.1, False, 0.0, 0.0, 0),
                 (5.9, -1.0, 0.9, False, 0.0, 0.0, 0), (0.4, 3.6, 1.3, False, 0.1, 0.0, 0), (-3.0, 3.8, 0.8, True, 0.0, 0.05, 0),
                 (4.4, 4.0, 1.2, False, 0.0, 0.0, 0), (-6.6, 2.4, 0.7, False, 0.0, 0.0, 0), (6.6, 2.8, 0.7, False, 0.0, 0.0, 0)],
        "drifts": 3}),
    "Bloom": ("Bellwood_LotusBloom", 304, {  # single flower with two pads, for a close accent by the causeway
        "pads": [(-1.2, -0.6, 1.8, False, 0.0, 0.0, 0), (1.9, 1.0, 1.4, False, 0.25, 0.0, 0)],
        "flowers": [(0.4, -0.3, 2.1, 1.3)], "drifts": 1}),
}


# ============================================================================================ export, renders
def tris(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


def bbox(objs):
    pts = np.array([tuple(o.matrix_world @ Vector(c)) for o in objs for c in o.bound_box])
    return pts.min(0), pts.max(0)


def export_glb(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_apply=False, export_image_format="NONE")


def setup_render():
    sc = bpy.context.scene
    ids = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    want = os.environ.get("LOTUS_ENGINE", "")
    sc.render.engine = want if want in ids else next(e for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT") if e in ids)
    if sc.render.engine == "CYCLES":
        sc.cycles.samples = 48
        sc.cycles.use_denoising = True
    for attr, val in (("use_raytracing", True), ("taa_render_samples", 64)):
        try:
            setattr(sc.eevee, attr, val)
        except (AttributeError, TypeError):
            pass
    try:
        sc.view_settings.view_transform = "Standard"  # judge the painted colours as Roblox shows them
    except TypeError:
        pass
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.36, 0.42, 0.44, 1)
    bg.inputs["Strength"].default_value = 0.8
    sc.world = w
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy, sun.data.color, sun.data.angle = 3.2, (1.0, 0.93, 0.82), math.radians(4)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    sc.collection.objects.link(sun)
    wm = bpy.data.materials.new("PreviewWater")
    wm.use_nodes = True
    p = next(n for n in wm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    p.inputs["Base Color"].default_value = (0.012, 0.022, 0.024, 1)
    p.inputs["Roughness"].default_value = 0.07
    me = bpy.data.meshes.new("PreviewWater")
    me.from_pydata([(-400, -400, 0), (400, -400, 0), (400, 400, 0), (-400, 400, 0)], [], [(0, 1, 2, 3)])
    me.materials.append(wm)
    sc.collection.objects.link(bpy.data.objects.new("PreviewWater", me))
    fm = bpy.data.materials.new("RefFig")
    fm.use_nodes = True
    next(n for n in fm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.55, 0.55, 0.55, 1)
    fig = MB()
    for x0, y0, z0, sx, sy, sz in ((-0.55, 0, 0, 0.95, 0.95, 2.0), (0.55, 0, 0, 0.95, 0.95, 2.0), (0, 0, 2.0, 2.2, 1.1, 2.1),
                                   (-1.6, 0, 2.1, 0.8, 0.8, 2.0), (1.6, 0, 2.1, 0.8, 0.8, 2.0), (0, 0, 4.1, 1.3, 1.3, 1.4)):
        v = [fig.v((x0 + dx * sx / 2, y0 + dy * sy / 2, z0 + dz * sz)) for dz in (0, 1) for dy in (-1, 1) for dx in (-1, 1)]
        for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
            fig.f([v[i] for i in f], [(0, 0)] * 4)
    fo = fig.build("Ref_Figure_5.5studs", fm)
    fo.data.shade_flat()
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.clip_start, cam.data.clip_end = 0.1, 2000
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.image_settings.file_format = "PNG"
    return sc, cam, fo


def shoot(sc, cam, eye, target, lens, path, res=(1600, 1000)):
    cam.data.lens = lens
    sc.render.resolution_x, sc.render.resolution_y = res
    cam.location = Vector(eye)
    cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    log("render", Path(path).name)
    return Path(path)


def render_piece(name, objs, all_objs, rdir, sc, cam, fig, flower_at):
    for o in all_objs:
        o.hide_render = o not in objs
    lo, hi = bbox(objs)
    ctr = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, 0.5))
    span = max(hi[0] - lo[0], hi[1] - lo[1])
    fig.location = (hi[0] + 2.0, ctr.y, -0.8)  # standing knee-deep in the lake for scale
    fig.hide_render = False
    out = [shoot(sc, cam, ctr + Vector((-0.55, -0.85, 0.62)).normalized() * span * 1.45, ctr, 35, rdir / f"{name}_q34.png"),
           shoot(sc, cam, ctr + Vector((0.25, -1.0, 0.0)) * span * 1.6 + Vector((0, 0, 5.0)), ctr, 35, rdir / f"{name}_eye.png")]
    if flower_at:
        fig.hide_render = True
        t = Vector(flower_at)
        out.append(shoot(sc, cam, t + Vector((-2.2, -3.6, 2.4)), t, 45, rdir / f"{name}_close.png"))
    return out


def vignette(pieces, all_objs, rdir, sc, cam, fig):
    """All four pieces in one patch of water, seen from a standing player's eye at the shore (5 studs up)."""
    for o in all_objs:
        o.hide_render = True
    sc_ = bpy.context.scene
    tmp = []
    for key, (x, y, rz) in {"Bloom": (-1, 9, 0.4), "ClusterA": (-9, 20, 1.3), "ClusterB": (10, 24, 2.6), "Drift": (-2, 36, 0.8)}.items():
        for o in pieces.get(key, []):
            c = bpy.data.objects.new("V_" + o.name, o.data)
            c.matrix_world = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(rz, 4, "Z")
            sc_.collection.objects.link(c)
            tmp.append(c)
    fig.location, fig.hide_render = (5.5, 11, -0.8), False
    f = shoot(sc, cam, Vector((0, -6, 5.0)), Vector((0, 22, 0.5)), 28, rdir / "Bellwood_Lotus_vignette_eye.png")
    for c in tmp:
        bpy.data.objects.remove(c)
    return f


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(a[0] if a else ROOT / "assets/source/landmarks/bellwood_lotus").resolve()
    rdir = out / "renders"
    rdir.mkdir(parents=True, exist_ok=True)
    keys = [k for k in os.environ.get("LOTUS_PIECES", ",".join(PIECES)).split(",") if k]
    norender = bool(os.environ.get("LOTUS_NORENDER"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats, mapfiles = make_materials(out / "maps")
    built, entries = {}, {}
    for key in keys:
        name, seed, spec = PIECES[key]
        P, B = build_piece(spec, seed)
        objs = [P.build(f"{name}__Pad", mats["Pad"]), B.build(f"{name}__Bloom", mats["Bloom"])]
        objs = [o for o in objs if len(o.data.polygons)]
        subs = {o.name: tris(o) for o in objs}
        assert all(v < TRI_CAP for v in subs.values()), subs
        glb = out / f"{name}.glb"
        export_glb(objs, glb)
        lo, hi = bbox(objs)
        roles = sorted(o.name.split("__")[1] for o in objs)
        entries[name] = {
            "group": "Bellwood", "sub_meshes": subs, "tris_total": sum(subs.values()),
            "size_studs_xyz": [round(float(hi[i] - lo[i]), 1) for i in range(3)],
            "bbox_min": [round(float(c), 2) for c in lo], "bbox_max": [round(float(c), 2) for c in hi],
            "materials": sorted(MAT[r] for r in roles), "file": glb.name, "builder": BUILDER,
            "no_decimation": True, "decimation": "none: built directly at game density, every sub < 17500 tris",
            "map_resolution": {r: N for r in roles}, "maps": {r: mapfiles[r] for r in roles},
            "base_layer": "procedural: numpy-painted atlases, no third-party sources",
            "pivot": "water surface at the cluster centre (z = 0 / glTF y = 0); pads float 0.02-0.05 above it, stalks end 0.6 below",
            "collision": {r: "None" for r in roles},
            "two_sided": "real back faces on every card, pad and leaf; DoubleSided not needed",
        }
        built[key] = objs
        log(f"{name}: {glb.name} {glb.stat().st_size / 1e3:.0f} kB; subs {subs}; size {entries[name]['size_studs_xyz']}")
    mf = out / "manifest.json"
    m = json.loads(mf.read_text()) if mf.exists() else {"kit": "Bellwood landmark: Sunken Temple lotus and lily pads", "pieces": {}}
    m["pieces"].update(entries)
    mf.write_text(json.dumps(m, indent=2))
    if norender:
        return
    sc, cam, fig = setup_render()
    all_objs = [o for v in built.values() for o in v]
    for key, objs in built.items():
        name, _, spec = PIECES[key]
        fl = spec.get("flowers")
        render_piece(name, objs, all_objs, rdir, sc, cam, fig, (fl[0][0], fl[0][1], fl[0][3]) if fl else None)
    if len(built) == len(PIECES):
        vignette(built, all_objs, rdir, sc, cam, fig)
    log("LOTUS_OK", len(entries), "pieces")


if __name__ == "__main__":
    main()
