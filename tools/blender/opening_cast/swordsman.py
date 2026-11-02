"""Cursed Swordsman: a dead pagoda guard still keeping his post, one constructed Piece per R15 limb plus his dao.

Upright where the monk hunches, armoured where the monk is ragged: a ribbed iron helmet with a crimson plume and a
brim that throws the face into shadow, two ember eyes, a snarling iron jaw guard and a lamellar neck guard (no face to
read as uncanny), a torn crimson silk scarf, flaring iron pauldrons over black lamellar laced in crimson, a bronze heart-mirror on the chest, a
lamellar skirt over a near-black robe, splinted greaves and boots. The ring-pommel dao is its own piece bound to the
right hand (AsuraRole=Weapon), its grip closed inside the gauntlet; its empty lacquered scabbard rides the left hip.
build(hi): hi=True is the master, hi=False the game mesh built from the same landmarks.

Arms share the monk's inboard landmarks (castlib solves the clips for the visible fist), so the rigid fist and the
blade stay on the forearm's hinge line through every cut.
"""
import math
import random

import body as zb
from lib import V, Piece, curve_pts, gauss, lathe, rot, slab, sring, tr, tube
from monk import ARM_ELBOW, ARM_TOP, ARM_WRIST, FIST, bands, sphere, sx

G = gauss
lerp, smooth, interp = zb.lerp, zb.smooth, zb.interp
NAME = "Swordsman"
HIP_X, SOLE_Z = 0.42, -3.0
# the dao's grip lies diagonally across the right palm (as a real sword grip does), not square to the forearm: the
# curled fingers and the whole dao are turned this far about X through the fist centre, point forward and down
GRIP_TILT = -65.0
Hc = V((0.0, 0.03, 1.49))

# robe body under the armour: z, half-width, front depth, back depth, centre y, superellipse power (upright, deep chest)
TORSO = [
    (-1.05, 0.50, 0.30, 0.33, 0.0, 2.3),
    (-0.85, 0.53, 0.32, 0.35, 0.0, 2.3),
    (-0.60, 0.49, 0.30, 0.32, 0.0, 2.3),
    (-0.40, 0.45, 0.28, 0.29, 0.0, 2.3),
    (-0.15, 0.50, 0.30, 0.29, 0.0, 2.4),
    (0.15, 0.56, 0.33, 0.31, 0.0, 2.5),
    (0.45, 0.63, 0.35, 0.32, 0.0, 2.6),
    (0.62, 0.68, 0.31, 0.30, 0.0, 2.7),
    (0.74, 0.66, 0.27, 0.29, 0.0, 2.6),
    (0.85, 0.53, 0.24, 0.27, -0.01, 2.4),
    (0.95, 0.33, 0.20, 0.23, -0.02, 2.2),
    (1.04, 0.19, 0.16, 0.18, -0.02, 2.0),
]


def torso_pt(theta, z, off=0.0):
    rx, ryf, ryb, cy, p = interp(TORSO, z)
    s, c = math.sin(theta), math.cos(theta)
    x = math.copysign(abs(s) ** (2 / p), s) * (rx + off)
    y = cy + math.copysign(abs(c) ** (2 / p), c) * ((ryf if c >= 0 else ryb) + off)
    return V((x, y, z))


def centre(z):
    return V((0, interp(TORSO, z)[3], z))


# ---------------------------------------------------------------------------------------------------------
SKULL = [(0.0, -0.40), (0.11, -0.385), (0.18, -0.31), (0.215, -0.17), (0.235, -0.02), (0.235, 0.12), (0.21, 0.26),
         (0.15, 0.36), (0.07, 0.415), (0.0, 0.43)]
SKULL_SY = 1.14


def skull_r(z):
    return interp([(z_, r) for r, z_ in SKULL], z)[0]


def mask_disp(x, z):
    """The demon mask's relief over the skull (Hc-relative x, z): a scowling brow, deep sockets, a flat broad nose,
    a snarling mouth slot and a jutting chin."""
    ax = abs(x)
    bz = 0.075 - 0.12 * max(0.0, 0.07 - ax)                                       # inner brow driven down: the scowl
    d = 0.050 * G((z - bz) ** 2, 0.03) * G(x * x, 0.11) * smooth((0.20 - ax) / 0.05)
    d += 0.022 * G(x * x, 0.03) * G((z - 0.06) ** 2, 0.0346)                    # the knot between the brows
    d -= 0.045 * G((ax - 0.085) ** 2, 0.0332) * G((z - 0.005) ** 2, 0.03)       # sockets
    if -0.17 < z < 0.07:                                                          # broad flat nose
        t = smooth((0.06 - z) / 0.2)
        d += (0.02 + 0.045 * t) * G(x * x, 0.025 + 0.015 * t)
    d += 0.035 * G((ax - 0.045) ** 2, 0.0224) * G((z + 0.14) ** 2, 0.0245)        # flared nostrils
    d += 0.028 * G((ax - 0.15) ** 2, 0.0387) * G((z + 0.05) ** 2, 0.0447)          # cheek plates
    d += 0.030 * G(x * x, 0.0775) * G((z + 0.20) ** 2, 0.0245)                     # snarling upper lip
    d -= 0.040 * G(x * x, 0.0894) * G((z + 0.245 + 0.4 * x * x) ** 2, 0.0158)    # mouth slot, corners down
    for fx in (-0.06, 0.06):                                                      # fangs over the slot
        d += 0.016 * G((x - fx) ** 2, 0.01) * G((z + 0.24) ** 2, 0.02)
    d += 0.040 * G(x * x, 0.0707) * G((z + 0.33) ** 2, 0.0346)                     # chin
    return d


