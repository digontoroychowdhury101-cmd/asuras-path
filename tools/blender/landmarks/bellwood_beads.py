"""Bellwood landmark kit: the Fallen Abbot's prayer beads, left on a lacquer tray in the colossal temple's upper hall.
Taking them is what wakes Grandmaster Shen on the lake (ShenLakeRules); his Prayer Beads attack is this same string.

  "C:/Program Files/Blender Foundation/Blender 5.3/blender.exe" -b --python-exit-code 1 -P tools/blender/landmarks/bellwood_beads.py -- [out_dir]
  default out_dir: assets/source/landmarks/bellwood_beads      env: BEADS_NORENDER=1

All procedural, on the lotus kit's helpers (bellwood_lotus.py): one 2048 atlas painted with numpy, no third-party sources.
  quadrants: cast bronze (worn bright where handled, dark patina at the string holes, an engraved lotus band)
             | jade (cloudy, pale veins, a few iron spots) | red silk (strands on the left half, the cushion's weave and
             gold-thread border on the right) | black lacquer worn through to red
Two pieces in one frame (units studs, Z up, pivot at the tray's feet on the altar top, z = 0):
  Bellwood_AbbotTray   lacquer tray on four feet with a piped silk cushion; it stays on the altar.
  Bellwood_AbbotBeads  54 bronze beads with five jade markers and a jade head bead, coiled twice on the cushion and
                       crossing once at the back; a red cord, and a silk tassel that runs over the tray's front rim and
                       hangs to the altar top. This is the piece the player takes.
"""
import json
import math
import os
import random
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bellwood_lotus as L  # noqa: E402  (MB, atlas helpers, export, renders; its main() is guarded)

ROOT = HERE.parents[2]
BUILDER = "tools/blender/landmarks/bellwood_beads.py (win-109, procedural mala + lacquer tray, numpy-painted 2048 atlas)"
TAU, Q, N = L.TAU, L.Q, L.N
MAT = "Vesp_Bellwood_Beads__Relic"
TRI_CAP = L.TRI_CAP
BRONZE, JADE, SILK, LACQUER = (0, 0), (1, 0), (0, 1), (1, 1)
log = L.log

# Layout (studs). The tray is 3.1 x 2.2 on 0.10 feet; the cushion sits on its floor.
TRAY = (1.55, 1.10)           # half extents
RIM_T, RIM_TOP, FLOOR = 0.09, 0.36, 0.20
CUSH = (1.30, 0.90)           # cushion half extents (superellipse of power P_SE)
P_SE, SEAM, BULGE = 6.0, 0.30, 0.20
BEAD_D, MARK_D, HEAD_D = 0.17, 0.19, 0.26
COUNT = 54
MATERIAL = None


# ============================================================================================ texture
def bronze_quadrant(seed):
    lu, lv = L.qgrid()
    f1, f2, f3 = L.field(Q, 1.4, seed), L.field(Q, 0.8, seed + 1), L.field(Q, 0.3, seed + 2)
    pole = np.abs(lv - 0.5)                                         # lv is latitude; 0 and 1 are the string holes
    patina = np.clip(0.85 * L.sst(0.26, 0.46, pole) + 0.65 * L.sst(0.5, 1.9, f1), 0, 1)
    wear = L.sst(0.24, 0.0, pole) * L.sst(-0.6, 0.9, f2) * (1 - patina)
    # engraved lotus band: a scalloped groove either side of the equator and a straight one beyond it
    band = 0.075 + 0.035 * np.abs(np.sin(math.pi * lu * 12))
    groove = np.clip(np.exp(-((pole - band) / 0.006) ** 2) + 0.7 * np.exp(-((pole - 0.125) / 0.005) ** 2), 0, 1)
    col = np.zeros((Q, Q, 3)) + (0.33, 0.22, 0.11)
    col *= (1 + 0.07 * f3)[..., None]
    col = L.mix(col, (0.64, 0.46, 0.24), 0.65 * wear)
    col = L.mix(col, (0.19, 0.25, 0.19), 0.85 * patina)
    col = L.mix(col, (0.09, 0.10, 0.08), 0.45 * L.sst(1.4, 2.6, f3) * patina)
    col = L.mix(col, (0.13, 0.11, 0.07), 0.75 * groove)             # grime packed into the cut lines
    rough = 0.52 - 0.18 * wear + 0.3 * patina + 0.04 * f3 + 0.2 * groove
    metal = 0.85 * (1 - patina) * (1 - 0.6 * groove)
    h = 0.5 - 0.12 * groove - 0.05 * patina * L.sst(0.5, 2.0, f1) + 0.015 * f3
    return np.clip(col, 0, 1), h, np.clip(rough, 0, 1), metal


