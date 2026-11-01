"""The Jian starting set and the shared opening-combat actions.

Attack clips are timed from the built WeaponSchema (jianlib.timing): clip length = the move's total, the contact sits in
the authoritative active window, and FighterAnimations phase-locks playback to the server's move clock, so the blade
reaches the swept shape StrikeGeometry checks. Every attack starts and ends on READY so strings chain cleanly.
"""
import jianlib as J
from jianlib import Clip, pose

READY = J.READY


def attack(name, move, keys, timing, **kw):
    m = timing[move]
    s, a = m["startup"], m["active"]
    return Clip(name, m["total"], keys, priority="Action2", move=move, kind=m["kind"], contacts=[s + a * 0.5],
                active=(s, a, m["arc"], m["reach"] + m["lunge"] * 0.35), **kw)


def idle():
    # Breathing guard: the blade tip draws a small slow circle at the opponent's throat; weight settles on the back leg.
    k = []
    for i, (dy, tip, chest) in enumerate([(0.0, (0, 0), 0), (-0.035, (0.04, -0.03), 1.5), (0.0, (0, -0.05), 0),
                                         (-0.02, (-0.04, -0.02), -1)]):
        d = (READY["dir"][0] + tip[0], READY["dir"][1] + tip[1], READY["dir"][2])
        k.append((i * 0.6, {"pel": (0.05, -0.32 + dy, 0.05), "dir": d, "chest": (4 + chest, -12, 0),
                            "grip": (0.42, -0.62 + dy * 0.6, -1.05)}, "inout"))
    return Clip("Jian_Idle", 2.4, [(0, pose(), "inout")] + k[1:], loop=True, priority="Movement", slot="Jian.Idle",
                notes="Ready stance loop (Movement priority, above avatar idle packs); legs keyed, so it only plays while standing.")


def light1(T):
    # Darting Thrust: a compact fencing extension. Coil the right shoulder back, then the front foot steps as the
    # hips drive the right shoulder through and the arm extends level along the facing.
    m = T["Jian_L1"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        (0.055, {"grip": (0.56, -0.54, -0.72), "dir": (-0.08, 0.2, -1), "pel": (0.1, -0.4, 0.15), "pelR": (0, 14, 0),
                "chest": (6, -6, 0), "lh": (-0.25, -0.15, -0.85)}, "inout"),
        (s + a * 0.5, {"grip": (0.18, -0.12, -2.15), "dir": (-0.02, 0.03, -1), "edge": (0, 1, 0),
                       "pel": (0.08, -0.48, -0.4), "pelR": (0, 36, 0), "chest": (6, -2, 0),
                       "rf": (0.38, -1.25, 0, -6, 0), "relb": (1, -0.4, 0.2),
                       "lh": (-1.15, -0.35, 0.75), "lfing": (-0.4, 0.3, 1), "lpalm": (0, -1, 0.2)}, "snap"),
        (s + a, {"grip": (0.18, -0.12, -2.2)}, "linear"),
        (s + a + 0.07, {"grip": (0.3, -0.35, -1.6), "dir": (-0.1, 0.2, -1), "pel": (0.06, -0.42, -0.2),
                        "pelR": (0, 30, 0), "chest": (5, -8, 0), "rf": (0.42, -0.95, 0, -7, 0),
                        "lh": (-0.7, -0.3, 0.1), "lfing": (0, 0.5, -1), "lpalm": (1, -0.2, 0)}, "out"),
        (m["total"], pose(), "inout"),
    ]
    return attack("Jian_L1", "Jian_L1", keys, T, slot="Jian.Light1", notes="Darting Thrust: level thrust, front-foot step, rear hand counterweights.")


