"""Cursed Swordsman: the dead pagoda guard's own dao clip set.

Attacks are timed from the built WeaponSchema Dao moves (castlib.timing): clip length = the move's total and the cut
lands at startup + active/2, the time FighterAnimations phase-locks to the server's move clock. The dao is part of
his skin (bound to the right hand), so where it points is set by the arm solve: the elbow pole turns the blade's plane,
elbow bend plus wrist flex tilt it within that plane. Every cut is checked against the server's swept shape at the
blade's middle (validate) and its direction was set with probe_blade.py.
"""
import math

import numpy as np

import castlib as C
from castlib import Clip

GRIP = (1.04, -0.89, 0.0)            # the grip line through the visible fist (root space at rest)
GRIP_TILT = -65.0                    # swordsman.py: the grip crosses the palm diagonally, the point forward and down


def blade_point(along, lift):
    """Root-space rest position of a point `along` studs down the blade from the fist, `lift` above its axis."""
    a = math.radians(GRIP_TILT)
    y, z = along * math.cos(a) - lift * math.sin(a), along * math.sin(a) + lift * math.cos(a)   # Blender offsets
    return (GRIP[0], GRIP[1] + z, GRIP[2] - y)


TIP = blade_point(3.17, 0.09)
MID = ("RightHand", blade_point(1.75, 0.0))
FLEX = (-45.0, 20.0)                 # the wrist's real ulnar / radial deviation range
SWORDSMAN = C.Body("Swordsman", GRIP)
UPPER = {"UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand"}
SLOT = "CursedSwordsman."

READY = {
    # Right foot leading, body bladed, the dao low and forward with its point at the throat, left hand open by the chest.
    "pel": (0.0, -0.22, 0.05), "pelR": (0, 22, 0), "chest": (-4, -10, 0), "neck": (2, 0, 0),
    "look": (0, 1.3, -30), "lookW": 0.9,
    "rh": (0.62, 0.15, -1.15), "relb": (0.161, -0.891, 0.425), "rflex": -26.9,   # aim((-0.2, 0.6, -0.78))
    "lh": (-0.35, 0.55, -0.75), "lelb": (-0.6, -1, 0.3), "lflex": 0.0, "rspace": 0.0, "lspace": 0.0,
    "lf": (-0.55, 0.55, 0, -24, 0), "rf": (0.45, -0.6, 0, 12, 0), "lknee": (-0.2, 0, -1), "rknee": (0.2, 0, -1),
}


def pose(**over):
    out = dict(READY)
    out.update(over)
    return out


class SClip(Clip):
    def __init__(self, *a, **kw):
        super().__init__(*a, body=SWORDSMAN, **kw)
        self.base = dict(READY)


_SOLVER = None
_AIMED = {}


def blade_dir(clip, c):
    _, world, _ = clip.solve(c)
    f = C.visible(world, "RightHand", SWORDSMAN, GRIP)
    t = C.visible(world, "RightHand", SWORDSMAN, TIP)
    return (t - f) / np.linalg.norm(t - f)


