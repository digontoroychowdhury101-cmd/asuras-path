"""Corrupt Wandering Monk: a fallen temple brawler, one constructed Piece per R15 limb.

Lean and wiry, bald with ordination burns, ember-touched eyes under a heavy brow and a broken nose. A
rust-patched kasaya crosses from the left shoulder to under the right arm, leaving the right shoulder and
chest bare; a burnt tail of it hangs down the back, a ragged sleeve caps the left arm. Heavy prayer beads
(three cracked to ember) ride on the chest, linen wraps bind the forearms, knuckles and shins, a rope sash
holds a cracked alms bowl, and he walks on straw sandals. build(hi): hi=True is the master, hi=False the
game mesh built from the same landmarks.
"""
import math
import random

import body as zb
import heads
from lib import V, Piece, curve_pts, gauss, lathe, rot, slab, sring, tr, tube

G = gauss
lerp, smooth, interp = zb.lerp, zb.smooth, zb.interp
NAME = "Monk"
# arms hang a little inside the R15 shoulder joints (x 0.97) so the torso can stay lean
ARM_TOP, ARM_ELBOW, ARM_WRIST = V((0.90, 0, 0.86)), V((0.97, 0.0, 0.03)), V((1.02, 0.0, -0.70))
FIST = V((1.04, 0.0, -0.89))
HIP_X, KNEE_Z, ANKLE_Z, SOLE_Z = 0.42, -1.84, -2.73, -3.0

# bare wiry torso: z, half-width, front depth, back depth, centre y, superellipse power
TORSO = [
    (-1.05, 0.47, 0.28, 0.32, 0.0, 2.2),
    (-0.85, 0.54, 0.32, 0.36, 0.0, 2.3),
    (-0.62, 0.50, 0.30, 0.33, 0.0, 2.2),
    (-0.40, 0.42, 0.26, 0.27, 0.0, 2.2),
    (-0.15, 0.46, 0.28, 0.28, 0.0, 2.2),
    (0.15, 0.52, 0.31, 0.30, 0.0, 2.3),
    (0.45, 0.63, 0.34, 0.32, 0.0, 2.4),
    (0.62, 0.73, 0.30, 0.30, 0.0, 2.6),
    (0.74, 0.72, 0.27, 0.29, 0.0, 2.6),
    (0.85, 0.58, 0.24, 0.27, -0.01, 2.4),
    (0.95, 0.36, 0.20, 0.23, -0.02, 2.2),
    (1.04, 0.21, 0.17, 0.19, -0.02, 2.0),
]


def torso_pt(theta, z, off=0.0):
    rx, ryf, ryb, cy, p = interp(TORSO, z)
    s, c = math.sin(theta), math.cos(theta)
    x = math.copysign(abs(s) ** (2 / p), s) * (rx + off)
    y = cy + math.copysign(abs(c) ** (2 / p), c) * ((ryf if c >= 0 else ryb) + off)
    return V((x, y, z))


def centre(z):
    return V((0, interp(TORSO, z)[3], z))


def muscle(a, z):
    """Outward offset of the bare torso: pectorals, sternum, abdominals, serratus, trapezius, lats."""
    aa = abs(a)
    back = abs(abs(a) - math.pi)
    d = 0.045 * G((aa - 0.5) ** 2, 0.12) * G((z - 0.47) ** 2, 0.016) * (1 - 0.6 * smooth((0.36 - z) / 0.08))
    d -= 0.012 * G(a * a, 0.05) * G((z - 0.38) ** 2, 0.08)
    for zk in (0.18, 0.02, -0.14):
        d += 0.012 * G((aa - 0.16) ** 2, 0.006) * G((z - zk) ** 2, 0.0028)
    for k in range(3):
        d += 0.007 * G((aa - 1.05) ** 2, 0.01) * G((z - (0.30 - 0.1 * k) - 0.2 * (aa - 1.05)) ** 2, 0.0015)
    d += 0.012 * G((aa - 0.7) ** 2, 0.06) * G((z - 0.86) ** 2, 0.002)                        # clavicles
    d += 0.032 * G((back - 0.0) ** 2, 0.5) * G((z - 0.88) ** 2, 0.012) * G((aa - 2.4) ** 2, 0.4)  # trapezius
    d += 0.028 * G((aa - 2.15) ** 2, 0.08) * G((z - 0.35) ** 2, 0.05)                         # lats
    d -= 0.010 * G(back ** 2, 0.02) * G((z - 0.3) ** 2, 0.15)                                 # spine groove
    d += 0.014 * G((back - 0.45) ** 2, 0.04) * G((z - 0.6) ** 2, 0.02)                        # shoulder blades
    return d


def kasaya_top(a):
    """Upper edge of the kasaya: over the left shoulder (a = -pi/2), under the right arm (a = +pi/2)."""
    return 0.62 - 0.40 * math.sin(a)


def bands(pc, c0, c1, r0, r1, count, mat, hi, tilt=0.16, out=0.012, rows=3, seg=None):
    """Hand-wound strips around an axis from c0 to c1: overlapping, tilted bands (reads as a spiral wrap)."""
    ax = (c1 - c0).normalized()
    u = ax.cross(V((0, 1, 0)))
    u = u.normalized() if u.length > 1e-6 else V((1, 0, 0))
    w = ax.cross(u).normalized()
    n = seg or (24 if hi else 10)
    h = (c1 - c0).length / count
    for k in range(count):
        f0 = (k + 0.5) / count
        c = c0.lerp(c1, f0)
        r = (r0(f0) if callable(r0) else lerp(r0, r1, f0)) + out
        R = []
        for i in range(rows):
            g = -0.5 + i / (rows - 1)
            bulge = (1 - 4 * g * g) * 0.006
            row = []
            for j in range(n):
                t = 2 * math.pi * j / n
                rad = u * math.cos(t) + w * math.sin(t)
                row.append(c + ax * (g * h * 1.25 + tilt * r * math.sin(t + 0.7 * k)) + rad * (r + bulge + 0.002 * (k % 2)))
            R.append(row)
        pc.grid(R, mat, closed_u=True)


