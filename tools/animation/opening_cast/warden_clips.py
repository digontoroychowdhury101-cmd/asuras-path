"""Hollow-Bell Warden: the grave-keeper's own crescent-moon spade clip set, and his Hollow Toll.

Attacks are timed from the built WeaponSchema Guandao moves (castlib.timing): clip length = the move's total and the
blow lands at startup + active/2. The spade is part of his skin (bound to the right hand, warden.py), its shaft on the
grip line through the right fist (root -Z at rest), the fist low on the haft just above the butt and the crescent
4.7 studs ahead of it, so at his 1.35 scale each blow lands on a body where his AI swings from (castlib checks it).
Every key names where the right fist is and where the shaft points; the left fist then takes the shaft wherever
ahead of the right hand sits comfortably for the left shoulder, as hands slide on a polearm, and turns its grip to
lie along the shaft. Hollow Toll swings the haft crosswise into his own bell, like a
temple's striker log, its contact on the shockwave's Windup (FighterAnimations.signatureTime).
"""
import math

import numpy as np

import castlib as C
from castlib import Clip

GRIP = (1.22, -0.88, 0.0)            # warden.py FIST: the grip line through the visible right fist (root space at rest)
LGRIP = (-1.22, -0.88, 0.0)
GRIP_TILT = -65.0  # warden.py: the shaft crosses each palm diagonally, forward and down at rest
SPADE_HOLD = 1.75  # warden.py: the right fist rides this far down the haft, just above the butt socket
SCALE = 1.35       # WorldDefinitions: his game scale; a contact this far forward x SCALE meets the Guandao's reach
# Where his blows meet a body: the AI stands off at 0.75 x the Guandao's light reach (MobSpacing.standoff, 10.5 ->
# 7.9; the Studio duel trace held 8.7 root to root) and the target's surface is 1.2 in from its root.
MEET = 7.5
LEFT_ON = (0.55, 3.4)  # the stretch of haft ahead of the right fist the left hand may hold (butt behind, crescent ahead)


def along(grip, d):
    """Root-space rest point d studs along the shaft from a fist's grip centre (toward the crescent)."""
    a = math.radians(GRIP_TILT)
    return (grip[0], grip[1] + d * math.sin(a), grip[2] - d * math.cos(a))


CRESCENT = ("RightHand", along(GRIP, 2.95 + SPADE_HOLD))
FLEX = (-45.0, 25.0)
WARDEN = C.Body("Warden", GRIP)
UPPER = {"UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand"}
SLOT = "HollowBellWarden."
REACH = 1.12                         # comfortable shoulder-to-fist distance for the left hand's grip

READY = {
    # Left foot leading, body bladed to his right, the right fist by the hip and the crescent raised forward on the
    # left of the line, the left hand forward on the shaft.
    "pel": (0.0, -0.32, 0.05), "pelR": (0, -26, 0), "chest": (-8, -22, 0), "neck": (6, 0, 0),
    "look": (0, 1.3, -30), "lookW": 0.85,
    "rh": (0.8, -0.1, -0.35), "relb": (0.5, -0.8, 0.3), "rflex": 0.0,
    "lh": (0.2, 0.3, -1.2), "lelb": (-0.6, -1, 0.0), "lflex": 0.0, "rspace": 0.0, "lspace": 0.0,
    "lf": (-0.55, -0.6, 0, -18, 0), "rf": (0.6, 0.45, 0, 28, 0), "lknee": (-0.2, 0, -1), "rknee": (0.3, 0, -1),
}
GUARD_WANT = (-0.3, 0.42, -0.86)


def pose(**over):
    out = dict(READY)
    out.update(over)
    return out


class WClip(Clip):
    def __init__(self, *a, **kw):
        super().__init__(*a, body=WARDEN, **kw)
        self.base = dict(READY)
        self.scale, self.meet = SCALE, MEET


_SOLVER = None
_CACHE = {}


def solver():
    global _SOLVER
    if _SOLVER is None:
        _SOLVER = WClip("aim", 1.0, [(0.0, pose(), "linear")])
    return _SOLVER


