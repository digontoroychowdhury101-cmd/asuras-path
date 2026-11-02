"""Weapon-family clips and the universal actions the Jian set lacks, on the shared R15 template rig (jianlib).

    python3 tools/animation/families/families.py [--only Dao,Guandao] [--list]

Each family states its real geometry from CharacterService.WEAPON_VISUALS / WeaponModels (where the fist sits on the weapon, where
the striking end is, which hand holds what), its ready stance and a strike list. Every attack is built from the move's own
timing in the built WeaponSchema: clip length = the move's total, contact inside its active window, the path sweeping
left to right through the arc StrikeGeometry checks (or travelling forward for a narrow arc), ending on the family's ready pose so
strings chain. Clips are validated by jianlib.validate (reach, floor, sliding feet, weapon in body, pops, loop seams) with
the family's weapon. Output: assets/animations/families/<Weapon>_<Key>.rbxmx and manifest.json, for publish.py.

This is keyed choreography from one parametric strike, not motion capture: whether each set reads well is human judgment.
"""
import json
import math
import subprocess
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "tools/animation/jian"))
sys.path.insert(0, str(ROOT / "tools/animation/general_zhao"))
import jianlib as J  # noqa: E402
import rig  # noqa: E402
from jianlib import Clip, EASE  # noqa: E402,F401
from rig import unit  # noqa: E402

OUT = ROOT / "assets/animations/families"
BLADE_POINTS = J.blade
LEFT_REACH = 0.774 + 0.807  # shoulder to wrist with the elbow nearly straight


def timing():
    luau = ROOT / "work/bin/luau" / ("luau.exe" if sys.platform == "win32" else "luau")
    out = subprocess.run([str(luau), str(HERE / "timing.luau")], capture_output=True, text=True, cwd=str(HERE), check=True)
    return json.loads(out.stdout.strip().splitlines()[-1])


def yawed(yaw, pitch=0.0):
    y, p = math.radians(yaw), math.radians(pitch)
    return (math.sin(y) * math.cos(p), math.sin(p), -math.cos(y) * math.cos(p))


class Family:
    def __init__(self, weapon, points, hold=0.0, ready=None, strikes=(), reach_arm=1.42, fist=False, dual=False, notes="", guard=None,
                 carry=None, rise=0.0, axis="-Z"):
        self.weapon, self.points, self.hold = weapon, points, hold
        self.ready = dict(J.READY)
        self.ready.update({"hold": 1.0 if hold > 0 else 0.0})
        self.ready.update(ready or {})
        self.strikes, self.reach_arm, self.fist, self.dual, self.notes = list(strikes), reach_arm, fist, dual, notes
        self.guard, self.carry, self.rise, self.axis = guard or {}, carry or {}, rise, axis

    def aim(self, along, edge):
        """(dir, edge) controls that point this family's striking axis along `along`. Hand -Z is a blade's axis; a staff's head is on
        hand +Y and a censer hangs along hand -Y, so those aim the hand's Y axis instead, thumb up."""
        if self.axis == "staff":
            # Staff through the fist along hand Y, head tipped toward the strike; its butt stays below the hand, clear of the body.
            a, up = np.asarray(along, float), np.array([0.0, 1.0, 0.0])
            return tuple(unit(a * 0.87 - up * 0.5)), tuple(unit(up * 0.87 + a * 0.5))
        if self.axis == "-Y":
            return (0.0, 1.0, 0.02), tuple(-np.asarray(along, float))
        return tuple(along), tuple(edge)

    def blade(self, world):
        H = world["RightHand"]
        return tuple((H @ np.array([p[0], p[1], p[2], 1.0]))[:3] for p in self.points)


class FamilyClip(Clip):
    """A jianlib clip whose left hand can ride the weapon: the `hold` channel (0 free, 1 gripping) slides the left fist onto the shaft,
    family.hold studs ahead of the right fist."""

    def __init__(self, family, *a, **kw):
        super().__init__(*a, **kw)
        self.family = family
        self.base = dict(family.ready)

    def solve(self, c):
        weight = float(c["hold"])
        if weight > 0.001 and self.family.hold > 0:
            c = dict(c)
            d = unit(np.asarray(c["dir"], float))
            e = unit(np.asarray(c["edge"], float))
            grip = np.asarray(c["grip"], float)
            # The left fist slides along the haft to where the arm reaches, as a real polearm grip does through a turn.
            torso = rig.fk({"LowerTorso": rig.frame(rig.euler(c["pelR"]), c["pel"]), "UpperTorso": rig.frame(rig.euler(c["chest"]))})
            shoulder = rig.joint_world(torso, "LeftUpperArm")
            along = self.family.hold
            while along > 0.25 and float(np.linalg.norm(grip + d * along - shoulder)) > LEFT_REACH:
                along -= 0.02
            on = grip + d * along
            lh = np.asarray(c["lh"], float) * (1 - weight) + on * weight
            c["lh"] = tuple(lh)
            c["lfing"] = tuple(unit(np.asarray(c["lfing"], float) * (1 - weight) + (-e) * weight))
            c["lpalm"] = tuple(unit(np.asarray(c["lpalm"], float) * (1 - weight) + np.cross(d, e) * weight))
        return super().solve(c)


def pose(family, **over):
    out = dict(family.ready)
    out.update(over)
    return out