def aim(want, prev=None, **over):
    """Key channels that put the visible fist at over["rh"] with the dao pointing along `want` (root space): searches
    the elbow pole round the shoulder-fist line and the wrist flex, preferring an elbow that hangs out and down."""
    global _SOLVER
    if _SOLVER is None:
        _SOLVER = SClip("aim", 1.0, [(0.0, pose(), "linear")])
    key = (tuple(np.round(want, 3)), None if prev is None else tuple(np.round(prev, 3)),
           tuple(sorted((k, tuple(np.ravel(v))) for k, v in over.items())))
    if key in _AIMED:
        return dict(over, **_AIMED[key])
    want = np.asarray(want, float) / np.linalg.norm(want)
    c = pose(**over)
    _, world, _ = _SOLVER.solve(c)
    S = C.rig.joint_world(world, "RightUpperArm")
    u = C.unit(np.asarray(c["rh"], float) - S)
    a = C.unit(np.cross(u, [0, 1.0, 0]) if abs(u[1]) < 0.95 else np.cross(u, [1.0, 0, 0]))
    b = np.cross(u, a)

    def cost(phi, flex):
        pole = a * math.cos(phi) + b * math.sin(phi)
        d = blade_dir(_SOLVER, dict(c, relb=tuple(pole), rflex=flex))
        turn = 0.0 if prev is None else math.acos(max(-1.0, min(1.0, float(pole @ prev))))   # keep the elbow travelling smoothly
        return math.acos(max(-1.0, min(1.0, float(d @ want)))) + 0.15 * max(0.0, pole[1]) + 0.002 * abs(flex) / 10 + 0.08 * turn + 0.6 * max(0.0, turn - 1.0), pole

    best = None
    for i in range(16):
        for flex in range(int(FLEX[0]), int(FLEX[1]) + 1, 5):
            v, pole = cost(2 * math.pi * i / 16, flex)
            if best is None or v < best[0]:
                best = (v, 2 * math.pi * i / 16, flex)
    _, phi, flex = best
    step_p, step_f = math.pi / 16, 5.0
    for _ in range(12):   # coordinate refinement
        for dp, df in ((step_p, 0), (-step_p, 0), (0, step_f), (0, -step_f)):
            v, _ = cost(phi + dp, max(FLEX[0], min(FLEX[1], flex + df)))
            if v < best[0]:
                best = (v, phi + dp, max(FLEX[0], min(FLEX[1], flex + df)))
        _, phi, flex = best
        step_p, step_f = step_p * 0.6, step_f * 0.6
    _, pole = cost(phi, flex)
    _AIMED[key] = {"relb": tuple(round(float(x), 3) for x in pole), "rflex": round(float(flex), 1)}
    if best[0] > 0.2:
        print("aim: %s misses by %.0f deg" % (np.round(want, 2), math.degrees(best[0])))
    return dict(over, **_AIMED[key])


def hold(k, t, **ch):
    """Hold key k's aimed pose until t (re-aiming it could pick another elbow pole and drift the blade)."""
    return (t, dict(k[1], **ch), "inout")


def stepped(keys):
    """Every keyed foot move becomes a step: the foot lifts on an arc between its keys (toe down as it leaves) instead of
    sliding along the ground, so a cut lands on a stamp and the recovery steps back to the guard."""
    out = list(keys)
    for side in ("lf", "rf"):
        feet = [(t, c[side]) for t, c, _ in sorted(keys, key=lambda k: k[0]) if side in c]
        if not any(side in c for t, c, _ in keys if t > 0):
            continue
        for (t0, f0), (t1, f1) in zip(feet, feet[1:]):
            gap = math.hypot(f1[0] - f0[0], f1[1] - f0[1])
            if gap < 0.12 or f0[2] > 0 or f1[2] > 0 or t1 - t0 < 0.05:
                continue
            mid = ((f0[0] + f1[0]) / 2, (f0[1] + f1[1]) / 2, min(0.32, 0.12 + 0.35 * gap), (f0[3] + f1[3]) / 2, -14.0)
            out.append((t0 + (t1 - t0) * 0.45, {side: mid}, "inout"))
    return out


def attack(name, move, keys, T, key, striker=MID, **kw):
    m = T[move]
    s, a = m["startup"], m["active"]
    keys = stepped(keys)
    return SClip(name, m["total"], keys, priority="Action2", move=move, kind=m["kind"], contacts=[s + a * 0.5],
                 active=(s, a, m["arc"], m["reach"]), striker=striker, slot=SLOT + key, **kw)


_CHAIN = {"t": 1e9, "pole": None}