def axis(world, part, grip):
    a = C.visible(world, part, WARDEN, grip)
    b = C.visible(world, part, WARDEN, along(grip, 1.0))
    return a, (b - a) / np.linalg.norm(b - a)


def search(c, side, score, prev=None):
    """Elbow pole round the shoulder-fist line and wrist flex for one arm minimising score(world)."""
    s = solver()
    pole_key, flex_key, hand_key = ("relb", "rflex", "rh") if side == "Right" else ("lelb", "lflex", "lh")
    _, world, _ = s.solve(c)
    S = C.rig.joint_world(world, side + "UpperArm")
    u = C.unit(np.asarray(c[hand_key], float) - S)
    a = C.unit(np.cross(u, [0, 1.0, 0]) if abs(u[1]) < 0.95 else np.cross(u, [1.0, 0, 0]))
    b = np.cross(u, a)

    def cost(phi, flex):
        pole = a * math.cos(phi) + b * math.sin(phi)
        _, w, _ = s.solve(dict(c, **{pole_key: tuple(pole), flex_key: flex}))
        turn = 0.0 if prev is None else math.acos(max(-1.0, min(1.0, float(pole @ prev))))
        return score(w) + 0.15 * max(0.0, pole[1]) + 0.002 * abs(flex) / 10 + 0.08 * turn + 0.6 * max(0.0, turn - 1.0), pole

    best = None
    for i in range(16):
        for flex in range(int(FLEX[0]), int(FLEX[1]) + 1, 5):
            v, _ = cost(2 * math.pi * i / 16, flex)
            if best is None or v < best[0]:
                best = (v, 2 * math.pi * i / 16, flex)
    _, phi, flex = best
    sp, sf = math.pi / 16, 5.0
    for _ in range(10):
        for dp, df in ((sp, 0), (-sp, 0), (0, sf), (0, -sf)):
            f2 = max(FLEX[0], min(FLEX[1], flex + df))
            v, _ = cost(phi + dp, f2)
            if v < best[0]:
                best = (v, phi + dp, f2)
        _, phi, flex = best
        sp, sf = sp * 0.6, sf * 0.6
    _, pole = cost(phi, flex)
    return {pole_key: tuple(round(float(x), 3) for x in pole), flex_key: round(float(flex), 1)}, best[0]


def grip(want, prev=None, prev_l=None, d_pref=1.0, **over):
    """Channels with the right fist at over["rh"], the shaft along `want`, the left fist on the shaft."""
    key = (tuple(np.round(want, 3)), None if prev is None else tuple(np.round(prev, 3)), round(d_pref, 2),
           tuple(sorted((k, tuple(np.ravel(v))) for k, v in over.items())))
    if key in _CACHE:
        return dict(over, **_CACHE[key])
    want = np.asarray(want, float) / np.linalg.norm(want)
    c = pose(**over)

    def r_score(w):
        _, d = axis(w, "RightHand", GRIP)
        return math.acos(max(-1.0, min(1.0, float(d @ want))))

    right, miss = search(c, "Right", r_score, prev)
    if miss > 0.25:
        print("grip: shaft %s misses by %.0f deg" % (np.round(want, 2), math.degrees(miss)))
    c = dict(c, **right)
    _, world, _ = solver().solve(c)
    G, D = axis(world, "RightHand", GRIP)
    S = C.rig.joint_world(world, "LeftUpperArm")
    best = None
    d_pref = d_pref if d_pref > 0 else LEFT_ON[0] + 0.2  # "behind" now means hands together just above the butt
    for d in [x / 20 for x in range(int(LEFT_ON[0] * 20), int(LEFT_ON[1] * 20) + 1)]:
        p = G + D * d
        v = abs(float(np.linalg.norm(p - S)) - REACH) + 0.25 * abs(d - d_pref)
        if best is None or v < best[0]:
            best = (v, d, p)
    lh = tuple(round(float(x), 3) for x in best[2])
    c["lh"] = lh

    def l_score(w):
        _, d = axis(w, "LeftHand", LGRIP)
        return math.acos(min(1.0, abs(float(d @ D))))

    left, _ = search(c, "Left", l_score, prev_l)
    out = dict(right, lh=lh, **left)
    _CACHE[key] = out
    return dict(over, **out)


