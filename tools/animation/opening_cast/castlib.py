"""Clip authoring for the opening cast's production meshes on the shared R15 template rig
(tools/animation/general_zhao/rig.py: the joints, FK and foot frames behind General Zhao's and the Jian's clips).

The cast's lean meshes keep their arms a little inside the R15 arm column: the visible elbow and fist sit ~0.45 studs
inboard of the rig's elbow and wrist joints (only the shoulder pivot is on the geometry). Any forearm or wrist twist
would swing that geometry around the joint, so arms here are solved for the *visible* fist: the shoulder is a free
ball joint, the elbow a pure hinge about the forearm's local X and the wrist a pure flex about its local X. Those two
rotations keep the inboard geometry on its hinge line, so the forearm and fist never orbit or detach; the fist's roll
comes from the shoulder (an elbow pointing down gives the monk's vertical fist, pointing out a palm-down one).

Controls (HumanoidRootPart space, +X right, +Y up, -Z forward):
    pel / pelR, chest, neck, look / lookW    as jianlib
    rh, lh        the visible fist (or open hand) centre
    relb, lelb    which way each elbow points
    rflex, lflex  wrist flex in degrees (+ bends the fist toward the forearm's front)
    rspace, lspace  0 = that hand's target is in root space, 1 = in UpperTorso space (an off hand that rides the turn)
    lf, rf        feet (x, z, lift, yaw, pitch); lknee, rknee their knee poles

Locomotion cycles (gait) are in place: the planted foot travels backward at the clip's `velocity`, and the client
plays them at measured ground speed / (velocity x the model's scale), so the feet stay put on the ground.
"""
import json
import math
import subprocess
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE.parent / "jian"))
sys.path.insert(0, str(HERE.parent / "general_zhao"))
import jianlib as J  # noqa: E402
import rig  # noqa: E402
from rig import unit  # noqa: E402

FPS = J.FPS
EASE = J.EASE
REST = rig.fk({})


def timing():
    """Authoritative move timing of the Unarmed and Dao weapons (built WeaponSchema, 1.4x tempo), keyed by move id."""
    luau = ROOT / "work/bin/luau" / ("luau.exe" if sys.platform == "win32" else "luau")
    out = subprocess.run([str(luau), str(HERE / "timing.luau")], capture_output=True, text=True, cwd=str(HERE), check=True)
    return json.loads(out.stdout.strip().splitlines()[-1])


class Body:
    """Where a character's visible hands sit at rest (root space), from its Blender build constants."""

    def __init__(self, name, fist_r, fist_l=None):
        self.name = name
        self.fist = {"Right": np.asarray(fist_r, float),
                     "Left": np.asarray(fist_l if fist_l is not None else (-fist_r[0], fist_r[1], fist_r[2]), float)}


MONK = Body("Monk", (1.04, -0.89, 0.0))


def arm_chain(side, fist, flex):
    """Rest-frame geometry of one arm: shoulder S, elbow hinge offset e, and the forearm+fist vector at wrist flex."""
    S = rig.joint_world(REST, side + "UpperArm")
    E = rig.joint_world(REST, side + "LowerArm")
    W = rig.joint_world(REST, side + "Hand")
    f = (W - E) + rig.rx(flex) @ (fist - W)
    return S, E - S, f


def fist_local(e, f, theta):
    return e + rig.rx(theta) @ f


