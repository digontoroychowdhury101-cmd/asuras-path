"""Hollow-Bell Warden: the grave field's keeper, a giant who once rang the monastery's funeral bell and now wears it.

His own body, not the monk's or the swordsman's: a hunched barrel torso under a grave robe closed left over right
(as the dead are dressed), a hump that carries the bell's rim, arms hanging outside the torso with ash-skin forearms
in iron bracers and fists the size of the bell's bosses, a rope belt hung with spirit tablets over a bell-shaped
robe skirt, wrapped shins and iron-shod boots. The head is a cast verdigris bell over head and shoulders: three raised
bands, rows of bosses, one ember crack from crown to rim with a failed paper seal pasted over it, a single ember eye
slit, a chain bound diagonally round it and yellowed talismans hanging from its rim. No face is ever shown.

His crescent-moon spade is its own piece bound to the right hand (AsuraRole=Weapon) on the grip line through the
right fist (+Y at rest): a crescent blade on the front end with two jingling rings, a burial spade on the butt. The
left fist takes the shaft wherever it sits comfortably in the clips (warden_clips.py). build(hi): hi=True is the master, hi=False the game mesh.
"""
import math
import random

import body as zb
from lib import V, Piece, box, curve_pts, gauss, lathe, rot, slab, sring, tr, tube
from monk import bands, sphere, sx

G = gauss
lerp, smooth, interp = zb.lerp, zb.smooth, zb.interp
NAME = "Warden"
# broad shoulders: the arms hang outside a torso wider than the R15 shoulder joints (castlib solves for FIST)
ARM_TOP, ARM_ELBOW, ARM_WRIST = V((1.08, 0, 0.80)), V((1.16, 0.0, 0.0)), V((1.20, 0.0, -0.68))
FIST = V((1.22, 0.0, -0.88))
HIP_X, SOLE_Z = 0.46, -3.0
SHAFT_LEFT = 1.0          # leather grips this far either side of the right fist: the left hand slides between them
SHAFT_R = 0.054
# the shaft crosses each palm diagonally (as a polearm's does), not square to the forearm: the curled fingers and the
# whole spade are turned this far about X through the fist centre, the crescent forward and down at rest
GRIP_TILT = -65.0
BELL_C = V((0.0, 0.17, 0.0))   # the bell's axis sits a little forward: it overhangs the chest

# barrel chest and hump under the robe, the top pitched forward (he stoops under the bell): z, half-width, front depth, back depth, centre y, superellipse power
TORSO = [
    (-1.05, 0.62, 0.42, 0.40, 0.02, 2.2),
    (-0.85, 0.66, 0.46, 0.42, 0.03, 2.2),
    (-0.60, 0.66, 0.50, 0.42, 0.05, 2.3),
    (-0.35, 0.66, 0.52, 0.42, 0.05, 2.4),
    (-0.10, 0.70, 0.50, 0.44, 0.04, 2.5),
    (0.20, 0.80, 0.48, 0.50, 0.06, 2.6),
    (0.50, 0.90, 0.44, 0.60, 0.10, 2.8),
    (0.70, 0.96, 0.40, 0.66, 0.13, 2.8),
    (0.86, 0.88, 0.33, 0.68, 0.16, 2.6),
    (0.98, 0.62, 0.26, 0.62, 0.18, 2.3),
    (1.06, 0.36, 0.20, 0.50, 0.18, 2.0),
]

# the bell's outer wall (radius, z) from the rim lip to the crown
BELL_OUT = [(0.585, 0.975), (0.607, 1.0), (0.602, 1.04), (0.566, 1.08), (0.532, 1.2), (0.506, 1.4), (0.489, 1.6),
            (0.473, 1.78), (0.452, 1.88), (0.402, 1.955), (0.30, 2.0), (0.16, 2.02), (0.0, 2.026)]
BELL_IN = [(0.0, 1.89), (0.30, 1.865), (0.43, 1.76), (0.462, 1.5), (0.49, 1.2), (0.532, 1.02), (0.556, 0.975)]
BANDS_Z = (1.10, 1.36, 1.78)


def torso_pt(theta, z, off=0.0):
    rx, ryf, ryb, cy, p = interp(TORSO, z)
    s, c = math.sin(theta), math.cos(theta)
    x = math.copysign(abs(s) ** (2 / p), s) * (rx + off)
    y = cy + math.copysign(abs(c) ** (2 / p), c) * ((ryf if c >= 0 else ryb) + off)
    return V((x, y, z))


def centre(z):
    return V((0, interp(TORSO, z)[3], z))


def robe_off(a, z, hi=True):
    """Outward offset of the robe over the torso: the hump and trapezius masses, and heavy cloth folds."""
    back = abs(abs(a) - math.pi)
    d = 0.08 * G(back ** 2, 0.55) * G((z - 0.62) ** 2, 0.07)
    d += 0.03 * G((abs(a) - 2.3) ** 2, 0.15) * G((z - 0.86) ** 2, 0.03)
    d += (0.014 if hi else 0.007) * math.sin(7 * a + 2.5 * z) * smooth((0.9 - z) / 0.4)
    return d


def robe_pt(a, z, extra=0.0):
    return torso_pt(a, z, robe_off(a, z) + extra)


def bell_r(z, table=BELL_OUT):
    rows = sorted(table, key=lambda rz: rz[1])
    if z <= rows[0][1]:
        return rows[0][0]
    for (r0, z0), (r1, z1) in zip(rows, rows[1:]):
        if z <= z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return rows[-1][0]