def mask_pt(a, z, out=0.0):
    r = skull_r(z)
    x, y = math.sin(a) * r, math.cos(a) * r * SKULL_SY
    d = V((math.sin(a), math.cos(a) * SKULL_SY, 0)).normalized()
    return Hc + V((x, y, z)) + d * (0.026 + out + mask_disp(x, z) * smooth(math.cos(a) / 0.35))


def head(hi):
    pc = Piece(NAME + "_Head", "Head")
    # neck wound in black cloth, rising out of the scarf; a black hood under the helmet: the face is only shadow
    tube(pc, [V((0, -0.01, 1.0)), V((0, 0.0, 1.16)), Hc + V((0, -0.02, -0.28))], 0.13, 16 if hi else 8, "ROBE_DARK")
    lathe(pc, SKULL, 36 if hi else 14, "SHROUD", tr(Hc), sy=SKULL_SY)
    # two ember eyes burning in the gap between the helmet brim and the jaw guard, slanted up at the outer corners
    for s in (-1, 1):
        x, z = s * 0.09, 0.0
        a = math.asin(max(-1.0, min(1.0, x / skull_r(z))))
        p = Hc + V((math.sin(a) * skull_r(z), math.cos(a) * skull_r(z) * SKULL_SY, z)) + V((0, 0.006, 0))
        M = tr(p) @ rot("Z", -math.degrees(a) * 1.3) @ rot("Y", -s * 16) @ rot("X", -90)
        lathe(pc, [(0.0, -0.016), (0.04, -0.012), (0.058, 0.0), (0.04, 0.012), (0.0, 0.016)], 16 if hi else 8, "EMBER", M, sy=0.4)
    # the jaw guard: an iron half-mask from under the eyes to under the chin, a snarl with fangs, a bronze rim
    na, nz = (36, 26) if hi else (12, 8)
    A0 = 1.2
    rows = [[mask_pt(lerp(-A0, A0, k / na), lerp(-0.42, -0.065 - 0.05 * (lerp(-1, 1, k / na)) ** 2, i / nz)) for k in range(na + 1)]
            for i in range(nz + 1)]
    slab(pc, rows, 0.022, "IRON", offset=0.004)
    rim = [rows[i][0] for i in range(nz + 1)] + rows[-1][1:] + [rows[i][-1] for i in range(nz, -1, -1)]
    tube(pc, curve_pts(rim, 40 if hi else 16), 0.011, 5 if hi else 3, "BRONZE", cap0=False, cap1=False)
    for fx, ln in ((-0.075, 0.06), (-0.03, 0.035), (0.03, 0.035), (0.075, 0.06)):   # fangs over the mouth slot
        r = mask_pt(math.asin(fx / skull_r(-0.22)), -0.215, 0.006)
        tube(pc, [r + V((0, -0.01, 0.01)), r + V((0, 0.012, -ln * 0.5)), r + V((0, 0.008, -ln))], lambda t: 0.014 * (1 - 0.85 * t),
             6 if hi else 4, "BRONZE", cap1=True)
    # ribbed iron helmet bowl (doumou) with a forward brim that throws the eyes into shadow
    HM = tr(Hc + V((0, -0.01, 0)))
    outer = [(0.0, 0.48), (0.08, 0.465), (0.16, 0.42), (0.225, 0.34), (0.27, 0.24), (0.29, 0.13), (0.295, 0.05)]
    inner = [(r - 0.024, z) for r, z in outer[1:]][::-1] + [(0.0, 0.455)]
    lathe(pc, outer + inner, 40 if hi else 16, "IRON", HM, sy=SKULL_SY * 0.97)
    lathe(pc, [(0.298, 0.035), (0.318, 0.05), (0.31, 0.075), (0.294, 0.07)], 40 if hi else 16, "BRONZE", HM, sy=SKULL_SY * 0.97)
    for k in range(8 if hi else 4):   # raised ribs between the bowl's plates
        t = 2 * math.pi * (k + 0.5) / (8 if hi else 4)
        rib = [HM @ V((math.sin(t) * (r + 0.008), math.cos(t) * (r + 0.008) * SKULL_SY * 0.97, z)) for r, z in outer[1:]]
        tube(pc, rib, 0.014, 5 if hi else 3, "BRONZE", cap0=False, cap1=False)
    nb, nr = (28, 4) if hi else (10, 2)
    brim = [[HM @ V((math.sin(a) * lerp(0.29, 0.43 - 0.07 * abs(a), f), math.cos(a) * lerp(0.29, 0.43 - 0.07 * abs(a), f) * SKULL_SY * 0.97,
                     0.06 - 0.035 * f)) for a in [lerp(-1.25, 1.25, j / nb) for j in range(nb + 1)]] for f in [i / nr for i in range(nr + 1)]]
    slab(pc, brim, 0.018, "IRON")
    tube(pc, brim[-1], 0.009, 5 if hi else 3, "BRONZE")
    # lamellar neck guard hanging from the bowl round the sides and back
    nsurf = lambda a, z: Hc + V((math.sin(a) * (0.30 + 0.24 * (0.04 - z)), math.cos(a) * (0.30 + 0.24 * (0.04 - z)) * SKULL_SY, z))
    zb.lamellar(pc, nsurf, lambda z: Hc + V((0, 0, z)), [(0.05 - 0.14 * k, 0.17, 1.15, 2 * math.pi - 1.15, 16, 0.004 * k) for k in range(3)],
                hi, plate_mat="IRON", lo_group=2, thick=0.018, tilt=0.03, lace="LACE")
    # bronze finial and a crimson horsehair plume spilling down the back of the bowl
    top = HM @ V((0, 0, 0.47))
    lathe(pc, [(0.0, 0.0), (0.05, 0.0), (0.04, 0.06), (0.022, 0.09), (0.03, 0.12), (0.0, 0.20)], 12 if hi else 6, "BRONZE", tr(top))
    rnd = random.Random(29)
    for k in range(26 if hi else 5):
        a = 2 * math.pi * k / (26 if hi else 5)
        spread = 0.06 if hi else 0.05
        p0 = top + V((0, 0, 0.13))
        p1 = top + V((math.sin(a) * spread, math.cos(a) * spread - 0.08, 0.10))
        p2 = top + V((math.sin(a) * spread * 1.6, math.cos(a) * spread - 0.30 - rnd.uniform(0, 0.06), -0.05 - rnd.uniform(0, 0.08)))
        tube(pc, curve_pts([p0, p1, p2], 8 if hi else 4), lambda t: (0.016 if hi else 0.045) * (1 - 0.6 * t), 5 if hi else 4, "SCARF",
             cap0=False)
    return pc


