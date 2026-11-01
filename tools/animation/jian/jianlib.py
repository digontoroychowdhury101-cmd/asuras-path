"""Jian clip authoring on the shared R15 template rig (tools/animation/general_zhao/rig.py: same joints, FK, analytic
limb IK and foot frames that baked General Zhao's 59 published clips).

A clip is a list of keys (time, controls, ease). Every control channel interpolates on its own between the keys that set
it (Catmull-Rom through the keys, re-timed by the ending key's ease), so arcs stay round and a key only lists what
changes. Controls, all in HumanoidRootPart space (+X right, +Y up, -Z forward):
    pel / pelR   LowerTorso offset (studs) and rotation (CFrame.Angles degrees) on the Root joint - cosmetic only
    chest, neck  Waist and Neck rotations; the head also stabilises toward `look` by `lookW`
    grip         the sword fist: the point of the blade axis level with the hand centre
    dir, edge    blade direction (hand -Z) and the edge side it turns toward (hand +Y); a jian is double edged
    relb         right elbow pole
    lh, lfing, lpalm, lelb   free left hand: centre, finger direction (hand -Y), palm side (hand -X), elbow pole
    lf, rf       feet (x, z, lift, yaw, pitch); lknee, rknee their knee poles
The jian is CharacterService's WEAPON_VISUALS.Jian: 4.2 studs welded to RightHand, hand-local axis (0, -0.158, z) from
the pommel at z = +0.48 to the tip at z = -3.8, edges along hand +/-Y. Animation never moves that weld.
"""
import json
import math
import subprocess
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE.parent / "general_zhao"))
import rig  # noqa: E402
from rig import unit  # noqa: E402

FPS = 60
BLADE_Y = -0.158                     # blade axis below the hand centre (half the R15 hand height)
POMMEL_Z, GUARD_Z, TIP_Z = 0.48, -0.4, -3.8
HAND_UP = np.array([0, 0.1316, 0])   # wrist joint from the hand centre (RightWrist Attachment1)
ARM_REACH = 0.774 + 0.807 + 0.1316   # shoulder -> hand centre at full extension

EASE = {
    "linear": lambda t: t,
    "in": lambda t: t * t * t,
    "out": lambda t: 1 - (1 - t) ** 3,
    "inout": lambda t: t * t * (3 - 2 * t),
    "snap": lambda t: 2 * t * t - t ** 3,          # rest to moving: explodes and arrives travelling
    "whip": lambda t: 1.5 * t * t - 0.5 * t ** 3,
    "settle": lambda t: 1 - (1 - t) ** 2,
    "step": lambda t: 1.0 if t >= 1 else 0.0,
}

READY = {
    # Ready stance: sword-side foot forward, body bladed a quarter turn, blade level at the opponent's throat,
    # left hand in sword-fingers by the right forearm.
    "pel": (0.05, -0.32, 0.05), "pelR": (0, 24, 0), "chest": (4, -12, 0), "neck": (0, 0, 0),
    "look": (0, 1.4, -30), "lookW": 0.9,
    "grip": (0.42, -0.62, -1.05), "dir": (-0.18, 0.32, -1), "edge": (0, 1, 0.2), "relb": (1, -1, 0.4),
    "lh": (-0.05, -0.25, -0.95), "lfing": (0.25, 0.55, -1), "lpalm": (1, -0.2, 0), "lelb": (-1, -1, 0.3),
    "lf": (-0.75, 0.6, 0, 40, 0), "rf": (0.45, -0.6, 0, -8, 0), "lknee": (-0.3, 0, -1), "rknee": (0.1, 0, -1),
}
VECTOR = {"pel", "look", "grip", "relb", "lh", "lelb", "lknee", "rknee"}
EULER = {"pelR", "chest", "neck"}
SCALAR = {"lookW"}
DIRECTION = {"dir", "edge", "lfing", "lpalm"}
FEET = {"lf", "rf"}


def pose(**over):
    out = dict(READY)
    out.update(over)
    return out