def bell_pt(a, z, off=0.0):
    """Point on the bell's outer wall at angle a (0 = his front, +pi/2 = his right)."""
    r = bell_r(z) + off
    return BELL_C + V((math.sin(a) * r, math.cos(a) * r, z))


def bell_n(a):
    return V((math.sin(a), math.cos(a), 0.0))


# ---------------------------------------------------------------------------------------------------------
def head(hi):
    pc = Piece(NAME + "_Head", "Head")
    n = 72 if hi else 30
    M = tr(BELL_C)
    lathe(pc, BELL_OUT + BELL_IN + BELL_OUT[:1], n, "BELL", M)
    # raised bands, the lip bead and four vertical ribs dividing the panels
    for z in BANDS_Z:
        ring = [bell_pt(2 * math.pi * k / n, z, 0.004) for k in range(n)]
        tube(pc, ring + ring[:1], 0.024 if z != BANDS_Z[1] else 0.018, 6 if hi else 4, "BELL", cap0=False, cap1=False)
    for a in (0.62, -0.62, math.pi - 0.62, -(math.pi - 0.62)):
        tube(pc, [bell_pt(a, lerp(BANDS_Z[0], BANDS_Z[2], k / 8), 0.003) for k in range(9)], 0.016, 5 if hi else 4, "BELL")
    # bosses: a row in every panel above the eye slit's band, a lower row on the sides and back, a crown ring
    dome = [(0.034, 0.0), (0.03, 0.018), (0.018, 0.032), (0.0, 0.037)]
    bosses = [(pa + d, 1.66) for pa in (0.0, math.pi / 2, math.pi, -math.pi / 2) for d in (-0.32, 0.0, 0.32)]
    bosses += [(pa + d, 1.23) for pa in (math.pi / 2, math.pi, -math.pi / 2) for d in (-0.32, 0.0, 0.32)]
    bosses += [(2 * math.pi * k / 12 + 0.26, 1.86) for k in range(12)]
    for a, z in bosses:
        p = bell_pt(a, z, -0.004)
        lathe(pc, dome if z < 1.8 else [(r * 0.7, h * 0.7) for r, h in dome], 10 if hi else 6, "BELL",
              tr(p) @ bell_n(a).to_track_quat("Z", "Y").to_matrix().to_4x4(), cap0=True)
    # crown loop (the bell's hanging lug) with a rope still knotted through it
    loop = [BELL_C + V((lerp(-0.17, 0.17, t), 0.0, 1.995 + 0.19 * math.sin(math.pi * t) ** 0.8)) for t in
            [k / (16 if hi else 7) for k in range((16 if hi else 7) + 1)]]
    tube(pc, loop, lambda t: 0.05 + 0.012 * G((t - 0.5) ** 2, 0.04), 8 if hi else 5, "BELL")
    knot = BELL_C + V((0.0, 0.0, 2.17))
    ring = [knot + V((0.0, math.cos(t) * 0.07, math.sin(t) * 0.07)) for t in [2 * math.pi * k / 12 for k in range(12)]]
    tube(pc, ring + ring[:1], 0.017, 5 if hi else 4, "ROPE", cap0=False, cap1=False)
    tube(pc, curve_pts([knot + V((0, -0.06, -0.02)), knot + V((0.02, -0.16, -0.06)), knot + V((0.05, -0.24, -0.16))], 6 if hi else 3),
         lambda t: 0.016 * (1 - 0.4 * t), 5 if hi else 4, "ROPE")

    # the eye slit: one ember band in a raised bronze lip, in the front panel between the upper bands
    zs, za = (1.522, 1.588), 0.34
    m = 16 if hi else 6
    slab(pc, [[bell_pt(lerp(-za, za, k / m), z, 0.004) for k in range(m + 1)] for z in zs], 0.012, "EMBER")
    lip = [bell_pt(lerp(-za, za, k / m), zs[1] + 0.012, 0.008) for k in range(m + 1)] + \
          [bell_pt(lerp(za, -za, k / m), zs[0] - 0.012, 0.008) for k in range(m + 1)]
    tube(pc, lip + lip[:1], 0.012, 5 if hi else 4, "BELL", cap0=False, cap1=False)
    # the crack: crown to rim down his front right, ember leaking out, one branch
    rnd = random.Random(11)
    nz = 22 if hi else 9
    crack = [(0.22 + 0.06 * k / nz + (0.045 if k % 2 else -0.035) * (0.4 + rnd.random()), lerp(1.97, 0.985, k / nz)) for k in range(nz + 1)]
    tube(pc, [bell_pt(a, z, 0.003) for a, z in crack], lambda t: 0.011 * (0.6 + 0.6 * G((t - 0.55) ** 2, 0.12)), 4, "EMBER")
    br = crack[nz // 2]
    tube(pc, [bell_pt(br[0] + d, br[1] - 0.10 * k, 0.003) for k, d in enumerate((0.0, -0.08, -0.12, -0.2))], 0.007, 4, "EMBER")
    # the failed seal pasted across the crack in the lower zone, torn at one end
    sm = 8 if hi else 3
    seal = [[bell_pt(0.27 + lerp(-0.13, 0.13, j / sm) + 0.06 * (i - 0.5), lerp(1.30, 1.13, i) + 0.10 * (j / sm - 0.5), 0.006)
             for j in range(sm + 1)] for i in (0.0, 0.5, 1.0)]
    slab(pc, seal, 0.006, "PAPER")
    slab(pc, [[seal[i][j] + bell_n(0.27) * 0.004 for j in range(1, sm)] for i in (1,)] +
         [[seal[1][j] + bell_n(0.27) * 0.004 + V((0, 0, -0.018)) for j in range(1, sm)]], 0.004, "LACE")

    # the chain, wound once round the bell on a tilt: low at his left, high at his right; and a dangling tail
    links = 44 if hi else 30
    path = [bell_pt(a, 1.47 + 0.27 * math.sin(a), 0.032) for a in [2 * math.pi * k / links for k in range(links)]]
    tail = [bell_pt(1.62, 1.72 - 0.12 * k, 0.04 + 0.02 * k) for k in range(7)]
    tail += [bell_pt(1.62, 0.98, 0.17) + V((0, 0.01 * k, -0.10 * k)) for k in range(1, 5)]

    def chain(pts, closed):
        for k in range(len(pts) - (0 if closed else 1)):
            p, q = pts[k], pts[(k + 1) % len(pts)]
            c, t = (p + q) / 2, (q - p).normalized()
            side = t.cross(V((0, 0, 1)))
            side = side.normalized() if side.length > 1e-4 else V((1, 0, 0))
            nrm = t.cross(side).normalized()
            u = side if k % 2 else nrm   # alternate links turn a quarter
            L = (q - p).length * 0.62 + 0.02
            m_ = 10 if hi else 6
            ring = [c + t * (math.cos(2 * math.pi * j / m_) * L) + u * (math.sin(2 * math.pi * j / m_) * 0.036) for j in range(m_)]
            tube(pc, ring + ring[:1], 0.011 if hi else 0.013, 5 if hi else 4, "IRON", cap0=False, cap1=False)

    chain(path, True)
    chain(tail, False)

    # paper talismans tied under the lip, hanging over the chest, each with a crimson ink stroke
    rnd = random.Random(29)
    for a, ln in ((-0.70, 0.60), (0.50, 0.34), (0.86, 0.50)):
        rows = 7 if hi else 3
        P = []
        tw = rnd.uniform(-0.12, 0.12)
        for i in range(rows + 1):
            f = i / rows
            z = lerp(1.06, 1.06 - ln - 0.06, f) + (rnd.uniform(-0.03, 0.03) if i == rows else 0.0)
            r = bell_r(max(z, 0.975)) + 0.012 + (0.035 * (0.975 - z) / 0.4 if z < 0.975 else 0.0) + 0.015 * math.sin(4 * f)
            row = []
            for g in (-1, 0, 1):
                aa = a + tw * f + g * 0.085 / max(0.3, r)
                row.append(BELL_C + V((math.sin(aa) * r, math.cos(aa) * r, z)))
            P.append(row)
        slab(pc, P, 0.006, "PAPER")
        ink = [[p + (p - BELL_C - V((0, 0, p.z - BELL_C.z))).normalized() * 0.005 + V((0, 0, 0)) for p in (row[0].lerp(row[1], 0.75), row[1].lerp(row[2], 0.25))]
               for row in P[1:-1]]
        slab(pc, ink, 0.004, "LACE")
        tube(pc, [bell_pt(a, 1.12, 0.012), bell_pt(a, 1.07, 0.02)], 0.009, 4, "CORD")
    # inside the hollow: a shroud-wound neck rising into the dark, so the overhang never shows daylight
    tube(pc, curve_pts([V((0, 0.14, 0.86)), V((0, 0.16, 1.12)), V((0, 0.15, 1.40))], 6 if hi else 3),
         lambda t: (0.22 - 0.03 * t, 0.21 - 0.03 * t), 14 if hi else 8, "SHROUD")
    return pc


# ---------------------------------------------------------------------------------------------------------
def lapel(pc, hi, a0, z0, a1, z1, off, mat):
    """A collar band of the robe running diagonally across the chest."""
    n = 22 if hi else 7
    P = [[], []]
    for k in range(n + 1):
        t = k / n
        a, z = lerp(a0, a1, t), lerp(z0, z1, t) - 0.06 * math.sin(math.pi * t)
        for r, da in enumerate((0.0, 0.30)):
            P[r].append(robe_pt(a + da, z, off))
    slab(pc, P, 0.024, mat)


def upper_torso(hi):
    pc = Piece(NAME + "_UpperTorso", "UpperTorso")
    nz, na = (32, 72) if hi else (11, 26)
    rows = []
    for i in range(nz + 1):
        z = lerp(-0.5, 1.06, i / nz)
        rows.append([torso_pt(a, z, robe_off(a, z, hi)) for a in [-math.pi + 2 * math.pi * k / na for k in range(na)]])
    pc.grid(rows, "ROBE_GRAVE", closed_u=True, cap0=True, cap1=True)
    # collar closed left over right, as the dead are dressed: the under-lapel first, the over-lapel on top
    lapel(pc, hi, -0.80, 1.02, 0.62, -0.46, 0.022, "ROBE")
    lapel(pc, hi, 0.50, 1.02, -0.98, -0.46, 0.046, "ROBE")
    # huge iron prayer beads hanging in a U from under the bell over the chest, two cracked to ember
    nb = 15
    for k in range(nb):
        u = k / (nb - 1)
        a, z = lerp(-0.86, 0.86, u), 0.95 - 0.78 * math.sin(math.pi * u)
        p = robe_pt(a, z, 0.06) + zb.surf_normal(lambda aa, zz: robe_pt(aa, zz, 0.06), a, z, centre) * 0.072
        sphere(pc, p, 0.074, "BEAD_CRACK" if k in (4, 10) else "BEAD", hi, 14 if hi else 7)
    cord = [robe_pt(lerp(-0.86, 0.86, u), 0.95 - 0.78 * math.sin(math.pi * u), 0.10) for u in [k / 24 for k in range(25)]]
    tube(pc, cord, 0.01, 4, "CORD")
    # a heavy grave-iron pendant at the bottom of the loop
    g = robe_pt(0.0, 0.10, 0.16)
    lathe(pc, [(0.0, 0.07), (0.06, 0.06), (0.085, 0.0), (0.06, -0.08), (0.0, -0.11)], 12 if hi else 6, "IRON",
          tr(g + V((0, 0.02, -0.10))) @ rot("X", -8), sy=0.5)
    shroud(pc, hi)
    return pc


def shroud(pc, hi):
    """A torn burial shroud worn under the bell, falling over the hump in strips: it ties the bell to the body from
    behind and the side, and breaks up the robe's back."""
    def at(x, z):   # x in [-0.62, 0.62] spans the back from -45 to +45 degrees round the hump
        return robe_pt(math.pi - x * 1.25, z, 0.05 + 0.03 * (1.02 - z) + 0.015 * math.sin(x * 15 + z * 4))

    # torn into strips of different lengths, a little apart, each narrowing as it falls
    for k, (x0, x1, z1) in enumerate(((-0.62, -0.30, 0.30), (-0.26, 0.04, -0.05), (0.08, 0.34, 0.18), (0.38, 0.62, 0.45))):
        n = 4 if hi else 2
        xs = [lerp(x0, x1, j / n) for j in range(n + 1)]
        zs = [lerp(1.02, z1, i / (14 if hi else 5)) for i in range((14 if hi else 5) + 1)]
        mid = (x0 + x1) / 2
        nar = lambda x, z, z1=z1, mid=mid: mid + (x - mid) * (1 - 0.35 * smooth((1.02 - z) / (1.02 - z1)))
        zb.panel(pc, xs, zs, lambda x, z, nar=nar: at(nar(x, z), z).y, "SHROUD", 0.02, fray=0.2, seed=13 + k,
                 xfun=lambda x, z, nar=nar: at(nar(x, z), z).x)


def lower_torso(hi):
    pc = Piece(NAME + "_LowerTorso", "LowerTorso")
    na, nz = (60, 14) if hi else (22, 5)
    angs = [-math.pi + 2 * math.pi * k / na for k in range(na)]
    rows = [[torso_pt(a, lerp(-1.05, -0.28, i / nz), 0.02) for a in angs] for i in range(nz + 1)]
    pc.grid(rows, "ROBE_GRAVE", closed_u=True, cap0=True, cap1=True)
    # bell-shaped first tier of the skirt, flaring from the belt
    random.seed(3)
    hem = [-1.24 + (random.random() - 0.5) * (0.08 if hi else 0.05) for _ in range(na)]
    tiers = 9 if hi else 4
    P = []
    for i in range(tiers + 1):
        f = i / tiers
        row = []
        for k, a in enumerate(angs):
            z = lerp(-0.40, hem[k], f)
            out = 0.06 + 0.30 * f ** 1.4 + 0.03 * math.sin(11 * a + 2.0) * f * (1 if hi else 0.6)
            row.append(torso_pt(a, max(z, -1.05), out) + V((0, 0, z - max(z, -1.05))))
        P.append(row + row[:1])
    slab(pc, P, 0.022, "ROBE_GRAVE")
    # rope belt: two thick turns, the knot at his front right, tails hanging
    for z, r in ((-0.39, 0.034), (-0.47, 0.03)):
        ring = [torso_pt(a, z, 0.10 + 0.006 * math.sin(k * 1.7)) for k, a in enumerate(angs)]
        tube(pc, ring + ring[:1], r, 6 if hi else 4, "ROPE", cap0=False, cap1=False)
    kn = torso_pt(0.42, -0.43, 0.15)
    sphere(pc, kn, 0.065, "ROPE", hi)
    for dx, ln in ((-0.03, 0.62), (0.04, 0.48)):
        tube(pc, curve_pts([kn, kn + V((dx, 0.05, -0.18)), kn + V((dx * 2, 0.08, -ln))], 8 if hi else 4),
             lambda t: 0.026 * (1 - 0.3 * t), 6 if hi else 4, "ROPE")
    # spirit tablets of the graves he keeps, hung from the belt on cords
    for a, ln in ((-0.95, 0.44), (-0.62, 0.36), (0.78, 0.38), (1.08, 0.46), (2.7, 0.40)):
        top = torso_pt(a, -0.52, 0.17)
        c = top + V((0, 0, -0.04 - ln / 2))
        nrm = V((math.sin(a), math.cos(a), 0.0))
        M = rot("Z", -math.degrees(a)) @ rot("X", -6)
        box(pc, c, (0.15, 0.04, ln), "WOOD_RED", M, bevel=0.008 if hi else 0.0)
        lathe(pc, [(0.0, 0.0), (0.075, 0.0), (0.06, 0.04), (0.0, 0.055)], 10 if hi else 5, "WOOD_RED",
              tr(c + V((0, 0, ln / 2))) @ rot("Z", -math.degrees(a)), sy=0.28)
        box(pc, c + nrm * 0.022, (0.085, 0.006, ln * 0.7), "PAPER", M)
        tube(pc, [torso_pt(a, -0.45, 0.13), top + V((0, 0, -0.02))], 0.009, 4, "CORD")
    # front apron hanging from the belt between the leg skirts
    n = 8 if hi else 4
    xs = [lerp(-0.34, 0.34, k / n) for k in range(n + 1)]
    zs = [lerp(-0.50, -2.0, k / (18 if hi else 6)) for k in range((18 if hi else 6) + 1)]
    yf = lambda x, z: interp(TORSO, max(z, -1.05))[1] * (1 - 0.5 * smooth((-0.7 - z) / 0.4)) + 0.14 + 0.16 * smooth((-0.6 - z) / 0.7) \
        + 0.025 * math.sin(x * 14 + 1.0) * smooth((-0.8 - z) / 0.6) - 0.08 * (x / 0.34) ** 2
    zb.panel(pc, xs, zs, yf, "ROBE_DARK", 0.022, fray=0.1, seed=9)
    # rear skirt panels, split so the legs can stride
    for s in (-1, 1):
        n = 14 if hi else 5
        xs = [s * lerp(0.04, 0.66, k / n) for k in range(n + 1)]
        zs = [lerp(-0.70, -2.12, k / (24 if hi else 8)) for k in range((24 if hi else 8) + 1)]

        def yb(x, z):
            f = smooth((-0.7 - z) / 0.9)
            fold = 0.05 * math.sin(abs(x) * 11.0 + 0.8) * smooth((-0.9 - z) / 1.2)
            return -0.60 * max(0.0, 1 - (abs(x) / 0.85) ** 2.4) ** (1 / 2.4) * (1 - f) + (-0.70 + 0.2 * (abs(x) / 0.66) ** 2) * f + fold

        zb.panel(pc, xs, zs, yb, "ROBE_GRAVE", 0.022, fray=0.12, seed=21 + s, xfun=lambda x, z: x * (1 + 0.12 * smooth((-0.8 - z) / 1.2)))
    return pc


# ---------------------------------------------------------------------------------------------------------
def upper_leg(hi, s):
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}UpperLeg", side + "UpperLeg")
    X = s * HIP_X
    tube(pc, [V((X, 0.0, -0.80)), V((X + s * 0.02, 0.01, -1.35)), V((X, 0.02, -1.98))],
         lambda t: (0.32 - 0.07 * t + 0.02 * math.sin(math.pi * t), 0.31 - 0.07 * t), 24 if hi else 12, "ROBE_DARK")
    # skirts wrapped round the front and outside of the thigh: the near-black under-robe, longer, then the grave robe
    for mat, z1, r0, a0, a1, seed in (("ROBE_DARK", -2.20, 0.37, -0.25, 2.65, 41), ("ROBE_GRAVE", -1.92, 0.42, -0.4, 2.35, 31)):
        na_, nzz = (16, 22) if hi else (7, 8)
        random.seed(seed + s)
        P = []
        for i in range(nzz + 1):
            f = i / nzz
            z = lerp(-0.62, z1, f)
            row = []
            for j in range(na_ + 1):
                a = lerp(a0, a1, j / na_)
                r = r0 + 0.14 * smooth(f / 0.8) + 0.026 * math.sin(7 * a + 3 * f) * smooth(f / 0.35)
                zz = z + ((random.random() - 0.4) * 0.10 if i == nzz else 0.0)
                row.append(V((X + s * math.sin(a) * r, 0.02 + math.cos(a) * r, zz)))
            P.append(row)
        slab(pc, P, 0.022, mat)
    return pc