def sphere(pc, c, r, mat, hi, n=None):
    prof = [(0.0, -r), (0.5 * r, -0.87 * r), (0.87 * r, -0.5 * r), (r, 0.0), (0.87 * r, 0.5 * r), (0.5 * r, 0.87 * r), (0.0, r)]
    if not hi:
        prof = [prof[0], prof[2], prof[3], prof[4], prof[6]]
    lathe(pc, prof, n or (12 if hi else 6), mat, tr(c))


def groom(pc, guide, width, thick, count, seed, hi, out=0.004, lo_n=4):
    """Hair mass along a guide (as Zhao's): dark core, plus individual tapered strands on the master."""
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
            pts.append(c + side * (u * width(t)) + nrm * ((1 - u * u) * thick(t) * 0.8 * lift + out))
        r0 = rnd.uniform(0.0022, 0.0040)
        tube(pc, curve_pts(pts, 9), lambda t, r0=r0: r0 * (1 - 0.85 * t) + 0.0006, 4, "HAIR", cap0=False, cap1=True)


# ---------------------------------------------------------------------------------------------------------
def head(hi):
    pc = Piece(NAME + "_Head", "Head")
    Hc = V((0.0, 0.03, 1.49))
    # chin to crown: z, half-width, front depth, back depth, centre y, superellipse power (a square brawler's jaw)
    profile = [
        (-0.42, 0.07, 0.06, 0.05, 0.19, 2.2), (-0.38, 0.13, 0.10, 0.12, 0.14, 2.4), (-0.31, 0.18, 0.16, 0.19, 0.08, 2.6),
        (-0.23, 0.205, 0.23, 0.23, 0.03, 2.6), (-0.14, 0.215, 0.255, 0.28, 0.0, 2.4), (-0.04, 0.235, 0.27, 0.315, 0.0, 2.2),
        (0.04, 0.245, 0.27, 0.335, 0.0, 2.1), (0.12, 0.25, 0.265, 0.345, 0.0, 2.05), (0.22, 0.25, 0.25, 0.34, -0.005, 2.0),
        (0.30, 0.23, 0.235, 0.30, -0.01, 2.0), (0.36, 0.185, 0.185, 0.235, -0.015, 2.0), (0.40, 0.115, 0.105, 0.14, -0.02, 2.0),
        (0.425, 0.03, 0.02, 0.035, -0.02, 2.0),
    ]

    # the features below are drawn in these design units; the sculpt shortens the lower third (nose to chin) and the
    # crown so the face does not read long and horse-like
    def squash(z):
        return -0.14 + (z + 0.14) * 0.79 if z < -0.14 else (0.22 + (z - 0.22) * 0.9 if z > 0.22 else z)

    def unsquash(z):
        return -0.14 + (z + 0.14) / 0.79 if z < -0.14 else (0.22 + (z - 0.22) / 0.9 if z > 0.22 else z)

    profile = [(squash(z), *row) for z, *row in profile]

    def scar(x, z):
        sx0, sz0, sx1, sz1 = 0.07, -0.20, 0.17, -0.34   # burn from the right mouth corner across the jaw (+X is his right)
        t = max(0, min(1, ((x - sx0) * (sx1 - sx0) + (z - sz0) * (sz1 - sz0)) / ((sx1 - sx0) ** 2 + (sz1 - sz0) ** 2)))
        return (x - (sx0 + t * (sx1 - sx0))) ** 2 + (z - (sz0 + t * (sz1 - sz0))) ** 2

    def disp(x, z):
        ax = abs(x)
        d = 0.034 * G((z - 0.075) ** 2, 0.022) * G(x * x, 0.11)                     # heavy brow ridge
        d += 0.012 * G(x * x, 0.02) * G((z - 0.068) ** 2, 0.02)                     # scowl knot between the brows
        d -= 0.008 * G((ax - 0.022) ** 2, 0.006) * G((z - 0.06) ** 2, 0.025)        # its furrows
        d -= 0.048 * G((ax - 0.088) ** 2, 0.042) * G((z - 0.012) ** 2, 0.032)       # sunken sockets
        nx = x - 0.011 * smooth(-z / 0.1)                                           # nose broken to his left
        if -0.16 < z < 0.075:
            t = smooth((0.06 - z) / 0.17)
            d += (0.018 + 0.058 * t ** 1.3) * G(nx * nx, 0.015 + 0.013 * t) * smooth((z + 0.14) / 0.025)
        d += 0.010 * G(nx * nx, 0.016) * G((z + 0.02) ** 2, 0.01)                   # the healed break on the bridge
        d += 0.016 * G(nx * nx, 0.022) * G((z + 0.1) ** 2, 0.018)                   # tip
        d += 0.024 * G(x * x, 0.075) * G((z + 0.2) ** 2, 0.06)                      # muzzle over the teeth
        d += 0.040 * G((abs(nx) - 0.034) ** 2, 0.014) * G((z + 0.118) ** 2, 0.016)  # alae
        d -= 0.012 * G(nx * nx, 0.03) * G((z + 0.142) ** 2, 0.008)
        d += 0.030 * G((ax - 0.15) ** 2, 0.035) * G((z + 0.025) ** 2, 0.03)         # hard cheekbones
        d -= 0.040 * G((ax - 0.14) ** 2, 0.035) * G((z + 0.175) ** 2, 0.045)        # starved cheeks
        d -= 0.018 * G((ax - (0.045 + 0.35 * max(0.0, -0.12 - z))) ** 2, 0.008) * G((z + 0.17) ** 2, 0.045)   # nasolabial folds
        d -= 0.005 * G(x * x, 0.008) * G((z + 0.16) ** 2, 0.012)                    # philtrum
        d += 0.022 * G(x * x, 0.045) * G((z + 0.178) ** 2, 0.011)                   # upper lip
        d -= 0.020 * G(x * x, 0.055) * G((z + 0.195 + 0.6 * x * x) ** 2, 0.0045)    # mouth, corners turned down
        d += 0.018 * G(x * x, 0.04) * G((z + 0.215) ** 2, 0.011)                    # lower lip
        d -= 0.012 * G(x * x, 0.05) * G((z + 0.245) ** 2, 0.012)
        d += 0.046 * G(x * x, 0.06) * G((z + 0.33) ** 2, 0.03)                      # a chin that holds its ground
        d += 0.012 * G((ax - 0.15) ** 2, 0.012) * G((z + 0.33) ** 2, 0.02)          # jaw corners
        d -= 0.014 * G((ax - 0.21) ** 2, 0.03) * G((z - 0.08) ** 2, 0.05)           # hollow temples
        d += 0.008 * G((ax - 0.09) ** 2, 0.03) * G((z + 0.03) ** 2, 0.01)           # bags under the eyes
        for k in range(3):
            d -= 0.0035 * G((ax - 0.165) ** 2, 0.012) * G((z - (0.012 - 0.022 * k) - 0.25 * (ax - 0.165)) ** 2, 0.0035)
            d -= 0.003 * G(x * x, 0.09) * G((z - (0.15 + 0.035 * k)) ** 2, 0.0025)  # forehead lines
        d -= 0.007 * G(scar(x, z), 0.008)
        return d

    def stubble(x, y, z):
        hairline = -0.2 + 0.39 * smooth((y + 0.1) / 0.32) - 0.03 * G((abs(x) - 0.2) ** 2, 0.03) * smooth(y / 0.15)
        scalp = smooth((z - hairline) / 0.025)
        beard = 0.6 * smooth((-0.2 - z) / 0.03) * smooth((y - 0.05) / 0.06) * (1 - G(x * x, 0.05) * G((z + 0.2) ** 2, 0.02))
        # brows painted as dense hair (weight > 1 saturates the stubble speckle): thick, low and angled down to the knot
        ax = abs(x)
        bz = 0.066 + 0.30 * (ax - 0.03) - 1.1 * (ax - 0.03) ** 2
        brow = 1.6 * smooth((ax - 0.022) / 0.012) * smooth((0.19 - ax) / 0.03) * G((z - bz) ** 2, 0.009 + 0.006 * smooth((0.1 - ax) / 0.07)) \
            * smooth(y / 0.12)
        return max(scalp, beard, brow) * (1 - smooth(1 - scar(x, z) / 0.0006))

    def soot(x, y, z):
        mouth = 0.6 * G(x * x, 0.05) * G((z + 0.195 + 0.6 * x * x) ** 2, 0.005) * smooth(y / 0.1)
        return min(1.0, G((abs(x) - 0.088) ** 2, 0.05) * G((z - 0.0) ** 2, 0.042) * smooth(y / 0.1) * 1.1
                   + 0.5 * G(scar(x, z), 0.012) * smooth(y / 0.05) + mouth)

    face_pt = heads.sculpt(pc, hi, Hc, profile, lambda x, z: disp(x, unsquash(z)),
                           lambda x, y, z: stubble(x, y, unsquash(z)), lambda x, y, z: soot(x, y, unsquash(z)),
                           eye=(0.088, 0.012, 0.039), lid=(13, -17), neck=(0.2, 0.95))
    def skull(a, z):
        """Sculpted surface (Hc-relative) at column angle a (0 = his front, +pi/2 = his right) and sculpt height z."""
        rx, ryf, ryb, cy, p = heads.interp(profile, z)
        s, c = math.sin(a), math.cos(a)
        x = math.copysign(abs(s) ** (2 / p), s) * rx
        y = cy + math.copysign(abs(c) ** (2 / p), c) * (ryf if c >= 0 else ryb)
        if c > 0:
            y += disp(x, unsquash(z)) * smooth(c / 0.45)
        return V((x, y, z))

    # face wrap: ash-dark cloth wound from under the eyes to the throat; it drapes off the nose and the chin, so the
    # face reads only as two ember eyes in the hat's shadow
    na_w, nz_w = (96, 30) if hi else (32, 9)

    def wrap_top(a):   # under the eyes in front, dipping under the ears at the sides and back
        return lerp(-0.05, -0.17, smooth((abs(a) - 0.9) / 0.6))

    def wrap_pt(a, z, out=0.0):
        q = skull(a, z)
        d = V((q.x, q.y, 0.0))
        d = d.normalized() if d.length > 1e-4 else V((math.sin(a), math.cos(a), 0.0))
        best = 0.235
        for m in range(13):   # cloth drapes off the nose and chin instead of following the face into every hollow
            zz = z + 0.02 * m
            if zz > wrap_top(a) + 1e-4:
                break
            qq = skull(a, zz)
            best = max(best, math.hypot(qq.x, qq.y) - 0.75 * (zz - z))
        r = best + 0.016 + out
        return Hc + V((d.x * r, d.y * r, z))

    angs = [-math.pi + 2 * math.pi * k / na_w for k in range(na_w)]
    rows = []
    for i in range(nz_w + 1):
        raw = [wrap_pt(a, lerp(-0.58, wrap_top(a), i / nz_w)) - Hc for a in angs]
        rad = [math.hypot(p.x, p.y) for p in raw]
        w = max(1, na_w // 16)   # wound cloth bridges the jaw corners: radii smoothed round the head
        row = []
        for k, (a, p) in enumerate(zip(angs, raw)):
            r = sum(rad[(k + m) % na_w] for m in range(-w, w + 1)) / (2 * w + 1)
            r = max(r, rad[k] - 0.01)
            ph = (p.z - 0.075 * math.sin(a)) / 0.085   # overlapping turns crossing the face on the diagonal
            r += 0.010 * (ph - math.floor(ph)) if hi else 0.0
            d = V((p.x, p.y, 0.0)).normalized()
            row.append(Hc + V((d.x * r, d.y * r, p.z)))
        rows.append(row)
    pc.grid(rows, "SHROUD", closed_u=True)
    tube(pc, rows[-1] + rows[-1][:1], 0.009, 5 if hi else 3, "SHROUD", cap0=False, cap1=False)
    tail = curve_pts([Hc + V((0.10, -0.26, -0.30)), Hc + V((0.17, -0.50, -0.55)), Hc + V((0.21, -0.60, -0.85)),
                      Hc + V((0.24, -0.62, -1.05))], 10 if hi else 4)
    tube(pc, tail, lambda t: (0.048 * (1 - 0.35 * t), 0.010), 6 if hi else 4, "SHROUD", up=V((0, 1, 0)))

    # the douli: a broad bamboo hat tipped forward over the brow, a bite broken out of the brim at his front left
    HM = tr(Hc + V((0.0, -0.04, 0.18))) @ rot("X", -8)
    R0, nphi, nr = 0.74, (120 if hi else 40), (16 if hi else 5)
    rnd = random.Random(23)
    jag = [rnd.uniform(-1, 1) for _ in range(nphi)]

    def rim(j):
        ph = -math.pi + 2 * math.pi * j / nphi
        deg = math.degrees(ph)
        bite = smooth((deg + 66) / 10) * smooth((-18 - deg) / 10)
        return ph, R0 - 0.26 * bite + (0.008 + 0.05 * bite) * jag[j], bite

    top_rows, und_rows = [], []
    for i in range(nr + 1):
        f = i / nr
        rt, ru = [], []
        for j in range(nphi):
            ph, R, _ = rim(j)
            r = lerp(0.035, R, f)
            u = r / R0
            sag = 0.012 * math.sin(5 * ph + 1.0) * u * u
            d = V((math.sin(ph), math.cos(ph), 0.0))
            rt.append(HM @ (d * r + V((0, 0, 0.30 - 0.29 * u ** 1.1 + sag))))
            ru.append(HM @ (d * r + V((0, 0, 0.27 - 0.295 * u + sag))))
        top_rows.append(rt)
        und_rows.append(ru)
    pc.grid(top_rows, "DOULI", closed_u=True, cap0=True)
    pc.grid(und_rows, "DOULI_IN", closed_u=True, cap0=True, flip=True)
    pc.grid([top_rows[-1], und_rows[-1]], "DOULI", closed_u=True)
    lathe(pc, [(0.0, 0.0), (0.045, 0.0), (0.038, 0.028), (0.0, 0.046)], 12 if hi else 6, "DOULI", HM @ tr((0, 0, 0.292)))
    for j in range(nphi):   # snapped splints stick out of the broken bite
        ph, R, bite = rim(j)
        if bite > 0.6 and j % (2 if hi else 3) == 0:
            d = V((math.sin(ph), math.cos(ph), 0.0))
            L = R + rnd.uniform(0.06, 0.2)
            pts = [HM @ (d * (R - 0.05) + V((0, 0, 0.285 - 0.29 * (R - 0.05) / R0))),
                   HM @ (d * L + V((0, 0, 0.285 - 0.29 * L / R0 - rnd.uniform(0.0, 0.05))))]
            tube(pc, pts, lambda t: 0.007 * (1 - 0.6 * t), 4 if hi else 3, "DOULI")
    for s in (-1, 1):   # chin cords from the hat frame, down the cheeks, knotted under the jaw
        tube(pc, curve_pts([HM @ V((s * 0.26, -0.02, 0.17)), Hc + V((s * 0.265, 0.0, -0.12)), Hc + V((s * 0.17, 0.11, -0.36)),
                            Hc + V((0.0, 0.17, -0.40))], 10 if hi else 4), 0.008, 5 if hi else 3, "ROPE")
    return pc


# ---------------------------------------------------------------------------------------------------------
def upper_torso(hi):
    pc = Piece(NAME + "_UpperTorso", "UpperTorso")
    nz, na = (30, 72) if hi else (10, 24)
    rows = []
    for i in range(nz + 1):
        z = lerp(-0.5, 1.05, i / nz)
        rows.append([torso_pt(a, z, muscle(a, z)) for a in [-math.pi + 2 * math.pi * k / na for k in range(na)]])
    pc.grid(rows, "SKIN", closed_u=True, cap0=True, cap1=True)
    # kasaya: one wrap from the waist up to a diagonal edge, folds radiating from the left shoulder
    nzk = 16 if hi else 6
    rows, edge = [], []
    for i in range(nzk + 1):
        v = i / nzk
        row = []
        for k in range(na):
            a = -math.pi + 2 * math.pi * k / na
            top = kasaya_top(a)
            z = lerp(-0.42, top, v)
            fold = 0.014 * math.sin(16 * (0.55 * a + 0.9 * z)) * smooth(v / 0.3) * (1 if hi else 0.5)
            row.append(torso_pt(a, z, 0.03 + max(0.0, muscle(a, z)) + fold + 0.012 * v))
        rows.append(row)
    pc.grid(rows, "KASAYA", closed_u=True)
    edge = rows[-1]
    tube(pc, edge + edge[:1], 0.020, 6 if hi else 4, "KASAYA", cap0=False, cap1=False)
    # burnt tail of the kasaya gathered at the left shoulder and hanging down the back
    xs = [lerp(-0.74, -0.16, k / (12 if hi else 5)) for k in range((12 if hi else 5) + 1)]
    zs = [lerp(0.92, -0.25, k / (22 if hi else 8)) for k in range((22 if hi else 8) + 1)]
    yb = lambda x, z: -(interp(TORSO, z)[2] + 0.075) * max(0.35, 1 - (abs(x) / 0.85) ** 3) - 0.02 * math.sin(x * 14 + z * 3)
    zb.panel(pc, xs, zs, yb, "KASAYA", 0.022, fray=0.12, seed=5)
    # prayer beads: a heavy loop round the neck lying on the chest, three beads cracked to ember
    n = 34
    loop = []
    for k in range(n):
        a = -math.pi + 2 * math.pi * (k + 0.5) / n
        h = 0.64 - 0.34 * math.cos(a)
        on = 0.03 + 0.012 if kasaya_top(a) > h else 0.0
        p = torso_pt(a, h, max(0.0, muscle(a, h)) + on)
        loop.append(p + zb.surf_normal(torso_pt, a, h, centre) * 0.046)
    for k, p in enumerate(loop):
        sphere(pc, p, 0.043, "BEAD_CRACK" if k in (5, 14, 25) else "BEAD", hi)
    tube(pc, loop + loop[:1], 0.008, 4, "CORD", cap0=False, cap1=False)
    g = torso_pt(0, 0.30, 0.05) + V((0, 0.04, -0.05))
    sphere(pc, g, 0.066, "BEAD_CRACK", hi, 14 if hi else 8)
    for dx in ((-0.02, 0.0, 0.02) if hi else (0.0,)):
        tube(pc, curve_pts([g + V((dx, 0, -0.06)), g + V((dx * 1.5, 0.01, -0.16)), g + V((dx * 2.5, 0.0, -0.30))], 6),
             lambda t: 0.018 * (1 - 0.4 * t) + 0.004, 6 if hi else 4, "ROPE")
    mantle(pc, hi)
    return pc


def mantle(pc, hi):
    """Straw rain cape (suoyi) over the shoulders in two shaggy tiers, tied at the collar: it sets the wanderer's
    silhouette and hides where the rigid arms meet the torso."""
    na = 72 if hi else 28
    rnd = random.Random(61)

    def hem_z(a):   # front 0.46, sides 0.54, longest down the back
        c = math.cos(a)
        return 0.54 - 0.08 * max(0.0, c) - 0.24 * max(0.0, -c)

    def at(t, a, out=0.0):
        s, c = math.sin(a), math.cos(a)
        g = t ** 0.5
        rx = lerp(0.25, 1.13, g) + out
        ry = lerp(0.22, 0.52 if c >= 0 else 0.56, g) + out
        return V((math.copysign(abs(s) ** (2 / 2.4), s) * rx, -0.02 + math.copysign(abs(c) ** (2 / 2.4), c) * ry,
                  1.16 - (1.16 - hem_z(a)) * t ** 1.5))

    for tmax, out, nr, seed in ((1.0, 0.0, 10 if hi else 4, 3), (0.6, 0.04, 6 if hi else 3, 7)):
        jag = [rnd.uniform(-1, 1) for _ in range(na)]
        P = []
        for i in range(nr + 1):
            row = []
            for k in range(na):
                a = -math.pi + 2 * math.pi * k / na
                t = tmax * i / nr
                if i == nr:
                    t += 0.07 * jag[k]
                row.append(at(t, a, out + 0.012 * math.sin(11 * a + seed) * (1 if hi else 0.5)))
            P.append(row + row[:1])
        slab(pc, P, 0.028, "STRAW_CAPE")
        if hi:   # loose straws hanging off the hem
            for _ in range(160 if tmax == 1.0 else 110):
                a = rnd.uniform(-math.pi, math.pi)
                t0 = tmax - 0.06
                t1 = tmax + rnd.uniform(0.06, 0.16)
                tube(pc, [at(t0, a, out + 0.016), at((t0 + t1) / 2, a, out + 0.02), at(t1, a, out + 0.012 + rnd.uniform(0, 0.03))],
                     lambda t: 0.006 * (1 - 0.7 * t), 4, "STRAW_CAPE", cap0=False)
    collar = [at(0.03, -math.pi + 2 * math.pi * k / na, 0.012) for k in range(na)]
    tube(pc, collar + collar[:1], 0.03, 6 if hi else 4, "ROPE", cap0=False, cap1=False)


def lower_torso(hi):
    pc = Piece(NAME + "_LowerTorso", "LowerTorso")
    na, nz = (56, 14) if hi else (18, 5)
    rows = [[torso_pt(-math.pi + 2 * math.pi * k / na, lerp(-1.05, -0.28, i / nz), 0.02) for k in range(na)] for i in range(nz + 1)]
    pc.grid(rows, "TROUSER", closed_u=True, cap0=True, cap1=True)
    # the kasaya's wrapped skirt top over the hips
    rows = []
    for i in range(7 if hi else 3):
        z = lerp(-0.30, -0.80, i / (6 if hi else 2))
        rows.append([torso_pt(a, z, 0.06 + 0.012 * math.sin(9 * a + 4 * z) * (1 if hi else 0.5))
                     for a in [-math.pi + 2 * math.pi * k / na for k in range(na)]])
    pc.grid(rows, "KASAYA", closed_u=True)
    # rope sash: two twisted turns, a knot at the left front, tails hanging
    for z, r in ((-0.36, 0.024), (-0.43, 0.022)):
        ring = [torso_pt(-math.pi + 2 * math.pi * k / na, z, 0.09 + 0.006 * math.sin(k * 1.3)) for k in range(na)]
        tube(pc, ring + ring[:1], r, 6 if hi else 4, "ROPE", cap0=False, cap1=False)
    kn = torso_pt(-0.55, -0.40, 0.12)
    sphere(pc, kn, 0.05, "ROPE", hi)
    for dx, ln in ((-0.03, 0.55), (0.03, 0.42)):
        tube(pc, curve_pts([kn, kn + V((dx, 0.04, -0.15)), kn + V((dx * 2, 0.06, -ln))], 8 if hi else 4),
             lambda t: 0.02 * (1 - 0.35 * t), 6 if hi else 4, "ROPE")
    # cracked iron alms bowl tied at the right hip
    b = torso_pt(1.75, -0.62, 0.20)
    tube(pc, [torso_pt(1.6, -0.40, 0.10), b + V((0, 0, 0.08))], 0.009, 4, "ROPE")
    M = tr(b) @ rot("Y", 18) @ rot("X", 8)
    lathe(pc, [(0.0, -0.10), (0.09, -0.095), (0.15, -0.06), (0.17, 0.0), (0.165, 0.02), (0.15, 0.0), (0.13, -0.05),
               (0.0, -0.07)], 24 if hi else 10, "IRON", M)
    # front flap hanging from the sash between the leg skirts
    n = 8 if hi else 4
    xs = [lerp(-0.30, 0.30, k / n) for k in range(n + 1)]
    zs = [lerp(-0.46, -1.62, k / (16 if hi else 6)) for k in range((16 if hi else 6) + 1)]
    yf = lambda x, z: interp(TORSO, max(z, -1.05))[1] * (1 - 0.6 * smooth((-0.7 - z) / 0.4)) + 0.10 + 0.08 * smooth((-0.7 - z) / 0.6) \
        + 0.02 * math.sin(x * 16 + 1.0) * smooth((-0.8 - z) / 0.6) - 0.08 * (x / 0.3) ** 2
    zb.panel(pc, xs, zs, yf, "KASAYA", 0.02, fray=0.1, seed=9)
    # rear skirt panels, split so the legs can stride
    for s in (-1, 1):
        n = 14 if hi else 5
        xs = [s * lerp(0.04, 0.58, k / n) for k in range(n + 1)]
        zs = [lerp(-0.70, -1.95, k / (24 if hi else 8)) for k in range((24 if hi else 8) + 1)]

        def yb(x, z):
            f = smooth((-0.7 - z) / 0.9)
            fold = 0.045 * math.sin(abs(x) * 12.0 + 0.8) * smooth((-0.9 - z) / 1.2)
            return -0.42 * max(0.0, 1 - (abs(x) / 0.75) ** 2.4) ** (1 / 2.4) * (1 - f) + (-0.52 + 0.2 * (abs(x) / 0.58) ** 2) * f + fold

        zb.panel(pc, xs, zs, yb, "KASAYA", 0.02, fray=0.12, seed=21 + s, xfun=lambda x, z: x * (1 + 0.1 * smooth((-0.8 - z) / 1.2)))
    return pc


# ---------------------------------------------------------------------------------------------------------
def upper_leg(hi, s):
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}UpperLeg", side + "UpperLeg")
    X = s * HIP_X
    tube(pc, [V((X, 0.0, -0.80)), V((X + s * 0.02, 0.01, -1.35)), V((X, 0.02, -1.98))],
         lambda t: (0.29 - 0.06 * t + 0.02 * math.sin(math.pi * t), 0.28 - 0.06 * t), 24 if hi else 12, "TROUSER")
    # skirts wrapped round the front and outside of the thigh: the grey under-robe, longer, then the kasaya
    for mat, z1, r0, a0, a1, seed in (("ROBE", -2.12, 0.33, -0.2, 2.6, 41), ("KASAYA", -1.80, 0.37, -0.35, 2.25, 31)):
        na_, nzz = (16, 22) if hi else (7, 8)
        random.seed(seed + s)
        P = []
        for i in range(nzz + 1):
            f = i / nzz
            z = lerp(-0.66, z1, f)
            row = []
            for j in range(na_ + 1):
                a = lerp(a0, a1, j / na_)
                r = r0 + 0.10 * smooth(f / 0.8) + 0.022 * math.sin(7 * a + 3 * f) * smooth(f / 0.35)
                zz = z + ((random.random() - 0.4) * 0.10 if i == nzz else 0.0)
                row.append(V((X + s * math.sin(a) * r, 0.02 + math.cos(a) * r, zz)))
            P.append(row)
        slab(pc, P, 0.02, mat)
    return pc