# ---------------------------------------------------------------------------------------------------------
def upper_torso(hi):
    pc = Piece(NAME + "_UpperTorso", "UpperTorso")
    nz, na = (24, 56) if hi else (8, 20)
    rows = [[torso_pt(-math.pi + 2 * math.pi * k / na, lerp(-0.5, 1.05, i / nz)) for k in range(na)] for i in range(nz + 1)]
    pc.grid(rows, "ROBE_DARK", closed_u=True, cap0=True, cap1=True)
    # black lamellar laced in crimson, from under the arms to the waist
    surf = lambda a, z: torso_pt(a, z, 0.035)
    rows_l = [(0.62 - 0.13 * k, 0.17, -math.pi, math.pi, 40, 0.0 + 0.004 * k) for k in range(9)]
    zb.lamellar(pc, surf, centre, rows_l, hi, plate_mat="IRON", lo_group=2, thick=0.018, tilt=0.03, lace="LACE")
    # iron chest and back plates over the top of the lamellar, joined by straps over the shoulders
    for front in (True, False):
        a0, a1 = (-1.15, 1.15) if front else (math.pi - 1.2, math.pi + 1.2)
        nu, nv = (24, 8) if hi else (8, 3)
        P = [[torso_pt(lerp(a0, a1, j / nu), lerp(0.56, 0.92 - 0.06 * abs(lerp(-1, 1, j / nu)) ** 2, i / nv), 0.05) for j in range(nu + 1)]
             for i in range(nv + 1)]
        slab(pc, P, 0.024, "IRON")
    for s in (-1, 1):
        strap = [torso_pt(s * a, lerp(0.88, 0.94, math.sin(math.pi * (a - 0.7) / 1.8)), 0.075) for a in [lerp(0.7, 2.5, k / 10) for k in range(11)]]
        tube(pc, strap, lambda t: (0.05, 0.014), 6 if hi else 4, "LEATHER", up=V((0, 0, 1)))
    # bronze heart-mirror (huxinjing) on the chest, tied by crimson cords
    mc = torso_pt(0, 0.34, 0.075)
    M = tr(mc) @ rot("X", -90)
    lathe(pc, [(0.0, 0.03), (0.08, 0.026), (0.135, 0.016), (0.155, 0.0), (0.15, -0.012), (0.0, -0.012)], 32 if hi else 12, "BRONZE", M)
    lathe(pc, [(0.05, 0.034), (0.06, 0.04), (0.07, 0.034)], 24 if hi else 10, "BRONZE", M)
    for s in (-1, 1):
        tube(pc, curve_pts([mc + V((s * 0.14, 0.0, 0.05)), torso_pt(s * 0.9, 0.55, 0.08), torso_pt(s * 1.3, 0.75, 0.075)], 8 if hi else 4),
             0.012, 5 if hi else 3, "LACE")
    scarf(pc, hi)
    return pc