_CHAIN = {"t": 1e9, "pole": None, "lpole": None}


def key(t, want, ease, d=1.0, **ch):
    """One two-handed key; keys are aimed in order, each preferring the elbow poles of the key before it."""
    if t <= _CHAIN["t"]:
        _CHAIN["pole"] = C.unit(np.asarray(READY["relb"], float))
        _CHAIN["lpole"] = C.unit(np.asarray(READY["lelb"], float))
    out = grip(want, prev=_CHAIN["pole"], prev_l=_CHAIN["lpole"], d_pref=d, **ch)
    _CHAIN["t"], _CHAIN["pole"], _CHAIN["lpole"] = t, C.unit(np.asarray(out["relb"], float)), C.unit(np.asarray(out["lelb"], float))
    return (t, out, ease)


def guard_pose():
    return grip(GUARD_WANT, prev=C.unit(np.asarray(READY["relb"], float)), rh=READY["rh"])


def ready():
    return pose(**guard_pose())


def hold(k, t, **ch):
    return (t, dict(k[1], **ch), "inout")


def stepped(keys):
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


def attack(name, move, keys, T, slot, **kw):
    m = T[move]
    s, a = m["startup"], m["active"]
    return WClip(name, m["total"], stepped(keys), priority="Action2", move=move, kind=m["kind"], contacts=[s + a * 0.5],
                 active=(s, a, m["arc"], m["reach"]), striker=CRESCENT, slot=SLOT + slot, **kw)


LF, RF = READY["lf"], READY["rf"]


def light1(T):
    # Crescent Reap: the shaft swung back across to his right, then the crescent reaps right to left through the
    # facing at waist height, the hips unwinding behind it.
    m = T["Guandao_L1"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, ready(), "linear"),
        key(0.09, (0.55, 0.15, -0.82), "inout", d=-1.0, rh=(0.6, 0.35, -0.55), pelR=(0, -48, 0), chest=(-6, -34, 0)),
        key(s + a * 0.5, (-0.25, -0.05, -0.97), "snap", d=1.0, rh=(0.65, 0.2, -0.85), pelR=(0, -20, 0), chest=(-12, -12, 0),
            pel=(0.0, -0.4, -0.22), lf=(-0.55, -0.9, 0, -18, 0)),
        key(s + a, (-0.75, -0.05, -0.65), "linear", d=1.0, rh=(0.5, 0.2, -0.8), pelR=(0, -6, 0), chest=(-12, 4, 0)),
        key(s + a + 0.07, (-0.9, 0.05, -0.4), "settle", d=1.0, rh=(0.45, 0.25, -0.7), pelR=(0, -2, 0), chest=(-10, 8, 0), pel=(0.0, -0.36, -0.1)),
        (m["total"], ready(), "inout"),
    ]
    return attack("Warden_L1", "Guandao_L1", keys, T, "Light1", feet_free=[(0.03, m["total"] - 0.03)],
                  notes="Crescent Reap: right-to-left reaping sweep at waist height on a short step.")


def light2(T):
    # Returning Tide: the crescent carried on round to his left, then swept back left to right, rising a little.
    m = T["Guandao_L2"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, ready(), "linear"),
        key(0.09, (-0.8, 0.2, -0.55), "inout", d=1.0, rh=(0.55, 0.15, -0.65), pelR=(0, -4, 0), chest=(-8, 10, 0)),
        key(s + a * 0.5, (0.2, 0.12, -0.97), "snap", d=1.0, rh=(0.7, 0.25, -0.8), pelR=(0, -30, 0), chest=(-10, -20, 0),
            pel=(0.0, -0.4, -0.2), rf=(0.6, 0.15, 0, 28, 0)),
        key(s + a, (0.65, 0.2, -0.73), "linear", d=-1.0, rh=(0.75, 0.3, -0.6), pelR=(0, -44, 0), chest=(-8, -30, 0)),
        key(s + a + 0.08, (0.75, 0.3, -0.55), "settle", d=-1.0, rh=(0.75, 0.35, -0.45), pelR=(0, -46, 0), chest=(-6, -32, 0)),
        (m["total"], ready(), "inout"),
    ]
    return attack("Warden_L2", "Guandao_L2", keys, T, "Light2", feet_free=[(0.03, m["total"] - 0.03)],
                  notes="Returning Tide: left-to-right return sweep, rising, the hands sliding on the shaft.")


