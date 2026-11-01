"""Corrupt Wandering Monk: the fallen temple brawler's own clip set.

Attacks are timed from the built WeaponSchema Unarmed moves (castlib.timing): clip length = the move's total and the
blow lands at startup + active/2, the time FighterAnimations phase-locks to the server's move clock. Strikes are
real ones: a planted support foot, the hips turning the shoulder through, the fist (vertical, kung-fu style) or elbow
or knee arriving on the facing, then a recovery back to the guard. Hit reactions, posture break and the death are his
too; Deflect, Backdash, Roll and Recover stay on the shared universal clips.
"""
import castlib as C
from castlib import Clip, pose

UPPER = {"UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand"}
R, L = ("RightHand", "fist"), ("LeftHand", "fist")
ELBOW = ("RightUpperArm", (0.97, 0.03, 0.0))   # the visible point of the elbow at rest
KNEE = ("RightUpperLeg", (0.42, -1.84, 0.0))


def attack(name, move, keys, T, striker, **kw):
    m = T[move]
    s, a = m["startup"], m["active"]
    return Clip(name, m["total"], keys, priority="Action2", move=move, kind=m["kind"], contacts=[s + a * 0.5],
                active=(s, a, m["arc"], m["reach"]), striker=striker, slot="CorruptWanderingMonk." + kw.pop("key"), **kw)


def idle():
    # Coiled, restless guard: weight rocks between the feet, the lead fist hunts in small circles, a shoulder twitch.
    k = [(0.0, pose(), "inout")]
    for i, (dy, lx, ly, ch) in enumerate([(-0.04, 0.05, -0.03, 2), (0.0, 0.0, -0.06, 0), (-0.03, -0.05, -0.02, -2)]):
        k.append(((i + 1) * 0.6, {"pel": (0.0, -0.3 + dy, 0.08), "lh": (-0.24 + lx, 0.84 + ly, -1.16), "chest": (-6 + ch * 0.5, 10 + ch, 0),
                                  "rh": (0.36, 0.86 + dy * 0.8, -0.62)}, "inout"))
    return Clip("Monk_Idle", 2.4, k, loop=True, priority="Movement", slot="CorruptWanderingMonk.Idle",
                notes="Guard loop: orthodox, left lead, fists at the chin; legs keyed so it only plays standing.")


def move():
    # Arms-only stalking guard over the walk: fists stay up and bob with the steps.
    keys = [(0.0, pose(), "inout"), (0.35, {"rh": (0.36, 0.82, -0.6), "lh": (-0.24, 0.8, -1.12), "chest": (-8, 8, 0)}, "inout")]
    return Clip("Monk_Move", 0.7, keys, loop=True, priority="Movement", mask=UPPER, slot="CorruptWanderingMonk.Move",
                notes="Upper-body guard carried over Roblox's walk/run.")


def light1(T):
    # Flicker Jab: the lead fist snaps straight out on a short step, shoulder turned in to cover the chin.
    m = T["Unarmed_L1"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        (0.04, {"lh": (-0.26, 0.8, -1.02), "pelR": (0, -22, 0)}, "inout"),
        (s + a * 0.5, {"lh": (-0.08, 0.88, -2.3), "lelb": (-0.3, -1, 0.1), "pelR": (0, -44, 0), "chest": (-8, 6, 0),
                       "pel": (0.0, -0.33, -0.22), "lf": (-0.45, -0.85, 0, -14, 0), "rh": (0.32, 0.9, -0.52)}, "snap"),
        (s + a, {"lh": (-0.08, 0.88, -2.33)}, "linear"),
        (s + a + 0.05, {"lh": (-0.2, 0.84, -1.45), "pelR": (0, -34, 0), "pel": (0.0, -0.31, -0.08)}, "out"),
        (m["total"], pose(), "inout"),
    ]
    return attack("Monk_L1", "Unarmed_L1", keys, T, L, key="Light1", notes="Flicker Jab: lead-hand vertical fist, short step.")