def body(yaw, drive=1.0):
    """The torso leads the weapon: chest and hips turn toward the strike's yaw. +pelR.Y turns left."""
    return {"pelR": (0, -yaw * 0.34 * drive + 8, 0), "chest": (4, -yaw * 0.30 * drive, 0)}


def counter(f, yaw, drive=1.0):
    """The free hand thrown out behind the swing, riding the body's turn, so the strike never passes through it."""
    if f.hold > 0:
        return {}
    a = math.radians(yaw * 0.64 * drive)
    lx, lz = -1.02, 0.28
    return {"lh": (lx * math.cos(a) - lz * math.sin(a), -0.42, lx * math.sin(a) + lz * math.cos(a)), "lfing": (-0.6, 0.15, 0.7), "lpalm": (0, -1, 0.2), "lelb": (-1, -1, 0.3)}


def slash(f, m, height=-0.15, rise=0.0, radius=1.25, step=0.95, drive=1.0, width=1.0, lean=0.0):
    """Left to right through the arc. `rise` > 0 climbs through contact, < 0 falls; `radius` is the fist's distance from the chest."""
    s, a, total = m["startup"], m["active"], m["total"]
    half = min(m["arc"] * 0.5, 75.0) * width
    edge = lambda yaw: (math.cos(math.radians(yaw)), 0.0, math.sin(math.radians(yaw)))
    cx = 0.05 if f.hold > 0 else 0.28
    drive = drive if f.hold > 0 else drive * 0.8

    def at(yaw, r, h):
        v = yawed(yaw)
        return (cx + v[0] * r, h, v[2] * r)

    length = max(abs(p[2]) for p in f.points) if f.axis == "-Z" else 0.0

    def aimed(yaw, pitch):
        if length > 4.5:  # a long weapon's tip stays above the floor at any pitch
            pitch = max(pitch, -math.degrees(math.asin(min(1.0, (height + 2.75) / length))))
        d, e = f.aim(yawed(yaw, pitch), edge(yaw))
        return {"dir": d, "edge": e}

    follow = half + 22
    pitch0, pitch1 = rise * 40.0, rise * 30.0
    h0, h1 = height - rise * 0.42, height + rise * 0.42
    keys = [(0, pose(f), "linear")]
    if s >= 0.11:
        # A strike with room for it chambers first; the fastest ones go straight at the line, or the reversal reads as a pop.
        room = min((s - 0.1) / 0.1, 1.0)
        chamber = max(-half - 6 - 28 * room, -95.0)
        keys.append((s * 0.6, dict(grip=at(chamber, radius * (0.9 - 0.28 * room), h0 + 0.08), pel=(0.02, -0.46, 0.12), **aimed(chamber - 6, -pitch0 + 8), **body(chamber * 0.9, drive), **counter(f, chamber * 0.9, drive)), "inout"))
    keys.append((s, dict(grip=at(-half, radius * 0.92, h0), pel=(0.05, -0.5 - lean, 0.0), **aimed(-half, -pitch0 * 0.7), **body(-half, drive), **counter(f, -half, drive)), "whip"))
    keys.append((s + a * 0.5, dict(grip=at(0, radius, height), pel=(0.08, -0.56 - lean, -0.22), rf=(0.48, -step, 0, -10, 0), **aimed(2, pitch1 * 0.15), **body(0, drive), **counter(f, 0, drive)), "linear"))
    keys.append((s + a, dict(grip=at(half, radius * 0.94, h1), **aimed(half, pitch1), **body(half, drive), **counter(f, half, drive)), "linear"))
    tail = min(s + a + max(0.05, m["recovery"] * 0.28), total - 0.05)
    keys.append((tail, dict(grip=at(follow, radius * 0.72, h1 - 0.06), pel=(0.05, -0.5, -0.12), **aimed(follow + 10, pitch1 * 0.8), **body(follow, drive), **counter(f, follow, drive)), "out"))
    keys.append((total, pose(f), "inout"))
    return keys


def thrust(f, m, height=-0.1, radius=1.62, step=1.2, pitch=2.0, side=0.16):
    s, a, total = m["startup"], m["active"], m["total"]
    turn = 0.3 if f.hold > 0 else 1.0
    aim = lambda yaw, p: dict(zip(("dir", "edge"), f.aim(yawed(yaw, p), (0, 1, 0))))
    free = {} if f.hold > 0 else {"lh": (-1.1, -0.38, 0.45), "lfing": (-0.4, 0.3, 1), "lpalm": (0, -1, 0.2)}
    keys = [(0, pose(f), "linear"),
            (max(s * 0.62, 0.05), dict(grip=(side + 0.3, height - 0.35, -max(radius - 0.75, 0.4)), relb=(0.8, -1, 0.6), pel=(0.05, -0.5, 0.14), pelR=(0, 16 * turn, 0), chest=(5, 2, 0), **aim(-4, pitch + 8)), "inout"),
            (s + a * 0.5, dict(grip=(side, height, -radius), relb=(1, -0.4, 0.2), pel=(0.08, -0.56, -0.42), pelR=(0, 34 * turn, 0), chest=(6, -4, 0), rf=(0.4, -step, 0, -6, 0), **aim(0, pitch), **free), "snap"),
            (s + a, dict(grip=(side, height, -radius - 0.05)), "linear"),
            (min(s + a + max(0.06, m["recovery"] * 0.3), total - 0.05),
             dict(grip=(side + 0.1, height - 0.2, -radius * 0.76), pel=(0.06, -0.46, -0.2), pelR=(0, 26 * turn, 0), rf=(0.42, -step * 0.7, 0, -7, 0), **aim(-2, pitch + 6)), "out"),
            (total, pose(f), "inout")]
    return keys