def light3(T):
    # Heaven-Splitting Cleave: the crescent raised high over the bell, then brought straight down the centre line on a
    # lunging step.
    m = T["Guandao_L3"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, ready(), "linear"),
        key(0.12, (-0.1, 0.9, -0.42), "inout", d=-0.9, rh=(0.6, 0.9, -0.45), pelR=(0, -24, 0), chest=(4, -14, 0), pel=(0.0, -0.24, 0.12)),
        key(s + a * 0.5, (-0.08, -0.25, -0.96), "snap", d=-0.9, rh=(0.45, 0.45, -1.0), pelR=(0, -20, 0), chest=(-18, -10, 0),
            pel=(0.0, -0.55, -0.45), lf=(-0.55, -1.15, 0, -18, 0)),
        key(s + a, (-0.05, -0.55, -0.83), "linear", d=-0.9, rh=(0.45, 0.25, -0.95), chest=(-22, -10, 0)),
        key(s + a + 0.1, (0.0, -0.7, -0.7), "out", d=-0.9, rh=(0.5, 0.1, -0.85), pel=(0.0, -0.46, -0.3), chest=(-16, -12, 0)),
        (m["total"], ready(), "inout"),
    ]
    return attack("Warden_L3", "Guandao_L3", keys, T, "Light3", feet_free=[(0.03, m["total"] - 0.03)],
                  notes="Heaven-Splitting Cleave: overhead gather and a straight cleave down the centre line.")


def heavy(T):
    # Grave-Digger's Arc: a long coil with the crescent high behind his right shoulder, then a stamping step carries
    # a huge diagonal arc from high right down through the target to low left.
    m = T["Guandao_Heavy"]
    s, a = m["startup"], m["active"]
    coil = key(0.22, (0.5, 0.75, 0.43), "inout", d=-1.0, rh=(0.75, 0.62, -0.3), pelR=(0, -56, 0), chest=(4, -30, 0), pel=(0.0, -0.3, 0.25))
    keys = [
        (0, ready(), "linear"),
        coil,
        hold(coil, 0.3, pelR=(0, -54, 0)),
        key(s, (0.4, 0.55, -0.73), "snap", d=-1.0, rh=(0.6, 0.75, -0.75), pelR=(0, -40, 0), chest=(0, -22, 0)),
        key(s + a * 0.5, (-0.25, -0.3, -0.92), "linear", d=1.0, rh=(0.55, 0.3, -0.95), pelR=(0, -14, 0), chest=(-18, -4, 0),
            pel=(0.0, -0.58, -0.45), lf=(-0.55, -1.1, 0, -18, 0)),
        key(s + a, (-0.65, -0.45, -0.6), "linear", d=1.0, rh=(0.45, 0.15, -0.85), chest=(-20, 8, 0)),
        key(s + a + 0.14, (-0.75, -0.6, -0.25), "out", d=1.0, rh=(0.35, 0.0, -0.7), chest=(-16, 10, 0), pel=(0.0, -0.5, -0.35)),
        (m["total"], ready(), "inout"),
    ]
    return attack("Warden_Heavy", "Guandao_Heavy", keys, T, "Heavy", feet_free=[(0.22, m["total"] - 0.05)],
                  notes="Grave-Digger's Arc: long coil behind the right shoulder, stamping step, high-right to low-left arc.")