def solve_arm(world, local, side, fist_rest, target, pole, flex):
    """Ball shoulder + pure elbow hinge + pure wrist flex onto the visible fist target. Returns the reach excess."""
    _, e, f = arm_chain(side, fist_rest, flex)
    S = rig.joint_world(world, side + "UpperArm")
    D = float(np.linalg.norm(target - S))
    lo, hi = 0.0, 150.0
    dmax, dmin = np.linalg.norm(fist_local(e, f, lo)), np.linalg.norm(fist_local(e, f, hi))
    excess = max(0.0, D - dmax, dmin - D)
    if D >= dmax:
        theta = lo
    elif D <= dmin:
        theta = hi
    else:
        for _ in range(40):
            mid = (lo + hi) / 2
            if np.linalg.norm(fist_local(e, f, mid)) > D:
                lo = mid
            else:
                hi = mid
        theta = (lo + hi) / 2
    p = fist_local(e, f, theta)
    Ru = rig.align(p, np.array([0, 0, 1.0]), target - S, np.asarray(pole, float))
    parent = world["UpperTorso"][:3, :3]
    local[side + "UpperArm"] = rig.frame(parent.T @ Ru)
    local[side + "LowerArm"] = rig.frame(rig.rx(theta))
    local[side + "Hand"] = rig.frame(rig.rx(flex))
    return excess


READY = {
    # Monk's guard: orthodox, left foot and left fist leading, body bladed, right fist by the chin, weight low.
    "pel": (0.0, -0.3, 0.08), "pelR": (0, -26, 0), "chest": (-6, 10, 0), "neck": (4, 0, 0),
    "look": (0, 1.3, -30), "lookW": 0.9,
    "rh": (0.36, 0.86, -0.62), "relb": (0.4, -1, 0.3), "rflex": 0.0,
    "lh": (-0.24, 0.84, -1.16), "lelb": (-0.4, -1, 0.2), "lflex": 0.0, "rspace": 0.0, "lspace": 0.0,
    "lf": (-0.45, -0.55, 0, -14, 0), "rf": (0.6, 0.5, 0, 30, 0), "lknee": (-0.2, 0, -1), "rknee": (0.3, 0, -1),
}
VECTOR = {"pel", "look", "rh", "relb", "lh", "lelb", "lknee", "rknee"}


def pose(**over):
    out = dict(READY)
    out.update(over)
    return out


class Clip(J.Clip):
    """jianlib's keyed Catmull-Rom clip with the cast's fist controls and solver."""

    def __init__(self, *a, body=MONK, striker=None, velocity=(0.0, 0.0), **kw):
        super().__init__(*a, **kw)
        self.base = dict(READY)
        self.body = body
        self.striker = striker  # (part, "fist" | (x, y, z) part-local point) that lands the blow
        self.velocity = velocity  # (vx, vz) root ground speed a locomotion cycle is authored for (scale 1)

    def channel(self, name, t):
        if name in ("rflex", "lflex", "lookW", "rspace", "lspace"):
            keyed = [(kt, c[name], e) for kt, c, e in self.keys if name in c]
            if not keyed:
                return self.base[name]
            v = J.Clip.channel(self, name, t)
            return float(np.asarray(v).ravel()[0])
        return J.Clip.channel(self, name, t)

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
        for side, key, pole, flex, space in (("Right", "rh", "relb", "rflex", "rspace"), ("Left", "lh", "lelb", "lflex", "lspace")):
            target = np.asarray(c[key], float)
            w = float(c[space])
            if w > 0:
                target = target * (1 - w) + (world["UpperTorso"] @ np.append(target, 1))[:3] * w
            diag[side.lower() + "_excess"] = solve_arm(world, local, side, self.body.fist[side], target, c[pole], float(c[flex]))
            world = rig.fk(local)
        for side, key, pole in (("Left", "lf", "lknee"), ("Right", "rf", "rknee")):
            x, z, lift, yaw, pitch = c[key]
            RF, pF = rig.foot_frame(x, z, lift, yaw, pitch)
            diag[side.lower() + "_leg_excess"] = rig.solve_limb(world, local, side + "UpperLeg", side + "LowerLeg",
                                                                side + "Foot", RF, pF, rig.ry(yaw) @ np.asarray(c[pole], float), 1)
        world = rig.fk(local)
        return local, world, diag