def timing():
    """The Jian's authoritative timing from the built WeaponSchema (1.4x tempo, 60 Hz), so clips cannot drift from
    the move data."""
    luau = ROOT / "work/bin/luau" / ("luau.exe" if sys.platform == "win32" else "luau")
    out = subprocess.run([str(luau), str(HERE / "timing.luau")], capture_output=True, text=True, cwd=str(HERE), check=True)
    return json.loads(out.stdout.strip().splitlines()[-1])


class Clip:
    def __init__(self, name, length, keys, loop=False, priority="Action", contacts=(), move=None, kind="",
                 active=None, notes="", mask=None, feet_free=(), slot=""):
        self.name, self.length, self.loop, self.priority = name, float(length), loop, priority
        self.keys = sorted(((float(t), c, e) for t, c, e in keys), key=lambda k: k[0])
        self.contacts = [float(c) for c in contacts]
        self.move, self.kind, self.active, self.notes = move, kind, active, notes
        self.mask = None if mask is None else set(mask)
        self.slot = slot  # AnimationCatalog slot name the clip fills, e.g. "Jian.Light1"  # keyed parts; the rest are Weight-0 containers
        self.feet_free = [tuple(w) for w in feet_free]  # windows where a foot may leave the ground or slide (dodges)
        self.base = dict(READY)

    def frames(self):
        n = int(round(self.length * FPS))
        return [i / FPS for i in range(n + 1)]

    def channel(self, name, t):
        keyed = [(kt, c[name], e) for kt, c, e in self.keys if name in c]
        if not keyed:
            return self.base[name]
        if self.loop and keyed[-1][0] < self.length - 1e-6:
            keyed = keyed + [(self.length, keyed[0][1], keyed[0][2])]
        if t <= keyed[0][0]:
            return keyed[0][1]
        if t >= keyed[-1][0]:
            return keyed[-1][1]
        vals = [np.asarray(k[1], float) for k in keyed]
        for i in range(len(keyed) - 1):
            t0, t1 = keyed[i][0], keyed[i + 1][0]
            if t <= t1:
                u = EASE[keyed[i + 1][2]]((t - t0) / (t1 - t0) if t1 > t0 else 1.0)
                p1, p2 = vals[i], vals[i + 1]
                if np.allclose(p1, p2, atol=1e-6):
                    out = p1
                else:
                    p0 = vals[i - 1] if i > 0 else (vals[-2] if self.loop else p1)
                    p3 = vals[i + 2] if i + 2 < len(vals) else (vals[1] if self.loop else p2)
                    m1 = np.zeros_like(p1) if np.allclose(p0, p1, atol=1e-6) else (p2 - p0) * 0.5
                    m2 = np.zeros_like(p2) if np.allclose(p2, p3, atol=1e-6) else (p3 - p1) * 0.5
                    u2, u3 = u * u, u * u * u
                    out = (2 * u3 - 3 * u2 + 1) * p1 + (u3 - 2 * u2 + u) * m1 + (-2 * u3 + 3 * u2) * p2 + (u3 - u2) * m2
                    if name in FEET:  # a travelling foot lifts in an arc rather than skating
                        dist = float(np.linalg.norm(p2[:2] - p1[:2]))
                        out = out.copy()
                        out[2] = max(out[2], min(0.45, dist * 0.35) * math.sin(math.pi * u) if dist > 0.08 else 0)
                return unit(out) if name in DIRECTION else out
        return keyed[-1][1]

    def controls(self, t):
        return {name: self.channel(name, t) for name in self.base}

    # ------------------------------------------------------------------------------------------------ solve
    def solve(self, c):
        local = {"LowerTorso": rig.frame(rig.euler(c["pelR"]), c["pel"]), "UpperTorso": rig.frame(rig.euler(c["chest"]))}
        world = rig.fk(local)
        head_pos = rig.joint_world(world, "Head")
        fwd = unit(np.asarray(c["look"], float) - head_pos)
        Rchest = world["UpperTorso"][:3, :3]
        Rlook = rig.align(np.array([0, 0, -1.0]), np.array([0, 1.0, 0]), fwd, Rchest[:, 1])
        q = rig.slerp(rig.quat(np.eye(3)), rig.quat(Rchest.T @ Rlook), float(c["lookW"]))
        local["Head"] = rig.frame(rig.mat(q) @ rig.euler(c["neck"]))
        world = rig.fk(local)
        diag = {}
        # right arm: the hand frame carries the blade; overreach pulls the fist in along the arm, never the blade off
        d = unit(np.asarray(c["dir"], float))
        RH, _ = rig.hand_frame((0, 0, 0), d, 0, np.asarray(c["edge"], float))
        grip = np.asarray(c["grip"], float)
        pH = grip - RH @ np.array([0, BLADE_Y, 0])
        S = rig.joint_world(world, "RightUpperArm")
        W = pH + RH @ HAND_UP
        over = float(np.linalg.norm(W - S)) - (0.774 + 0.807) * 0.995
        diag["right_pull"] = max(0.0, over)
        if over > 0:
            pH = pH - unit(W - S) * over
        diag["right_excess"] = rig.solve_limb(world, local, "RightUpperArm", "RightLowerArm", "RightHand", RH, pH,
                                              np.asarray(c["relb"], float), -1)
        # left arm: free hand, fingers (hand -Y) along lfing, palm (hand -X) toward lpalm
        fing = unit(np.asarray(c["lfing"], float))
        RL = rig.align(np.array([0, -1.0, 0]), np.array([-1.0, 0, 0]), fing, np.asarray(c["lpalm"], float))
        diag["left_excess"] = rig.solve_limb(world, local, "LeftUpperArm", "LeftLowerArm", "LeftHand", RL,
                                             np.asarray(c["lh"], float), np.asarray(c["lelb"], float), -1)
        for side, key, pole in (("Left", "lf", "lknee"), ("Right", "rf", "rknee")):
            x, z, lift, yaw, pitch = c[key]
            RF, pF = rig.foot_frame(x, z, lift, yaw, pitch)
            diag[side.lower() + "_leg_excess"] = rig.solve_limb(world, local, side + "UpperLeg", side + "LowerLeg",
                                                                side + "Foot", RF, pF, rig.ry(yaw) @ np.asarray(c[pole], float), 1)
        world = rig.fk(local)
        return local, world, diag

    def bake(self):
        out = []
        for t in self.frames():
            c = self.controls(t)
            local, world, diag = self.solve(c)
            out.append((t, local, world, diag, c))
        return out