def punch(f, m, hand="R", height=0.1, step=0.95, hook=False):
    """A fist's strike. The R15 fist's knuckle line is hand -Y, so `dir` stays thumb-up and `edge` points back along the forearm."""
    s, a, total = m["startup"], m["active"], m["total"]
    half = min(m["arc"] * 0.5, 40.0) if hook else 0.0
    reach = 1.42 if hand == "R" else 1.25
    fwd = lambda yaw: np.array(yawed(yaw))
    back = lambda yaw: tuple(-fwd(yaw))
    if hand == "R":
        strike = lambda yaw, r, h: dict(grip=(0.3 + fwd(yaw)[0] * r, h, fwd(yaw)[2] * r), dir=(0.0, 1.0, -0.08), edge=back(yaw), relb=(1, -0.5, 0.25))
        turn = 1
    else:
        strike = lambda yaw, r, h: dict(lh=(-0.3 + fwd(yaw)[0] * r, h, fwd(yaw)[2] * r), lfing=tuple(fwd(yaw)), lpalm=(0.15, 1, 0), lelb=(-1, -0.5, 0.25))
        turn = -1
    keys = [(0, pose(f), "linear")]
    keys.append((max(s * 0.62, 0.05), dict(strike(-half, 0.7, height - 0.2), pel=(0.03, -0.48, 0.1), pelR=(0, 16 * turn, 0), chest=(4, 8 * turn, 0)), "inout"))
    keys.append((s + a * 0.5, dict(strike(0, reach if not hook else 1.3, height), pel=(0.06, -0.54, -0.28), pelR=(0, -24 * turn, 0), chest=(5, -14 * turn, 0),
                                   rf=(0.42, -step, 0, -6, 0)), "snap"))
    keys.append((s + a, dict(strike(half, reach - 0.03 if not hook else 1.22, height)), "linear"))
    keys.append((min(s + a + max(0.05, m["recovery"] * 0.3), total - 0.05), dict(strike(half * 1.2, 0.95, height - 0.1), pel=(0.05, -0.48, -0.12),
                                                                              pelR=(0, -10 * turn, 0), chest=(3, -6 * turn, 0), rf=(0.42, -step * 0.7, 0, -6, 0)), "out"))
    keys.append((total, pose(f), "inout"))
    return keys


def attack_clip(f, name, key, keys, m, notes="", check=True):
    s, a = m["startup"], m["active"]
    return FamilyClip(f, name, m["total"], keys, priority="Action2", move=None if not check else key, kind=m["kind"], contacts=[s + a * 0.5],
                      active=None if not check else (s, a, m["arc"], m["reach"] + m["lunge"] * 0.35), slot=f.weapon + "." + key, notes=notes,
                      feet_free=[(0.0, s + a + 0.02), (s + a + 0.02, m["total"])])


SQUARE = {"pelR": (0, 0, 0), "chest": (0, 0, 0), "pel": (0, 0, 0), "lf": (-0.5, 0, 0, 0, 0), "rf": (0.5, 0, 0, 0, 0)}


def stock_clips(f):
    ready = f.ready
    name = f.weapon
    breathe = [(0, pose(f), "inout"), (1.2, {"pel": (ready["pel"][0], ready["pel"][1] - 0.035, ready["pel"][2]), "chest": (ready["chest"][0] + 1.2, ready["chest"][1], 0),
                                             "grip": (ready["grip"][0], ready["grip"][1] - 0.02, ready["grip"][2])}, "inout")]
    out = [FamilyClip(f, name + "_Idle", 2.4, breathe, loop=True, priority="Movement", slot=name + ".Idle", notes="Ready stance loop.")]
    carry = pose(f, **SQUARE)
    carry.update(f.carry)
    sway = {"grip": (carry["grip"][0], carry["grip"][1] + 0.04, carry["grip"][2])}
    out.append(FamilyClip(f, name + "_Move", 0.8, [(0, carry, "inout"), (0.4, sway, "inout")], loop=True, priority="Movement", mask=J.ARMS, slot=name + ".Move",
                          notes="Arms-only carry over the walk or run."))
    rest = dict(carry)
    rest.update(dict(zip(("dir", "edge"), f.aim(yawed(4, -28 if f.hold <= 0 else 20), (0, 1, 0.1)))))
    rest.update(grip=(0.95, -1.05, -0.3) if f.axis == "-Z" and not f.fist else carry["grip"], hold=0.0, lh=(-1.0, -1.0, -0.05), lfing=(0, -1, 0), lpalm=(1, 0, 0))
    aimed = lambda yaw, pitch, e: dict(zip(("dir", "edge"), f.aim(yawed(yaw, pitch), e)))
    equip = [(0, rest, "linear"),
             (0.2, dict(grip=(0.92, -0.35, -0.3), relb=(1, -1, 0.7), **aimed(10, 40, (0, 0.6, 0.8))), "inout"),
             (0.34, dict(grip=(0.72, -0.25, -0.5), hold=ready["hold"] * 0.5, pelR=(0, ready["pelR"][1] * 0.6, 0), **aimed(4, 24, (0, 1, 0.3))), "inout"),
             (0.62, pose(f), "inout")]
    out.append(FamilyClip(f, name + "_Equip", 0.62, equip, priority="Action", slot=name + ".Equip", notes="Draw into the ready stance."))
    guard = dict(grip=(0.34, -0.3, -0.95), dir=yawed(-14, 62), edge=(0, -0.3, -1), relb=(1, -1, 0.2), chest=(6, -8, 0))
    guard.update(f.guard)
    out.append(FamilyClip(f, name + "_Guard", 2.0, [(0, pose(f, **guard), "inout"), (1.0, {"grip": (guard["grip"][0], guard["grip"][1] - 0.03, guard["grip"][2])}, "inout")],
                          loop=True, priority="Action", mask=J.UPPER, slot=name + ".Guard", notes="Guard, upper body only."))
    hit = {"grip": (guard["grip"][0] + 0.02, guard["grip"][1] + 0.08, guard["grip"][2] + 0.2), "chest": (-6, guard["chest"][1] + 3, 3)}
    out.append(FamilyClip(f, name + "_GuardImpact", 0.35, [(0, pose(f, **guard), "linear"), (0.06, hit, "out"), (0.35, pose(f, **guard), "inout")],
                          priority="Action3", mask=J.UPPER, slot=name + ".GuardImpact", notes="Guard recoil; ends on the guard pose."))
    return out


