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


def carry(keys, t0, t1, t2, t3, off):
    """(2026-11-09) Carries the fist of a cut's per-frame keys by `off` (rig units, his frame): eased in from t0 to t1, held to t2, eased out by t3.
    A cut's arc keeps its hands on one small arc in front of him; where the haft then turns across his trunk in a frame or two, the butt has to
    go round him, and the solver can only shift each frame to the nearer side, so the fist hopped from one side to the other in a frame."""
    out = []
    for t, kw, ease in keys:
        if "rp" in kw and t0 < t < t3:
            w = L.smooth01((t - t0) / max(t1 - t0, 1e-6)) if t < t1 else (1.0 if t <= t2 else L.smooth01((t3 - t) / max(t3 - t2, 1e-6)))
            kw = {**kw, "rp": tuple(np.asarray(kw["rp"], float) + w * np.asarray(off, float))}
        out.append((t, kw, ease))
    return out


# ---------------------------------------------------------------- planes a blade can cut in, seen by him: where it comes from
FROM_HIGH_LEFT = (-0.72, 0.7, 0.0)      # kesa: his left shoulder down through to his right hip
FROM_HIGH_RIGHT = (0.72, 0.7, 0.0)      # the return: right shoulder to left hip
FROM_LOW_LEFT = (-0.75, -0.66, 0.0)     # rising: left hip up through his right shoulder
FROM_LOW_RIGHT = (0.75, -0.66, 0.0)
FROM_OVERHEAD = (0.0, 1.0, 0.15)
FROM_LEFT = (-1.0, 0.0, 0.2)            # a flat wheel
FROM_RIGHT = (1.0, 0.0, 0.2)


RSL, LSL = -1.8, 1.25    # the guard's grip: right hand 1.0 from the butt, left hand 1.25 nearer the blade (shoulder width is 1.44)
PINWHEEL_OUT = (0.25, 0.05, -0.1)     # (2026-11-07) the pinwheels' fist, out to his right and forward, so the spinning haft passes outside his arm (pinwheel_fist)
GUARD = {}     # the guard this phase stands in; a first cut grows out of it