def lower_leg(hi, s):
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}LowerLeg", side + "LowerLeg")
    X = s * HIP_X
    nz, na = (22, 28) if hi else (6, 10)
    rows = []
    for i in range(nz + 1):
        t = i / nz
        z = lerp(-1.66, -2.76, t)
        calf = G((t - 0.3) ** 2, 0.18)
        blouse = 0.05 * G((t - 0.05) ** 2, 0.05)   # trousers bunched above the wraps
        rx = 0.14 + 0.05 * calf - 0.02 * t + blouse
        rows.append(sring(V((X, 0.01, z)), V((1, 0, 0)), V((0, 1, 0)), rx, 0.14 + 0.02 * calf + blouse, na, 2.2, -math.pi / 2,
                          0.14 + 0.08 * calf + blouse))
    pc.grid(rows, "TROUSER", closed_u=True, cap0=True, cap1=True)

    def r_at(f):
        t = lerp(0.2, 0.98, f)
        return 0.14 + 0.05 * G((t - 0.3) ** 2, 0.18) - 0.02 * t + 0.035
    bands(pc, V((X, 0.03, -1.88)), V((X, 0.01, -2.74)), r_at, None, 9 if hi else 4, "LINEN", hi, tilt=0.22, out=0.0)
    return pc


def foot(hi, s):
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}Foot", side + "Foot")
    X = s * HIP_X
    n = 24 if hi else 8
    rows = []
    for i in range(n + 1):
        t = i / n
        y = lerp(-0.20, 0.36, t)
        top = SOLE_Z + lerp(0.30, 0.11, smooth((t - 0.15) / 0.75))
        bot = SOLE_Z + 0.05
        w = 0.13 * (1 + 0.12 * smooth((t - 0.5) / 0.4)) * (1 - 0.5 * smooth((t - 0.94) / 0.06)) + 0.01
        rows.append(sring(V((X + s * 0.01 * t, y, (top + bot) / 2)), V((1, 0, 0)), V((0, 0, 1)), w, (top - bot) / 2, 18 if hi else 8, 2.6))
    pc.grid(rows, "SKIN", closed_u=True, cap0=True, cap1=True)
    # toes: big toe inside, four smaller ones fanning out
    for k, (dx, r, ln) in enumerate(((-0.075, 0.036, 0.11), (-0.02, 0.026, 0.10), (0.025, 0.024, 0.09), (0.065, 0.022, 0.08),
                                     (0.10, 0.02, 0.065))):
        x = X + s * dx
        tube(pc, [V((x, 0.31, SOLE_Z + 0.08)), V((x, 0.31 + ln * 0.6, SOLE_Z + 0.075)), V((x, 0.31 + ln, SOLE_Z + 0.06))],
             lambda t, r=r: r * (1 - 0.2 * t), 8 if hi else 5, "SKIN")
    # straw sandal: woven sole a little wider than the foot, toe thong and ankle ties
    S = []
    m = 12 if hi else 6
    for k in range(m + 1):
        t = k / m
        y = lerp(-0.23, 0.47, t)
        w = 0.16 * (1 + 0.1 * smooth((t - 0.5) / 0.4)) * (1 - 0.35 * smooth((t - 0.85) / 0.15)) + 0.01
        S.append([V((X - w, y, SOLE_Z + 0.025)), V((X + w, y, SOLE_Z + 0.025))])
    slab(pc, [[r[0] for r in S], [r[1] for r in S]], 0.05, "STRAW")
    tp = V((X - s * 0.045, 0.34, SOLE_Z + 0.06))
    for sd in (-1, 1):
        tube(pc, curve_pts([tp, V((X + sd * 0.12, 0.15, SOLE_Z + 0.17)), V((X + sd * 0.15, -0.05, SOLE_Z + 0.2))], 8 if hi else 4),
             0.012, 5 if hi else 4, "ROPE")
    ring = [V((X + math.cos(a) * 0.155, 0.0 + math.sin(a) * 0.15, SOLE_Z + 0.24 + 0.02 * math.sin(a))) for a in
            [2 * math.pi * k / 16 for k in range(16)]]
    tube(pc, ring + ring[:1], 0.013, 5 if hi else 4, "ROPE", cap0=False, cap1=False)
    return pc