def light2(T):
    # Snapping Cross: the rear heel turns out, the hips and shoulder drive the right fist down the centre line.
    m = T["Unarmed_L2"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        (0.045, {"rh": (0.44, 0.8, -0.42), "pelR": (0, -32, 0)}, "inout"),
        (s + a * 0.5, {"rh": (0.06, 0.9, -2.2), "relb": (0.3, -1, 0.1), "pelR": (0, 14, 0), "chest": (-10, 8, 0),
                       "pel": (0.0, -0.36, -0.36), "rf": (0.6, 0.5, 0, 30, -22), "lh": (-0.34, 0.88, -0.62)}, "snap"),
        (s + a, {"rh": (0.06, 0.9, -2.23)}, "linear"),
        (s + a + 0.06, {"rh": (0.3, 0.86, -1.3), "pelR": (0, -8, 0), "pel": (0.0, -0.33, -0.1)}, "out"),
        (m["total"], pose(), "inout"),
    ]
    return attack("Monk_L2", "Unarmed_L2", keys, T, R, key="Light2", notes="Snapping Cross: rear straight, heel turned, hips through.")


def light3(T):
    # Temple Hook: the lead arm locks into a horizontal hook and the whole body pivots on the lead foot, sweeping the
    # fist left to right across the facing at temple height.
    m = T["Unarmed_L3"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        (0.055, {"lh": (-0.95, 0.9, -0.95), "lelb": (-1, 0.4, 0.3), "pelR": (0, -46, 0), "chest": (-6, -4, 0)}, "inout"),
        (s, {"lh": (-0.7, 0.94, -1.5), "lelb": (-1, 0.25, 0.4), "pelR": (0, -30, 0)}, "snap"),
        (s + a * 0.5, {"lh": (-0.2, 0.95, -1.8), "lelb": (-0.8, 0.3, 0.6), "pelR": (0, -6, 0), "chest": (-8, 6, 0),
                       "pel": (0.0, -0.34, -0.18)}, "linear"),
        (s + a, {"lh": (0.15, 0.92, -1.45), "lelb": (-0.5, 0.4, 0.8), "pelR": (0, 8, 0), "chest": (-6, -6, 0)}, "linear"),
        (s + a + 0.06, {"lh": (0.3, 0.86, -1.1), "lelb": (-0.4, 0, 1), "pelR": (0, 4, 0)}, "out"),
        (m["total"], pose(), "inout"),
    ]
    return attack("Monk_L3", "Unarmed_L3", keys, T, L, key="Light3", notes="Temple Hook: horizontal lead hook, pivot on the lead foot.")


def light4(T):
    # Collapsing Palm: the right hand chambers at the hip while the left reaches out to measure, then a stomping step
    # drives the heel of the right hand forward as the left pulls back to the hip.
    m = T["Unarmed_L4"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        (0.06, {"rh": (0.5, 0.35, -0.05), "relb": (0.6, -0.4, 1), "rflex": -30, "pelR": (0, -40, 0), "pel": (0.0, -0.36, 0.14),
                "lh": (-0.12, 0.82, -1.55), "lelb": (-0.3, -1, 0)}, "inout"),
        (s + a * 0.5, {"rh": (0.1, 0.52, -2.35), "rflex": -58, "relb": (0.25, -1, 0.2), "pelR": (0, 16, 0), "chest": (-12, 6, 0),
                       "pel": (0.0, -0.5, -0.42), "lf": (-0.45, -1.02, 0, -10, 0), "rf": (0.6, 0.5, 0, 30, -16),
                       "lh": (-0.6, 0.22, 0.05), "lelb": (-0.6, -0.5, 1)}, "snap"),
        (s + a, {"rh": (0.1, 0.52, -2.38)}, "linear"),
        (s + a + 0.08, {"rh": (0.3, 0.6, -1.6), "rflex": -30, "pel": (0.0, -0.42, -0.25), "pelR": (0, 0, 0)}, "out"),
        (m["total"], pose(), "inout"),
    ]
    return attack("Monk_L4", "Unarmed_L4", keys, T, R, key="Light4", notes="Collapsing Palm: stomp step, palm-heel thrust, counter-pull.")