def lower_leg(hi, s):
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}LowerLeg", side + "LowerLeg")
    X = s * HIP_X
    nz, na = (22, 28) if hi else (6, 10)
    rows = []
    for i in range(nz + 1):
        t = i / nz
        z = lerp(-1.66, -2.62, t)
        calf = G((t - 0.3) ** 2, 0.18)
        rx = 0.20 + 0.05 * calf - 0.025 * t
        rows.append(sring(V((X, 0.01, z)), V((1, 0, 0)), V((0, 1, 0)), rx, 0.20 + 0.02 * calf, na, 2.2, -math.pi / 2,
                          0.20 + 0.08 * calf))
    pc.grid(rows, "ROBE_DARK", closed_u=True, cap0=True, cap1=True)

    def r_at(f):
        t = lerp(0.25, 0.98, f)
        return 0.20 + 0.05 * G((t - 0.3) ** 2, 0.18) - 0.025 * t + 0.04
    bands(pc, V((X, 0.03, -1.92)), V((X, 0.01, -2.60)), r_at, None, 8 if hi else 4, "LINEN", hi, tilt=0.2, out=0.0)
    # an iron shin plate strapped over the wraps
    def gsurf(a, z):
        t = (-1.95 - z) / 0.62
        r = r_at(min(1, max(0, t))) + 0.03
        return V((X + math.sin(a) * r, 0.02 + math.cos(a) * r, z))
    nu, nv = (12, 8) if hi else (5, 3)
    slab(pc, [[gsurf(lerp(-1.1, 1.1, j / nu), lerp(-1.97, -2.52, i / nv)) for j in range(nu + 1)] for i in range(nv + 1)], 0.024, "IRON")
    zb.rivets(pc, [(gsurf(a, z), V((math.sin(a), math.cos(a), 0))) for z in (-2.03, -2.46) for a in (-0.8, 0.8)], 0.014, hi)
    return pc