def light2(T):
    # Rising Willow Cut: a backhand that coils the blade low across the left hip, then the hips unwind and the edge
    # rises left-low to right-high through the facing (StrikeGeometry sweeps slashes left to right).
    m = T["Jian_L2"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        (0.06, {"grip": (-0.15, -0.7, -0.75), "dir": (-0.8, -0.35, -0.5), "edge": (-0.2, -1, 0.3), "pelR": (0, 34, 0),
                "chest": (6, 20, 0), "pel": (0.0, -0.42, 0.05), "relb": (0.6, -1, 0.6),
                "lh": (-0.55, -0.25, 0.15), "lfing": (-0.3, 0.4, -1), "lpalm": (0, -0.3, 1)}, "inout"),
        (s, {"grip": (0.05, -0.55, -1.3), "dir": (-0.6, -0.2, -0.78), "edge": (0.6, 0.6, -0.2), "pelR": (0, 28, 0),
             "chest": (4, 10, 0)}, "snap"),
        (s + a * 0.5, {"grip": (0.35, -0.25, -1.6), "dir": (0.0, 0.3, -1), "edge": (0.7, 0.7, 0), "pelR": (0, 18, 0),
                       "chest": (2, -6, 0), "pel": (0.08, -0.45, -0.1), "rf": (0.5, -0.75, 0, -8, 0)}, "linear"),
        (s + a, {"grip": (0.7, 0.05, -1.35), "dir": (0.62, 0.55, -0.6), "edge": (0.6, 0.7, 0.3), "pelR": (0, 8, 0),
                 "chest": (-2, -18, 0), "lh": (-1.3, -0.15, 0.25), "lfing": (-1, 0.2, 0.3), "lpalm": (0, -1, 0)}, "linear"),
        (s + a + 0.05, {"grip": (0.9, 0.3, -0.85), "dir": (0.65, 0.72, -0.25), "edge": (0.2, 0.3, 1), "pelR": (0, 4, 0),
                        "chest": (-4, -22, 0)}, "out"),
        (m["total"], pose(), "inout"),
    ]
    return attack("Jian_L2", "Jian_L2", keys, T, slot="Jian.Light2",
                  notes="Rising Willow Cut: backhand diagonal, left hip to right shoulder height, hips unwind.")


def light3(T):
    # Horizon Sweep: a flat 120 degree cut at chest height; the blade chambers past the left shoulder and the whole
    # body pivots on a right-foot step, with the left hand thrown out to balance the follow-through.
    m = T["Jian_L3"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        (0.06, {"grip": (-0.25, -0.05, -0.75), "dir": (-0.82, 0.05, 0.55), "edge": (0.4, 0, -1), "pelR": (0, 42, 0),
                "chest": (2, 26, 0), "pel": (0.0, -0.4, 0.1), "relb": (0.4, -1, 0.8),
                "lh": (-0.6, -0.3, 0.25), "lfing": (0, 0.6, -1), "lpalm": (1, 0, 0)}, "inout"),
        (s, {"grip": (-0.05, -0.15, -1.35), "dir": (-0.87, 0.0, -0.5), "edge": (0.5, 0, -0.87), "pelR": (0, 34, 0),
             "chest": (2, 14, 0)}, "snap"),
        (s + a * 0.5, {"grip": (0.4, -0.15, -1.65), "dir": (0.0, 0.02, -1), "edge": (1, 0, 0), "pelR": (0, 14, 0),
                       "chest": (2, -4, 0), "pel": (0.12, -0.5, -0.15), "rf": (0.75, -0.8, 0, -25, 0)}, "linear"),
        (s + a, {"grip": (0.85, -0.15, -1.25), "dir": (0.87, 0.0, -0.5), "edge": (0.5, 0, 0.87), "pelR": (0, -6, 0),
                 "chest": (2, -20, 0), "lh": (-1.45, -0.1, -0.2), "lfing": (-1, 0.1, -0.2), "lpalm": (0, -1, 0)}, "linear"),
        (s + a + 0.06, {"grip": (1.05, -0.2, -0.55), "dir": (0.82, 0.02, 0.4), "edge": (-0.4, 0, 1), "pelR": (0, -14, 0),
                        "chest": (0, -26, 0)}, "out"),
        (m["total"], pose(), "inout"),
    ]
    return attack("Jian_L3", "Jian_L3", keys, T, slot="Jian.Light3",
                  notes="Horizon Sweep: flat chest-height cut, full pivot on a right-foot step, left arm counterbalance.")


