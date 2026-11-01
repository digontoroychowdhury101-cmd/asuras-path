"""Sculpted heads for the opening cast, shared by every character with its own skull profile and face.

The skull is a stack of superellipse slices (chin to crown) so the cranium, cheekbones and jaw angle are drawn, not
squashed from a sphere. Columns crowd toward the front and rows toward the face band, so the game mesh keeps the
nose, lips and brow as real geometry rather than as a normal map. Eyes are real eyeballs under heavy lid shells; the
master carries per-vertex `stubble` and `soot` weights the skin material turns into a shaved scalp, a beard shadow
and dark sunken sockets, which the bake carries to the game atlas.
"""
import math

from mathutils import Matrix
from mathutils.bvhtree import BVHTree

from lib import V, gauss, lathe, rot, slab, tr, tube

G = gauss


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def interp(table, z):
    if z <= table[0][0]:
        return table[0][1:]
    for (z0, *a), (z1, *b) in zip(table, table[1:]):
        if z <= z1:
            t = (z - z0) / (z1 - z0)
            return tuple(x + (y - x) * t for x, y in zip(a, b))
    return table[-1][1:]


def spread(n, power):
    """n angles over [-pi, pi), crowded toward 0 (the face) by `power` > 1."""
    out = []
    for k in range(n):
        u = -1 + 2 * k / n
        out.append(math.pi * math.copysign(abs(u) ** power, u))
    return out


def bands(spans):
    """Concatenated linspaces [(z0, z1, count), ...] without repeating the joins."""
    out = []
    for z0, z1, n in spans:
        for k in range(n):
            out.append(z0 + (z1 - z0) * k / n)
    out.append(spans[-1][1])
    return out


def sculpt(pc, hi, Hc, profile, disp, stubble=None, soot=None, eye=(0.088, 0.012, 0.036), lid=(14, -16),
           neck=(0.18, 0.95), ears=True):
    """Build skull, eyes, lids, ears and neck into Piece pc. profile rows: (z, rx, ry_front, ry_back, cy, power) about
    Hc; disp(x, z) -> forward offset of the face; stubble/soot(x, y, z) -> 0..1 vertex weights (master only).
    Returns face_pt(x, z, out) for placing extra features on the sculpted surface."""
    cols = spread(160 if hi else 64, 1.55)
    zs = bands([(profile[0][0], -0.32, 12 if hi else 5), (-0.32, 0.15, 80 if hi else 28), (0.15, profile[-1][0], 28 if hi else 9)])
    rows = []
    for z in zs:
        rx, ryf, ryb, cy, p = interp(profile, z)
        row = []
        for a in cols:
            s, c = math.sin(a), math.cos(a)
            x = math.copysign(abs(s) ** (2 / p), s) * rx
            y = cy + math.copysign(abs(c) ** (2 / p), c) * (ryf if c >= 0 else ryb)
            if c > 0:
                y += disp(x, z) * smooth(c / 0.45)
            row.append(Hc + V((x, y, z)))
        rows.append(row)
    weights = hi and (stubble or soot)
    if weights:  # layers first: adding one later invalidates the vertices already made
        lay_s = pc.bm.verts.layers.float.get("stubble") or pc.bm.verts.layers.float.new("stubble")
        lay_o = pc.bm.verts.layers.float.get("soot") or pc.bm.verts.layers.float.new("soot")
    vs, faces = pc.grid(rows, "SKIN", closed_u=True, cap0=True, cap1=True)
    if weights:
        for v in vs:
            q = v.co - Hc
            v[lay_s] = stubble(q.x, q.y, q.z) if stubble else 0.0
            v[lay_o] = soot(q.x, q.y, q.z) if soot else 0.0
    bvh = BVHTree.FromBMesh(pc.bm)

    def face_pt(x, z, out=0.0):
        hit = bvh.ray_cast(Hc + V((x, 1.0, z)), V((0, -1, 0)))
        p = hit[0] if hit[0] is not None else Hc + V((x, 0.25, z))
        return p + V((0, out, 0))

    ex, ez, er = eye
    up, lo = lid
    for s in (-1, 1):
        c = face_pt(s * ex, ez) - V((0, er * 0.78, 0))
        lathe(pc, [(0.0, -er), (er * 0.5, -er * 0.87), (er * 0.87, -er * 0.5), (er, 0.0), (er * 0.87, er * 0.5), (0.0, er)],
              18 if hi else 10, "EYE", tr(c) @ rot("X", 90))
        # lid shells on a slightly larger sphere: the upper one heavy, past the top of the iris; edge thickness reads
        R = er + 0.007
        for top, e0, e1 in ((True, up, 70), (False, lo, -62)):
            P = []
            nu = 12 if hi else 6
            for i in range(4 if hi else 3):
                f = i / (3 if hi else 2)
                row = []
                for j in range(nu + 1):
                    ph = math.radians(-72 + 144 * j / nu)
                    edge = math.radians(e0) * (0.55 + 0.45 * math.cos(ph * 1.15)) + (math.radians(6) * s * math.sin(ph) if top else 0.0)
                    el = edge + (math.radians(e1) - edge) * f
                    d = V((math.sin(ph) * math.cos(el) * s, math.cos(ph) * math.cos(el), math.sin(el)))
                    row.append(c + d * R)
                P.append(row)
            slab(pc, P, 0.009, "SKIN")
    if ears:
        for s in (-1, 1):
            rx_e = interp(profile, -0.02)[0]
            E = Hc + V((s * (rx_e - 0.012), -0.045, -0.025))
            az = V((s, -0.3, 0.0)).normalized()
            ay = V((0, 0, 1))
            axx = ay.cross(az).normalized()
            M = tr(E) @ Matrix((axx, ay, az)).transposed().to_4x4() @ rot("Z", s * 8)
            lathe(pc, [(0.0, -0.016), (0.55, -0.012), (0.85, -0.002), (1.0, 0.014), (0.93, 0.027), (0.75, 0.016), (0.6, 0.004),
                       (0.42, -0.002), (0.2, 0.0), (0.0, 0.002)],   # the bowl closes: no hole into the shell
                  20 if hi else 9, "SKIN", M, sx=0.058, sy=0.098)
            lathe(pc, [(0.0, -0.012), (0.024, 0.0), (0.018, 0.014), (0.0, 0.018)], 10 if hi else 5, "SKIN",
                  M @ tr((0, -0.08, -0.002)), sx=1.0, sy=1.3)
    r, z0 = neck
    tube(pc, [V((0, -0.035, z0)), V((0, -0.025, (z0 + Hc.z) / 2)), V((0, -0.02, Hc.z - 0.12))],
         lambda t: (r * (1.08 - 0.12 * t), r * (1.0 - 0.1 * t)), 20 if hi else 10, "SKIN", cap0=True, cap1=False)
    for s in (-1, 1):   # sternocleidomastoid: behind the ear down to the collarbone notch
        tube(pc, [Hc + V((s * 0.13, -0.07, -0.12)), V((s * 0.09, 0.06, (z0 + Hc.z) / 2)), V((s * 0.04, 0.12, z0 + 0.02))],
             lambda t: 0.04 * (1 - 0.3 * t), 10 if hi else 5, "SKIN")
    return face_pt