def key(t, want, ease, **ch):
    """One key whose dao points along `want` (root space) with the visible fist at ch["rh"]. Keys are aimed in order
    and each prefers the elbow pole of the key before it (a clip's first key starts from the guard's), so the blade
    sweeps between keys instead of flipping over."""
    if t <= _CHAIN["t"]:
        _CHAIN["pole"] = np.asarray(READY["relb"], float) / np.linalg.norm(READY["relb"])
    out = aim(want, prev=_CHAIN["pole"], **ch)
    _CHAIN["t"], _CHAIN["pole"] = t, np.asarray(out["relb"], float)
    return (t, out, ease)


def light1(T):
    # Rising Crescent: the point dips low to the right of his lead knee, then the edge rises from low right to high left
    # through the facing on a short step, the left hand pulling back to the hip. (Dao lights start in 0.1 s: every
    # chamber stays in front of him and eases to a stop before the cut reverses it.)
    m = T["Dao_L1"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        key(0.065, (0.25, -0.3, -0.92), "inout", rh=(0.78, 0.0, -1.1), pelR=(0, 32, 0), chest=(-4, -18, 0), lh=(-0.45, 0.6, -0.9)),
        key(s + a * 0.5, (-0.35, 0.35, -0.87), "snap", rh=(0.3, 0.5, -1.8), pelR=(0, 8, 0), chest=(-10, 10, 0), pel=(0.0, -0.3, -0.26),
            rf=(0.45, -0.95, 0, 12, 0), lh=(-0.6, 0.3, -0.2)),
        key(s + a, (-0.6, 0.6, -0.5), "linear", rh=(-0.05, 0.85, -1.55), chest=(-8, 16, 0), lh=(-0.6, 0.3, -0.2)),
        key(s + a + 0.05, (-0.5, 0.75, -0.45), "settle", rh=(-0.1, 0.95, -1.3), chest=(-6, 14, 0), pel=(0.0, -0.24, -0.12),
            lh=(-0.55, 0.35, -0.4)),
        (m["total"], pose(), "inout"),
    ]
    return attack("Swordsman_L1", "Dao_L1", keys, T, "Light1", feet_free=[(0.03, m["total"] - 0.03)],
                  notes="Rising Crescent: low-right to high-left rising cut on a short step.")


def light2(T):
    # Descending Crescent: the dao lifts up beside the left temple, then cuts down the diagonal to the right hip.
    m = T["Dao_L2"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        key(0.065, (-0.35, 0.75, -0.55), "inout", rh=(0.3, 1.0, -1.05), pelR=(0, 10, 0), chest=(-4, 14, 0), lh=(-0.5, 0.5, -0.5)),
        key(s + a * 0.5, (0.3, -0.2, -0.93), "snap", rh=(0.35, 0.6, -1.8), pelR=(0, 34, 0), chest=(-14, -16, 0), pel=(0.0, -0.38, -0.32),
            rf=(0.45, -0.95, 0, 12, 0), lh=(-0.6, 0.4, -0.3)),
        key(s + a, (0.5, -0.5, -0.7), "linear", rh=(0.7, 0.25, -1.6), chest=(-12, -18, 0)),
        key(s + a + 0.06, (0.45, -0.75, -0.45), "out", rh=(0.9, -0.05, -1.2), pel=(0.0, -0.28, -0.12), chest=(-8, -14, 0)),
        (m["total"], pose(), "inout"),
    ]
    return attack("Swordsman_L2", "Dao_L2", keys, T, "Light2", feet_free=[(0.03, m["total"] - 0.03)],
                  notes="Descending Crescent: over the left shoulder and down the diagonal to the right hip.")