def light4(T):
    # Piercing Heron Lunge: the string's finisher. The sword fist draws back to the hip while the left hand points
    # the line, then a long right-foot lunge drives a level thrust; the left arm flings back like a heron's wing.
    m = T["Jian_L4"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        (0.075, {"grip": (0.9, -0.65, -0.15), "dir": (0.05, 0.12, -1), "pel": (0.05, -0.55, 0.15), "pelR": (0, 12, 0),
                 "chest": (4, 0, 0), "relb": (0.8, -1, 0.6), "lh": (-0.15, -0.15, -0.95), "lfing": (0.1, 0.1, -1),
                 "lpalm": (1, 0, 0)}, "inout"),
        (s + a * 0.5, {"grip": (0.15, -0.25, -2.3), "dir": (0.0, 0.0, -1), "edge": (0, 1, 0), "pel": (0.1, -0.85, -0.8),
                       "pelR": (0, 38, 0), "chest": (12, -4, 0), "rf": (0.4, -1.75, 0, -4, 0), "lf": (-0.75, 0.75, 0, 50, 0),
                       "relb": (1, -0.3, 0.2), "lh": (-1.2, 0.35, 0.9), "lfing": (-0.5, 0.5, 1), "lpalm": (0, -1, 0)}, "snap"),
        (s + a, {"grip": (0.15, -0.25, -2.4)}, "linear"),
        (s + a + 0.09, {"grip": (0.3, -0.4, -1.8), "dir": (-0.08, 0.15, -1), "pel": (0.08, -0.6, -0.45),
                        "pelR": (0, 32, 0), "chest": (8, -6, 0), "rf": (0.42, -1.25, 0, -6, 0),
                        "lh": (-0.9, -0.1, 0.45)}, "out"),
        (m["total"], pose(), "inout"),
    ]
    return attack("Jian_L4", "Jian_L4", keys, T, slot="Jian.Light4",
                  notes="Piercing Heron Lunge: hip chamber, long lunge thrust, rear arm flung back as a wing.")


def heavy(T):
    # Falling Star Thrust: rise onto the back foot with the blade lifted overhead and the sword-fingers on the wrist,
    # hold, then drop into a deep lunge driving the point down-forward at the chest.
    m = T["Jian_Heavy"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(), "linear"),
        (0.12, {"grip": (0.5, 0.5, -0.6), "dir": (0.05, -0.15, -1), "edge": (0, 1, 0), "pel": (0.05, -0.15, 0.2),
                "pelR": (0, 20, 0), "chest": (-6, -8, 0), "relb": (1, 0.3, 0.6), "rf": (0.45, -0.45, 0.25, -8, 0),
                "lh": (0.1, 0.3, -0.6), "lfing": (0.3, 0.8, -0.5), "lpalm": (1, 0, 0)}, "inout"),
        (0.27, {"grip": (0.52, 0.6, -0.5), "chest": (-9, -8, 0), "pel": (0.05, -0.12, 0.25)}, "inout"),
        (s + a * 0.5, {"grip": (0.15, -0.5, -1.98), "dir": (0.0, -0.2, -1), "pel": (0.08, -0.9, -0.7),
                       "pelR": (0, 34, 0), "chest": (16, -4, 0), "rf": (0.42, -1.65, 0, -4, 0), "relb": (1, -0.3, 0.2),
                       "lh": (-1.3, 0.15, 0.75), "lfing": (-0.5, 0.6, 1), "lpalm": (0, -1, 0)}, "snap"),
        (s + a, {"grip": (0.15, -0.55, -2.03)}, "linear"),
        (s + a + 0.14, {"grip": (0.3, -0.5, -1.7), "dir": (-0.05, 0.05, -1), "pel": (0.08, -0.65, -0.4),
                        "pelR": (0, 30, 0), "chest": (8, -8, 0), "rf": (0.43, -1.15, 0, -6, 0),
                        "lh": (-0.7, -0.2, 0.2), "lfing": (0, 0.5, -1), "lpalm": (1, -0.2, 0)}, "out"),
        (m["total"], pose(), "inout"),
    ]
    return attack("Jian_Heavy", "Jian_Heavy", keys, T, slot="Jian.Heavy",
                  notes="Falling Star Thrust: overhead rise and hold, then a deep falling lunge thrust.")


