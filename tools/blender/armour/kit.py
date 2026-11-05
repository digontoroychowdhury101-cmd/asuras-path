"""Fitted foundation for every armour set: the production player's measured R15 body plus the forms all three
suits share. A suit is one rigid MeshPart group per limb, so nothing may depend on a skinned deformation.

Coordinates are studs at scale 1, rest pose. Blender +X = the wearer's right, +Y = forward, +Z = Roblox +Y.
hi=True builds the detailed master, hi=False the game mesh that receives the master's bake.
Measured source: outputs/mac-followup-2026-11-02/armour/player_body_measured.json.
"""
import math
import random

from mathutils import Matrix

from lib import V, box, curve_pts, gauss, hring, lathe, rot, slab, sring, tr, tube

# Limb boxes as Studio reports them (size x, y, z) with R15 rest centres (x, y, z in Roblox axes).
LIMBS = {
    "Head": ((1.196, 1.203, 1.198), (0, 1.586, 0)), "UpperTorso": ((2, 1.6, 1), (0, 0.2, 0)), "LowerTorso": ((2, 0.4, 1), (0, -0.8, 0)),
    "LeftUpperArm": ((1, 1.169, 1), (-1.5, 0.369, 0)), "LeftLowerArm": ((1, 1.052, 1), (-1.5, -0.224, 0)), "LeftHand": ((1, 0.3, 1), (-1.5, -0.85, 0)),
    "RightUpperArm": ((1, 1.169, 1), (1.5, 0.369, 0)), "RightLowerArm": ((1, 1.052, 1), (1.5, -0.224, 0)), "RightHand": ((1, 0.3, 1), (1.5, -0.85, 0)),
    "LeftUpperLeg": ((1, 1.217, 1), (-0.5, -1.421, 0)), "LeftLowerLeg": ((1, 1.193, 1), (-0.5, -2.201, 0)), "LeftFoot": ((1, 0.3, 1), (-0.5, -2.85, 0)),
    "RightUpperLeg": ((1, 1.217, 1), (0.5, -1.421, 0)), "RightLowerLeg": ((1, 1.193, 1), (0.5, -2.201, 0)), "RightFoot": ((1, 0.3, 1), (0.5, -2.85, 0)),
}
PIVOT = {k: V((c[0], -c[2], c[1])) for k, (_, c) in LIMBS.items()}

NECK_Z, WAIST_Z, HIP_Z, KNEE_Z, ANKLE_Z, SOLE_Z = 1.0, -0.6, -1.0, -1.84, -2.73, -3.0
# The weapon's haft runs along the hand's -Z through the bottom of the hand box (CharacterService.equip),
# so the fist has to close there or every weapon floats outside the hand.
FIST = V((1.5, 0.0, -1.0))
HAFT_R = 0.075
ARM_TOP, ARM_ELBOW, ARM_WRIST = V((1.0, 0, 0.80)), V((1.32, 0, 0.03)), V((1.46, 0, -0.72))
LEG_X = 0.5


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def interp(table, z):
    if z <= table[0][0]:
        return table[0][1:]
    for (z0, *a), (z1, *b) in zip(table, table[1:]):
        if z <= z1:
            t = (z - z0) / (z1 - z0)
            return tuple(lerp(x, y, t) for x, y in zip(a, b))
    return table[-1][1:]


# torso: z, half-width, front depth, back depth, centre y, superellipse power
TORSO = [
    (-1.05, 0.56, 0.32, 0.36, 0.0, 2.2), (-0.85, 0.68, 0.40, 0.44, 0.0, 2.4), (-0.62, 0.62, 0.36, 0.38, 0.0, 2.3),
    (-0.42, 0.56, 0.32, 0.33, 0.0, 2.2), (-0.15, 0.59, 0.35, 0.34, 0.0, 2.2), (0.15, 0.69, 0.42, 0.38, 0.0, 2.3),
    (0.48, 0.77, 0.46, 0.41, 0.0, 2.4), (0.70, 0.78, 0.43, 0.40, 0.0, 2.5), (0.86, 0.72, 0.36, 0.36, 0.0, 2.4),
    (0.97, 0.44, 0.27, 0.29, -0.01, 2.2), (1.05, 0.22, 0.19, 0.21, -0.01, 2.0),
]


def torso_pt(a, z, off=0.0):
    """a 0 = front (+Y), +pi/2 = the wearer's right (+X)."""
    rx, ryf, ryb, cy, p = interp(TORSO, z)
    s, c = math.sin(a), math.cos(a)
    x = math.copysign(abs(s) ** (2 / p), s) * (rx + off)
    y = cy + math.copysign(abs(c) ** (2 / p), c) * ((ryf if c >= 0 else ryb) + off)
    return V((x, y, z))