def heavy(T):
    # Iron Mountain Elbow: coil back onto the rear leg, then a long stomp into a deep horse stance drives the folded
    # right elbow through the centre line like a battering ram.
    m = T["Unarmed_Heavy"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        (0.18, {"rh": (0.7, 0.92, 0.45), "relb": (1, 0.3, 0.6), "pelR": (0, -55, 0), "chest": (-2, -8, 0), "pel": (0.0, -0.28, 0.28),
                "lh": (-0.45, 0.8, -1.0)}, "inout"),
        (0.2, {"lh": (-0.75, 0.25, -0.75), "lspace": 1.0}, "inout"),
        (s + a * 0.5, {"rh": (-0.25, 0.55, -1.3), "relb": (0.1, 0.15, -1), "rflex": 20, "pelR": (0, 38, 0), "chest": (-14, 18, 0),
                       "pel": (0.0, -0.55, -0.6), "lf": (-0.5, -1.1, 0, -12, 0), "rf": (0.6, 0.5, 0, 30, -10),
                       "lh": (-0.95, -0.55, 0.15), "lelb": (-0.8, -0.6, 0.6)}, "snap"),
        (s + a, {"rh": (-0.26, 0.55, -1.33)}, "linear"),
        (s + a + 0.12, {"rh": (0.2, 0.75, -0.9), "lh": (-0.55, 0.45, -0.85), "lspace": 1.0, "pel": (0.0, -0.5, -0.4), "pelR": (0, 10, 0), "chest": (-10, 10, 0)}, "out"),
        (m["total"], pose(), "inout"),
    ]
    return attack("Monk_Heavy", "Unarmed_Heavy", keys, T, ELBOW, key="Heavy",
                  notes="Iron Mountain Elbow: rear-leg coil, stomp into horse stance, folded elbow through the centre.")


def running(T):
    # Flying Knee: launch off the rear foot, both hands dragging an imagined head down as the right knee drives up
    # and through; land on the left foot.
    m = T["Unarmed_Running"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        (0.09, {"pel": (0.0, -0.46, 0.05), "rf": (0.5, 0.7, 0, 20, -30), "rh": (0.35, 1.02, -1.2), "lh": (-0.35, 1.02, -1.2),
                "relb": (0.6, -0.6, 0.4), "lelb": (-0.6, -0.6, 0.4), "pelR": (0, -10, 0)}, "inout"),
        (s + a * 0.5, {"pel": (0.0, 0.1, -1.1), "pelR": (0, 8, 0), "chest": (6, 0, 0), "rf": (0.38, -1.3, 1.35, 0, 70),
                       "rknee": (0, 0.6, -1), "lf": (-0.45, 0.25, 0.45, 0, -25), "rh": (0.3, 0.35, -1.0), "lh": (-0.3, 0.35, -1.0),
                       "relb": (0.8, 0, 0.6), "lelb": (-0.8, 0, 0.6)}, "snap"),
        (s + a, {"rf": (0.38, -1.3, 1.3, 0, 68)}, "linear"),
        (s + a + 0.1, {"pel": (0.0, -0.45, -0.3), "lf": (-0.45, -0.55, 0, -14, 0), "rf": (0.55, -0.1, 0.25, 10, 0), "chest": (-8, 6, 0),
                       "rh": (0.36, 0.8, -0.7), "lh": (-0.26, 0.8, -1.1)}, "out"),
        (m["total"], pose(), "inout"),
    ]
    return attack("Monk_Running", "Unarmed_Running", keys, T, KNEE, key="Running", feet_free=[(0.03, m["total"] - 0.03)],
                  notes="Flying Knee: rear-foot launch, two-hand drag, right knee through, land on the left foot.")