def running(T):
    # Swallow Skims Water: out of a sprint the body drops almost to the ground and the point skims forward at knee
    # height, then lifts like a swallow leaving the water (Arc 40 is a thrust in StrikeGeometry).
    m = T["Jian_Running"]
    s, a = m["startup"], m["active"]
    keys = [
        (0, pose(chest=(10, -8, 0), pel=(0.05, -0.25, 0)), "linear"),
        (0.1, {"grip": (0.95, -0.8, -0.3), "dir": (0.35, -0.3, -1), "pel": (0.05, -0.7, 0.1), "pelR": (0, 18, 0),
               "chest": (22, -4, 0), "rf": (0.45, -0.9, 0, -6, 0), "relb": (0.8, -1, 0.6),
               "lh": (-0.9, -0.5, -0.4), "lfing": (0, -0.3, -1), "lpalm": (1, 0, 0)}, "inout"),
        (s + a * 0.5, {"grip": (0.2, -1.0, -1.88), "dir": (0.0, 0.0, -1), "edge": (0, 1, 0), "pel": (0.08, -1.1, -0.9),
                       "pelR": (0, 30, 0), "chest": (26, -4, 0), "rf": (0.42, -1.85, 0, -4, 0),
                       "lf": (-0.7, 0.9, 0, 45, 0), "lh": (-1.3, 0.1, 0.8), "lfing": (-0.4, 0.6, 1), "lpalm": (0, -1, 0)}, "snap"),
        (s + a, {"grip": (0.2, -0.82, -1.98), "dir": (0.0, 0.22, -1)}, "linear"),
        (s + a + 0.12, {"grip": (0.32, -0.55, -1.6), "dir": (-0.05, 0.3, -1), "pel": (0.06, -0.65, -0.45),
                        "pelR": (0, 28, 0), "chest": (10, -8, 0), "rf": (0.43, -1.2, 0, -6, 0)}, "out"),
        (m["total"], pose(), "inout"),
    ]
    return attack("Jian_Running", "Jian_Running", keys, T, slot="Jian.Running",
                  notes="Swallow Skims Water: low skimming lunge out of a sprint, point lifts at the end.")


