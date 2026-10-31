"""General Zhao v2 body: every R15 limb as its own set of constructed forms.

build(hi) returns a list of Pieces. hi=True is the detailed master (individual lamellae, lacing,
rivets, sculpted face); hi=False is the game mesh built from the same landmarks with fewer segments
and banded lamellar rows that receive the master's detail as a baked normal map.
"""
import math
import random

import bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

from lib import (V, Piece, box, curve_pts, gauss, hring, lathe, rot, slab, sring, tr, tube)

# R15 landmarks at scale 1 (Blender Z = Roblox Y), measured limb centres from the v1 manifest
NECK_Z, WAIST_Z = 1.0, -0.6
SHOULDER, ELBOW_Z, WRIST_Z = V((1.0, 0, 0.763)), 0.035, -0.725
HIP_X, HIP_Z, KNEE_Z, ANKLE_Z, SOLE_Z = 0.5, -1.0, -1.84, -2.73, -3.0
FIST = V((1.29, 0.0, -0.88))      # haft axis passes through here, along +Y
HAFT_R = 0.072


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def interp(table, z):
    """Linear interpolation of tuples keyed by z (table sorted by z ascending)."""
    if z <= table[0][0]:
        return table[0][1:]
    for (z0, *a), (z1, *b) in zip(table, table[1:]):
        if z <= z1:
            t = (z - z0) / (z1 - z0)
            return tuple(lerp(x, y, t) for x, y in zip(a, b))
    return table[-1][1:]


# torso section: z, half-width, front depth, back depth, centre y, superellipse power
TORSO = [
    (-1.05, 0.50, 0.30, 0.34, 0.0, 2.2),
    (-0.85, 0.70, 0.40, 0.44, 0.0, 2.4),
    (-0.62, 0.60, 0.36, 0.38, 0.0, 2.3),
    (-0.42, 0.45, 0.31, 0.32, 0.0, 2.2),  # armoured waist
    (-0.15, 0.51, 0.35, 0.34, 0.0, 2.2),
    (0.15, 0.66, 0.44, 0.39, 0.0, 2.3),
    (0.48, 0.79, 0.49, 0.42, 0.0, 2.4),   # chest
    (0.70, 0.80, 0.46, 0.42, 0.0, 2.5),
    (0.86, 0.74, 0.38, 0.38, 0.0, 2.4),
    (0.97, 0.46, 0.29, 0.31, -0.01, 2.2),
    (1.05, 0.22, 0.19, 0.21, -0.01, 2.0),
]


def torso_pt(theta, z, off=0.0):
    """Point on the torso surface; theta 0 = front (+Y), +pi/2 = right (+X)."""
    rx, ryf, ryb, cy, p = interp(TORSO, z)
    s, c = math.sin(theta), math.cos(theta)
    x = math.copysign(abs(s) ** (2 / p), s) * (rx + off)
    y = cy + math.copysign(abs(c) ** (2 / p), c) * ((ryf if c >= 0 else ryb) + off)
    return V((x, y, z))


def surf_normal(surf, a, z, centre):
    p = surf(a, z)
    da = surf(a + 1e-3, z) - surf(a - 1e-3, z)
    dz = surf(a, z + 1e-3) - surf(a, z - 1e-3)
    n = da.cross(dz)
    if n.length < 1e-9:
        n = p - centre(z)
    n.normalize()
    if n.dot(p - centre(z)) < 0:
        n = -n
    return n