def jade_quadrant(seed):
    lu, lv = L.qgrid()
    f1, f2, f3 = L.field(Q, 1.6, seed), L.field(Q, 1.1, seed + 1), L.field(Q, 0.4, seed + 2)
    col = L.mix(np.zeros((Q, Q, 3)) + (0.05, 0.20, 0.14), (0.22, 0.43, 0.31), L.sst(-0.8, 1.6, f1))
    vein = L.sst(0.07, 0.0, np.abs(f2))                             # thin pale lines where the field crosses zero
    col = L.mix(col, (0.60, 0.72, 0.56), 0.45 * vein)
    col = L.mix(col, (0.30, 0.22, 0.10), 0.55 * L.sst(2.1, 2.9, f3))  # iron spots
    col = L.mix(col, (0.05, 0.16, 0.11), 0.3 * L.sst(0.30, 0.48, np.abs(lv - 0.5)))  # darker at the holes
    rough = 0.17 + 0.04 * f3 + 0.1 * L.sst(0.3, 0.48, np.abs(lv - 0.5))
    h = 0.5 + 0.01 * f3 - 0.02 * vein
    return np.clip(col, 0, 1), h, np.clip(rough, 0, 1), np.zeros((Q, Q))


def silk_quadrant(seed):
    lu, lv = L.qgrid()
    f1, f2, f3 = L.field(Q, 1.2, seed), L.field(Q, 0.9, seed + 1), L.field(Q, 0.3, seed + 2)
    left = lu < 0.5
    # left half: twisted strands running up lv (the cord and the tassel run their length along lv)
    s = np.sin(TAU * 90 * lu + 2.5 * f1) * 0.5 + 0.5
    strands = L.mix(np.zeros((Q, Q, 3)) + (0.36, 0.04, 0.04), (0.62, 0.10, 0.07), s ** 1.6)
    # right half: the cushion in planar UVs; the gold border is a superellipse ring, the same curve as the geometry's rim
    X, Y = (lu - 0.75) / 0.25, (lv - 0.5) / 0.5
    r = (np.abs(X) ** P_SE + np.abs(Y) ** P_SE) ** (1 / P_SE)
    weave = 0.5 + 0.5 * np.sin(TAU * 220 * lu) * np.sin(TAU * 110 * lv)
    cloth = L.mix(np.zeros((Q, Q, 3)) + (0.40, 0.05, 0.05), (0.52, 0.08, 0.06), weave)
    cloth = L.mix(cloth, (0.30, 0.07, 0.06), 0.35 * L.sst(0.6, 2.0, f2))         # handled, faded patches
    lines = np.exp(-((r - 0.80) / 0.008) ** 2) + np.exp(-((r - 0.88) / 0.008) ** 2)
    diamonds = (np.abs(np.mod(np.arctan2(Y, X) * 48 / TAU, 1) - 0.5) * 0.08 + np.abs(r - 0.84)) < 0.024
    gold = np.clip(lines + 0.9 * diamonds, 0, 1) * L.sst(0.70, 0.76, r)
    cloth = L.mix(cloth, (0.70, 0.52, 0.24), 0.9 * gold)
    col = np.where(left[..., None], strands, cloth)
    col *= (1 + 0.05 * f3)[..., None]
    rough = np.where(left, 0.48 - 0.12 * s, 0.6 - 0.08 * weave - 0.22 * gold) + 0.03 * f3
    metal = np.where(left, 0.0, 0.55 * gold)
    h = np.where(left, 0.5 + 0.10 * s, 0.5 + 0.012 * weave + 0.08 * gold) + 0.01 * f3
    return np.clip(col, 0, 1), h, np.clip(rough, 0, 1), metal