def art(T):
    # Seven Star Flurry: sword-fingers draw qi along the flat, then six rapid points at the stars of the Dipper on
    # the opponent's torso, the seventh a full lunge on the authoritative active frames.
    m = T["Jian_Art"]
    s, a = m["startup"], m["active"]
    stars = [(-0.1, 0.12), (0.08, 0.04), (-0.04, -0.06), (0.1, 0.1), (-0.08, -0.02), (0.04, 0.08)]
    keys = [
        (0, pose(), "linear"),
        (0.09, {"grip": (0.3, -0.35, -0.75), "dir": (-0.05, 0.75, -0.65), "edge": (0, 0.3, 1), "chest": (2, -10, 0),
                "lh": (-0.35, 0.0, -0.95), "lfing": (0.4, 0.7, -0.6), "lpalm": (1, 0, 0)}, "inout"),
        (0.15, {"grip": (0.55, -0.45, -0.5), "dir": (0.0, 0.1, -1), "edge": (0, 1, 0), "pel": (0.08, -0.5, 0.1),
                "pelR": (0, 26, 0), "chest": (6, -8, 0), "lh": (-0.8, -0.1, 0.35), "lfing": (-0.2, 0.6, -1),
                "lpalm": (0, -1, 0)}, "inout"),
    ]
    contacts = []
    for i, (dx, dy) in enumerate(stars):
        out = 0.17 + i * 0.033
        keys.append((out, {"grip": (0.3 + dx * 0.5, -0.3 + dy, -1.62 - 0.03 * i), "dir": (dx, dy, -1),
                           "pel": (0.08, -0.52 - 0.02 * i, 0.05 - 0.05 * i)}, "snap"))
        keys.append((out + 0.016, {"grip": (0.42, -0.4, -1.35 - 0.04 * i)}, "linear"))
        contacts.append(out)
    keys += [
        (s + a * 0.5 + 0.03, {"grip": (0.15, -0.25, -2.08), "dir": (0, 0.02, -1), "pel": (0.1, -0.85, -0.75),
                              "pelR": (0, 38, 0), "chest": (12, -4, 0), "rf": (0.4, -1.7, 0, -4, 0),
                              "lh": (-1.25, 0.3, 0.85), "lfing": (-0.5, 0.5, 1)}, "snap"),
        (s + a + 0.02, {"grip": (0.15, -0.25, -2.12)}, "linear"),
        (s + a + 0.15, {"grip": (0.3, -0.4, -1.75), "dir": (-0.08, 0.15, -1), "pel": (0.08, -0.6, -0.4),
                        "pelR": (0, 30, 0), "chest": (6, -8, 0), "rf": (0.42, -1.2, 0, -6, 0),
                        "lh": (-0.6, -0.2, 0.0), "lfing": (0, 0.5, -1), "lpalm": (1, -0.2, 0)}, "out"),
        (m["total"], pose(), "inout"),
    ]
    clip = attack("Jian_Art", "Jian_Art", keys, T, slot="Jian.WeaponArt",
                  notes="Seven Star Flurry: qi drawn along the flat, six star points, seventh as a full lunge.")
    clip.contacts = contacts + [s + a * 0.5 + 0.03]  # each star point is a deliberate hard stop, not a pop
    return clip


SQUARE = {"pelR": (0, 0, 0), "chest": (0, 0, 0), "pel": (0, 0, 0), "lf": (-0.5, 0, 0, 0, 0), "rf": (0.5, 0, 0, 0, 0)}


def move():
    # Carry while walking or running: arms only (the walk keeps the torso and legs). Low guard at the hip, point
    # level forward (a downward point dipped below the feet under the sprint lean in Studio), left hand relaxed; authored against a square torso, as the walk holds it.
    base = pose(grip=(0.8, -0.6, -0.75), dir=(0.12, -0.1, -1), edge=(0, 1, 0.1), relb=(1, -1, 0.3),
                lh=(-0.95, -0.85, -0.15), lfing=(0.1, -1, -0.3), lpalm=(1, 0, 0), **SQUARE)
    keys = [(0, base, "inout"), (0.4, {"grip": (0.8, -0.56, -0.78), "dir": (0.12, -0.06, -1)}, "inout")]
    return Clip("Jian_Move", 0.8, keys, loop=True, priority="Movement", mask=J.ARMS, slot="Jian.Move",
                notes="Arms-only carry layered over Roblox's walk/run.")


def equip():
    # Draw flourish: from a relaxed hang the blade wheels up beside the body, over and forward into the ready stance.
    rest = pose(grip=(0.95, -1.1, -0.3), dir=(0.05, -0.55, -1), edge=(0, 1, 0), lh=(-1.0, -1.0, -0.05),
                lfing=(0, -1, 0), lpalm=(1, 0, 0), **SQUARE)
    keys = [
        (0, rest, "linear"),
        (0.18, {"grip": (1.05, -0.6, 0.15), "dir": (0.1, 0.9, 0.4), "edge": (0, -0.4, 0.9), "relb": (1, -1, 0.8)}, "inout"),
        (0.27, {"grip": (1.0, -0.2, -0.15), "dir": (0.08, 0.8, -0.5), "edge": (0, 0.53, 0.85)}, "linear"),
        (0.36, {"grip": (0.85, 0.1, -0.55), "dir": (0.05, 0.25, -1), "edge": (0, 0.97, 0.24), "pelR": (0, 14, 0),
                "lh": (-0.3, 0.0, -0.75), "lfing": (0.3, 0.8, -0.5), "lpalm": (1, -0.2, 0), "rf": (0.48, -0.35, 0, -4, 0)},
         "inout"),
        (0.65, pose(), "inout"),
    ]
    return Clip("Jian_Equip", 0.65, keys, priority="Action", slot="Jian.Equip", notes="Draw flourish into the ready stance.")