def running(T):
    # Burial Thrust: the spade drawn back level at the hip as he charges, then the crescent driven straight out.
    m = T["Guandao_Running"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, ready(), "linear"),
        key(0.13, (-0.05, 0.05, -1.0), "inout", d=1.0, rh=(0.85, 0.05, 0.1), pelR=(0, -40, 0), chest=(-10, -26, 0), pel=(0.0, -0.42, 0.12)),
        key(s + a * 0.5, (-0.05, 0.02, -1.0), "snap", d=1.0, rh=(0.6, 0.15, -1.05), pelR=(0, -28, 0), chest=(-16, -16, 0),
            pel=(0.0, -0.55, -0.7), lf=(-0.55, -1.4, 0, -18, 0), rf=(0.6, 0.8, 0.1, 28, -20)),
        key(s + a, (-0.05, 0.02, -1.0), "linear", d=1.0, rh=(0.58, 0.15, -1.1)),
        key(s + a + 0.1, (-0.1, 0.3, -0.95), "out", d=1.0, rh=(0.65, 0.1, -0.75), pel=(0.0, -0.42, -0.35)),
        (m["total"], ready(), "inout"),
    ]
    return attack("Warden_Running", "Guandao_Running", keys, T, "Running", feet_free=[(0.03, m["total"] - 0.03)],
                  notes="Burial Thrust: drawn back at the hip on the charge, a long lunging thrust of the crescent.")


def art(T):
    # Tolling Cyclone: he sinks and winds the crescent far round to his right, then unwinds it through the full arc
    # in front of him and carries it on round past his left side.
    m = T["Guandao_Art"]
    s, a = m["startup"], m["active"]
    wind = key(0.18, (0.85, 0.1, -0.5), "inout", d=-1.1, rh=(0.65, 0.3, -0.5), pelR=(0, -62, 0), chest=(-6, -34, 0), pel=(0.0, -0.48, 0.2))
    keys = [
        (0, ready(), "linear"),
        wind,
        hold(wind, 0.24),
        key(s + a * 0.3, (0.6, 0.05, -0.8), "linear", d=-1.0, rh=(0.85, 0.25, -0.55), pelR=(0, -40, 0), chest=(-10, -22, 0)),
        key(s + a * 0.5, (-0.25, 0.0, -0.97), "linear", d=1.0, rh=(0.5, 0.35, -0.7), pelR=(0, -18, 0), chest=(-12, -6, 0), pel=(0.0, -0.55, -0.35),
            lf=(-0.55, -0.95, 0, -18, 0)),
        key(s + a * 0.8, (-0.75, 0.0, -0.66), "linear", d=1.0, rh=(0.4, 0.38, -0.55), pelR=(0, 2, 0), chest=(-10, 12, 0)),
        key(s + a + 0.15, (-0.95, 0.05, -0.2), "settle", d=1.0, rh=(0.3, 0.25, -0.65), pelR=(0, 8, 0), chest=(-8, 16, 0), pel=(0.0, -0.45, -0.25)),
        (m["total"], ready(), "inout"),
    ]
    return attack("Warden_Art", "Guandao_Art", keys, T, "WeaponArt", feet_free=[(0.15, m["total"] - 0.05)],
                  notes="Tolling Cyclone: deep wind to the right, the crescent unwinds through the whole front arc.")


