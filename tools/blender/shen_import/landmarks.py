"""Measured landmarks, seeds and cut rules of Shen's two sculpts, in rig space (rigspace.py). Numbers were read off gridded views (work/shen_import/measure) and colour statistics."""
import numpy as np


class Ctx:
    def __init__(self, p, hue, sat, val, rgb):
        self.p, self.hue, self.sat, self.val, self.rgb = p, hue, sat, val, rgb
        self.x, self.y, self.z = p[:, 0], p[:, 1], p[:, 2]
        self.cache = {}


def unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def caps(p, a, b, r):
    a, b = np.array(a, float), np.array(b, float)
    d = b - a
    t = np.clip(((p - a) @ d) / (d @ d), 0, 1)
    return np.linalg.norm(p - (a + t[:, None] * d), axis=1) < r


def along(p, a, b):
    a, b = np.array(a, float), np.array(b, float)
    d = b - a
    t = ((p - a) @ d) / (d @ d)
    return t, np.linalg.norm(p - (a + t[:, None] * d), axis=1)


def ball(p, c, r):
    return np.linalg.norm(p - np.array(c, float), axis=1) < r


def cut(lab, names, a, b, is_a, where=None):
    m = (lab == names.index(a)) | (lab == names.index(b))
    if where is not None:
        m &= where
    lab[m] = np.where(is_a[m], names.index(a), names.index(b))


def plane(p, at, normal):
    return (p - np.array(at, float)) @ unit(normal)


def haft_line(c, butt, socket):
    """The haft is slightly bowed: a polyline through the medians of its own dark surface, binned along the butt->socket chord."""
    if "haft" in c.cache:
        return c.cache["haft"]
    t, d = along(c.p, butt, socket)
    dark = (c.sat < 0.30) & (c.val < 0.32) & (d < 0.42) & (t > 0.02) & (t < 1.0)
    bins = np.linspace(0.02, 1.0, 17)
    pts = []
    for lo, hi in zip(bins[:-1], bins[1:]):
        m = dark & (t >= lo) & (t < hi)
        if m.sum() > 12:
            pts.append(np.median(c.p[m], axis=0))
    pts = np.array(pts)
    c.cache["haft"] = pts
    return pts


def haft_dist(c, butt, socket):
    if "haftd" in c.cache:
        return c.cache["haftd"]
    pts = haft_line(c, butt, socket)
    best = np.full(len(c.p), 1e9)
    for a, b in zip(pts[:-1], pts[1:]):
        d = b - a
        u = np.clip(((c.p - a) @ d) / (d @ d), 0, 1)
        best = np.minimum(best, np.linalg.norm(c.p - (a + u[:, None] * d), axis=1))
    # past the ends: straight on along the chord
    t, line = along(c.p, butt, socket)
    best = np.where((t < 0.03) | (t > 0.99), line, best)
    c.cache["haftd"] = best
    return best


def pale(c):
    return (c.sat < 0.085) & (c.val > 0.38)