def light3(T):
    # Whirling Butcher Cut: hips wind right and the blade lies back flat, then the whole body pivots on the lead foot and
    # sweeps the edge 150 degrees right to left at chest height.
    m = T["Dao_L3"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        key(s, (0.55, 0.05, -0.83), "snap", rh=(0.95, 0.6, -1.4), pelR=(0, 40, 0), chest=(-4, -20, 0), lh=(-0.2, 0.7, -0.9)),
        key(s + a * 0.5, (-0.15, 0.0, -1.0), "linear", rh=(0.25, 0.62, -1.8), pelR=(0, 12, 0), chest=(-8, 4, 0), pel=(0.0, -0.28, -0.3),
            lh=(-0.55, 0.45, -0.25)),
        key(s + a, (-0.7, 0.0, -0.7), "linear", rh=(-0.35, 0.6, -1.45), pelR=(0, -10, 0), chest=(-8, 22, 0)),
        key(s + a + 0.08, (-0.9, 0.05, -0.4), "settle", rh=(-0.5, 0.55, -1.15), pelR=(0, -14, 0), chest=(-6, 24, 0), lh=(-0.4, 0.4, 0.2)),
        (m["total"], pose(), "inout"),
    ]
    return attack("Swordsman_L3", "Dao_L3", keys, T, "Light3", feet_free=[(0.03, m["total"] - 0.03)],
                  notes="Whirling Butcher Cut: flat 150-degree sweep right to left, pivoting on the lead foot.")


def light4(T):
    # Tiger Tail Cleave: the dao goes up over the head as he gathers, then a long lunge brings it straight down the
    # centre line, the left hand thrown back for balance.
    m = T["Dao_L4"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        key(0.1, (0.0, 0.85, -0.5), "settle", rh=(0.6, 1.45, -0.7), pelR=(0, 26, 0), chest=(6, -6, 0), pel=(0.0, -0.18, 0.15),
            lh=(-0.45, 0.9, -0.8)),
        key(s + a * 0.5, (0.0, -0.18, -0.98), "snap", rh=(0.35, 0.7, -1.95), pelR=(0, 18, 0), chest=(-14, -4, 0), pel=(0.0, -0.45, -0.6),
            rf=(0.45, -1.35, 0, 12, 0), lf=(-0.55, 0.65, 0, -24, -10), lh=(-0.6, 0.45, 0.15)),
        key(s + a, (0.05, -0.6, -0.8), "linear", rh=(0.45, 0.25, -1.95), chest=(-18, -4, 0)),
        key(s + a + 0.09, (0.1, -0.85, -0.5), "out", rh=(0.6, -0.1, -1.45), pel=(0.0, -0.38, -0.4), chest=(-12, -6, 0)),
        (m["total"], pose(), "inout"),
    ]
    return attack("Swordsman_L4", "Dao_L4", keys, T, "Light4", feet_free=[(0.03, m["total"] - 0.03)],
                  notes="Tiger Tail Cleave: overhead gather, lunge, straight cleave down the centre line.")


def heavy(T):
    # Moon Arc: a long coil (hyperarmour) with the dao raised behind the right shoulder, then a stamping step carries
    # a huge diagonal arc from high right down through the target to low left.
    m = T["Dao_Heavy"]
    s, a = m["startup"], m["active"]
    coil = key(0.2, (0.45, 0.85, 0.25), "inout", rh=(0.95, 1.5, -0.2), pelR=(0, 52, 0), chest=(8, -26, 0), pel=(0.0, -0.3, 0.3),
               lh=(-0.3, 0.75, -0.8), lelb=(-0.6, -1, 0))
    keys = [
        (0, pose(), "linear"),
        coil,
        hold(coil, 0.27, pelR=(0, 50, 0)),
        key(s, (0.3, 0.65, -0.7), "snap", rh=(0.95, 1.35, -0.9), pelR=(0, 40, 0), chest=(2, -18, 0)),
        key(s + a * 0.5, (-0.3, -0.3, -0.9), "linear", rh=(0.3, 0.6, -1.95), pelR=(0, 6, 0), chest=(-16, 8, 0), pel=(0.0, -0.52, -0.55),
            rf=(0.5, -1.3, 0, 12, 0), lh=(-0.6, 0.35, 0.0)),
        key(s + a, (-0.6, -0.5, -0.62), "linear", rh=(-0.35, 0.1, -1.85), chest=(-18, 18, 0)),
        key(s + a + 0.12, (-0.6, -0.75, 0.25), "out", rh=(-0.65, -0.3, -0.95), chest=(-14, 18, 0), pel=(0.0, -0.45, -0.45),
            lh=(-0.45, 0.4, -0.15)),
        (0.59, pose(rh=(0.1, 0.25, -1.25), relb=(-0.45, -0.2, 0.87), rflex=-35.0, chest=(-8, 6, 0), pel=(0.0, -0.32, -0.2),
                   lh=(-0.5, 0.4, -0.3)), "inout"),   # the elbow rolls round behind the arm back to the guard's
        (m["total"], pose(), "inout"),
    ]
    return attack("Swordsman_Heavy", "Dao_Heavy", keys, T, "Heavy", feet_free=[(0.2, m["total"] - 0.05)],
                  notes="Moon Arc: long coil behind the shoulder, stamping step, high-right to low-left arc.")