def signature():
    # Hollow Toll: he brings the spade up crosswise in front of his bell, draws it back out as a ringer draws the
    # striker log, holds, then drives the haft into the bell's face on the shockwave's Windup (1.1 s), the bell
    # rocking back from the blow, and lets the spade fall back to the guard.
    W = 1.1
    cross = dict(pelR=(0, -6, 0), chest=(-4, -4, 0), lookW=0.3, lf=(-0.55, -0.35, 0, -12, 0), rf=(0.6, 0.35, 0, 18, 0))
    draw = key(0.55, (-1.0, 0.05, 0.0), "inout", d=1.0, rh=(0.6, 1.15, -1.02), chest=(6, -4, 0), neck=(-8, 0, 0), pel=(0.0, -0.25, 0.1),
               **{k: v for k, v in cross.items() if k != "chest"})
    keys = [
        (0, ready(), "linear"),
        key(0.3, (-1.0, 0.1, -0.1), "inout", d=1.0, rh=(0.6, 1.0, -1.1), neck=(0, 0, 0), pel=(0.0, -0.3, 0.05), **cross),
        draw,
        hold(draw, 0.95, rh=(0.6, 1.17, -1.0), pel=(0.0, -0.22, 0.14)),
        key(W, (-1.0, 0.0, 0.0), "snap", d=1.0, rh=(0.6, 1.25, -0.76), chest=(-10, -4, 0), neck=(-14, 0, 0), pel=(0.0, -0.34, -0.12),
            **{k: v for k, v in cross.items() if k != "chest"}),
        key(W + 0.12, (-1.0, -0.05, 0.05), "out", d=1.0, rh=(0.6, 1.15, -1.05), chest=(-4, -4, 0), neck=(-22, 0, 0), pel=(0.0, -0.36, 0.0),
            **{k: v for k, v in cross.items() if k != "chest"}),
        key(1.45, (-0.6, 0.3, -0.75), "inout", d=1.0, rh=(0.75, 0.3, -0.7), chest=(-8, -14, 0), neck=(4, 0, 0)),
        (1.8, ready(), "inout"),
    ]
    return WClip("Warden_Signature", 1.8, keys, priority="Action2", contacts=[W], slot=SLOT + "Signature", feet_free=[(0.2, 1.6)],
                 notes="Hollow Toll: the haft swung crosswise into his own bell on the shockwave's Windup.")


def idle():
    base = guard_pose()
    k = [(0.0, ready(), "inout")]
    for i, (dy, ch) in enumerate([(-0.04, 2), (0.0, 0), (-0.025, -2)]):
        k.append(key((i + 1) * 0.9, GUARD_WANT, "inout", rh=(0.8, -0.1 + dy, -0.35), pel=(0.0, -0.32 + dy, 0.05),
                     chest=(-8 + ch * 0.5, -22 + ch, 0)))
    k[-1] = (3.6, ready(), "inout")
    del base
    return WClip("Warden_Idle", 3.6, k, loop=True, priority="Movement", slot=SLOT + "Idle",
                 notes="Guard loop: bladed, the crescent raised forward on the left of the line, slow heavy breath.")


def move():
    keys = [(0.0, ready(), "inout"), key(0.4, GUARD_WANT, "inout", rh=(0.8, -0.14, -0.35), chest=(-10, -20, 0)), (0.8, ready(), "inout")]
    return WClip("Warden_Move", 0.8, keys, loop=True, priority="Movement", mask=UPPER, slot=SLOT + "Move",
                 notes="Upper-body guard carried over the gait.")


WALK_SPEED = 5.6
RUN_SPEED = 9.5


def ride(carry, **mean):
    """A two-handed carry for a gait: both fists' targets re-expressed in UpperTorso space (rspace = lspace = 1) at the
    cycle's mean pose, so the spade rides the torso's sway instead of the arms straining after fixed root points."""
    c = pose(**dict(carry, **mean))
    _, world, _ = solver().solve(c)
    inv = np.linalg.inv(world["UpperTorso"])
    local = {k: tuple(round(float(x), 4) for x in (inv @ np.append(np.asarray(c[k], float), 1))[:3]) for k in ("rh", "lh")}
    return dict(carry, rspace=1.0, lspace=1.0, **local)


def cycle(name, length, velocity, duty, lift, feet, body, slot, notes, pitch_off=-16.0):
    keys = [(t, pose(**dict(body(t / length), lf=lf, rf=rf)), "linear")
            for t, lf, rf in C.gait(length, velocity, duty, lift, feet, pitch_off=pitch_off)]
    return WClip(name, length, keys, loop=True, priority="Movement", slot=SLOT + slot, velocity=velocity, notes=notes)