class P1:
    """Disciplined Master. Haft through the right fist; beads down his right chest; hair falls to the waist behind; coat over an ivory inner skirt."""
    PELVIS, WAIST, NECK = (-0.09, -0.25, -0.10), (-0.09, 0.25, -0.10), (-0.12, 1.65, -0.25)
    RSH, REL, RWR, RGRIP = (0.64, 1.14, -0.03), (0.96, 0.38, -0.03), (1.06, -0.20, -0.42), (0.96, -0.42, -0.45)
    LSH, LEL, LWR, LHAND = (-0.80, 1.14, 0.00), (-1.12, 0.31, 0.00), (-1.15, -0.26, -0.28), (-1.05, -0.55, -0.33)
    RHIP, RKN, RAN = (0.25, -0.55, -0.10), (0.68, -1.85, 0.02), (0.95, -2.85, 0.12)
    LHIP, LKN, LAN = (-0.45, -0.55, -0.10), (-0.66, -1.85, 0.02), (-0.72, -2.85, 0.12)
    BUTT, SOCKET = (1.96, 1.56, 1.28), (0.55, -1.10, -1.15)
    NAMES = ["Head", "UpperTorso", "LowerTorso", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
             "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
             "HairBack", "Beard", "Beads", "RightMantle", "LeftMantle", "RobeBack", "RobeRight", "RobeLeft", "RobeInner", "RobeFront", "Weapon"]
    DEFAULT = "UpperTorso"
    KEEP = ("Weapon",)

    @staticmethod
    def weapon(c):
        d = haft_dist(c, P1.BUTT, P1.SOCKET)
        t, line = along(c.p, P1.BUTT, P1.SOCKET)
        butt_cap = (t > -0.09) & (t < 0.13) & (line < 0.25)
        haft = (t > -0.09) & (t < 1.0) & (d < 0.135)
        collar = (t >= 0.86) & (t < 1.18) & (line < 0.5) & (c.z < -0.85)
        blade = (c.z < -1.28) & (c.y < -0.9)
        return haft | butt_cap | collar | blade

    @staticmethod
    def beads(c):
        if "beads" in c.cache:
            return c.cache["beads"]
        chain = caps(c.p, (0.12, 1.75, -0.30), (0.16, 1.25, -0.72), 0.34) | caps(c.p, (0.16, 1.25, -0.72), (-0.42, 0.78, -0.82), 0.32)
        dark = (c.val < 0.30) & (c.y > 0.55) & (c.y < 1.95) & (c.z < -0.05) & chain
        # the string of beads, from the medians of the dark surface: painted shadow on the robe beside it stays robe
        rows = [np.median(c.p[dark & (c.y >= lo) & (c.y < lo + 0.1)], axis=0) for lo in np.arange(0.62, 1.9, 0.1) if (dark & (c.y >= lo) & (c.y < lo + 0.1)).sum() > 40]
        best = np.full(len(c.p), 1e9)
        for a, b in zip(rows[:-1], rows[1:]):
            d = b - a
            u = np.clip(((c.p - a) @ d) / max(d @ d, 1e-9), 0, 1)
            best = np.minimum(best, np.linalg.norm(c.p - (a + u[:, None] * d), axis=1))
        c.cache["beads"] = dark & (best < 0.235)
        return c.cache["beads"]

    @staticmethod
    def seeds(c):
        x, y, z, J = c.x, c.y, c.z, P1
        out = []
        add = lambda b, m: out.append((b, m))
        ivory = (c.hue > 22) & (c.hue < 52) & (c.sat < 0.36) & (c.val > 0.6)
        indigo = (c.hue > 200) & (c.hue < 275) & (c.sat > 0.18)
        add("UpperTorso", (np.abs(x + 0.09) < 0.62) & (y > 0.5) & (y < 1.45) & (np.abs(z + 0.12) < 0.56))
        add("LowerTorso", (np.abs(x + 0.09) < 0.72) & (y > -0.15) & (y < 0.42) & (np.abs(z + 0.12) < 0.62))
        skirt = y < -0.14
        add("RobeInner", skirt & ivory & (z < 0.3) & (np.abs(x + 0.1) < 1.15))
        add("RobeBack", skirt & indigo & (z > 0.15))
        add("RobeRight", skirt & indigo & (z <= 0.15) & (x > -0.09))
        add("RobeLeft", skirt & indigo & (z <= 0.15) & (x <= -0.09))
        add("RobeFront", (x > -0.42) & (x < 0.12) & (y > -2.3) & (y < -0.14) & (z < -0.45) & indigo)
        for side, hip, kn, an in (("Right", J.RHIP, J.RKN, J.RAN), ("Left", J.LHIP, J.LKN, J.LAN)):
            blk = (c.val < 0.20) & (c.sat < 0.35) & (y > -2.62) & (y < -1.75) & (np.abs(x - an[0]) < 0.75) & (z > -0.55) & (z < 0.75)
            add(side + "UpperLeg", blk & (y > -2.0))
            add(side + "LowerLeg", blk & (y <= -2.0))
            add(side + "LowerLeg", caps(c.p, (an[0], -2.5, an[2]), (an[0], -2.86, an[2]), 0.36))
            add(side + "Foot", (y < -2.92) & (np.abs(x - an[0]) < 0.8) & (z > -0.9) & (z < 0.8))
        for side, sh, el, wr, hand in (("Right", J.RSH, J.REL, J.RWR, J.RGRIP), ("Left", J.LSH, J.LEL, J.LWR, J.LHAND)):
            add(side + "UpperArm", caps(c.p, np.array(sh) + (0, -0.42, 0), el, 0.42))
            add(side + "LowerArm", caps(c.p, np.array(el) + (0, -0.1, 0), wr, 0.40))
            add(side + "Hand", ball(c.p, hand, 0.42) & (c.hue < 40) & (c.sat > 0.18) & (c.val > 0.34))
            add(side + "Mantle", (np.abs(x - sh[0]) < 0.62) & (y > 0.66) & (y < 1.56) & indigo & (np.sign(sh[0]) * x > abs(sh[0]) * 0.62))
        add("Head", (y > 1.68) & (np.abs(x + 0.12) < 0.72) & (z < 0.8))
        add("HairBack", pale(c) & (z > -0.32) & (y < 2.08) & (y > -0.1))
        add("Beard", pale(c) & (z < -0.30) & (np.abs(x + 0.12) < 0.34) & (y < 1.92) & (y > 0.8))
        add("Beads", J.beads(c))
        add("Weapon", J.weapon(c))
        add("RightHand", ball(c.p, J.RGRIP, 0.36) & (c.hue < 40) & (c.sat > 0.18) & (c.val > 0.34))
        return out

    LIMITS = {"Weapon": lambda c: P1.weapon(c) | ball(c.p, P1.RGRIP, 0.02), "Beads": lambda c: P1.beads(c),
              "RightHand": lambda c: ball(c.p, P1.RGRIP, 0.34) | ((c.hue < 40) & (c.sat > 0.18) & (c.val > 0.34) & ball(c.p, P1.RGRIP, 0.42)), "LeftHand": lambda c: ball(c.p, P1.LHAND, 0.62),
              "Beard": lambda c: pale(c) | (c.y > 1.5), "HairBack": lambda c: pale(c) | (c.y > 1.6)}

    @staticmethod
    def clean(lab, c, names):
        J, p = P1, c.p
        for side, sh, el, wr in (("Right", J.RSH, J.REL, J.RWR), ("Left", J.LSH, J.LEL, J.LWR)):
            n = unit(np.array(sh) - el) + unit(np.array(el) - wr)
            cut(lab, names, side + "UpperArm", side + "LowerArm", plane(p, el, n) > 0)
        cut(lab, names, "UpperTorso", "LowerTorso", c.y > 0.46)
        cut(lab, names, "RightUpperLeg", "RightLowerLeg", c.y > -2.0)
        cut(lab, names, "LeftUpperLeg", "LeftLowerLeg", c.y > -2.0)
        for bone in ("RobeBack", "RobeRight", "RobeLeft", "RobeInner", "RobeFront"):
            cut(lab, names, "LowerTorso", bone, c.y > -0.14)
        cut(lab, names, "RobeBack", "RobeRight", c.z > 0.15, c.x > -0.09)
        cut(lab, names, "RobeBack", "RobeLeft", c.z > 0.15, c.x <= -0.09)
        return lab