# ---------------------------------------------------------------------------------------------------------
def sx(v, s):
    return V((v.x * s, v.y, v.z))


def upper_arm(hi, s):
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}UpperArm", side + "UpperArm")
    a0, a1 = sx(ARM_TOP, s), sx(ARM_ELBOW, s)
    path = curve_pts([a0.lerp(a1, 0.14), a0.lerp(a1, 0.5) + V((s * 0.015, 0.01, 0)), a1 - V((0, 0, 0.05))], 14 if hi else 5)
    tube(pc, path, lambda t: 0.150 + 0.028 * math.sin(math.pi * min(1, t * 1.3)) - 0.035 * t, 24 if hi else 12, "SKIN")
    # deltoid cap bridging shoulder and arm
    M = tr(V((s * 0.84, 0.0, 0.68))) @ rot("Y", s * 24)
    lathe(pc, [(0.0, 0.16), (0.10, 0.145), (0.165, 0.09), (0.185, 0.02), (0.17, -0.08), (0.125, -0.19), (0.0, -0.25)],
          24 if hi else 10, "SKIN", M, sy=1.08)
    # biceps and triceps masses
    lathe(pc, [(0.0, -0.17), (0.07, -0.12), (0.095, 0.0), (0.07, 0.12), (0.0, 0.17)], 16 if hi else 6, "SKIN",
          tr(a0.lerp(a1, 0.5) + V((s * -0.005, 0.085, 0.04))))
    lathe(pc, [(0.0, -0.2), (0.08, -0.13), (0.1, 0.0), (0.075, 0.13), (0.0, 0.2)], 16 if hi else 6, "SKIN",
          tr(a0.lerp(a1, 0.42) + V((s * 0.01, -0.085, 0.0))))
    if s < 0:
        # the kasaya's ragged half-sleeve, its top tucked up under the straw cape
        n = 28 if hi else 10
        random.seed(17)
        hem = [0.30 + 0.05 * math.sin(3 * (2 * math.pi * k / n)) + (random.random() - 0.5) * (0.06 if hi else 0.03) for k in range(n)]
        ax = (a1 - a0).normalized()
        rows_o, rows_i = [], []
        for i in range(7 if hi else 3):
            f = i / (6 if hi else 2)
            row_o, row_i = [], []
            for k in range(n):
                t = 2 * math.pi * k / n
                zt = lerp(0.62, hem[k], f)
                c = a0 + ax * ((a0.z - zt) / max(1e-3, -ax.z))
                r = 0.22 + 0.05 * f + 0.012 * math.sin(5 * t + 2 * f) * (1 if hi else 0)
                d = V((math.cos(t), math.sin(t) * 1.08, 0))
                row_o.append(c + d * r)
                row_i.append(c + d * (r - 0.02))
            rows_o.append(row_o)
            rows_i.append(row_i)
        pc.grid(rows_o, "KASAYA", closed_u=True)
        pc.grid(rows_i, "KASAYA", closed_u=True, flip=True)
        pc.grid([rows_o[-1], rows_i[-1]], "KASAYA", closed_u=True)
    else:
        # a corrupted vein-dark band of linen tied above the bare right elbow
        bands(pc, a0.lerp(a1, 0.72), a0.lerp(a1, 0.86), 0.155, 0.15, 2, "LINEN", hi, tilt=0.1, out=0.01)
    return pc