def foot(hi, s):
    """Iron-shod boot: a heavy leather boot with a cuffed shaft, an iron toe cap, instep straps and a thick iron sole."""
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}Foot", side + "Foot")
    X = s * HIP_X
    n = 24 if hi else 8
    rows = []
    for i in range(n + 1):
        t = i / n
        y = lerp(-0.24, 0.42, t)
        top = SOLE_Z + lerp(0.40, 0.17, smooth((t - 0.12) / 0.7))
        bot = SOLE_Z + 0.07
        w = 0.19 * (1 + 0.12 * smooth((t - 0.5) / 0.4)) * (1 - 0.45 * smooth((t - 0.92) / 0.08)) + 0.01
        rows.append(sring(V((X + s * 0.012 * t, y, (top + bot) / 2)), V((1, 0, 0)), V((0, 0, 1)), w, (top - bot) / 2, 18 if hi else 8, 2.6))
    pc.grid(rows, "LEATHER", closed_u=True, cap0=True, cap1=True)
    # boot shaft and its turned-down cuff
    lathe(pc, [(0.21, SOLE_Z + 0.22), (0.22, SOLE_Z + 0.36), (0.225, -2.56), (0.25, -2.53), (0.255, -2.47), (0.22, -2.47)],
          20 if hi else 8, "LEATHER", tr(V((X, -0.02, 0))), sy=1.05)
    # iron toe cap
    toe = V((X + s * 0.012, 0.30, SOLE_Z + 0.10))
    lathe(pc, [(0.0, 0.14), (0.11, 0.13), (0.18, 0.065), (0.2, 0.0)], 16 if hi else 8, "IRON", tr(toe) @ rot("X", -90),
          sx=1.05, sy=0.62, arc=math.pi, a0=0.0)
    # thick iron sole plate, a little wider than the boot
    S = []
    m = 12 if hi else 5
    for k in range(m + 1):
        t = k / m
        y = lerp(-0.27, 0.47, t)
        w = 0.215 * (1 + 0.08 * smooth((t - 0.5) / 0.4)) * (1 - 0.35 * smooth((t - 0.85) / 0.15)) + 0.01
        S.append([V((X - w, y, SOLE_Z + 0.035)), V((X + w, y, SOLE_Z + 0.035))])
    slab(pc, [[r[0] for r in S], [r[1] for r in S]], 0.07, "IRON")
    # two iron straps over the instep
    for y in (0.02, 0.15):
        top = SOLE_Z + lerp(0.40, 0.17, smooth(((y + 0.24) / 0.66 - 0.12) / 0.7)) + 0.012
        ring = [V((X + math.cos(a) * 0.21, y, SOLE_Z + 0.07 + math.sin(a) * (top - SOLE_Z - 0.07))) for a in
                [math.pi * k / 10 for k in range(11)]]
        tube(pc, ring, (0.018, 0.012), 4, "IRON", up=V((0, 1, 0)))
    return pc