def lamellar(pc, surf, centre, rows, hi, plate_mat="LACQUER", cord=True, lo_group=2, thick=0.016, tilt=0.05):
    """Rows of lamellae on a surface. rows: (z_top, height, a0, a1, n_plates, offset).
    Master: individual curved plates (alternately stepped so they overlap), a lacing cord per row.
    Game: one slab band per row with a notched lower edge every `lo_group` plates."""
    for r, (zt, h, a0, a1, n, off) in enumerate(rows):
        da = (a1 - a0) / n
        if hi:
            for k in range(n):
                ac = a0 + da * (k + 0.5)
                w = da * 0.66
                P = []
                for i, f in enumerate((0.0, 0.3, 0.65, 0.88, 1.0)):
                    z = zt - h * f
                    row = []
                    for j, g in enumerate((-1, -0.5, 0, 0.5, 1)):
                        shrink = 1.0 if f < 0.85 else (0.72 if f < 0.95 else 0.4)
                        a = ac + g * w * shrink
                        n_ = surf_normal(surf, a, z, centre)
                        row.append(surf(a, z) + n_ * (off + tilt * f + 0.0045 * (k % 2) + 0.002 * r))
                    P.append(row)
                slab(pc, P, thick, plate_mat, "IRON")
                # two lacing holes read as small cord stitches near the top of each plate
            if cord:
                ring = []
                zc = zt - h * 0.16
                m = max(8, n * 3)
                for k in range(m + 1):
                    a = a0 + (a1 - a0) * k / m
                    ring.append(surf(a, zc) + surf_normal(surf, a, zc, centre) * (off + tilt * 0.16 + 0.0045 + 0.002 * r + thick * 0.5 + 0.006))
                tube(pc, ring, 0.0065, 5, "CORD", cap0=True, cap1=True)
                ring = []
                zc = zt - h * 0.55
                for k in range(m + 1):
                    a = a0 + (a1 - a0) * k / m
                    ring.append(surf(a, zc) + surf_normal(surf, a, zc, centre) * (off + tilt * 0.55 + 0.0045 + 0.002 * r + thick * 0.5 + 0.005))
                tube(pc, ring, 0.005, 4, "CORD", cap0=True, cap1=True)
        else:
            cols = max(3, n // lo_group)
            P = []
            for i, f in enumerate((0.0, 1.0)):
                row = []
                for j in range(cols + 1):
                    a = a0 + (a1 - a0) * j / cols
                    z = zt - h * f + (0.035 if (f == 1.0 and 0 < j < cols) else 0.0)
                    n_ = surf_normal(surf, a, z, centre)
                    row.append(surf(a, z) + n_ * (off + tilt * f + 0.002 * r + 0.004))
                P.append(row)
            slab(pc, P, 0.03, plate_mat, "IRON")


def ragged(z, seed, amp=0.06):
    random.seed(seed)
    return z + (random.random() - 0.5) * amp


def panel(pc, xs, zs, yfun, mat, thick=0.018, fray=0.0, seed=1, trim=None, xfun=None):
    """Hanging cloth panel. xs/zs sample columns/rows; yfun(x, z) gives depth. Bottom row frays."""
    random.seed(seed)
    P = []
    for i, z in enumerate(zs):
        row = []
        for j, x in enumerate(xs):
            zz = z
            if i == len(zs) - 1 and fray:
                zz = z + (random.random() - 0.3) * fray + (fray * 0.8 if j % 3 == 1 else 0)
            xx = xfun(x, zz) if xfun else x
            row.append(V((xx, yfun(x, zz), zz)))
        P.append(row)
    slab(pc, P, thick, mat)
    if trim:  # faded azure hem band, a hair in front of the panel
        tmat, depth, side = trim
        T = []
        for i in range(2):
            f = i / 1
            row = []
            for j, x in enumerate(xs):
                zb = zs[-1] + 0.07
                z = zb + depth * (1 - f) * 0.6
                xx = xfun(x, z) if xfun else x
                row.append(V((xx, yfun(x, z) + side * 0.012, z)))
            T.append(row)
        slab(pc, T, thick * 0.6, tmat)
    random.seed(seed * 13)
    for j in range(1, len(xs) - 1):
        if random.random() < 0.45:
            top = P[-1][j]
            nxt = P[-1][j + 1]
            w = (nxt - top).length * (0.4 + 0.4 * random.random())
            ln = 0.08 + 0.2 * random.random()
            side = (nxt - top).normalized()
            dn = V((0, 0, -1))
            S = [[top + side * (g * w * (1 - 0.6 * f)) + dn * (ln * f) + V((0, 0.02 * f * (random.random() - 0.5), 0))
                  for g in (0.0, 0.5, 1.0)] for f in (-0.1, 0.5, 1.0)]
            slab(pc, S, thick * 0.8, mat)
    return P


def rivets(pc, pts, r, hi):
    if not hi:
        return
    for p, n in pts:
        M = Matrix.Translation(p) @ n.to_track_quat("Z", "Y").to_matrix().to_4x4()
        lathe(pc, [(r, 0.0), (r * 0.8, r * 0.55), (0.0, r * 0.75)], 8, "BRONZE", M, cap0=True)


# ---------------------------------------------------------------------------------------------------------
def head(hi):
    pc = Piece("Zhao_Head", "Head")
    Hc = V((0.0, 0.03, 1.515))
    RX, RYF, RYB, RZ = 0.236, 0.30, 0.33, 0.43
    G = gauss

    def disp(x, z):
        """Forward displacement of the face (local x, z about Hc)."""
        ax = abs(x)
        d = 0.0
        d += 0.050 * G((z - 0.072) ** 2, 0.024) * G(x * x, 0.13)              # brow ridge
        d -= 0.010 * G((ax - 0.016) ** 2, 0.008) * G((z - 0.06) ** 2, 0.03)     # glabella furrows
        d -= 0.050 * G((ax - 0.095) ** 2, 0.042) * G((z - 0.004) ** 2, 0.032)   # eye sockets
        ridge = smooth((0.06 - z) / 0.16) * (1 - smooth((-0.115 - z) / 0.03))
        d += 0.050 * G(x * x, 0.030) * ridge                                    # nose bridge
        d += 0.032 * G(x * x, 0.032) * G((z + 0.105) ** 2, 0.028)               # nose tip
        d += 0.020 * G((ax - 0.036) ** 2, 0.016) * G((z + 0.118) ** 2, 0.018)   # alae
        d -= 0.016 * G(x * x, 0.035) * G((z + 0.152) ** 2, 0.011)              # under the nose
        d += 0.026 * G((ax - 0.165) ** 2, 0.045) * G((z + 0.025) ** 2, 0.035)  # cheekbones
        d -= 0.034 * G((ax - 0.15) ** 2, 0.04) * G((z + 0.17) ** 2, 0.045)     # hollow cheeks
        nl = (ax - (0.042 + 0.36 * max(0.0, -0.12 - z))) ** 2                       # nasolabial folds
        d -= 0.010 * G(nl, 0.008) * G((z + 0.175) ** 2, 0.05)
        d += 0.012 * G(x * x, 0.048) * G((z + 0.198) ** 2, 0.013)              # upper lip
        d -= 0.012 * G(x * x, 0.06) * G((z + 0.217) ** 2, 0.006)               # mouth line (down-turned below)
        d += 0.010 * G(x * x, 0.04) * G((z + 0.236) ** 2, 0.013)               # lower lip
        d += 0.040 * G(x * x, 0.06) * G((z + 0.33) ** 2, 0.045)                # chin
        d -= 0.012 * G((ax - 0.21) ** 2, 0.03) * G((z - 0.08) ** 2, 0.05)      # temples
        d += 0.007 * G((ax - 0.095) ** 2, 0.03) * G((z + 0.036) ** 2, 0.01)    # bags under the eyes
        d -= 0.004 * G((ax - 0.10) ** 2, 0.03) * G((z + 0.05) ** 2, 0.004)     # lower lid crease
        for k in range(3):                                                     # crow's feet
            d -= 0.0035 * G((ax - 0.165) ** 2, 0.012) * G((z - (0.012 - 0.022 * k) - 0.25 * (ax - 0.165)) ** 2, 0.0035)
        d -= 0.006 * G((ax - 0.06) ** 2, 0.006) * G((z + 0.27) ** 2, 0.03)     # mouth-corner marionette lines
        # scar: diagonal over the left brow onto the cheek (character's left is -X)
        sx0, sz0, sx1, sz1 = -0.135, 0.13, -0.065, -0.10
        t = max(0, min(1, ((x - sx0) * (sx1 - sx0) + (z - sz0) * (sz1 - sz0)) / ((sx1 - sx0) ** 2 + (sz1 - sz0) ** 2)))
        dd = (x - (sx0 + t * (sx1 - sx0))) ** 2 + (z - (sz0 + t * (sz1 - sz0))) ** 2
        d -= 0.007 * G(dd, 0.006)
        return d, dd

    nlon, nlat = (128, 96) if hi else (40, 30)
    rows, scar_faces = [], []
    for i in range(nlat + 1):
        ph = -math.pi / 2 + math.pi * i / nlat
        row = []
        for j in range(nlon):
            lam = 2 * math.pi * j / nlon
            cx, cy, sz = math.cos(ph) * math.sin(lam), math.cos(ph) * math.cos(lam), math.sin(ph)
            x = RX * cx
            y = (RYF if cy >= 0 else RYB) * cy
            z = RZ * sz
            if z < 0:
                k = min(1.0, -z / RZ)
                x *= 1 - 0.34 * k ** 1.5
                if y < 0:
                    y *= 1 - 0.40 * k
                else:
                    y *= 1 - 0.10 * k * k
            if z < -0.1 and y > 0:  # square jaw corners
                x *= 1 + 0.10 * G((z + 0.24) ** 2, 0.06) * G((abs(x) - 0.18) ** 2, 0.05) / max(0.3, 1)
            if y > 0:
                w = smooth(y / 0.18)
                d, _ = disp(x, z)
                y += d * w
                x += math.copysign(0.012, x) * G((abs(x) - 0.17) ** 2, 0.04) * G((z + 0.03) ** 2, 0.04) * w
            row.append(Hc + V((x, y, z)))
        rows.append(row)
    vs, faces = pc.grid(rows, "SKIN", closed_u=True)
    if hi:
        for f in faces:
            c = f.calc_center_median() - Hc
            if c.y > 0.1:
                _, dd = disp(c.x, c.z)
                if dd < 0.00012:
                    f.material_index = pc.mi("SCAR")

    bvh = BVHTree.FromBMesh(pc.bm)

    def face_pt(x, z, out=0.0):
        """Front surface point of the sculpted face at local x, z (ray cast from the front)."""
        hit = bvh.ray_cast(Hc + V((x, 1.0, z)), V((0, -1, 0)))
        p = hit[0] if hit[0] is not None else Hc + V((x, RYF * 0.8, z))
        return p + V((0, out, 0))

    # eyes (deep set) and heavy lids
    for s in (-1, 1):
        e = face_pt(s * 0.093, 0.004) + V((0, -0.02, 0))
        lathe(pc, [(0.0, -0.03), (0.009, -0.0287), (0.0166, -0.025), (0.0225, -0.0195), (0.027, -0.012), (0.03, 0.0), (0.026, 0.02), (0.0, 0.03)], 16 if hi else 6, "EYE",
              tr(e) @ rot("X", 90), cap0=False)
        lid = [face_pt(s * (0.055 + 0.08 * t), 0.022 + 0.012 * math.sin(math.pi * t) - 0.012 * (1 - t), -0.004)
               for t in [k / 7 for k in range(8)]]
        tube(pc, lid, lambda t: 0.011 * math.sin(math.pi * (0.1 + 0.8 * t)) + 0.004, 6 if hi else 4, "SKIN", flat=0.6)
        low = [face_pt(s * (0.06 + 0.07 * t), -0.022 - 0.006 * math.sin(math.pi * t), -0.006) for t in [k / 6 for k in range(7)]]
        tube(pc, low, lambda t: 0.006 * math.sin(math.pi * (0.1 + 0.8 * t)) + 0.003, 5 if hi else 4, "SKIN", flat=0.7)
    def groom(guide, width, thick, count, seed, out=0.004, lo_n=4):
        """A hair mass along a guide: a dark core (the game mesh keeps only this) plus, on the master,
        individual tapered strands fanned across the guide's width so it reads as hair, not a slab."""
        guide = curve_pts(guide, 12 if hi else 6)
        tube(pc, guide, lambda t: (thick(t) * (0.55 if hi else 1.0), width(t) * (0.7 if hi else 1.0)),
             8 if hi else lo_n, "HAIR_CORE" if hi else "HAIR", up=V((0, 1, 0)))
        if not hi:
            return
        rnd = random.Random(seed)
        T = [(guide[min(len(guide) - 1, i + 1)] - guide[max(0, i - 1)]).normalized() for i in range(len(guide))]
        for _ in range(count):
            u = rnd.uniform(-1, 1)
            t0, t1 = rnd.uniform(0.0, 0.18), rnd.uniform(0.78, 1.0)
            lift = rnd.uniform(0.2, 1.0)
            ph = rnd.uniform(0, 6.28)
            pts = []
            for k in range(7):
                t = t0 + (t1 - t0) * k / 6
                f = t * (len(guide) - 1)
                i = min(len(guide) - 2, int(f))
                c = guide[i].lerp(guide[i + 1], f - i)
                tg = T[i].lerp(T[i + 1], f - i).normalized()
                side = tg.cross(V((0, 1, 0)))
                side = side.normalized() if side.length > 1e-6 else V((1, 0, 0))
                nrm = side.cross(tg).normalized()
                if nrm.y < 0:
                    nrm = -nrm
                pts.append(c + side * (u * width(t) + 0.004 * math.sin(ph + 4 * t))
                           + nrm * ((1 - u * u) * thick(t) * 0.8 * lift + out))
            r0 = rnd.uniform(0.0022, 0.0040)
            tube(pc, curve_pts(pts, 9), lambda t, r0=r0: r0 * (1 - 0.85 * t) + 0.0006, 4,
                 "HAIR", cap0=False, cap1=True)

    # brows: thick, angled down toward the centre (stern); the left one is broken by the scar
    for s in (-1, 1):
        segs = [(0.0, 1.0)] if s > 0 else [(0.0, 0.42), (0.6, 1.0)]
        for t0, t1 in segs:
            pts = []
            for k in range(6):
                t = t0 + (t1 - t0) * k / 5
                pts.append(face_pt(s * (0.026 + 0.14 * t), 0.048 + 0.045 * t - 0.012 * t * t, 0.004))
            if s < 0:
                pts.reverse()
            span = t1 - t0
            groom(pts, lambda t, a=t0, b=t1, s=s: 0.019 * math.sin(math.pi * (0.12 + 0.8 * t)) * (1.2 - 0.5 * (a + (b - a) * (t if s > 0 else 1 - t))) + 0.003,
                  lambda t: 0.008, int(55 * span) + 6, 11 + s + int(10 * t0))
    # moustache: from under the nose, drooping past the mouth corners
    for s in (-1, 1):
        pts = [face_pt(s * 0.008, -0.158, 0.010), face_pt(s * 0.05, -0.172, 0.012), face_pt(s * 0.082, -0.205, 0.008),
               face_pt(s * 0.094, -0.26, 0.010) + V((0, 0.01, 0)), face_pt(s * 0.098, -0.33, 0.008) + V((0, 0.03, 0))]
        groom(pts, lambda t: 0.020 * (1 - 0.75 * t) + 0.003, lambda t: 0.011 * (1 - 0.6 * t) + 0.003, 70, 30 + s, lo_n=5)
    # pointed goatee
    pts = [face_pt(0, -0.25, 0.006), face_pt(0, -0.31, 0.012), face_pt(0, -0.37, 0.018) + V((0, 0.01, 0)),
           Hc + V((0, 0.335, -0.44)), Hc + V((0, 0.355, -0.50))]
    groom(pts, lambda t: 0.045 * (1 - t) ** 0.9 + 0.003, lambda t: 0.026 * (1 - t) + 0.003, 110, 40, lo_n=5)
    # neck
    tube(pc, [V((0, -0.02, 0.96)), V((0, -0.01, 1.12)), V((0, 0.0, 1.3))], lambda t: (0.155, 0.15), 16 if hi else 8,
         "SKIN", cap0=True, cap1=False)
    # ears hidden under cheek guards: sideburn hair mass instead
    for s in (-1, 1):
        lathe(pc, [(0.0, -0.08), (0.06, -0.06), (0.07, 0.0), (0.05, 0.06), (0.0, 0.08)], 10 if hi else 6, "HAIR",
              tr(Hc + V((s * 0.225, -0.04, 0.02))) @ rot("Y", 90), sx=1.0, sy=1.4)

    # ---- helm -------------------------------------------------------------------------------------------
    nh = 96 if hi else 24
    bump = (lambda t: 1 + 0.018 * abs(math.cos(4 * t)) ** 12) if hi else None
    prof = [(0.300, 1.665), (0.306, 1.74), (0.302, 1.82), (0.285, 1.90), (0.25, 1.97), (0.19, 2.03), (0.11, 2.07),
            (0.05, 2.088), (0.0, 2.092)]
    rows = []
    for r, z in prof:
        rows.append(sring(V((0, 0.0, z)), V((1, 0, 0)), V((0, 1, 0)), r, r * 1.14, nh, 2.0, 0.0, None, bump))
    pc.grid(rows, "IRON", closed_u=True, cap1=True)
    # inner rim so the bowl has thickness at the opening
    rows = [sring(V((0, 0.0, 1.665)), V((1, 0, 0)), V((0, 1, 0)), 0.300, 0.342, nh),
            sring(V((0, 0.0, 1.70)), V((1, 0, 0)), V((0, 1, 0)), 0.275, 0.315, nh)]
    pc.grid(rows, "LEATHER", closed_u=True)
    if hi:  # riveted iron ribs on the gores
        for k in range(8):
            a = math.pi / 8 + k * math.pi / 4
            pts = []
            for r, z in prof[:-1]:
                pts.append(V((math.sin(a) * r * 1.02, math.cos(a) * r * 1.14 * 1.02, z)))
            tube(pc, curve_pts(pts, 16), lambda t: 0.008 * (1 - 0.5 * t), 6, "IRON")
    # brow band with rivets
    band = [sring(V((0, 0, z)), V((1, 0, 0)), V((0, 1, 0)), 0.318, 0.36, nh) for z in (1.64, 1.725)]
    pc.grid(band, "IRON", closed_u=True)
    band_in = [sring(V((0, 0, z)), V((1, 0, 0)), V((0, 1, 0)), 0.300, 0.342, nh) for z in (1.725, 1.64)]
    pc.grid(band_in, "IRON", closed_u=True)
    pc.grid([band[0], band_in[1]], "IRON", closed_u=True)
    pc.grid([band_in[0], band[1]], "IRON", closed_u=True)
    rv = []
    for k in range(18):
        a = 2 * math.pi * k / 18
        p = V((math.sin(a) * 0.32, math.cos(a) * 0.362, 1.682))
        rv.append((p, V((math.sin(a), math.cos(a) / 1.14, 0)).normalized()))
    rivets(pc, rv, 0.012, hi)
    # front visor peak, angled down
    P = []
    na = 16 if hi else 7
    for i, f in enumerate((0.0, 1.0)):
        row = []
        for j in range(na + 1):
            a = math.radians(-56 + 112 * j / na)
            depth = 0.065 * math.cos(a * 1.35) ** 2 * f
            r = 1.0 + depth / 0.33
            row.append(V((math.sin(a) * 0.318 * r, math.cos(a) * 0.36 * r, 1.648 - 0.5 * depth)))
        P.append(row)
    slab(pc, P, 0.018, "IRON")
    # azure diamond crest on the brow plate
    crest = V((0, 0.392, 1.80))
    for size, mat, dy in ((0.085, "IRON", 0.0), (0.06, "ENAMEL", 0.01)):
        d = [[crest + V((0, dy, 0)) + V((math.sin(a) * size * 0.75, 0, math.cos(a) * size)) * f
              for a in [k * math.pi / 2 for k in range(5)]] for f in (0.05, 1.0)]
        slab(pc, d, 0.02, mat)
    # finial spire with a bronze ring
    lathe(pc, [(0.055, 2.06), (0.07, 2.10), (0.05, 2.14), (0.062, 2.17), (0.064, 2.19), (0.045, 2.21),
               (0.03, 2.27), (0.036, 2.30), (0.0, 2.36)], 16 if hi else 8, "IRON", cap1=True)
    lathe(pc, [(0.066, 2.165), (0.072, 2.18), (0.066, 2.195)], 16 if hi else 8, "BRONZE")
    # lamellar cheek guards and neck guard hang from the band and flare out
    def guard_surf(a, z):
        f = (1.66 - z) / 0.5
        r = 1.0 + (0.14 if math.cos(a) > -0.3 else 0.30) * f
        return V((math.sin(a) * 0.318 * r, math.cos(a) * 0.36 * r * (0.92 if math.cos(a) < 0 else 1), z))

    gc = lambda z: V((0, 0, z))
    rows = []
    for s in (-1, 1):
        a0, a1 = sorted((s * math.radians(58), s * math.radians(118)))
        rows += [(1.66, 0.17, a0, a1, 6, 0.0), (1.52, 0.17, a0, a1, 6, 0.012), (1.38, 0.16, a0, a1, 6, 0.024)]
    lamellar(pc, guard_surf, gc, rows, hi, cord=hi, lo_group=2)
    nrows = [(1.66, 0.19, math.radians(118), math.radians(242), 16, 0.0),
             (1.50, 0.19, math.radians(116), math.radians(244), 17, 0.014),
             (1.34, 0.18, math.radians(114), math.radians(246), 18, 0.028)]
    lamellar(pc, guard_surf, gc, nrows, hi, cord=hi, lo_group=2)
    # leather liner behind the guards
    P = []
    for z in (1.66, 1.17):
        row = []
        for j in range(25 if hi else 10):
            a = math.radians(58 + (302 - 58) * j / (24 if hi else 9))
            row.append(guard_surf(a, z) - V((math.sin(a), math.cos(a), 0)) * 0.012)
        P.append(row)
    slab(pc, P, 0.01, "LEATHER")
    return pc


def plumes(hi):
    pc = Piece("Zhao_Plumes", "Head")
    for s in (-1, 1):
        ctrl = [(s * 0.025, -0.005, 2.30), (s * 0.07, 0.03, 2.75), (s * 0.15, -0.04, 3.30), (s * 0.25, -0.28, 3.86),
                (s * 0.34, -0.66, 4.28), (s * 0.40, -1.08, 4.50), (s * 0.42, -1.38, 4.55)]
        n = 70 if hi else 30
        path = curve_pts(ctrl, n)
        cols = 7 if hi else 5
        P = []
        for i, c in enumerate(path):
            t = i / (n - 1)
            tang = (path[min(n - 1, i + 1)] - path[max(0, i - 1)]).normalized()
            face = V((s * 0.5, 1.0, 0.0)).normalized()
            side = tang.cross(face).normalized()
            w = 0.072 * min(1.0, t / 0.10) * (1 - t) ** 0.5 + 0.004
            row = []
            for j in range(cols):
                g = -1 + 2 * j / (cols - 1)
                serr = (0.01 * math.sin(i * 2.7 + j) if hi and abs(g) == 1 else 0.0)
                row.append(c + side * (g * w) + tang * (abs(g) * -0.03 + serr) + face * (0.012 * (1 - g * g)))
            P.append(row)
        slab(pc, P, lambda i, j: 0.012 * (1 - 0.6 * i / (n - 1)), "PLUME")
        if hi:
            tube(pc, path, lambda t: 0.013 * (1 - 0.85 * t) + 0.002, 6, "PLUME", up=V((0, 1, 0)))
        # socket tube rising from the finial
        tube(pc, [V((s * 0.012, 0.0, 2.26)), V((s * 0.03, -0.005, 2.42))], 0.018, 8 if hi else 5, "BRONZE")
    return pc


# ---------------------------------------------------------------------------------------------------------
def upper_torso(hi):
    pc = Piece("Zhao_UpperTorso", "UpperTorso")
    centre = lambda z: V((0, interp(TORSO, z)[3], z))
    nz = 26 if hi else 9
    na = 64 if hi else 22
    rows = []
    for i in range(nz + 1):
        z = -0.5 + (1.06 - -0.5) * i / nz
        rows.append([torso_pt(-math.pi + 2 * math.pi * k / na, z) for k in range(na)])
    pc.grid(rows, "CLOTH_DARK", closed_u=True, cap0=True, cap1=True)
    # cuirass: eight overlapping lamellar rows, each upper row riding over the one below
    rows = []
    zt = 0.80
    for r in range(7):
        n = 54 if r < 5 else 46
        rows.append((zt, 0.19, -math.pi + 0.01, math.pi - 0.01, n, 0.045 + 0.004 * (6 - r)))
        zt -= 0.135
    # cinched waist under the cuirass: a wrapped red sash with a faded azure edge
    for z0, z1, mat, off in ((0.0, -0.30, "CLOTH_RED", 0.05), (-0.255, -0.30, "AZURE", 0.056)):
        nz2 = 6 if hi else 2
        rows_w = [[torso_pt(-math.pi + 2 * math.pi * k / na, lerp(z0, z1, i / nz2), off + 0.012 * math.sin(i * 1.7 + k * 0.9) * (1 if hi else 0))
                   for k in range(na)] for i in range(nz2 + 1)]
        pc.grid(rows_w, mat, closed_u=True)
    lamellar(pc, torso_pt, centre, rows, hi, lo_group=1)
    # shoulder yoke: a lacquered collar plate from the top row up to the neck
    nzy = 8 if hi else 3
    rows = []
    for i in range(nzy + 1):
        z = lerp(0.70, 1.0, i / nzy)
        rows.append([torso_pt(-math.pi + 2 * math.pi * k / na, z, 0.075 - 0.02 * i / nzy) for k in range(na)])
    pc.grid(rows, "LACQUER", closed_u=True)
    rim = [torso_pt(-math.pi + 2 * math.pi * k / na, 0.70, 0.075) for k in range(na)]
    tube(pc, rim + rim[:1], 0.016, 6 if hi else 4, "IRON", cap0=False, cap1=False)
    rv = [(torso_pt(a, 0.735, 0.085), surf_normal(torso_pt, a, 0.735, centre))
          for a in [-math.pi + 2 * math.pi * k / 28 for k in range(28)]]
    rivets(pc, rv, 0.014, hi)
    # standing collar, red with a faded azure lip, over an iron gorget ring
    lathe(pc, [(0.245, 0.95), (0.262, 1.0), (0.272, 1.06), (0.285, 1.11)], 32 if hi else 12, "LACQUER", sy=1.08)
    lathe(pc, [(0.285, 1.11), (0.28, 1.125), (0.266, 1.115), (0.245, 0.97)], 32 if hi else 12, "AZURE", sy=1.08)
    # quilted neck wrap filling the collar: dark padded cloth wound around the throat
    lathe(pc, [(0.245, 0.955), (0.215, 1.0), (0.195, 1.05), (0.183, 1.10), (0.176, 1.15), (0.168, 1.18), (0.156, 1.19)],
          40 if hi else 14, "CLOTH_DARK", sy=1.05)
    if hi:
        for z in (1.0, 1.05, 1.10, 1.15):
            r = 0.245 - (z - 0.955) * 0.36
            lathe(pc, [(r - 0.004, z - 0.012), (r + 0.006, z), (r - 0.004, z + 0.012)], 40, "CLOTH_DARK", sy=1.05)
    # chest mirror: an iron disc with a small azure diamond, the oath's emblem
    cm = torso_pt(0, 0.43, 0.105)
    M = tr(cm) @ rot("X", -84)
    lathe(pc, [(0.0, 0.03), (0.13, 0.024), (0.19, 0.012), (0.205, 0.0), (0.19, -0.012), (0.0, -0.012)],
          40 if hi else 14, "IRON", M)
    lathe(pc, [(0.205, 0.004), (0.215, 0.012), (0.205, 0.02), (0.19, 0.016)], 40 if hi else 14, "BRONZE", M)
    for size, mat, dy in ((0.095, "IRON", 0.032), (0.07, "ENAMEL", 0.042)):
        d = [[cm + V((0, dy, 0)) + V((math.sin(a) * size * 0.75, 0, math.cos(a) * size)) * f
              for a in [k * math.pi / 2 for k in range(5)]] for f in (0.05, 1.0)]
        slab(pc, d, 0.016, mat)
    # crossed leather straps holding the back frame
    for s in (-1, 1):
        pts = [torso_pt(s * 0.55, 0.98, 0.1), torso_pt(s * 2.3, 0.82, 0.10), torso_pt(s * 2.7, 0.25, 0.08),
               torso_pt(-s * 2.9, -0.15, 0.08)]
        tube(pc, curve_pts(pts, 18 if hi else 7), (0.035, 0.008), 6 if hi else 4, "LEATHER", up=V((0, 0, 1)), p=4)
    return pc


def pennants(hi):
    pc = Piece("Zhao_Pennants", "UpperTorso")
    # iron back frame bolted between the straps
    P = [[V((x, -0.55 - 0.02 * (1 - abs(x) / 0.5), z)) for x in (-0.5, -0.25, 0.0, 0.25, 0.5)] for z in (0.25, 0.85)]
    slab(pc, P, 0.03, "IRON")
    for s in (-1, 1):
        base, top = V((s * 0.40, -0.58, 0.12)), V((s * 0.62, -0.84, 3.62))
        axis = (top - base).normalized()
        # sockets
        for z0 in (0.2, 0.75):
            c = base + axis * ((z0 - base.z) / axis.z)
            tube(pc, [c - axis * 0.07, c + axis * 0.07], 0.05, 10 if hi else 6, "IRON")
        tube(pc, [base, top], lambda t: 0.036 - 0.01 * t, 10 if hi else 6, "POLE")
        M = tr(top) @ axis.to_track_quat("Z", "Y").to_matrix().to_4x4()
        lathe(pc, [(0.04, -0.02), (0.045, 0.02), (0.02, 0.05), (0.055, 0.09), (0.035, 0.17), (0.0, 0.27)],
              8 if hi else 4, "IRON", M, cap0=True, p=2.0 if hi else 2.0)
        # flag: hung from a short back arm, trailing backward and a little outward, torn at the foot
        arm0 = base + axis * ((3.36 - base.z) / axis.z)
        back = V((s * 0.18, -1.0, 0.0)).normalized()
        tube(pc, [arm0, arm0 + back * 0.46], 0.016, 6 if hi else 4, "POLE")
        nu, nv = (12, 22) if hi else (4, 7)
        random.seed(7 + s)
        Pf = []
        for i in range(nv + 1):
            v = i / nv
            row = []
            for j in range(nu + 1):
                u = j / nu
                z = 3.34 - 1.35 * v
                width = 0.44 * (1 - 0.18 * v)
                p = arm0 + axis * ((z - arm0.z) / axis.z) + back * (u * width)
                side = axis.cross(back).normalized()
                p += side * (0.05 * math.sin(u * 5.0 + v * 2.2) * (0.4 + u) + 0.03 * v)
                if i == nv:
                    p.z += (0.16 * (1 - abs(u - 0.5) * 2) if u > 0.15 else 0) + (random.random() - 0.5) * (0.05 if hi else 0.02)
                row.append(p)
            Pf.append(row)
        slab(pc, Pf, 0.012, "CLOTH_RED")
        tt = arm0 + back * 0.46
        tube(pc, [tt, tt + V((0, 0, -0.06))], 0.012, 6 if hi else 4, "BRONZE")
        tube(pc, [tt + V((0, 0, -0.05)), tt + V((0, -0.01, -0.2)), tt + V((0, -0.03, -0.42))],
             lambda t: 0.018 + 0.03 * t, 8 if hi else 5, "CLOTH_RED")
        # azure diamond on both faces near the top
        side = axis.cross(back).normalized()
        c = arm0 + axis * ((3.07 - arm0.z) / axis.z) + back * 0.22 + side * 0.035 * math.sin(0.22 / 0.44 * 2.6 + 0.4)
        for sd in (-1, 1):
            d = [[c + side * (sd * 0.009) + (back * math.sin(a) * 0.09 + V((0, 0, 1)) * math.cos(a) * 0.12) * f
                  for a in [k * math.pi / 2 for k in range(5)]] for f in (0.05, 1.0)]
            slab(pc, d, 0.004, "AZURE")
    return pc


# ---------------------------------------------------------------------------------------------------------
def lower_torso(hi):
    pc = Piece("Zhao_LowerTorso", "LowerTorso")
    centre = lambda z: V((0, 0, z))
    na = 56 if hi else 16
    nz = 14 if hi else 5
    rows = []
    for i in range(nz + 1):
        z = lerp(-1.05, -0.28, i / nz)
        rows.append([torso_pt(-math.pi + 2 * math.pi * k / na, z) for k in range(na)])
    pc.grid(rows, "CLOTH_DARK", closed_u=True, cap0=True, cap1=True)
    # broad leather belt with iron plaques
    belt = lambda a, z: torso_pt(a, z, 0.085)
    P = [[belt(-math.pi + 0.01 + (2 * math.pi - 0.02) * k / na, z) for k in range(na + 1)] for z in (-0.27, -0.56)]
    slab(pc, P, 0.03, "LEATHER")
    nplq = 14
    for k in range(nplq):
        a = -math.pi + 2 * math.pi * (k + 0.5) / nplq
        if abs(a) < 0.3:
            continue
        Pq = [[belt(a + g * 0.16, z) + surf_normal(belt, a, z, centre) * 0.02 for g in (-1, 0, 1)] for z in (-0.31, -0.42, -0.52)]
        slab(pc, Pq, 0.016, "IRON")
        if hi:
            rivets(pc, [(belt(a + g * 0.12, -0.415) + surf_normal(belt, a, -0.415, centre) * 0.03,
                         surf_normal(belt, a, -0.415, centre)) for g in (-1, 1)], 0.011, hi)
    # buckle: iron frame with a small azure diamond
    b = belt(0, -0.415) + V((0, 0.03, 0))
    box(pc, b, (0.26, 0.04, 0.2), "IRON", bevel=0.012 if hi else 0.0)
    d = [[b + V((0, 0.025, 0)) + V((math.sin(a) * 0.05, 0, math.cos(a) * 0.065)) * f for a in [k * math.pi / 2 for k in range(5)]]
         for f in (0.05, 1.0)]
    slab(pc, d, 0.012, "ENAMEL")
    # rear coat panels, split, 0.3+ clear behind the legs
    for s in (-1, 1):
        xs = [s * lerp(0.05, 0.72, k / (16 if hi else 6)) for k in range((16 if hi else 6) + 1)]
        zs = [lerp(-0.48, -2.56, k / (30 if hi else 10)) for k in range((30 if hi else 10) + 1)]

        def yb(x, z):
            top = -0.51 * max(0.0, 1 - (abs(x) / 0.8) ** 2.4) ** (1 / 2.4)
            f = smooth((-0.48 - z) / 1.0)
            fold = 0.035 * math.sin(abs(x) * 13.0 + 1.0) * smooth((-0.8 - z) / 1.5)
            return top * (1 - f) + (-0.64 - 0.06 * (abs(x) / 0.72) ** 2) * f - 0.06 * max(0, (-1.5 - z)) + fold

        xf = lambda x, z: x * (1 + 0.12 * smooth((-0.6 - z) / 1.8))
        panel(pc, xs, zs, yb, "CLOTH_RED", 0.02, fray=0.1, seed=11 + s, trim=("AZURE", 0.06, -1), xfun=xf)
    # oath tablet hanging at the left hip: an iron tablet split by a crack, on a frayed cord
    hp = belt(-1.35, -0.52) + V((0, 0.03, 0))
    tube(pc, [hp, hp + V((-0.02, 0.02, -0.14)), hp + V((-0.04, 0.03, -0.24))], 0.008, 5, "CORD")
    t0 = hp + V((-0.05, 0.035, -0.37))
    for k, (dz, h, tilt) in enumerate(((0.07, 0.13, 3), (-0.08, 0.15, -6))):
        M = tr(t0 + V((0.006 * k, 0, dz))) @ rot("Y", tilt) @ rot("Z", -70)
        box(pc, V(), (0.13, 0.025, h), "IRON", M, bevel=0.008 if hi else 0.0)
    return pc


# ---------------------------------------------------------------------------------------------------------
def upper_leg(hi, s):
    pc = Piece(("Zhao_RightUpperLeg" if s > 0 else "Zhao_LeftUpperLeg"), ("Right" if s > 0 else "Left") + "UpperLeg")
    X = s * 0.47
    tube(pc, [V((X, 0.0, -0.80)), V((X, 0.01, -1.35)), V((X, 0.02, -1.98))],
         lambda t: (0.30 - 0.09 * t, 0.29 - 0.07 * t), 24 if hi else 12, "CLOTH_DARK")
    # front coat panel over the thigh
    n = 12 if hi else 5
    xs = [s * lerp(0.06, 0.66, k / n) for k in range(n + 1)]
    zs = [lerp(-0.62, -2.46, k / (30 if hi else 10)) for k in range((30 if hi else 10) + 1)]
    def yf(x, z):
        drop = smooth((-0.7 - z) / 1.6)
        fold = 0.03 * math.sin((abs(x) - 0.06) * 15.0 + 0.6) * drop
        return 0.37 + 0.05 * math.cos((abs(x) - 0.36) * 4.0) + 0.10 * drop + fold

    xf = lambda x, z: x * (1 + 0.14 * smooth((-0.8 - z) / 1.6)) + s * 0.02 * smooth((-0.8 - z) / 1.6)
    panel(pc, xs, zs, yf, "CLOTH_RED", 0.02, fray=0.1, seed=31 + s, trim=("AZURE", 0.06, 1), xfun=xf)
    # side panel bridging front and back on the outside of the leg
    ys = [lerp(0.30, -0.42, k / (8 if hi else 4)) for k in range((8 if hi else 4) + 1)]
    zs2 = [lerp(-0.66, -2.36, k / (26 if hi else 8)) for k in range((26 if hi else 8) + 1)]
    random.seed(41 + s)
    P = []
    for i, z in enumerate(zs2):
        row = []
        for y in ys:
            zz = z + ((random.random() - 0.4) * 0.09 if i == len(zs2) - 1 else 0)
            row.append(V((s * (0.80 + 0.07 * smooth((-0.8 - zz) / 1.5) - 0.06 * (y / 0.4) ** 2), y, zz)))
        P.append(row)
    slab(pc, P, 0.02, "CLOTH_DARK")
    # lamellar tasset over the outer front of the thigh
    ax = V((X, 0.02, 0))
    tsurf = lambda a, z: V((X + math.sin(a) * (0.40 + 0.10 * (-0.62 - z)), 0.03 + math.cos(a) * (0.43 + 0.08 * (-0.62 - z)), z))
    a0, a1 = (-0.15, 2.0) if s > 0 else (-2.0, 0.15)
    rows = [(-0.62 - 0.16 * r, 0.2, a0, a1, 16, 0.0 + 0.016 * r) for r in range(3)]
    lamellar(pc, tsurf, lambda z: V((X, 0.02, z)), rows, hi, lo_group=2)
    # iron top rail the tasset hangs from
    rail = [tsurf(a0 + (a1 - a0) * k / 16, -0.61) for k in range(17)]
    tube(pc, rail, 0.018, 6 if hi else 4, "IRON")
    return pc


def lower_leg(hi, s):
    pc = Piece(("Zhao_RightLowerLeg" if s > 0 else "Zhao_LeftLowerLeg"), ("Right" if s > 0 else "Left") + "LowerLeg")
    X = s * 0.47
    nz, na = (22, 28) if hi else (6, 10)
    rows = []
    for i in range(nz + 1):
        z = lerp(-1.70, -2.76, i / nz)
        t = i / nz
        calf = gauss((t - 0.28) ** 2, 0.18)
        rx = 0.15 + 0.06 * calf - 0.02 * t
        rows.append(sring(V((X, 0.01, z)), V((1, 0, 0)), V((0, 1, 0)), rx, 0.15 + 0.02 * calf, na, 2.2, -math.pi / 2,
                          0.15 + 0.09 * calf))
    pc.grid(rows, "CLOTH_DARK", closed_u=True, cap0=True, cap1=True)
    # puttee wraps
    for z in ([-1.98 - 0.07 * k for k in range(9)] if hi else [-2.1, -2.4]):
        t = (-1.70 - z) / 1.06
        calf = gauss((t - 0.28) ** 2, 0.18)
        rx = 0.15 + 0.06 * calf - 0.02 * t + 0.008
        ring = sring(V((X, 0.01, z)), V((1, 0, 0)), V((0, 1, 0)), rx, 0.158 + 0.02 * calf, na, 2.2, -math.pi / 2,
                     0.158 + 0.09 * calf)
        tube(pc, ring + ring[:1], 0.012 if hi else 0.015, 4, "LEATHER", cap0=False, cap1=False)
    # splinted iron greave on the shin
    gsurf = lambda a, z: V((X + math.sin(a) * 0.19, 0.03 + math.cos(a) * (0.20 + 0.03 * (z + 2.0)), z))
    nspl = 5
    for k in range(nspl):
        a = -1.05 + 2.1 * (k + 0.5) / nspl
        P = []
        for z in ([lerp(-1.96, -2.64, f) for f in (0, 0.25, 0.5, 0.75, 1)] if hi else (-1.96, -2.64)):
            row = []
            for g in (-1, 0, 1):
                aa = a + g * 0.2
                row.append(gsurf(aa, z) + V((math.sin(aa), math.cos(aa), 0)) * (0.02 + 0.006 * (k % 2) + 0.02 * max(0, -2.5 - z)))
            P.append(row)
        slab(pc, P, 0.022, "IRON")
    for z in (-2.0, -2.58):
        band = [gsurf(-1.2 + 2.4 * k / 12, z) + V((math.sin(-1.2 + 2.4 * k / 12), math.cos(-1.2 + 2.4 * k / 12), 0)) * 0.045
                for k in range(13)]
        tube(pc, band, 0.016, 6 if hi else 4, "LEATHER", up=V((0, 0, 1)))
    # knee cop (poleyn) with side wings
    kc = V((X, 0.19, -1.84))
    M = tr(kc) @ rot("X", -90)
    lathe(pc, [(0.0, 0.10), (0.07, 0.085), (0.12, 0.05), (0.15, 0.0), (0.155, -0.02), (0.13, -0.01)],
          24 if hi else 10, "IRON", M, sx=1.0, sy=1.2)
    for g in (-1, 1):
        Mw = tr(kc + V((g * 0.13, -0.08, 0))) @ rot("Z", g * 70)
        box(pc, V(), (0.16, 0.025, 0.2), "IRON", Mw, bevel=0.01 if hi else 0.0)
    return pc


def foot(hi, s):
    pc = Piece(("Zhao_RightFoot" if s > 0 else "Zhao_LeftFoot"), ("Right" if s > 0 else "Left") + "Foot")
    X = s * 0.47
    n = 26 if hi else 9
    rows = []
    for i in range(n + 1):
        t = i / n
        y = lerp(-0.22, 0.46, t)
        top = SOLE_Z + lerp(0.36, 0.13, smooth((t - 0.2) / 0.7)) + 0.07 * smooth((t - 0.88) / 0.12)
        bot = SOLE_Z + 0.05 + 0.06 * smooth((t - 0.86) / 0.14)
        w = 0.155 * (1 - 0.25 * smooth((t - 0.7) / 0.3)) * (1 - 0.65 * smooth((t - 0.93) / 0.07)) + 0.01
        h = (top - bot) / 2
        c = V((X, y, (top + bot) / 2))
        rows.append(sring(c, V((1, 0, 0)), V((0, 0, 1)), w, h, 20 if hi else 8, 2.8))
    pc.grid(rows, "LEATHER", closed_u=True, cap0=True, cap1=True, )
    # sole
    S = []
    for k in range(13 if hi else 6):
        t = k / (12 if hi else 5)
        y = lerp(-0.24, 0.43, t)
        w = 0.165 * (1 - 0.3 * smooth((t - 0.7) / 0.3)) + 0.005
        S.append([V((X - w, y, SOLE_Z + 0.03 + 0.06 * smooth((t - 0.86) / 0.14))),
                  V((X + w, y, SOLE_Z + 0.03 + 0.06 * smooth((t - 0.86) / 0.14)))])
    slab(pc, [[r[0] for r in S], [r[1] for r in S]], 0.06, "LEATHER", offset=0.0)
    # boot shaft collar and iron instep lames
    lathe(pc, [(0.17, -2.78), (0.18, -2.70), (0.175, -2.62), (0.16, -2.60)], 20 if hi else 8, "LEATHER", tr((X, -0.02, 0)), sy=1.1)
    for k in range(3):
        y = 0.05 + k * 0.1
        top = SOLE_Z + lerp(0.36, 0.13, smooth(((y + 0.22) / 0.68 - 0.2) / 0.7)) + 0.012
        P = [[V((X + math.sin(a) * 0.15, y + dy, top - 0.04 + math.cos(a) * 0.05)) for a in (-1.2, -0.6, 0, 0.6, 1.2)]
             for dy in (-0.06, 0.06)]
        slab(pc, P, 0.016, "IRON", offset=0.01 + 0.004 * k)
    return pc


# ---------------------------------------------------------------------------------------------------------
ARM_TOP, ARM_ELBOW, ARM_WRIST = V((1.11, 0, 0.92)), V((1.20, 0.0, 0.03)), V((1.27, 0.0, -0.70))


def sx(v, s):
    return V((v.x * s, v.y, v.z))


def upper_arm(hi, s):
    pc = Piece(("Zhao_RightUpperArm" if s > 0 else "Zhao_LeftUpperArm"), ("Right" if s > 0 else "Left") + "UpperArm")
    a0, a1 = sx(ARM_TOP, s), sx(ARM_ELBOW, s)
    path = curve_pts([a0 + V((0, 0, 0.04)), a0.lerp(a1, 0.5) + V((s * 0.02, 0, 0)), a1 - V((0, 0, 0.05))], 14 if hi else 5)
    tube(pc, path, lambda t: 0.205 + 0.03 * math.sin(math.pi * t) - 0.03 * t, 24 if hi else 12, "CLOTH_RED")
    if s < 0:  # the failed oath: a faded azure cord knotted round the left arm, tails cut short
        c = a0.lerp(a1, 0.62)
        ring = [c + V((math.cos(t) * 0.215, math.sin(t) * 0.215, 0.012 * math.sin(3 * t))) for t in
                [2 * math.pi * k / 24 for k in range(25)]]
        tube(pc, ring, 0.016, 6 if hi else 4, "AZURE", cap0=False, cap1=False)
        k0 = c + V((-0.215, 0.05, 0))
        lathe(pc, [(0.0, -0.03), (0.03, -0.02), (0.035, 0.0), (0.028, 0.025), (0.0, 0.03)], 10 if hi else 6, "AZURE", tr(k0))
        for dy, ln in ((0.03, 0.42), (0.07, 0.3)):
            tube(pc, curve_pts([k0, k0 + V((-0.03, dy, -0.12)), k0 + V((-0.02, dy + 0.02, -ln))], 8 if hi else 4),
                 lambda t: (0.016 * (1 - 0.3 * t), 0.007), 6 if hi else 4, "AZURE", up=V((1, 0, 0)))
    # pauldron: domed cap plus four flaring lames on the outside of the arm
    ax = (a1 - a0).normalized()
    out = V((s, 0, 0))
    fwd = V((0, 1, 0))

    def psurf(a, z):
        # bell of lames around the arm axis, a = 0 is outward (+X side for s=1)
        t = (0.80 - z)
        c = a0 + ax * ((a0.z - z) / max(1e-3, -ax.z))
        r = 0.30 + 0.20 * t
        return c + out * (math.cos(a) * r) + fwd * (math.sin(a) * r * 1.08)

    pcen = lambda z: a0 + ax * ((a0.z - z) / max(1e-3, -ax.z))
    rows = [(0.80 - 0.125 * k, 0.185, -1.95, 1.95, 15, 0.0 + 0.02 * k) for k in range(4)]
    lamellar(pc, psurf, pcen, rows, hi, lo_group=2, thick=0.02, tilt=0.04)
    # domed shoulder cap (a shell, tilted outward) riding over the joint and the first lame
    M = tr(V((s * 1.06, 0.0, 0.75))) @ rot("Y", s * 30)
    outer = [(0.0, 0.25), (0.12, 0.24), (0.23, 0.19), (0.31, 0.11), (0.355, 0.02), (0.37, -0.05)]
    inner = [(r - 0.03, z - 0.012) for r, z in outer[1:]][::-1] + [(0.0, 0.22)]
    lathe(pc, outer + inner, 28 if hi else 10, "LACQUER", M, sy=1.12)
    lathe(pc, [(0.372, -0.065), (0.39, -0.045), (0.375, -0.025), (0.355, -0.04)], 28 if hi else 10, "IRON", M, sy=1.12)
    if hi:
        rv = []
        for k in range(10):
            a = -1.6 + 3.2 * k / 9 + (math.pi if s < 0 else 0)
            p = M @ V((math.cos(a) * 0.345, math.sin(a) * 0.345 * 1.12, 0.03))
            rv.append((p, (M.to_3x3() @ V((math.cos(a), math.sin(a), 0.3))).normalized()))
        rivets(pc, rv, 0.013, hi)
    return pc


def lower_arm(hi, s):
    pc = Piece(("Zhao_RightLowerArm" if s > 0 else "Zhao_LeftLowerArm"), ("Right" if s > 0 else "Left") + "LowerArm")
    e, w = sx(ARM_ELBOW, s), sx(ARM_WRIST, s)
    tube(pc, curve_pts([e + V((0, 0, 0.06)), e.lerp(w, 0.5), w], 12 if hi else 4),
         lambda t: 0.19 - 0.06 * t + 0.03 * gauss(t * t, 0.12), 22 if hi else 12, "CLOTH_RED")
    ax = (w - e).normalized()
    # iron vambrace: outer shell, inner leather half, flared at the wrist
    def bsurf(a, z, r0=0.165):
        t = (e.z - z) / (e.z - w.z)
        c = e + (w - e) * t
        r = r0 - 0.03 * t + 0.03 * smooth((t - 0.8) / 0.2)
        return c + V((s * math.cos(a) * r, math.sin(a) * r * 1.05, 0))

    for (aa, ab, mat, off) in ((-1.9, 1.9, "IRON", 0.0), (1.9, 2 * math.pi - 1.9, "LEATHER", -0.008)):
        nu, nv = (16, 12) if hi else (6, 3)
        P = [[bsurf(lerp(aa, ab, j / nu), lerp(-0.10, -0.66, i / nv), 0.165 + off) for j in range(nu + 1)] for i in range(nv + 1)]
        slab(pc, P, 0.024, mat)
    for z in (-0.20, -0.55):
        ring = [bsurf(2 * math.pi * k / 16, z, 0.19) for k in range(16)]
        tube(pc, ring + ring[:1], 0.017, 5 if hi else 4, "LEATHER", cap0=False, cap1=False)
    rv = [(bsurf(a, z, 0.19), V((s * math.cos(a), math.sin(a), 0))) for z in (-0.20, -0.55) for a in (-1.0, 0.0, 1.0)]
    rivets(pc, rv, 0.014, hi)
    # elbow cop
    M = tr(e + V((s * 0.02, -0.16, 0.0))) @ rot("X", 90)
    lathe(pc, [(0.0, 0.07), (0.07, 0.055), (0.11, 0.02), (0.115, 0.0)], 18 if hi else 8, "IRON", M, sx=1.0, sy=1.25)
    return pc


def hand(hi, s):
    pc = Piece(("Zhao_RightHand" if s > 0 else "Zhao_LeftHand"), ("Right" if s > 0 else "Left") + "Hand")
    F = sx(FIST, s)
    grip = s > 0
    R = HAFT_R + 0.036
    X, Y = V((s, 0, 0)), V((0, 1, 0))
    # wrist cuff over the vambrace end
    lathe(pc, [(0.125, -0.64), (0.142, -0.69), (0.135, -0.75), (0.11, -0.775)], 18 if hi else 8, "LEATHER",
          tr((F.x - s * 0.02, 0, 0)), sy=1.15)
    # back of the hand: a lofted metacarpal mass from the wrist to the knuckle line, palm toward the haft
    nz, na = (10, 20) if hi else (3, 8)
    rows = []
    for i in range(nz + 1):
        t = i / nz
        z = lerp(-0.70, F.z + 0.01, t)
        cx = F.x + s * (0.082 + 0.012 * math.sin(math.pi * t))
        rows.append(sring(V((cx, 0.01, z)), X, Y, 0.052 + 0.006 * t, 0.112 + 0.026 * t, na, 3.0))
    pc.grid(rows, "LEATHER", closed_u=True, cap0=True, cap1=True)
    # two iron lames over the back of the hand
    for k, (z0, z1) in enumerate(((-0.715, -0.79), (-0.78, -0.86))):
        P = [[V((F.x + s * (0.137 + 0.004 * k - 0.03 * u * u), u * (0.12 + 0.02 * k) + 0.01, z)) for u in (-1, -0.5, 0, 0.5, 1)]
             for z in (z0, z1)]
        slab(pc, P, 0.014, "IRON")
    lens = (1.0, 1.07, 1.0, 0.82)
    ys = (0.104, 0.036, -0.032, -0.096)
    wrap = 1.0 if grip else 0.72
    for f, (ly, L) in enumerate(zip(ys, lens)):
        pts = []
        n = 22 if hi else 7
        for k in range(n):
            t = k / (n - 1)
            ang = math.radians(10 - 230 * L * wrap * t)
            rr = R + (0.0 if grip else 0.025 + 0.025 * t)
            pts.append(V((F.x + s * math.cos(ang) * rr, ly - 0.01 * t * (f - 1.5), F.z + math.sin(ang) * rr)))
        knuckles = lambda t: 0.0045 * (gauss((t - 0.02) ** 2, 0.03) + gauss((t - 0.4) ** 2, 0.03) + gauss((t - 0.72) ** 2, 0.03))
        rad = lambda t, L=L, knuckles=knuckles: (0.034 * (1 - 0.22 * t) + knuckles(t)) * (0.95 if L < 0.9 else 1.0)
        tube(pc, pts, rad, 12 if hi else 6, "LEATHER", up=V((0, 1, 0)))
    # curved iron knuckle guard over the proximal joints
    P = []
    for ang in (12, -8, -30):
        a_ = math.radians(ang)
        P.append([V((F.x + s * math.cos(a_) * (R + 0.042), y, F.z + math.sin(a_) * (R + 0.042)))
                  for y in (-0.13, -0.065, 0.0, 0.065, 0.135)])
    slab(pc, P, 0.016, "IRON")
    # thumb over the front of the grip (right) or resting forward (left)
    if grip:
        th = [V((F.x + s * 0.07, 0.125, -0.74)), V((F.x + s * 0.035, 0.17, F.z + 0.075)), V((F.x - s * 0.035, 0.168, F.z + 0.07)),
              V((F.x - s * 0.095, 0.15, F.z + 0.02))]
    else:
        th = [V((F.x + s * 0.07, 0.125, -0.74)), V((F.x + s * 0.035, 0.18, F.z + 0.045)), V((F.x - s * 0.01, 0.2, F.z - 0.0)),
              V((F.x - s * 0.05, 0.195, F.z - 0.05))]
    tube(pc, curve_pts(th, 16 if hi else 6), lambda t: 0.038 * (1 - 0.25 * t) + 0.004 * gauss((t - 0.5) ** 2, 0.02),
         12 if hi else 6, "LEATHER")
    return pc


def build(hi):
    out = [head(hi), plumes(hi), upper_torso(hi), pennants(hi), lower_torso(hi)]
    for s in (1, -1):
        out += [upper_arm(hi, s), lower_arm(hi, s), hand(hi, s), upper_leg(hi, s), lower_leg(hi, s), foot(hi, s)]
    return out
