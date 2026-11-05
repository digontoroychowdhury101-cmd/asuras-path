"""Grandmaster Shen's clip library on both supplied sculpts (shen_lib.py). The guandao is the weapon he was modelled with: both hands hold it, right hand behind on the haft, left hand leading, and he cuts with his whole body.

Gait follows human walking and running measurements: stance about 62% of a walk and 36% of a run; the heel strikes first, the foot is flat by 10% of the cycle, the heel lifts near 40%, the toes leave at 62%; the foot is highest early in the swing and passes the
standing leg low; the stance knee stays nearly straight except for a soft dip after the strike; the pelvis comes from the stance leg, so it is highest over the planted foot and lowest in double support.
Phase 1 is unsettling control. Phase 2 is the same technique corrupted (Clip.corrupt): wound further, and he floats, so his legs hang and cloth does the travelling.
Timing comes from BossAttackCatalog (windups, pulses) and WeaponSchema via the boss-shared Guandao contacts. Contact = the server's first active frame or impact.
"""
import math

import numpy as np

import shen_lib as L
from shen_lib import Clip, check_rigs, validate, write_rbxmx  # noqa: F401  (export.py takes these from the set's module)

RIGS = {1: L.Rig(1), 2: L.Rig(2)}
REVEAL = 0.9      # WorldDefinitions Transition.Reveal: the phase 1 clip reaches the handoff pose here and holds; phase 2 starts from it
HOVER = 1.25      # rig studs his feet float in phase 2
MELEE = {  # Rules.Contacts: the boss-shared Guandao times. (length, contact, active, arc, reach, lunge)
    "Guandao_L1": (0.4, 0.15, 0.067, 120, 10.5, 1.0), "Guandao_L2": (0.4167, 0.15, 0.067, 120, 10.5, 1.0), "Guandao_L3": (0.5167, 0.183, 0.067, 30, 11.0, 2.0),
    "Guandao_Heavy": (0.8333, 0.383, 0.067, 160, 12.0, 2.0), "Guandao_Running": (0.6, 0.217, 0.083, 15, 12.5, 8.0), "Guandao_Art": (0.9, 0.317, 0.2, 360, 11.5, 1.5),
}


def H(yaw, pitch=0.0):
    y, p = math.radians(yaw), math.radians(pitch)
    return (math.sin(y) * math.cos(p), math.sin(p), -math.cos(y) * math.cos(p))


def E(haft, hint=(0, -1, 0)):
    """The cutting edge: the hint's direction, square to the haft."""
    return tuple(L.orth(np.array(hint, float), L.unit(np.array(haft, float))))


def K(t, ease="io", **kw):
    return (t, kw, ease)


def curve(points, u):
    """Smooth through (u, value) pairs."""
    pts = points
    if u <= pts[0][0]:
        return pts[0][1]
    for (a, x), (b, y) in zip(pts, pts[1:]):
        if u <= b:
            return x + (y - x) * L.smooth01((u - a) / (b - a))
    return pts[-1][1]


# ---------------------------------------------------------------- planes a blade can cut in, seen by him: where it comes from
FROM_HIGH_LEFT = (-0.72, 0.7, 0.0)      # kesa: his left shoulder down through to his right hip
FROM_HIGH_RIGHT = (0.72, 0.7, 0.0)      # the return: right shoulder to left hip
FROM_LOW_LEFT = (-0.75, -0.66, 0.0)     # rising: left hip up through his right shoulder
FROM_LOW_RIGHT = (0.75, -0.66, 0.0)
FROM_OVERHEAD = (0.0, 1.0, 0.15)
FROM_LEFT = (-1.0, 0.0, 0.2)            # a flat wheel
FROM_RIGHT = (1.0, 0.0, 0.2)


GUARD = {}     # the guard this phase stands in; a first cut grows out of it


def arc(t0, tc, t1, th0, th1, source, aim=(0.0, -6.0), centre=(0.32, 0.22, -1.2), span=1.2, rsl=-1.8, whip=2.2, settle=2.4, hover=0.0):
    """One curved cut on a tilted plane. The blade rotates from th0 degrees upstream through the aim at tc (the contact) to th1 downstream; the hands travel on a matching small arc, right hand behind and left hand leading, so the two arms lever the haft.
    Returns a key per frame: the blade's path is the point of the move, so nothing is left to spline between poses."""
    F = np.array(H(*aim))
    A = L.orth(np.array(source, float), F)
    Cn = np.array(centre, float)
    Y = np.array([0, 1.0, 0])

    def line(th):
        """The haft's direction at th degrees. Far upstream a blade cannot go straight behind him, the fists would turn backwards: it climbs over the shoulder as the hands rise to it."""
        a = math.radians(th)
        over = max(0.0, (th - 100.0) / 80.0)
        d = math.cos(a) * F + math.sin(a) * A + Y * over * 1.1
        return d / np.linalg.norm(d), over

    n0 = max(int(round((tc - t0) * 30)), 1)
    n1 = max(int(round((t1 - tc) * 30)), 1)
    times = [t0 + (tc - t0) * i / n0 for i in range(n0)] + [tc + (t1 - tc) * i / n1 for i in range(n1 + 1)]
    out = []
    for t in times:
        if t <= tc:
            u = (t - t0) / max(tc - t0, 1e-6)
            th = th0 * (1 - u ** whip)
        else:
            v = (t - tc) / max(t1 - tc, 1e-6)
            th = -th1 * (1 - (1 - v) ** settle)
        a = math.radians(th)
        d, over = line(th)
        motion = line(th - 1.0)[0] - line(th + 1.0)[0]
        sweep = math.sin(min(max(a, -math.pi / 2), math.pi / 2))
        C = Cn + A * (0.7 * sweep) + np.array([0, 0.5 * over, 0.3 * (1 - math.cos(a)) * (1 - over) + 0.5 * over])
        rp = C - d * span / 2
        if t0 < 0.3:    # the first cut of a move grows out of the guard: the hands leave it and pick the blade's path up, they do not jump to it
            enter = max(0.1, 0.3 * (tc - t0))
            s = L.smooth01((t - t0) / enter)
            if s < 1.0:
                # the blade rises along its own plane as the hands pick it up, so the wrist never has to catch it up
                th = th * s
                a = math.radians(th)
                d, over = line(th)
                sweep = math.sin(min(max(a, -math.pi / 2), math.pi / 2))
                rp = Cn + A * (0.7 * sweep) + np.array([0, 0.5 * over, 0.3 * (1 - math.cos(a)) * (1 - over) + 0.5 * over]) - d * span / 2
                d0 = np.array(GUARD["haft"], float)
                d0 = d0 / np.linalg.norm(d0)
                d = (d0 + (d - d0) * s) / max(np.linalg.norm(d0 + (d - d0) * s), 1e-3)
                rp = np.array(GUARD["rp"], float) + (rp - np.array(GUARD["rp"], float)) * s
                motion = np.array(GUARD["face"], float) + (motion - np.array(GUARD["face"], float)) * s
                if abs(float(np.dot(d, motion))) > 0.98 * np.linalg.norm(motion):
                    motion = np.array(GUARD["face"], float)
                rsl_k, lsl_k = -1.8, 1.15 + (span - 1.15) * s
                out.append(K(t, "lin", rp=tuple(rp), haft=tuple(d), face=tuple(motion), rsl=rsl_k + (rsl - rsl_k) * s, lsl=lsl_k, lhw=1.0))
                continue
        out.append(K(t, "lin", rp=tuple(rp), haft=tuple(d), face=tuple(motion), rsl=rsl, lsl=span, lhw=1.0))
    return out