# ---------------------------------------------------------------------------------------------------------
def upper_arm(hi, s):
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}UpperArm", side + "UpperArm")
    a0, a1 = sx(ARM_TOP, s), sx(ARM_ELBOW, s)
    path = curve_pts([a0.lerp(a1, 0.1), a0.lerp(a1, 0.5) + V((s * 0.02, 0.01, 0)), a1 - V((0, 0, 0.05))], 14 if hi else 5)
    tube(pc, path, lambda t: 0.20 + 0.03 * math.sin(math.pi * min(1, t * 1.3)) - 0.03 * t, 22 if hi else 12, "SKIN")
    # the robe's heavy shoulder, gathered over the joint (hides where the rigid arm meets the hump)
    M = tr(V((s * 0.98, 0.05, 0.74))) @ rot("Y", s * 26)
    lathe(pc, [(0.0, 0.24), (0.14, 0.22), (0.25, 0.14), (0.29, 0.03), (0.28, -0.10), (0.22, -0.24), (0.0, -0.30)],
          24 if hi else 10, "ROBE_GRAVE", M, sy=1.12)
    # wide sleeve, rolled up above the elbow and bound with a cord
    n = 28 if hi else 12
    random.seed(17 + s)
    hem = [0.18 + 0.04 * math.sin(3 * (2 * math.pi * k / n)) + (random.random() - 0.5) * (0.06 if hi else 0.03) for k in range(n)]
    ax = (a1 - a0).normalized()
    rows_o, rows_i = [], []
    nr = 8 if hi else 3
    for i in range(nr + 1):
        f = i / nr
        row_o, row_i = [], []
        for k in range(n):
            t = 2 * math.pi * k / n
            zt = lerp(0.66, hem[k], f)
            c = a0 + ax * ((a0.z - zt) / max(1e-3, -ax.z))
            r = 0.26 + 0.08 * f ** 1.5 + 0.018 * math.sin(5 * t + 2 * f) * (1 if hi else 0.4) + 0.03 * G((f - 1) ** 2, 0.03)
            d = V((math.cos(t), math.sin(t) * 1.08, 0))
            row_o.append(c + d * r)
            row_i.append(c + d * (r - 0.022))
        rows_o.append(row_o)
        rows_i.append(row_i)
    pc.grid(rows_o, "ROBE_GRAVE", closed_u=True)
    pc.grid(rows_i, "ROBE_GRAVE", closed_u=True, flip=True)
    pc.grid([rows_o[-1], rows_i[-1]], "ROBE_GRAVE", closed_u=True)
    c = a0 + ax * ((a0.z - 0.42) / max(1e-3, -ax.z))
    ring = [c + V((math.cos(t) * 0.30, math.sin(t) * 0.32, 0.02 * math.sin(t))) for t in [2 * math.pi * k / 18 for k in range(18)]]
    tube(pc, ring + ring[:1], 0.02, 5 if hi else 4, "CORD", cap0=False, cap1=False)
    return pc