def art(T):
    # Sundering Qi Palm: hands circle down and gather at the waist, he sinks and draws breath, then both palm-heels
    # drive out on a stomp as one wall of force.
    m = T["Unarmed_Art"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        (0.12, {"rh": (0.5, 0.2, 0.15), "lh": (-0.5, 0.2, 0.15), "relb": (1, -0.3, 1), "lelb": (-1, -0.3, 1), "rflex": -20, "lflex": -20,
                "pel": (0.0, -0.5, 0.2), "pelR": (0, -6, 0), "chest": (8, 0, 0), "lf": (-0.5, -0.4, 0, -10, 0), "rf": (0.6, 0.5, 0, 30, 0)},
         "inout"),
        (0.2, {"pel": (0.0, -0.56, 0.22), "chest": (10, 0, 0)}, "inout"),
        (s + a * 0.5, {"rh": (0.28, 0.6, -2.05), "lh": (-0.28, 0.6, -2.05), "rflex": -60, "lflex": -60, "relb": (0.5, -1, 0),
                       "lelb": (-0.5, -1, 0), "pel": (0.0, -0.6, -0.55), "pelR": (0, 0, 0), "chest": (-14, 0, 0),
                       "lf": (-0.5, -1.0, 0, -8, 0), "rf": (0.6, 0.5, 0, 30, -10)}, "snap"),
        (s + a, {"rh": (0.28, 0.6, -2.08), "lh": (-0.28, 0.6, -2.08)}, "linear"),
        (s + a + 0.14, {"rh": (0.35, 0.7, -1.6), "lh": (-0.3, 0.7, -1.7), "rflex": -25, "lflex": -25, "pel": (0.0, -0.45, -0.35),
                        "chest": (-8, 4, 0)}, "out"),
        (m["total"], pose(), "inout"),
    ]
    return attack("Monk_Art", "Unarmed_Art", keys, T, R, key="WeaponArt",
                  notes="Sundering Qi Palm: gather and sink, double palm-heel on a stomp (hyperarmour, unblockable).")


def guard():
    # Forearms stacked in front of the face, chin tucked, hunched: upper body only so he can still step.
    g = {"rh": (0.14, 1.12, -0.72), "lh": (-0.16, 1.05, -0.86), "relb": (0.3, -1, -0.2), "lelb": (-0.3, -1, -0.2),
         "chest": (-12, 4, 0), "neck": (10, 0, 0), "rflex": 10, "lflex": 10}
    keys = [(0.0, pose(**g), "inout"), (0.8, pose(**dict(g, chest=(-13, 5, 0), rh=(0.14, 1.1, -0.7))), "inout")]
    return Clip("Monk_Guard", 1.6, keys, loop=True, priority="Action", mask=UPPER, slot="CorruptWanderingMonk.Guard",
                notes="Forearm guard, upper body only.")


def guard_impact():
    g = {"rh": (0.14, 1.12, -0.72), "lh": (-0.16, 1.05, -0.86), "relb": (0.3, -1, -0.2), "lelb": (-0.3, -1, -0.2),
         "chest": (-12, 4, 0), "neck": (10, 0, 0), "rflex": 10, "lflex": 10}
    keys = [(0.0, pose(**g), "linear"),
            (0.06, pose(**dict(g, chest=(4, 0, 0), neck=(-6, 0, 0), rh=(0.16, 1.2, -0.45), lh=(-0.18, 1.12, -0.55))), "snap"),
            (0.32, pose(**g), "settle")]
    return Clip("Monk_GuardImpact", 0.32, keys, priority="Action2", mask=UPPER, slot="CorruptWanderingMonk.GuardImpact",
                notes="Blocked blow drives the forearms back into the face, then he re-settles.")


def hit_light():
    keys = [(0.0, pose(), "linear"),
            (0.06, {"chest": (10, -14, 6), "neck": (-14, -18, 0), "pel": (0.0, -0.3, 0.2), "rh": (0.45, 0.7, -0.4),
                    "lh": (-0.45, 0.66, -0.7)}, "snap"),
            (0.18, {"chest": (2, 2, 2), "neck": (-4, -6, 0)}, "out"),
            (0.36, pose(), "inout")]
    return Clip("Monk_Hit_Light", 0.36, keys, priority="Action3", slot="CorruptWanderingMonk.Hitstun_Light",
                notes="Head snaps back and away, guard knocked open, back in the guard.")