def scarf(pc, hi):
    """Torn crimson silk wound round the neck; two tails stream down the back, one longer and shredded."""
    na = 40 if hi else 14
    for z, r, w in ((1.0, 0.255, 0.075), (0.93, 0.29, 0.07)):
        ring = [V((math.sin(t) * r, -0.01 + math.cos(t) * r * 0.95, z + 0.02 * math.sin(2 * t + z * 9))) for t in
                [2 * math.pi * k / na for k in range(na)]]
        tube(pc, ring + ring[:1], lambda t, w=w: (w, 0.045), 8 if hi else 5, "SCARF", cap0=False, cap1=False, up=V((0, 0, 1)))
    knot = V((-0.17, -0.24, 0.94))
    sphere(pc, knot, 0.075, "SCARF", hi)
    for dx, ln, w, seed in ((-0.06, 1.55, 0.12, 3), (0.06, 1.05, 0.10, 7)):
        rnd = random.Random(seed)
        pts = [knot + V((dx * 0.5, -0.02, -0.04))]
        for k in range(1, 7):
            f = k / 6
            pts.append(knot + V((dx + 0.05 * math.sin(3 * f + seed), -0.10 - 0.18 * f - 0.05 * math.sin(4 * f), -ln * f)))
        tube(pc, curve_pts(pts, 16 if hi else 6), lambda t, w=w: (w * (1 - 0.25 * t), 0.012), 6 if hi else 4, "SCARF", up=V((0, 1, 0)),
             twist=0.6)
        if hi:   # shredded ends
            end = pts[-1]
            for _ in range(5):
                d = V((rnd.uniform(-0.05, 0.05), rnd.uniform(-0.03, 0.01), -rnd.uniform(0.08, 0.2)))
                tube(pc, [end + V((rnd.uniform(-w, w) * 0.6, 0, 0.02)), end + d], lambda t: (0.02 * (1 - 0.7 * t), 0.006), 4, "SCARF",
                     up=V((0, 1, 0)))


def lower_torso(hi):
    pc = Piece(NAME + "_LowerTorso", "LowerTorso")
    na, nz = (56, 12) if hi else (18, 4)
    rows = [[torso_pt(-math.pi + 2 * math.pi * k / na, lerp(-1.05, -0.28, i / nz), 0.02) for k in range(na)] for i in range(nz + 1)]
    pc.grid(rows, "ROBE_DARK", closed_u=True, cap0=True, cap1=True)
    # wide leather belt over a crimson sash, a bronze plaque at the buckle
    for z0, z1, off, mat in ((-0.36, -0.58, 0.075, "SCARF"), (-0.40, -0.53, 0.10, "LEATHER")):
        nu = 48 if hi else 16
        P = [[torso_pt(-math.pi + 2 * math.pi * k / nu, z, off) for k in range(nu + 1)] for z in (z0, (z0 + z1) / 2, z1)]
        slab(pc, P, 0.02, mat)
    M = tr(torso_pt(0, -0.465, 0.13)) @ rot("X", -90)
    lathe(pc, [(0.0, 0.025), (0.09, 0.02), (0.12, 0.0), (0.0, 0.0)], 4, "BRONZE", M, a0=math.pi / 4, sx=1.25, sy=0.9)
    # lamellar skirt hanging behind and at the hips (the thighs carry their own tassets so the legs can stride)
    def skirt(a, z):
        f = smooth((-0.55 - z) / 1.0)
        return torso_pt(a, max(z, -1.0), 0.10 + 0.16 * f)

    rows_s = [(-0.56 - 0.20 * k, 0.24, 1.55, 2 * math.pi - 1.55, 22, 0.0 + 0.004 * k) for k in range(5)]
    zb.lamellar(pc, skirt, centre, rows_s, hi, plate_mat="IRON", lo_group=2, thick=0.018, tilt=0.03, lace="LACE")
    # crimson front apron between the tassets
    n = 8 if hi else 4
    xs = [lerp(-0.22, 0.22, k / n) for k in range(n + 1)]
    zs = [lerp(-0.55, -1.55, k / (14 if hi else 5)) for k in range((14 if hi else 5) + 1)]
    yf = lambda x, z: interp(TORSO, max(z, -1.05))[1] + 0.13 + 0.05 * smooth((-0.7 - z) / 0.6) - 0.06 * (x / 0.22) ** 2 \
        + 0.015 * math.sin(x * 18) * smooth((-0.8 - z) / 0.5)
    zb.panel(pc, xs, zs, yf, "SCARF", 0.02, fray=0.1, seed=12)
    scabbard(pc, hi)
    return pc