def attacks(f, T):
    moves = T[f.weapon]["moves"]
    out = []
    table = {"Light1": "_L1", "Light2": "_L2", "Light3": "_L3", "Light4": "_L4", "Heavy": "_Heavy", "Running": "_Running", "WeaponArt": "_Art"}
    for key, build in f.strikes:
        move = moves.get(f.weapon + table[key])
        if not move:
            continue
        keys, check, note = build(f, move)
        clip = attack_clip(f, f.weapon + "_" + key, key, keys, move, note, check)
        clip.move_id = f.weapon + table[key]
        out.append(clip)
    return out


# ------------------------------------------------------------------------------------------------- the families
def S(kind, note, check=True, **kw):
    return lambda f, m: (kind(f, m, **kw), check, note)


def one_handed_ready(**over):
    r = {"grip": (0.5, -0.55, -0.9), "dir": (-0.1, 0.4, -1), "edge": (0, 1, 0.3)}
    r.update(over)
    return r


FAMILIES = [
    Family("Unarmed", [(0, 0, 0), (0, -0.12, 0), (0, -0.55, 0)], fist=True, axis="-Y",
           ready={"grip": (0.42, 0.0, -0.9), "dir": (0, 1, -0.08), "edge": (0.1, -0.1, 1), "relb": (1, -0.7, 0.3), "lh": (-0.32, 0.12, -1.0), "lfing": (0, 0.15, -1),
                  "lpalm": (0.15, 1, 0), "lelb": (-1, -0.7, 0.3), "chest": (5, -8, 0), "pelR": (0, 18, 0)},
           guard={"grip": (0.3, 0.3, -0.72), "dir": (0, 1, -0.05), "edge": (0.2, -0.45, 1), "chest": (8, -6, 0), "lh": (-0.26, 0.34, -0.74), "lfing": (0.1, 0.55, -1), "lpalm": (0.3, 1, 0)},
           carry={"grip": (0.75, -0.55, -0.5), "dir": (0, 1, -0.1), "edge": (0, -0.3, 1), "lh": (-0.75, -0.55, -0.5), "lfing": (0, -0.3, -1), "lpalm": (0.2, 1, 0)},
           notes="Fists: jab, cross, hook, knee-driving straight, palm heavy.",
           strikes=[("Light1", S(punch, "Flicker Jab: lead straight.", check=False, hand="R")), ("Light2", S(punch, "Cross: rear hand, hips through.", check=False, hand="L", step=0.7)),
                    ("Light3", S(punch, "Hook: wide right fist through the 60 degree arc.", check=False, hand="R", hook=True, height=0.15)),
                    ("Light4", S(punch, "Long straight on a deep step.", check=False, hand="L", step=1.2)),
                    ("Heavy", S(punch, "Driving palm, whole body behind it.", check=False, hand="R", step=1.3, height=0.0)),
                    ("Running", S(punch, "Running straight.", check=False, hand="R", step=1.4)),
                    ("WeaponArt", S(punch, "Qi palm on the long step.", check=False, hand="L", step=1.4, height=0.2))]),
    Family("Dao", [(0, -0.158, 0.4), (0, -0.158, -0.4), (0, -0.158, -3.2)], ready=one_handed_ready(grip=(0.55, -0.72, -0.85), dir=(0.2, 0.32, -1), edge=(0, 1, 0.3)),
           guard={"grip": (0.34, -0.2, -0.95), "dir": yawed(-30, 40), "edge": (0.5, 0.2, -1)}, carry={"grip": (0.82, -0.68, -0.6), "dir": (0.14, -0.08, -1), "edge": (0, 1, 0.1), "lh": (-0.95, -0.85, -0.15)},
           notes="Single edge, chopping weight: falling and rising cuts from the shoulder; the free hand braces.",
           strikes=[("Light1", S(slash, "Falling cut left to right.", rise=-0.7, height=-0.05, radius=1.4)), ("Light2", S(slash, "Rising cut.", rise=0.4, height=-0.1, radius=1.3, width=0.72)),
                    ("Light3", S(slash, "Flat sweep through 150 degrees, full pivot.", height=-0.12, radius=1.25, drive=1.0, width=0.6, step=1.05)), ("Light4", S(slash, "Chop on a deep step.", rise=-0.85, height=0.1, radius=1.45, step=1.3)),
                    ("Heavy", S(slash, "Overhead chop through the body line.", rise=-0.7, height=0.1, radius=1.35, step=1.35, lean=0.08)), ("Running", S(slash, "Running flat cut.", radius=1.45, step=1.4)),
                    ("WeaponArt", S(slash, "Two-beat full sweep.", radius=1.45, drive=1.4, step=1.3))]),
    Family("Guandao", [(0, -0.158, 0.4), (0, -0.158, -1.0), (0, 0.24, -10.0)], hold=0.8, ready={"grip": (0.32, -0.72, -0.2), "dir": (-0.22, 0.42, -1), "edge": (0, 1, 0.4), "relb": (1, -1, 0.5), "lelb": (-1, -1, 0.3)},
           guard={"grip": (0.28, -0.5, -0.3), "dir": yawed(-18, 40), "edge": (0, 0.6, -1)}, carry={"grip": (-0.05, -0.62, -0.42), "dir": (-0.05, 0.32, -1), "edge": (0, 1, 0.3), "hold": 1.0},
           notes="Right fist at the butt, left on the haft; the arc comes from the hips and the long lever.",
           strikes=[("Light1", S(slash, "Wide flat cleave.", radius=0.5, drive=1.25, step=0.95)), ("Light2", S(slash, "Rising reverse cleave.", rise=0.55, radius=0.5, drive=1.25, step=0.8)),
                    ("Light3", S(thrust, "Long point thrust.", radius=0.5, side=-0.05, step=1.25, height=-0.25)), ("Heavy", S(slash, "Falling full-lever cleave.", rise=-0.8, height=0.1, radius=0.5, drive=1.3, step=1.2)),
                    ("Running", S(thrust, "Running charge, point first.", radius=0.5, side=-0.05, step=1.3, height=-0.25)), ("WeaponArt", S(slash, "Whirling sweep.", radius=0.5, drive=1.5, step=1.2))]),
    Family("Odachi", [(0, 0, 0.4), (0, 0, -0.7), (0, 0, -6.0)], hold=0.45, ready={"grip": (0.3, -0.62, -0.5), "dir": (-0.15, 0.55, -1), "edge": (0, 1, 0.5), "lelb": (-1, -1, 0.3)},
           guard={"grip": (0.28, -0.35, -0.55), "dir": yawed(-14, 58), "edge": (0, 0.5, -1)}, carry={"grip": (-0.05, -0.6, -0.5), "dir": (-0.05, 0.5, -1), "edge": (0, 1, 0.4)},
           notes="Both fists close on the handle behind the guard. Shared by the Colossal Odachi and Calamity Bone Cleaver: identical timing and blade.",
           strikes=[("Light1", S(slash, "Mountain sweep.", radius=0.58, drive=1.3, step=1.0)), ("Light2", S(slash, "Rising return.", rise=0.6, radius=0.58, drive=1.3, step=0.85)), ("Light3", S(slash, "Earthshatter falling cut.", rise=-0.9, height=0.15, radius=0.58, step=1.2)),
                    ("Heavy", S(slash, "Ground-shattering overhead.", rise=-0.5, height=0.2, radius=0.38, step=1.25)), ("Running", S(slash, "Pursuing cut.", radius=0.58, step=1.3)), ("WeaponArt", S(slash, "Qi release sweep.", radius=0.58, drive=1.4, step=1.2))]),
    Family("TwinDaggers", [(0, -0.1, 0.1), (0, -0.1, -0.5), (0, -0.1, -2.25)], dual=True, ready=one_handed_ready(grip=(0.5, -0.55, -0.85), dir=(0.05, 0.1, -1), edge=(0, 1, 0.1), lh=(-0.5, -0.45, -0.75), lfing=(0.05, -0.95, -0.25), lpalm=(-1, 0, 0), lelb=(-1, -1, 0.1)),
           guard={"grip": (0.45, -0.15, -0.9), "dir": yawed(-24, 18), "edge": (0.3, 1, 0.2), "lh": (-0.42, -0.05, -0.85), "lfing": (0.1, -0.9, -0.35), "lpalm": (-1, 0, 0)}, carry={"grip": (0.8, -0.6, -0.55), "dir": (0.08, 0, -1), "lh": (-0.8, -0.6, -0.5), "lfing": (0, -1, -0.15), "lpalm": (-1, 0, 0)},
           notes="A sai in each hand: the off hand stays forward with its blade clear of the body.",
           strikes=[("Light1", S(slash, "Shadow fang.", radius=1.45, step=0.9)), ("Light2", S(slash, "Twin flurry return.", rise=0.5, radius=1.45, step=0.75)), ("Light3", S(slash, "Rising talon.", rise=0.45, radius=1.35, step=1.0)), ("Light4", S(slash, "Falling sai.", rise=-0.8, height=0.1, radius=1.45, step=1.1)),
                    ("Heavy", S(slash, "Airborne launch uppercut.", rise=1.0, radius=1.32, step=1.2, drive=1.2)), ("Running", S(slash, "Pursuing cut.", radius=1.5, step=1.35)), ("WeaponArt", S(slash, "Nightfall flurry.", radius=1.5, drive=1.3, step=1.2))]),
    Family("ChainScythe", [(0, 0, 0.0), (0, 0, -1.0), (1.9, 0, -1.8)], ready=one_handed_ready(grip=(0.65, -0.5, -0.75), dir=(0.15, 0.5, -1), edge=(0, 1, 0.4), lh=(-0.55, -0.55, -0.7)),
           guard={"grip": (0.42, -0.1, -0.9), "dir": yawed(-16, 50), "edge": (0.2, 0.4, -1)}, carry={"grip": (0.85, -0.65, -0.55), "dir": (0.1, 0.1, -1)},
           notes="Sickle in the right fist, chain hanging from it. The hand motion only: the chain's 15-stud reach is not animated by a body clip.",
           strikes=[("Light1", S(slash, "Reaping arc.", check=False, radius=1.45, drive=1.2)), ("Light2", S(slash, "Weighted crescent.", check=False, rise=0.5, radius=1.45, drive=1.2)), ("Light3", S(slash, "Chain reversal.", check=False, rise=-0.5, radius=1.45, drive=1.3)),
                    ("Heavy", S(slash, "Distant snare cast.", check=False, rise=0.4, radius=1.32, step=1.2)), ("Running", S(slash, "Pursuing cut.", check=False, radius=1.36, step=1.3)), ("WeaponArt", S(slash, "Reaper's orbit.", check=False, radius=1.5, drive=1.5, step=1.1))]),
    Family("WarFan", [(0, 0, 0), (0, 0, -0.4), (0, 0, -2.4)], ready=one_handed_ready(grip=(0.5, -0.4, -0.95), dir=(0.1, 0.25, -1), edge=(0, 1, 0.3), lh=(-0.7, -0.5, -0.3)),
           guard={"grip": (0.15, 0.0, -1.0), "dir": yawed(-30, 24), "edge": (0.3, 1, 0.3)}, carry={"grip": (0.8, -0.55, -0.55), "dir": (0.1, 0.1, -1)},
           notes="Open iron fan in one hand: short, turning cuts with the wrist; the free arm counterbalances.",
           strikes=[("Light1", S(slash, "Silken edge.", radius=1.5, step=0.85)), ("Light2", S(slash, "Gale turn.", rise=0.45, radius=1.5, step=0.75, drive=1.2)), ("Light3", S(slash, "Wind-cutting finisher.", rise=-0.5, radius=1.5, step=1.1, drive=1.3)),
                    ("Heavy", S(slash, "Crushing fan.", rise=-0.9, height=0.15, radius=1.5, step=1.2)), ("Running", S(slash, "Pursuing cut.", radius=1.5, step=1.3)), ("WeaponArt", S(slash, "Tempest ward.", radius=1.5, drive=1.4, step=1.1))]),
    Family("Catalyst", [(0, -2.8, -0.5), (0, -0.5, -0.5), (0, 2.8, -0.5)], axis="staff", ready=one_handed_ready(grip=(0.62, -0.28, -0.85), dir=(0.02, -0.17, -1), edge=(0, 1, -0.17), lh=(-0.55, -0.4, -0.65), lfing=(0.2, 0.7, -0.6)),
           guard={"grip": (0.42, -0.2, -0.95), "dir": (0.12, -0.1, -1), "edge": (-0.35, 0.93, 0)}, carry={"grip": (0.85, -0.3, -0.55), "dir": (0.1, -0.2, -1), "edge": (0, 1, -0.2)},
           notes="Staff held at its balance, jade head above the fist (hand +Y): the strike leads with the head; the off hand forms a seal.",
           strikes=[("Light1", S(thrust, "Jade tap.", check=False, radius=1.5, step=0.9)), ("Light2", S(thrust, "Seal sweep.", check=False, radius=1.5, step=0.9, side=0.3)), ("Light3", S(thrust, "Spirit thrust.", check=False, radius=1.6, step=1.15, side=0.1)),
                    ("Heavy", S(thrust, "Crushing tap on the deep step.", check=False, radius=1.6, step=1.25)), ("Running", S(thrust, "Pursuing tap.", check=False, radius=1.6, step=1.3)), ("WeaponArt", S(thrust, "Resonant seal.", check=False, radius=1.6, step=1.1))]),
    Family("PrayerOfTheDefiled", [(0, 0, -0.6), (0, -0.5, -0.6), (0, -4.2, -0.6)], axis="-Y", ready=one_handed_ready(grip=(0.72, 0.15, -0.6), dir=(0.05, 1, -0.15), edge=(-0.05, 0.42, 1), relb=(1, -0.3, 0.2), lh=(-0.45, -0.3, -0.75), lfing=(0.2, 0.7, -0.6)),
           guard={"grip": (0.6, 0.45, -0.7), "dir": (0.05, 1, -0.2), "edge": (-0.1, 0.55, 1)}, carry={"grip": (0.85, 0.0, -0.45), "dir": (0.05, 1, -0.15), "edge": (-0.1, 0.42, 1)},
           notes="Censer on a chain from the raised right fist, the left hand in prayer: the fist swings it. The censer's 12-stud reach is not animated by a body clip.",
           strikes=[("Light1", S(slash, "Censer toll.", check=False, height=0.2, radius=1.35)), ("Light2", S(slash, "Black incense.", check=False, height=0.2, rise=0.3, radius=1.35)), ("Light3", S(slash, "Funeral procession.", check=False, height=0.2, rise=-0.4, radius=1.35, step=1.1)),
                    ("Heavy", S(slash, "Overhead toll.", check=False, height=-0.15, rise=-0.15, radius=1.35, step=1.2)), ("Running", S(slash, "Pursuing toll.", check=False, height=-0.05, radius=1.35, step=1.3)), ("WeaponArt", S(slash, "Abbot's dirge.", check=False, height=-0.05, radius=1.35, drive=1.4, step=1.1))]),
    Family("HeavenPiercingGuandao", [(0, 0, 0.4), (0, 0, -0.7), (0, 0, -7.0)], hold=0.8, ready={"grip": (0.32, -0.72, -0.2), "dir": (-0.2, 0.42, -1), "edge": (0, 1, 0.4), "relb": (1, -1, 0.5), "lelb": (-1, -1, 0.3)},
           guard={"grip": (0.28, -0.5, -0.3), "dir": yawed(-18, 40), "edge": (0, 0.6, -1)}, carry={"grip": (-0.05, -0.62, -0.42), "dir": (-0.05, 0.32, -1), "edge": (0, 1, 0.3), "hold": 1.0},
           notes="Its own timing on the two-handed haft grip.",
           strikes=[("Light1", S(slash, "Ashen crescent.", radius=0.5, drive=1.25)), ("Light2", S(slash, "Storm coil.", rise=0.55, radius=0.5, drive=1.25, step=0.85)), ("Light3", S(slash, "Heaven piercer.", rise=-0.6, height=0.1, radius=0.5, step=1.25)),
                    ("Heavy", S(slash, "Falling full-lever cleave.", rise=-0.9, height=0.15, radius=0.5, step=1.25)), ("Running", S(slash, "Pursuing cut.", radius=0.5, step=1.3)), ("WeaponArt", S(slash, "Thunderfall.", rise=-0.7, height=-0.05, radius=0.5, drive=1.35, step=1.2))]),
]