def running(T):
    # Charging Tiger: the dao drawn back level at the hip as he runs in, then driven out in a flat lunging thrust-cut.
    m = T["Dao_Running"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        key(0.12, (0.6, 0.0, -0.8), "inout", rh=(0.7, 0.6, -0.95), pelR=(0, 36, 0), chest=(-10, -20, 0), pel=(0.0, -0.4, 0.1),
            lh=(-0.4, 0.75, -1.1)),
        key(s + a * 0.5, (-0.1, 0.0, -1.0), "snap", rh=(0.35, 0.62, -2.05), pelR=(0, 12, 0), chest=(-14, 2, 0), pel=(0.0, -0.5, -0.7),
            rf=(0.45, -1.4, 0, 12, 0), lf=(-0.55, 0.75, 0.1, -24, -20), lh=(-0.75, 0.45, 0.25)),
        key(s + a, (-0.1, 0.05, -1.0), "linear", rh=(0.32, 0.6, -2.1)),
        key(s + a + 0.09, (-0.1, 0.35, -0.93), "out", rh=(0.5, 0.4, -1.6), pel=(0.0, -0.35, -0.35)),
        (m["total"], pose(), "inout"),
    ]
    return attack("Swordsman_Running", "Dao_Running", keys, T, "Running", feet_free=[(0.03, m["total"] - 0.03)],
                  notes="Charging Tiger: dao drawn back at the hip, flat lunging thrust-cut.")


def art(T):
    # Crimson Gale Massacre: he sinks and winds far right with the blade trailing behind him, then unwinds through a
    # 180-degree sweep and carries it on round past his left side.
    m = T["Dao_Art"]
    s, a = m["startup"], m["active"]
    wind = key(0.17, (0.85, 0.2, -0.45), "inout", rh=(1.05, 0.5, -0.8), pelR=(0, 62, 0), chest=(-6, -30, 0), pel=(0.0, -0.45, 0.2),
               lh=(-0.1, 0.6, -0.8))
    keys = [
        (0, pose(), "linear"),
        wind,
        hold(wind, 0.22),
        key(s + a * 0.5, (-0.1, 0.0, -1.0), "snap", rh=(0.1, 0.62, -1.9), pelR=(0, 10, 0), chest=(-12, 6, 0), pel=(0.0, -0.5, -0.4),
            rf=(0.5, -1.1, 0, 12, 0), lh=(-0.8, 0.45, 0.2)),
        key(s + a, (-0.85, 0.0, -0.5), "linear", rh=(-0.4, 0.55, -1.35), pelR=(0, -24, 0), chest=(-10, 26, 0), lh=(-0.5, 0.45, 0.05)),
        key(s + a + 0.15, (-0.95, 0.0, -0.1), "settle", rh=(-0.4, 0.45, -1.0), pelR=(0, -30, 0), chest=(-8, 28, 0), pel=(0.0, -0.42, -0.3)),
        (m["total"], pose(), "inout"),
    ]
    return attack("Swordsman_Art", "Dao_Art", keys, T, "WeaponArt", feet_free=[(0.15, m["total"] - 0.05)],
                  notes="Crimson Gale Massacre: deep wind-up, 180-degree unwinding sweep carried round past the left side.")