def gait(length, velocity, duty, lift, neutral, pitch_off=-16.0, samples=30):
    """Per-sample feet for an in-place cycle (General Zhao's gait): [(t, lf, rf)], the left foot landing at t = 0 and
    the right at length / 2; a planted foot travels backward at exactly `velocity` (vx, vz), the swing foot arcs over."""
    V = np.asarray(velocity, float)
    half = V * duty * length / 2
    n = int(samples * length / 0.5)
    out = []
    for i in range(n + 1):
        t = length * i / n
        feet = []
        for side, phase in (("lf", 0.0), ("rf", 0.5)):
            x0, z0, _, yaw, _ = neutral[side]
            p0 = np.array([x0, z0])
            u = (t / length + phase) % 1.0
            if u < duty:
                p, h, pt = p0 + half - V * (u * length), 0.0, 0.0
            else:
                w = (u - duty) / (1 - duty)
                e = w * w * (3 - 2 * w)
                p = (p0 - half) + (2 * half) * e
                h = lift * math.sin(math.pi * w)
                pt = pitch_off * math.sin(math.pi * min(1.0, w * 1.6)) if w < 0.62 else 0.0
            feet.append((float(p[0]), float(p[1]), h, yaw, pt))
        out.append((t, feet[0], feet[1]))
    return out


def visible(world, part, body, rest_point):
    """Where a rest-space point carried by `part` is now (the mesh rides the part rigidly)."""
    M = world[part] @ np.linalg.inv(REST[part])
    return (M @ np.append(np.asarray(rest_point, float), 1))[:3]


def striker_point(clip, world):
    part, pt = clip.striker
    if pt == "fist":
        pt = clip.body.fist["Right" if part.startswith("Right") else "Left"]
    return visible(world, part, clip.body, pt)


def pop_point(clip, world):
    """The point the pop check follows. A held weapon's striker is tracked at the hand that holds it, as jianlib does
    for the Jian: the blade only amplifies the wrist's rotation, and the swept blade is checked by the blow test."""
    if not clip.striker:
        return visible(world, "RightHand", clip.body, clip.body.fist["Right"])
    part, pt = clip.striker
    if pt != "fist" and part.endswith("Hand"):
        return visible(world, part, clip.body, clip.body.fist["Right" if part.startswith("Right") else "Left"])
    return striker_point(clip, world)


