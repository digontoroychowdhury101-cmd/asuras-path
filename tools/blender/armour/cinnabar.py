"""Cinnabar Guard: the medium set, built from its concept sheet on the production player's body.

Resolved contradictions (the sheet's detail crop is authoritative): the diagonal strap runs from the wearer's right
shoulder to the left hip on the front, and crosses the other way on the back; the boss sits on the wearer's left chest.
Hanging plates ride the thigh they cover, so a stride opens the skirt instead of pushing a leg through it.
"""
import math

from mathutils import Matrix

from kit import (ARM_ELBOW, ARM_TOP, ARM_WRIST, LEG_X, SOLE_Z, boot, bronze_boss, buckle, cloth_panel, hand, interp, lamellae, lerp, normal,
                 on_torso, rivets, smooth, strap, sx, torso_centre, torso_pt, trim, TORSO)
from lib import V, Piece, box, curve_pts, gauss, lathe, rot, slab, sring, tr, tube

SIDE = {1: "Right", -1: "Left"}


def piece(limb):
    return Piece("Armor_" + limb, limb)


def armhole(z):
    """Half-angle of the cuirass front and back panels: the chest narrows toward the shoulder as on the sheet."""
    return lerp(1.42, 0.84, smooth((z - 0.20) / 0.42))


def cuirass_rows(hi):
    rows = []
    zt = 0.58
    h, step = 0.135, 0.098
    for r in range(9):
        off = 0.052 + 0.004 * (8 - r)
        if zt > 0.20:
            half = armhole(zt)
            n = max(9, int(half * 2 * 7.4))
            rows.append((zt, h, -half, half, n, off))
            rows.append((zt, h, math.pi - half, math.pi + half, n, off))
        else:
            rows.append((zt, h, -math.pi + 0.01, math.pi - 0.01, 42, off))
        zt -= step
    return rows


