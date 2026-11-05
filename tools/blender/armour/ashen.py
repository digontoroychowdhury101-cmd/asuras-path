"""Ashen Pilgrim: the light set and the starter, from its concept sheet, on the same fitted foundation as Cinnabar Guard.

Sheet details kept: ash robe crossed by a charcoal lapel, torn mantle over the wearer's left shoulder knotted with a bronze ring,
leather strap over the right shoulder (a V on the back), layered sash and belt with a pouch, jade disc and long red tail, torn tunic
with deep side dips over a charcoal layer, calf band and crossed leg wraps. Cloth over a thigh rides that thigh, as on Cinnabar.
"""
import math
import random

from cinnabar import SIDE, piece
from kit import (ARM_ELBOW, ARM_TOP, ARM_WRIST, LEG_X, boot, buckle, cloth_panel, hand, interp, lerp, normal, on_torso, rivets, smooth, strap, sx,
                 torn, torso_centre, torso_pt, trim)
from lib import V, curve_pts, gauss, lathe, rot, slab, sring, tr, tube


def lapel(pc, hi, side, mat, width, off, zend, aend, lift=0.0):
    """A robe edge from the collar across the chest. side = which shoulder it comes from."""
    n = 26 if hi else 12
    # starts under the standing collar; a band carried round the nape as well twisted over itself and baked inside out
    pts = [torso_pt(side * lerp(0.60, aend, i / (n - 1)), lerp(1.04, zend, i / (n - 1)), off + lift) for i in range(n)]
    rows = []
    for i, p in enumerate(pts):
        tang = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        o = (p - V((0, 0, p.z))).normalized()
        sd = o.cross(tang).normalized()
        rows.append([p + sd * (g * width) + o * (0.01 * (1 - g * g)) for g in (-1, -0.33, 0.33, 1)])
    slab(pc, rows, 0.022, mat)


def rag(pc, ring_top, ring_bot, cols, rows, mat, seed, fray, thick=0.018):
    return cloth_panel(pc, ring_top, ring_bot, thick, mat, cols, rows, seed=seed, fray=fray)


def cowl(pc, hi, a0, a1, out, rmax, drop, half, seed, mat, depth=0.11, thick=0.018, r0=0.14, wide=1.05):
    """Cloth falling over a limb from a closed dome at its top: no open sleeve mouth, whichever way the arm is raised."""
    ax = (a1 - a0).normalized()
    fwd = V((0, 1, 0))
    ln = (a1 - a0).length
    nu, nv = (56, 16) if hi else (40, 7)
    closed = half >= math.pi - 1e-3
    P = []
    for i in range(nv + 1):
        f = i / nv
        c = a0 + ax * (ln * lerp(-0.22, drop, f))
        r = lerp(r0, rmax, math.sqrt(smooth(min(1.0, f * 1.8))))
        row = []
        for j in range(nu + 1):
            a = lerp(-half, half, j / nu)
            fold = 1 + (0.075 * math.sin(a * 5 + f * 3 + seed) + 0.03 * math.sin(a * 11 - f * 4)) * smooth((f - 0.15) / 0.6)
            q = c + out * (math.cos(a) * r * fold) + fwd * (math.sin(a) * r * wide * fold)
            if i == nv:
                q += ax * (torn(0.0, j % nu if closed else j, seed, depth) * -1.0 + depth * 0.5 * (j % 2))
            row.append(q)
        P.append(row)
    slab(pc, P, thick, mat)