def walk():
    # Ponderous walk: the spade shouldered at the port, the hump rolling over each heavy step.
    mean = dict(pel=(0.0, -0.56, 0.03), pelR=(0, -8, 0), chest=(-8, -8, 0))
    carry = ride(grip((-0.45, 0.6, -0.66), prev=C.unit(np.asarray(READY["relb"], float)), rh=(0.75, 0.05, -0.45), **mean), **mean)
    feet = {"lf": (-0.46, 0.1, 0, -8, 0), "rf": (0.46, -0.1, 0, 8, 0)}

    def body(u):
        c2, c1 = math.cos(4 * math.pi * u), math.cos(2 * math.pi * u)
        return dict(carry, pel=(-0.06 * math.cos(2 * math.pi * (u - 0.3)), -0.56 - 0.03 * c2, 0.03),
                    pelR=(0, -8 - 7 * c1, 3 * math.sin(2 * math.pi * u)), chest=(-8 + 2 * c2, -8 + 5 * c1, 2 * math.sin(2 * math.pi * u)),
                    neck=(6, -3 * c1, 0))

    return cycle("Warden_Walk", 45 / 60, (0.0, -WALK_SPEED), 0.62, 0.2, feet, body, "Walk",
                 "Ponderous walk at %.1f studs/s (scale 1): heavy planted feet, the hump rolling, spade at the port." % WALK_SPEED)


def run():
    # Lumbering charge: leaned in, the spade carried low across the body, crescent forward.
    mean = dict(pel=(0.0, -0.67, -0.12), pelR=(-8, -14, 0), chest=(-16, -12, 0))
    carry = ride(grip((-0.35, 0.15, -0.92), prev=C.unit(np.asarray(READY["relb"], float)), rh=(0.8, -0.3, -0.3), **mean), **mean)
    feet = {"lf": (-0.42, 0.05, 0, -5, 0), "rf": (0.42, -0.05, 0, 5, 0)}

    def body(u):
        c2, c1 = math.cos(4 * math.pi * u), math.cos(2 * math.pi * u)
        return dict(carry, pel=(-0.06 * math.cos(2 * math.pi * (u - 0.2)), -0.67 + 0.05 * math.cos(4 * math.pi * (u - 0.18)), -0.12),
                    pelR=(-8, -14 - 9 * c1, 0), chest=(-16 + 2 * c2, -12 + 8 * c1, 0), neck=(14, -6 * c1, 0))

    return cycle("Warden_Run", 42 / 60, (0.0, -RUN_SPEED), 0.4, 0.42, feet, body, "Run",
                 "Lumbering charge at %.1f studs/s (scale 1): leaned in, spade low across the body." % RUN_SPEED, pitch_off=-22.0)


def guard_keys(t, ease, **ch):
    g = dict(rh=(0.65, 0.95, -0.8), pelR=(0, -12, 0), chest=(-6, -8, 0), neck=(6, 0, 0))
    g.update(ch)
    return key(t, (-0.97, 0.22, -0.1), ease, d=1.0, **g)


def guard():
    first = guard_keys(0.0, "inout")
    keys = [first, guard_keys(0.8, "inout", chest=(-7, -9, 0)), (1.6, first[1], "inout")]
    return WClip("Warden_Guard", 1.6, keys, loop=True, priority="Action", mask=UPPER, slot=SLOT + "Guard",
                 notes="Haft guard: the shaft held crosswise before the bell in both fists.")


def guard_impact():
    keys = [guard_keys(0.0, "linear"), guard_keys(0.07, "snap", rh=(0.65, 1.05, -0.55), chest=(4, -6, 0), neck=(-8, 0, 0)),
            guard_keys(0.34, "settle")]
    return WClip("Warden_GuardImpact", 0.34, keys, priority="Action2", mask=UPPER, slot=SLOT + "GuardImpact",
                 notes="A blocked blow drives the haft back against the bell, then it re-settles.")