def arc(t0, tc, t1, th0, th1, source, aim=(0.0, -6.0), centre=(0.32, 0.22, -1.2), span=1.2, rsl=RSL, whip=2.2, settle=2.4, hover=0.0, link=False, enter=None):
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
            enter = max(0.1, 0.3 * (tc - t0)) if enter is None else enter     # (2026-11-09) enter: seconds to pick the blade up, where a cut asks for its own
            s = 1.0 if link else L.smooth01((t - t0) / enter)     # a linked cut grows out of the last one's ending, not out of the guard
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
                rsl_k, lsl_k = RSL, LSL + (span - LSL) * s
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
    # Middle guard (2026-11-06 grip pass): the old guard parked the right fist beside the hip with the blade trailing low, and the left hand could not
    # reach its keyed spot, so the solver slid it back to 0.50 from the fist and the grip read one-handed. Here the right fist is rear and in front
    # of the hip, the left hand leads by LSL (about shoulder width, 1.44), the hips stand half-turned and the blade points at the opponent's waist.
    RHAFT = H(-14, -6)
    YAW = dict(pel=-30.0, chest=-14.0, neck=38.0)
    FEET_R = (0.2, 0.44, 0, -24, 0)
    FEET_L = (0.0, -0.4, 0, 2, 0)
    READY = dict(pel=(0.02, -0.07, 0.02), pelR=(3, YAW["pel"], 0), chest=(2, YAW["chest"], 0), neck=(-1, YAW["neck"], 0), rf=FEET_R, lf=FEET_L, lua=(0, 0, 0), lfa=(0, 0, 0), lha=(0, 0, 0), lhw=1.0, ltw=0.0, rsl=RSL, lsl=LSL,
                 rp=(0.4, 0.25, -0.35), haft=RHAFT, face=E(RHAFT), relb=(0.75, -0.55, 0.35), lelb=(-0.6, -0.75, 0.25), rknee=(0.12, 0, -1.0), lknee=(-0.05, 0, -1.0), rlk=0.0)
    GUARD.update(READY)

    def chest_frame(k, corrupt=True):
        """(2026-11-08) His chest's frame under a key: how the UpperTorso is turned and where its joint is, phase 2's corruption layer (Clip.controls)
        included unless the clip goes without it (corrupt=False: the transform)."""
        pel, pelR, chest = (np.array(k[n], float) for n in ("pel", "pelR", "chest"))
        if phase == 2 and corrupt:
            pel = pel + np.array([0, -0.1, -0.03])
            pelR = pelR * np.array([1, 1 + L.CORRUPT_TWIST[0], 1]) + np.array([6.0, 0, 0])
            chest = chest * np.array([1, 1 + L.CORRUPT_TWIST[1], 1]) + np.array([8.0, 0, 0])
        lt = rg.pivoted(np.eye(4), "LowerTorso", L.homog(L.euler(pelR), pel))
        ut = rg.pivoted(lt, "UpperTorso", L.homog(L.euler(chest)))
        return ut[:3, :3], (ut @ np.append(rg.JOINT["UpperTorso"], 1))[:3]

    def melee(name, keys, notes, feet_free=(), **kw):
        length, contact, active, arc_, reach, lunge = MELEE[name]
        return clip(name, length, keys, contacts=[contact], move=name, notes=notes, active=(contact, active, arc_, reach, lunge), feet_free=feet_free, **kw)

    def body(t, ease="io", yaw=0.0, chest=None, pitch=4.0, roll=0.0, sink=-0.1, fwd=0.0, side=0.0, look=None, **kw):
        ch = yaw * 0.7 if chest is None else chest
        return K(t, ease, pel=(side, sink, 0.02 + fwd), pelR=(pitch, yaw, roll), chest=(pitch * 0.8, ch, -roll * 0.5), neck=(-pitch * 1.3, -(yaw + ch) * (0.9 if look is None else look), roll * 0.2), **kw)

    # ---------------------------------------------------------------- ordinary swings: 0.15 s to the contact, so they start from the guard's own blade line
    def crescent_reap():
        # (2026-11-09) phase 2 turns his hips and chest 20 and 30 deg further to his right through the swing (the head turned back by 0.9 of it, eyes
        # on the target): its corruption reaches the lead hand out past his right side, and turned as phase 1 the left upper arm went 0.26 into his
        # chest there (f6-9, shen_lib.validate). Turned with it, 0.17 (rest 0.14) and the contact within 0.2 of where it was. Through the follow-through
        # the head lets the turn carry it 18 deg past the target (look 0.77): held on it, his neck would turn 122 deg on his chest (the library's
        # widest is 107, Abbot Sweep). Turned at the hips more than the chest instead, or with phase 1's wind-up kept: 0.20-0.22 (f2-5)
        dy, dc = (-20, -30) if phase == 2 else (0, 0)
        return melee("Guandao_L1", [K(0, **READY), body(0.07, "out", yaw=12 + dy, chest=20 + dc, sink=-0.14, fwd=0.04), body(0.15, "whip", yaw=-8 + dy, chest=-16 + dc, sink=-0.22, fwd=-0.38, lf=(0.0, -0.95, 0, 0, 0), rf=(0.16, 0.34, 0, -30, 0)),
                                    body(0.27, "out", yaw=-34 + dy, chest=-52 + dc, sink=-0.26, fwd=-0.46, roll=-3, look=0.77 if phase == 2 else None, lf=(0.0, -0.95, 0, 0, 0), rf=(0.14, 0.3, 0, -46, 0)), K(0.4, "io", **READY)]
                     + arc(0, 0.15, 0.3, 74, 84, FROM_HIGH_LEFT, aim=(2, -12)) + [K(0.4, "io", rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL)],
                     "Crescent Reap: left shoulder to right hip, hips driving first, the rear foot pivoting behind them.", feet_free=[(0, 0.4)])

    def returning_tide():
        return melee("Guandao_L2", [K(0, **READY), body(0.07, "out", yaw=16, chest=24, sink=-0.26, fwd=0.02), body(0.15, "whip", yaw=-6, chest=-12, sink=-0.16, fwd=-0.3, rf=(0.1, -0.2, 0, -14, 0), lf=(0.02, -0.2, 0, 8, 0)),
                                    body(0.29, "out", yaw=-30, chest=-48, sink=-0.05, fwd=-0.38, pitch=-2, rf=(0.1, -0.2, 0, -30, 0), lf=(0.02, -0.2, 0, 8, 0)), K(0.4167, "io", **READY)]
                     # (2026-11-09) the follow-through carries the fist out to his right and forward (carry): as the blade climbs past his right shoulder the
                     # butt comes down across his front, and with the fist left on the arc in front of his middle it went through his belly, cleared behind
                     # his right hip on f6 and in front on f7 (phase 1 fist pop 0.29). Phase 2's broader, hunched trunk takes it further out and back to his
                     # side: by f8 his chest faces his right (78 deg round), so a fist carried forward was across its front and the straight arm lay 0.30
                     # in it; carried to where the chest faces, 0.17 (the blow 0.08 from where it was)
                     + carry(arc(0, 0.15, 0.3, 66, 98, FROM_LOW_LEFT, aim=(2, 0)), 0.12, 0.2, 0.3, 0.4167, (0.65, 0.0, -0.4) if phase == 1 else (1.5, 0.1, 0.2))
                     + [K(0.4167, "io", rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL)],
                     "Returning Tide: the blade drops to his left hip and climbs through to the right shoulder off the rear foot's step.", feet_free=[(0, 0.4167)])

    def heaven_cleave():
        # (2026-11-09) phase 2 bows 6 deg less into the cleave: its corruption already pitches the chest 8 deg and the hips 6 further, so at the blow
        # his chest leaned 40 deg down over hands at his belly and folded onto the right arm (0.19, f6, whatever the elbow); now 0.12, the blow as it was
        return melee("Guandao_L3", [K(0, **READY), body(0.09, "out", yaw=4, chest=6, pitch=-6, sink=-0.03, fwd=0.1), body(0.183, "whip", yaw=-10, chest=-14, pitch=12 if phase == 1 else 6, sink=-0.32, fwd=-0.5, lf=(0.0, -1.05, 0, 0, 0), rf=(0.16, 0.3, 0, -28, 0)),
                                    body(0.33, "out", yaw=-12, chest=-16, pitch=18 if phase == 1 else 12, sink=-0.42, fwd=-0.58, lf=(0.0, -1.05, 0, 0, 0), rf=(0.16, 0.3, 0, -28, 0)), K(0.5167, "io", **READY)]
                     + arc(0, 0.183, 0.33, 118, 46, FROM_OVERHEAD, aim=(0, -10), centre=(0.2, 0.34, -1.25)) + [K(0.5167, "io", rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL)],
                     "Heaven-Splitting Cleave: up over the head and straight down the server's line, a long step under it.", feet_free=[(0, 0.5167)])

    def green_dragon():
        # (2026-11-09) phase 2 winds 82 deg, not 100, and bows less at the top of it: its corruption already pitches the chest 8 deg and the hips 6, and
        # wound with both hands still out in front the lead arm crossed his chest (0.23-0.30, f7-9). Its blow eases in ("io"): whipped, the chest's
        # unwind folded onto the right arm at the contact. The follow-through is carried 0.6 out to his right and 1.0 back, round with his chest:
        # unwound 116 deg past the hands, the right arm held the glaive across his chest (0.37 keyed, f15-21, cleared or not by the bake by chance)
        c = melee("Guandao_Heavy", [K(0, **READY), body(0.14, "io", yaw=26, chest=38, sink=-0.16, fwd=0.1), body(0.31, "io", yaw=42 if phase == 1 else 36, chest=58 if phase == 1 else 46, sink=-0.2, fwd=0.16, pitch=-2 if phase == 1 else -9, rf=(0.2, 0.5, 0, -6, 0)),
                                       body(0.383, "whip" if phase == 1 else "io", yaw=4, chest=-4, sink=-0.3, fwd=-0.5, pitch=9, lf=(0.0, -1.15, 0, -2, 0), rf=(0.16, 0.34, 0, -32, 0)),
                                       body(0.56, "out", yaw=-46, chest=-70, sink=-0.36, fwd=-0.62, pitch=11, roll=-4, lf=(0.0, -1.15, 0, -2, 0), rf=(0.12, 0.26, 0, -62, 0)), K(0.8333, "io", **READY)]
                     # (2026-11-09) phase 2: 0.3 further forward and 0.18 out to his right with the lunge (hips 0.5-0.62 forward through the sweep):
                     # his broader body's right arm 0.27 -> 0.18 in his chest at the contact and the lead hand's regrip no longer jumps (0.26 at f20); the blow lands
                     # where it did (0.07). Further (0.6, -1.9) turned the wrist 118 deg and put the arm 0.32 in
                     + carry(arc(0.06, 0.383, 0.6, 130, 110, (-0.92, 0.38, 0.0), aim=(0, -14), whip=3.4, settle=4.4, centre=(0.5, 0.22, -1.7) if phase == 2 else (0.32, 0.22, -1.4)), 0.42, 0.56, 0.6, 0.65, (0.6, 0.0, 1.0) if phase == 2 else (0.0, 0.0, 0.0)) + [K(0.8333, "io", rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL)],
                     "Green Dragon Reaping: winds until his back shows, then hips, chest and arms unwind in that order, and the blade carries his weight past the target.", feet_free=[(0, 0.8333)])
        # (2026-11-07) the lead hand runs down the haft into the blow (a sliding grip), then lets go as the blade carries on past him: no wrist can stay
        # on the wood through that follow-through (15-50 deg past its range). It swings free for balance and catches the haft again as he settles
        c.slide_floor = 0.6 if phase == 1 else None     # phase 2 reaches further: sliding in shortens its blow past the body
        # (2026-11-07, later) phase 1 lets go sooner (0.34-0.42, as the whip starts): held to 0.47 the haft's butt end swept through his left arm
        # (0.11 deep) and no elbow could keep it out; free, the arm swings clear of it (shen_lib.clear_free_arm)
        # (2026-11-08) the regrip's weights on keys of their own, over 5 frames (0.64-0.8, linear: the curve between keys eases them already): keyed
        # over 3.6 frames with a fast end, the grip and reach arms, 95-178 deg apart at the forearm, swapped inside one frame. The reach targets are as
        # they were, and both phases let go as before (sooner or later moved the blow's contact)
        let_go = 0.34 if phase == 1 else 0.47
        off = [K(0.34, "io", lhw=1.0, ltw=0.0), K(0.42, "out", lhw=0.0, ltw=1.0, lt=(-0.5, -1.0, -0.45), lelb=(-0.75, -0.25, 0.4), lha=(-10, 0, 0))] if phase == 1 else \
              [K(0.47, "io", lhw=1.0, ltw=0.0), K(0.55, "out", lhw=0.0, ltw=1.0, lt=(-0.5, -1.0, -0.45), lelb=(-0.75, -0.25, 0.4), lha=(-10, 0, 0))]
        c.keys = sorted([(t, {k: v for k, v in kw.items() if not (k == "lhw" and let_go < t < 0.8)}, e) for t, kw, e in c.keys] + off +     # "lin": the curve between keys eases them already
                        [K(0.64, "lin", lhw=0.0, ltw=1.0), K(0.68, "io", lt=(-0.4, -1.05, -0.6)), K(0.8, "lin", lhw=1.0, ltw=0.0)], key=lambda k: k[0])
        return c

    def charging_cut():
        start = dict(READY, pel=(0, -0.12, -0.05), pelR=(12, -10, 0), chest=(8, -8, 0), neck=(-16, 16, 0), rf=(0.1, 0.5, 0.2, -6, -18), lf=(0.0, -0.3, 0, 2, 0))
        return melee("Guandao_Running", [K(0, "lin", **start), body(0.1, "out", yaw=14, chest=22, pitch=8, sink=-0.2, fwd=-0.2, rf=(0.14, 0.15, 0.12, -14, 0), lf=(0, -0.55, 0, 2, 0)),
                                         body(0.217, "whip", yaw=-8, chest=-18, pitch=10, sink=-0.26, fwd=-0.6, lf=(0, -1.2, 0, 0, 0), rf=(0.14, 0.42, 0, -28, 0)),
                                         body(0.36, "out", yaw=-30, chest=-46, pitch=7, sink=-0.26, fwd=-0.66, lf=(0, -1.2, 0, 0, 0), rf=(0.14, 0.05, 0.15, -18, 0)), K(0.6, "io", **READY)]
                     # (2026-11-09) phase 2's cut goes forward with the run's lunge (hips 0.6 forward at the contact): his broader chest came onto his
                     # arms holding it in front of his feet (right 0.18, left 0.23, f5-8); the blade lands 0.27 further along the lunge
                     + arc(0, 0.217, 0.4, 92, 80, FROM_LOW_LEFT, aim=(0, -2), centre=(0.32, 0.22, -1.7) if phase == 2 else (0.32, 0.22, -1.2))
                     + [K(0.6, "io", rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL)],
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

        # (2026-11-08) the fist and haft are held in his chest's own frame. They were keyed around the body's axis, 0.35 out along the blade's heading:
        # that is the middle of his chest, in both phases, on every frame. The solver had to push the fist out of him and chose the nearer side:
        # phase 1 front-right until frame 17, then across to his left (the right arm 0.11-0.17 through his chest after the hop); phase 2, broader
        # and pitched forward, left and behind from frame 5, the right arm 0.37 through his chest for the whole spin. Where phase 1's solver
        # held them there (front-right, 0.45 out) phase 2's right forearm lay along the haft's butt (0.05-0.07 into it on every frame; its butt is
        # too short for the fist to slide down) and the haft tilted to and fro to pass it. Here, chosen by a scan of holds in both phases' chests:
        # both arms out ahead of him, the fist 0.85 in front of his chest, the haft 55 deg across to his left and 12 deg up, so the lead hand reaches
        # its spot (1.63 from its shoulder) and the butt passes clear under the forearm; easing into the guard's own hold as he settles.
        Rr, ar = chest_frame(READY)
        ready_q, ready_h = (np.array(READY["rp"], float) - ar) @ Rr, L.unit(np.array(READY["haft"], float) @ Rr)
        spin_q, spin_h = np.array([0.45, 0.3, -0.85]), np.array(H(-55, 12))
        keys = []
        for i in range(28):
            t = i / 27 * 0.9
            a = curve(turn, t) if t >= 0.2 else -62.0 * L.smooth01(t / 0.2)
            y = a + 8.0      # he turns to his right, the blade at the end of both arms ahead of his chest all the way round
            haft = H(y, -6)
            r = np.array(H(y)) * 0.95
            settle = L.smooth01((t - 0.74) / 0.16)
            k = dict(pel=(0, -0.3 * (1 - settle) - 0.07 * settle, -0.1 * (1 - settle)), pelR=(6 - 3 * settle, -a - 16, 0), chest=(5 - 3 * settle, -14 + 5 * settle, 0), neck=(-4 + 3 * settle, 18 + 6 * settle, 0),
                     rp=(r[0] - haft[0] * 0.6, 0.2 - haft[1] * 0.6, r[2] - haft[2] * 0.6), haft=haft, face=E(haft, H(y + 90)), lhw=1.0, lsl=LSL, rsl=RSL, relb=READY["relb"], lelb=READY["lelb"], rknee=READY["rknee"], lknee=READY["lknee"], **spin(-a))
            Rc, at = chest_frame(k)
            hq = L.unit(spin_h + (ready_h - spin_h) * settle)
            k["haft"] = tuple(Rc @ hq)
            k["rp"] = tuple(at + Rc @ (spin_q + (ready_q - spin_q) * settle))
            k["face"] = E(k["haft"], H(y + 90))
            keys.append(K(t, "lin", **k))
        return melee("Guandao_Art", keys, "Crescent Moon Cyclone: he winds left, then the whole body pivots right on the balls of the feet with the blade at the end of both arms; the server's 360 degree blow.", feet_free=[(0, 0.9)], authored_feet=True)

    def strike():
        return clip("Strike", 1.1, [K(0, **READY), body(0.3, "io", yaw=10, chest=16, pitch=-6, sink=-0.05, fwd=0.1), body(0.5, "whip", yaw=-12, chest=-20, pitch=12, sink=-0.3, fwd=-0.45, lf=(0, -0.95, 0, 0, 0), rf=(0.16, 0.34, 0, -28, 0)),
                                    body(0.72, "out", yaw=-24, chest=-34, pitch=14, sink=-0.32, fwd=-0.5, lf=(0, -0.95, 0, 0, 0), rf=(0.16, 0.34, 0, -32, 0)), K(1.1, "io", **READY)]
                    + arc(0.1, 0.5, 0.74, 118, 66, FROM_HIGH_LEFT, aim=(0, -8)) + [K(1.1, "io", rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL)],
                    contacts=[0.5], move="Strike", notes="Fallback diagonal cut for any move without its own slot.", feet_free=[(0, 1.1)])

    # ---------------------------------------------------------------- signature attacks
    def flowing_glaive():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL)
        return clip("FlowingJian", 3.5, [
            K(0, **READY),
            body(0.55, "io", yaw=30, chest=46, sink=-0.12, fwd=0.08, rf=(0.2, 0.5, 0, -14, 0)),
            body(0.8, "whip", yaw=-12, chest=-20, pitch=8, sink=-0.28, fwd=-0.42, lf=(0, -0.9, 0, 0, 0), rf=(0.16, 0.36, 0, -30, 0)),
            # (2026-11-10) the second cut comes from his high right, and he wound it up turned 28 deg (chest 38) to his left, away from it: both
            # arms reached across his chest to the high right (after the first swivel: right 0.20, left 0.21 over f28-66). Wound up facing it (yaw
            # -4, chest -6) the right arm clears (0.12); turning less into the third cut's wind-up (1.85: 18/28 -> 10/16) keeps the left arm off
            # his chest there (0.18 -> 0.17; the bake: right 0.104, left 0.171; keyprobe.py variants A-J)
            body(1.2, "io", yaw=-4, chest=-6, pitch=6, sink=-0.22, fwd=-0.44, lf=(0, -0.9, 0, 4, 0), rf=(0.16, 0.2, 0, -18, 0)),
            body(1.45, "whip", yaw=26, chest=34, pitch=8, sink=-0.3, fwd=-0.7, rf=(0.2, -0.3, 0, -8, 0), lf=(0, 0.1, 0, 10, 0)),
            body(1.85, "io", yaw=10, chest=16, pitch=5, sink=-0.32, fwd=-0.78, rf=(0.2, -0.3, 0, -8, 0), lf=(0, 0.1, 0, 10, 0)),
            body(2.1, "whip", yaw=-16, chest=-30, pitch=-1, sink=-0.12, fwd=-0.92, lf=(0, -0.9, 0, 0, 0), rf=(0.16, 0.36, 0, -26, 0)),
            body(2.5, "io", yaw=-2, chest=2, pitch=-8, sink=-0.05, fwd=-0.9, lf=(0, -0.9, 0, 0, 0), rf=(0.16, 0.36, 0, -26, 0)),
            # (2026-11-09) the overhead finish lands 0.35 further forward, with his 1.1 lunge: left at -1.25 the hands came down at his belt and the lead
            # forearm into his belly (0.18-0.20, f83-90; keyed 0.18 -> 0.11)
            body(2.75, "whip", yaw=-8, chest=-14, pitch=16, sink=-0.42, fwd=-1.1, lf=(0, -1.05, 0, 0, 0), rf=(0.16, 0.2, 0, -28, 0)),
            body(3.0, "out", yaw=-10, chest=-16, pitch=18, sink=-0.44, fwd=-1.12, lf=(0, -1.05, 0, 0, 0), rf=(0.16, 0.2, 0, -28, 0)),
            K(3.5, "io", **READY),
        ] + arc(0.24, 0.8, 1.02, 135, 50, FROM_HIGH_LEFT, aim=(2, -8), whip=2.6) + arc(1.2, 1.45, 1.66, 70, 55, FROM_HIGH_RIGHT, aim=(-4, -6), whip=1.8, link=True) + arc(1.84, 2.1, 2.3, 75, 60, FROM_LOW_LEFT, aim=(0, 2), whip=1.8, centre=(0.32, 0.5, -1.2), link=True)
          + arc(2.48, 2.75, 3.0, 110, 40, FROM_OVERHEAD, aim=(0, -10), whip=2.0, centre=(0.2, 0.34, -1.6), link=True) + [K(3.5, "io", **back)],
            contacts=[0.8, 1.45, 2.1, 2.75], move="FlowingJian", feet_free=[(0, 3.5)], notes="Flowing Glaive: four linked curved cuts on the server's deflect pulses: a falling diagonal, its mirror on the way back, a rising cut, and an overhead finish, each flowing out of the last in a figure eight. Stable id FlowingJian.")

    def hesitant_moon():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL)
        high = arc(0.1, 0.6, 0.6001, 150, 0, FROM_HIGH_RIGHT, aim=(-10, 18), whip=1.0)
        # (2026-11-09) the hang is the top of the falling cut itself: held at a pose of its own (haft up and to his left), the cut's first key 0.05 s
        # later was 0.58 lower with the haft 45 deg round, one frame that carried the haft through his trunk and flipped the side it is cleared to
        # (fist 0.61 out of line, f30-33, and the lead hand 0.33 short of the haft). And it falls from his right side: centred on his middle, the
        # haft's line ran through his trunk all through the hang, so the fist was cleared to his left for six frames and then flipped to his right
        # (0.62 in a frame, f36-37), where the blow then landed anyway. Centred 0.8 out the hang's fist was still past his reach: the solver drew it
        # in and the butt into his belly, cleared behind his right hip on f26 and in front on f27 (0.56). Centred 1.0 out and 0.1 forward the butt
        # hangs outside his hip through the hang and the fall (phase 1: fist pops 0.61 -> 0.14, arms 0.18/0.16 -> 0.17/0.15, grip held)
        fall = arc(1.0, 1.3, 1.55, 78, 80, FROM_HIGH_RIGHT, aim=(-2, -8), whip=3.0, centre=(1.0, 0.22, -1.3))
        return clip("HesitantMoon", 2.15, [
            K(0, **READY),
            body(0.55, "io", yaw=-22, chest=-34, pitch=-4, sink=-0.1, fwd=0.1, rf=(0.2, 0.52, 0, -28, 0)),
            body(0.95, "lin", yaw=-24, chest=-38, pitch=-5, sink=-0.1, fwd=0.12, rf=(0.2, 0.52, 0, -28, 0)),
            body(1.3, "whip", yaw=-2, chest=-6, pitch=10, sink=-0.32, fwd=-0.48, lf=(0, -1.0, 0, 0, 0), rf=(0.16, 0.34, 0, -26, 0)),
            body(1.55, "out", yaw=28, chest=44, pitch=11, sink=-0.34, fwd=-0.54, lf=(0, -1.0, 0, 8, 0), rf=(0.16, 0.2, 0, -14, 0)),
            K(2.15, "io", **READY),
        ] + arc(0.1, 0.6, 0.62, 130, 0, FROM_HIGH_RIGHT, aim=(-14, 44), whip=1.2, settle=1.0, enter=0.3)[:-1]     # (2026-11-09) picked up over 0.3 s as he turns: in 0.15 the fist swung back past his right hip (forearm 0.18 in, f6)
          + [K(0.95, "lin", **fall[0][1])]
          + fall + [K(2.15, "io", **back)],
            contacts=[1.3], move="HesitantMoon", feet_free=[(0, 2.15)], notes="Hesitant Moon: the blade rises and hangs at the top of the cut longer than it should, so a deflect pressed at the expected moment is too early; then it falls from his right shoulder across his body.")

    def wheel_of_heaven():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL)
        keys = [K(0, **READY), body(0.3, "io", yaw=-6, chest=-10, pitch=-2, sink=-0.08, fwd=0.0, lf=(0, -0.4, 0, 0, 0))]
        # the pinwheel: the haft turns on the fingers of the right hand in the plane beside him; the left hand lets go and is back before the cut
        for i in range(25):
            t = 0.1 + i * (0.9 - 0.1) / 24
            a = 270 + i / 24 * 870     # it starts from the guard's line and ends where the catch and the cut begin
            d = L.unit(np.array([0.32, math.cos(math.radians(a)), math.sin(math.radians(a))]))
            keys.append(K(t, "lin", rp=pinwheel_fist(0.95, 0.5, -0.55), rsl=-0.1, haft=tuple(d), face=E(d, (0.2, -math.sin(math.radians(a)), math.cos(math.radians(a)))), rlk=1.0, rhx=H(-20, 30)))
        keys += [K(0.08, "io", lhw=1.0), K(0.18, "out", lhw=0.0, lua=(-20, 0, -6), lfa=(-50, 0, 0), lha=(0, 0, 0)), K(0.84, "io", lhw=0.0), K(1.02, "in", lhw=1.0), K(0.92, "lin", rlk=1.0), K(1.0, "lin", rlk=0.0, rsl=RSL)]
        keys += [body(1.0, "io", yaw=30, chest=48, pitch=-2, sink=-0.12, fwd=0.05), body(1.35, "whip", yaw=-10, chest=-20, pitch=9, sink=-0.3, fwd=-0.46, lf=(0, -1.0, 0, 0, 0), rf=(0.16, 0.34, 0, -30, 0)),
                 body(1.73, "whip", yaw=26, chest=40, pitch=6, sink=-0.3, fwd=-0.7, rf=(0.2, -0.3, 0, -8, 0), lf=(0, -0.1, 0, 10, 0)), body(2.0, "out", yaw=34, chest=52, pitch=5, sink=-0.3, fwd=-0.72, rf=(0.2, -0.3, 0, -8, 0), lf=(0, -0.1, 0, 10, 0)), K(2.6, "io", **READY)]
        # (2026-11-09) both cuts go forward with his lunge (0.46, then 0.7 forward of his feet): left in front of his feet, the lead arm folded into
        # his chest to hold the haft between them (0.19, f44-49) and the right 0.17; 0.25 and 0.4 further forward both stand clear (0.14 / 0.14)
        keys += arc(1.0, 1.35, 1.5, 120, 62, FROM_HIGH_LEFT, aim=(2, -6), whip=2.4, centre=(0.32, 0.22, -1.45)) + arc(1.53, 1.73, 2.0, 60, 80, FROM_LOW_RIGHT, aim=(-4, 2), whip=1.6, centre=(0.32, 0.22, -1.6)) + [K(2.6, "io", **back)]
        return clip("WheelOfHeaven", 2.6, keys, contacts=[1.35, 1.73], move="WheelOfHeaven", feet_free=[(0, 2.6)], notes="Wheel of Heaven: two full pinwheels of the glaive beside him, then the left hand catches it and two cuts come close together, a falling diagonal and a rising return.")

    def pinwheel_fist(x, y, z):
        """(2026-11-07) Where the fist spins a pinwheel. The haft wheels in a plane through the fist, its butt half leaning in toward him; with the
        fist at the hip's side that plane ran through his right upper arm on every turn and the butt through his thigh. Out to the side and
        forward by PINWHEEL_OUT the plane passes outside the arm (measured on the real surfaces, Flourish: weapon in the arm 0.17 -> 0, in the legs 0.17 -> 0)."""
        return (x + PINWHEEL_OUT[0], y + PINWHEEL_OUT[1], z + PINWHEEL_OUT[2])

    def flourish():
        keys = [K(0, **READY), body(0.3, "io", yaw=-8, chest=-12, pitch=0, sink=-0.05, lf=(0, -0.42, 0, 0, 0)), body(1.0, "io", yaw=-4, chest=-6, pitch=0, sink=-0.05, lf=(0, -0.42, 0, 0, 0)), K(1.6, "io", **READY)]
        for i in range(33):
            t = 0.12 + i * (1.2 - 0.12) / 32
            a = 270 + i / 32 * 1080     # (2026-11-09) from and back to the guard's line, haft forward: ended pointing at the ground (200), the catch slid the weapon 1.7 down through the fist into the floor, so the fist went 1.5 behind his back instead (f34-41, a 0.33 pop)
            # (2026-11-09) the wheel leans further out as the blade goes behind him (0.3 -> 0.75 at its back): leaning 0.3 the whole way, the
            # solver swung the haft 30-50 deg out for the two frames the blade passed behind his shoulder and back (phase 2 blade line 0.69 and edge
            # 0.70 out of line f19-20); keyed where it has to go, nothing jumps (both phases pass)
            d = L.unit(np.array([0.3 + 0.45 * max(0.0, math.sin(math.radians(a))), math.cos(math.radians(a)), math.sin(math.radians(a))]))
            keys.append(K(t, "lin", rp=pinwheel_fist(0.95, 0.45, -0.5), rsl=-0.1, haft=tuple(d), face=E(d, (0.2, -math.sin(math.radians(a)), math.cos(math.radians(a)))), rlk=1.0, rhx=H(-20, 30)))
        keys += [K(0.1, "io", lhw=1.0), K(0.22, "out", lhw=0.0, lua=(-16, 0, -6), lfa=(-44, 0, 0), lha=(0, 0, 0)), K(1.14, "io", lhw=0.0), K(1.32, "in", lhw=1.0), K(1.22, "lin", rlk=1.0, rsl=-0.1), K(1.34, "lin", rlk=0.0, rsl=RSL),
                 K(1.6, "io", rp=READY["rp"], haft=READY["haft"], face=READY["face"], lsl=LSL)]
        return clip("Flourish", 1.6, keys, contacts=[0.6], feet_free=[(0, 1.6)], notes="Three unhurried pinwheels of the glaive, caught back into both hands; plays between exchanges so the pause is never the same twice.")

    def feint():
        # (2026-11-09) the blade is picked up out of the guard over 0.3 s (enter), not the default 0.144: the whole body commits over half a second,
        # and lifted 150 deg in four frames the haft flipped 110 deg between f3 and f4 and drew the right arm across his chest (phase 2 0.26-0.29)
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL)
        return clip("Feint", 1.05, [K(0, **READY),
                                    body(0.32, "io", yaw=28, chest=44, sink=-0.14, fwd=0.04, rf=(0.2, 0.5, 0, -12, 0)),
                                    body(0.52, "out", yaw=10, chest=8, pitch=9, sink=-0.26, fwd=-0.28, lf=(0, -0.72, 0, 0, 0), rf=(0.16, 0.4, 0, -26, 0)),
                                    body(0.72, "io", yaw=-10, chest=-6, pitch=3, sink=-0.1, fwd=0.05, lf=(0, -0.4, 0, 2, 0)), K(1.05, "io", **READY)]
                    + arc(0.04, 0.52, 0.52001, 150, 0, FROM_HIGH_LEFT, aim=(-10, 26), whip=1.6, settle=1.0, centre=(0.4, 0.3, -1.45), enter=0.3)[:-1] + [K(1.05, "io", **back)],
                    contacts=[0.52], feet_free=[(0, 1.05)], notes="A cut that never comes: the whole body commits, the blade stops short at the top and he settles back. No warning is shown, because nothing is thrown.")

    def prayer_beads():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL)
        keys = [K(0, **READY), body(0.4, "io", yaw=-8, chest=-12, pitch=-2, sink=-0.06), body(0.9, "io", yaw=22, chest=34, pitch=-4, sink=-0.08, fwd=0.08), body(1.1, "whip", yaw=-10, chest=-18, pitch=8, sink=-0.26, fwd=-0.36, lf=(0, -0.85, 0, 0, 0), rf=(0.16, 0.36, 0, -28, 0)),
                body(1.4, "out", yaw=-24, chest=-40, pitch=8, sink=-0.28, fwd=-0.42, lf=(0, -0.85, 0, 0, 0), rf=(0.16, 0.36, 0, -36, 0)), K(2.1, "io", **READY)]
        for i in range(15):
            t = 0.1 + i * 0.5 / 14
            a = 200 + i / 14 * 540
            d = L.unit(np.array([0.3, math.cos(math.radians(a)), math.sin(math.radians(a))]))
            keys.append(K(t, "lin", rp=pinwheel_fist(0.95, 0.5, -0.5), rsl=-0.1, haft=tuple(d), face=E(d, (0.2, -math.sin(math.radians(a)), math.cos(math.radians(a)))), rlk=1.0, rhx=H(-20, 30)))
        keys += [K(0.08, "io", lhw=1.0), K(0.18, "out", lhw=0.0, lua=(-20, 0, -6), lfa=(-50, 0, 0), lha=(0, 0, 0)), K(0.56, "io", lhw=0.0), K(0.72, "in", lhw=1.0), K(0.62, "lin", rlk=1.0), K(0.74, "lin", rlk=0.0, rsl=RSL)]
        keys += arc(0.74, 1.1, 1.42, 118, 80, FROM_HIGH_LEFT, aim=(0, 2), whip=2.4) + [K(2.1, "io", **back)]
        return clip("PrayerBeads", 2.1, keys, contacts=[1.1], move="PrayerBeads", feet_free=[(0, 2.1)], notes="The glaive pinwheels and gathers seven beads off his breath, the left hand catches it and the falling cut flings them on the server's release.")

    def abbot_sweep():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL)
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
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL)
        return clip("BloodWave", 2.15, [
            K(0, **READY),
            # (2026-11-09) the trunk winds as the hands take the blade back, not ahead of them: keyed at 0.35 s it had turned 52 deg by f9 with the
            # glaive still at the guard, the fist beside his ribs and the right arm 0.31 into his chest (f8-10); at 0.5 s it is 0.18
            body(0.5, "io", yaw=30, chest=46, pitch=10, sink=-0.36, fwd=0.04),
            # (2026-11-09) the haul bows 8 deg, not 14, and the lead hand chokes up (span 1.6): with phase 2's chest already pitched 8 deg the lead
            # arm folded into it as the edge dragged past his left knee (0.20, f17-29); now 0.17 / 0.16 with the grip on the haft (0.048 -> 0.005)
            body(1.0, "in", yaw=4, chest=-4, pitch=8, sink=-0.44, fwd=-0.3, lf=(0, -0.7, 0, 0, 0)),
            body(1.1, "whip", yaw=-22, chest=-36, pitch=-2, sink=-0.1, fwd=-0.46, lf=(0, -0.7, 0, 0, 0), rf=(0.16, 0.38, 0, -36, 0)),
            body(1.45, "out", yaw=-26, chest=-44, pitch=-6, sink=-0.05, fwd=-0.48, lf=(0, -0.7, 0, 0, 0), rf=(0.16, 0.38, 0, -36, 0)),
            K(2.15, "io", **READY),
        ] + arc(0.2, 1.1, 1.45, 104, 84, FROM_LOW_LEFT, aim=(4, -10), centre=(0.3, -0.05, -1.05), whip=2.6, span=1.6) + [K(2.15, "io", **back)],
            contacts=[1.1], move="BloodWave", feet_free=[(0, 2.15)], scrape=True, notes="The glaive's edge drags from his left, the whole body hauling it, then whips up and casts the low wave on the server's start.")

    def rending_arc():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL)
        return clip("RendingArc", 2.6, [
            K(0, **READY),
            body(0.6, "io", yaw=30, chest=48, sink=-0.12, fwd=0.1),
            body(0.9, "whip", yaw=-14, chest=-26, pitch=12, sink=-0.3, fwd=-0.6, lf=(0, -0.8, 0, 0, 0)),
            body(1.32, "whip", yaw=16, chest=24, pitch=10 if phase == 1 else 4, sink=-0.3, fwd=-0.9, rf=(0.1, -0.2, 0, 0, 0)),
            body(1.7, "io", yaw=-6, chest=-4, pitch=-6, sink=-0.05, fwd=-0.9, rf=(0.1, -0.2, 0, 0, 0)),
            body(1.95, "whip", yaw=-12, chest=-20, pitch=16 if phase == 1 else 8, sink=-0.44, fwd=-1.2, lf=(0, -1.0, 0, 0, 0)),
            K(2.6, "io", **READY),
        # (2026-11-09) the second and third cuts go forward with his lunge (0.9 and 1.2 forward of his feet there): left in front of his feet, his
        # arms folded against his chest to hold them and the solver drew both fists up and back to his shoulders (phase 2: right 0.35 and left
        # 0.38 inside his chest, f34-39). The second also comes from out to his right, where it starts. Moving the first cut forward too put the
        # right arm 0.36 in (f20-25); left where it was. Instead (phase 2) its approach is carried 0.3 left and forward, where his chest faces
        # (still turned 42-48 deg from the wind-up, f21-24: right 0.20, left 0.20), and back onto the cut by the blow; the lead hand chokes up the
        # haft for the second (1.8 from the fist: the left arm 0.22 -> 0.09 at its blow, f40); the overhead's wind-up rises 0.4 (right 0.23, f54).
        # Phase 2 bows 6 deg less into the second blow and 8 less into the third: with the corruption's 8 his chest folded onto the right arm
        # (keyed 0.18 at f40, 0.25-0.32 at f58-64), and the bake cleared the third or not depending on the rest of the clip (0.37 when the second moved)
        # (2026-11-10) Phase 2's overhead finish slides the rear fist 0.5 down to the butt (rsl), as a chop does: with a hand's breadth of haft (1.0)
        # behind the fist, the butt sat in the right forearm through the blow and the follow-through for every grip and elbow swivel weighs (arm in
        # the weapon 0.04-0.15, f58-71, swparts.py; the clear choices put the arm 0.25-0.37 in his chest), so it took the chest: right 0.19 there
        # after swivel (keyprobe.py: 0.15 with the slide; a shorter follow-through 0.20, the hands 0.22 to his right 0.18, 8 deg less bow 0.18)
        ] + carry(arc(0.24, 0.9, 1.04, 135, 74, FROM_HIGH_LEFT, aim=(2, -8), whip=2.4), 0.45, 0.65, 0.78, 0.9, (-0.3, 0.0, -0.3) if phase == 2 else (0.0, 0.0, 0.0))
          + arc(1.16, 1.32, 1.46, 70, 70, FROM_HIGH_RIGHT, aim=(-4, -6), whip=1.5, centre=(0.6, 0.22, -1.7), span=1.8 if phase == 2 else 1.2)
          + carry(arc(1.7, 1.95, 2.15, 100, 40, FROM_OVERHEAD, aim=(0, -10), whip=3.0, centre=(0.2, 0.34, -2.0), rsl=RSL if phase == 1 else RSL - 0.5), 1.62, 1.75, 1.82, 1.93, (0.2, 0.4, 0.0) if phase == 2 else (0.0, 0.0, 0.0)) + [K(2.6, "io", **back)],
            contacts=[0.9, 1.32, 1.95], move="RendingArc", feet_free=[(0, 2.6)], notes="Rending Arc: three cuts in a broken rhythm, the third held back so the third deflect has to wait for it.")

    def phantom_drift():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL)
        return clip("PhantomDrift", 2.0, [
            K(0, **READY),
            K(0.55, "io", pel=(0.02, -0.02, 0.2), pelR=(-8, 26, -8), chest=(-6, 40, 6), neck=(8, -40, 0), rf=(0.2, 0.7, 0, 0, 0), lf=(0, 0.2, 0, 0, 0)),
            K(1.0, "whip", pel=(0, -0.2, -0.62), pelR=(26, -10, 0), chest=(14, -20, 0), neck=(-30, 26, 0), rf=(0.2, 1.0, 0, 0, 0), lf=(0, 0.65, 0, 0, 0)),
            K(1.3, "out", pel=(0, -0.2, -0.7), pelR=(22, -30, -4), chest=(12, -50, 4), neck=(-26, 44, 0), rf=(0.2, 1.0, 0, 0, 0), lf=(0, 0.65, 0, 0, 0)),
            K(2.0, "io", **READY),
        # (2026-11-09) the cut goes forward with his glide (his hips 0.62 forward of his feet at the contact): left in front of his feet his arms
        # folded against his chest to reach it (phase 2: right 0.20, f27-28)
        ] + arc(0.25, 1.0, 1.32, 125, 80, FROM_HIGH_LEFT, aim=(0, -14), whip=2.8, centre=(0.32, 0.22, -1.7)) + [K(2.0, "io", **back)],
            contacts=[1.0], move="PhantomDrift", feet_free=[(0, 2.0)], notes="Phantom Drift: he leans back and hangs in the air, then glides through the server's lunge with his legs trailing and the blade falling across him.")

    def skyfall():
        back = dict(rp=READY["rp"], haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL)
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
        # (2026-11-10) the follow-through's fist carried 0.4 to his right and 0.1 forward from just after the blow (the contact keeps its key). Phase
        # 2's rear fist finished on his chest's right side, where every elbow turn swivel had near the up-and-back one put the arm in him: it
        # flipped the elbow down and forward round f56-62 (72 deg in a frame) and left the right arm 0.21 in his chest at f58-59, which clear_torso
        # could not move (no fist move clears it there, ctmoves.py). Carried, with swivel's run-wide recheck (below), the elbow stays up and back
        # through the follow-through (steps <= 31 deg after the blow) and the bake passes (0.160, 0.169 left; ctcache.py / ctmoves.py variant c5)
        ] + carry(arc(0.1, 1.5, 1.92, 135, 46, FROM_OVERHEAD, aim=(0, -18), whip=4.5, centre=(0.2, 0.3, -1.08)), 1.5, 1.62, 1.92, 2.0, (0.4, 0.0, -0.1)) + [K(2.6, "io", **back)],
            contacts=[1.5], move="GuandaoSkyfall", scrape=True, airborne=True, feet_free=[(0, 2.6)], authored_feet=True, notes="Coils, the server's aerial path carries the root, glaive high at the apex, and the blade falls with him; his feet touch down and his knees absorb the landing at the impact, then he lifts again.")

    def crimson_embrace():
        back_w = dict(rp=(0.75, -0.2, 0.55), haft=H(75, -28), face=E(H(75, -28)), rsl=-0.2)
        return clip("CrimsonEmbrace", 2.4, [
            K(0, **READY),
            # (2026-11-09) the grip and the reach hand over from 0.12 s together: with the grip held to 0.25 s the glaive had swung half way back with the
            # hand still on it (1.17 off the haft); with the reach rising from 0 s under a full grip the hand drifted 0.29 off the wood before letting go
            K(0.12, "io", lhw=1.0, ltw=0.0),
            K(0.5, "io", lhw=0.0, ltw=0.85, pel=(0, -0.05, 0.22), pelR=(-6, -18, 0), chest=(-10, -26, 0), neck=(4, 30, 0), lt=(-0.75, -0.2, 0.15), lelb=(-0.8, -0.1, 0.5), **back_w),
            K(0.98, "io", pel=(0.02, -0.1, 0.3), pelR=(-8, -20, 0), chest=(-13, -30, 0), neck=(6, 34, 0), lt=(-0.8, 0.0, 0.25)),
            K(1.2, "whip", pel=(0, -0.3, -1.1), pelR=(22, 12, 0), chest=(18, 26, 0), neck=(-18, -30, 0), ltw=1.0, lt=(0.5, 0.1, -1.46), lelb=(-0.5, -0.8, 0.1), rf=(0.2, 0.8, 0, 0, 0), lf=(0, 0.3, 0, 0, 0), rp=(1.0, -0.15, -0.55), haft=H(70, -26), face=E(H(70, -26))),
            # (2026-11-09) the grip comes back only once the reach is spent: ramping in from 0.5 s, it was already 0.75 at 1.33 s, with the haft still held
            # back in the right hand behind him, and the trunk wound round to bring the lead hand to it (both arms 0.38 in his chest, the hand 1.2 off the haft)
            # (2026-11-09) the trailing glaive goes with the lunge: keyed 0.65 out while his hips went 1.2 out and his chest turned 50 deg, the fist sat
            # behind the middle of his back (chest frame x 0.24, 0.55 behind) and the straight right arm ran through it (0.32 deep, f37-39); here it
            # trails beside his right hip. The guard he comes back to is the guard of his own lunging body (READY's fist 0.65 further out with his hips)
            K(1.4, "out", lhw=0.0, ltw=1.0, pel=(0, -0.32, -1.2), pelR=(24, 16, 0), chest=(20, 32, 0), neck=(-18, -36, 0), lt=(0.55, -0.15, -1.25), rp=(1.0, -0.4, -1.75), haft=H(70, -26), face=E(H(70, -26))),
            # (2026-11-09) and the lead hand takes the haft once the glaive is back in front of him: gripping from 1.4 s, its pull drew the weapon in
            # toward his left shoulder while it was still out to his right, the fist went in behind his hip and the right arm 0.28 into him (f48-50)
            K(1.62, "io", lhw=0.1, ltw=0.9),
            K(1.85, "io", pel=(0, -0.2, -0.65), pelR=(9, 0, 0), chest=(9, 0, 0), neck=(-8, 8, 0), ltw=0.0, lhw=1.0, rp=(READY["rp"][0], READY["rp"][1], READY["rp"][2] - 0.65), haft=READY["haft"], face=READY["face"], rsl=RSL, lsl=LSL),
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
                k = dict(pel=(0.02 + 0.05 * sway, -0.07 - 0.016 * breath - 0.008 * sway2, 0.02 + 0.012 * sway2), pelR=(3 + 0.3 * sway2, YAW["pel"] + 1.4 * sway, 1.1 * sway), chest=(2 - 1.2 * breath + 0.3 * sway2, YAW["chest"] - 1.6 * sway, -1.4 * sway),
                         neck=(-1 + 0.8 * breath + 0.6 * math.sin(2 * a), YAW["neck"] + look, 0.8 * sway), rp=tuple(r0 + np.array([0.015 * sway, 0.018 * breath, 0.01 * sway2])), haft=tuple(hf), face=E(hf))
            else:
                snap = sum(w * L.smooth01((t - at) / 0.11) for at, w in ((0.7, 12.0), (1.6, -18.0), (2.6, 10.0), (3.7, -4.0)))
                k = dict(pel=(0.02 + 0.08 * sway, -0.05 * breath, 0.04 * sway2), pelR=(4 + 1.2 * breath, YAW["pel"] + 2.4 * sway, 2.2 * sway), chest=(4 - 3.0 * breath + 0.8 * sway2, YAW["chest"] - 3.0 * sway, -2.4 * sway),
                         neck=(-4 + 2.4 * breath, YAW["neck"] + snap + 1.5 * sway, 1.5 * math.sin(a + 0.6)), rp=tuple(r0 + np.array([0.03 * sway, 0.05 * breath, 0.02 * sway2])), haft=tuple(hf), face=E(hf))
            k.update(rf=FEET_R, lf=FEET_L, lhw=1.0, rsl=RSL, lsl=LSL, relb=READY["relb"], lelb=READY["lelb"], rknee=READY["rknee"], lknee=READY["lknee"])
            keys.append((t, k, "lin"))
        return clip("Idle", length, keys, loop=True, priority="Idle", authored_feet=True, notes="The guard alive: both hands on the glaive, slow breath, weight drifting between the feet." if p1 else "He hangs in the air and cannot hold still: panting, head hunting in short snaps, the glaive drifting.")

    # ---------------------------------------------------------------- a human gait
    CARRY = (-10.0, -20.0)    # pelvis and chest yaw on the move: less turned than the guard, still enough for the lead hand to keep its spot

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

        stance_flex = ([(0, 28), (0.25, 40), (0.6, 30), (1, 20)] if run else [(0, 6), (0.22, 15), (0.55, 7), (0.85, 6), (1, 22)])
        rows = []
        for i in range(n):
            p = i / n
            a = 2 * math.pi * p
            wave, over = math.cos(a), math.sin(a)     # wave +: right leg forward; over +: weight on the right foot
            pelR = (lean * 0.6 + 2.0, twist * wave + (CARRY[0] if carry else 0), drop * over)
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
        # (2026-11-06) no extra lift through the flight phase: it left the landing leg 0.17 short of its foot
        F = np.fft.rfft(ys)
        F[5:] = 0
        ys = np.fft.irfft(F, n)
        keys = []
        for i, (p, a, wave, over, pelR, pel, fr, fl) in enumerate(rows):
            y = float(ys[i])
            base_twist = -6.0 if carry else 0.0
            chest_yaw = -twist * 0.95 * math.cos(a - 0.15) + (CARRY[1] if carry else 0)
            chest_world = pelR[1] + chest_yaw
            nod = L.rodrigues(np.array([1.0, 0, 0]) * math.radians(1.1 * math.cos(2 * a - 0.4)) + np.array([0, 1.0, 0]) * math.radians(1.6 * wave))
            # the guard carried with the shoulders: they face CARRY's total yaw instead of the guard's, so the weapon turns by the difference and both hands stay where they hold it
            held = carried(CARRY[0] + CARRY[1] - YAW["pel"] - YAW["chest"])
            r0 = np.array(held["rp"]) + np.array((0.0, y * (0.8 if carry == "charge" else 0.85), -lean * 0.012 if carry == "charge" else 0.0))
            h0 = np.array(held["haft"]) if carry != "charge" else L.unit(np.array(held["haft"]) + np.array((0.0, -0.06, 0.0)))
            hf = nod @ h0
            k = dict(pel=(pel[0], y, pel[2]), pelR=pelR, chest=(lean * 0.45 - 0.5 * math.cos(2 * a), chest_yaw, -pelR[2] * 1.2), neck=(-lean * 1.0 - 2.0 + 0.4 * math.cos(2 * a), -chest_world * 0.95, pelR[2] * 0.3),
                     rf=(ax * fr[0] - shuffle, az * fr[0], fr[1], 0, fr[2]), lf=(ax * fl[0] + shuffle, az * fl[0], fl[1], 0, fl[2]), rknee=(0.06, 0, -1.0), lknee=(-0.06, 0, -1.0),
                     rp=tuple(r0 + np.array([0.02 * over, 0.0, 0.05 * math.cos(a - 0.3)])), haft=tuple(hf), face=E(hf), rsl=RSL, lsl=LSL, lhw=1.0, relb=READY["relb"], lelb=READY["lelb"])
            keys.append((p * period, k, "lin"))
        if reverse:   # a backward walk is a forward walk run backwards: toes land first, the heel lets down, the heel pushes off
            keys = [((period - t) % period, k, e) for t, k, e in keys]
        actual = 2 * half / (beta * period)
        return Clip(rg, P + name, period, keys, loop=True, priority="Movement", authored_feet=True, feet_free=[(0, period)], notes="%s: %.2f rig studs per second at speed 1." % (name, actual))

    def glide(name, period, rate, lean, roll=0.0, trail=0.0, tuck=0.0, chest_carry=False, nudge=None):
        """Phase 2's travel: no steps at all. He leans into the direction, legs trailing, and the air does the rest."""
        n = int(round(period * 30))
        keys = []
        for i in range(n):
            a = 2 * math.pi * i / n
            s, c2 = math.sin(a), math.cos(2 * a)
            nod = L.rodrigues(np.array([1.0, 0, 0]) * math.radians(1.4 * s))
            body = dict(pel=(0.03 * s, 0.02 * c2 - 0.05 * abs(lean) / 20, -lean * 0.012), pelR=(lean * 0.9 + 1.5 * s, -8 + 2 * math.cos(a), roll + 2.2 * s), chest=(lean * 0.3 - 1.2 * c2, -10 - 2.5 * math.cos(a), -roll * 0.5))
            held = carried_chest(body) if chest_carry else carried(-8.0 - 10.0 - YAW["pel"] - YAW["chest"])      # his hips and chest face -8 and -10 here: the guard turns with them
            hf = nod @ L.unit(np.array(held["haft"]) + np.array((0.0, -0.1, 0.0)))
            r0 = np.array(held["rp"])
            # (2026-11-09) past a 20 deg lean the hands go forward and down with his chest (0.45 and 0.1 at the run's 38): held where the walk holds
            # them, his chest came down onto his arms (phase 2 run: right 0.20 and left 0.22 inside it for most of the loop; 0.3 forward alone, 0.33)
            dive = max(0.0, lean - 20.0) / 18.0
            r0 = r0 + np.array([0.0, -0.1 * dive, -0.45 * dive])
            # (2026-11-10) nudge: the fist further out (rig units, his frame). Phase 2's run held the haft against the right forearm through the
            # middle of its loop (in the weapon 0.04-0.06 for the arm's own elbow turns, f7-24, swparts.py), so swivel swung that elbow 80-120 deg
            # off Idle's for those frames; stopped there, the game's 0.2 s fade to Idle (stopGait) took the arm 0.26 through his chest (loopout.py).
            # 0.08 forward clears the haft: the elbow stays within 36 deg of Idle's, loop out 0.25 -> 0.15 (fadecheck3.py)
            if nudge is not None:
                r0 = r0 + np.array(nudge, float)
            k = dict(pel=(0.03 * s, 0.02 * c2 - 0.05 * abs(lean) / 20, -lean * 0.012), pelR=(lean * 0.9 + 1.5 * s, -8 + 2 * math.cos(a), roll + 2.2 * s), chest=(lean * 0.3 - 1.2 * c2, -10 - 2.5 * math.cos(a), -roll * 0.5), neck=(-lean * 1.15, 18 + 2 * math.sin(a * 2), 0),
                     rf=(0.05, 0.24 + trail + 0.1 * math.sin(a + 0.6), tuck, 0, 0), lf=(-0.03, -0.1 + trail - 0.12 * math.sin(a + 0.6), tuck * 0.4, 0, 0), rknee=(0.1, 0, -1.0), lknee=(-0.1, 0, -1.0),
                     rp=tuple(r0 + np.array([0.02 * s, 0.03 * c2, -0.02 * math.cos(a) - lean * 0.008])), haft=tuple(hf), face=E(hf), rsl=RSL, lsl=LSL, lhw=1.0, relb=READY["relb"], lelb=READY["lelb"])
            keys.append((i / n * period, k, "lin"))
        return clip(name, period, keys, loop=True, priority="Movement", feet_free=[(0, period)], notes="%s: floating; %.2f rig studs per second at speed 1." % (name, rate))

    def carried_chest(k):
        """(2026-11-09) READY's guard carried rigidly in his chest's frame under key k (chest_frame: his turn and pitch, phase 2's corruption
        included), for a gait that turns or leans his chest away from the guard's own (chest_carry)."""
        Rr, ar = chest_frame(READY)
        Rk, ak = chest_frame(k)
        M = Rk @ Rr.T
        return dict(rp=tuple(ak + M @ (np.array(READY["rp"], float) - ar)), haft=tuple(M @ np.array(READY["haft"], float)), face=tuple(M @ np.array(READY["face"], float)))

    def carried(yaw):
        """The guard turned with the shoulders by `yaw` degrees (+ toward his left), so a turn never pulls the lead hand off its spot on the haft."""
        R = L.ry(math.radians(yaw))
        hf = R @ np.array(READY["haft"], float)
        return dict(rp=tuple(R @ np.array(READY["rp"], float)), haft=tuple(hf), face=E(hf))

    def turn(name, direction, chest_carry=False):
        """Turning on the spot, as the server turns his root at TURN_RATE at speed 1: the planted foot counter-rotates exactly, the other steps ahead of it, and the hips lead the chest and the chest leads the head."""
        period = 0.9
        n = int(round(period * 30))
        sweep = direction * TURN_RATE * period / 2            # degrees each step covers; +: toward his left
        keys = []
        if floating:
            for i in range(n):
                a = 2 * math.pi * i / n
                k = {kk: READY[kk] for kk in READY}
                k.update(pelR=(4, YAW["pel"] + direction * 14, direction * 4), chest=(3, YAW["chest"] + direction * 10, 0), neck=(-3, YAW["neck"] + direction * 14, 0))
                k.update(carried_chest(k) if chest_carry else carried(direction * 14.0))
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
            k.update(pel=(0.04 * over, -0.07 - 0.015 * math.cos(4 * math.pi * p), 0.02), pelR=(3, YAW["pel"] + direction * 10, 2 * over), chest=(2, YAW["chest"] + direction * 10, -1.6 * over), neck=(-1, YAW["neck"] + direction * 12, 0))
            k.update(carried(direction * 10.0))
            keys.append((p * period, k, "lin"))
        return Clip(rg, P + name, period, keys, loop=True, priority="Movement", authored_feet=True, feet_free=[(0, period)], notes="%s at %d degrees per second, speed 1." % (name, TURN_RATE))

    def locomotion():
        # (2026-11-09) phase 2's TurnRight and WalkBackward carry the guard in his chest's frame (carried_chest): the turn swung the guard 14 deg
        # while his chest turned 24, and the backward glide leans him back 12-17 deg with the fist left where it was, so the right arm held the
        # guard in another shape than Idle's and the game's fades to and from Idle put it 0.19 into his chest (fadecheck2.py; carried, TurnRight 0.15 and WalkBackward 0.14)
        turns = [turn("TurnLeft", 1.0), turn("TurnRight", -1.0, chest_carry=floating)]
        if floating:   # rates the server already holds; a glide has no feet to keep planted, so these only set how fast his body drifts through its loop
            return turns + [glide("WalkForward", 2.4, 2.40, 12, trail=0.3), glide("RunForward", 1.6, 7.48, 38, trail=1.25, tuck=0.45, nudge=(0.0, 0.0, -0.08)), glide("WalkBackward", 2.4, 1.80, -10, trail=-0.2, chest_carry=True), glide("StrafeLeft", 2.4, 1.95, 4, roll=10), glide("StrafeRight", 2.4, 1.95, 4, roll=-10)]
        return turns + [gait("WalkForward", 1.4, 1.98, 0.63, lean=2.0, twist=5.0, drop=3.4, sway=0.07),
                        gait("RunForward", 0.75, 6.11, 0.36, carry="charge", run=True, lean=20, twist=9.0, drop=3.0, sway=0.04, centre=0.15),
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
        # (2026-11-08) a wide kneel: the lean is in his spine, not his hips (pelvis 13 -> 5 deg forward, chest 18 -> 26), and the raised left foot is set
        # out to the side (0.5 wide, 0.7 lower, toe turned 30 deg out) with the knee opened outward (lknee -0.9, 0, -0.45). Pitched forward over a foot 0.62 in
        # front, the left thigh folded past 110 deg up into the robe's lap, which is skinned to his hips and cannot give way (mesh check: RobeFront 0.20 deep
        # in 71% of the deathblow, 0.19 in the posture break). Now the thigh opens beside the lap: RobeFront clear, RobeLeft 0.06 at the edge (report sec. 8)
        knee = {**READY, "pel": (0.05, -0.95, 0.18), "pelR": (5, 4, 0), "chest": (26, 6, 0), "neck": (-3, -6, 0), "rf": (0.05, 0.95, 0.5, 0, -55), "lf": (0.5, -0.7, 0, 30, 0), "lknee": (-0.9, 0, -0.45), "rp": (0.85, -0.5, -0.85), "haft": kneel_h, "face": E(kneel_h, (0.2, -0.3, 0.9)), "rsl": RSL, "lsl": LSL}

        def hit(name, push, turn_, lean_p, lean_r):
            flinch = {**READY, "pel": (READY["pel"][0] + push[0], -0.14, READY["pel"][2] + push[1]), "pelR": (READY["pelR"][0] + lean_p, READY["pelR"][1] + turn_, lean_r), "chest": (READY["chest"][0] + lean_p * 1.8, READY["chest"][1] + turn_ * 1.5, lean_r * 1.3), "neck": (READY["neck"][0] + lean_p, READY["neck"][1] + turn_, 0),
                      "rf": (FEET_R[0] + push[0] * 0.5, FEET_R[1] + push[1] * 0.6, 0, FEET_R[3], 0), "lf": (FEET_L[0] + push[0] * 0.2, FEET_L[1] + push[1] * 0.2, 0, FEET_L[3], 0)}
            return clip(name, 0.48, [K(0, **READY), K(0.09, "snap", **flinch), K(0.22, "out", **flinch), K(0.48, "io", **READY)], priority="Action3", feet_free=[(0, 0.48)], notes="Flinch from the blow's direction: chest first, then the hips and the rear foot give; the cloth takes the same push at run time.")

        down = dict(hov=0.0) if floating else {}
        bowed_h = H(14, -32)    # bowing, his hands slide back to the butt of the haft, so none of it comes back through his chest
        bowed = dict(rp=(0.9, -0.6, -0.95), haft=bowed_h, face=E(bowed_h, (0.2, -0.3, 0.9)), rsl=RSL, lsl=LSL)
        def death():
            """(2026-11-06) A completed death: struck, the knees go, he kneels for a breath on the haft, then the support goes out of him: the hands open, the glaive
            drops and clatters flat beside him, his left hand goes out to the floor, and he falls forward onto his chest, head turned. Impact, a small rebound, and
            a lifeless rest that holds until the fade (BossAnimationRules.DeathFadeAt 2.6 s): the fall is complete by 2.0 s so it is seen. Body, hands and weapon
            rest on the floor, none of them through it. Phase 2 drops out of its hover first and lets go of its corruption as it falls; its orbs fall with him
            (ClothSim.drop)."""
            lie_w = dict(wfree=1.0, wrp=(2.24, -2.92, -1.57), whaft=(0.61, 0.0, -0.79), wface=(0.79, 0.0, 0.61))
            fallen = dict(pel=(-0.2, -2.15, -0.75), pelR=(86, 16, -35), chest=(12, 10, -14), neck=(-25, 50, 0),
                          rf=(0.3, 1.78, 0.43, 12, -80), lf=(-0.4, 1.66, 0.42, -14, -76), rknee=(0.0, -1.0, 0.15), lknee=(0.0, -1.0, 0.15),
                          relb=(0.3, 1.0, 0.2), rt=(0.9, -0.3, -0.5), rha=(40, 0, 0), lhw=0.0, ltw=1.0, lt=(-0.5, -0.5, -0.9), lelb=(-0.6, 0.6, 0.3), lha=(-40, 0, 0), **lie_w)
            toppling_h = H(-45, -14)
            toppling = dict(pel=(-0.08, -1.45, -0.32), pelR=(46, 10, -14), chest=(16, 8, -8), neck=(-8, 26, 0), rf=(0.14, 1.3, 0.3, 4, -66), lf=(-0.15, 0.7, 0.2, -6, -42),
                            rknee=(0.0, -0.7, -0.6), lknee=(0.0, -0.5, -0.8), rp=(0.8, -1.9, -1.55), haft=toppling_h, face=E(toppling_h, (0.2, -0.4, -0.9)),
                            wfree=0.35, relb=(0.4, 0.6, 0.4), rt=(0.6, -0.95, -0.8), rha=(20, 0, 0), lhw=0.35, ltw=0.65, lt=(-0.35, -1.15, -0.75), lelb=(-0.7, 0.3, 0.4), lha=(-25, 0, 0))
            impact = {**fallen, "pel": (-0.2, -2.19, -0.77), "chest": (9, 10, -14), "neck": (-21, 50, 0)}
            rebound = {**fallen, "pel": (-0.2, -2.1, -0.74), "chest": (14, 10, -14)}
            bounce = dict(wrp=(2.24, -2.85, -1.57), whaft=(0.6, 0.08, -0.79))
            stagger = dict(pel=(0.03, -0.55, 0.3), pelR=(6, 6, 0), chest=(10, 6, 0), neck=(4, 0, 0), rf=(0.1, 0.7, 0.32, 0, -30), lf=(0.05, -0.4, 0, 0, 0))
            kneel = dict(knee)
            if phase == 2:
                # (2026-11-09) phase 2: the guard rides his chest's frame into the stagger, and on the knee the fist sits 0.15 further to his right.
                # Keyed only at the guard and the knee, the fist was splined between them in the world while he sank 0.55 and pitched forward, so at
                # the stagger it sat high under his right armpit (0.62 above his waist, 0.18 in front); keyed that was clear (0.06), but the passes
                # that turn the fist and slide it on the haft folded the arm into his chest there (0.31 at f21, settle spreading wrist_yield's
                # corrections), and at the kneel the arm at full stretch had its front armpit 0.20 in (f36). Measured per stage (stagetrace.py)
                Rr, ar = chest_frame(READY)
                Rs, a_s = chest_frame(stagger)
                M = Rs @ Rr.T
                stagger.update(rp=tuple(a_s + M @ (np.asarray(READY["rp"], float) - ar)), haft=tuple(M @ np.asarray(READY["haft"], float)),
                               face=tuple(M @ np.asarray(READY["face"], float)), rsl=RSL, lsl=LSL)
                kneel["rp"] = tuple(np.asarray(knee["rp"], float) + chest_frame(knee)[0][:, 0] * 0.15)
            return Clip(rg, P + "Death", 3.0, [K(0, **READY, **({"hov": H0 * 0.5} if floating else {})), K(0.24, "snap", pel=(0, -0.16, 0.4), pelR=(-12, 6, 0), chest=(-18, 6, 0), neck=(16, 0, 0), **down),
                                                K(0.75, "io", **stagger),
                                                K(1.15, "in", **{k: v for k, v in kneel.items() if k not in ("neck",)}, neck=(-8, 0, 0)),
                                                K(1.35, "io", lhw=1.0, ltw=0.0, **{**lie_w, "wfree": 0.0}),
                                                K(1.55, "in", **toppling), K(1.84, "in", **impact), K(1.96, "out", **{**rebound, **bounce}), K(2.1, "in", **{**fallen, **lie_w}),
                                                K(2.4, "io", **fallen), K(3.0, "io", **fallen)],
                        priority="Action4", feet_free=[(0, 3)], airborne=floating, authored_feet=True, raw_after=2.4, still_after=2.2, uncorrupt=(1.15, 1.84), floor_body=True,
                        notes="Killed: staggers, sinks to the right knee on the haft, lets go: the glaive clatters flat beside him and he falls forward onto his chest, left hand out; a small rebound and he lies still before the fade.")

        return [
            hit("HitLightFront", (0.0, 0.2), 0, -5, 0), hit("HitLightBack", (0.0, -0.2), 0, 8, 0), hit("HitLightLeft", (0.2, 0.0), -9, -1, 4), hit("HitLightRight", (-0.2, 0.0), 9, -1, -4),
            Clip(rg, P + "PostureBreak", 1.0, [K(0, **READY, **({"hov": H0} if floating else {})), K(0.14, "snap", pel=(0.02, -0.15, 0.42), pelR=(-14, 7, 0), chest=(-20, 8, 0), neck=(13, 0, 0), rf=(0.2, 0.7, 0, -24, 0), **({"hov": H0 * 0.6} if floating else {})),
                                               K(0.46, "io", pel=(0.05, -0.5, 0.3), pelR=(5, 6, 0), chest=(6, 6, 0), neck=(2, 0, 0), rf=(0.1, 0.8, 0.3, 0, -26), lf=(0.05, -0.4, 0, 0, 0), **down), K(1.0, "in", **knee, **down)],
                 priority="Action3", feet_free=[(0, 1)], airborne=floating, authored_feet=True, notes="Stance broken: thrown back, the levitation fails if he had it, and he sinks to his right knee on the haft, still holding it in both hands."),
            Clip(rg, P + "DeathblowVictim", 2.2, [K(0, **knee), K(0.22, "snap", pel=(0.05, -0.8, 0.32), pelR=(-9, 4, 0), chest=(-14, 6, 0), neck=(15, 0, 0)), K(0.9, "io", pel=(0.05, -0.92, 0.28), pelR=(3, 4, 0), chest=(20, 6, 0), neck=(0, 0, 0)),     # (2026-11-08) bowed from the spine (see knee)
                                                  K(1.5, "in", pel=(0.05, -1.02, 0.16), pelR=(9, 4, 0), chest=(40, 6, 0), neck=(-14, 0, 0), **bowed), K(2.2, "io", pel=(0.05, -1.06, 0.12), pelR=(12, 4, 0), chest=(46, 6, 0), neck=(-20, 0, 0), **bowed)],
                 priority="Action4", feet_free=[(0, 2.2)], authored_feet=True, notes="Takes the deathblow on the knee: head snaps back, then the old body bows over the haft.",
                 # (2026-11-09) the blow drives the corruption out of him (as Death lets it go when he falls): phase 2's layer pitched his chest 8 deg
                 # and hips 6 further into the bow, onto his right arm (0.27 in his chest f21-25, every fist placement tried 0.27-0.34); phase 1's bow is clear
                 uncorrupt=(0.05, 0.6)),
            death(),
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
        # (2026-11-09) the roar throws the glaive up and out in his right hand and flings the left arm wide. Keyed as both hands on a haft laid out
        # to his right (H(70, 38) from a fist at his right hip), the lead hand's spot lay 2.4-2.7 from its shoulder: the solver slid it in and dragged
        # the weapon across him, and both arms lay 0.3-0.37 through his chest for 0.8 s (f3-24), the haft's butt through his hips. Now, in his chest's
        # own frame (no corruption layer in this clip): the fist out past his right shoulder, the blade up beside him; the fist and haft carried there
        # from the handoff in that frame (in the world's, the fist swung behind his back on the way); the left hand off the haft toward his
        # front-left by 0.14 s (held on, the straight arm crossed his chest at 0.38), out wide for the roar, and back on the haft as he settles
        Rh, ah = chest_frame(R, corrupt=False)
        q0, h0, e0 = (np.array(R["rp"], float) - ah) @ Rh, L.unit(np.array(R["haft"], float) @ Rh), L.unit(np.array(R["face"], float) @ Rh)
        q1, h1 = np.array([1.55, 1.15, -0.45]), L.unit(np.array([-0.1, 0.95, -0.3]))
        e1 = L.unit(L.orth(np.array([1.0, 0.0, -0.6]), h1))
        rise = dict(pel=(0.0, 0.0, 0.14), pelR=(-13, 0, 0), chest=(-22, 0, 0), neck=(18, 0, 0), rsl=RSL, lsl=LSL, relb=(0.9, -0.2, 0.3), hov=0.0)
        Rr, ar = chest_frame(rise, corrupt=False)
        wide = dict(lhw=0.0, ltw=1.0, lt=(-1.35, 0.35, -0.35), lelb=(-0.2, -0.7, 0.5), lha=(0.0, 0.0, 0.0))
        held = dict(rp=tuple(ar + Rr @ q1), haft=tuple(Rr @ h1), face=tuple(Rr @ e1))
        rise.update(held, **wide)
        carry = []
        for i in range(1, 10):     # the body's own keys between the handoff and the roar, as Clip.controls eases them ("snap")
            s_ = i / 10
            k = {n: tuple(np.array(R[n], float) + (np.array(rise[n], float) - np.array(R[n], float)) * L.EASE["snap"](s_)) for n in ("pel", "pelR", "chest")}
            Rt, at = chest_frame(k, corrupt=False)
            g = L.smooth01(s_)
            hh = L.unit(h0 + (h1 - h0) * g)
            carry.append(K(0.32 * s_, "lin", rp=tuple(at + Rt @ (q0 + (q1 - q0) * g)), haft=tuple(Rt @ hh), face=tuple(L.orth(Rt @ L.unit(e0 + (e1 - e0) * g), Rt @ hh))))
        return [Clip(rg, P + "Transform", 1.5, [
            K(0, hov=0.0, **R),
            K(0.14, "out", lhw=0.0, ltw=1.0, lt=(-0.7, -0.6, -1.0), lelb=(-0.5, -0.6, 0.4)),
            K(0.32, "snap", **rise),
            K(0.8, "io", pel=(0.0, 0.0, 0.14), pelR=(-15, 0, 0), chest=(-25, 0, 0), neck=(20, 0, 0), hov=HOVER * 0.75, **held, **wide),
            K(1.12, "io", lhw=0.0, ltw=1.0), K(1.38, "io", lhw=1.0, ltw=0.0),
            K(1.5, "io", **READY, hov=HOVER),
        ] + carry, priority="Action4", corrupt=False, feet_free=[(0, 1.5)], airborne=True, authored_feet=True, notes="Revealed from the shared handoff pose in the burst: he straightens, flings the glaive up and out in his right hand and his left arm wide, and on the roar his feet leave the floor; he takes the haft again in both hands as he settles. Ends exactly on the phase 2 idle.")]

    out = [idle(), strike(), flourish(), feint()] + locomotion() + guard() + reactions() + transform()
    out += [crescent_reap(), returning_tide(), heaven_cleave(), green_dragon(), charging_cut(), cyclone()]
    out += [flowing_glaive(), prayer_beads(), abbot_sweep(), hesitant_moon(), wheel_of_heaven()] if not floating else [blood_wave(), skyfall(), crimson_embrace(), rending_arc(), phantom_drift()]
    # (2026-11-09) per-clip bake opt-ins (shen_lib.Clip; the windows-pass scripts named are in outputs/grandmaster-shen-2026-11-05/repair/).
    # IDLE_HOLD is how each phase's Idle bake holds the guard, as swivel's state per hand (grip slant, turn round the haft, elbow turn; read off the
    # Idle bakes with swcost.py): the clips in `ends` start and end holding it. The game's 0.15 s joint fade between Idle and an end held one
    # elbow step (or, the lead hand, a flipped elbow) away put an arm 0.18-0.19 in his chest though both ends were clear (fadecheck2.py).
    # Phase 2 Hit Light Left holds it through its fade in as well (`entry`: in 0.185 -> 0.154, out 0.171 -> 0.127), and so does Phantom Drift,
    # a contact attack the game fades in over 0.1 s (BossAnimations.play; fadecheck3.py: 0.1 s in 0.182 -> 0.138, 0.15 s in 0.165 -> 0.138).
    # Deathblow Victim, entered from Idle while his stance is broken, holds its own first grip through its fade in: its swivel path swung the
    # right elbow 130 deg over those frames, and the fade from Idle passed the arm 0.18 into his chest (0.10 held; entrypick.py).
    # Phase 1 Guandao_L3's lead elbow sits in the other half turn from Idle's (about 180 deg off) all through the cut: Idle's grip pinned at its
    # end flipped the whole path to Idle's half and put the left arm 0.21 in his chest at f10 (swpath.py), so its left hand ends on the grip of
    # its own half whose fade to Idle is clearest instead (endpick.py: out 0.180 -> 0.039).
    # Flowing Jian eases its blow-frame tilt as an envelope (wrist_yield), and swivel's torso recheck walks each run of its frames past the wall as
    # one (recheck_runs): frame by frame, its left hand ended f84-85 a half-mix of unrelated grips (wrist 173 and 154 deg; walked as a run 27 and 35, swrecheck.py).
    # (2026-11-10) Phase 2 Skyfall walks its runs past the wall as one too (with its carried follow-through, skyfall()), and its right hand ends
    # on the grip whose 0.15 s fade to Idle is clearest from its own last pose (endpick.py: out 0.185 -> 0.122) rather than on Idle's own: with
    # Idle's held at both ends its bake left the arm 0.21 in his chest at f58-59. Its fade in from Idle is clear without a pin (0.1 s: 0.110).
    IDLE_HOLD = {"Right": (-20.0, 270.0, 51.43), "Left": (-20.0, 270.0, 0.0)} if phase == 1 else {"Right": (10.0, 22.5, 334.29), "Left": (-10.0, 292.5, 25.71)}
    ends = set() if phase == 1 else {"BloodWave", "CrimsonEmbrace", "Feint", "HitLightFront", "HitLightLeft", "PhantomDrift", "RendingArc"}
    entry = set() if phase == 1 else {"HitLightLeft", "PhantomDrift"}
    for c in out:
        short = c.name[len(P):]
        if short in ends:
            c.hold_start = c.hold_end = IDLE_HOLD
            c.hold_entry = short in entry
        if phase == 1 and short == "Guandao_L3":
            c.hold_start, c.hold_end = {"Right": IDLE_HOLD["Right"]}, {"Right": IDLE_HOLD["Right"], "Left": (-20.0, 292.5, 154.29)}
        if phase == 2 and short == "GuandaoSkyfall":
            c.hold_end = {"Right": (0.0, 67.5, 334.29)}
        if phase == 2 and short == "DeathblowVictim":
            c.hold_start, c.hold_entry = {"Right": (10.0, 90.0, 0.0)}, True
        c.blow_envelope = phase == 1 and short == "FlowingJian"
        c.run_recheck = (phase == 1 and short == "FlowingJian") or (phase == 2 and short == "GuandaoSkyfall")
        # (2026-11-10) and its recheck walk may not swing the lead hand round for a frame: f88 took a grip 45 deg from both neighbours and the
        # prayer beads whipped up past his head at the overhead finish's follow-through (see RECHECK_SPIKE_COST)
        c.recheck_spike = 15.0 if phase == 1 and short == "FlowingJian" else None
        # (2026-11-11) legs_guard (held_clash also weighs the glaive inside his legs) was built for phase 2 Skyfall: its fist slide, depop and
        # polish run the wood ahead of the right fist 0.12 into his right thigh after the landing (f49-50), unseen by every pass and by validate's
        # thinned weapon_in_legs (legprobe.py). Not adopted: with it the legs stay clear but the right arm ends 0.18-0.20 in his chest over f45-55,
        # which the polish could not clear (legpol_1/2.log: 0.184 left), and the full bake with it shows a 0.57 blade pop at f46 before its
        # polish (ttlgS). No clip opts in, so the exported Skyfall is the bake above and the thigh is open (windows-pass-2026-11-09/REPORT.md).
        c.legs_guard = False
    return out


TURN_RATE = 220   # degrees per second at playback 1: BossAnimationRules.TurnRate


def library():
    return build(1) + build(2)