def build(phase):
    rg = RIGS[phase]
    P = "GrandmasterShen_P%d_" % phase
    floating = phase == 2
    H0 = HOVER if floating else 0.0

    def clip(name, length, keys, **kw):
        if floating and "hov" not in {k for key in keys for k in key[1]}:
            kw.setdefault("hover", H0)
            kw.setdefault("airborne", True)
            kw.setdefault("authored_feet", True)
        return Clip(rg, P + name, length, keys, **kw)

    # ---------------------------------------------------------------- the guard every move leaves from and returns to: left foot and left hand leading, rear foot turned out, blade low and forward
    RHAFT = H(-14, -15)
    FEET_R = (0.2, 0.44, 0, -24, 0)
    FEET_L = (0.0, -0.4, 0, 2, 0)
    READY = dict(pel=(0.02, -0.07, 0.02), pelR=(3, -16, 0), chest=(2, -9, 0), neck=(-1, 24, 0), rf=FEET_R, lf=FEET_L, lua=(0, 0, 0), lfa=(0, 0, 0), lha=(0, 0, 0), lhw=1.0, ltw=0.0, rsl=-1.8, lsl=1.15,
                 rp=(0.52, -0.02, 0.0), haft=RHAFT, face=E(RHAFT), relb=(0.75, -0.55, 0.35), lelb=(-0.6, -0.75, 0.25), rknee=(0.12, 0, -1.0), lknee=(-0.05, 0, -1.0), rlk=0.0)
    GUARD.update(READY)

    def melee(name, keys, notes, feet_free=(), **kw):
        length, contact, active, arc_, reach, lunge = MELEE[name]
        return clip(name, length, keys, contacts=[contact], move=name, notes=notes, active=(contact, active, arc_, reach, lunge), feet_free=feet_free, **kw)

    def body(t, ease="io", yaw=0.0, chest=None, pitch=4.0, roll=0.0, sink=-0.1, fwd=0.0, side=0.0, look=None, **kw):
        ch = yaw * 0.7 if chest is None else chest
        return K(t, ease, pel=(side, sink, 0.02 + fwd), pelR=(pitch, yaw, roll), chest=(pitch * 0.8, ch, -roll * 0.5), neck=(-pitch * 1.3, -(yaw + ch) * (0.9 if look is None else look), roll * 0.2), **kw)

    # ---------------------------------------------------------------- ordinary swings: 0.15 s to the contact, so they start from the guard's own blade line
    def crescent_reap():
        return melee("Guandao_L1", [K(0, **READY), body(0.07, "out", yaw=12, chest=20, sink=-0.14, fwd=0.04), body(0.15, "whip", yaw=-8, chest=-16, sink=-0.22, fwd=-0.38, lf=(0.0, -0.95, 0, 0, 0), rf=(0.16, 0.34, 0, -30, 0)),
                                    body(0.27, "out", yaw=-34, chest=-52, sink=-0.26, fwd=-0.46, roll=-3, lf=(0.0, -0.95, 0, 0, 0), rf=(0.14, 0.3, 0, -46, 0)), K(0.4, "io", **READY)]
                     + arc(0, 0.15, 0.3, 74, 84, FROM_HIGH_LEFT, aim=(2, -12)) + [K(0.4, "io", rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15)],
                     "Crescent Reap: left shoulder to right hip, hips driving first, the rear foot pivoting behind them.", feet_free=[(0, 0.4)])

    def returning_tide():
        return melee("Guandao_L2", [K(0, **READY), body(0.07, "out", yaw=16, chest=24, sink=-0.26, fwd=0.02), body(0.15, "whip", yaw=-6, chest=-12, sink=-0.16, fwd=-0.3, rf=(0.1, -0.2, 0, -14, 0), lf=(0.02, -0.2, 0, 8, 0)),
                                    body(0.29, "out", yaw=-30, chest=-48, sink=-0.05, fwd=-0.38, pitch=-2, rf=(0.1, -0.2, 0, -30, 0), lf=(0.02, -0.2, 0, 8, 0)), K(0.4167, "io", **READY)]
                     + arc(0, 0.15, 0.3, 66, 98, FROM_LOW_LEFT, aim=(2, 0)) + [K(0.4167, "io", rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15)],
                     "Returning Tide: the blade drops to his left hip and climbs through to the right shoulder off the rear foot's step.", feet_free=[(0, 0.4167)])

    def heaven_cleave():
        return melee("Guandao_L3", [K(0, **READY), body(0.09, "out", yaw=4, chest=6, pitch=-6, sink=-0.03, fwd=0.1), body(0.183, "whip", yaw=-10, chest=-14, pitch=12, sink=-0.32, fwd=-0.5, lf=(0.0, -1.05, 0, 0, 0), rf=(0.16, 0.3, 0, -28, 0)),
                                    body(0.33, "out", yaw=-12, chest=-16, pitch=18, sink=-0.42, fwd=-0.58, lf=(0.0, -1.05, 0, 0, 0), rf=(0.16, 0.3, 0, -28, 0)), K(0.5167, "io", **READY)]
                     + arc(0, 0.183, 0.33, 118, 46, FROM_OVERHEAD, aim=(0, -10), centre=(0.2, 0.34, -1.25)) + [K(0.5167, "io", rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15)],
                     "Heaven-Splitting Cleave: up over the head and straight down the server's line, a long step under it.", feet_free=[(0, 0.5167)])

    def green_dragon():
        return melee("Guandao_Heavy", [K(0, **READY), body(0.14, "io", yaw=26, chest=38, sink=-0.16, fwd=0.1), body(0.31, "io", yaw=42, chest=58, sink=-0.2, fwd=0.16, pitch=-2, rf=(0.2, 0.5, 0, -6, 0)),
                                       body(0.383, "whip", yaw=4, chest=-4, sink=-0.3, fwd=-0.5, pitch=9, lf=(0.0, -1.15, 0, -2, 0), rf=(0.16, 0.34, 0, -32, 0)),
                                       body(0.56, "out", yaw=-46, chest=-70, sink=-0.36, fwd=-0.62, pitch=11, roll=-4, lf=(0.0, -1.15, 0, -2, 0), rf=(0.12, 0.26, 0, -62, 0)), K(0.8333, "io", **READY)]
                     + arc(0.06, 0.416, 0.6, 130, 110, (-0.92, 0.38, 0.0), aim=(0, -14), whip=3.4, settle=4.4) + [K(0.8333, "io", rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15)],
                     "Green Dragon Reaping: winds until his back shows, then hips, chest and arms unwind in that order, and the blade carries his weight past the target.", feet_free=[(0, 0.8333)])

    def charging_cut():
        start = dict(READY, pel=(0, -0.12, -0.05), pelR=(12, -10, 0), chest=(8, -8, 0), neck=(-16, 16, 0), rf=(0.1, 0.5, 0.2, -6, -18), lf=(0.0, -0.3, 0, 2, 0))
        return melee("Guandao_Running", [K(0, "lin", **start), body(0.1, "out", yaw=14, chest=22, pitch=8, sink=-0.2, fwd=-0.2, rf=(0.14, 0.15, 0.12, -14, 0), lf=(0, -0.55, 0, 2, 0)),
                                         body(0.217, "whip", yaw=-8, chest=-18, pitch=10, sink=-0.26, fwd=-0.6, lf=(0, -1.2, 0, 0, 0), rf=(0.14, 0.42, 0, -28, 0)),
                                         body(0.36, "out", yaw=-30, chest=-46, pitch=7, sink=-0.26, fwd=-0.66, lf=(0, -1.2, 0, 0, 0), rf=(0.14, 0.05, 0.15, -18, 0)), K(0.6, "io", **READY)]
                     + arc(0, 0.217, 0.4, 92, 80, FROM_LOW_LEFT, aim=(0, -2)) + [K(0.6, "io", rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15)],
                     "Charging Crescent: out of the run the blade rises from his left hip across the server's lunge, and the run carries into the step.", feet_free=[(0, 0.6)])

    def cyclone():
        def spin(a):
            d = {}
            for side, key, base in (("Right", "rf", FEET_R), ("Left", "lf", FEET_L)):
                at = rg.LEGS[side]["ankle"] + np.array([base[0], 0, base[1]])
                q = L.ry(math.radians(a)) @ at - rg.LEGS[side]["ankle"]
                d[key] = (float(q[0]), float(q[2]), 0, base[3] + a, 0)
            return d
        turn = [(0, 0.0), (0.2, -62.0), (0.317, 8.0), (0.46, 120.0), (0.62, 250.0), (0.76, 345.0), (0.9, 360.0)]
        keys = []
        for i in range(28):
            t = i / 27 * 0.9
            a = curve(turn, t) if t >= 0.2 else -62.0 * L.smooth01(t / 0.2)
            y = a + 8.0      # he turns to his right, the blade at the end of both arms ahead of his chest all the way round
            haft = H(y, -6)
            r = np.array(H(y)) * 0.95
            settle = L.smooth01((t - 0.74) / 0.16)
            k = dict(pel=(0, -0.3 * (1 - settle) - 0.07 * settle, -0.1 * (1 - settle)), pelR=(6 - 3 * settle, -a - 16, 0), chest=(5 - 3 * settle, -14 + 5 * settle, 0), neck=(-4 + 3 * settle, 18 + 6 * settle, 0),
                     rp=(r[0] - haft[0] * 0.6, 0.2 - haft[1] * 0.6, r[2] - haft[2] * 0.6), haft=haft, face=E(haft, H(y + 90)), lhw=1.0, lsl=1.15, rsl=-1.8, relb=READY["relb"], lelb=READY["lelb"], rknee=READY["rknee"], lknee=READY["lknee"], **spin(-a))
            keys.append(K(t, "lin", **k))
        return melee("Guandao_Art", keys, "Crescent Moon Cyclone: he winds left, then the whole body pivots right on the balls of the feet with the blade at the end of both arms; the server's 360 degree blow.", feet_free=[(0, 0.9)], authored_feet=True)

    def strike():
        return clip("Strike", 1.1, [K(0, **READY), body(0.3, "io", yaw=10, chest=16, pitch=-6, sink=-0.05, fwd=0.1), body(0.5, "whip", yaw=-12, chest=-20, pitch=12, sink=-0.3, fwd=-0.45, lf=(0, -0.95, 0, 0, 0), rf=(0.16, 0.34, 0, -28, 0)),
                                    body(0.72, "out", yaw=-24, chest=-34, pitch=14, sink=-0.32, fwd=-0.5, lf=(0, -0.95, 0, 0, 0), rf=(0.16, 0.34, 0, -32, 0)), K(1.1, "io", **READY)]
                    + arc(0.1, 0.5, 0.74, 118, 66, FROM_HIGH_LEFT, aim=(0, -8)) + [K(1.1, "io", rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15)],
                    contacts=[0.5], move="Strike", notes="Fallback diagonal cut for any move without its own slot.", feet_free=[(0, 1.1)])

    # ---------------------------------------------------------------- signature attacks
    def flowing_glaive():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15)
        return clip("FlowingJian", 3.5, [
            K(0, **READY),
            body(0.55, "io", yaw=30, chest=46, sink=-0.12, fwd=0.08, rf=(0.2, 0.5, 0, -14, 0)),
            body(0.8, "whip", yaw=-12, chest=-20, pitch=8, sink=-0.28, fwd=-0.42, lf=(0, -0.9, 0, 0, 0), rf=(0.16, 0.36, 0, -30, 0)),
            body(1.2, "io", yaw=28, chest=38, pitch=6, sink=-0.22, fwd=-0.44, lf=(0, -0.9, 0, 4, 0), rf=(0.16, 0.2, 0, -18, 0)),
            body(1.45, "whip", yaw=26, chest=34, pitch=8, sink=-0.3, fwd=-0.7, rf=(0.2, -0.3, 0, -8, 0), lf=(0, 0.1, 0, 10, 0)),
            body(1.85, "io", yaw=18, chest=28, pitch=5, sink=-0.32, fwd=-0.78, rf=(0.2, -0.3, 0, -8, 0), lf=(0, 0.1, 0, 10, 0)),
            body(2.1, "whip", yaw=-16, chest=-30, pitch=-1, sink=-0.12, fwd=-0.92, lf=(0, -0.9, 0, 0, 0), rf=(0.16, 0.36, 0, -26, 0)),
            body(2.5, "io", yaw=-2, chest=2, pitch=-8, sink=-0.05, fwd=-0.9, lf=(0, -0.9, 0, 0, 0), rf=(0.16, 0.36, 0, -26, 0)),
            body(2.75, "whip", yaw=-8, chest=-14, pitch=16, sink=-0.42, fwd=-1.1, lf=(0, -1.05, 0, 0, 0), rf=(0.16, 0.2, 0, -28, 0)),
            body(3.0, "out", yaw=-10, chest=-16, pitch=18, sink=-0.44, fwd=-1.12, lf=(0, -1.05, 0, 0, 0), rf=(0.16, 0.2, 0, -28, 0)),
            K(3.5, "io", **READY),
        ] + arc(0.24, 0.8, 1.02, 135, 72, FROM_HIGH_LEFT, aim=(2, -8), whip=2.6) + arc(1.2, 1.45, 1.66, 90, 74, FROM_HIGH_RIGHT, aim=(-4, -6), whip=1.8) + arc(1.84, 2.1, 2.3, 96, 80, FROM_LOW_LEFT, aim=(0, 2), whip=1.8, centre=(0.32, 0.5, -1.2))
          + arc(2.48, 2.75, 3.0, 126, 40, FROM_OVERHEAD, aim=(0, -10), whip=2.0, centre=(0.2, 0.34, -1.25)) + [K(3.5, "io", **back)],
            contacts=[0.8, 1.45, 2.1, 2.75], move="FlowingJian", feet_free=[(0, 3.5)], notes="Flowing Glaive: four linked curved cuts on the server's deflect pulses: a falling diagonal, its mirror on the way back, a rising cut, and an overhead finish, each flowing out of the last in a figure eight. Stable id FlowingJian.")

    def hesitant_moon():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15)
        high = arc(0.1, 0.6, 0.6001, 150, 0, FROM_HIGH_RIGHT, aim=(-10, 18), whip=1.0)
        return clip("HesitantMoon", 2.15, [
            K(0, **READY),
            body(0.55, "io", yaw=-22, chest=-34, pitch=-4, sink=-0.1, fwd=0.1, rf=(0.2, 0.52, 0, -28, 0)),
            body(0.95, "lin", yaw=-24, chest=-38, pitch=-5, sink=-0.1, fwd=0.12, rf=(0.2, 0.52, 0, -28, 0)),
            body(1.3, "whip", yaw=-2, chest=-6, pitch=10, sink=-0.32, fwd=-0.48, lf=(0, -1.0, 0, 0, 0), rf=(0.16, 0.34, 0, -26, 0)),
            body(1.55, "out", yaw=28, chest=44, pitch=11, sink=-0.34, fwd=-0.54, lf=(0, -1.0, 0, 8, 0), rf=(0.16, 0.2, 0, -14, 0)),
            K(2.15, "io", **READY),
        ] + arc(0.1, 0.6, 0.62, 130, 0, FROM_HIGH_RIGHT, aim=(-14, 44), whip=1.2, settle=1.0)[:-1]
          + [K(0.95, "lin", rp=(0.62, 1.0, -0.95), haft=H(-30, 62), face=E(H(-30, 62), (-1, -0.2, -0.5)), rsl=-1.8, lsl=1.15, lhw=1.0)]
          + arc(1.0, 1.3, 1.55, 78, 80, FROM_HIGH_RIGHT, aim=(-2, -8), whip=3.0) + [K(2.15, "io", **back)],
            contacts=[1.3], move="HesitantMoon", feet_free=[(0, 2.15)], notes="Hesitant Moon: the blade rises and hangs at the top of the cut longer than it should, so a deflect pressed at the expected moment is too early; then it falls from his right shoulder across his body.")

    def wheel_of_heaven():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15)
        keys = [K(0, **READY), body(0.3, "io", yaw=-6, chest=-10, pitch=-2, sink=-0.08, fwd=0.0, lf=(0, -0.4, 0, 0, 0))]
        # the pinwheel: the haft turns on the fingers of the right hand in the plane beside him; the left hand lets go and is back before the cut
        for i in range(25):
            t = 0.1 + i * (0.9 - 0.1) / 24
            a = 270 + i / 24 * 870     # it starts from the guard's line and ends where the catch and the cut begin
            d = L.unit(np.array([0.32, math.cos(math.radians(a)), math.sin(math.radians(a))]))
            keys.append(K(t, "lin", rp=(0.95, 0.5, -0.55), rsl=-0.1, haft=tuple(d), face=E(d, (0.2, -math.sin(math.radians(a)), math.cos(math.radians(a)))), rlk=1.0, rhx=H(-20, 30)))
        keys += [K(0.08, "io", lhw=1.0), K(0.18, "out", lhw=0.0, lua=(-20, 0, -6), lfa=(-50, 0, 0), lha=(0, 0, 0)), K(0.84, "io", lhw=0.0), K(1.02, "in", lhw=1.0), K(0.92, "lin", rlk=1.0), K(1.0, "lin", rlk=0.0, rsl=-1.8)]
        keys += [body(1.0, "io", yaw=30, chest=48, pitch=-2, sink=-0.12, fwd=0.05), body(1.35, "whip", yaw=-10, chest=-20, pitch=9, sink=-0.3, fwd=-0.46, lf=(0, -1.0, 0, 0, 0), rf=(0.16, 0.34, 0, -30, 0)),
                 body(1.73, "whip", yaw=26, chest=40, pitch=6, sink=-0.3, fwd=-0.7, rf=(0.2, -0.3, 0, -8, 0), lf=(0, -0.1, 0, 10, 0)), body(2.0, "out", yaw=34, chest=52, pitch=5, sink=-0.3, fwd=-0.72, rf=(0.2, -0.3, 0, -8, 0), lf=(0, -0.1, 0, 10, 0)), K(2.6, "io", **READY)]
        keys += arc(1.0, 1.35, 1.5, 120, 62, FROM_HIGH_LEFT, aim=(2, -6), whip=2.4) + arc(1.53, 1.73, 2.0, 60, 80, FROM_LOW_RIGHT, aim=(-4, 2), whip=1.6) + [K(2.6, "io", **back)]
        return clip("WheelOfHeaven", 2.6, keys, contacts=[1.35, 1.73], move="WheelOfHeaven", feet_free=[(0, 2.6)], notes="Wheel of Heaven: two full pinwheels of the glaive beside him, then the left hand catches it and two cuts come close together, a falling diagonal and a rising return.")

    def flourish():
        keys = [K(0, **READY), body(0.3, "io", yaw=-8, chest=-12, pitch=0, sink=-0.05, lf=(0, -0.42, 0, 0, 0)), body(1.0, "io", yaw=-4, chest=-6, pitch=0, sink=-0.05, lf=(0, -0.42, 0, 0, 0)), K(1.6, "io", **READY)]
        for i in range(33):
            t = 0.12 + i * (1.2 - 0.12) / 32
            a = 200 + i / 32 * 1080
            d = L.unit(np.array([0.3, math.cos(math.radians(a)), math.sin(math.radians(a))]))
            keys.append(K(t, "lin", rp=(0.95, 0.45, -0.5), rsl=-0.1, haft=tuple(d), face=E(d, (0.2, -math.sin(math.radians(a)), math.cos(math.radians(a)))), rlk=1.0, rhx=H(-20, 30)))
        keys += [K(0.1, "io", lhw=1.0), K(0.22, "out", lhw=0.0, lua=(-16, 0, -6), lfa=(-44, 0, 0), lha=(0, 0, 0)), K(1.14, "io", lhw=0.0), K(1.32, "in", lhw=1.0), K(1.22, "lin", rlk=1.0, rsl=-0.1), K(1.34, "lin", rlk=0.0, rsl=-1.8),
                 K(1.6, "io", rp=READY["rp"], haft=READY["haft"], face=READY["face"], lsl=1.15)]
        return clip("Flourish", 1.6, keys, contacts=[0.6], feet_free=[(0, 1.6)], notes="Three unhurried pinwheels of the glaive, caught back into both hands; plays between exchanges so the pause is never the same twice.")

    def feint():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15)
        return clip("Feint", 1.05, [K(0, **READY),
                                    body(0.32, "io", yaw=28, chest=44, sink=-0.14, fwd=0.04, rf=(0.2, 0.5, 0, -12, 0)),
                                    body(0.52, "out", yaw=10, chest=8, pitch=9, sink=-0.26, fwd=-0.28, lf=(0, -0.72, 0, 0, 0), rf=(0.16, 0.4, 0, -26, 0)),
                                    body(0.72, "io", yaw=-10, chest=-6, pitch=3, sink=-0.1, fwd=0.05, lf=(0, -0.4, 0, 2, 0)), K(1.05, "io", **READY)]
                    + arc(0.04, 0.52, 0.52001, 150, 0, FROM_HIGH_LEFT, aim=(-10, 26), whip=1.6, settle=1.0, centre=(0.4, 0.3, -1.45))[:-1] + [K(1.05, "io", **back)],
                    contacts=[0.52], feet_free=[(0, 1.05)], notes="A cut that never comes: the whole body commits, the blade stops short at the top and he settles back. No warning is shown, because nothing is thrown.")

    def prayer_beads():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15)
        keys = [K(0, **READY), body(0.4, "io", yaw=-8, chest=-12, pitch=-2, sink=-0.06), body(0.9, "io", yaw=22, chest=34, pitch=-4, sink=-0.08, fwd=0.08), body(1.1, "whip", yaw=-10, chest=-18, pitch=8, sink=-0.26, fwd=-0.36, lf=(0, -0.85, 0, 0, 0), rf=(0.16, 0.36, 0, -28, 0)),
                body(1.4, "out", yaw=-24, chest=-40, pitch=8, sink=-0.28, fwd=-0.42, lf=(0, -0.85, 0, 0, 0), rf=(0.16, 0.36, 0, -36, 0)), K(2.1, "io", **READY)]
        for i in range(15):
            t = 0.1 + i * 0.5 / 14
            a = 200 + i / 14 * 540
            d = L.unit(np.array([0.3, math.cos(math.radians(a)), math.sin(math.radians(a))]))
            keys.append(K(t, "lin", rp=(0.95, 0.5, -0.5), rsl=-0.1, haft=tuple(d), face=E(d, (0.2, -math.sin(math.radians(a)), math.cos(math.radians(a)))), rlk=1.0, rhx=H(-20, 30)))
        keys += [K(0.08, "io", lhw=1.0), K(0.18, "out", lhw=0.0, lua=(-20, 0, -6), lfa=(-50, 0, 0), lha=(0, 0, 0)), K(0.56, "io", lhw=0.0), K(0.72, "in", lhw=1.0), K(0.62, "lin", rlk=1.0), K(0.74, "lin", rlk=0.0, rsl=-1.8)]
        keys += arc(0.74, 1.1, 1.42, 118, 80, FROM_HIGH_LEFT, aim=(0, 2), whip=2.4) + [K(2.1, "io", **back)]
        return clip("PrayerBeads", 2.1, keys, contacts=[1.1], move="PrayerBeads", feet_free=[(0, 2.1)], notes="The glaive pinwheels and gathers seven beads off his breath, the left hand catches it and the falling cut flings them on the server's release.")

    def abbot_sweep():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15)
        return clip("AbbotSweep", 1.95, [
            K(0, **READY),
            body(0.6, "io", yaw=36, chest=58, pitch=8, sink=-0.4, fwd=0.12, rf=(0.26, 0.5, 0, -10, 0)),
            body(0.88, "io", yaw=44, chest=66, pitch=10, sink=-0.48, fwd=0.14, rf=(0.26, 0.5, 0, -10, 0)),
            body(1.0, "whip", yaw=6, chest=2, pitch=14, sink=-0.58, fwd=-0.4, lf=(-0.06, -0.92, 0, 0, 0), rf=(0.2, 0.42, 0, -30, 0)),
            body(1.25, "out", yaw=-44, chest=-74, pitch=14, sink=-0.6, fwd=-0.46, lf=(-0.06, -0.92, 0, 0, 0), rf=(0.2, 0.4, 0, -60, 0)),
            K(1.95, "io", **READY),
        ] + arc(0.3, 1.0, 1.32, 118, 84, FROM_LEFT, aim=(0, -24), centre=(0.3, -0.2, -1.05), whip=3.2) + [K(1.95, "io", **back)],
            contacts=[1.0], move="AbbotSweep", feet_free=[(0, 1.95)], notes="Abbot's Sweep: the weight sinks into the hip, then a wide low wheel at shin height with a committed follow-through; jump it.")

    def blood_wave():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15)
        return clip("BloodWave", 2.15, [
            K(0, **READY),
            body(0.35, "io", yaw=30, chest=46, pitch=10, sink=-0.36, fwd=0.04),
            body(1.0, "in", yaw=4, chest=-4, pitch=14, sink=-0.44, fwd=-0.3, lf=(0, -0.7, 0, 0, 0)),
            body(1.1, "whip", yaw=-22, chest=-36, pitch=-2, sink=-0.1, fwd=-0.46, lf=(0, -0.7, 0, 0, 0), rf=(0.16, 0.38, 0, -36, 0)),
            body(1.45, "out", yaw=-26, chest=-44, pitch=-6, sink=-0.05, fwd=-0.48, lf=(0, -0.7, 0, 0, 0), rf=(0.16, 0.38, 0, -36, 0)),
            K(2.15, "io", **READY),
        ] + arc(0.2, 1.1, 1.45, 104, 84, FROM_LOW_LEFT, aim=(4, -10), centre=(0.3, -0.05, -1.05), whip=2.6) + [K(2.15, "io", **back)],
            contacts=[1.1], move="BloodWave", feet_free=[(0, 2.15)], scrape=True, notes="The glaive's edge drags from his left, the whole body hauling it, then whips up and casts the low wave on the server's start.")

    def rending_arc():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15)
        return clip("RendingArc", 2.6, [
            K(0, **READY),
            body(0.6, "io", yaw=30, chest=48, sink=-0.12, fwd=0.1),
            body(0.9, "whip", yaw=-14, chest=-26, pitch=12, sink=-0.3, fwd=-0.6, lf=(0, -0.8, 0, 0, 0)),
            body(1.32, "whip", yaw=16, chest=24, pitch=10, sink=-0.3, fwd=-0.9, rf=(0.1, -0.2, 0, 0, 0)),
            body(1.7, "io", yaw=-6, chest=-4, pitch=-6, sink=-0.05, fwd=-0.9, rf=(0.1, -0.2, 0, 0, 0)),
            body(1.95, "whip", yaw=-12, chest=-20, pitch=16, sink=-0.44, fwd=-1.2, lf=(0, -1.0, 0, 0, 0)),
            K(2.6, "io", **READY),
        ] + arc(0.24, 0.9, 1.04, 135, 74, FROM_HIGH_LEFT, aim=(2, -8), whip=2.4) + arc(1.16, 1.32, 1.46, 70, 70, FROM_HIGH_RIGHT, aim=(-4, -6), whip=1.5) + arc(1.7, 1.95, 2.15, 100, 40, FROM_OVERHEAD, aim=(0, -10), whip=3.0, centre=(0.2, 0.34, -1.25)) + [K(2.6, "io", **back)],
            contacts=[0.9, 1.32, 1.95], move="RendingArc", feet_free=[(0, 2.6)], notes="Rending Arc: three cuts in a broken rhythm, the third held back so the third deflect has to wait for it.")

    def phantom_drift():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15)
        return clip("PhantomDrift", 2.0, [
            K(0, **READY),
            K(0.55, "io", pel=(0.02, -0.02, 0.2), pelR=(-8, 26, -8), chest=(-6, 40, 6), neck=(8, -40, 0), rf=(0.2, 0.7, 0, 0, 0), lf=(0, 0.2, 0, 0, 0)),
            K(1.0, "whip", pel=(0, -0.2, -0.62), pelR=(26, -10, 0), chest=(14, -20, 0), neck=(-30, 26, 0), rf=(0.2, 1.0, 0, 0, 0), lf=(0, 0.65, 0, 0, 0)),
            K(1.3, "out", pel=(0, -0.2, -0.7), pelR=(22, -30, -4), chest=(12, -50, 4), neck=(-26, 44, 0), rf=(0.2, 1.0, 0, 0, 0), lf=(0, 0.65, 0, 0, 0)),
            K(2.0, "io", **READY),
        ] + arc(0.25, 1.0, 1.32, 125, 80, FROM_HIGH_LEFT, aim=(0, -14), whip=2.8) + [K(2.0, "io", **back)],
            contacts=[1.0], move="PhantomDrift", feet_free=[(0, 2.0)], notes="Phantom Drift: he leans back and hangs in the air, then glides through the server's lunge with his legs trailing and the blade falling across him.")

    def skyfall():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15)
        low = dict(rf=FEET_R, lf=FEET_L)
        return Clip(rg, P + "GuandaoSkyfall", 2.6, [
            K(0, hov=H0, **READY),
            body(0.3, "snap", yaw=20, chest=28, pitch=-6, sink=-0.2),
            K(0.45, "io", pel=(0, 0.1, 0.1), pelR=(-14, 8, 0), chest=(-18, 10, 0), neck=(14, -14, 0), rf=(0.1, 0.4, 0.5, 0, -30), lf=(0, 0.4, 0.75, 0, -40), hov=H0),
            K(1.2, "io", pel=(0, 0.06, 0.05), pelR=(-10, 2, 0), chest=(-14, 4, 0), neck=(6, -4, 0), rf=(0.1, 0.1, 0.4, 0, -20), lf=(0, 0.1, 0.5, 0, -20), hov=H0 * 0.7),
            K(1.5, "whip", pel=(0, -0.55, -0.4), pelR=(20, 0, 0), chest=(26, -6, 0), neck=(-20, 6, 0), rf=(0.2, 0.42, 0, -24, 0), lf=(0, -0.42, 0, 2, 0), hov=0.0),
            K(1.92, "out", pel=(0, -0.62, -0.38), pelR=(23, 0, 0), chest=(29, -6, 0), neck=(-16, 6, 0), hov=0.0),
            K(2.3, "io", pel=(0.02, -0.25, -0.1), pelR=(9, -6, 0), chest=(10, -6, 0), neck=(-6, 8, 0), **low, hov=H0 * 0.35),
            K(2.6, "io", **READY, hov=H0),
        ] + arc(0.1, 1.5, 1.92, 135, 46, FROM_OVERHEAD, aim=(0, -18), whip=4.5, centre=(0.2, 0.3, -1.08)) + [K(2.6, "io", **back)],
            contacts=[1.5], move="GuandaoSkyfall", scrape=True, airborne=True, feet_free=[(0, 2.6)], authored_feet=True, notes="Coils, the server's aerial path carries the root, glaive high at the apex, and the blade falls with him; his feet touch down and his knees absorb the landing at the impact, then he lifts again.")

    def crimson_embrace():
        back_w = dict(rp=(0.75, -0.2, 0.55), haft=H(75, -28), face=E(H(75, -28)), rsl=-0.2)
        return clip("CrimsonEmbrace", 2.4, [
            K(0, **READY),
            K(0.25, "io", lhw=1.0),
            K(0.5, "io", lhw=0.0, ltw=0.85, pel=(0, -0.05, 0.22), pelR=(-6, -18, 0), chest=(-10, -26, 0), neck=(4, 30, 0), lt=(-0.75, -0.2, 0.15), lelb=(-0.8, -0.1, 0.5), **back_w),
            K(0.98, "io", pel=(0.02, -0.1, 0.3), pelR=(-8, -20, 0), chest=(-13, -30, 0), neck=(6, 34, 0), lt=(-0.8, 0.0, 0.25)),
            K(1.2, "whip", pel=(0, -0.3, -1.1), pelR=(22, 12, 0), chest=(18, 26, 0), neck=(-18, -30, 0), ltw=1.0, lt=(0.5, 0.1, -1.46), lelb=(-0.5, -0.8, 0.1), rf=(0.2, 0.8, 0, 0, 0), lf=(0, 0.3, 0, 0, 0), rp=(1.0, -0.15, -0.55), haft=H(70, -26), face=E(H(70, -26))),
            K(1.4, "out", pel=(0, -0.32, -1.2), pelR=(24, 16, 0), chest=(20, 32, 0), neck=(-18, -36, 0), lt=(0.55, -0.15, -1.25), rp=(1.0, -0.2, -0.65), haft=H(70, -26), face=E(H(70, -26))),
            K(1.85, "io", pel=(0, -0.2, -0.65), pelR=(9, 0, 0), chest=(9, 0, 0), neck=(-8, 8, 0), ltw=0.0, lhw=1.0, rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=-1.8, lsl=1.15),
            K(2.4, "io", **READY),
        ], contacts=[1.2], move="CrimsonEmbrace", feet_free=[(0, 2.4)], notes="The one move where a hand leaves the haft: the clawed left arm reaches with the whole torso behind it while the glaive swings back in the right. Cosmetic only: nothing attaches to a player.")

    # ---------------------------------------------------------------- idle
    def idle():
        p1 = not floating
        length = 6.4 if p1 else 4.8
        breaths = 2 if p1 else 3
        n = int(length * 15)
        keys = []
        for i in range(n):
            t = i / n * length
            a = 2 * math.pi * t / length
            breath = (0.5 - 0.5 * math.cos(a * breaths)) ** (1.5 if p1 else 0.8)
            sway, sway2 = math.sin(a), math.sin(2 * a + 0.9)
            r0, h0 = np.array(READY["rp"]), np.array(READY["haft"])
            nod = L.rodrigues(np.array([1.0, 0, 0]) * math.radians(0.9 * math.sin(a * breaths)) + np.array([0, 1.0, 0]) * math.radians(1.1 * sway))
            hf = nod @ h0
            if p1:
                look = 4.0 * math.sin(a + 0.4) + 1.2 * math.sin(3 * a)
                k = dict(pel=(0.02 + 0.05 * sway, -0.07 - 0.016 * breath - 0.008 * sway2, 0.02 + 0.012 * sway2), pelR=(3 + 0.3 * sway2, -16 + 1.4 * sway, 1.1 * sway), chest=(2 - 1.2 * breath + 0.3 * sway2, -9 - 1.6 * sway, -1.4 * sway),
                         neck=(-1 + 0.8 * breath + 0.6 * math.sin(2 * a), 24 + look, 0.8 * sway), rp=tuple(r0 + np.array([0.015 * sway, 0.018 * breath, 0.01 * sway2])), haft=tuple(hf), face=E(hf))
            else:
                snap = sum(w * L.smooth01((t - at) / 0.11) for at, w in ((0.7, 12.0), (1.6, -18.0), (2.6, 10.0), (3.7, -4.0)))
                k = dict(pel=(0.02 + 0.08 * sway, -0.05 * breath, 0.04 * sway2), pelR=(4 + 1.2 * breath, -16 + 2.4 * sway, 2.2 * sway), chest=(4 - 3.0 * breath + 0.8 * sway2, -9 - 3.0 * sway, -2.4 * sway),
                         neck=(-4 + 2.4 * breath, 24 + snap + 1.5 * sway, 1.5 * math.sin(a + 0.6)), rp=tuple(r0 + np.array([0.03 * sway, 0.05 * breath, 0.02 * sway2])), haft=tuple(hf), face=E(hf))
            k.update(rf=FEET_R, lf=FEET_L, lhw=1.0, rsl=-1.8, lsl=1.15, relb=READY["relb"], lelb=READY["lelb"], rknee=READY["rknee"], lknee=READY["lknee"])
            keys.append((t, k, "lin"))
        return clip("Idle", length, keys, loop=True, priority="Idle", authored_feet=True, notes="The guard alive: both hands on the glaive, slow breath, weight drifting between the feet." if p1 else "He hangs in the air and cannot hold still: panting, head hunting in short snaps, the glaive drifting.")

    # ---------------------------------------------------------------- a human gait
    def gait(name, period, rate, beta, along=(0.0, -1.0), carry="low", reverse=False, run=False, lean=2.5, twist=5.0, drop=3.5, sway=0.07, centre=0.0, shuffle=0.0):
        """The feet first, on the measured phases; then the pelvis height that keeps the stance knee where a human's is; then the trunk, counter-rotating, with the head level. A stance foot moves at exactly the body's speed, so it never skates: rate = 2 * half stride / (beta * period)."""
        n = max(int(round(period * 30)), 16)
        half = rate * beta * period / 2
        ax, az = along

        heel = 8.0 if run else 18.0
        offp = -50.0 if run else -40.0

        def foot(tau, shift):
            tau %= 1.0
            if tau < beta:
                f = tau / beta
                coord = centre + half * (1 - 2 * f)
                if run:
                    pitch = heel * (1 - L.smooth01(f / 0.15)) + offp * L.smooth01((f - 0.35) / 0.65)
                else:
                    pitch = heel * (1 - L.smooth01(f / 0.17)) + offp * L.smooth01((f - 0.6) / 0.4)
                if ax != 0:
                    pitch *= 0.35
                up, fw = L.foot_roll(pitch)
                return coord + fw, max(up, 0.0), pitch, True
            u = (tau - beta) / (1 - beta)
            coord = centre + half * (2 * L.smooth01(u ** 0.72 if run else u) - 1)
            p0 = L.foot_roll(offp * (0.35 if ax else 1))
            if run:
                lift = curve([(0, p0[0]), (0.12, 0.6), (0.38, 1.05), (0.62, 0.72), (0.86, 0.22), (1, L.foot_roll(heel)[0])], u)
                pitch = curve([(0, offp), (0.3, -82), (0.55, -50), (0.82, -8), (1, heel)], u)
            else:
                lift = curve([(0, p0[0]), (0.28, 0.42), (0.58, 0.16), (0.82, 0.08), (1, L.foot_roll(heel)[0])], u)
                pitch = curve([(0, offp), (0.22, -48), (0.5, -16), (0.76, 3), (1, heel)], u)
            if ax != 0:
                lift *= 0.55
                pitch *= 0.35
            return coord + p0[1] * (1 - L.smooth01(u / 0.2)), lift, pitch, False

        stance_flex = ([(0, 22), (0.25, 40), (0.6, 30), (1, 20)] if run else [(0, 6), (0.22, 15), (0.55, 7), (0.85, 6), (1, 22)])
        rows = []
        for i in range(n):
            p = i / n
            a = 2 * math.pi * p
            wave, over = math.cos(a), math.sin(a)     # wave +: right leg forward; over +: weight on the right foot
            pelR = (lean * 0.6 + 2.0, twist * wave + (-6.0 if carry else 0), drop * over)
            pel = (sway * over, 0.0, -lean * 0.012)
            rows.append((p, a, wave, over, pelR, pel, foot(p, 0), foot(p + 0.5, 0)))
        ys = np.full(n, np.nan)
        J = rg.JOINT
        for i, (p, a, wave, over, pelR, pel, fr, fl) in enumerate(rows):
            W = rg.pivoted(np.eye(4), "LowerTorso", L.homog(L.euler(pelR), pel))
            found = []
            for side, f, tau, inset, s_shift in (("Right", fr, p, -shuffle, 0), ("Left", fl, p + 0.5, shuffle, 0)):
                if not f[3]:
                    continue
                leg = rg.LEGS[side]
                Hp = (W @ np.append(J[side + "UpperLeg"], 1))[:3]
                A = leg["ankle"] + np.array([ax * f[0] + inset, f[1], az * f[0]])
                flex = math.radians(curve(stance_flex, ((tau % 1.0) / beta)))
                u_, l_ = float(np.linalg.norm(leg["u"])), float(np.linalg.norm(leg["l"]))
                d = math.sqrt(u_ * u_ + l_ * l_ + 2 * u_ * l_ * math.cos(flex))
                flat = (Hp[0] - A[0]) ** 2 + (Hp[2] - A[2]) ** 2
                found.append(A[1] + math.sqrt(max(d * d - flat, 0.01)) - Hp[1])
            if found:
                ys[i] = min(found)
        idx = np.arange(n)
        good = ~np.isnan(ys)
        ys = np.interp(idx, idx[good], ys[good], period=n)
        if run:
            ys += 0.08 * np.where(good, 0.0, 1.0)
        F = np.fft.rfft(ys)
        F[5:] = 0
        ys = np.fft.irfft(F, n)
        keys = []
        for i, (p, a, wave, over, pelR, pel, fr, fl) in enumerate(rows):
            y = float(ys[i])
            base_twist = -6.0 if carry else 0.0
            chest_yaw = -twist * 0.95 * math.cos(a - 0.15) - (7.0 if carry else 0)
            chest_world = pelR[1] + chest_yaw
            nod = L.rodrigues(np.array([1.0, 0, 0]) * math.radians(1.1 * math.cos(2 * a - 0.4)) + np.array([0, 1.0, 0]) * math.radians(1.6 * wave))
            if carry == "charge":
                r0 = np.array((0.5, -0.02 + y * 0.8, -0.05 - lean * 0.012))
                h0 = np.array(H(-14, -6))
            else:
                r0 = np.array((0.5, -0.02 + y * 0.85, 0.0))
                h0 = np.array(RHAFT)
            hf = nod @ h0
            k = dict(pel=(pel[0], y, pel[2]), pelR=pelR, chest=(lean * 0.45 - 0.5 * math.cos(2 * a), chest_yaw, -pelR[2] * 1.2), neck=(-lean * 1.0 - 2.0 + 0.4 * math.cos(2 * a), -chest_world * 0.95, pelR[2] * 0.3),
                     rf=(ax * fr[0] - shuffle, az * fr[0], fr[1], 0, fr[2]), lf=(ax * fl[0] + shuffle, az * fl[0], fl[1], 0, fl[2]), rknee=(0.06, 0, -1.0), lknee=(-0.06, 0, -1.0),
                     rp=tuple(r0 + np.array([0.02 * over, 0.0, 0.05 * math.cos(a - 0.3)])), haft=tuple(hf), face=E(hf), rsl=-1.8, lsl=1.15, lhw=1.0, relb=READY["relb"], lelb=READY["lelb"])
            keys.append((p * period, k, "lin"))
        if reverse:   # a backward walk is a forward walk run backwards: toes land first, the heel lets down, the heel pushes off
            keys = [((period - t) % period, k, e) for t, k, e in keys]
        actual = 2 * half / (beta * period)
        return Clip(rg, P + name, period, keys, loop=True, priority="Movement", authored_feet=True, feet_free=[(0, period)], notes="%s: %.2f rig studs per second at speed 1." % (name, actual))

    def glide(name, period, rate, lean, roll=0.0, trail=0.0, tuck=0.0):
        """Phase 2's travel: no steps at all. He leans into the direction, legs trailing, and the air does the rest."""
        n = int(round(period * 30))
        keys = []
        for i in range(n):
            a = 2 * math.pi * i / n
            s, c2 = math.sin(a), math.cos(2 * a)
            nod = L.rodrigues(np.array([1.0, 0, 0]) * math.radians(1.4 * s))
            hf = nod @ np.array(H(-14, -12))
            r0 = np.array(READY["rp"])
            k = dict(pel=(0.03 * s, 0.02 * c2 - 0.05 * abs(lean) / 20, -lean * 0.012), pelR=(lean * 0.9 + 1.5 * s, -8 + 2 * math.cos(a), roll + 2.2 * s), chest=(lean * 0.3 - 1.2 * c2, -10 - 2.5 * math.cos(a), -roll * 0.5), neck=(-lean * 1.15, 18 + 2 * math.sin(a * 2), 0),
                     rf=(0.05, 0.24 + trail + 0.1 * math.sin(a + 0.6), tuck, 0, 0), lf=(-0.03, -0.1 + trail - 0.12 * math.sin(a + 0.6), tuck * 0.4, 0, 0), rknee=(0.1, 0, -1.0), lknee=(-0.1, 0, -1.0),
                     rp=tuple(r0 + np.array([0.02 * s, 0.03 * c2, -0.02 * math.cos(a) - lean * 0.008])), haft=tuple(hf), face=E(hf), rsl=-1.8, lsl=1.15, lhw=1.0, relb=READY["relb"], lelb=READY["lelb"])
            keys.append((i / n * period, k, "lin"))
        return clip(name, period, keys, loop=True, priority="Movement", feet_free=[(0, period)], notes="%s: floating; %.2f rig studs per second at speed 1." % (name, rate))

    def turn(name, direction):
        """Turning on the spot, as the server turns his root at TURN_RATE at speed 1: the planted foot counter-rotates exactly, the other steps ahead of it, and the hips lead the chest and the chest leads the head."""
        period = 0.9
        n = int(round(period * 30))
        sweep = direction * TURN_RATE * period / 2            # degrees each step covers; +: toward his left
        keys = []
        if floating:
            for i in range(n):
                a = 2 * math.pi * i / n
                k = {kk: READY[kk] for kk in READY}
                k.update(pelR=(4, -16 + direction * 14, direction * 4), chest=(3, -9 + direction * 10, 0), neck=(-3, 24 + direction * 14, 0))
                keys.append((i / n * period, k, "lin"))
            return clip(name, period, keys, loop=True, priority="Movement", feet_free=[(0, period)], notes="Floating, he simply rotates; the upper body leads the turn.")
        for i in range(n):
            p = i / n
            k = {kk: READY[kk] for kk in READY}
            for key, side, base, tau in (("rf", "Right", FEET_R, p), ("lf", "Left", FEET_L, p + 0.5)):
                tau %= 1.0
                at = rg.LEGS[side]["ankle"] + np.array([base[0], 0, base[1]])
                if tau < 0.5:
                    ang, lift, pitch = sweep * (0.5 - tau * 2) * -1 * -1, 0.0, 0.0
                    ang = sweep * (0.5 - 2 * tau)
                else:
                    u = (tau - 0.5) * 2
                    ang = sweep * (-0.5 + L.smooth01(u))
                    lift = 0.2 * math.sin(math.pi * u)
                    pitch = -16 * math.sin(math.pi * u)
                q = L.ry(math.radians(ang)) @ at - rg.LEGS[side]["ankle"]
                k[key] = (float(q[0]), float(q[2]), lift, base[3] + ang, pitch)
            over = math.sin(2 * math.pi * p)
            k.update(pel=(0.04 * over, -0.07 - 0.015 * math.cos(4 * math.pi * p), 0.02), pelR=(3, -16 + direction * 10, 2 * over), chest=(2, -9 + direction * 10, -1.6 * over), neck=(-1, 24 + direction * 12, 0))
            keys.append((p * period, k, "lin"))
        return Clip(rg, P + name, period, keys, loop=True, priority="Movement", authored_feet=True, feet_free=[(0, period)], notes="%s at %d degrees per second, speed 1." % (name, TURN_RATE))

    def locomotion():
        turns = [turn("TurnLeft", 1.0), turn("TurnRight", -1.0)]
        if floating:   # rates the server already holds; a glide has no feet to keep planted, so these only set how fast his body drifts through its loop
            return turns + [glide("WalkForward", 2.4, 2.40, 12, trail=0.3), glide("RunForward", 1.6, 7.48, 38, trail=1.25, tuck=0.45), glide("WalkBackward", 2.4, 1.80, -10, trail=-0.2), glide("StrafeLeft", 2.4, 1.95, 4, roll=10), glide("StrafeRight", 2.4, 1.95, 4, roll=-10)]
        return turns + [gait("WalkForward", 1.4, 1.98, 0.63, lean=2.0, twist=5.0, drop=3.4, sway=0.07),
                        gait("RunForward", 0.75, 6.11, 0.36, carry="charge", run=True, lean=13, twist=9.0, drop=3.0, sway=0.04, centre=0.42),
                        gait("WalkBackward", 1.5, 1.48, 0.65, reverse=True, lean=0.5, twist=3.0, drop=2.4, sway=0.06),
                        gait("StrafeLeft", 1.3, 1.54, 0.62, along=(-1.0, 0.0), lean=2.0, twist=1.5, drop=2.0, sway=0.03, shuffle=0.12),
                        gait("StrafeRight", 1.3, 1.54, 0.62, along=(1.0, 0.0), lean=2.0, twist=1.5, drop=2.0, sway=0.03, shuffle=0.12)]

    def guard():
        up = H(-34, 34)
        a = {**READY, "pel": (0.02, -0.16, 0.05), "pelR": (4, -22, 0), "chest": (6, -8, 0), "neck": (-6, 28, 0), "rp": (0.62, 0.05, -0.1), "haft": up, "face": E(up, (0.3, 0.5, -0.8))}
        b = dict(chest=(5, -8, 0), pel=(0.02, -0.18, 0.05))
        hit = {**a, "pel": (0.02, -0.24, 0.3), "chest": (-3, -14, 3), "rp": (0.62, 0.15, 0.1)}
        return [clip("GuardLoop", 1.8, [K(0, **a), K(0.9, **b)], loop=True, priority="Movement", notes="Haft raised across the body in both hands, weight low and quiet."),
                clip("GuardHit", 0.45, [K(0, **a), K(0.1, "snap", **hit), K(0.45, "io", **a)], priority="Movement", feet_free=[(0, 0.45)], notes="A blow on the haft: he gives a little ground and resets.")]

    # ---------------------------------------------------------------- reactions
    def reactions():
        kneel_h = H(14, -36)
        knee = {**READY, "pel": (0.05, -0.95, 0.18), "pelR": (13, 4, 0), "chest": (18, 6, 0), "neck": (-3, -6, 0), "rf": (0.05, 0.95, 0.5, 0, -55), "lf": (0.05, -0.62, 0, 0, 0), "rp": (0.85, -0.5, -0.85), "haft": kneel_h, "face": E(kneel_h, (0.2, -0.3, 0.9)), "rsl": -1.8, "lsl": 1.15}

        def hit(name, push, turn_, lean_p, lean_r):
            flinch = {**READY, "pel": (READY["pel"][0] + push[0], -0.14, READY["pel"][2] + push[1]), "pelR": (READY["pelR"][0] + lean_p, READY["pelR"][1] + turn_, lean_r), "chest": (READY["chest"][0] + lean_p * 1.8, READY["chest"][1] + turn_ * 1.5, lean_r * 1.3), "neck": (READY["neck"][0] + lean_p, READY["neck"][1] + turn_, 0),
                      "rf": (FEET_R[0] + push[0] * 0.5, FEET_R[1] + push[1] * 0.6, 0, FEET_R[3], 0), "lf": (FEET_L[0] + push[0] * 0.2, FEET_L[1] + push[1] * 0.2, 0, FEET_L[3], 0)}
            return clip(name, 0.48, [K(0, **READY), K(0.09, "snap", **flinch), K(0.22, "out", **flinch), K(0.48, "io", **READY)], priority="Action3", feet_free=[(0, 0.48)], notes="Flinch from the blow's direction: chest first, then the hips and the rear foot give; the cloth takes the same push at run time.")

        down = dict(hov=0.0) if floating else {}
        bowed_h = H(14, -32)    # bowing, his hands slide back to the butt of the haft, so none of it comes back through his chest
        bowed = dict(rp=(0.9, -0.6, -0.95), haft=bowed_h, face=E(bowed_h, (0.2, -0.3, 0.9)), rsl=-1.8, lsl=1.15)
        return [
            hit("HitLightFront", (0.0, 0.2), 0, -5, 0), hit("HitLightBack", (0.0, -0.2), 0, 8, 0), hit("HitLightLeft", (0.2, 0.0), -9, -1, 4), hit("HitLightRight", (-0.2, 0.0), 9, -1, -4),
            Clip(rg, P + "PostureBreak", 1.0, [K(0, **READY, **({"hov": H0} if floating else {})), K(0.14, "snap", pel=(0.02, -0.15, 0.42), pelR=(-14, 7, 0), chest=(-20, 8, 0), neck=(13, 0, 0), rf=(0.2, 0.7, 0, -24, 0), **({"hov": H0 * 0.6} if floating else {})),
                                               K(0.46, "io", pel=(0.05, -0.5, 0.3), pelR=(5, 6, 0), chest=(6, 6, 0), neck=(2, 0, 0), rf=(0.1, 0.8, 0.3, 0, -26), lf=(0.05, -0.4, 0, 0, 0), **down), K(1.0, "in", **knee, **down)],
                 priority="Action3", feet_free=[(0, 1)], airborne=floating, authored_feet=True, notes="Stance broken: thrown back, the levitation fails if he had it, and he sinks to his right knee on the haft, still holding it in both hands."),
            Clip(rg, P + "DeathblowVictim", 2.2, [K(0, **knee), K(0.22, "snap", pel=(0.05, -0.8, 0.32), pelR=(-9, 4, 0), chest=(-14, 6, 0), neck=(15, 0, 0)), K(0.9, "io", pel=(0.05, -0.92, 0.28), pelR=(9, 4, 0), chest=(14, 6, 0), neck=(0, 0, 0)),
                                                  K(1.5, "in", pel=(0.05, -1.02, 0.16), pelR=(20, 4, 0), chest=(29, 6, 0), neck=(-14, 0, 0), **bowed), K(2.2, "io", pel=(0.05, -1.06, 0.12), pelR=(24, 4, 0), chest=(34, 6, 0), neck=(-20, 0, 0), **bowed)],
                 priority="Action4", feet_free=[(0, 2.2)], authored_feet=True, notes="Takes the deathblow on the knee: head snaps back, then the old body bows over the haft."),
            Clip(rg, P + "Death", 3.0, [K(0, **READY, **({"hov": H0 * 0.5} if floating else {})), K(0.24, "snap", pel=(0, -0.16, 0.4), pelR=(-12, 6, 0), chest=(-18, 6, 0), neck=(16, 0, 0), **down),
                                        K(0.85, "io", pel=(0.03, -0.55, 0.3), pelR=(6, 6, 0), chest=(10, 6, 0), neck=(4, 0, 0), rf=(0.1, 0.7, 0.32, 0, -30), lf=(0.05, -0.4, 0, 0, 0)),
                                        K(1.35, "in", **{k: v for k, v in knee.items() if k not in ("neck",)}, neck=(-8, 0, 0)), K(2.2, "io", pel=(0.05, -1.04, 0.1), pelR=(25, 6, 0), chest=(36, 6, 0), neck=(-24, 0, 0), **bowed), K(3.0, "io", pel=(0.05, -1.06, 0.08), pelR=(29, 6, 0), chest=(40, 6, 0), neck=(-28, 0, 0), **bowed)],
                 priority="Action4", feet_free=[(0, 3)], airborne=floating, authored_feet=True, notes="Killed: staggers, sinks to the right knee and dies kneeling on the haft; the body fades there."),
        ]

    # ---------------------------------------------------------------- the transformation: both forms meet at one pose at Transition.Reveal, on the ground; phase 2 then rises
    def handoff():
        h = H(26, -46)
        return dict(pel=(0.0, -0.38, 0.12), pelR=(18, 0, 0), chest=(26, 0, 0), neck=(-12, 0, 0), rp=(0.62, -0.42, -0.7), haft=h, face=E(h, (0.15, -0.35, 0.92)), rsl=-1.0, lsl=1.0, relb=(0.8, -0.3, 0.4), lhw=1.0, ltw=0.0, lelb=(-0.7, -0.6, 0.3), lua=(0, 0, 0), lfa=(0, 0, 0), lha=(0, 0, 0),
                    rf=(0.2, 0.36, 0, -20, 0), lf=(0.0, -0.34, 0, 2, 0), rknee=(0.06, 0, -1.0), lknee=(-0.06, 0, -1.0))

    def transform():
        R = handoff()
        if not floating:
            return [Clip(rg, P + "Transform", 1.7, [
                K(0, **READY),
                K(0.22, "snap", pel=(0.0, -0.22, 0.16), pelR=(9, -6, 3), chest=(15, -2, 2), neck=(10, 10, 0)),
                K(0.52, "io", pel=(0.0, -0.32, 0.16), pelR=(15, -3, 1), chest=(23, 0, 0), neck=(4, 2, 0)),
                K(REVEAL, "in", **R),
                K(1.7, "lin", **R),
            ], priority="Action4", feet_free=[(0, 1.7)], raw_after=REVEAL, notes="He falters and bows over the glaive, both hands tight on it; reaches the shared handoff pose at the Reveal and holds it for the swap.")]
        rh = H(70, 38)
        rise = dict(pel=(0.0, 0.0, 0.14), pelR=(-13, 0, 0), chest=(-22, 0, 0), neck=(18, 0, 0), rp=(0.95, 0.45, -0.1), haft=rh, face=E(rh, (0.3, 0.8, 0.5)), rsl=-1.8, lsl=1.15, relb=(0.9, -0.2, 0.3), lhw=1.0, hov=0.0)
        return [Clip(rg, P + "Transform", 1.5, [
            K(0, hov=0.0, **R),
            K(0.32, "snap", **rise),
            K(0.8, "io", pel=(0.0, 0.0, 0.14), pelR=(-15, 0, 0), chest=(-25, 0, 0), neck=(20, 0, 0), hov=HOVER * 0.75),
            K(1.5, "io", **READY, hov=HOVER),
        ], priority="Action4", corrupt=False, feet_free=[(0, 1.5)], airborne=True, authored_feet=True, notes="Revealed from the shared handoff pose in the burst: he straightens, the glaive thrown wide in both hands, and on the roar his feet leave the floor. Ends exactly on the phase 2 idle.")]

    out = [idle(), strike(), flourish(), feint()] + locomotion() + guard() + reactions() + transform()
    out += [crescent_reap(), returning_tide(), heaven_cleave(), green_dragon(), charging_cut(), cyclone()]
    out += [flowing_glaive(), prayer_beads(), abbot_sweep(), hesitant_moon(), wheel_of_heaven()] if not floating else [blood_wave(), skyfall(), crimson_embrace(), rending_arc(), phantom_drift()]
    return out


TURN_RATE = 220   # degrees per second at playback 1: BossAnimationRules.TurnRate


def library():
    return build(1) + build(2)