def lacquer_quadrant(seed):
    lu, lv = L.qgrid()
    f1, f2, f3, f4 = (L.field(Q, b, seed + i) for i, b in enumerate((2.2, 1.4, 0.3, 0.15)))
    worn = 0.85 * L.sst(1.3, 2.3, f1) * L.sst(-0.4, 1.0, f2)               # black coat rubbed through to the red ground
    crack = L.sst(0.05, 0.0, np.abs(f4)) * 0.6
    col = np.zeros((Q, Q, 3)) + (0.040, 0.030, 0.028)
    col *= (1 + 0.15 * f3)[..., None]
    col = L.mix(col, (0.34, 0.07, 0.04), worn)
    col = L.mix(col, (0.02, 0.015, 0.012), 0.5 * crack)
    rough = 0.24 + 0.22 * worn + 0.05 * f3 + 0.2 * crack
    h = 0.5 - 0.04 * worn - 0.05 * crack + 0.01 * f3
    return np.clip(col, 0, 1), h, np.clip(rough, 0, 1), np.zeros((Q, Q))


def make_material(maps):
    maps.mkdir(parents=True, exist_ok=True)
    quads = {BRONZE: bronze_quadrant(611), JADE: jade_quadrant(621), SILK: silk_quadrant(631), LACQUER: lacquer_quadrant(641)}
    col, nrm, rough = L.atlas({q: v[:3] for q, v in quads.items()}, 3.0)
    metal = np.zeros((N, N))
    for (qx, qy), v in quads.items():
        metal[qy * Q:qy * Q + Q, qx * Q:qx * Q + Q] = v[3]
    f = {s: maps / f"{MAT}_{s}.png" for s in ("Color", "Normal", "Roughness", "Metal")}
    ims = {"Color": L.save_png(f["Color"], MAT + "_Color", col, False),
           "Normal": L.save_png(f["Normal"], MAT + "_Normal", nrm, True),
           "Roughness": L.save_png(f["Roughness"], MAT + "_Roughness", rough, True),
           "Metal": L.save_png(f["Metal"], MAT + "_Metal", np.clip(metal, 0, 1), True)}
    m = bpy.data.materials.new(MAT)
    try:
        m.use_nodes = True
    except (AttributeError, TypeError):
        pass
    m.use_backface_culling = True
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
    log(f"maps {MAT} {N}x{N}")
    return m, {s: Path(v).relative_to(maps.parent).as_posix() for s, v in f.items()}


# ============================================================================================ geometry helpers
def superellipse(r, phi):
    c, s = math.cos(phi), math.sin(phi)
    k = 2 / P_SE
    return CUSH[0] * r * math.copysign(abs(c) ** k, c), CUSH[1] * r * math.copysign(abs(s) ** k, s)


def cushion_top(x, y):
    r = min(1.0, ((abs(x) / CUSH[0]) ** P_SE + (abs(y) / CUSH[1]) ** P_SE) ** (1 / P_SE))
    return SEAM + BULGE * (1 - r ** 4) ** 0.6


def frame(t):
    """Two unit vectors across tangent t (no flips on the paths used here)."""
    ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
    a = t.cross(ref).normalized()
    return a, t.cross(a).normalized()


def box(P, lo, hi, q, scale=0.28):
    """Closed box with shared corners (so a bevel can round it) and planar UVs inside quadrant q."""
    xs, ys, zs = (lo[0], hi[0]), (lo[1], hi[1]), (lo[2], hi[2])
    pos = [(xs[i], ys[j], zs[k]) for k in (0, 1) for j in (0, 1) for i in (0, 1)]
    v = [P.v(p) for p in pos]

    def uv(i, a, b):
        p = pos[i]
        return L.quv(q, min(1, max(0, 0.5 + p[a] * scale)), min(1, max(0, 0.5 + p[b] * scale)))

    for face, (a, b) in (((0, 2, 3, 1), (0, 1)), ((4, 5, 7, 6), (0, 1)), ((0, 1, 5, 4), (0, 2)),
                         ((2, 6, 7, 3), (0, 2)), ((0, 4, 6, 2), (1, 2)), ((1, 3, 7, 5), (1, 2))):
        P.f([v[i] for i in face], [uv(i, a, b) for i in face])