def upper_torso(hi):
    pc = piece("UpperTorso")
    na, nz = (64, 26) if hi else (28, 12)
    # cinnabar robe under everything, reaching below the sash so a bend never opens a gap
    pc.grid([[torso_pt(-math.pi + 2 * math.pi * k / na, lerp(-0.56, 0.98, i / nz)) for k in range(na)] for i in range(nz + 1)],
            "CINNABAR", closed_u=True, cap0=True, cap1=True)
    surf = on_torso(0.0)
    lamellae(pc, surf, torso_centre, cuirass_rows(hi), hi)
    # solid chest and back bands the lamellae hang from
    plate = on_torso(0.082)
    for a0, a1, is_front in ((-0.86, 0.86, True), (math.pi - 0.86, math.pi + 0.86, False)):
        nu = 26 if hi else 14
        P = [[plate(lerp(a0, a1, j / nu), lerp(0.55, 0.725, i / 3)) for j in range(nu + 1)] for i in range(4)]
        slab(pc, P, 0.03, "IRON")
        for z in (0.725, 0.55):
            trim(pc, [plate(lerp(a0, a1, j / nu), z) + normal(plate, lerp(a0, a1, j / nu), z, torso_centre) * 0.012 for j in range(nu + 1)], 0.019, 0.013, hi)
        for a in (a0, a1):
            trim(pc, [plate(a, lerp(0.55, 0.725, i / 3)) + normal(plate, a, 0.55, torso_centre) * 0.012 for i in range(4)], 0.019, 0.013, hi)
        if hi:
            rv = []
            for k in range(23):
                a = lerp(a0 + 0.03, a1 - 0.03, k / 22)
                for z in (0.70, 0.575):
                    rv.append((plate(a, z) + normal(plate, a, z, torso_centre) * 0.015, normal(plate, a, z, torso_centre)))
            rivets(pc, rv, 0.0125, hi)
    # the forged ornament at the centre of the chest band: four small studs round a fifth
    c = plate(0.0, 0.637)
    n0 = normal(plate, 0.0, 0.637, torso_centre)
    for d in (V((0, 0, 0)), V((0.05, 0, 0)), V((-0.05, 0, 0)), V((0, 0, 0.042)), V((0, 0, -0.042))):
        M = Matrix.Translation(c + d + n0 * 0.015) @ n0.to_track_quat("Z", "Y").to_matrix().to_4x4()
        lathe(pc, [(0.024, 0.0), (0.02, 0.012), (0.0, 0.017)], 12 if hi else 8, "BRONZE", M, cap0=True)
    # boss on the wearer's left chest, matching fitting on the right, both on the shoulder straps' feet
    a = -0.60
    bossp = plate(a, 0.637)
    bossn = normal(plate, a, 0.637, torso_centre)
    bronze_boss(pc, bossp + bossn * 0.016, bossn, 0.118, hi)
    bronze_boss(pc, plate(math.pi - 0.60, 0.637) + normal(plate, math.pi - 0.60, 0.637, torso_centre) * 0.016, normal(plate, math.pi - 0.60, 0.637, torso_centre), 0.092, hi)
    bronze_boss(pc, plate(math.pi + 0.60, 0.637) + normal(plate, math.pi + 0.60, 0.637, torso_centre) * 0.016, normal(plate, math.pi + 0.60, 0.637, torso_centre), 0.092, hi)
    # armhole edge strips run down from the band to the first full row
    trimsurf = on_torso(0.078)
    for s in (1, -1):
        for back in (False, True):
            pts = []
            for i in range(14 if hi else 7):
                z = lerp(0.55, 0.14, i / (13 if hi else 6))
                half = armhole(z)
                ang = s * half if not back else math.pi - s * half
                pts.append(trimsurf(ang, z) + normal(trimsurf, ang, z, torso_centre) * 0.012)
            trim(pc, pts, 0.022, 0.014, hi)
    # bottom hem strip of the cuirass, riveted, above the sash
    hem = [on_torso(0.105)(-math.pi + 2 * math.pi * k / na, -0.235) for k in range(na)]
    trim(pc, hem, 0.024, 0.014, hi, closed=True)
    # shoulder straps: leather with bronze edges, buckled below the collar, running over the shoulder to the back band
    yoke = on_torso(0.1)
    for s in (1, -1):
        ctrl = [(s * 0.64, 0.72), (s * 0.68, 0.84), (s * 0.80, 0.93), (s * 1.57, 0.985), (s * 2.40, 0.93), (s * 2.50, 0.84), (s * 2.50, 0.72)]
        path = strap(pc, yoke, torso_centre, ctrl, 0.135, 0.022, "LEATHER", 26 if hi else 14, hi=hi)
        p, n = path[len(path) // 7]
        buckle(pc, p, n, V((0, 0, 1)), 0.15, 0.10, hi)
        for g in (-1, 1):
            side = n.cross(V((0, 0, 1))).normalized()
            trim(pc, [q + side * (g * 0.074) + m * 0.006 for q, m in path[:6]], 0.012, 0.009, hi)
        p2, n2 = path[-len(path) // 7]
        buckle(pc, p2, n2, V((0, 0, 1)), 0.15, 0.10, hi)
    # the diagonal baldric: right shoulder to left hip in front, crossing the other way behind
    bald = on_torso(0.135)
    front = [(0.74, 0.82), (0.72, 0.52), (0.52, 0.26), (0.20, 0.02), (-0.22, -0.13), (-0.66, -0.25)]
    path = strap(pc, bald, torso_centre, front, 0.112, 0.024, "LEATHER", 32 if hi else 16, hi=hi)
    p, n = path[int(len(path) * 0.74)]
    buckle(pc, p, n, (path[int(len(path) * 0.74) + 1][0] - p).normalized(), 0.15, 0.14, hi)
    if hi:
        for k in range(3):
            q, m = path[int(len(path) * (0.82 + k * 0.05))]
            lathe(pc, [(0.011, 0.002), (0.004, 0.004)], 6, "BRONZE", Matrix.Translation(q + m * 0.012) @ m.to_track_quat("Z", "Y").to_matrix().to_4x4())
    back = [(math.pi - 0.74, 0.82), (math.pi - 0.72, 0.52), (math.pi - 0.52, 0.26), (math.pi - 0.20, 0.02), (math.pi + 0.22, -0.13), (math.pi + 0.66, -0.25)]
    path = strap(pc, bald, torso_centre, back, 0.112, 0.024, "LEATHER", 32 if hi else 16, hi=hi)
    p, n = path[int(len(path) * 0.42)]
    buckle(pc, p, n, (path[int(len(path) * 0.42) + 1][0] - p).normalized(), 0.15, 0.14, hi)
    collar(pc, hi)
    return pc


def collar(pc, hi):
    """Crossed collars: charcoal over pale inside a cinnabar lapel, wearer's left over right, closing in a V at the chest."""
    # a neck column the head can sit on
    lathe(pc, [(0.29, 0.86), (0.24, 0.98), (0.215, 1.08), (0.20, 1.20)], 24 if hi else 12, "SKIN", sy=1.0)
    n = 18 if hi else 10
    layers = (("PALE", 0.040, 0.012, 0.80), ("CHARCOAL", 0.078, 0.026, 0.74), ("CINNABAR", 0.135, 0.042, 0.68))
    for mat, width, off, vz in layers:
        for s in (1, -1):
            lift = 0.006 if s < 0 else 0.0  # the left side lies on top
            pts = []
            for i in range(n):
                t = i / (n - 1)
                # from the nape, round the neck, down to the V
                ang = lerp(math.pi * 0.92, 0.05, smooth(t * 1.25)) if t < 0.8 else lerp(lerp(math.pi * 0.92, 0.05, 1.0), -0.02, (t - 0.8) / 0.2)
                z = lerp(1.105 + (0.042 - off) * 0.9, vz, smooth((t - 0.34) / 0.66))
                rad = lerp(0.29, 0.36, smooth((t - 0.3) / 0.5)) + off * 0.75
                r_surf = torso_pt(s * ang, z, off + lift)
                ringp = V((s * math.sin(ang) * rad, math.cos(ang) * rad * 1.04 - 0.01, z))
                k = smooth((1.03 - z) / 0.12)
                pts.append(ringp.lerp(r_surf, k) if t >= 0.3 else ringp)
            rows = []
            for i, p in enumerate(pts):
                tang = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
                c = V((0, 0, p.z))
                out = (p - c).normalized()
                side = out.cross(tang).normalized()
                w = width * (0.72 + 0.28 * smooth((1.05 - p.z) / 0.15))
                rows.append([p + side * (g * w) + out * (0.008 * (1 - g * g)) for g in (-1, -0.33, 0.33, 1)])
            slab(pc, rows, 0.022, mat)


def sleeve(pc, hi, s):
    a0, a1 = sx(ARM_TOP, s), sx(ARM_ELBOW, s)
    # charcoal under-sleeve, carried across the elbow by the forearm piece
    path = curve_pts([a0, a0.lerp(a1, 0.5) + V((s * 0.01, 0, 0)), a1 + V((0, 0, -0.04))], 14 if hi else 6)
    tube(pc, path, lambda t: lerp(0.15, 0.235, smooth(t * 3)) - 0.02 * t, 26 if hi else 14, "CHARCOAL")
    # the cinnabar short sleeve: loose, ending in a torn hem above the elbow
    ax = (a1 - a0).normalized()
    out = V((s * ax.z * -1, 0, s * ax.x)).normalized()
    fwd = V((0, 1, 0))
    nu, nv = (32, 14) if hi else (18, 6)
    from kit import torn as ragged
    P = []
    for i in range(nv + 1):
        f = i / nv
        c = a0.lerp(a1, lerp(0.02, 0.72, f))
        r = lerp(0.20, 0.335, smooth(f * 2.2))
        row = []
        for j in range(nu + 1):
            a = 2 * math.pi * j / nu
            fold = 1 + 0.03 * math.sin(a * 5 + f * 4) * f
            p = c + out * (math.cos(a) * r * fold) + fwd * (math.sin(a) * r * 1.02 * fold)
            if i == nv:
                p = p + ax * ragged(0.0, j % nu, 40 + s, 0.07)
            row.append(p)
        P.append(row)
    slab(pc, P, 0.018, "CINNABAR")


def pauldron(pc, hi, s):
    """Layered riveted lames down a tilted shoulder form, bronze on every outer edge."""
    p0, p1 = V((s * 0.80, 0.0, 0.85)), V((s * 1.38, 0.0, -0.01))
    ax = (p1 - p0).normalized()
    out = V((s * -ax.z, 0, ax.x * s)).normalized()
    if out.z < 0:
        out = -out
    fwd = V((0, 1, 0))
    ln = (p1 - p0).length

    def surf(a, z):
        v = -z  # z is minus the distance down the shoulder, so the lamella helper runs downhill
        c = p0 + ax * (v * ln)
        r = (0.40 + 0.12 * v) * (math.sqrt(max(0.02, 1 - (v / 0.25) ** 2)) if v < 0 else 1.0)
        return c + out * (math.cos(a) * r * 0.80) + fwd * (math.sin(a) * r * 1.02)

    cen = lambda z: p0 + ax * (-z * ln)
    half = 1.5
    # top lame: a solid forged plate
    nu = 26 if hi else 14
    P = [[surf(lerp(-half, half, j / nu), lerp(0.245, -0.20, i / 8)) for j in range(nu + 1)] for i in range(9)]
    slab(pc, P, 0.034, "IRON")
    rows = [(-0.17 - 0.155 * k, 0.215, -half, half, 13, 0.0 + 0.017 * k) for k in range(4)]
    lamellae(pc, surf, cen, rows, hi, thick=0.02, tilt=0.055, stud=0.016)
    def edge(a, v0, v1, off=0.03):
        return [surf(a, lerp(v0, v1, i / 8)) + normal(surf, a, lerp(v0, v1, i / 8), cen) * off for i in range(9)]
    # bronze borders on the top plate, both long edges, and the bottom row
    arc = lambda v, off: [surf(lerp(-half, half, j / nu), v) + normal(surf, lerp(-half, half, j / nu), v, cen) * off for j in range(nu + 1)]
    trim(pc, arc(-0.02, 0.022), 0.03, 0.017, hi)
    trim(pc, arc(-0.20, 0.026), 0.024, 0.015, hi)
    trim(pc, arc(-0.85, 0.108), 0.03, 0.017, hi)
    for a in (-half, half):
        trim(pc, edge(a, -0.02, -0.85, 0.06), 0.026, 0.016, hi)
    if hi:
        rv = []
        for j in range(14):
            a = lerp(-half + 0.1, half - 0.1, j / 13)
            for v, off in ((-0.075, 0.018), (-0.135, 0.018), (-0.845, 0.122)):
                nn = normal(surf, a, v, cen)
                rv.append((surf(a, v) + nn * off, nn))
        for a in (-half, half):
            for k in range(9):
                v = lerp(-0.1, -0.83, k / 8)
                nn = normal(surf, a, v, cen)
                rv.append((surf(a, v) + nn * 0.075, nn))
        rivets(pc, rv, 0.019, hi)
    # the leather hanger that ties the plate to the shoulder strap
    for g in (-0.62, 0.62):
        q = surf(g, -0.03)
        n = normal(surf, g, -0.03, cen)
        P = [[q + V((0, u, 0)) * 0.05 + ax * d + n * 0.026 for u in (-1, 0, 1)] for d in (-0.13, 0.0, 0.12)]
        slab(pc, P, 0.016, "LEATHER")
        buckle(pc, q + ax * 0.02 + n * 0.04, n, ax, 0.075, 0.085, hi)


def upper_arm(hi, s):
    pc = piece(SIDE[s] + "UpperArm")
    sleeve(pc, hi, s)
    pauldron(pc, hi, s)
    return pc


def bracer(pc, hi, s):
    e, w = sx(ARM_ELBOW, s), sx(ARM_WRIST, s)
    ax = (w - e).normalized()
    out = V((s * -ax.z, 0, s * ax.x)).normalized()
    if out.x * s < 0:
        out = -out
    fwd = V((0, 1, 0))

    def surf(a, z):
        t = -z
        c = e.lerp(w, t)
        r = lerp(0.235, 0.175, t) + 0.035 * smooth((t - 0.86) / 0.14)
        return c + out * (math.cos(a) * r) + fwd * (math.sin(a) * r * 1.04)

    cen = lambda z: e.lerp(w, -z)
    # outer iron shell over a leather lining
    nu, nv = (28, 14) if hi else (16, 5)
    P = [[surf(lerp(-1.95, 1.95, j / nu), lerp(-0.13, -0.99, i / nv)) for j in range(nu + 1)] for i in range(nv + 1)]
    slab(pc, P, 0.03, "IRON", offset=0.012)
    Q = [[surf(lerp(1.95, 2 * math.pi - 1.95, j / (nu // 2)), lerp(-0.14, -0.98, i / nv)) for j in range(nu // 2 + 1)] for i in range(nv + 1)]
    slab(pc, Q, 0.02, "LEATHER", offset=0.0)
    # bronze cuffs and spine
    for v, wid in ((-0.13, 0.026), (-0.985, 0.03)):
        trim(pc, [surf(lerp(-1.95, 1.95, j / nu), v) + normal(surf, lerp(-1.95, 1.95, j / nu), v, cen) * 0.032 for j in range(nu + 1)], wid, 0.016, hi)
    for a in (-1.95, 1.95):
        trim(pc, [surf(a, lerp(-0.13, -0.985, i / 8)) + normal(surf, a, -0.5, cen) * 0.032 for i in range(9)], 0.016, 0.012, hi)
    # forged bronze shield over the outer forearm, as on the sheet's side view
    S = []
    for i in range(6 if hi else 3):
        f = i / (5 if hi else 2)
        v = lerp(-0.2, -0.56, f)
        half = lerp(0.62, 0.20, f * f)
        S.append([surf(g * half, v) + normal(surf, g * half, v, cen) * 0.047 for g in (-1, -0.5, 0, 0.5, 1)])
    slab(pc, S, 0.018, "BRONZE")
    I = []
    for i in range(6 if hi else 3):
        f = i / (5 if hi else 2)
        v = lerp(-0.24, -0.53, f)
        half = lerp(0.44, 0.10, f * f)
        I.append([surf(g * half, v) + normal(surf, g * half, v, cen) * 0.058 for g in (-1, -0.5, 0, 0.5, 1)])
    slab(pc, I, 0.012, "IRON")
    # crossed red lashing on the inner forearm
    for k in range(4):
        v0, v1 = -0.26 - k * 0.15, -0.38 - k * 0.15
        for a0, a1 in ((1.05, 2.25), (2.25, 1.05)):
            for side in (1, -1):
                pts = [surf(side * lerp(a0, a1, i / 6), lerp(v0, v1, i / 6)) + normal(surf, side * lerp(a0, a1, i / 6), lerp(v0, v1, i / 6), cen) * 0.05 for i in range(7)]
                tube(pc, pts, (0.016, 0.007), 6 if hi else 4, "CINNABAR", p=3.0)
    if hi:
        rv = []
        for v in (-0.16, -0.95):
            for j in range(9):
                a = lerp(-1.75, 1.75, j / 8)
                nn = normal(surf, a, v, cen)
                rv.append((surf(a, v) + nn * 0.04, nn))
        rivets(pc, rv, 0.014, hi)


def lower_arm(hi, s):
    pc = piece(SIDE[s] + "LowerArm")
    e, w = sx(ARM_ELBOW, s), sx(ARM_WRIST, s)
    # the under-sleeve carries on past the elbow, overlapping the upper arm so bends stay closed
    tube(pc, curve_pts([e + V((-s * 0.025, 0, 0.17)), e, e.lerp(w, 0.5), w], 16 if hi else 7), lambda t: 0.222 - 0.075 * t, 26 if hi else 14, "CHARCOAL")
    bracer(pc, hi, s)
    return pc


def hand_piece(hi, s):
    pc = piece(SIDE[s] + "Hand")
    hand(pc, hi, s)
    return pc


# -- waist: LowerTorso --------------------------------------------------------------------------------------------

def lower_torso(hi):
    pc = piece("LowerTorso")
    na, nz = (56, 12) if hi else (26, 5)
    pc.grid([[torso_pt(-math.pi + 2 * math.pi * k / na, lerp(-1.05, -0.26, i / nz)) for k in range(na)] for i in range(nz + 1)],
            "CHARCOAL", closed_u=True, cap0=True, cap1=True)
    # the wound sash: several overlapping turns, not a single band
    turns = [(-0.315, 0.10, 0.072, 0.0, 0.006), (-0.365, 0.125, 0.104, 2.2, 0.025), (-0.425, 0.125, 0.122, 4.1, 0.04), (-0.485, 0.14, 0.11, 1.1, 0.04), (-0.55, 0.115, 0.09, 3.0, 0.02)]
    for zc, h, off, ph, amp in turns:
        nr = 5 if hi else 3
        rows = []
        for i in range(nr + 1):
            f = i / nr
            z0 = zc + h * 0.5 - h * f
            row = []
            for k in range(na):
                a = -math.pi + 2 * math.pi * k / na
                z = z0 + amp * math.sin(a * 1.0 + ph)
                bulge = 0.024 * math.sin(math.pi * f)
                fold = 0.006 * math.sin(a * 9 + ph * 2) if hi else 0
                row.append(torso_pt(a, z, off + bulge + fold))
            rows.append(row)
        pc.grid(rows, "CINNABAR", closed_u=True)
    # narrow leather belt over the sash with the bronze buckle at the front
    belt = on_torso(0.138)
    P = [[belt(-1.65 + 3.3 * k / (na // 2), z) for k in range(na // 2 + 1)] for z in (-0.385, -0.45)]
    slab(pc, P, 0.02, "LEATHER")
    b = belt(0.0, -0.418) + V((0, 0.02, 0))
    buckle(pc, b, V((0, 1, 0)), V((0, 0, 1)), 0.20, 0.145, hi)
    # the sash knot, off to the wearer's left
    k0 = belt(-0.42, -0.43) + V((0, 0.03, 0))
    lathe(pc, [(0.0, -0.095), (0.066, -0.084), (0.098, -0.025), (0.092, 0.038), (0.056, 0.09), (0.0, 0.1)], 18 if hi else 10, "CINNABAR", tr(k0), sy=0.72)
    for dx, rz in ((-0.09, 22), (0.09, -22)):
        M = tr(k0 + V((dx, 0.0, 0.01))) @ rot("Y", rz)
        lathe(pc, [(0.0, -0.075), (0.042, -0.05), (0.052, 0.0), (0.042, 0.05), (0.0, 0.075)], 14 if hi else 8, "CINNABAR", M, sy=0.6)
    # jade bi disc on bronze cord, with a bronze cap and silk tassel
    jp = V((-0.175, 0.0, -0.98))
    jp.y = torso_pt(-0.25, -0.62, 0.0).y + 0.30
    tube(pc, [k0 + V((0.02, 0.0, -0.06)), jp + V((0.006, -0.03, 0.27)), jp + V((0, 0.0, 0.11))], 0.0095, 6 if hi else 4, "TASSEL")
    M = tr(jp) @ rot("X", 90)
    seg = 32 if hi else 16
    lathe(pc, [(0.05, 0.0), (0.056, 0.016), (0.075, 0.021), (0.10, 0.018), (0.115, 0.006), (0.115, -0.006), (0.10, -0.018), (0.075, -0.021), (0.056, -0.016), (0.05, 0.0)],
          seg, "JADE", M)
    ty = jp + V((0, 0, -0.108))
    lathe(pc, [(0.0, 0.0), (0.018, -0.008), (0.024, -0.04), (0.03, -0.075), (0.04, -0.09), (0.03, -0.098), (0.0, -0.1)], 14 if hi else 8, "BRONZE", tr(ty))
    # the tassel: a bundle in the master, a flared form in the game mesh that receives its bake
    if hi:
        for k in range(26):
            a = k * 2.4
            r0 = 0.012 + 0.016 * ((k * 7 % 11) / 10)
            top = ty + V((math.cos(a) * r0, math.sin(a) * r0, -0.095))
            ln = 0.30 + 0.05 * ((k * 5 % 7) / 6)
            tube(pc, [top, top + V((math.cos(a) * 0.006, math.sin(a) * 0.006, -ln * 0.5)), top + V((math.cos(a) * 0.016, math.sin(a) * 0.016, -ln))], lambda t: 0.0055 * (1 - 0.5 * t), 5, "TASSEL")
    else:
        lathe(pc, [(0.0, -0.09), (0.03, -0.1), (0.04, -0.25), (0.052, -0.41), (0.0, -0.42)], 10, "TASSEL", tr(ty))
    # front and back aprons: lamellar with a riveted bronze border, wider than they are long
    apron(pc, hi, 1)
    apron(pc, hi, -1)
    # charcoal tabard down the centre back, seen between the back tassets on the sheet
    xs = [lerp(-0.17, 0.17, j / 6) for j in range(7)]
    cloth_panel(pc, [V((x, -0.60, -0.72)) for x in xs], [V((x * 1.1, -0.66, -1.48)) for x in xs], 0.018, "CHARCOAL", 12, 12 if hi else 5, seed=9, fray=0.05)
    return pc


def apron(pc, hi, front):
    half, ztop, zbot = 0.40, -0.56, -1.12
    y0 = 0.47 if front > 0 else -0.50

    def surf(a, z):
        t = max(0.0, (ztop - z) / (ztop - zbot))
        return V((a * 0.46 + 0.0, front * (y0 + 0.06 + 0.075 * t - 0.11 * (a * 0.8) ** 2), z))

    cen = lambda z: V((0, 0, z))
    hw = half / 0.46
    rows = [(-0.585 - 0.102 * r, 0.138, -hw, hw, 12, 0.0 + 0.004 * (5 - r)) for r in range(5)]
    lamellae(pc, surf, cen, rows, hi, stud=0.0125)
    arc = lambda z, off: [surf(lerp(-hw, hw, j / 14), z) + normal(surf, lerp(-hw, hw, j / 14), z, cen) * off for j in range(15)]
    trim(pc, arc(-1.12, 0.06), 0.034, 0.018, hi)
    trim(pc, arc(-0.585, 0.04), 0.03, 0.016, hi)
    for a in (-hw, hw):
        trim(pc, [surf(a, lerp(-0.585, -1.12, i / 8)) + normal(surf, a, -0.9, cen) * 0.05 for i in range(9)], 0.03, 0.017, hi)
    if hi:
        rv = []
        for j in range(12):
            a = lerp(-hw + 0.1, hw - 0.1, j / 11)
            nn = normal(surf, a, -1.12, cen)
            rv.append((surf(a, -1.12) + nn * 0.076, nn))
        rivets(pc, rv, 0.017, hi)


# -- skirts and trousers: UpperLeg, so a stride opens the skirt rather than cutting through it -------------------------

def tasset_surf(s, back=False):
    """A plate curving from the front (or back) of the thigh round to its outside."""
    sign = -1 if back else 1

    def surf(a, z):
        t = max(0.0, (-0.56 - z) / 0.76)
        # a = 0 at the inner front edge, a = 1 at the outer side edge
        ang = lerp(0.36, 1.62, a)
        rx = 0.72 + 0.26 * t
        ry = 0.50 + 0.22 * t
        return V((s * math.sin(ang) * rx, sign * math.cos(ang) * ry, z))

    return surf


def tasset(pc, hi, s, back=False):
    surf = tasset_surf(s, back)
    cen = lambda z: V((0, 0, z))
    nrow = 6
    zt = -0.59
    rows = [(zt - 0.115 * r, 0.15, 0.0, 1.0, 11, 0.0 + 0.004 * (nrow - r)) for r in range(nrow)]
    lamellae(pc, surf, cen, rows, hi, stud=0.0135)
    zb = zt - 0.115 * (nrow - 1) - 0.15
    arc = lambda z, off: [surf(j / 14, z) + normal(surf, j / 14, z, cen) * off for j in range(15)]
    trim(pc, arc(zb, 0.06), 0.036, 0.019, hi)
    trim(pc, arc(zt, 0.04), 0.03, 0.016, hi)
    for a in (0.0, 1.0):
        trim(pc, [surf(a, lerp(zt, zb, i / 10)) + normal(surf, a, -1.1, cen) * 0.052 for i in range(11)], 0.03, 0.017, hi)
    if hi:
        rv = []
        for j in range(11):
            a = (j + 0.5) / 11
            nn = normal(surf, a, zb, cen)
            rv.append((surf(a, zb) + nn * 0.078, nn))
        for a in (0.0, 1.0):
            for k in range(7):
                z = lerp(zt - 0.05, zb + 0.05, k / 6)
                nn = normal(surf, a, z, cen)
                rv.append((surf(a, z) + nn * 0.07, nn))
        rivets(pc, rv, 0.017, hi)
    return zb


def upper_leg(hi, s):
    pc = piece(SIDE[s] + "UpperLeg")
    X = s * LEG_X
    # baggy trousers: full from hip to knee, gathered below it by the lower-leg piece
    nz, na = (28, 32) if hi else (10, 16)

    def leg_ring(z, grow=0.0):
        t = (-0.82 - z) / 1.06
        r = 0.29 + 0.145 * smooth((t - 0.25) / 0.55)
        fold = lambda th: 1 + (0.035 * math.sin(th * 5 + t * 6 + s) + 0.018 * math.sin(th * 11 - t * 9)) * smooth(t * 2)
        return sring(V((X + s * 0.02 * t, 0.0, z)), V((1, 0, 0)), V((0, 1, 0)), r * 0.99 + grow, r + grow, na, 2.1, -math.pi / 2, None, fold)

    rows = [leg_ring(lerp(-0.80, -1.80, i / nz)) for i in range(nz + 1)]
    pc.grid(rows, "PLAID", closed_u=True, cap0=True, cap1=True)
    # front tasset, back tasset
    tasset(pc, hi, s, False)
    tasset(pc, hi, s, True)
    # the torn cinnabar under-skirt outside each tasset, and the centre panels in halves
    nc, nr = (16, 14) if hi else (8, 5)
    ang = [lerp(-0.3, 2.86, j / 16) for j in range(17)]
    top = [V((s * math.sin(a) * 0.70, math.cos(a) * 0.48, -0.72)) for a in ang]
    bot = [V((s * math.sin(a) * 1.02, math.cos(a) * 0.76, -1.56)) for a in ang]
    cloth_panel(pc, top, bot, 0.018, "CINNABAR", 34, nr, seed=50 + s, fray=0.075)
    for f, sign in ((1, 1), (-1, 2)):
        xs = [s * lerp(0.0 if f > 0 else 0.12, 0.46, j / 6) for j in range(7)]
        y0, y1 = (0.46, 0.58) if f > 0 else (-0.50, -0.60)
        t0 = [V((x, y0 + f * 0.04, -1.02)) for x in xs]
        b0 = [V((x * 1.06, y1, -1.62)) for x in xs]
        cloth_panel(pc, t0, b0, 0.018, "CINNABAR", 14, nr, seed=70 + s + sign, fray=0.07)
    # the long sash tail hangs in front of the left thigh
    if s < 0:
        p0 = V((-0.13, 0.615, -0.56))
        p1 = V((-0.14, 0.70, -1.70))
        xs = [lerp(-0.085, 0.085, j / 4) for j in range(5)]
        cloth_panel(pc, [p0 + V((x, 0, 0)) for x in xs], [p1 + V((x * 1.1, 0, 0)) for x in xs], 0.018, "CINNABAR", 8 if hi else 4, 20 if hi else 8, seed=99, fray=0.05, cut=False)
    return pc


def lower_leg(hi, s):
    pc = piece(SIDE[s] + "LowerLeg")
    X = s * (LEG_X + 0.02)
    nz, na = (24, 30) if hi else (9, 14)
    # the gathered trouser bloused over the greave: it hides the knee from inside the thigh form
    rows = []
    for i in range(nz + 1):
        z = lerp(-1.66, -2.12, i / nz)
        t = i / nz
        r = interp([(0.0, 0.232), (0.1, 0.25), (0.28, 0.32), (0.48, 0.395), (0.7, 0.43), (1.0, 0.43)], 1 - t)[0]
        fold = lambda th, t=t: 1 + (0.022 + 0.05 * smooth((t - 0.25) / 0.6)) * math.sin(th * 7 + s + t * 1.4) + (0.014 + 0.028 * smooth((t - 0.3) / 0.6)) * math.sin(th * 13 - t * 2)
        rows.append(sring(V((X, 0.0, z)), V((1, 0, 0)), V((0, 1, 0)), r, r, na, 2.1, -math.pi / 2, None, fold))
    pc.grid(rows, "PLAID", closed_u=True, cap0=True, cap1=True)
    # leather boot shaft, with the calf's weight behind
    rows = []
    for i in range(nz + 1):
        t = i / nz
        z = lerp(-2.02, -2.78, t)
        calf = gauss((t - 0.22) ** 2, 0.2)
        rows.append(sring(V((X, 0.0, z)), V((1, 0, 0)), V((0, 1, 0)), 0.2 + 0.03 * calf - 0.04 * t, 0.2 + 0.012 * calf - 0.04 * t, na, 2.2, -math.pi / 2, 0.2 + 0.06 * calf - 0.04 * t))
    pc.grid(rows, "BOOT", closed_u=True, cap0=True, cap1=True)
    # iron greave wrapping the shin in five splints
    def gsurf(a, z):
        k = lerp(0.245, 0.192, smooth((-2.08 - z) / 0.58))
        return V((X + math.sin(a) * k, 0.012 + math.cos(a) * (k + 0.004), z))

    nsp = 9
    for k in range(nsp):
        a = -2.62 + 5.24 * (k + 0.5) / nsp
        P = []
        for z in ([lerp(-2.08, -2.66, f) for f in (0, 0.25, 0.5, 0.75, 1)] if hi else (-2.08, -2.37, -2.66)):
            P.append([gsurf(a + g * 0.29, z) + V((math.sin(a + g * 0.29), math.cos(a + g * 0.29), 0)) * (0.016 + 0.006 * (k % 2)) for g in (-1, 0, 1)])
        slab(pc, P, 0.026, "IRON")
    if hi:
        rv = []
        for k in range(nsp):
            a = -2.62 + 5.24 * (k + 0.5) / nsp
            for z in (-2.13, -2.6):
                rv.append((gsurf(a, z) + V((math.sin(a), math.cos(a), 0)) * 0.036, V((math.sin(a), math.cos(a), 0))))
        rivets(pc, rv, 0.015, hi)
    # the bronze knee-and-shin plate: a tapered shield with an iron spine, as the sheet draws it
    def sh(a, z):
        return gsurf(a, z) + V((math.sin(a), math.cos(a), 0)) * 0.05

    S, I = [], []
    for i in range(8 if hi else 4):
        f = i / (7 if hi else 3)
        z = lerp(-1.93, -2.46, f)
        half = lerp(0.74, 0.14, smooth(f * 1.05))
        S.append([sh(g * half, z) for g in (-1, -0.5, 0, 0.5, 1)])
        ih = lerp(0.34, 0.04, smooth(f * 1.05))
        zi = lerp(-1.96, -2.42, f)
        I.append([sh(g * ih, zi) + V((0, 0.014, 0)) for g in (-1, -0.5, 0, 0.5, 1)])
    slab(pc, S, 0.022, "BRONZE")
    slab(pc, I, 0.014, "IRON")
    if hi:
        rv = []
        for z in (-2.0, -2.12, -2.24):
            for g in (-1, 1):
                a = g * 0.5 * (1 - (-1.93 - z) / 0.55)
                rv.append((sh(a, z) + V((0, 0.012, 0)), V((math.sin(a), math.cos(a), 0))))
        rivets(pc, rv, 0.015, hi)
    # red wrappings: crossed at the top, a band and strap at the ankle
    wrap = lambda a, z, r=0.29: V((X + math.sin(a) * r, 0.015 + math.cos(a) * r * 1.03, z))
    w = 0.036
    for k, (z0, z1, ph) in enumerate(((-2.08, -2.24, 0.0), (-2.24, -2.06, math.pi), (-2.16, -2.34, 1.2), (-2.34, -2.16, 1.2 + math.pi))):
        pts = [wrap(ph + 2 * math.pi * i / 22, lerp(z0, z1, 0.5 - 0.5 * math.cos(2 * math.pi * i / 22)) if False else lerp(z0, z1, i / 22), 0.262 + 0.002 * k) for i in range(23)]
        tube(pc, pts, (w, 0.011), 6 if hi else 4, "CINNABAR", p=3.0)
    ring = [wrap(2 * math.pi * i / 22, -2.60, 0.238) for i in range(22)]
    trim(pc, ring, 0.052, 0.013, hi, "CINNABAR", closed=True)
    ring = [wrap(2 * math.pi * i / 22, -2.60 + 0.002 * math.sin(i), 0.25) for i in range(22)]
    trim(pc, ring, 0.024, 0.010, hi, "LEATHER", closed=True)
    buckle(pc, wrap(s * 0.65, -2.60, 0.255), V((math.sin(s * 0.65), math.cos(s * 0.65), 0)), V((0, 0, 1)), 0.075, 0.08, hi)
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
