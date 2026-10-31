"""Zhao's guandao, a separate asset. Rest binding as the costume: haft along the hand's -Z (Blender +Y)
through the right fist, cutting edge up. The blade tip sits TIP studs ahead of the RightHand centre."""
import math
import random

from mathutils import Matrix

from body import FIST, HAFT_R, smooth
from lib import V, Piece, curve_pts, lathe, rot, slab, tr, tube

TIP = 9.2
HAND_CENTRE = V((1.5, 0.0, -0.85))
AX = Matrix.Translation(FIST) @ rot("X", -90)  # local +Z of lathes runs along +Y from the fist


def haft(hi):
    pc = Piece("Zhao_GuandaoHaft", "RightHand", "Weapon")
    n = 16 if hi else 10
    # oxblood lacquered haft, oval in section, slightly swelling at the balance point
    pts = [FIST + V((0, y, 0)) for y in [-1.30 + 8.42 * k / (40 if hi else 10) for k in range(((40 if hi else 10)) + 1)]]
    tube(pc, pts, lambda t: (HAFT_R * (1 + 0.06 * math.sin(math.pi * t)), HAFT_R * 0.92 * (1 + 0.06 * math.sin(math.pi * t))),
         n, "WOOD_RED", up=V((0, 0, 1)))
    # iron bands
    for y in (-1.05, 1.15, 3.6, 6.0, 6.85):
        lathe(pc, [(HAFT_R + 0.004, -0.05), (HAFT_R + 0.016, -0.035), (HAFT_R + 0.018, 0.0), (HAFT_R + 0.016, 0.035),
                   (HAFT_R + 0.004, 0.05)], n, "IRON", AX @ tr((0, 0, y)))
    # cord-wrapped grips for the right hand and the left hand's sliding position
    for y0, y1 in ((-0.42, 0.42), (2.25, 3.25)):
        m = 22 if hi else 3
        prof = []
        for k in range(m + 1):
            y = y0 + (y1 - y0) * k / m
            bulge = 0.006 * (abs(math.sin(k * math.pi / 2)) if hi else 1)
            prof.append((HAFT_R + 0.008 + bulge, y))
        lathe(pc, prof, n, "CORD", AX)
    # butt spike (zun)
    lathe(pc, [(HAFT_R + 0.012, -1.24), (HAFT_R + 0.02, -1.32), (0.07, -1.40), (0.05, -1.48), (0.035, -1.62),
               (0.0, -1.74)], n, "IRON", AX, cap0=True)
    return pc


def blade(hi):
    pc = Piece("Zhao_GuandaoBlade", "RightHand", "Weapon")
    n = 18 if hi else 8
    # dragon-mouth collar (tunkou): flared socket that swallows the blade tang
    prof = [(HAFT_R + 0.01, 6.92), (0.10, 6.96), (0.115, 7.04), (0.10, 7.10), (0.125, 7.16), (0.145, 7.24),
            (0.13, 7.30), (0.08, 7.34)]
    lathe(pc, prof, n, "IRON", AX, cap1=True, sy=1.25)
    if hi:  # fang ridges around the collar mouth
        for k in range(8):
            a = 2 * math.pi * k / 8
            p0 = FIST + V((math.cos(a) * 0.13, 7.16, math.sin(a) * 0.15))
            tube(pc, [p0, p0 + V((math.cos(a) * 0.035, 0.12, math.sin(a) * 0.04))], lambda t: 0.018 * (1 - t) + 0.002, 6, "BRONZE")
    # crescent blade, edge up. Each column is a closed section: edge -> +x face -> spine -> -x face.
    edge = curve_pts([(7.22, 0.12), (7.48, 0.30), (7.85, 0.41), (8.25, 0.49), (8.62, 0.58), (8.92, 0.70), (9.12, 0.82), (TIP, 0.88)], 44 if hi else 24)
    spine = curve_pts([(7.22, -0.10), (7.6, -0.10), (8.0, -0.085), (8.38, -0.045), (8.66, 0.06), (8.92, 0.30), (9.09, 0.58), (TIP, 0.88)],
                      44 if hi else 24)
    rows = []
    for i, (e, sp) in enumerate(zip(edge, spine)):
        t = i / (len(edge) - 1)
        y = (e.x + sp.x) / 2
        ze, zs = e.y, sp.y
        th = 0.034 * (1 - 0.55 * t) * (1 - smooth((t - 0.9) / 0.1)) + 0.002
        sec = []
        # +x side from edge down to spine, then -x side back up
        prof = (0.0, 0.08, 0.3, 0.55, 0.78, 1.0) if hi else (0.0, 0.3, 1.0)
        for f in prof:
            z = ze + (zs - ze) * f
            w = th * smooth(f / 0.45) * (1 if f < 0.98 else 0.85)
            groove = (-0.35 * th * math.exp(-((f - 0.62) ** 2) / 0.004) if hi and 0.08 < t < 0.8 else 0.0)
            sec.append(FIST + V((w + groove * 0.5, y, z)))
        for p in reversed(sec[1:]):
            sec.append(V((2 * FIST.x - p.x, p.y, p.z)))
        rows.append(sec)
    pc.grid(rows, "STEEL", closed_u=True, cap0=True, cap1=True)
    # back spur on the spine, angled toward the haft
    P = []
    for f in (0.0, 1.0):
        P.append([FIST + V((0, 7.84 + 0.14 * g - 0.10 * f, -0.08 - 0.20 * f * (1 - abs(g)) - 0.02 * f)) for g in (-1, 0, 1)])
    slab(pc, P, 0.03, "STEEL")
    # red tassel hanging from the collar
    top = FIST + V((0, 6.98, -0.12))
    lathe(pc, [(0.03, 0.0), (0.04, -0.03), (0.03, -0.06)], 10 if hi else 6, "BRONZE", tr(top))
    if hi:
        random.seed(5)
        for k in range(14):
            a = 2 * math.pi * k / 14
            off = V((math.cos(a) * 0.025, math.sin(a) * 0.025, 0))
            end = top + V((math.cos(a) * (0.07 + random.random() * 0.03), -0.06 + math.sin(a) * 0.06, -0.48 - random.random() * 0.12))
            tube(pc, curve_pts([top + off - V((0, 0, 0.06)), top + off * 1.5 + V((0, -0.02, -0.25)), end], 8),
                 lambda t: 0.012 * (1 - 0.6 * t), 5, "CLOTH_RED")
    else:
        tube(pc, [top - V((0, 0, 0.05)), top + V((0, -0.02, -0.3)), top + V((0, -0.05, -0.58))],
             lambda t: 0.03 + 0.06 * t, 6, "CLOTH_RED")
    return pc


def build(hi):
    return [haft(hi), blade(hi)]