def lower_arm(hi, s):
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}LowerArm", side + "LowerArm")
    e, w = sx(ARM_ELBOW, s), sx(ARM_WRIST, s)
    tube(pc, curve_pts([e + V((0, 0, 0.07)), e.lerp(w, 0.35) + V((0, 0.01, 0)), w], 12 if hi else 4),
         lambda t: 0.15 - 0.045 * t + 0.03 * G((t - 0.25) ** 2, 0.03), 22 if hi else 12, "SKIN")
    bands(pc, e.lerp(w, 0.30), w + V((s * 0.005, 0, -0.02)), lambda f: 0.15 - 0.045 * lerp(0.3, 1.0, f) + 0.012, None,
          8 if hi else 4, "LINEN", hi, tilt=0.2, out=0.004)
    return pc


def hand(hi, s):
    side = "Right" if s > 0 else "Left"
    pc = Piece(f"{NAME}_{side}Hand", side + "Hand")
    F = sx(FIST, s)
    R = 0.062
    X, Y = V((s, 0, 0)), V((0, 1, 0))
    nz, na = (10, 20) if hi else (3, 8)
    rows = []
    for i in range(nz + 1):
        t = i / nz
        z = lerp(-0.70, F.z + 0.01, t)
        cx = F.x + s * (0.07 + 0.012 * math.sin(math.pi * t))
        rows.append(sring(V((cx, 0.01, z)), X, Y, 0.05 + 0.008 * t, 0.104 + 0.022 * t, na, 3.0))
    pc.grid(rows, "SKIN", closed_u=True, cap0=True, cap1=True)
    # linen wound across the palm and the back of the hand, and over the knuckles
    bands(pc, V((F.x + s * 0.07, 0.01, -0.74)), V((F.x + s * 0.07, 0.01, -0.83)), 0.066, 0.075, 2, "LINEN", hi, tilt=0.1,
          out=0.01, seg=16 if hi else 8)
    lens = (1.0, 1.07, 1.0, 0.82)
    ys = (0.100, 0.034, -0.032, -0.094)
    for f, (ly, L) in enumerate(zip(ys, lens)):
        n = 22 if hi else 7
        pts = []
        for k in range(n):
            t = k / (n - 1)
            ang = math.radians(12 - 250 * L * t)
            pts.append(V((F.x + s * math.cos(ang) * R, ly - 0.01 * t * (f - 1.5), F.z + math.sin(ang) * R)))
        knuckles = lambda t: 0.0055 * (G((t - 0.02) ** 2, 0.03) + G((t - 0.38) ** 2, 0.03) + G((t - 0.7) ** 2, 0.03))
        tube(pc, pts, lambda t, L=L, kn=knuckles: (0.034 * (1 - 0.22 * t) + kn(t)) * (0.94 if L < 0.9 else 1.0), 12 if hi else 6, "SKIN",
             up=V((0, 1, 0)))
    P = []
    for ang in (14, -8, -32):
        a_ = math.radians(ang)
        P.append([V((F.x + s * math.cos(a_) * (R + 0.04), y, F.z + math.sin(a_) * (R + 0.04))) for y in (-0.13, -0.065, 0.0, 0.065, 0.135)])
    slab(pc, P, 0.012, "LINEN")
    th = [V((F.x + s * 0.06, 0.12, -0.74)), V((F.x + s * 0.03, 0.165, F.z + 0.06)), V((F.x - s * 0.03, 0.16, F.z + 0.02)),
          V((F.x - s * 0.07, 0.13, F.z - 0.03))]
    tube(pc, curve_pts(th, 16 if hi else 6), lambda t: 0.037 * (1 - 0.25 * t) + 0.004 * G((t - 0.5) ** 2, 0.02), 12 if hi else 6, "SKIN")
    return pc


def build(hi):
    out = [head(hi), upper_torso(hi), lower_torso(hi)]
    for s in (1, -1):
        out += [upper_arm(hi, s), lower_arm(hi, s), hand(hi, s), upper_leg(hi, s), lower_leg(hi, s), foot(hi, s)]
    return out