def hit_light():
    keys = [(0.0, ready(), "linear"),
            key(0.07, (-0.2, 0.7, -0.68), "snap", rh=(0.85, 0.15, -0.2), chest=(8, -28, 4), neck=(-14, -16, 0), pel=(0.0, -0.28, 0.18)),
            key(0.2, (-0.28, 0.5, -0.82), "out", rh=(0.8, -0.05, -0.3), chest=(0, -24, 2), neck=(-4, -6, 0)),
            (0.4, ready(), "inout")]
    return WClip("Warden_Hit_Light", 0.4, keys, priority="Action3", slot=SLOT + "Hitstun_Light",
                 notes="The bell rocks back, the crescent knocked high, then back on the line.")


def hit_heavy():
    keys = [(0.0, ready(), "linear"),
            key(0.09, (-0.1, 0.85, -0.5), "snap", rh=(0.9, 0.3, 0.0), chest=(16, -24, 0), neck=(-18, 0, 0), pel=(0.0, -0.26, 0.4),
                lf=(-0.55, -0.3, 0, -18, 0)),
            key(0.32, (-0.3, -0.45, -0.84), "inout", rh=(0.75, -0.25, -0.5), chest=(-20, -18, 0), neck=(12, 0, 0), pel=(0.0, -0.55, 0.4)),
            key(0.55, (-0.3, 0.2, -0.93), "out", chest=(-12, -20, 0), neck=(6, 0, 0), pel=(0.0, -0.4, 0.2), rh=(0.8, -0.1, -0.35)),
            (0.75, ready(), "inout")]
    return WClip("Warden_Hit_Heavy", 0.75, keys, priority="Action3", slot=SLOT + "Hitstun_Heavy", feet_free=[(0.0, 0.75)],
                 notes="Rocked back a step, doubles over the haft, recovers the guard.")


def stance_broken():
    b = dict(pel=(0.0, -0.55, 0.2), pelR=(0, -14, 0), chest=(-26, -10, 4), neck=(20, 0, 6), rh=(0.75, -0.5, -0.55), lookW=0.2,
             lf=(-0.55, -0.6, 0, -18, 0), rf=(0.6, 0.45, 0, 28, 0))
    first = key(0.0, (-0.2, -0.75, -0.63), "inout", **b)
    keys = [first, key(0.9, (-0.22, -0.73, -0.65), "inout", **dict(b, chest=(-22, -6, -4), neck=(16, 4, -8), pel=(0.04, -0.6, 0.2))),
            (1.8, first[1], "inout")]
    return WClip("Warden_StanceBroken", 1.8, keys, loop=True, priority="Action4", slot=SLOT + "StanceBroken",
                 notes="Posture break: the crescent sags to the earth, the bell lolls forward, the punish window.")


def death():
    knees = dict(lknee=(0, -0.3, -1), rknee=(0, -0.3, -1), lf=(-0.55, -0.6, 0, -18, -40), rf=(0.6, 0.45, 0, 28, -60))
    keys = [(0.0, ready(), "linear"),
            key(0.14, (-0.1, 0.7, -0.7), "snap", chest=(14, -16, 0), neck=(-16, 0, 0), pel=(0.0, -0.28, 0.2), rh=(0.85, 0.2, -0.2), lookW=0.3),
            key(0.6, (-0.15, -0.9, -0.4), "inout", chest=(-30, -6, 6), neck=(30, 0, 10), pel=(0.0, -1.05, 0.1), rh=(0.75, -0.9, -0.6),
                lookW=0.0, **knees),
            key(1.0, (-0.1, -0.97, -0.2), "settle", chest=(-40, -6, 8), neck=(36, 0, 12), pel=(0.0, -1.2, 0.05), rh=(0.75, -1.05, -0.6), **knees)]
    return WClip("Warden_Death", 1.0, keys, priority="Action4", slot=SLOT + "Death", feet_free=[(0.0, 1.0)],
                 notes="Knees give, the crescent drives into a grave, the bell drops; held while the body burns away.")


def library():
    T = C.timing()
    return [idle(), move(), walk(), run(), light1(T), light2(T), light3(T), heavy(T), running(T), art(T), signature(), guard(),
            guard_impact(), hit_light(), hit_heavy(), stance_broken(), death()]