def upper_torso(hi):
    pc = piece("UpperTorso")
    na, nz = (64, 26) if hi else (28, 12)
    pc.grid([[torso_pt(-math.pi + 2 * math.pi * k / na, lerp(-0.56, 0.98, i / nz), 0.012 * math.sin(k * 0.9 + i * 0.8) if hi else 0.0) for k in range(na)] for i in range(nz + 1)],
            "ASH", closed_u=True, cap0=True, cap1=True)
    lathe(pc, [(0.29, 0.86), (0.24, 0.98), (0.215, 1.08), (0.20, 1.20)], 24 if hi else 12, "SKIN")
    # the standing collar over the nape, where the two lapels leave the neck
    na2 = 28 if hi else 14
    slab(pc, [[V((math.sin(a) * r, math.cos(a) * r * 1.06 - 0.01, z)) for a in [lerp(0.62, 2 * math.pi - 0.62, j / na2) for j in range(na2 + 1)]] for r, z in ((0.355, 0.98), (0.335, 1.07), (0.30, 1.15))], 0.03, "CHARCOAL_LT")
    # crossed robe: under-layer from the right, the broad charcoal lapel over it from the left
    lapel(pc, hi, 1, "ASH", 0.11, 0.024, 0.28, -0.20)
    lapel(pc, hi, 1, "PALE", 0.045, 0.034, 0.60, 0.20)
    lapel(pc, hi, -1, "PALE", 0.05, 0.040, 0.62, 0.15)
    lapel(pc, hi, -1, "CHARCOAL_LT", 0.105, 0.056, -0.30, -0.95)
    # strap over the right shoulder, a V on the back
    yoke = on_torso(0.082)
    path = strap(pc, yoke, torso_centre, [(1.10, 0.20), (0.84, 0.54), (0.72, 0.84), (1.15, 0.985), (2.25, 0.86), (2.72, 0.42), (math.pi, -0.22)], 0.115, 0.024, "LEATHER", 34 if hi else 16, hi=hi)
    p, n = path[int(len(path) * 0.22)]
    buckle(pc, p, n, V((0, 0, 1)), 0.15, 0.13, hi)
    rv = [(q + m * 0.016, m) for q, m in path[2:int(len(path) * 0.2)]]
    rivets(pc, rv[::2], 0.013, hi)
    path = strap(pc, yoke, torso_centre, [(-2.25, 0.86), (-2.72, 0.42), (-math.pi, -0.22)], 0.105, 0.022, "LEATHER", 14 if hi else 8, hi=hi)
    # the mantle's body side, sweeping from the knot on the chest over the left shoulder and down the back
    mantle = on_torso(0.105)
    knot = mantle(-0.28, 0.55)
    kn = normal(mantle, -0.28, 0.55, torso_centre)
    def layer(off, seed, drop, a0, a1):
        cols = 40
        tops, bots = [], []
        for j in range(cols + 1):
            a = lerp(a0, a1, j / cols)
            # the upper edge climbs from the knot along the lapel to the neck, then runs round the nape
            ztop = lerp(0.56, 1.02, smooth((-0.30 - a) / 0.62))
            # the hem: just under the knot, deepest at the arm, rising to the shoulder blade at the back
            zhem = lerp(0.40, 0.08 - drop, smooth((-0.30 - a) / 0.85))
            zhem = lerp(zhem, 0.62 - drop, smooth((-1.75 - a) / 0.85))
            tops.append(torso_pt(a, ztop, off))
            bots.append(torso_pt(a, zhem, off + 0.03))
        rag(pc, tops, bots, cols, 12 if hi else 5, "MANTLE", seed, 0.085)
    layer(0.128, 3, 0.10, -2.72, -0.28)
    layer(0.160, 5, -0.14, -2.45, -0.32)
    # knot: a bronze ring gathering the mantle
    M = tr(knot + kn * 0.09) @ kn.to_track_quat("Z", "Y").to_matrix().to_4x4()
    lathe(pc, [(0.035, 0.0), (0.05, 0.016), (0.066, 0.0), (0.05, -0.016), (0.035, 0.0)], 18 if hi else 10, "BRONZE", M)
    lathe(pc, [(0.0, 0.05), (0.045, 0.03), (0.055, 0.0), (0.04, -0.03), (0.0, -0.04)], 12 if hi else 8, "MANTLE", tr(knot + kn * 0.07))
    return pc