def lower_arm(hi, s):
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}LowerArm", side + "LowerArm")
    e, w = sx(ARM_ELBOW, s), sx(ARM_WRIST, s)
    tube(pc, curve_pts([e + V((0, 0, 0.08)), e.lerp(w, 0.32) + V((s * 0.01, 0.015, 0)), w], 12 if hi else 4),
         lambda t: 0.19 - 0.05 * t + 0.035 * G((t - 0.25) ** 2, 0.03), 22 if hi else 12, "SKIN")

    def bsurf(a, z, r0=0.18):
        t = (e.z - z) / (e.z - w.z)
        c = e + (w - e) * t
        r = r0 - 0.04 * t + 0.03 * smooth((t - 0.82) / 0.18)
        return c + V((s * math.cos(a) * r, math.sin(a) * r * 1.05, 0))

    # a closed iron bracer from mid-forearm to the wrist, bound with rope
    nu, nv = (24, 10) if hi else (10, 3)
    P = [[bsurf(2 * math.pi * j / nu, lerp(-0.26, -0.64, i / nv), 0.185) for j in range(nu + 1)] for i in range(nv + 1)]
    slab(pc, P, 0.026, "IRON")
    for z in (-0.30, -0.58):
        ring = [bsurf(2 * math.pi * k / 18, z, 0.205) for k in range(18)]
        tube(pc, ring + ring[:1], 0.018, 5 if hi else 4, "ROPE", cap0=False, cap1=False)
    zb.rivets(pc, [(bsurf(a, -0.44, 0.205), V((s * math.cos(a), math.sin(a), 0))) for a in (-1.2, -0.4, 0.4, 1.2)], 0.015, hi)
    return pc


