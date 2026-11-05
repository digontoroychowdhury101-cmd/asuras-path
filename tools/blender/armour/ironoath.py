"""Iron Oath: the heavy set, from the three-set lineup (no individual sheet was supplied), on the Cinnabar Guard foundation.

Lineup details kept: forged chased breastplate with bronze borders and belly lames over red cloth, big layered pauldrons with heavy bronze
edges, full plate vambraces with elbow lobes, a broad belt with the bronze demon-face boss over a red sash, jade disc and two tassels,
long riveted tassets with centre plates and torn red under-skirt, domed chased knee cops, full greaves with red straps, iron-capped boots.
"""
import math

from cinnabar import SIDE, bracer, collar, piece, sleeve
from kit import (ARM_ELBOW, ARM_WRIST, LEG_X, boot, bronze_boss, buckle, cloth_panel, hand, interp, lamellae, lerp, normal, on_torso, rivets, smooth,
                 strap, sx, torn, torso_centre, torso_pt, trim)
from lib import V, curve_pts, gauss, lathe, rot, slab, sring, tr, tube

FWD = V((0, 1, 0))


def stud(pc, p, n, r, h, hi, mat="BRONZE", seg=12):
    M = tr(p) @ n.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
    lathe(pc, [(r, 0.0), (r * 0.82, h * 0.6), (r * 0.42, h * 0.95), (0.0, h)], seg if hi else 7, mat, M, cap0=True)


def chest_half(z):
    return lerp(1.5, 0.92, smooth((z - 0.16) / 0.5))


def breastplate(pc, hi, front):
    """One forged plate from the collar to the belly lames, with the armhole's curve, a centre ridge and bronze borders."""
    plate = on_torso(0.10)
    a0 = 0.0 if front else math.pi
    nu, nv = (30, 16) if hi else (16, 7)
    zs = (0.80, 0.08)
    at = lambda g, z: a0 + g * chest_half(z)
    P = [[plate(at(lerp(-1, 1, j / nu), lerp(*zs, i / nv)), lerp(*zs, i / nv)) for j in range(nu + 1)] for i in range(nv + 1)]
    slab(pc, P, 0.045, "IRON")
    off = 0.024
    lift = lambda a, z: plate(a, z) + normal(plate, a, z, torso_centre) * off
    # borders: heavy along the top and the armholes
    trim(pc, [lift(at(lerp(-1, 1, j / nu), zs[0]), zs[0]) for j in range(nu + 1)], 0.042, 0.02, hi)
    trim(pc, [lift(at(lerp(-1, 1, j / nu), zs[1]), zs[1]) for j in range(nu + 1)], 0.036, 0.018, hi)
    for g in (-1, 1):
        trim(pc, [lift(at(g, lerp(*zs, i / nv)), lerp(*zs, i / nv)) for i in range(nv + 1)], 0.036, 0.018, hi)
    # two riveted bands across the plate, as on the lineup: one under the collar, one under the chest
    for zb, h in ((0.655, 0.12),):
        Q = [[lift(at(lerp(-1, 1, j / nu), z), z) for j in range(nu + 1)] for z in (zb + h / 2, zb, zb - h / 2)]
        slab(pc, Q, 0.022, "IRON")
        for z in (zb + h / 2, zb - h / 2):
            trim(pc, [lift(at(lerp(-1, 1, j / nu), z), z) + normal(plate, at(lerp(-1, 1, j / nu), z), z, torso_centre) * 0.012 for j in range(nu + 1)], 0.02, 0.012, hi)
        if hi:
            rv = []
            for j in range(19):
                a = at(lerp(-0.96, 0.96, j / 18), zb)
                n = normal(plate, a, zb, torso_centre)
                rv.append((plate(a, zb) + n * (off + 0.012), n))
            rivets(pc, rv, 0.016, hi)
    # the chased field: a raised centre ridge, a sunburst, leaf studs across the chest
    if front:
        tube(pc, [lift(0.0, lerp(0.54, 0.26, i / 6)) for i in range(7)], lambda t: 0.018, 8 if hi else 4, "IRON")
        c = lift(0.0, 0.41)
        n0 = normal(plate, 0.0, 0.41, torso_centre)
        bronze_boss(pc, c, n0, 0.105, hi)
        if hi:
            for k in range(14):
                t = 2 * math.pi * k / 14
                a1, z1 = 0.105 * math.cos(t) / 0.62, 0.41 + 0.105 * math.sin(t)
                a2, z2 = 0.205 * math.cos(t) / 0.62, 0.41 + 0.205 * math.sin(t) * 0.8
                tube(pc, [lift(a1, z1), lift(a2, z2)], lambda u: 0.014 * (1 - u) + 0.003, 5, "BRONZE")
            for g in (-1, 1):
                for a, z, r in ((0.55, 0.47, 0.03), (0.74, 0.39, 0.024), (0.50, 0.33, 0.024), (0.92, 0.47, 0.02), (0.78, 0.30, 0.018)):
                    stud(pc, lift(g * a, z), normal(plate, g * a, z, torso_centre), r, r * 0.8, hi)
                    tube(pc, [lift(g * a, z + 0.03), lift(g * (a + 0.05), z + 0.06), lift(g * (a + 0.12), z + 0.05)], lambda u: 0.009 * (1 - u) + 0.002, 5, "BRONZE")
        bronze_boss(pc, lift(-0.72, 0.62), normal(plate, -0.72, 0.62, torso_centre), 0.078, hi)
        bronze_boss(pc, lift(0.72, 0.62), normal(plate, 0.72, 0.62, torso_centre), 0.078, hi)
    else:
        for g in (-1, 1):
            a = a0 + g * 0.55
            bronze_boss(pc, lift(a, 0.42), normal(plate, a, 0.42, torso_centre), 0.09, hi)