def upper_arm(hi, s):
    pc = piece(SIDE[s] + "UpperArm")
    a0, a1 = sx(ARM_TOP, s), sx(ARM_ELBOW, s)
    path = curve_pts([a0, a0.lerp(a1, 0.5), a1 + V((0, 0, -0.04))], 14 if hi else 6)
    tube(pc, path, lambda t: lerp(0.15, 0.225, smooth(t * 3)) - 0.02 * t, 26 if hi else 14, "CHARCOAL_LT")
    ax = (a1 - a0).normalized()
    out = V((s * -ax.z, 0, s * ax.x)).normalized()
    if out.x * s < 0:
        out = -out
    fwd = V((0, 1, 0))
    # loose linen short sleeve, torn above the elbow
    cowl(pc, hi, a0, a1, out, 0.315, 0.66, math.pi, 41 + s, "ASH", depth=0.10, thick=0.02, wide=1.0, r0=0.015)
    if s < 0:  # the mantle's arm side rides the arm, in two torn layers that lap the body side
        cowl(pc, hi, a0, a1, out, 0.40, 0.70, math.pi, 7, "MANTLE", depth=0.13, r0=0.24, wide=1.10)
        cowl(pc, hi, a0, a1, out, 0.44, 0.42, 2.05, 11, "MANTLE", depth=0.12, r0=0.30, wide=1.14)
    return pc


def lower_arm(hi, s):
    pc = piece(SIDE[s] + "LowerArm")
    e, w = sx(ARM_ELBOW, s), sx(ARM_WRIST, s)
    tube(pc, curve_pts([e + V((-s * 0.025, 0, 0.17)), e, e.lerp(w, 0.5), w], 16 if hi else 7), lambda t: 0.205 - 0.06 * t, 26 if hi else 14, "SKIN")
    ax = (w - e).normalized()
    # charcoal forearm wrappings in overlapping turns, with crossed red cords
    nturn = 7
    out = V((s, 0, 0))
    fwd = V((0, 1, 0))
    def around(v, a, grow):
        c = e.lerp(w, v)
        r = lerp(0.222, 0.165, v) + grow
        side = fwd.cross(ax).normalized()
        return c + side * (math.cos(a) * r) + fwd * (math.sin(a) * r)
    for k in range(nturn):
        v = lerp(0.34, 1.02, k / (nturn - 1))
        ring = [around(v + 0.03 * math.sin(2 * math.pi * i / 20 + k), 2 * math.pi * i / 20, 0.016) for i in range(20)]
        trim(pc, ring, 0.058, 0.012, hi, "CHARCOAL_LT", closed=True)
    for ph, sign in ((0.3, 1), (0.3 + math.pi, 1), (0.3, -1), (0.3 + math.pi, -1)):
        pts = [around(lerp(0.36, 0.98, i / 26), ph + sign * 2 * math.pi * 1.05 * i / 26, 0.031) for i in range(27)]
        tube(pc, pts, (0.026, 0.009), 6 if hi else 4, "CINNABAR", p=3.0)
    return pc


def hand_piece(hi, s):
    pc = piece(SIDE[s] + "Hand")
    hand(pc, hi, s, glove="CHARCOAL_LT", guard="CHARCOAL_LT")
    return pc