GUARD_POSE = {"grip": (0.3, -0.4, -0.95), "dir": (-0.3, 0.9, -0.3), "edge": (0, 0, -1), "relb": (1, -1, 0.2),
              "chest": (6, -10, 0), "lh": (-0.4, -0.05, -0.75), "lfing": (0.3, 1, -0.2), "lpalm": (1, 0, -0.3)}


def guard():
    # Guard: blade upright before the centre line, edge to the opponent, sword-fingers braced behind the spine.
    # Upper body only, so a guarding fighter still walks; the stance legs come from the ready loop underneath.
    keys = [(0, pose(**GUARD_POSE), "inout"), (1.0, {"grip": (0.3, -0.43, -0.93), "chest": (7, -10, 0)}, "inout")]
    return Clip("Jian_Guard", 2.0, keys, loop=True, priority="Action", mask=J.UPPER, slot="Jian.Guard",
                notes="Upright guard, upper body only.")


def guard_impact():
    # A blocked hit drives the guard back into the chest; it re-sets by the end of blockstun.
    keys = [(0, pose(**GUARD_POSE), "linear"),
            (0.06, {"grip": (0.32, -0.32, -0.6), "dir": (-0.4, 0.88, -0.1), "chest": (-6, -6, 3), "lh": (-0.4, 0.0, -0.5)}, "out"),
            (0.35, pose(**GUARD_POSE), "inout")]
    return Clip("Jian_GuardImpact", 0.35, keys, priority="Action3", mask=J.UPPER, slot="Jian.GuardImpact",
                notes="Guard recoil under a blocked hit; ends on the guard pose.")


def deflect():
    # Beat parry: the blade snaps to the inside line, then beats outward with the forte, returning to ready.
    keys = [(0, pose(), "linear"),
            (0.05, {"grip": (0.15, -0.15, -1.05), "dir": (-0.35, 0.88, -0.35), "edge": (-1, 0, -0.2), "chest": (4, 4, 0),
                    "lh": (-0.4, -0.3, -0.3), "lfing": (0, 0.6, -1), "lpalm": (1, 0, 0)}, "inout"),
            (0.11, {"grip": (0.6, -0.05, -1.05), "dir": (0.35, 0.82, -0.45), "edge": (1, 0, -0.3), "chest": (2, -16, 0)}, "inout"),
            (0.32, pose(), "inout")]
    return Clip("Fighter_Deflect", 0.32, keys, priority="Action3", mask=J.UPPER, slot="Deflect",
                notes="Beat parry, upper body only.")


def roll():
    # Dodge: a low ducking shuffle that reads in any direction (the server carries the body); blade tucked forward.
    low = {"pel": (0.0, -1.05, 0.05), "pelR": (0, 15, 0), "chest": (32, -6, 0), "grip": (0.6, -1.0, -0.4),
           "dir": (0.15, 0.05, -1), "lh": (-0.7, -1.1, -0.45), "lfing": (0, -0.6, -1), "lpalm": (1, 0, 0),
           "lf": (-0.7, 0.45, 0.12, 30, 0), "rf": (0.5, -0.5, 0.12, -6, 0)}
    keys = [(0, pose(), "linear"), (0.09, low, "out"),
            (0.24, dict(low, lf=READY["lf"], rf=READY["rf"]), "linear"),
            (0.36, pose(), "inout")]
    return Clip("Fighter_Dodge", 0.36, keys, priority="Action2", slot="Roll", feet_free=[(0.0, 0.3)],
                notes="Low evasive duck; the server moves the root, the clip keeps the body compact.")