def scabbard(pc, hi):
    """Empty black-lacquered scabbard slung edge-up at the left hip, angled down and back, bronze-mounted."""
    p0 = torso_pt(-1.2, -0.50, 0.16) + V((0, 0.05, 0))
    d = V((-0.06, -0.80, -0.60)).normalized()
    L = 3.0
    path = curve_pts([p0, p0 + d * (L * 0.5) + V((0, 0, 0.05)), p0 + d * L + V((0, 0, 0.14))], 16 if hi else 6)
    tube(pc, path, lambda t: (0.035, 0.12 + 0.03 * math.sin(math.pi * min(1.0, t * 1.2)) - 0.06 * smooth((t - 0.85) / 0.15)),
         10 if hi else 6, "LACQUER", up=V((0, 0, 1)), cap0=True, cap1=True)
    for t in (0.0, 0.18, 0.55, 0.97):   # throat, two hanging mounts, chape
        i = min(len(path) - 1, int(t * (len(path) - 1)))
        seg = [path[i] - d * 0.05, path[i] + d * (0.09 if t < 0.9 else 0.06)]
        tube(pc, seg, lambda _: (0.045, 0.15 if t < 0.9 else 0.11), 10 if hi else 6, "BRONZE", up=V((0, 0, 1)))
    for t in (0.18, 0.55):   # straps up to the belt
        i = int(t * (len(path) - 1))
        tube(pc, curve_pts([path[i] + V((0, 0, 0.12)), torso_pt(-1.35 - 0.4 * t, -0.47, 0.13)], 6 if hi else 3), lambda _: (0.03, 0.01),
             4, "LEATHER", up=V((1, 0, 0)))


# ---------------------------------------------------------------------------------------------------------
def thigh_surf(s, X):
    def surf(a, z):
        r = 0.34 + 0.08 * smooth((-0.65 - z) / 0.9)
        return V((X + s * math.sin(a) * r, 0.03 + math.cos(a) * r, z))
    return surf


def upper_leg(hi, s):
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}UpperLeg", side + "UpperLeg")
    X = s * HIP_X
    tube(pc, [V((X, 0.0, -0.80)), V((X + s * 0.02, 0.01, -1.35)), V((X, 0.02, -1.98))],
         lambda t: (0.30 - 0.06 * t + 0.02 * math.sin(math.pi * t), 0.29 - 0.06 * t), 24 if hi else 12, "ROBE_DARK")
    # lamellar tasset over the front and outside of the thigh
    surf = thigh_surf(s, X)
    rows = [(-0.62 - 0.19 * k, 0.23, -0.55, 2.2, 13, 0.0 + 0.004 * k) for k in range(5)]
    zb.lamellar(pc, surf, lambda z: V((X, 0.03, z)), rows, hi, plate_mat="IRON", lo_group=2, thick=0.018, tilt=0.03, lace="LACE")
    return pc