def lower_torso(hi):
    pc = piece("LowerTorso")
    na, nz = (56, 12) if hi else (26, 5)
    pc.grid([[torso_pt(-math.pi + 2 * math.pi * k / na, lerp(-1.05, -0.26, i / nz)) for k in range(na)] for i in range(nz + 1)], "CHARCOAL_LT", closed_u=True, cap0=True, cap1=True)
    # layered sash: charcoal under, red crossing over, a studded leather belt below
    for zc, h, off, ph, amp, mat in ((-0.29, 0.15, 0.08, 0.0, 0.01, "CHARCOAL_LT"), (-0.44, 0.17, 0.09, 2.1, 0.015, "CHARCOAL_LT"), (-0.56, 0.12, 0.085, 3.0, 0.02, "CHARCOAL_LT"),
                                     (-0.36, 0.062, 0.112, 1.6, 0.085, "CINNABAR"), (-0.36, 0.062, 0.124, 4.74, 0.085, "CINNABAR"), (-0.27, 0.05, 0.10, 0.4, 0.012, "CINNABAR")):
        nr = 5 if hi else 3
        rows = []
        for i in range(nr + 1):
            f = i / nr
            z0 = zc + h * 0.5 - h * f
            rows.append([torso_pt(-math.pi + 2 * math.pi * k / na, z0 + amp * math.sin(-math.pi + 2 * math.pi * k / na + ph), off + 0.022 * math.sin(math.pi * f) + (0.006 * math.sin(k * 0.9 + ph) if hi else 0)) for k in range(na)])
        pc.grid(rows, mat, closed_u=True)
    belt = on_torso(0.128)
    P = [[belt(-math.pi + 0.01 + (2 * math.pi - 0.02) * k / na, -0.50 + 0.03 * math.sin(k * 2 * math.pi / na + 0.5) + dz) for k in range(na + 1)] for dz in (0.042, -0.042)]
    slab(pc, P, 0.022, "LEATHER")
    if hi:
        rv = []
        for k in range(34):
            a = -math.pi + 2 * math.pi * k / 34
            z = -0.50 + 0.03 * math.sin(a + math.pi + 0.5)
            rv.append((belt(a, z) + normal(belt, a, z, torso_centre) * 0.014, normal(belt, a, z, torso_centre)))
        rivets(pc, rv, 0.012, hi)
    k0 = belt(-0.16, -0.40) + V((0, 0.03, 0))
    lathe(pc, [(0.0, -0.09), (0.062, -0.08), (0.092, -0.025), (0.088, 0.035), (0.052, 0.085), (0.0, 0.095)], 18 if hi else 10, "CINNABAR", tr(k0), sy=0.72)
    for dx, rz in ((-0.085, 24), (0.085, -24)):
        lathe(pc, [(0.0, -0.07), (0.04, -0.05), (0.05, 0.0), (0.04, 0.05), (0.0, 0.07)], 14 if hi else 8, "CINNABAR", tr(k0 + V((dx, 0, 0.01))) @ rot("Y", rz), sy=0.6)
    # the tail's root and the cord's top stay with the knot; the rest rides the thigh, overlapping them, so neither parts in a stride
    tail_strip(pc, hi, -0.44, -0.74, 99, 0.0)
    tube(pc, [k0 + V((-0.005, 0.0, -0.07)), V((-0.19, cloth_y(-0.70) + 0.035, -0.70))], 0.0095, 6 if hi else 4, "TASSEL")
    # the pouch on the left hip
    ph = belt(-1.25, -0.72) + V((-0.03, 0.0, 0.0))
    from lib import box
    M = tr(ph) @ rot("Z", -68)
    box(pc, V(), (0.34, 0.13, 0.28), "LEATHER", M, bevel=0.022)
    box(pc, V(), (0.36, 0.05, 0.14), "LEATHER", tr(ph + V((-0.05, 0.03, 0.09))) @ rot("Z", -68), bevel=0.012)
    buckle(pc, ph + V((-0.13, 0.06, 0.08)), V((-0.93, 0.37, 0)).normalized(), V((0, 0, 1)), 0.06, 0.06, hi)
    return pc


# Where the cloth under the sash tail lies at rest, measured from the master along its centre line: z -> y. The tail and the jade follow it,
# so from the side they lie on the robe instead of standing off it.
CLOTH_Y = [(-1.75, 0.735), (-1.55, 0.725), (-1.5, 0.705), (-1.3, 0.645), (-1.1, 0.58), (-0.9, 0.52), (-0.75, 0.47), (-0.62, 0.49), (-0.45, 0.50)]
SLOPE = 17  # degrees the robe leans out toward its hem
DOWN = V((0, math.sin(math.radians(SLOPE)), -math.cos(math.radians(SLOPE))))


def cloth_y(z):
    return interp(CLOTH_Y, z)[0]


def tail_strip(pc, hi, z0, z1, seed, fray):
    """The red sash tail, lying on the cloth from z0 down to z1."""
    x0, half = -0.16, 0.085
    nr = 20 if hi else 8
    P = []
    for i in range(nr + 1):
        z = lerp(z0, z1, i / nr)
        row = []
        for j in range(9):
            q = V((x0 + lerp(-half, half, j / 8), cloth_y(z) + 0.014, z))
            if i == nr and fray:
                q += V((0, 0, torn(0.0, j, seed, fray)))
            row.append(q)
        P.append(row)
    slab(pc, P, 0.018, "CINNABAR")