def on_torso(off):
    return lambda a, z: torso_pt(a, z, off)


def torso_centre(z):
    return V((0, interp(TORSO, z)[3], z))


def normal(surf, a, z, centre):
    p = surf(a, z)
    da, dz = surf(a + 1e-3, z) - surf(a - 1e-3, z), surf(a, z + 1e-3) - surf(a, z - 1e-3)
    n = da.cross(dz)
    if n.length < 1e-9:
        n = p - centre(z)
    n.normalize()
    return n if n.dot(p - centre(z)) >= 0 else -n


def rivets(pc, pts, r, hi, mat="BRONZE"):
    if not hi:
        return
    for p, n in pts:
        M = Matrix.Translation(p) @ n.to_track_quat("Z", "Y").to_matrix().to_4x4()
        lathe(pc, [(r, 0.0), (r * 0.82, r * 0.5), (r * 0.42, r * 0.78), (0.0, r * 0.86)], 8, mat, M, cap0=True)


def lamellae(pc, surf, centre, rows, hi, thick=0.016, tilt=0.05, stud=0.0125, lace="LACE", plate="IRON"):
    """Riveted rows, each riding over the one below. rows: (top, height, a0, a1, plates, offset).
    Master: a separately forged plate each, a rivet each and a lacing cord each row.
    Game: one scalloped band per row, tilted the same, so rim silhouettes and row shadows survive."""
    for r, (zt, h, a0, a1, n, off) in enumerate(rows):
        da = (a1 - a0) / n
        if hi:
            for k in range(n):
                ac = a0 + da * (k + 0.5)
                w = da * 0.49
                P = []
                for f in (0.0, 0.3, 0.65, 0.88, 1.0):
                    z = zt - h * f
                    shrink = 1.0 if f < 0.9 else 0.86
                    row = []
                    for g in (-1, -0.5, 0, 0.5, 1):
                        a = ac + g * w * shrink
                        row.append(surf(a, z) + normal(surf, a, z, centre) * (off + tilt * f + 0.004 * (k % 2) + 0.0025 * r))
                    P.append(row)
                slab(pc, P, thick, plate)
                zs = zt - h * 0.52
                nn = normal(surf, ac, zs, centre)
                rivets(pc, [(surf(ac, zs) + nn * (off + tilt * 0.52 + 0.004 * (k % 2) + 0.0025 * r + thick * 0.5), nn)], stud, hi)
            ring = []
            zc = zt - h * 0.16
            for k in range(max(8, n * 3) + 1):
                a = a0 + (a1 - a0) * k / max(8, n * 3)
                ring.append(surf(a, zc) + normal(surf, a, zc, centre) * (off + tilt * 0.16 + 0.004 + 0.0025 * r + thick * 0.5))
            tube(pc, ring, 0.0075, 5, lace)
        else:
            P = []
            cols = n
            for f in (0.0, 1.0):
                row = []
                for j in range(cols + 1):
                    a = a0 + (a1 - a0) * j / cols
                    z = zt - h * f  # a straight band: the plates themselves come from the bake, square-cut as on the sheet
                    row.append(surf(a, z) + normal(surf, a, z, centre) * (off + tilt * f + 0.0025 * r + 0.004))
                P.append(row)
            slab(pc, P, 0.026, plate)


def trim(pc, pts, w, h, hi, mat="BRONZE", up=V((0, 0, 1)), closed=False):
    """A forged edge strip along a path."""
    path = pts + pts[:1] if closed else pts
    tube(pc, path, (w, h), 8 if hi else 4, mat, cap0=not closed, cap1=not closed, p=3.0, up=up)


def strap(pc, surf, centre, ctrl, width, thick, mat, n, off=0.0, hi=True, holes=0):
    """A flat strap lying on a surface. ctrl: (a, z) points. Returns its centre path."""
    C = curve_pts([V((a, z, 0)) for a, z in ctrl], n)
    pts = [surf(c.x, c.y) for c in C]
    ns = [normal(surf, c.x, c.y, centre) for c in C]
    pts = [p + m * off for p, m in zip(pts, ns)]
    rows = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        side = ns[i].cross(t).normalized()
        rows.append([p + side * (g * width * 0.5) + ns[i] * ((0.0035 if abs(g) < 0.8 else 0) if hi else 0) for g in (-1, -0.45, 0.45, 1)])
    slab(pc, rows, thick, mat)
    return list(zip(pts, ns))