class P2:
    """Demonic Chimera. Same glaive and fist; horns, torn robes, claw; two bead masses float off the right hip."""
    PELVIS, WAIST, NECK = (-0.03, -0.25, -0.05), (-0.03, 0.30, -0.05), (0.00, 1.35, -0.20)
    RSH, REL, RWR, RGRIP = (0.74, 1.08, 0.00), (1.09, 0.40, -0.10), (1.09, -0.20, -0.28), (1.09, -0.39, -0.35)
    LSH, LEL, LWR, LHAND = (-0.80, 1.08, 0.00), (-1.05, 0.18, -0.13), (-1.18, -0.39, -0.42), (-1.28, -0.71, -0.50)
    RHIP, RKN, RAN = (0.25, -0.55, -0.05), (0.72, -1.72, 0.10), (1.00, -2.79, 0.19)
    LHIP, LKN, LAN = (-0.38, -0.55, -0.05), (-0.62, -1.72, 0.10), (-0.80, -2.79, 0.19)
    BUTT, SOCKET = (2.12, 1.32, 1.06), (0.68, -1.00, -1.09)
    NAMES = ["Head", "UpperTorso", "LowerTorso", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
             "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
             "HairBack", "Beard", "Bead1", "Bead2", "Bead3", "LeftSleeve", "RibbonRight", "RibbonLeft", "RobeBack", "RobeRight", "RobeLeft", "RobeFront", "Weapon"]
    DEFAULT = "UpperTorso"
    KEEP = ("Bead1", "Bead2", "Bead3", "Weapon", "RibbonRight", "RibbonLeft")

    @staticmethod
    def weapon(c):
        d = haft_dist(c, P2.BUTT, P2.SOCKET)
        t, line = along(c.p, P2.BUTT, P2.SOCKET)
        butt_cap = (t > -0.09) & (t < 0.13) & (line < 0.25)
        haft = (t > -0.09) & (t < 1.0) & (d < 0.135)
        collar = (t >= 0.84) & (t < 1.2) & (line < 0.5) & (c.z < -0.82)
        blade = (c.z < -1.22) & (c.y < -0.8)
        return haft | butt_cap | collar | blade

    @staticmethod
    def bead_tone(c):
        return (c.val < 0.42) & (c.hue < 40) & (c.sat > 0.4) & (c.x > 1.05) & (c.y > -0.5) & (c.y < 0.65) & (c.z > 0.05)

    @staticmethod
    def seeds(c):
        x, y, z, J = c.x, c.y, c.z, P2
        out = []
        add = lambda b, m: out.append((b, m))
        indigo = (c.hue > 200) & (c.hue < 275) & (c.sat > 0.18)
        ivory = (c.hue > 15) & (c.hue < 60) & (c.sat < 0.36) & (c.val > 0.45)
        red = ((c.hue < 25) | (c.hue > 340)) & (c.sat > 0.45)
        add("UpperTorso", (np.abs(x + 0.03) < 0.62) & (y > 0.45) & (y < 1.25) & (np.abs(z + 0.1) < 0.5))
        add("LowerTorso", (np.abs(x + 0.03) < 0.72) & (y > -0.12) & (y < 0.36) & (np.abs(z + 0.05) < 0.62))
        skirt = y < -0.14
        add("RobeBack", skirt & (z > 0.15) & indigo)
        add("RobeFront", skirt & (z <= 0.15) & indigo & (x > -0.78) & (x < 0.38))
        add("RobeRight", skirt & ivory & (x >= -0.2))
        add("RobeRight", skirt & indigo & (z <= 0.15) & (x >= 0.38))
        add("RobeLeft", skirt & ivory & (x < -0.2))
        add("RobeLeft", skirt & indigo & (z <= 0.15) & (x <= -0.78))
        for side, hip, kn, an in (("Right", J.RHIP, J.RKN, J.RAN), ("Left", J.LHIP, J.LKN, J.LAN)):
            add(side + "UpperLeg", (c.val < 0.2) & (c.sat < 0.45) & (y > -2.2) & (y < -1.1) & (np.abs(x - kn[0]) < 0.62) & (z > -0.5) & (z < 0.65))
            add(side + "LowerLeg", caps(c.p, (an[0], -2.28, an[2]), (an[0], -2.76, an[2]), 0.40) & (((c.hue < 25) | (c.hue > 340)) | (c.val < 0.3)) & ~ivory)
            add(side + "Foot", (y < -2.86) & (np.abs(x - an[0]) < 0.8) & (z > -1.0) & (z < 0.8))
        for side, sh, el, wr, hand in (("Right", J.RSH, J.REL, J.RWR, J.RGRIP), ("Left", J.LSH, J.LEL, J.LWR, J.LHAND)):
            add(side + "UpperArm", caps(c.p, np.array(sh) + (0, -0.2, 0), el, 0.40))
            add(side + "LowerArm", caps(c.p, np.array(el) + (0, -0.08, 0), wr, 0.38))
            add(side + "Hand", ball(c.p, hand, 0.30))
        add("LeftSleeve", ivory & (x < -0.82) & (y < 0.62) & (y > -0.65))
        add("RibbonRight", red & (x > 0.72) & (x < 1.72) & (y < -0.32) & (y > -0.95) & (z > -0.1) & (np.linalg.norm(c.p - np.array(J.RGRIP), axis=1) > 0.32))
        add("RibbonLeft", red & (x < -1.28) & (y < 0.05) & (y > -0.75))
        add("HairBack", pale(c) & ((y > 1.40) | (z > 0.0)) & (y > 1.05))
        add("Beard", pale(c) & (y <= 1.40) & (z <= 0.0) & (y > 0.75))
        face = (np.abs(x) < 0.42) & (y > 1.40) & (y < 2.08) & (z < -0.22)
        horn = red & (np.abs(x) < 0.62) & (y > 1.72) & (z < 0.1)
        add("Head", face | horn)
        tone = J.bead_tone(c)
        add("Bead1", tone & ball(c.p, (1.68, 0.15, 0.40), 0.45))
        add("Bead2", tone & ball(c.p, (1.26, -0.10, 0.23), 0.40) & (c.val > 0.14))
        add("Weapon", J.weapon(c))
        add("RightHand", ball(c.p, J.RGRIP, 0.30) & (haft_dist(c, J.BUTT, J.SOCKET) > 0.135))
        return out

    LIMITS = {"Weapon": lambda c: P2.weapon(c), "Bead1": lambda c: P2.bead_tone(c), "Bead2": lambda c: P2.bead_tone(c),
              "RibbonRight": lambda c: ((c.hue < 25) | (c.hue > 340)) & (c.sat > 0.35) & (c.y < -0.25), "RibbonLeft": lambda c: ((c.hue < 25) | (c.hue > 340)) & (c.sat > 0.35) & (c.x < -1.26) & (c.y < 0.1) & (c.y > -0.8),
              "RightHand": lambda c: ball(c.p, P2.RGRIP, 0.42) & (c.x > 0.82), "LeftHand": lambda c: ball(c.p, P2.LHAND, 0.6),
              "RightLowerArm": lambda c: caps(c.p, P2.REL, P2.RWR, 0.56) & (c.x > 0.8) & (c.y > -0.32), "LowerTorso": lambda c: (c.x < 0.92) | (c.y < -0.1),
              "Beard": lambda c: pale(c) | (c.y > 1.3), "HairBack": lambda c: pale(c) | (c.y > 1.5)}

    @staticmethod
    def clean(lab, c, names):
        J, p = P2, c.p
        for side, sh, el, wr in (("Right", J.RSH, J.REL, J.RWR), ("Left", J.LSH, J.LEL, J.LWR)):
            n = unit(np.array(sh) - el) + unit(np.array(el) - wr)
            cut(lab, names, side + "UpperArm", side + "LowerArm", plane(p, el, n) > 0)
        cut(lab, names, "UpperTorso", "LowerTorso", c.y > 0.38)
        cut(lab, names, "RightUpperLeg", "RightLowerLeg", c.y > -1.72)
        cut(lab, names, "LeftUpperLeg", "LeftLowerLeg", c.y > -1.72)
        # the larger bead mass is two beads and a shed fragment: split at the waist between them, so each can drift on its own
        m = lab == names.index("Bead1")
        if m.any():
            q = p[m] - p[m].mean(0)
            axis = np.linalg.svd(q, full_matrices=False)[2][0]
            lab[np.nonzero(m)[0][q @ axis > 0]] = names.index("Bead3")
        # the strand trailing from the middle bead is the ribbon's, not the sphere's
        m = lab == names.index("Bead2")
        if m.any():
            lab[np.nonzero(m)[0][np.linalg.norm(p[m] - np.median(p[m], axis=0), axis=1) > 0.30]] = names.index("RibbonRight")
        for bone in ("RobeBack", "RobeRight", "RobeLeft", "RobeFront"):
            cut(lab, names, "LowerTorso", bone, c.y > -0.14)
        cut(lab, names, "RobeBack", "RobeRight", c.z > 0.15, c.x > -0.2)
        cut(lab, names, "RobeBack", "RobeLeft", c.z > 0.15, c.x <= -0.2)
        return lab


PHASES = {1: P1, 2: P2}