def tunic_hem(a, s):
    """Deep dips at the sides and back corner, high at the centre, ragged either way. a is the angle from the front."""
    return lerp(-1.50, -1.90, smooth((a - 0.25) / 1.2)) + 0.22 * smooth((a - 1.9) / 0.9)


def upper_leg(hi, s):
    pc = piece(SIDE[s] + "UpperLeg")
    X = s * LEG_X
    nz, na = (28, 32) if hi else (10, 16)
    def ring(z):
        t = (-0.82 - z) / 1.06
        r = 0.29 + 0.145 * smooth((t - 0.25) / 0.55)
        fold = lambda th: 1 + (0.035 * math.sin(th * 5 + t * 6 + s) + 0.018 * math.sin(th * 11 - t * 9)) * smooth(t * 2)
        return sring(V((X + s * 0.02 * t, 0.0, z)), V((1, 0, 0)), V((0, 1, 0)), r * 0.99, r, na, 2.1, -math.pi / 2, None, fold)
    pc.grid([ring(lerp(-0.80, -1.80, i / nz)) for i in range(nz + 1)], "TROUSER", closed_u=True, cap0=True, cap1=True)
    cols = 44
    angs = [lerp(0.0, 3.0, j / cols) for j in range(cols + 1)]
    top = [V((s * math.sin(a) * 0.70, math.cos(a) * 0.46, -0.70)) for a in angs]
    bot = [V((s * math.sin(a) * 1.0, math.cos(a) * 0.70, tunic_hem(a, s))) for a in angs]
    cloth_panel(pc, top, bot, 0.018, "ASH", cols, 16 if hi else 6, seed=60 + s, fray=0.07)
    # charcoal layer, short and ragged, over the hips at the sides
    cols = 30
    angs = [lerp(0.72, 2.02, j / cols) for j in range(cols + 1)]
    top = [V((s * math.sin(a) * 0.76, math.cos(a) * 0.52, -0.66)) for a in angs]
    bot = [V((s * math.sin(a) * 1.05, math.cos(a) * 0.76, -1.40 - 0.24 * math.sin((a - 0.72) / 1.3 * math.pi))) for a in angs]
    cloth_panel(pc, top, bot, 0.018, "CHARCOAL_LT", cols, 12 if hi else 5, seed=80 + s, fray=0.075)
    if s < 0:
        tail_strip(pc, hi, -0.68, -1.72, 99, 0.05)
        # jade disc, bronze cap and tassel, lying on the tail and leaning with the robe
        jz = -0.95
        jp = V((-0.20, cloth_y(jz) + 0.054, jz))
        tube(pc, [V((-0.19, cloth_y(-0.68) + 0.035, -0.68)), V((-0.195, cloth_y(-0.80) + 0.034, -0.80)), jp - DOWN * 0.10], 0.0095, 6 if hi else 4, "TASSEL")
        lathe(pc, [(0.05, 0.0), (0.056, 0.016), (0.075, 0.021), (0.10, 0.018), (0.115, 0.006), (0.115, -0.006), (0.10, -0.018), (0.075, -0.021), (0.056, -0.016), (0.05, 0.0)], 32 if hi else 16, "JADE", tr(jp) @ rot("X", 90 + SLOPE))
        ty = jp + DOWN * 0.108
        M = tr(ty) @ rot("X", SLOPE)
        lathe(pc, [(0.0, 0.0), (0.018, -0.008), (0.024, -0.04), (0.03, -0.075), (0.04, -0.09), (0.03, -0.098), (0.0, -0.1)], 14 if hi else 8, "BRONZE", M)
        lathe(pc, [(0.0, -0.09), (0.03, -0.1), (0.04, -0.25), (0.046, -0.41), (0.0, -0.42)], 12, "TASSEL", M)
    return pc