def tube(P, pts, radius, q, sides=8, u_span=(0.02, 0.46), closed=False, cap_end=False, repeats=1.0):
    """Tube along pts (radius: number or per-point list). UV: around -> u_span of quadrant q; along -> v, `repeats` times
    over the length. A closed loop restarts v at each repeat; the strand texture runs along v, so the step is invisible."""
    n = len(pts)
    rad = radius if isinstance(radius, list) else [radius] * n
    acc = [0.0]
    for i in range(1, n):
        acc.append(acc[-1] + (pts[i] - pts[i - 1]).length)
    total = acc[-1] + ((pts[0] - pts[-1]).length if closed else 0.0)
    rings = []
    for i, p in enumerate(pts):
        nxt, prv = (pts[(i + 1) % n], pts[i - 1]) if closed else (pts[min(i + 1, n - 1)], pts[max(i - 1, 0)])
        a, b = frame((nxt - prv).normalized())
        rings.append([P.v(p + (a * math.cos(TAU * k / sides) + b * math.sin(TAU * k / sides)) * rad[i]) for k in range(sides + 1)])
    for i in range(n if closed else n - 1):
        j = (i + 1) % n
        s0 = acc[i] / total * repeats
        s1 = (acc[i] + (pts[j] - pts[i]).length) / total * repeats
        base = math.floor(s0)
        v0, v1 = 0.02 + 0.96 * (s0 - base), 0.02 + 0.96 * min(1.0, s1 - base)
        for k in range(sides):
            u0 = u_span[0] + (u_span[1] - u_span[0]) * k / sides
            u1 = u_span[0] + (u_span[1] - u_span[0]) * (k + 1) / sides
            P.f([rings[i][k], rings[i][k + 1], rings[j][k + 1], rings[j][k]],
                [L.quv(q, u0, v0), L.quv(q, u1, v0), L.quv(q, u1, v1), L.quv(q, u0, v1)])
    if cap_end:
        c = P.v(pts[-1] + (pts[-1] - pts[-2]).normalized() * rad[-1] * 0.25)
        for k in range(sides):
            P.f([rings[-1][k], rings[-1][k + 1], c], [L.quv(q, 0.25, 0.97)] * 3)


def bead(P, c, axis, d, q, spin, flat=0.88, lon=14, lat=9, hole=0.028):
    """Slightly oblate bead round axis (the cord's direction), open at both holes. lu = longitude, lv = latitude."""
    a, b = frame(axis)
    rot = Matrix.Rotation(spin, 3, axis)
    a, b = rot @ a, rot @ b
    r = d / 2
    lim = math.asin(min(0.95, hole / r))
    lats = [-(math.pi / 2 - lim) + (math.pi - 2 * lim) * i / (lat - 1) for i in range(lat)]
    rings = []
    for phi in lats:
        rings.append([P.v(c + axis * (math.sin(phi) * r * flat) + (a * math.cos(TAU * k / lon) + b * math.sin(TAU * k / lon))
                          * (math.cos(phi) * r)) for k in range(lon + 1)])
    for i in range(lat - 1):
        v0, v1 = 0.5 + lats[i] / math.pi, 0.5 + lats[i + 1] / math.pi
        for k in range(lon):
            P.f([rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k]],
                [L.quv(q, k / lon, v0), L.quv(q, (k + 1) / lon, v0), L.quv(q, (k + 1) / lon, v1), L.quv(q, k / lon, v1)])
    # the hole lips turn inward, so the dark mouth reads round the cord
    for end, sign in ((rings[0], -1), (rings[-1], 1)):
        inner = [P.v(c + axis * (sign * r * flat * 0.78) + (a * math.cos(TAU * k / lon) + b * math.sin(TAU * k / lon)) * hole)
                 for k in range(lon + 1)]
        vv = 0.0 if sign < 0 else 1.0
        for k in range(lon):
            quad = [end[k], end[k + 1], inner[k + 1], inner[k]] if sign > 0 else [end[k + 1], end[k], inner[k], inner[k + 1]]
            P.f(quad, [L.quv(q, k / lon, vv)] * 4)