def lower_leg(hi, s):
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}LowerLeg", side + "LowerLeg")
    X = s * HIP_X
    nz, na = (20, 26) if hi else (6, 10)
    rows = []
    for i in range(nz + 1):
        t = i / nz
        calf = G((t - 0.3) ** 2, 0.18)
        rows.append(sring(V((X, 0.01, lerp(-1.66, -2.74, t))), V((1, 0, 0)), V((0, 1, 0)), 0.15 + 0.05 * calf - 0.02 * t,
                          0.15 + 0.02 * calf, na, 2.2, -math.pi / 2, 0.15 + 0.08 * calf))
    pc.grid(rows, "ROBE_DARK", closed_u=True, cap0=True, cap1=True)
    bands(pc, V((X, 0.02, -1.92)), V((X, 0.01, -2.62)), lambda f: 0.15 + 0.05 * G((lerp(0.24, 0.9, f) - 0.3) ** 2, 0.18)
          - 0.02 * lerp(0.24, 0.9, f) + 0.012, None, 7 if hi else 3, "LEATHER", hi, tilt=0.18, out=0.0)
    # splinted iron greave on the shin, bound with two leather straps
    gsurf = lambda a, z: V((X + math.sin(a) * 0.19, 0.03 + math.cos(a) * (0.20 + 0.03 * (z + 2.0)), z))
    for k in range(5):
        a = -1.05 + 2.1 * (k + 0.5) / 5
        P = []
        for z in ([lerp(-1.94, -2.64, f) for f in (0, 0.25, 0.5, 0.75, 1)] if hi else (-1.94, -2.64)):
            P.append([gsurf(a + g * 0.2, z) + V((math.sin(a + g * 0.2), math.cos(a + g * 0.2), 0)) * (0.03 + 0.006 * (k % 2))
                      for g in (-1, 0, 1)])
        slab(pc, P, 0.022, "IRON")
    for z in (-2.0, -2.56):
        band = [gsurf(-1.2 + 2.4 * k / 12, z) + V((math.sin(-1.2 + 2.4 * k / 12), math.cos(-1.2 + 2.4 * k / 12), 0)) * 0.055
                for k in range(13)]
        tube(pc, band, 0.016, 6 if hi else 4, "LEATHER")
    kc = V((X, 0.20, -1.84))   # knee cop
    lathe(pc, [(0.0, 0.10), (0.07, 0.085), (0.12, 0.05), (0.15, 0.0), (0.155, -0.02), (0.13, -0.01)], 22 if hi else 10, "IRON",
          tr(kc) @ rot("X", -90), sy=1.2)
    return pc


def foot(hi, s):
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}Foot", side + "Foot")
    X = s * HIP_X
    n = 24 if hi else 9
    rows = []
    for i in range(n + 1):
        t = i / n
        y = lerp(-0.22, 0.44, t)
        top = SOLE_Z + lerp(0.36, 0.13, smooth((t - 0.2) / 0.7)) + 0.06 * smooth((t - 0.88) / 0.12)
        bot = SOLE_Z + 0.05 + 0.05 * smooth((t - 0.86) / 0.14)
        w = 0.15 * (1 - 0.25 * smooth((t - 0.7) / 0.3)) * (1 - 0.65 * smooth((t - 0.93) / 0.07)) + 0.01
        rows.append(sring(V((X, y, (top + bot) / 2)), V((1, 0, 0)), V((0, 0, 1)), w, (top - bot) / 2, 18 if hi else 8, 2.8))
    pc.grid(rows, "LEATHER", closed_u=True, cap0=True, cap1=True)
    S = []
    for k in range(12 if hi else 6):
        t = k / (11 if hi else 5)
        y = lerp(-0.24, 0.42, t)
        w = 0.16 * (1 - 0.3 * smooth((t - 0.7) / 0.3)) + 0.005
        zz = SOLE_Z + 0.03 + 0.05 * smooth((t - 0.86) / 0.14)
        S.append([V((X - w, y, zz)), V((X + w, y, zz))])
    slab(pc, [[r[0] for r in S], [r[1] for r in S]], 0.06, "LEATHER")
    lathe(pc, [(0.17, -2.80), (0.18, -2.70), (0.175, -2.62), (0.16, -2.60)], 20 if hi else 8, "LEATHER", tr((X, -0.02, 0)), sy=1.1)
    return pc


# ---------------------------------------------------------------------------------------------------------
def upper_arm(hi, s):
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}UpperArm", side + "UpperArm")
    a0, a1 = sx(ARM_TOP, s), sx(ARM_ELBOW, s)
    path = curve_pts([a0.lerp(a1, 0.1), a0.lerp(a1, 0.5) + V((s * 0.015, 0.01, 0)), a1 - V((0, 0, 0.05))], 14 if hi else 5)
    tube(pc, path, lambda t: 0.175 + 0.02 * math.sin(math.pi * t) - 0.03 * t, 22 if hi else 12, "ROBE_DARK")
    # pauldron: four flaring iron lames on the outside of the arm under a domed cap (the broad guard's silhouette)
    ax = (a1 - a0).normalized()
    out, fwd = V((s, 0, 0)), V((0, 1, 0))
    pcen = lambda z: a0 + ax * ((a0.z - z) / max(1e-3, -ax.z))

    def psurf(a, z):
        r = 0.27 + 0.22 * (0.80 - z)
        return pcen(z) + out * (math.cos(a) * r) + fwd * (math.sin(a) * r * 1.08)

    rows = [(0.80 - 0.12 * k, 0.18, -1.9, 1.9, 15, 0.0 + 0.02 * k) for k in range(4)]
    zb.lamellar(pc, psurf, pcen, rows, hi, plate_mat="IRON", lo_group=2, thick=0.02, tilt=0.04, lace="LACE")
    M = tr(V((s * 0.86, 0.0, 0.76))) @ rot("Y", s * 30)
    outer = [(0.0, 0.24), (0.12, 0.23), (0.22, 0.18), (0.30, 0.10), (0.34, 0.02), (0.355, -0.05)]
    inner = [(r - 0.03, z - 0.012) for r, z in outer[1:]][::-1] + [(0.0, 0.21)]
    lathe(pc, outer + inner, 28 if hi else 10, "IRON", M, sy=1.12)
    lathe(pc, [(0.357, -0.065), (0.375, -0.045), (0.36, -0.025), (0.34, -0.04)], 28 if hi else 10, "BRONZE", M, sy=1.12)
    if hi:
        rv = []
        for k in range(9):
            a = -1.5 + 3.0 * k / 8 + (math.pi if s < 0 else 0)
            rv.append((M @ V((math.cos(a) * 0.33, math.sin(a) * 0.33 * 1.12, 0.03)),
                       (M.to_3x3() @ V((math.cos(a), math.sin(a), 0.3))).normalized()))
        zb.rivets(pc, rv, 0.013, hi)
    return pc