def buckle(pc, p, n, up, w, h, hi, mat="BRONZE"):
    """A square forged buckle frame with a tongue, lying on normal n."""
    side = n.cross(up).normalized()
    upv = side.cross(n).normalized()
    corners = [p + side * (sx * w * 0.5) + upv * (sy * h * 0.5) + n * 0.012 for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    trim(pc, corners, 0.016 if hi else 0.02, 0.012 if hi else 0.014, hi, mat, up=n, closed=True)
    tube(pc, [p - side * (w * 0.46) + n * 0.018, p + side * (w * 0.46) + n * 0.024], 0.0085, 6 if hi else 4, mat)


def torn(z, j, seed, depth):
    """Hem height for column j: long rips and short frays, the same for master and game."""
    r = random.Random(seed * 1000 + j)
    slow = math.sin(j * 0.71 + seed) * 0.5 + math.sin(j * 1.93 + seed * 2.0) * 0.35
    return z + depth * (slow + (r.random() - 0.5) * 0.8 - (1.0 if r.random() < 0.14 else 0.0))


def cloth_panel(pc, top, bottom, thick, mat, cols, rows, seed=1, fray=0.1, cut=True):
    """Hanging cloth between two polylines of equal sampling; the last row is torn."""
    P = []
    for i in range(rows + 1):
        f = i / rows
        row = []
        for j in range(cols + 1):
            u = j / cols
            k = u * (len(top) - 1)
            ka = min(int(k), len(top) - 2)
            a = top[ka].lerp(top[ka + 1], k - ka)
            b = bottom[ka].lerp(bottom[ka + 1], k - ka)
            p = a.lerp(b, f)
            if i == rows and fray:
                p = p + V((0, 0, torn(0.0, j, seed, fray)))
            row.append(p)
        P.append(row)
    slab(pc, P, thick, mat)
    if cut and fray:
        rng = random.Random(seed * 77)
        for j in range(cols):
            if rng.random() < 0.3:
                a, b = P[-1][j], P[-1][j + 1]
                ln = fray * (0.8 + 1.4 * rng.random())
                S = [[a.lerp(b, g) + V((0, 0, -ln * f)) * 1.0 + (b - a) * (0.5 - g) * 0.7 * f for g in (0.0, 0.5, 1.0)] for f in (-0.1, 0.5, 1.0)]
                slab(pc, S, thick * 0.8, mat)
    return P


def bronze_boss(pc, p, n, r, hi):
    """The round bronze boss: raised rim, ring, domed centre."""
    M = Matrix.Translation(p) @ n.to_track_quat("Z", "Y").to_matrix().to_4x4()
    seg = 32 if hi else 16
    lathe(pc, [(r, 0.0), (r, 0.018), (r * 0.9, 0.03), (r * 0.82, 0.022), (r * 0.64, 0.018), (r * 0.58, 0.03), (r * 0.46, 0.022),
               (r * 0.34, 0.03), (r * 0.18, 0.052), (0.0, 0.058)], seg, "BRONZE", M, cap0=True)
    if hi:
        for k in range(10):
            a = k * 2 * math.pi / 10
            q = M @ V((math.cos(a) * r * 0.74, math.sin(a) * r * 0.74, 0.024))
            rivets(pc, [(q, n)], r * 0.07, hi)


# -- shared body parts: hands and feet fit every set -------------------------------------------------------------

def sx(v, s):
    return V((v.x * s, v.y, v.z))


def hand(pc, hi, s, glove="LEATHER", guard="IRON", skin="SKIN"):
    """Fingerless glove. The right hand is a fist round the weapon haft; the left hangs half open."""
    F = sx(FIST, s)
    grip = s > 0
    X, Y = V((s, 0, 0)), V((0, 1, 0))
    nz, na = (12, 22) if hi else (6, 12)
    bottom = F.z - (0.10 if grip else 0.06)
    rows = []
    for i in range(nz + 1):
        t = i / nz
        z = lerp(-0.68, bottom, t)
        cx = lerp(sx(ARM_WRIST, s).x, F.x + s * 0.03, smooth(t * 1.4))
        rows.append(sring(V((cx, 0.0, z)), X, Y, lerp(0.105, 0.135, smooth(t * 2)) * (1 - 0.25 * smooth((t - 0.8) / 0.2)),
                          lerp(0.125, 0.165, smooth(t * 2)) * (1 - 0.2 * smooth((t - 0.8) / 0.2)), na, 2.6))
    pc.grid(rows, glove, closed_u=True, cap0=True, cap1=True)
    # iron plate over the back of the hand
    P = [[V((F.x + s * (0.178 - 0.05 * u * u), u * 0.145, z)) for u in (-1, -0.5, 0, 0.5, 1)] for z in (-0.74, -0.84, -0.94)]
    slab(pc, P, 0.018, guard)
    ys = (0.118, 0.040, -0.038, -0.112)
    lens = (0.96, 1.05, 1.0, 0.84)
    for ly, L in zip(ys, lens):
        n = 18 if hi else 8
        pts = []
        for k in range(n):
            t = k / (n - 1)
            ang = math.radians(5 - (215 if grip else 165) * L * t)
            rr = HAFT_R + (0.05 if grip else 0.075)
            pts.append(V((F.x + s * math.cos(ang) * rr, ly, F.z + math.sin(ang) * rr + (0.0 if grip else 0.03))))
        cut = int(n * 0.34)
        rad = lambda t: 0.042 * (1 - 0.18 * t)
        tube(pc, pts[:cut + 1], lambda t, c=cut / (n - 1): rad(t * c) + 0.005, 12 if hi else 6, glove, up=V((0, 1, 0)))
        tube(pc, pts[cut:], lambda t, c=cut / (n - 1): rad(c + t * (1 - c)), 12 if hi else 6, skin, up=V((0, 1, 0)))
    th = [V((F.x + s * 0.03, 0.15, -0.80)), V((F.x - s * 0.015, 0.205, F.z + 0.10)), V((F.x - s * 0.09, 0.19, F.z + 0.03)), V((F.x - s * 0.135, 0.15, F.z - 0.03))]
    tube(pc, curve_pts(th[:2], 5 if hi else 3), 0.05, 12 if hi else 6, glove)
    tube(pc, curve_pts(th[1:], 12 if hi else 5), lambda t: 0.046 * (1 - 0.25 * t), 12 if hi else 6, skin)
    return pc


def boot(pc, hi, s, upper="LEATHER", toe="IRON", welt="BRONZE"):
    X = s * (LEG_X + 0.02)
    n = 26 if hi else 12
    rows = []

    def prof(t):
        y = lerp(-0.27, 0.56, t)
        top = SOLE_Z + lerp(0.40, 0.15, smooth((t - 0.2) / 0.62)) + 0.05 * smooth((t - 0.86) / 0.14)
        bot = SOLE_Z + 0.06 + 0.05 * smooth((t - 0.84) / 0.16)
        w = 0.185 * (1 - 0.2 * smooth((t - 0.7) / 0.3)) * (1 - 0.6 * smooth((t - 0.94) / 0.06)) + 0.012
        heel = 0.55 + 0.45 * smooth(t / 0.16) ** 0.6
        w *= heel
        top = bot + (top - bot) * (0.82 + 0.18 * smooth(t / 0.12))
        return y, top, bot, w

    for i in range(n + 1):
        y, top, bot, w = prof(i / n)
        rows.append(sring(V((X, y, (top + bot) / 2)), V((1, 0, 0)), V((0, 0, 1)), w, (top - bot) / 2, 20 if hi else 10, 2.8))
    pc.grid(rows, upper, closed_u=True, cap0=True, cap1=True)
    # layered sole with a forged welt line
    S = []
    for k in range(14 if hi else 7):
        t = k / (13 if hi else 6)
        y, _, bot, w = prof(t)
        S.append([V((X - w - 0.012, y, bot - 0.022)), V((X + w + 0.012, y, bot - 0.022))])
    slab(pc, [[r[0] for r in S], [r[1] for r in S]], 0.075, "LEATHER_SOLE")
    # iron toe cap and two instep lames
    C = []
    for i in range(7 if hi else 4):
        t = lerp(0.68, 1.0, i / (6 if hi else 3))
        y, top, bot, w = prof(t)
        c = V((X, y, (top + bot) / 2))
        C.append(sring(c, V((1, 0, 0)), V((0, 0, 1)), w + 0.013, (top - bot) / 2 + 0.013, 20 if hi else 10, 2.8))
    pc.grid([[p for p in row] for row in C], toe, closed_u=True, cap1=True)
    for k in range(3):
        y, top, _, w = prof(0.42 + k * 0.1)
        P = [[V((X + math.sin(a) * (w + 0.012), y + dy, top - 0.045 + math.cos(a) * 0.06)) for a in (-1.25, -0.6, 0, 0.6, 1.25)] for dy in (-0.05, 0.05)]
        slab(pc, P, 0.016, toe, offset=0.005 + 0.004 * k)
    # ankle strap with bronze hardware
    for yy, zz in ((0.05, SOLE_Z + 0.31),):
        ring = [V((X + math.cos(a) * 0.21, yy - 0.06 + math.sin(a) * 0.26, zz + 0.02 * math.sin(a))) for a in [2 * math.pi * k / 20 for k in range(20)]]
        trim(pc, ring, 0.03, 0.009, hi, "LEATHER", closed=True)
    buckle(pc, V((X + s * 0.205, -0.01, SOLE_Z + 0.31)), V((s, 0, 0)), V((0, 0, 1)), 0.07, 0.07, hi, welt)
    return pc