# ---------------------------------------------------------------------------------------------------- geometry
def blade(world):
    """(pommel, guard, tip) world points of the welded jian."""
    H = world["RightHand"]
    return tuple((H @ np.array([0, BLADE_Y, z, 1.0]))[:3] for z in (POMMEL_Z, GUARD_Z, TIP_Z))


BODY = ["Head", "UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
        "LeftUpperArm", "LeftLowerArm", "LeftHand", "LeftFoot", "RightFoot"]


def validate(clip, baked):
    """Measured problems: unreachable targets, blade through the body, feet below ground or sliding while planted,
    contact timing/trajectory against the server's StrikeGeometry, hand pops and loop seams."""
    w = {"right_reach": 0.0, "right_pull": 0.0, "left_reach": 0.0, "leg_reach": 0.0, "sole_below_ground": 0.0,
         "planted_slide": 0.0, "blade_in_body": 0.0, "blade_below_ground": 0.0, "hand_jerk": 0.0, "loop_seam_deg": 0.0}
    hits, prev, tips, hands = [], None, [], []
    for t, local, world, diag, c in baked:
        w["right_reach"] = max(w["right_reach"], diag["right_excess"])
        w["right_pull"] = max(w["right_pull"], diag["right_pull"])
        w["left_reach"] = max(w["left_reach"], diag["left_excess"])
        w["leg_reach"] = max(w["leg_reach"], diag["left_leg_excess"], diag["right_leg_excess"])
        soles = {}
        for foot in ("LeftFoot", "RightFoot"):
            pts = rig.obb_points(world, foot)
            low = min(p[1] for p in pts)
            w["sole_below_ground"] = max(w["sole_below_ground"], rig.GROUND - low)
            soles[foot] = (pts, low)
        free = any(a - 1e-6 <= t <= b + 1e-6 for a, b in clip.feet_free)
        if prev and not free:
            for foot, (pts, low) in soles.items():
                pts0, low0 = prev[foot]
                if low - rig.GROUND < 0.01 and low0 - rig.GROUND < 0.01:
                    k = int(np.argmin([p[1] for p in pts]))
                    w["planted_slide"] = max(w["planted_slide"], float(np.linalg.norm((pts[k] - pts0[k])[[0, 2]])) * FPS)
        prev = soles
        pommel, guard, tip = blade(world)
        tips.append(tip)
        hands.append(world["RightHand"][:3, 3].copy())
        w["blade_below_ground"] = max(w["blade_below_ground"], rig.GROUND - tip[1])
        for part in BODY:
            clearance = rig.segment_obb_distance(world, part, guard, tip, inflate=0.0)
            if clearance < -0.03:
                w["blade_in_body"] = max(w["blade_in_body"], -clearance)
                hits.append((round(t, 3), part))
    for k in range(1, len(hands) - 1):
        if any(abs(baked[k][0] - ct) < 0.035 for ct in clip.contacts):
            continue
        a, b, c2 = hands[k - 1], hands[k], hands[k + 1]
        jerk = float(np.linalg.norm(a - 2 * b + c2))
        v0, v1 = b - a, c2 - b
        speed = max(float(np.linalg.norm(v0)), float(np.linalg.norm(v1)))
        # A strike accelerating along its path is not a pop; a kink is: the hand turns sharply between frames.
        turn = float(np.dot(unit(v0), unit(v1))) if min(np.linalg.norm(v0), np.linalg.norm(v1)) > 0.02 else 1.0
        if jerk >= 0.75 * speed and turn < 0.7:
            w["hand_jerk"] = max(w["hand_jerk"], jerk)
    if clip.loop:
        a, b = baked[0][1], baked[-1][1]
        w["loop_seam_deg"] = max(rig.angle_of(a[p][:3, :3].T @ b[p][:3, :3]) for p in a)
    strike = strike_report(clip, baked, tips)
    w = {k: round(float(v), 4) for k, v in w.items()}
    problems = []
    if w["right_reach"] > 0.03 or w["left_reach"] > 0.05:
        problems.append("arm short of its target (R %.2f, L %.2f)" % (w["right_reach"], w["left_reach"]))
    if w["right_pull"] > 0.25:
        problems.append("sword fist pulled in %.2f (overreach)" % w["right_pull"])
    if w["leg_reach"] > 0.05:
        problems.append("leg short of its foot by %.2f" % w["leg_reach"])
    if w["sole_below_ground"] > 0.06:
        problems.append("foot %.2f below ground" % w["sole_below_ground"])
    if w["planted_slide"] > 0.6:
        problems.append("planted foot slides %.2f studs/s" % w["planted_slide"])
    if w["blade_in_body"] > 0:
        problems.append("blade %.2f into the body %s" % (w["blade_in_body"], hits[:4]))
    if w["blade_below_ground"] > 0.05:
        problems.append("blade tip %.2f below ground" % w["blade_below_ground"])
    if w["hand_jerk"] > 0.3:
        problems.append("hand pops %.2f" % w["hand_jerk"])
    if clip.loop and w["loop_seam_deg"] > 1.0:
        problems.append("loop seam %.1f deg" % w["loop_seam_deg"])
    problems += strike.pop("problems")
    w["strike"] = strike
    return w, problems