def lower_arm(hi, s):
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}LowerArm", side + "LowerArm")
    e, w = sx(ARM_ELBOW, s), sx(ARM_WRIST, s)
    tube(pc, curve_pts([e + V((0, 0, 0.07)), e.lerp(w, 0.35) + V((0, 0.01, 0)), w], 12 if hi else 4),
         lambda t: 0.16 - 0.04 * t + 0.025 * G((t - 0.25) ** 2, 0.03), 22 if hi else 12, "ROBE_DARK")

    def bsurf(a, z, r0=0.17):
        t = (e.z - z) / (e.z - w.z)
        c = e + (w - e) * t
        r = r0 - 0.035 * t + 0.03 * smooth((t - 0.8) / 0.2)
        return c + V((s * math.cos(a) * r, math.sin(a) * r * 1.05, 0))

    for aa, ab, mat, off in ((-1.9, 1.9, "IRON", 0.0), (1.9, 2 * math.pi - 1.9, "LEATHER", -0.008)):
        nu, nv = (16, 12) if hi else (6, 3)
        P = [[bsurf(lerp(aa, ab, j / nu), lerp(-0.10, -0.64, i / nv), 0.17 + off) for j in range(nu + 1)] for i in range(nv + 1)]
        slab(pc, P, 0.024, mat)
    for z in (-0.20, -0.54):
        ring = [bsurf(2 * math.pi * k / 16, z, 0.195) for k in range(16)]
        tube(pc, ring + ring[:1], 0.016, 5 if hi else 4, "LEATHER", cap0=False, cap1=False)
    zb.rivets(pc, [(bsurf(a, z, 0.195), V((s * math.cos(a), math.sin(a), 0))) for z in (-0.20, -0.54) for a in (-1.0, 0.0, 1.0)], 0.013, hi)
    lathe(pc, [(0.0, 0.07), (0.07, 0.055), (0.11, 0.02), (0.115, 0.0)], 18 if hi else 8, "IRON",
          tr(e + V((s * 0.02, -0.15, 0.0))) @ rot("X", 90), sy=1.25)
    return pc