def idle():
    # Still as a statue keeping his post: slow breath, the point drifting a hand's width on the guard line.
    k = [(0.0, pose(), "inout")]
    for i, (dy, dx, ch) in enumerate([(-0.03, 0.03, 2), (0.0, 0.0, 0), (-0.02, -0.03, -2)]):
        k.append(key((i + 1) * 0.8, (-0.2 + dx, 0.6, -0.78), "inout", rh=(0.62 + dx * 0.5, 0.15 + dy, -1.15), pel=(0.0, -0.22 + dy, 0.05),
                     chest=(-4 + ch * 0.5, -10 + ch, 0)))
    k[-1] = (3.2, pose(), "inout")
    return SClip("Swordsman_Idle", 3.2, k, loop=True, priority="Movement", slot=SLOT + "Idle",
                 notes="Guard loop: right foot leading, dao low and forward, the point at the throat.")


def move():
    keys = [(0.0, pose(), "inout"), key(0.35, (-0.2, 0.62, -0.76), "inout", rh=(0.62, 0.12, -1.1), chest=(-6, -8, 0)),
            (0.7, pose(), "inout")]
    return SClip("Swordsman_Move", 0.7, keys, loop=True, priority="Movement", mask=UPPER, slot=SLOT + "Move",
                 notes="Upper-body guard carried over the walk/run: the dao stays on the line.")


WALK_SPEED = 6.4    # studs/s at scale 1: his patrol pace (about 8) at the 1.2 x he spawns at
RUN_SPEED = 11.0    # his chase (about 12 studs/s) plays this near 1 x at 1.2 scale; full pace (22.4) about 1.7 x


def cycle(name, length, velocity, duty, lift, feet, body, slot, notes, pitch_off=-16.0):
    """A full-body in-place locomotion loop: castlib.gait feet with body(u) -> channels at each sample (u = 0..1)."""
    keys = [(t, pose(**dict(body(t / length), lf=lf, rf=rf)), "linear")
            for t, lf, rf in C.gait(length, velocity, duty, lift, feet, pitch_off=pitch_off)]
    return SClip(name, length, keys, loop=True, priority="Movement", slot=SLOT + slot, velocity=velocity, notes=notes)


def walk():
    # Stalking walk: the dao stays on the guard line, the hips swing and lift over each stance leg, the shoulders
    # counter them and the empty left hand swings against the left leg.
    carry = aim((-0.2, 0.62, -0.76), prev=np.asarray(READY["relb"], float), rh=(0.62, 0.1, -1.1))
    feet = {"lf": (-0.42, 0.1, 0, -6, 0), "rf": (0.42, -0.1, 0, 6, 0)}

    def body(u):
        c2, c1 = math.cos(4 * math.pi * u), math.cos(2 * math.pi * u)
        swing = math.cos(2 * math.pi * u)            # +1 as the left foot lands (left hand back), -1 as the right does
        return dict(carry, pel=(-0.04 * math.cos(2 * math.pi * (u - 0.3)), -0.39 - 0.05 * c2, 0.03),
                    pelR=(0, 8 - 9 * c1, 2 * math.sin(2 * math.pi * u)), chest=(-6 + 1.5 * c2, -6 + 7 * c1, 0),
                    rh=(0.62, 0.1 + 0.025 * c2, -1.1), lh=(-0.9, -0.5 + 0.06 * abs(swing), -0.1 + 0.42 * swing),
                    lelb=(-0.3, -0.4, 1), lflex=-5.0, neck=(4, -4 * c1, 0))

    return cycle("Swordsman_Walk", 0.7, (0.0, -WALK_SPEED), 0.58, 0.3, feet, body, "Walk",
                 "Guarded stalk at %.1f studs/s (scale 1): planted feet, hip lift and sway, counter-twist." % WALK_SPEED)