def disc(P, c, axis, d, thick, q, sides=16):
    """A flat bronze spacer or cap: a short closed cylinder across axis."""
    a, b = frame(axis)
    r = d / 2
    ring = [(math.cos(TAU * k / sides), math.sin(TAU * k / sides)) for k in range(sides + 1)]
    top = [P.v(c + axis * thick / 2 + (a * x + b * y) * r) for x, y in ring]
    bot = [P.v(c - axis * thick / 2 + (a * x + b * y) * r) for x, y in ring]
    ct, cb = P.v(c + axis * thick / 2), P.v(c - axis * thick / 2)
    for k in range(sides):
        u0, u1 = k / sides, (k + 1) / sides
        P.f([bot[k], bot[k + 1], top[k + 1], top[k]], [L.quv(q, u0, 0.46), L.quv(q, u1, 0.46), L.quv(q, u1, 0.54), L.quv(q, u0, 0.54)])
        P.f([top[k], top[k + 1], ct], [L.quv(q, u0, 0.6), L.quv(q, u1, 0.6), L.quv(q, (u0 + u1) / 2, 0.66)])
        P.f([bot[k + 1], bot[k], cb], [L.quv(q, u1, 0.4), L.quv(q, u0, 0.4), L.quv(q, (u0 + u1) / 2, 0.34)])


# ============================================================================================ pieces
def build_tray():
    P = L.MB()
    ox, oy = TRAY
    box(P, (-ox + 0.04, -oy + 0.04, 0.10), (ox - 0.04, oy - 0.04, FLOOR), LACQUER)               # floor slab
    for lo, hi in (((-ox, -oy, 0.10), (ox, -oy + RIM_T, RIM_TOP)), ((-ox, oy - RIM_T, 0.10), (ox, oy, RIM_TOP)),
                   ((-ox, -oy + RIM_T, 0.10), (-ox + RIM_T, oy - RIM_T, RIM_TOP)),
                   ((ox - RIM_T, -oy + RIM_T, 0.10), (ox, oy - RIM_T, RIM_TOP))):
        box(P, lo, hi, LACQUER)
    for sx in (-1, 1):                                                                         # bracket feet
        for sy in (-1, 1):
            cx, cy = sx * (ox - 0.26), sy * (oy - 0.22)
            box(P, (cx - 0.17, cy - 0.15, 0.0), (cx + 0.17, cy + 0.15, 0.10), LACQUER)
    tray = P.build("Bellwood_AbbotTray__Lacquer", MATERIAL)
    bev = tray.modifiers.new("Bevel", "BEVEL")
    bev.width, bev.segments, bev.limit_method = 0.018, 2, "ANGLE"
    bpy.ops.object.select_all(action="DESELECT")
    tray.select_set(True)
    bpy.context.view_layer.objects.active = tray
    bpy.ops.object.modifier_apply(modifier=bev.name)
    # cushion: a superellipse pillow, top and bottom sharing the seam ring, with silk piping round the seam
    C = L.MB()
    T = [i / 24 for i in range(25)]
    ns = 112
    top_rows, bot_rows = [], []
    for t in T:
        tr, br = [], []
        for j in range(ns):
            x, y = superellipse(t, TAU * j / ns)
            if t >= 1.0:
                v = C.v((x, y, SEAM))
                tr.append(v)
                br.append(v)
            else:
                tr.append(C.v((x, y, cushion_top(x, y))))
                br.append(C.v((x, y, max(FLOOR + 0.004, SEAM - 0.4 * BULGE * (1 - t ** 4) ** 0.6))))
        top_rows.append(tr)
        bot_rows.append(br)

    def cuv(i, j):
        x, y = superellipse(T[i], TAU * j / ns)
        return L.quv(SILK, 0.75 + 0.25 * x / CUSH[0], 0.5 + 0.5 * y / CUSH[1])

    for i in range(len(T) - 1):
        for j in range(ns):
            jn = (j + 1) % ns
            if i == 0:  # ring 0 is the centre point repeated; fan it
                C.f([top_rows[0][0], top_rows[1][j], top_rows[1][jn]], [cuv(0, 0), cuv(1, j), cuv(1, jn)])
                C.f([bot_rows[0][0], bot_rows[1][jn], bot_rows[1][j]], [cuv(0, 0), cuv(1, jn), cuv(1, j)])
            else:
                C.f([top_rows[i][j], top_rows[i + 1][j], top_rows[i + 1][jn], top_rows[i][jn]],
                    [cuv(i, j), cuv(i + 1, j), cuv(i + 1, jn), cuv(i, jn)])
                C.f([bot_rows[i][jn], bot_rows[i + 1][jn], bot_rows[i + 1][j], bot_rows[i][j]],
                    [cuv(i, jn), cuv(i + 1, jn), cuv(i + 1, j), cuv(i, j)])
    ring = [Vector((*superellipse(1.0, TAU * j / 180), SEAM)) for j in range(180)]
    tube(C, ring, 0.028, SILK, sides=8, closed=True, repeats=6)
    cushion = C.build("Bellwood_AbbotTray__Cushion", MATERIAL)
    cushion.data.validate()
    # one sub-mesh for the whole tray
    bpy.ops.object.select_all(action="DESELECT")
    tray.select_set(True)
    cushion.select_set(True)
    bpy.context.view_layer.objects.active = tray
    bpy.ops.object.join()
    tray.name = tray.data.name = "Bellwood_AbbotTray__Lacquer"
    return [tray]