def hand(hi, s):
    """A heavy ash-skin fist, knuckles bound in linen; the fingers wrap the grip line through FIST along +Y (the shaft)."""
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}Hand", side + "Hand")
    F = sx(FIST, s)
    R = 0.088
    X, Y = V((s, 0, 0)), V((0, 1, 0))
    nz, na = (10, 20) if hi else (3, 8)
    rows = []
    for i in range(nz + 1):
        t = i / nz
        z = lerp(-0.66, F.z + 0.015, t)
        cx = F.x + s * (0.085 + 0.014 * math.sin(math.pi * t))
        rows.append(sring(V((cx, 0.01, z)), X, Y, 0.062 + 0.01 * t, 0.128 + 0.026 * t, na, 3.0))
    pc.grid(rows, "SKIN", closed_u=True, cap0=True, cap1=True)
    bands(pc, V((F.x + s * 0.085, 0.01, -0.70)), V((F.x + s * 0.085, 0.01, -0.80)), 0.08, 0.09, 2, "LINEN", hi, tilt=0.1,
          out=0.012, seg=16 if hi else 8)
    n0 = len(pc.bm.verts)
    for f, (ly, L) in enumerate(zip((0.122, 0.042, -0.038, -0.114), (1.0, 1.07, 1.0, 0.82))):
        n = 22 if hi else 7
        pts = []
        for k in range(n):
            t = k / (n - 1)
            ang = math.radians(12 - 250 * L * t)
            pts.append(V((F.x + s * math.cos(ang) * R, ly - 0.012 * t * (f - 1.5), F.z + math.sin(ang) * R)))
        knuckles = lambda t: 0.007 * (G((t - 0.02) ** 2, 0.03) + G((t - 0.38) ** 2, 0.03) + G((t - 0.7) ** 2, 0.03))
        tube(pc, pts, lambda t, L=L, kn=knuckles: (0.042 * (1 - 0.2 * t) + kn(t)) * (0.94 if L < 0.9 else 1.0), 12 if hi else 6, "SKIN",
             up=V((0, 1, 0)))
    P = []   # linen across the knuckles
    for ang in (14, -8, -32):
        a_ = math.radians(ang)
        P.append([V((F.x + s * math.cos(a_) * (R + 0.05), y, F.z + math.sin(a_) * (R + 0.05))) for y in (-0.16, -0.08, 0.0, 0.08, 0.165)])
    slab(pc, P, 0.014, "LINEN")
    th = [V((F.x + s * 0.075, 0.145, -0.72)), V((F.x + s * 0.035, 0.20, F.z + 0.07)), V((F.x - s * 0.035, 0.195, F.z + 0.025)),
          V((F.x - s * 0.085, 0.16, F.z - 0.035))]
    tube(pc, curve_pts(th, 16 if hi else 6), lambda t: 0.045 * (1 - 0.25 * t) + 0.005 * G((t - 0.5) ** 2, 0.02), 12 if hi else 6, "SKIN")
    tilt_grip(pc, n0, F)
    return pc