def backdash():
    # Backstep: a light hop back with the guard held forward.
    keys = [(0, pose(), "linear"),
            (0.07, {"pel": (0.05, -0.15, 0.25), "chest": (-8, -10, 0), "lf": (-0.75, 0.65, 0.25, 40, 0),
                    "rf": (0.45, -0.4, 0.3, -8, 0), "grip": (0.42, -0.5, -1.0)}, "out"),
            (0.15, {"pel": (0.05, -0.42, 0.12), "chest": (2, -12, 0), "lf": (-0.75, 0.6, 0, 40, 0),
                    "rf": (0.45, -0.6, 0, -8, 0)}, "in"),
            (0.22, pose(), "inout")]
    return Clip("Fighter_Backstep", 0.22, keys, priority="Action2", slot="Backdash", feet_free=[(0.0, 0.2)],
                notes="Backstep hop, guard kept forward.")


def hit_light():
    keys = [(0, pose(), "linear"),
            (0.05, {"chest": (-14, 6, 6), "neck": (-14, 8, 0), "lookW": 0.4, "pel": (0.05, -0.36, 0.2),
                    "grip": (0.75, -0.45, -0.75), "dir": (0.4, 0.4, -1), "lh": (-0.9, -0.3, -0.2)}, "out"),
            (0.28, pose(), "inout")]
    return Clip("Fighter_HitLight", 0.28, keys, priority="Action3", slot="Hitstun_Light", notes="Light flinch.")


def hit_heavy():
    keys = [(0, pose(), "linear"),
            (0.07, {"chest": (-24, 14, 10), "neck": (-18, 10, 6), "lookW": 0.2, "pel": (0.1, -0.5, 0.45),
                    "pelR": (0, 34, 4), "grip": (1.05, -0.3, -0.35), "dir": (0.6, 0.45, -0.6), "relb": (1, -0.6, 0.8),
                    "lh": (-1.25, 0.1, 0.2), "lfing": (-1, 0.3, 0), "lpalm": (0, -1, 0)}, "out"),
            (0.2, {"rf": (0.45, -0.1, 0, -10, 0), "pel": (0.08, -0.6, 0.35), "chest": (-6, 8, 4)}, "inout"),
            (0.48, pose(), "inout")]
    return Clip("Fighter_HitHeavy", 0.48, keys, priority="Action3", slot="Hitstun_Heavy",
                notes="Heavy recoil with a stagger step back.")


BROKEN = {"pel": (0.05, -0.75, 0.15), "pelR": (0, 14, 0), "chest": (28, -4, 8), "neck": (12, 0, 0), "lookW": 0.3,
          "grip": (0.95, -1.35, -0.6), "dir": (0.32, -0.4, -0.86), "edge": (0, 1, 0), "relb": (1, -0.2, 0.3),
          "lh": (-0.45, -0.95, -0.6), "lfing": (0.3, -1, -0.3), "lpalm": (1, 0, 0.3)}


def stance_broken():
    keys = [(0, pose(**BROKEN), "inout"),
            (0.6, {"chest": (31, 2, 10), "pel": (0.08, -0.8, 0.12), "grip": (0.95, -1.4, -0.55)}, "inout")]
    return Clip("Fighter_PostureBroken", 1.2, keys, loop=True, priority="Action4", slot="StanceBroken",
                notes="Posture broken: hunched, sword arm hanging, swaying.")


def recover():
    keys = [(0, pose(**BROKEN), "linear"),
            (0.15, {"chest": (12, -6, 2), "neck": (-6, -12, 0), "pel": (0.05, -0.55, 0.1),
                    "grip": (0.6, -0.9, -0.8), "dir": (0, 0.1, -1)}, "inout"),
            (0.45, pose(), "inout")]
    return Clip("Fighter_Recover", 0.45, keys, priority="Action3", slot="Recover",
                notes="Posture recovery: shake off, re-raise the blade into the ready stance.")


def library():
    T = J.timing()
    return [idle(), move(), equip(), light1(T), light2(T), light3(T), light4(T), heavy(T), running(T), art(T),
            guard(), guard_impact(), deflect(), roll(), backdash(), hit_light(), hit_heavy(), stance_broken(), recover()]