def coil(t, rm, d=0.12):
    """Closed path, two turns: outer at t = 0 (the front), inner at t = 0.5; it crosses itself once, at the back."""
    th = -math.pi / 2 + 2 * TAU * t
    r = rm + d * math.cos(TAU * t)
    return Vector((r * math.cos(th), 0.74 * r * math.sin(th), 0.0))


def coil_length(rm, n=2000):
    pts = [coil(i / n, rm) for i in range(n + 1)]
    return sum((pts[i + 1] - pts[i]).length for i in range(n))


def build_beads():
    rng = random.Random(709)
    marker = lambda i: i % 9 == 0 and 0 < i < COUNT  # noqa: E731
    diam = [HEAD_D] + [MARK_D if marker(i) else BEAD_D * rng.uniform(0.97, 1.03) for i in range(1, COUNT + 1)]
    spacer = 0.045
    need = sum(diam) + 2 * spacer + 0.004 * (COUNT + 1)
    lo, hi = 0.5, 1.3
    for _ in range(40):                                     # the radius whose two turns hold the string without slack
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if coil_length(mid) < need else (lo, mid)
    rm = (lo + hi) / 2
    n = 4000
    pts = [coil(i / n, rm) for i in range(n)]
    acc = [0.0]
    for i in range(1, n):
        acc.append(acc[-1] + (pts[i] - pts[i - 1]).length)
    total = acc[-1] + (pts[0] - pts[-1]).length
    gap = (total - sum(diam) - 2 * spacer) / (COUNT + 1)

    def at(s):
        s %= total
        k = max(0, min(n - 1, int(np.searchsorted(acc, s)) - 1))
        p0, p1 = pts[k], pts[(k + 1) % n]
        seg = (p1 - p0).length or 1e-9
        return p0.lerp(p1, (s - acc[k]) / seg), (p1 - p0).normalized(), k / n

    def lift(p, tt, d):
        over = math.exp(-((tt - 0.75) / 0.035) ** 2)       # the second turn rides over the first where they cross
        return Vector((p.x, p.y, cushion_top(p.x, p.y) + d / 2 - 0.012 + over * 0.15))

    B, Cd = L.MB(), L.MB()
    s = 0.0
    centres = []
    for i, d in enumerate(diam):
        if i == 1:
            s += spacer + gap
        s += d / 2
        p, t, tt = at(s)
        c = lift(p, tt, d)
        head = i == 0
        bead(B, c, t, d, JADE if head or marker(i) else BRONZE, rng.uniform(0, TAU), flat=0.9 if head else 0.86,
             lon=18 if head else 14, lat=11 if head else 9)
        centres.append((s, c, t))
        s += d / 2 + gap
    for ds in (HEAD_D / 2 + spacer / 2 + 0.004, -(HEAD_D / 2 + spacer / 2 + 0.004)):   # spacers flank the head bead
        p, t, tt = at(ds)
        disc(Cd, lift(p, tt, 0.13), t, 0.13, 0.035, BRONZE)
    cord = []
    for i in range(360):                                    # the cord: one closed loop through every bead
        p, _, tt = at(total * i / 360)
        cord.append(lift(p, tt, BEAD_D))
    tube(Cd, cord, 0.022, SILK, sides=6, closed=True, repeats=12)
    # the tassel leaves the head bead towards the front, over the cushion edge and the tray rim, down to the altar top
    _, head_c, _ = centres[0]
    root = head_c + Vector((0, -(HEAD_D / 2 + 0.01), -0.02))
    ft = -TRAY[1]
    guide = [root, Vector((root.x, -CUSH[1] + 0.06, root.z - 0.01)), Vector((root.x + 0.01, -CUSH[1] - 0.02, SEAM + 0.02)),
             Vector((root.x + 0.02, ft + RIM_T + 0.03, FLOOR + 0.07)), Vector((root.x + 0.03, ft + 0.05, RIM_TOP + 0.06)),
             Vector((root.x + 0.035, ft - 0.05, RIM_TOP - 0.02)), Vector((root.x + 0.04, ft - 0.085, 0.22)),
             Vector((root.x + 0.045, ft - 0.095, 0.03))]
    fine = []
    for i in range(len(guide) - 1):                         # Catmull-Rom through the guide points
        p0, p1, p2, p3 = guide[max(i - 1, 0)], guide[i], guide[i + 1], guide[min(i + 2, len(guide) - 1)]
        for k in range(6):
            u = k / 6
            fine.append(0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3))
    fine.append(guide[-1])
    bead(Cd, fine[1], (fine[2] - fine[0]).normalized(), 0.10, BRONZE, 0.4, flat=0.8, lon=12, lat=7)  # counter bead
    neck = 5                                                # silk wrapped tight for the first stretch below it
    tube(Cd, fine[2:neck + 1], [0.032 + 0.004 * i for i in range(neck - 1)], SILK, sides=10, u_span=(0.26, 0.46))
    srng = random.Random(733)
    for k in range(26):                                     # the loose strands: fanned flat where they drape
        ang, rho = srng.uniform(0, TAU), math.sqrt(srng.uniform(0.04, 1.0))
        end = len(fine) - 1 - srng.choice((0, 0, 0, 1, 1, 2))
        pts = []
        for i in range(neck, end + 1):
            f = (i - neck) / max(1, len(fine) - 1 - neck)
            spread = 0.026 + 0.05 * f ** 0.7
            nxt, prv = fine[min(i + 1, len(fine) - 1)], fine[max(i - 1, 0)]
            a, b = frame((nxt - prv).normalized())
            pts.append(fine[i] + (a * math.cos(ang) + b * 0.35 * math.sin(ang)) * spread * rho)
        u0 = srng.uniform(0.02, 0.36)
        tube(Cd, pts, [0.009 * (1 - 0.35 * j / max(1, len(pts) - 1)) for j in range(len(pts))], SILK, sides=4,
             u_span=(u0, u0 + 0.08))
    beads = B.build("Bellwood_AbbotBeads__Beads", MATERIAL)
    cords = Cd.build("Bellwood_AbbotBeads__Cord", MATERIAL)
    log(f"coil rm {rm:.3f}  length {total:.2f}  gap {gap:.4f}")
    return [beads, cords]