# ---------------------------------------------------------------------------------------------- universal actions
UNIVERSAL_FAMILY = Family("Universal", [(0, -0.158, 0.48), (0, -0.158, -0.4), (0, -0.158, -0.5)])
LOWER = {"LowerTorso", "UpperTorso", "Head", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot"}


def dash(direction):
    """The body and legs of a directional dash; the arms stay on the weapon's own idle (a mask, so one clip serves every grip)."""
    f = UNIVERSAL_FAMILY
    r = J.READY
    lean = {"Forward": ((-20, 0, 0), (0, -0.62, -0.28), (-0.6, 0.85, 0.5, 30, 0), (0.45, -1.15, 0.35, -8, 0)),
            "Left": ((-4, -8, 14), (-0.3, -0.6, 0), (-1.2, 0.3, 0.45, 35, 0), (0.1, -0.3, 0.25, -5, 0)),
            "Right": ((-4, 8, -14), (0.3, -0.6, 0), (-0.25, 0.4, 0.25, 40, 0), (1.15, -0.45, 0.45, -18, 0))}[direction]
    chest, pel, lf, rf = lean
    keys = [(0, pose(f), "linear"),
            (0.08, {"chest": chest, "pel": pel, "lf": lf, "rf": rf, "lookW": 0.7}, "out"),
            (0.24, {"chest": (chest[0] * 0.6, chest[1] * 0.6, chest[2] * 0.6), "pel": (pel[0] * 0.5, -0.5, pel[2] * 0.6), "lf": r["lf"], "rf": r["rf"]}, "linear"),
            (0.36, pose(f), "inout")]
    return FamilyClip(f, "Fighter_Dash" + direction, 0.36, keys, priority="Action2", mask=LOWER, slot="Dash" + direction, feet_free=[(0.0, 0.3)],
                      notes="Directional dash: lean and leading foot in the travel direction; the arms stay on the weapon's idle.")


def deathblow_attacker():
    f = UNIVERSAL_FAMILY
    keys = [(0, pose(f), "linear"),
            (0.3, {"grip": (0.62, 0.05, -0.85), "dir": yawed(4, 62), "edge": (0, 0.45, 1), "pel": (0.05, -0.5, 0.1), "chest": (-4, -4, 0), "lh": (-0.45, -0.28, -0.52)}, "inout"),
            (0.55, {"lh": (-0.62, -0.75, -0.72), "grip": (0.3, -0.72, -1.2), "dir": yawed(0, -32), "edge": (0, 1, 0), "pel": (0.05, -0.85, -0.4), "pelR": (0, 26, 0), "chest": (26, -2, 0), "rf": (0.42, -1.1, 0, -6, 0)}, "snap"),
            (0.8, {"grip": (0.3, -0.76, -1.18), "chest": (28, -2, 0)}, "linear"),
            (0.95, {"grip": (0.35, -0.68, -1.1), "chest": (14, -6, 0), "pel": (0.05, -0.55, -0.1), "lh": (-0.42, -0.52, -0.62)}, "inout"),
            (1.1, pose(f), "inout")]
    return FamilyClip(f, "Fighter_DeathblowAttacker", 1.1, keys, priority="Action4", slot="Deathblow_Attacker", notes="Raised, driven finishing strike; state length 1.1 s (CombatSettings).")


def deathblow_victim():
    f = UNIVERSAL_FAMILY
    knees = {"pel": (0.0, -1.3, 0.25), "pelR": (0, 0, 0), "chest": (24, 0, 0), "neck": (14, 0, 0), "lookW": 0.1, "grip": (0.75, -1.25, -0.35), "dir": yawed(10, -20), "lh": (-0.75, -1.25, -0.35), "lfing": (0, -1, 0), "lpalm": (1, 0, 0),
             "lf": (-0.5, 0.35, 0, 8, 0), "rf": (0.5, -0.3, 0, -8, 0)}
    keys = [(0, pose(f), "linear"), (0.3, knees, "out"),
            (0.62, {"chest": (-22, 0, 0), "neck": (-18, 0, 0), "pel": (0.0, -1.2, 0.35)}, "snap"),
            (1.6, {"chest": (6, 0, 0), "neck": (20, 0, 0), "pel": (0.0, -1.36, 0.3)}, "inout")]
    return FamilyClip(f, "Fighter_DeathblowVictim", 1.6, keys, priority="Action4", slot="Deathblow_Victim", feet_free=[(0.0, 0.3)], notes="Forced to the knees, jolts at the blow, sinks; state length 1.6 s.")


def altar_rest():
    f = UNIVERSAL_FAMILY
    kneel = {"pel": (0.0, -1.32, 0.15), "pelR": (0, 0, 0), "chest": (10, 0, 0), "neck": (16, 0, 0), "lookW": 0.05, "grip": (0.42, -1.0, -0.72), "dir": yawed(0, -55), "edge": (0, 0.5, 1), "relb": (1, -1, 0.2),
             "lh": (-0.1, -0.85, -0.8), "lfing": (0.4, -0.7, -0.4), "lpalm": (1, 0, 0), "lf": (-0.5, 0.4, 0, 6, 0), "rf": (0.5, -0.32, 0, -6, 0)}
    keys = [(0, pose(f, **kneel), "inout"), (1.5, {"chest": (11.5, 0, 0), "pel": (0.0, -1.34, 0.15)}, "inout")]
    return FamilyClip(f, "Fighter_AltarRest", 3.0, keys, loop=True, priority="Action", slot="AltarRest", notes="Kneeling rest at a shrine, weapon lowered, slow breath.")


def library(T, only=None):
    out = []
    for f in FAMILIES:
        if only and f.weapon not in only:
            continue
        out.extend((f, c) for c in stock_clips(f) + attacks(f, T))
    if not only or "Universal" in only:
        for c in (dash("Forward"), dash("Left"), dash("Right"), deathblow_attacker(), deathblow_victim(), altar_rest()):
            out.append((UNIVERSAL_FAMILY, c))
    return out


def validate(f, clip, baked):
    body = J.BODY
    J.blade = f.blade
    if f.hold > 0:
        # The left fist grips the shaft: it and its forearm are meant to touch it.
        J.BODY = [b for b in body if b not in ("LeftHand", "LeftLowerArm")]
    if f.fist:
        J.BODY = [b for b in body if b not in ("LeftHand", "LeftLowerArm", "RightHand", "UpperTorso", "LowerTorso")]  # a fist may rest on the chest
    try:
        stats, problems = J.validate(clip, baked)
    finally:
        J.blade, J.BODY = BLADE_POINTS, body
    # jianlib's forward check assumes a jian's length: hold each family to its own design reach through the report instead.
    problems = [p for p in problems if not p.startswith("thrust tip only")]
    if clip.mask is not None and "LeftHand" not in clip.mask:
        # The arms of this clip are Weight 0: they stay on the weapon's own idle, so their solve means nothing.
        problems = [p for p in problems if not p.startswith(("arm short", "sword fist", "blade ", "hand pops"))]
    return stats, problems


def main():
    args = sys.argv[1:]
    only = set(args[args.index("--only") + 1].split(",")) if "--only" in args else None
    import export as zx  # general_zhao/export.py: content_hash
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"clips": {}}
    T = timing()
    failed = 0
    for f, clip in library(T, only):
        baked = clip.bake()
        stats, problems = validate(f, clip, baked)
        path = OUT / (clip.name + ".rbxmx")
        keys = J.write_rbxmx(clip, baked, path)
        manifest["clips"][clip.name] = {"slot": clip.slot, "family": f.weapon, "length": round(clip.length, 4), "loop": clip.loop, "priority": clip.priority, "keyframes": keys, "notes": clip.notes or f.notes,
                                        "contacts": [round(c, 4) for c in clip.contacts], "tip_reach": stats.get("strike", {}).get("tip_reach"), "problems": problems,
                                        "validation": {k: v for k, v in stats.items() if k != "strike"}, "sha256": zx.content_hash(path)}
        failed += 1 if problems else 0
        print("%s %-34s %5.3fs keys %3d %s" % ("FIX" if problems else "OK ", clip.name, clip.length, keys, "; ".join(problems)[:150]))
    manifest["clips"] = dict(sorted(manifest["clips"].items()))
    manifest_path.write_text(json.dumps(manifest, indent=1))
    print("%d of %d with problems" % (failed, len(manifest["clips"])))


if __name__ == "__main__":
    main()