def hit_heavy():
    keys = [(0.0, pose(), "linear"),
            (0.08, {"chest": (18, -8, 0), "neck": (-18, 0, 0), "pel": (0.0, -0.3, 0.45), "rh": (0.55, 0.45, -0.3), "lh": (-0.55, 0.45, -0.35),
                    "relb": (1, -0.5, 0.3), "lelb": (-1, -0.5, 0.3), "lf": (-0.45, -0.2, 0, -14, 0)}, "snap"),
            (0.3, {"chest": (-22, 6, 0), "neck": (12, 0, 0), "pel": (0.0, -0.55, 0.5), "rh": (0.5, -0.2, -0.8), "lh": (-0.55, -0.25, -0.75),
                   "rf": (0.6, 0.85, 0, 30, 0)}, "inout"),
            (0.5, {"chest": (-10, 8, 0), "neck": (6, 0, 0), "pel": (0.0, -0.4, 0.25)}, "out"),
            (0.7, pose(), "inout")]
    return Clip("Monk_Hit_Heavy", 0.7, keys, priority="Action3", slot="CorruptWanderingMonk.Hitstun_Heavy", feet_free=[(0.0, 0.7)],
                notes="Rocked back off the lead foot, doubles over, a step back, recovers the guard.")


def stance_broken():
    # Posture broken: dazed, guard dropped, knees soft, swaying, head lolling.
    b = {"pel": (0.0, -0.55, 0.2), "pelR": (0, -10, 0), "chest": (-24, 0, 4), "neck": (18, 0, 6), "rh": (0.55, -0.25, -0.35),
         "lh": (-0.55, -0.3, -0.25), "relb": (1, 0, 0.5), "lelb": (-1, 0, 0.5), "rflex": -10, "lflex": -10, "lookW": 0.2,
         "lf": (-0.5, -0.3, 0, -10, 0), "rf": (0.55, 0.3, 0, 20, 0)}
    keys = [(0.0, pose(**b), "inout"),
            (0.8, pose(**dict(b, chest=(-20, 4, -4), neck=(14, 4, -8), pel=(0.04, -0.6, 0.2))), "inout")]
    return Clip("Monk_StanceBroken", 1.6, keys, loop=True, priority="Action4", slot="CorruptWanderingMonk.StanceBroken",
                notes="Posture break: dazed sway with the guard dropped, the punish window.")


def death():
    # Knees give out under him while the arms go slack and the head drops; EnemyDissolve then topples the body forward.
    keys = [(0.0, pose(), "linear"),
            (0.12, {"chest": (14, 0, 0), "neck": (-16, 0, 0), "pel": (0.0, -0.3, 0.2), "rh": (0.6, 0.4, -0.3), "lh": (-0.6, 0.4, -0.4),
                    "lookW": 0.3}, "snap"),
            (0.55, {"chest": (-30, 0, 6), "neck": (30, 0, 10), "pel": (0.0, -1.05, 0.1), "rh": (0.55, -0.9, -0.3),
                    "lh": (-0.55, -0.95, -0.2), "relb": (1, 0, 0.3), "lelb": (-1, 0, 0.3), "rflex": -20, "lflex": -20, "lookW": 0.0,
                    "lf": (-0.45, -0.55, 0, -14, -40), "rf": (0.55, 0.5, 0, 25, -60), "lknee": (0, -0.3, -1), "rknee": (0, -0.3, -1)},
             "inout"),
            (0.9, {"chest": (-40, 0, 8), "neck": (35, 0, 12), "pel": (0.0, -1.2, 0.05)}, "settle")]
    return Clip("Monk_Death", 0.9, keys, priority="Action4", slot="CorruptWanderingMonk.Death", feet_free=[(0.0, 0.9)],
                notes="Knees buckle and the head drops; held on its last frame while the body topples and burns away.")


def library():
    T = C.timing()
    return [idle(), move(), light1(T), light2(T), light3(T), light4(T), heavy(T), running(T), art(T), guard(), guard_impact(),
            hit_light(), hit_heavy(), stance_broken(), death()]