def validate(clip, baked):
    """Reach, ground, planted-foot slide, pops, loop seam, and the blow against the server's swept shape."""
    w = {"arm_reach": 0.0, "leg_reach": 0.0, "sole_below_ground": 0.0, "planted_slide": 0.0, "hand_jerk": 0.0, "loop_seam_deg": 0.0}
    prev, pts, hand = None, [], []
    for t, local, world, diag, c in baked:
        w["arm_reach"] = max(w["arm_reach"], diag["right_excess"], diag["left_excess"])
        w["leg_reach"] = max(w["leg_reach"], diag["left_leg_excess"], diag["right_leg_excess"])
        soles = {}
        for foot in ("LeftFoot", "RightFoot"):
            p = rig.obb_points(world, foot)
            low = min(q[1] for q in p)
            w["sole_below_ground"] = max(w["sole_below_ground"], rig.GROUND - low)
            soles[foot] = (p, low)
        free = any(a - 1e-6 <= t <= b + 1e-6 for a, b in clip.feet_free)
        if prev and not free:
            for foot, (p, low) in soles.items():
                p0, low0 = prev[foot]
                if low - rig.GROUND < 0.01 and low0 - rig.GROUND < 0.01:
                    k = int(np.argmin([q[1] for q in p]))
                    # a locomotion cycle's planted foot rides the ground backward at exactly the root's speed
                    slip = (p[k] - p0[k])[[0, 2]] * FPS + np.asarray(clip.velocity, float)
                    w["planted_slide"] = max(w["planted_slide"], float(np.linalg.norm(slip)))
        prev = soles
        pts.append(striker_point(clip, world) if clip.striker else visible(world, "RightHand", clip.body, clip.body.fist["Right"]))
        hand.append(pop_point(clip, world))
    for k in range(1, len(hand) - 1):
        if any(abs(baked[k][0] - ct) < 0.035 for ct in clip.contacts):
            continue
        a, b, c2 = hand[k - 1], hand[k], hand[k + 1]
        v0, v1 = b - a, c2 - b
        jerk = float(np.linalg.norm(a - 2 * b + c2))
        speed = max(float(np.linalg.norm(v0)), float(np.linalg.norm(v1)))
        turn = float(np.dot(unit(v0), unit(v1))) if min(np.linalg.norm(v0), np.linalg.norm(v1)) > 0.02 else 1.0
        if jerk >= 0.75 * speed and turn < 0.7:
            w["hand_jerk"] = max(w["hand_jerk"], jerk)
    if clip.loop:
        a, b = baked[0][1], baked[-1][1]
        w["loop_seam_deg"] = max(rig.angle_of(a[p][:3, :3].T @ b[p][:3, :3]) for p in a)
    w = {k: round(float(v), 4) for k, v in w.items()}
    problems = []
    if w["arm_reach"] > 0.06:
        problems.append("fist short of its target by %.2f" % w["arm_reach"])
    if w["leg_reach"] > 0.05:
        problems.append("leg short of its foot by %.2f" % w["leg_reach"])
    if w["sole_below_ground"] > 0.06:
        problems.append("foot %.2f below ground" % w["sole_below_ground"])
    if w["planted_slide"] > 0.6:
        problems.append("planted foot slides %.2f studs/s" % w["planted_slide"])
    if w["hand_jerk"] > 0.3:
        problems.append("striker pops %.2f" % w["hand_jerk"])
    if clip.loop and w["loop_seam_deg"] > 1.0:
        problems.append("loop seam %.1f deg" % w["loop_seam_deg"])
    if clip.move and clip.active is not None and clip.striker:
        start, length, arc, reach = clip.active
        times = [b[0] for b in baked]
        i0 = int(np.argmin([abs(t - start) for t in times]))
        i1 = int(np.argmin([abs(t - (start + length)) for t in times]))
        ic = int(np.argmin([abs(t - clip.contacts[0]) for t in times]))
        yaw = lambda p: math.degrees(math.atan2(p[0], -p[2]))
        hit = pts[ic]
        s = {"contact": [round(float(x), 2) for x in hit], "forward": round(float(-hit[2]), 2), "yaw": round(yaw(hit), 1)}
        if arc > 40:
            s["sweep_deg"] = round(yaw(pts[i1]) - yaw(pts[i0]), 1)
        if -hit[2] < 1.7:
            problems.append("blow lands only %.2f studs forward" % -hit[2])
        if abs(yaw(hit)) > max(25, arc * 0.5):
            problems.append("blow lands %.0f deg off the facing" % yaw(hit))
        # A scaled body's blow should land on the target's body where the AI actually swings from (clip.meet, studs
        # from his root at game scale), not short of it in clear air.
        scale, meet = getattr(clip, "scale", None), getattr(clip, "meet", None)
        if scale and meet:
            radial = float(math.hypot(hit[0], hit[2])) * scale
            s["game_reach"] = round(radial, 2)
            if abs(radial - meet) > 0.8:
                problems.append("blow lands %.1f studs out at scale %.2f; the body is met at %.1f" % (radial, scale, meet))
        w["strike"] = s
    return w, problems


def frames_json(clip, baked, path):
    frames = [{"t": round(t, 4), "parts": {p: [round(float(x), 5) for x in M.ravel()] for p, M in world.items()}}
              for t, local, world, diag, c in baked]
    path.write_text(json.dumps({"name": clip.name, "length": clip.length, "contacts": clip.contacts, "frames": frames}))