def entry(name, objs, mapfiles, pivot, collision):
    subs = {o.name: L.tris(o) for o in objs}
    assert all(v < TRI_CAP for v in subs.values()), subs
    lo, hi = L.bbox(objs)
    return {
        "group": "Bellwood", "sub_meshes": subs, "tris_total": sum(subs.values()),
        "size_studs_xyz": [round(float(hi[i] - lo[i]), 2) for i in range(3)],
        "bbox_min": [round(float(c), 3) for c in lo], "bbox_max": [round(float(c), 3) for c in hi],
        "materials": [MAT], "file": f"{name}.glb", "builder": BUILDER,
        "no_decimation": True, "decimation": "none: built directly at game density, every sub < 17500 tris",
        "map_resolution": {"Relic": N}, "maps": mapfiles,
        "base_layer": "procedural: numpy-painted atlas, no third-party sources",
        "pivot": pivot, "collision": collision,
    }


def main():
    global MATERIAL
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(a[0] if a else ROOT / "assets/source/landmarks/bellwood_beads").resolve()
    rdir = out / "renders"
    rdir.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATERIAL, mapfiles = make_material(out / "maps")
    tray = build_tray()
    beads = build_beads()
    pivot = "shared frame: the tray's feet stand on z = 0 (glTF y = 0), centred on x = y = 0; the beads rest on its cushion"
    entries = {"Bellwood_AbbotTray": entry("Bellwood_AbbotTray", tray, mapfiles, pivot, {"Lacquer": "Box"}),
               "Bellwood_AbbotBeads": entry("Bellwood_AbbotBeads", beads, mapfiles, pivot, {"Beads": "None", "Cord": "None"})}
    for name, objs in (("Bellwood_AbbotTray", tray), ("Bellwood_AbbotBeads", beads)):
        L.export_glb(objs, out / f"{name}.glb")
        log(f"{name}: {(out / f'{name}.glb').stat().st_size / 1e3:.0f} kB; {entries[name]['sub_meshes']}; size {entries[name]['size_studs_xyz']}")
    (out / "manifest.json").write_text(json.dumps(
        {"kit": "Bellwood landmark: the Fallen Abbot's prayer beads on their lacquer tray", "pieces": entries}, indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "AbbotBeads.blend"))
    if os.environ.get("BEADS_NORENDER"):
        log("BEADS_OK (no renders)")
        return
    sc, cam, fig = L.setup_render()
    for o in sc.objects:
        if o.name == "PreviewWater":
            o.hide_render = True
    sm = bpy.data.materials.new("PreviewStone")        # an altar top to sit on, the placeholder plinth's slate
    sm.use_nodes = True
    next(n for n in sm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.11, 0.10, 0.09, 1)
    S = L.MB()
    box(S, (-2.5, -1.5, -2.6), (2.5, 1.5, 0.0), LACQUER)
    S.build("PreviewAltar", sm)
    fig.location = (4.2, 1.0, -2.6)
    ctr = Vector((0, 0, 0.3))
    L.shoot(sc, cam, ctr + Vector((-2.2, -3.6, 2.6)), ctr, 50, rdir / "AbbotBeads_q34.png")
    fig.hide_render = True
    L.shoot(sc, cam, Vector((0.25, -1.9, 1.35)), Vector((0.0, -0.55, 0.32)), 50, rdir / "AbbotBeads_close.png")
    L.shoot(sc, cam, Vector((0.0, 0.0, 4.6)), Vector((0.0, 0.0, 0.3)), 50, rdir / "AbbotBeads_top.png")
    fig.hide_render = False
    L.shoot(sc, cam, Vector((-1.0, -9.5, 5.2)), Vector((0.0, 0.0, 0.0)), 35, rdir / "AbbotBeads_player.png")
    log("BEADS_OK", entries["Bellwood_AbbotTray"]["tris_total"], entries["Bellwood_AbbotBeads"]["tris_total"])


if __name__ == "__main__":
    main()