def strike_report(clip, baked, tips):
    """Checks the blade against the server's swept shape (StrikeGeometry.segment) during the authoritative active
    window: thrusts travel forward along the facing, slashes sweep left to right through the arc's centre line."""
    if not clip.move or clip.active is None:
        return {"problems": []}
    start, length, arc, reach = clip.active
    times = [b[0] for b in baked]
    i0 = int(np.argmin([abs(t - start) for t in times]))
    i1 = int(np.argmin([abs(t - (start + length)) for t in times]))
    a, b = tips[i0], tips[i1]
    out = {"tip_start": [round(float(x), 2) for x in a], "tip_end": [round(float(x), 2) for x in b], "problems": []}
    yaw = lambda p: math.degrees(math.atan2(p[0], -p[2]))  # +right of the facing
    if arc > 40:
        out["sweep_deg"] = round(yaw(b) - yaw(a), 1)
        if yaw(b) - yaw(a) < min(30, arc * 0.4):
            out["problems"].append("slash does not sweep left to right through the active frames (%.0f deg)" % (yaw(b) - yaw(a)))
        mid = tips[(i0 + i1) // 2]
        if abs(yaw(mid)) > arc * 0.5:
            out["problems"].append("slash midpoint %.0f deg off the facing" % yaw(mid))
    else:
        out["advance"] = round(float(a[2] - b[2]), 2)
        best = max(tips[i0:i1 + 1], key=lambda p: -p[2])
        if abs(yaw(best)) > 20:
            out["problems"].append("thrust lands %.0f deg off the facing" % yaw(best))
        if -best[2] < 4.0:
            out["problems"].append("thrust tip only %.1f studs forward at contact" % -best[2])
    reach_tip = max(float(np.linalg.norm(t[[0, 2]])) for t in tips[i0:i1 + 1])
    out["tip_reach"] = round(reach_tip, 2)
    return out


ARMS = {"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand"}
UPPER = ARMS | {"UpperTorso", "Head"}


def pose_xml(part, local, mask, indent):
    """export.py's Pose writer plus a mask: a part outside it is written with Weight 0, which Roblox treats as an
    unkeyed container (measured in Studio: a Weight-0 LowerTorso leaves the Core walk's Root transform intact)."""
    import export as zx
    pad = "\t" * indent
    M = local.get(part, np.eye(4))
    weight = 1 if mask is None or part in mask else 0
    kids = "".join(pose_xml(k, local, mask, indent + 1) for k in zx.CHILDREN.get(part, []))
    return ('%s<Item class="Pose" referent="%s"><Properties><string name="Name">%s</string>'
            '<CoordinateFrame name="CFrame">%s</CoordinateFrame><float name="Weight">%d</float>'
            '<token name="EasingStyle">0</token><token name="EasingDirection">0</token></Properties>\n%s%s</Item>\n'
            % (pad, zx.ref(), part, zx.cframe(M) if part != "HumanoidRootPart" else zx.cframe(np.eye(4)), weight, kids, pad))


def write_rbxmx(clip, baked, path, keep_times=()):
    """KeyframeSequence in the format the Zhao clips were published with (export.py's writer), masked if the clip is."""
    import export as zx  # tools/animation/general_zhao/export.py
    zx._ref[0] = 0
    idx = zx.decimate([(b[0], b[1]) for b in baked], list(clip.contacts) + list(keep_times))
    body = "".join('\t<Item class="Keyframe" referent="%s"><Properties><string name="Name">Keyframe</string>'
                   '<float name="Time">%.6f</float></Properties>\n%s\t</Item>\n'
                   % (zx.ref(), baked[i][0], pose_xml("HumanoidRootPart", baked[i][1], clip.mask, 2)) for i in idx)
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">\n'
           '<Item class="KeyframeSequence" referent="%s"><Properties><string name="Name">%s</string>'
           '<bool name="Loop">%s</bool><token name="Priority">%d</token><float name="AuthoredHipHeight">2.192423</float>'
           '</Properties>\n%s</Item>\n</roblox>\n' % (zx.ref(), clip.name, "true" if clip.loop else "false",
                                                    zx.PRIORITY[clip.priority], body))
    path.write_text(xml)
    return len(idx)


def frames_json(clip, baked, path):
    frames = [{"t": round(t, 4), "parts": {p: [round(float(x), 5) for x in M.ravel()] for p, M in world.items()}}
              for t, local, world, diag, c in baked]
    path.write_text(json.dumps({"name": clip.name, "length": clip.length, "contacts": clip.contacts, "frames": frames,
                                "blade": {"y": BLADE_Y, "pommel": POMMEL_Z, "guard": GUARD_Z, "tip": TIP_Z}}))