def lower_leg(hi, s):
    pc = piece(SIDE[s] + "LowerLeg")
    X = s * (LEG_X + 0.02)
    nz, na = (24, 30) if hi else (9, 14)
    rows = []
    for i in range(nz + 1):
        t = i / nz
        z = lerp(-1.66, -2.12, t)
        r = interp([(0.0, 0.225), (0.1, 0.245), (0.28, 0.32), (0.48, 0.395), (0.7, 0.43), (1.0, 0.43)], 1 - t)[0]
        fold = lambda th, t=t: 1 + (0.022 + 0.05 * smooth((t - 0.25) / 0.6)) * math.sin(th * 7 + s + t * 1.4) + (0.014 + 0.028 * smooth((t - 0.3) / 0.6)) * math.sin(th * 13 - t * 2)
        rows.append(sring(V((X, 0.0, z)), V((1, 0, 0)), V((0, 1, 0)), r, r, na, 2.1, -math.pi / 2, None, fold))
    pc.grid(rows, "TROUSER", closed_u=True, cap0=True, cap1=True)
    # calf column, wrapped
    rows = []
    for i in range(nz + 1):
        t = i / nz
        z = lerp(-2.02, -2.78, t)
        calf = gauss((t - 0.22) ** 2, 0.2)
        r = 0.2 + 0.03 * calf - 0.04 * t
        rows.append(sring(V((X, 0.0, z)), V((1, 0, 0)), V((0, 1, 0)), r, 0.2 + 0.012 * calf - 0.04 * t, na, 2.2, -math.pi / 2, 0.2 + 0.06 * calf - 0.04 * t))
    pc.grid(rows, "BOOT", closed_u=True, cap0=True, cap1=True)
    wrap = lambda a, z, r: V((X + math.sin(a) * r, 0.012 + math.cos(a) * r, z))
    leg = lambda z: lerp(0.235, 0.17, smooth((-2.2 - z) / 0.5))
    # the ash linen band at the top of the calf
    for k in range(3):
        z = -2.13 - 0.058 * k
        ring = [wrap(2 * math.pi * i / 22, z + 0.008 * math.sin(i * 2 + k), leg(z) + 0.016) for i in range(22)]
        trim(pc, ring, 0.05, 0.013, hi, "ASH", closed=True)
    # crossed bands below it
    for ph, sign, mat, w0 in ((0.0, 1, "CHARCOAL_LT", 0.04), (math.pi, 1, "CHARCOAL_LT", 0.04), (0.0, -1, "CHARCOAL_LT", 0.04), (math.pi, -1, "CHARCOAL_LT", 0.04), (0.5, 1, "ASH", 0.02), (0.5, -1, "ASH", 0.02)):
        pts = []
        for i in range(37):
            f = i / 36
            z = lerp(-2.30, -2.74, f)
            pts.append(wrap(ph + sign * 2 * math.pi * 1.5 * f, z, leg(z) + (0.03 if mat == "ASH" else 0.022)))
        tube(pc, pts, (w0, 0.008), 6 if hi else 4, mat, p=3.0)
    # red cords: crossed at the knee and over the ankle
    for z0, z1, ph in ((-2.04, -2.14, 0.0), (-2.14, -2.04, math.pi), (-2.54, -2.72, 0.5), (-2.72, -2.54, 0.5 + math.pi)):
        pts = [wrap(ph + 2 * math.pi * i / 22, lerp(z0, z1, i / 22), leg(lerp(z0, z1, i / 22)) + 0.034) for i in range(23)]
        tube(pc, pts, (0.036, 0.012), 6 if hi else 4, "CINNABAR", p=3.0)
    return pc


def foot(hi, s):
    pc = piece(SIDE[s] + "Foot")
    boot(pc, hi, s, upper="BOOT", toe="BOOT", welt="LEATHER")
    return pc


def build(hi):
    out = [upper_torso(hi), lower_torso(hi)]
    for s in (1, -1):
        out += [upper_arm(hi, s), lower_arm(hi, s), hand_piece(hi, s), upper_leg(hi, s), lower_leg(hi, s), foot(hi, s)]
    return out