def tilt_grip(pc, n0, F):
    pc.bm.verts.ensure_lookup_table()
    pc.transform(pc.bm.verts[n0:], tr(F) @ rot("X", GRIP_TILT) @ tr(-F))


# ---------------------------------------------------------------------------------------------------------
def spade(hi):
    """Crescent-moon spade on the grip line through the right fist (+Y = his front at rest): a dark shaft with leather
    grips for both hands and iron rings, the crescent blade (horns forward, sharp on its concave edge) in the
    vertical plane with two loose iron rings on its back, and a flat burial spade on the butt."""
    pc = Piece(NAME + "_Spade", "RightHand", role="Weapon")
    F = sx(FIST, 1)
    gx, gz = F.x, F.z
    Y0, Y1 = -2.42, 2.38
    tube(pc, [V((gx, y, gz)) for y in (Y0, 0.0, Y1)], SHAFT_R, 12 if hi else 8, "POLE")
    for y0, y1 in ((-0.24, 0.24), (SHAFT_LEFT - 0.3, SHAFT_LEFT + 0.3), (-SHAFT_LEFT - 0.3, -SHAFT_LEFT + 0.3)):
        tube(pc, [V((gx, y, gz)) for y in (y0, (y0 + y1) / 2, y1)], SHAFT_R + 0.008, 12 if hi else 8, "LEATHER")
    for y in (-1.25, 0.55, 1.85):
        tube(pc, [V((gx, y - 0.025, gz)), V((gx, y + 0.025, gz))], SHAFT_R + 0.012, 12 if hi else 8, "IRON")
    # sockets
    sock = [(0.0, -0.30), (SHAFT_R + 0.008, -0.30), (SHAFT_R + 0.012, -0.12), (0.066, -0.04), (0.078, 0.0), (0.06, 0.03), (0.0, 0.03)]
    lathe(pc, sock, 14 if hi else 8, "IRON", tr(V((gx, Y1, gz))) @ rot("X", -90))
    lathe(pc, sock, 14 if hi else 8, "IRON", tr(V((gx, Y0, gz))) @ rot("X", 90))

    # crescent: outer arc about C, sharp concave edge facing forward, horns at +-112 deg from the back
    Ro, thm = 0.58, math.radians(112)
    C = V((gx, Y1 + Ro - 0.01, gz))
    n = 30 if hi else 12
    rows = []
    for i in range(n + 1):
        th = lerp(-thm, thm, i / n)
        u = th / thm
        d = V((0.0, -math.cos(th), math.sin(th)))
        w = 0.27 * max(0.0, 1 - u * u) ** 0.7 + 0.006
        t = 0.04 * (1 - 0.6 * u * u) + 0.006
        Ri = Ro - w
        Xv = V((1, 0, 0))
        pi_, po = C + d * Ri, C + d * Ro
        rows.append([pi_, pi_ + d * (w * 0.35) + Xv * (t * 0.42), po - d * 0.012 + Xv * (t * 0.5), po,
                     po - d * 0.012 - Xv * (t * 0.5), pi_ + d * (w * 0.35) - Xv * (t * 0.42)])
    pc.grid(rows, "STEEL", closed_u=True, cap0=True, cap1=True)
    # two loose iron rings on lugs at the crescent's back (they ring when he walks)
    for sg in (-1, 1):
        th = sg * 0.5
        lug = C + V((0.0, -math.cos(th), math.sin(th))) * (Ro + 0.015)
        tube(pc, [lug + V((-0.025, 0, 0)), lug + V((0.025, 0, 0))], 0.022, 6 if hi else 4, "IRON")
        rc = lug + V((0.0, -0.035 * math.cos(th), 0.035 * math.sin(th))) + V((0, 0, -0.07))
        m = 14 if hi else 8
        ring = [rc + V((0.0, math.cos(2 * math.pi * k / m) * 0.075, math.sin(2 * math.pi * k / m) * 0.075)) for k in range(m)]
        tube(pc, ring + ring[:1], 0.012, 5 if hi else 4, "IRON", cap0=False, cap1=False)

    # burial spade on the butt: flat (width along X), a shallow scoop, a slightly rounded cutting edge
    nr, nc = (10, 10) if hi else (4, 4)
    P = []
    for i in range(nr + 1):
        f = i / nr
        hw = lerp(0.13, 0.25, smooth(f / 0.5) ** 0.8)
        row = []
        for j in range(nc + 1):
            g = -1 + 2 * j / nc
            y = Y0 - 0.06 - (0.52 + 0.06 * (1 - g * g)) * f
            row.append(V((gx + g * hw, y, gz + 0.035 * g * g * smooth(f / 0.3))))
        P.append(row)
    slab(pc, P, lambda i, j: 0.04 * (1 - i / nr) + 0.01, "STEEL")
    tilt_grip(pc, 0, F)
    return pc


def build(hi):
    out = [head(hi), upper_torso(hi), lower_torso(hi), spade(hi)]
    for s in (1, -1):
        out += [upper_arm(hi, s), lower_arm(hi, s), hand(hi, s), upper_leg(hi, s), lower_leg(hi, s), foot(hi, s)]
    return out