def run():
    # Charging run: leaned into it, the dao trailed low behind the right hip with its point back, the left arm pumping.
    trail = aim((0.15, -0.45, 0.88), prev=np.asarray(READY["relb"], float), rh=(0.8, -0.22, 0.15))
    feet = {"lf": (-0.38, 0.05, 0, -4, 0), "rf": (0.38, -0.05, 0, 4, 0)}

    def body(u):
        c2, c1 = math.cos(4 * math.pi * u), math.cos(2 * math.pi * u)
        swing = math.cos(2 * math.pi * u)
        return dict(trail, pel=(-0.05 * math.cos(2 * math.pi * (u - 0.2)), -0.47 + 0.08 * math.cos(4 * math.pi * (u - 0.18)), -0.12),
                    pelR=(-8, -12 * c1, 0), chest=(-16 + 2 * c2, 14 * c1, 0), neck=(14, -10 * c1, 0),
                    rh=(0.8 + 0.04 * swing, -0.22 + 0.04 * c2, 0.15 - 0.12 * swing),
                    lh=(-0.66, -0.3 + 0.32 * max(0.0, -swing), -0.1 + 0.4 * swing), lelb=(-0.15, -1, 0.35), lflex=-10.0)

    return cycle("Swordsman_Run", 36 / 60, (0.0, -RUN_SPEED), 0.36, 0.5, feet, body, "Run",
                 "Charging run at %.1f studs/s (scale 1): forward lean, dao trailed low, left arm pumping." % RUN_SPEED,
                 pitch_off=-26.0)


GUARD = dict(rh=(0.45, 1.2, -0.95), lh=(-0.3, 1.15, -1.1), lelb=(-0.6, -1, 0.2), chest=(-8, -4, 0), neck=(6, 0, 0))


def guard():
    first = key(0.0, (-0.96, 0.18, -0.22), "inout", **GUARD)
    keys = [first, key(0.8, (-0.96, 0.2, -0.2), "inout", **dict(GUARD, chest=(-9, -5, 0))), (1.6, first[1], "inout")]
    return SClip("Swordsman_Guard", 1.6, keys, loop=True, priority="Action", mask=UPPER, slot=SLOT + "Guard",
                 notes="Hanging guard: the dao held flat across the brow, left hand braced behind it.")


def guard_impact():
    keys = [key(0.0, (-0.96, 0.18, -0.22), "linear", **GUARD),
            key(0.06, (-0.9, 0.35, 0.1), "snap", **dict(GUARD, rh=(0.5, 1.32, -0.62), lh=(-0.3, 1.25, -0.8), chest=(4, -2, 0), neck=(-6, 0, 0))),
            key(0.32, (-0.96, 0.18, -0.22), "settle", **GUARD)]
    return SClip("Swordsman_GuardImpact", 0.32, keys, priority="Action2", mask=UPPER, slot=SLOT + "GuardImpact",
                 notes="A blocked blow drives the guard back toward the helmet, then it re-settles.")


def hit_light():
    keys = [(0.0, pose(), "linear"),
            key(0.06, (0.2, 0.75, -0.6), "snap", chest=(10, -24, 6), neck=(-14, -18, 0), pel=(0.0, -0.24, 0.2), rh=(0.8, 0.35, -0.7),
                lh=(-0.5, 0.45, -0.5)),
            key(0.18, (-0.1, 0.65, -0.75), "out", chest=(2, -12, 2), neck=(-4, -6, 0)),
            (0.36, pose(), "inout")]
    return SClip("Swordsman_Hit_Light", 0.36, keys, priority="Action3", slot=SLOT + "Hitstun_Light",
                 notes="Helmet snaps back, the guard knocked wide, then back on the line.")