def hand(hi, s):
    """Leather gauntlet closed in a fist; the fingers wrap the grip line through FIST along +Y (the dao's axis)."""
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}Hand", side + "Hand")
    F = sx(FIST, s)
    R = 0.064
    X, Y = V((s, 0, 0)), V((0, 1, 0))
    nz, na = (10, 20) if hi else (3, 8)
    rows = []
    for i in range(nz + 1):
        t = i / nz
        z = lerp(-0.68, F.z + 0.01, t)
        rows.append(sring(V((F.x + s * (0.07 + 0.012 * math.sin(math.pi * t)), 0.01, z)), X, Y, 0.054 + 0.008 * t, 0.106 + 0.022 * t,
                          na, 3.0))
    pc.grid(rows, "LEATHER", closed_u=True, cap0=True, cap1=True)
    # flared gauntlet cuff over the wrist
    lathe(pc, [(0.15, -0.60), (0.17, -0.66), (0.135, -0.74), (0.12, -0.74)], 20 if hi else 8, "LEATHER",
          tr(V((F.x + s * 0.05, 0.01, 0.0))), sx=0.85, sy=1.1)
    n0 = len(pc.bm.verts)
    for f, (ly, L) in enumerate(zip((0.100, 0.034, -0.032, -0.094), (1.0, 1.07, 1.0, 0.82))):
        n = 20 if hi else 7
        pts = [V((F.x + s * math.cos(math.radians(12 - 250 * L * k / (n - 1))) * R, ly - 0.01 * k / (n - 1) * (f - 1.5),
                  F.z + math.sin(math.radians(12 - 250 * L * k / (n - 1))) * R)) for k in range(n)]
        tube(pc, pts, lambda t, L=L: (0.036 * (1 - 0.18 * t)) * (0.94 if L < 0.9 else 1.0), 12 if hi else 6, "LEATHER", up=V((0, 1, 0)))
    P = []   # iron knuckle plate over the back of the fingers
    for ang in (14, -8, -30):
        a_ = math.radians(ang)
        P.append([V((F.x + s * math.cos(a_) * (R + 0.045), y, F.z + math.sin(a_) * (R + 0.045))) for y in (-0.13, -0.065, 0.0, 0.065, 0.135)])
    slab(pc, P, 0.014, "IRON")
    th = [V((F.x + s * 0.06, 0.12, -0.74)), V((F.x + s * 0.03, 0.165, F.z + 0.06)), V((F.x - s * 0.03, 0.16, F.z + 0.02)),
          V((F.x - s * 0.07, 0.13, F.z - 0.03))]
    tube(pc, curve_pts(th, 14 if hi else 6), lambda t: 0.038 * (1 - 0.2 * t), 12 if hi else 6, "LEATHER")
    if s > 0:
        tilt_grip(pc, n0, F)
    return pc


def tilt_grip(pc, n0, F):
    pc.bm.verts.ensure_lookup_table()
    pc.transform(pc.bm.verts[n0:], tr(F) @ rot("X", GRIP_TILT) @ tr(-F))


def dao(hi):
    """Ring-pommel dao on the grip line through the right fist (+Y = his front at rest, spine +Z, edge -Z): cord-wrapped
    grip, oval bronze guard, a willow-leaf blade swelling toward a clipped tip and curving up along the spine."""
    pc = Piece(NAME + "_Dao", "RightHand", role="Weapon")
    F = sx(FIST, 1)
    gx, gz = F.x, F.z
    # grip and its ferrules
    tube(pc, [V((gx, y, gz)) for y in (-0.21, -0.02, 0.17)], lambda t: (0.034, 0.042), 10 if hi else 6, "LACE", p=2.2)
    for y in (-0.22, 0.165):
        tube(pc, [V((gx, y - 0.02, gz)), V((gx, y + 0.02, gz))], lambda t: (0.04, 0.05), 10 if hi else 6, "BRONZE")
    # ring pommel in the plane of the blade, tucked against the heel of the fist (the diagonal grip carries it toward
    # the wrist, so it stays small and bare)
    rc = V((gx, -0.27, gz))
    ring = [rc + V((0, math.cos(t) * 0.055, math.sin(t) * 0.05)) for t in [2 * math.pi * k / (24 if hi else 10) for k in range(24 if hi else 10)]]
    tube(pc, ring + ring[:1], 0.014, 6 if hi else 4, "IRON", cap0=False, cap1=False)
    # guard
    lathe(pc, [(0.0, -0.016), (0.10, -0.016), (0.12, 0.0), (0.10, 0.016), (0.0, 0.016)], 24 if hi else 10, "BRONZE",
          tr(V((gx, 0.20, gz))) @ rot("X", -90), sx=0.62, sy=1.0)
    # blade: closed sections from guard to tip
    n = 28 if hi else 9
    L = 2.95
    rows = []
    for i in range(n + 1):
        t = i / n
        y = 0.22 + L * t
        lift = 0.11 * t ** 2
        spine = gz + 0.035 + lift - 0.05 * smooth((t - 0.9) / 0.1)
        depth = (0.15 + 0.07 * smooth((t - 0.25) / 0.55)) * (1 - smooth((t - 0.84) / 0.16)) ** 0.6 + 0.004
        th = 0.034 * (1 - 0.5 * t) + 0.004
        edge = spine - depth
        rows.append([V((gx, y, edge)), V((gx + th * 0.42, y, edge + depth * 0.35)), V((gx + th * 0.5, y, spine - 0.012)),
                     V((gx, y, spine)), V((gx - th * 0.5, y, spine - 0.012)), V((gx - th * 0.42, y, edge + depth * 0.35))])
    pc.grid(rows, "STEEL", closed_u=True, cap0=True, cap1=True)
    tilt_grip(pc, 0, F)
    return pc


def build(hi):
    out = [head(hi), upper_torso(hi), lower_torso(hi), dao(hi)]
    for s in (1, -1):
        out += [upper_arm(hi, s), lower_arm(hi, s), hand(hi, s), upper_leg(hi, s), lower_leg(hi, s), foot(hi, s)]
    return out