def upper_torso(hi):
    pc = piece("UpperTorso")
    na, nz = (64, 26) if hi else (28, 12)
    pc.grid([[torso_pt(-math.pi + 2 * math.pi * k / na, lerp(-0.56, 0.98, i / nz)) for k in range(na)] for i in range(nz + 1)],
            "CINNABAR", closed_u=True, cap0=True, cap1=True)
    breastplate(pc, hi, True)
    breastplate(pc, hi, False)
    # three belly lames all round, each riding over the one below
    for r in range(3):
        zt = 0.11 - 0.118 * r
        off = 0.135 - 0.014 * r
        surf = on_torso(off)
        nu = 56 if hi else 26
        arc = lambda z, o=0.0: [surf(-math.pi + 2 * math.pi * j / nu, z) + V((0, 0, 0)) + normal(surf, -math.pi + 2 * math.pi * j / nu, z, torso_centre) * o for j in range(nu)]
        rows = [arc(zt), arc(zt - 0.075, 0.012), arc(zt - 0.15, 0.024)]
        rows = [row + [row[0]] for row in rows]
        slab(pc, rows, 0.034, "IRON")
        trim(pc, arc(zt - 0.15, 0.04), 0.022, 0.013, hi, closed=True)
        if hi:
            rv = []
            for j in range(40):
                a = -math.pi + 2 * math.pi * (j + 0.5) / 40
                n = normal(surf, a, zt - 0.075, torso_centre)
                rv.append((surf(a, zt - 0.075) + n * 0.032, n))
            rivets(pc, rv, 0.014, hi)
    # shoulder straps over the top of the plate, buckled at both feet
    yoke = on_torso(0.135)
    for s in (1, -1):
        ctrl = [(s * 0.72, 0.68), (s * 0.74, 0.82), (s * 0.86, 0.93), (s * 1.57, 0.985), (s * 2.32, 0.93), (s * 2.42, 0.82), (s * 2.42, 0.68)]
        path = strap(pc, yoke, torso_centre, ctrl, 0.15, 0.026, "LEATHER", 26 if hi else 14, hi=hi)
        for q in (len(path) // 6, -len(path) // 6):
            p, n = path[q]
            buckle(pc, p, n, V((0, 0, 1)), 0.17, 0.11, hi)
        side = lambda n: n.cross(V((0, 0, 1))).normalized()
        for g in (-1, 1):
            trim(pc, [q + side(m) * (g * 0.082) + m * 0.008 for q, m in path[:7]], 0.014, 0.01, hi)
    collar(pc, hi)
    return pc


def pauldron(pc, hi, s):
    """Large forged shoulder: a dome plate, four wide lames below it, heavy bronze on every outer edge."""
    p0, p1 = V((s * 0.80, 0.0, 0.90)), V((s * 1.33, 0.0, -0.06))
    ax = (p1 - p0).normalized()
    out = V((s * -ax.z, 0, ax.x * s)).normalized()
    if out.z < 0:
        out = -out
    ln = (p1 - p0).length

    def surf(a, z):
        v = -z
        c = p0 + ax * (v * ln)
        r = (0.44 + 0.13 * v) * (math.sqrt(max(0.02, 1 - (v / 0.25) ** 2)) if v < 0 else 1.0)
        return c + out * (math.cos(a) * r * 0.86) + FWD * (math.sin(a) * r * 1.04)

    cen = lambda z: p0 + ax * (-z * ln)
    half = 1.62
    nu = 28 if hi else 14
    lifted = lambda a, v, o: surf(a, v) + normal(surf, a, v, cen) * o
    arc = lambda v, o: [lifted(lerp(-half, half, j / nu), v, o) for j in range(nu + 1)]
    # the dome and its wide bronze rim
    slab(pc, [[surf(lerp(-half, half, j / nu), lerp(0.245, -0.24, i / 9)) for j in range(nu + 1)] for i in range(10)], 0.04, "IRON")
    trim(pc, arc(-0.03, 0.03), 0.042, 0.02, hi)
    trim(pc, arc(-0.24, 0.036), 0.045, 0.022, hi)
    # four lames, each lapping the next
    bottom = -0.24
    for k in range(4):
        v0 = -0.20 - 0.155 * k
        v1 = v0 - 0.22
        o0, o1 = 0.022 + 0.014 * k, 0.062 + 0.014 * k
        P = [[lifted(lerp(-half, half, j / nu), lerp(v0, v1, f), lerp(o0, o1, f)) for j in range(nu + 1)] for f in (0, 0.5, 1)]
        slab(pc, P, 0.032, "IRON")
        trim(pc, [lifted(lerp(-half, half, j / nu), v1, o1 + 0.02) for j in range(nu + 1)], 0.032 if k == 3 else 0.022, 0.016, hi)
        bottom = v1
        if hi:
            rv = []
            for j in range(15):
                a = lerp(-half + 0.1, half - 0.1, j / 14)
                n = normal(surf, a, v0 - 0.12, cen)
                rv.append((lifted(a, v0 - 0.12, lerp(o0, o1, 0.55) + 0.018), n))
            rivets(pc, rv, 0.02, hi)
    # bronze edge straps down both ends, tying the lames together
    for a in (-half, half):
        trim(pc, [lifted(a, lerp(-0.03, bottom, i / 10), 0.09) for i in range(11)], 0.042, 0.02, hi)
        if hi:
            rivets(pc, [(lifted(a, lerp(-0.08, bottom + 0.05, i / 7), 0.112), normal(surf, a, lerp(-0.08, bottom + 0.05, i / 7), cen)) for i in range(8)], 0.019, hi)
    # the forged crest: a raised bronze-edged plate on the outside of the dome
    C = [[lifted(g * lerp(0.62, 0.30, f), lerp(-0.05, -0.20, f), 0.036) for g in (-1, -0.5, 0, 0.5, 1)] for f in (0, 0.33, 0.66, 1)]
    slab(pc, C, 0.016, "BRONZE")
    stud(pc, lifted(0.0, -0.12, 0.05), normal(surf, 0.0, -0.12, cen), 0.05, 0.05, hi, "IRON")
    # hanger to the shoulder strap
    for g in (-0.7, 0.7):
        buckle(pc, lifted(g, 0.06, 0.03), normal(surf, g, 0.06, cen), ax, 0.11, 0.09, hi)


def upper_arm(hi, s):
    pc = piece(SIDE[s] + "UpperArm")
    sleeve(pc, hi, s)
    pauldron(pc, hi, s)
    return pc


def lower_arm(hi, s):
    pc = piece(SIDE[s] + "LowerArm")
    e, w = sx(ARM_ELBOW, s), sx(ARM_WRIST, s)
    tube(pc, curve_pts([e + V((-s * 0.025, 0, 0.17)), e, e.lerp(w, 0.5), w], 16 if hi else 7), lambda t: 0.222 - 0.075 * t, 26 if hi else 14, "CHARCOAL")
    bracer(pc, hi, s)
    # the elbow lobes: flared plates above the vambrace, bronze edged, that overlap the sleeve in a bend
    ax = (w - e).normalized()
    out = V((s * -ax.z, 0, s * ax.x)).normalized()
    if out.x * s < 0:
        out = -out
    def surf(a, v):
        c = e + ax * (v * 0.3)
        r = 0.255 + 0.05 * smooth((0.0 - v) / 0.5)
        return c + out * (math.cos(a) * r) + FWD * (math.sin(a) * r * 1.06)
    nu = 22 if hi else 12
    P = [[surf(lerp(-1.75, 1.75, j / nu), v) for j in range(nu + 1)] for v in (-0.55, -0.2, 0.1, 0.38)]
    slab(pc, P, 0.03, "IRON")
    trim(pc, [surf(lerp(-1.75, 1.75, j / nu), -0.55) + out * 0.02 for j in range(nu + 1)], 0.035, 0.018, hi)
    trim(pc, [surf(lerp(-1.75, 1.75, j / nu), 0.38) + out * 0.02 for j in range(nu + 1)], 0.035, 0.018, hi)
    stud(pc, surf(0.0, -0.1) + out * 0.02, out, 0.05, 0.045, hi)
    if hi:
        rivets(pc, [(surf(lerp(-1.5, 1.5, j / 8), 0.3) + out * 0.03, out) for j in range(9)], 0.015, hi)
    return pc


def hand_piece(hi, s):
    pc = piece(SIDE[s] + "Hand")
    hand(pc, hi, s)
    return pc


def demon_face(pc, hi, c):
    """The forged bronze belt boss: a snarling face in a round frame."""
    n = FWD
    bronze_boss(pc, c, n, 0.255, hi)
    y = lambda d: V((0, d, 0))
    M = lambda p: tr(p) @ n.to_track_quat("Z", "Y").to_matrix().to_4x4()
    # the face mass, muzzle and brow
    lathe(pc, [(0.17, 0.0), (0.165, 0.035), (0.135, 0.07), (0.0, 0.09)], 20 if hi else 10, "BRONZE", M(c + y(0.03)), cap0=True)
    for g in (-1, 1):
        tube(pc, [c + V((g * 0.03, 0.12, 0.045)), c + V((g * 0.095, 0.115, 0.075)), c + V((g * 0.165, 0.09, 0.05))], lambda t: 0.024 - 0.012 * t, 8 if hi else 5, "BRONZE")
        stud(pc, c + V((g * 0.078, 0.10, 0.02)), n, 0.034, 0.03, hi, "IRON")
        tube(pc, [c + V((g * 0.16, 0.05, 0.12)), c + V((g * 0.20, 0.06, 0.185)), c + V((g * 0.175, 0.045, 0.255))], lambda t: 0.028 * (1 - t) + 0.004, 8 if hi else 5, "BRONZE")
        tube(pc, [c + V((g * 0.07, 0.12, -0.075)), c + V((g * 0.073, 0.135, -0.13))], lambda t: 0.018 * (1 - t) + 0.002, 7 if hi else 4, "BRONZE")
    stud(pc, c + V((0, 0.115, -0.012)), n, 0.04, 0.042, hi)
    tube(pc, [c + V((-0.09, 0.118, -0.07)), c + V((0, 0.135, -0.085)), c + V((0.09, 0.118, -0.07))], lambda t: 0.014, 7 if hi else 4, "IRON")


def jade_drop(pc, hi, k0, jp, long=True):
    tube(pc, [k0, jp + V((0.004, -0.02, 0.24)), jp + V((0, 0, 0.11))], 0.0095, 6 if hi else 4, "TASSEL")
    lathe(pc, [(0.05, 0.0), (0.056, 0.016), (0.075, 0.021), (0.10, 0.018), (0.115, 0.006), (0.115, -0.006), (0.10, -0.018), (0.075, -0.021), (0.056, -0.016), (0.05, 0.0)],
          32 if hi else 16, "JADE", tr(jp) @ rot("X", 90))
    tassel(pc, hi, jp + V((0, 0, -0.108)))


def tassel(pc, hi, ty):
    lathe(pc, [(0.0, 0.0), (0.018, -0.008), (0.024, -0.04), (0.03, -0.075), (0.04, -0.09), (0.03, -0.098), (0.0, -0.1)], 14 if hi else 8, "BRONZE", tr(ty))
    if hi:
        for k in range(26):
            a = k * 2.4
            r0 = 0.012 + 0.016 * ((k * 7 % 11) / 10)
            top = ty + V((math.cos(a) * r0, math.sin(a) * r0, -0.095))
            ln = 0.30 + 0.05 * ((k * 5 % 7) / 6)
            tube(pc, [top, top + V((math.cos(a) * 0.006, math.sin(a) * 0.006, -ln * 0.5)), top + V((math.cos(a) * 0.016, math.sin(a) * 0.016, -ln))], lambda t: 0.0055 * (1 - 0.5 * t), 5, "TASSEL")
    else:
        lathe(pc, [(0.0, -0.09), (0.03, -0.1), (0.04, -0.25), (0.052, -0.41), (0.0, -0.42)], 10, "TASSEL", tr(ty))


def lower_torso(hi):
    pc = piece("LowerTorso")
    na, nz = (56, 12) if hi else (26, 5)
    pc.grid([[torso_pt(-math.pi + 2 * math.pi * k / na, lerp(-1.05, -0.26, i / nz)) for k in range(na)] for i in range(nz + 1)],
            "CHARCOAL", closed_u=True, cap0=True, cap1=True)
    # red sash under the belt, showing above and below it
    for zc, h, off, ph, amp in ((-0.40, 0.12, 0.11, 2.2, 0.02), (-0.61, 0.12, 0.104, 1.1, 0.02), (-0.67, 0.11, 0.09, 3.0, 0.02)):
        nr = 5 if hi else 3
        rows = [[torso_pt(-math.pi + 2 * math.pi * k / na, zc + h * 0.5 - h * i / nr + amp * math.sin(-math.pi + 2 * math.pi * k / na + ph), off + 0.024 * math.sin(math.pi * i / nr)) for k in range(na)] for i in range(nr + 1)]
        pc.grid(rows, "CINNABAR", closed_u=True)
    # the broad belt, bronze edged and studded
    belt = on_torso(0.146)
    P = [[belt(-math.pi + 0.005 + (2 * math.pi - 0.01) * k / na, z) for k in range(na + 1)] for z in (-0.41, -0.50, -0.59)]
    slab(pc, P, 0.03, "LEATHER")
    for z in (-0.415, -0.585):
        trim(pc, [belt(-math.pi + 2 * math.pi * k / na, z) + normal(belt, -math.pi + 2 * math.pi * k / na, z, torso_centre) * 0.018 for k in range(na)], 0.022, 0.013, hi, closed=True)
    if hi:
        rv = []
        for k in range(36):
            a = -math.pi + 2 * math.pi * (k + 0.5) / 36
            if abs(a) > 0.5:
                rv.append((belt(a, -0.50) + normal(belt, a, -0.50, torso_centre) * 0.018, normal(belt, a, -0.50, torso_centre)))
        rivets(pc, rv, 0.02, hi)
    c = belt(0.0, -0.50) + V((0, 0.03, 0))
    demon_face(pc, hi, c)
    # jade on the wearer's left, a plain tassel on the right: both on the belt
    jade_drop(pc, hi, belt(-0.60, -0.60) + V((0, 0.02, 0)), V((-0.30, 0.685, -1.0)))
    k1 = belt(0.46, -0.60) + V((0, 0.02, 0))
    tp = V((0.20, 0.685, -0.90))
    tube(pc, [k1, tp + V((0, 0, 0.05))], 0.0095, 6 if hi else 4, "TASSEL")
    tassel(pc, hi, tp)
    # short lamellar aprons: the long plates below them ride the thighs
    for front in (1, -1):
        half, ztop, zbot = 0.40, -0.62, -1.10
        y0 = 0.50 if front > 0 else -0.52
        def surf(a, z, front=front, y0=y0, ztop=ztop, zbot=zbot):
            t = max(0.0, (ztop - z) / (ztop - zbot))
            return V((a * 0.46, front * (y0 + 0.06 + 0.075 * t - 0.11 * (a * 0.8) ** 2), z))
        cen = lambda z: V((0, 0, z))
        hw = half / 0.46
        rows = [(-0.645 - 0.095 * r, 0.13, -hw, hw, 12, 0.004 * (5 - r)) for r in range(5)]
        lamellae(pc, surf, cen, rows, hi, stud=0.0125)
        arc = lambda z, off: [surf(lerp(-hw, hw, j / 14), z) + normal(surf, lerp(-hw, hw, j / 14), z, cen) * off for j in range(15)]
        trim(pc, arc(-1.135, 0.06), 0.036, 0.018, hi)
        for a in (-hw, hw):
            trim(pc, [surf(a, lerp(-0.645, -1.135, i / 8)) + normal(surf, a, -0.9, cen) * 0.05 for i in range(9)], 0.03, 0.017, hi)
    return pc


def tasset_surf(s, back=False):
    sign = -1 if back else 1
    def surf(a, z):
        t = max(0.0, (-0.56 - z) / 1.0)
        ang = lerp(0.40, 1.78, a)
        rx = 0.72 + 0.26 * t
        ry = 0.50 + 0.24 * t
        return V((s * math.sin(ang) * rx, sign * math.cos(ang) * ry, z))
    return surf


def tasset(pc, hi, s, back=False):
    surf = tasset_surf(s, back)
    cen = lambda z: V((0, 0, z))
    nrow = 8
    zt = -0.60
    rows = [(zt - 0.115 * r, 0.15, 0.0, 1.0, 12, 0.004 * (nrow - r)) for r in range(nrow)]
    lamellae(pc, surf, cen, rows, hi, stud=0.0145)
    zb = zt - 0.115 * (nrow - 1) - 0.15
    arc = lambda z, off: [surf(j / 14, z) + normal(surf, j / 14, z, cen) * off for j in range(15)]
    trim(pc, arc(zb, 0.06), 0.046, 0.022, hi)
    trim(pc, arc(zt, 0.04), 0.036, 0.018, hi)
    # a riveted reinforcing bar across the middle, as the lineup's plates carry
    trim(pc, arc(lerp(zt, zb, 0.5), 0.07), 0.028, 0.016, hi)
    for a in (0.0, 1.0):
        trim(pc, [surf(a, lerp(zt, zb, i / 12)) + normal(surf, a, -1.1, cen) * 0.052 for i in range(13)], 0.036, 0.019, hi)
    if hi:
        rv = []
        for j in range(12):
            a = (j + 0.5) / 12
            for z, o in ((zb, 0.082), (lerp(zt, zb, 0.5), 0.088)):
                nn = normal(surf, a, z, cen)
                rv.append((surf(a, z) + nn * o, nn))
        rivets(pc, rv, 0.018, hi)


def upper_leg(hi, s):
    pc = piece(SIDE[s] + "UpperLeg")
    X = s * LEG_X
    nz, na = (28, 32) if hi else (10, 16)
    def leg_ring(z):
        t = (-0.82 - z) / 1.06
        r = 0.29 + 0.10 * smooth((t - 0.25) / 0.55)
        fold = lambda th: 1 + (0.03 * math.sin(th * 5 + t * 6 + s) + 0.015 * math.sin(th * 11 - t * 9)) * smooth(t * 2)
        return sring(V((X + s * 0.02 * t, 0.0, z)), V((1, 0, 0)), V((0, 1, 0)), r * 0.99, r, na, 2.1, -math.pi / 2, None, fold)
    pc.grid([leg_ring(lerp(-0.80, -1.80, i / nz)) for i in range(nz + 1)], "CHARCOAL", closed_u=True, cap0=True, cap1=True)
    tasset(pc, hi, s, False)
    tasset(pc, hi, s, True)
    # torn red under-skirt showing below and outside the plates
    nr = 14 if hi else 5
    ang = [lerp(-0.3, 2.86, j / 16) for j in range(17)]
    top = [V((s * math.sin(a) * 0.70, math.cos(a) * 0.48, -0.72)) for a in ang]
    bot = [V((s * math.sin(a) * 1.04, math.cos(a) * 0.78, -1.70)) for a in ang]
    cloth_panel(pc, top, bot, 0.018, "CINNABAR", 34, nr, seed=50 + s, fray=0.08)
    # the centre plate over the front of the thigh: forged, bronze edged, hung between the tassets
    xs = lambda z: [s * lerp(0.02, 0.40, j / 6) for j in range(7)]
    zs = (-1.02, -1.56)
    P = [[V((x * lerp(1.0, 1.06, i / 3), lerp(0.60, 0.70, i / 3), lerp(*zs, i / 3))) for x in xs(0)] for i in range(4)]
    slab(pc, P, 0.03, "IRON")
    for i in (0, 3):
        trim(pc, [p + FWD * 0.02 for p in P[i]], 0.032, 0.017, hi)
    trim(pc, [P[i][-1] + FWD * 0.02 for i in range(4)], 0.03, 0.016, hi)
    trim(pc, [P[i][0] + FWD * 0.02 for i in range(4)], 0.03, 0.016, hi)
    if hi:
        rivets(pc, [(P[3][j] + FWD * 0.036, FWD) for j in range(7)], 0.016, hi)
        rivets(pc, [(P[0][j] + FWD * 0.036, FWD) for j in range(7)], 0.016, hi)
    # behind it, the charcoal panel, and at the centre back a red one
    bk = [s * lerp(0.08, 0.46, j / 6) for j in range(7)]
    cloth_panel(pc, [V((x, -0.52, -1.00)) for x in bk], [V((x * 1.06, -0.62, -1.68)) for x in bk], 0.018, "CINNABAR", 14, nr, seed=70 + s, fray=0.07)
    # the long sash tail, lying on the plates down the wearer's left thigh
    if s < 0:
        nr2 = 20 if hi else 8
        prof = [(-1.84, 0.745), (-1.56, 0.74), (-1.13, 0.715), (-0.75, 0.665), (-0.62, 0.655)]
        T = []
        for i in range(nr2 + 1):
            z = lerp(-0.62, -1.84, i / nr2)
            row = []
            for j in range(5):
                q = V((-0.09 + lerp(-0.075, 0.075, j / 4), interp(prof, z)[0], z))
                if i == nr2:
                    q += V((0, 0, torn(0.0, j, 99, 0.05)))
                row.append(q)
            T.append(row)
        slab(pc, T, 0.018, "CINNABAR")
    return pc


def lower_leg(hi, s):
    pc = piece(SIDE[s] + "LowerLeg")
    X = s * (LEG_X + 0.02)
    nz, na = (24, 30) if hi else (9, 14)
    # trouser and boot shaft inside the plate: the knee stays closed in a deep bend
    rows = []
    for i in range(nz + 1):
        t = i / nz
        z = lerp(-1.66, -2.12, t)
        r = interp([(0.0, 0.232), (0.3, 0.30), (0.6, 0.355), (1.0, 0.37)], 1 - t)[0]
        rows.append(sring(V((X, 0.0, z)), V((1, 0, 0)), V((0, 1, 0)), r, r, na, 2.1, -math.pi / 2))
    pc.grid(rows, "CHARCOAL", closed_u=True, cap0=True, cap1=True)
    rows = []
    for i in range(nz + 1):
        t = i / nz
        z = lerp(-2.02, -2.78, t)
        calf = gauss((t - 0.22) ** 2, 0.2)
        rows.append(sring(V((X, 0.0, z)), V((1, 0, 0)), V((0, 1, 0)), 0.2 + 0.03 * calf - 0.04 * t, 0.2 + 0.012 * calf - 0.04 * t, na, 2.2, -math.pi / 2, 0.2 + 0.06 * calf - 0.04 * t))
    pc.grid(rows, "BOOT", closed_u=True, cap0=True, cap1=True)

    def gsurf(a, z):
        k = lerp(0.262, 0.208, smooth((-2.10 - z) / 0.58))
        return V((X + math.sin(a) * k, 0.012 + math.cos(a) * (k + 0.008), z))
    out = lambda a: V((math.sin(a), math.cos(a), 0))
    # the full greave: a forged shell round the shin and the calf, bronze on its borders, a spine down the front
    A = 2.45
    nu, nv = (26, 10) if hi else (14, 5)
    P = [[gsurf(lerp(-A, A, j / nu), lerp(-2.08, -2.70, i / nv)) + out(lerp(-A, A, j / nu)) * 0.03 for j in range(nu + 1)] for i in range(nv + 1)]
    slab(pc, P, 0.036, "IRON")
    trim(pc, [p + out(lerp(-A, A, j / nu)) * 0.02 for j, p in enumerate(P[0])], 0.04, 0.02, hi)
    trim(pc, [p + out(lerp(-A, A, j / nu)) * 0.02 for j, p in enumerate(P[-1])], 0.04, 0.02, hi)
    for g in (-A, A):
        trim(pc, [gsurf(g, lerp(-2.08, -2.70, i / 8)) + out(g) * 0.05 for i in range(9)], 0.03, 0.017, hi)
    # the bronze shin shield and iron spine
    S, I = [], []
    for i in range(8 if hi else 4):
        f = i / (7 if hi else 3)
        z = lerp(-2.10, -2.58, f)
        half = lerp(0.60, 0.16, smooth(f * 1.05))
        S.append([gsurf(g * half, z) + out(g * half) * 0.056 for g in (-1, -0.5, 0, 0.5, 1)])
        ih = lerp(0.30, 0.06, smooth(f * 1.05))
        zi = lerp(-2.13, -2.55, f)
        I.append([gsurf(g * ih, zi) + out(g * ih) * 0.07 for g in (-1, -0.5, 0, 0.5, 1)])
    slab(pc, S, 0.018, "BRONZE")
    slab(pc, I, 0.014, "IRON")
    if hi:
        rv = []
        for a in (-1.2, -0.85, 0.85, 1.2, -2.1, 2.1):
            for z in (-2.2, -2.4, -2.6):
                rv.append((gsurf(a, z) + out(a) * 0.052, out(a)))
        rivets(pc, rv, 0.017, hi)
    # the domed knee cop: iron under a bronze frame, chased with curling leaf
    c = V((X, 0.17, -1.90))
    M = tr(c) @ FWD.to_track_quat("Z", "Y").to_matrix().to_4x4()
    lathe(pc, [(0.31, -0.02), (0.31, 0.02), (0.285, 0.10), (0.215, 0.18), (0.11, 0.235), (0.0, 0.25)], 30 if hi else 14, "IRON", M)
    lathe(pc, [(0.335, -0.02), (0.335, 0.03), (0.30, 0.055), (0.27, 0.075), (0.25, 0.03)], 30 if hi else 14, "BRONZE", M)
    def dome(th, r):
        h = 0.25 * math.sqrt(max(0.0, 1 - (r / 0.31) ** 2))
        return c + V((math.cos(th) * r, h + 0.012, math.sin(th) * r))
    bronze_boss(pc, dome(0, 0.0) + V((0, -0.012, 0)), FWD, 0.075, hi)
    for k in range(8):
        th = 2 * math.pi * k / 8 + s * 0.2
        pts = [dome(th + 0.7 * f, lerp(0.09, 0.27, f)) for f in [i / 8 for i in range(9)]]
        tube(pc, pts, lambda u: 0.019 * (1 - u) + 0.006, 7 if hi else 4, "BRONZE")
        if hi:
            stud(pc, dome(th + 0.1, 0.23), (dome(th + 0.1, 0.23) - c).normalized(), 0.016, 0.014, hi)
    # strap behind the knee and the red straps round the greave
    wrap = lambda a, z, r: V((X + math.sin(a) * r, 0.015 + math.cos(a) * r * 1.03, z))
    for z, r in ((-2.14, 0.312), (-2.60, 0.268)):
        ring = [wrap(2 * math.pi * i / 22, z, r) for i in range(22)]
        trim(pc, ring, 0.05, 0.014, hi, "CINNABAR", closed=True)
        trim(pc, [wrap(2 * math.pi * i / 22, z, r + 0.012) for i in range(22)], 0.022, 0.010, hi, "LEATHER", closed=True)
        buckle(pc, wrap(s * 1.35, z, r + 0.018), out(s * 1.35), V((0, 0, 1)), 0.085, 0.09, hi)
    return pc


def foot(hi, s):
    pc = piece(SIDE[s] + "Foot")
    boot(pc, hi, s, upper="BOOT")
    return pc


def build(hi):
    out = [upper_torso(hi), lower_torso(hi)]
    for s in (1, -1):
        out += [upper_arm(hi, s), lower_arm(hi, s), hand_piece(hi, s), upper_leg(hi, s), lower_leg(hi, s), foot(hi, s)]
    return out