def hit_heavy():
    keys = [(0.0, pose(), "linear"),
            key(0.08, (0.55, 0.3, -0.78), "snap", chest=(18, -16, 0), neck=(-18, 0, 0), pel=(0.0, -0.24, 0.45), rh=(1.0, 0.2, -0.4),
                lh=(-0.6, 0.35, -0.3), lelb=(-1, -0.5, 0.3), lf=(-0.55, 0.85, 0, -24, 0)),
            key(0.3, (0.4, -0.75, -0.5), "inout", chest=(-20, -4, 0), neck=(12, 0, 0), pel=(0.0, -0.52, 0.5), rh=(0.75, -0.25, -0.9),
                lh=(-0.55, -0.2, -0.6)),
            key(0.5, (0.0, 0.3, -0.95), "out", chest=(-10, -8, 0), neck=(6, 0, 0), pel=(0.0, -0.36, 0.25)),
            (0.7, pose(), "inout")]
    return SClip("Swordsman_Hit_Heavy", 0.7, keys, priority="Action3", slot=SLOT + "Hitstun_Heavy", feet_free=[(0.0, 0.7)],
                 notes="Rocked back a step, doubles over the point, recovers the guard.")


def stance_broken():
    b = dict(pel=(0.0, -0.5, 0.2), pelR=(0, 12, 0), chest=(-24, -4, 4), neck=(18, 0, 6), rh=(0.75, -0.55, -0.6), lh=(-0.55, -0.3, -0.25),
             lelb=(-1, 0, 0.5), lflex=-10, lookW=0.2, lf=(-0.55, 0.55, 0, -24, 0), rf=(0.45, -0.4, 0, 12, 0))
    first = key(0.0, (0.15, -0.9, -0.4), "inout", **b)
    keys = [first, key(0.8, (0.2, -0.88, -0.42), "inout", **dict(b, chest=(-20, 0, -4), neck=(14, 4, -8), pel=(0.04, -0.55, 0.2))),
            (1.6, first[1], "inout")]
    return SClip("Swordsman_StanceBroken", 1.6, keys, loop=True, priority="Action4", slot=SLOT + "StanceBroken",
                 notes="Posture break: the point sags to the ground, the helmet lolls, the punish window.")


def death():
    knees = dict(lknee=(0, -0.3, -1), rknee=(0, -0.3, -1), lf=(-0.55, 0.55, 0, -24, -40), rf=(0.45, -0.5, 0, 12, -60))
    keys = [(0.0, pose(), "linear"),
            key(0.12, (0.3, 0.5, -0.8), "snap", chest=(14, -10, 0), neck=(-16, 0, 0), pel=(0.0, -0.26, 0.2), rh=(0.85, 0.35, -0.6),
                lh=(-0.6, 0.4, -0.4), lookW=0.3),
            key(0.55, (0.1, -0.95, -0.3), "inout", chest=(-28, 0, 6), neck=(30, 0, 10), pel=(0.0, -1.05, 0.1), rh=(0.7, -0.95, -0.7),
                lh=(-0.55, -0.95, -0.2), lelb=(-1, 0, 0.3), lflex=-20, lookW=0.0, **knees),
            key(0.9, (0.05, -1.0, -0.2), "settle", chest=(-38, 0, 8), neck=(35, 0, 12), pel=(0.0, -1.2, 0.05), rh=(0.7, -1.1, -0.7),
                lh=(-0.55, -1.0, -0.2), **knees)]
    return SClip("Swordsman_Death", 0.9, keys, priority="Action4", slot=SLOT + "Death", feet_free=[(0.0, 0.9)],
                 notes="Knees give, the point drives into the ground, the helmet drops; held while the body burns away.")


def library():
    T = C.timing()
    return [idle(), move(), walk(), run(), light1(T), light2(T), light3(T), light4(T), heavy(T), running(T), art(T), guard(), guard_impact(),
            hit_light(), hit_heavy(), stance_broken(), death()]
