"""Grandmaster Shen's clip solver, one instance per form: forward kinematics about each sculpt's own joints, analytic limb IK, a true two-handed guandao, and baked cloth, hair, beard and bead motion.

Each form's rest pose is its sculpt (tools/blender/shen_import/rigdef.py): a zero Transform on every joint shows the model as designed. BossRigs.apply moves the rig attachments to these joints, rotations stay axis-aligned, so
    W[bone] = W[parent] * Translate(joint) * Transform * Translate(-joint)    (W maps a rest-pose point to clip space)
Clip space is HumanoidRootPart space at scale 1; the Animator scales translation with the Model. +X his right, +Y up, -Z his front.

Joint owners: the clip owns every joint. Secondary motion is derived here at bake time and exported as ordinary keyed joints; no script writes a joint at run time, so nothing fights the Animator.
Blade convention: `face` is the direction the cutting edge points, `haft` runs from butt to blade. rx(+a) swings a hanging limb toward his front.
"""
import math
import random
import re
import sys
import zlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/blender/shen_import"))
sys.path.insert(0, str(ROOT / "tools/animation/general_zhao"))
import landmarks as LM  # noqa: E402
import rigdef as R  # noqa: E402
import rig as ZR  # noqa: E402  # quat, mat, slerp, angle_of
import export as ZX  # noqa: E402  # cframe, ref, PRIORITY

FPS = 30
GROUND = -3.1924
SCALE = 1.3        # WorldDefinitions: Shen's game scale, chosen so the sculpted guandao reaches the server's blow
BODY_MET = 7.875   # MobSpacing.standoff: 0.75 x the Guandao's first swing, reach 10.5


def unit(v):
    v = np.asarray(v, float)
    return v / max(np.linalg.norm(v), 1e-9)


def orth(v, axis):
    v = np.asarray(v, float)
    return unit(v - axis * np.dot(v, axis))


def rx(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]], float)


def ry(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]], float)


def rz(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]], float)


def euler(e):
    """degrees (pitch x, yaw y, roll z), applied yaw, then pitch, then roll. Yaw + turns him left, pitch + bows him forward when applied to a torso."""
    return ry(math.radians(e[1])) @ rx(math.radians(-e[0])) @ rz(math.radians(e[2]))


def frame3(a, b):
    a = unit(a)
    b = orth(b, a)
    return np.column_stack((a, b, np.cross(a, b)))


def homog(Rm=None, t=None):
    M = np.eye(4)
    if Rm is not None:
        M[:3, :3] = Rm
    if t is not None:
        M[:3, 3] = t
    return M


def rotvec(M):
    """The rotation vector of a rotation matrix, radians."""
    c = min(max((np.trace(M) - 1) / 2, -1.0), 1.0)
    a = math.acos(c)
    if a < 1e-6:
        return np.zeros(3)
    w = np.array([M[2, 1] - M[1, 2], M[0, 2] - M[2, 0], M[1, 0] - M[0, 1]])
    return w / (2 * math.sin(a)) * a


def rodrigues(v):
    a = float(np.linalg.norm(v))
    if a < 1e-9:
        return np.eye(3)
    k = v / a
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + math.sin(a) * K + (1 - math.cos(a)) * K @ K


def clamp_rot(M, fraction, limit_deg):
    """The fraction of a rotation, no larger than limit_deg, as a rotation vector."""
    v = rotvec(M) * fraction
    a = math.degrees(np.linalg.norm(v))
    return v * (limit_deg / a) if a > limit_deg else v


def pole_of(a, b, c):
    """The side the middle joint bends to at rest: its offset from the line a-c."""
    return orth(b - a, unit(c - a))


def two_bone(S, T, u0, l0, pole0, pole1, label, diag):
    """Solve shoulder/hip S, target T for rest bones u0, l0. Returns rotations of the two bones and the reached end; overreach is reported."""
    a, b = float(np.linalg.norm(u0)), float(np.linalg.norm(l0))
    d = T - S
    dist = float(np.linalg.norm(d))
    limit = (a + b) * 0.9995
    diag[label] = max(diag.get(label, 0.0), max(0.0, dist - limit))
    dist_c = min(max(dist, abs(a - b) + 1e-3), limit)
    axis = unit(d)
    along = (a * a - b * b + dist_c * dist_c) / (2 * dist_c)
    height = math.sqrt(max(a * a - along * along, 0.0))
    M = S + axis * along + orth(pole1, axis) * height
    W = S + axis * dist_c
    return frame3(M - S, pole1) @ frame3(u0, pole0).T, frame3(W - M, pole1) @ frame3(l0, pole0).T, W


def foot_roll(pitch_deg):
    """How the ankle rises and travels as the foot rolls: pitch + (toe up) pivots on the heel, pitch - (heel up) on the ball. Returns (lift, forward)."""
    th = math.radians(pitch_deg)
    a, b = (0.27, 0.34) if pitch_deg >= 0 else (-0.6, 0.34)
    return a * math.sin(th) + b * math.cos(th) - b, a * math.cos(th) - b * math.sin(th) - a


def clip_airborne(clip):
    return clip.airborne


class Rig:
    def __init__(self, phase):
        self.phase = phase
        J = LM.PHASES[phase]
        self.landmarks = J
        joints, helpers = R.JOINT[phase], R.HELPER[phase]
        self.JOINT = {k: np.array(v[1], float) for k, v in joints.items()}
        self.PARENT = {k: v[0] for k, v in joints.items()}
        self.MOTOR = {k: v[2] for k, v in joints.items()}
        self.ORDER = list(joints)
        for k, v in helpers.items():
            self.JOINT[k] = np.array(v[1], float)
            self.PARENT[k] = v[0]
        self.HELPERS = list(helpers)
        self.ALL = self.ORDER + self.HELPERS
        self.CHILDREN = {}
        for k in self.ALL:
            self.CHILDREN.setdefault(self.PARENT[k], []).append(k)
        self.GRIP0 = np.array(J.RGRIP, float)
        self.PALM0 = np.array(J.LHAND, float)
        self.HAFT0 = unit(np.array(J.SOCKET, float) - np.array(J.BUTT, float))
        self.samples = {k: v.astype(float) for k, v in np.load(ROOT / f"work/shen_import/samples_p{phase}.npz").items()}
        w = self.samples["Weapon"]
        t = (w - self.GRIP0) @ self.HAFT0
        blade = w[t > np.dot(np.array(J.SOCKET, float) - self.GRIP0, self.HAFT0) + 0.05]
        off = (blade - self.GRIP0) - np.outer((blade - self.GRIP0) @ self.HAFT0, self.HAFT0)
        spine = np.linalg.svd(off - off.mean(0))[2][0]     # the blade's width axis; the tip sweeps to the spine side
        spine = spine if (off @ spine).max() > -(off @ spine).min() else -spine
        self.FACE0 = orth(-spine, self.HAFT0)              # the convex cutting edge is the other side
        self.TIP0 = w[int(np.argmax(t))]
        J_ = self.JOINT
        self.ARM_U, self.ARM_L = J_["RightLowerArm"] - J_["RightUpperArm"], J_["RightHand"] - J_["RightLowerArm"]
        self.ELBOW0 = pole_of(J_["RightUpperArm"], J_["RightLowerArm"], J_["RightHand"])
        self.LARM_U, self.LARM_L = J_["LeftLowerArm"] - J_["LeftUpperArm"], J_["LeftHand"] - J_["LeftLowerArm"]
        self.LELBOW0 = pole_of(J_["LeftUpperArm"], J_["LeftLowerArm"], J_["LeftHand"])
        self.LEGS = {}
        for side in ("Left", "Right"):
            h, k, a = J_[side + "UpperLeg"], J_[side + "LowerLeg"], J_[side + "Foot"]
            self.LEGS[side] = {"u": k - h, "l": a - k, "pole": pole_of(h, k, a), "ankle": a}
        self.REST = {
            "pel": (0.0, 0.0, 0.0), "pelR": (0.0, 0.0, 0.0), "chest": (0.0, 0.0, 0.0), "neck": (0.0, 0.0, 0.0),
            "rh": tuple(self.GRIP0 - J_["RightUpperArm"]), "haft": tuple(self.HAFT0), "face": tuple(self.FACE0), "relb": tuple(self.ELBOW0), "rgw": 0.0, "rg": tuple(self.GRIP0),
            "lua": (0.0, 0.0, 0.0), "lfa": (0.0, 0.0, 0.0), "lha": (0.0, 0.0, 0.0), "lhw": 0.0, "lsl": -1.1, "ltw": 0.0, "lt": (-0.2, -1.2, -0.6), "lelb": (-0.5, -0.4, 0.7),
            "rf": (0.0, 0.0, 0.0, 0.0, 0.0), "lf": (0.0, 0.0, 0.0, 0.0, 0.0), "rknee": tuple(self.LEGS["Right"]["pole"]), "lknee": tuple(self.LEGS["Left"]["pole"]),
        }

    def pivoted(self, W_parent, bone, L):
        j = self.JOINT[bone]
        return W_parent @ homog(None, j) @ L @ homog(None, -j)

    def hand_rotation(self, haft, face):
        return frame3(haft, face) @ frame3(self.HAFT0, self.FACE0).T

    def palm_rotation(self, haft, forearm):
        """The left hand on the haft: its length wraps across the haft, thumb side toward the blade, continuing the forearm as far as the wrap allows."""
        a0 = unit(self.PALM0 - self.JOINT["LeftHand"])
        return frame3(orth(forearm, unit(haft)), haft) @ frame3(a0, (0, 0, -1)).T


DIRECTION = {"haft", "face", "relb", "rknee", "lknee", "lelb"}
FEET = {"rf", "lf"}
EASE = {
    "lin": lambda u: u, "in": lambda u: u * u, "out": lambda u: 1 - (1 - u) * (1 - u), "io": lambda u: u * u * (3 - 2 * u),
    "snap": lambda u: 1 - (1 - u) ** 3, "whip": lambda u: u * u * u,
}


class Clip:
    rise_guard = False
    """Timed partial control keys, Catmull-Rom between them; a channel a key omits holds through. Phase 2's corruption (lower, forward, more torque) is a layer over the shared technique."""

    def __init__(self, rig, name, length, keys, loop=False, priority="Action", contacts=(), move=None, notes="", active=None, slot="", feet_free=(), corrupt=True, scrape=False, airborne=False, authored_feet=False, raw_after=None):
        self.rig = rig
        self.name, self.length, self.loop, self.priority = name, float(length), loop, priority
        self.keys = sorted(((float(t), c, e) for t, c, e in keys), key=lambda k: k[0])
        self.contacts = [float(c) for c in contacts]
        self.move, self.notes, self.active = move, notes, active
        self.slot = slot or name
        self.feet_free = list(feet_free)
        self.corrupt = corrupt and rig.phase == 2
        self.scrape, self.airborne = scrape, airborne
        self.authored_feet, self.raw_after = authored_feet, raw_after   # a gait or a pivot keys its own heel and toe; raw_after: the pose must be exact from here (a shared handoff)

    def frames(self):
        n = int(round(self.length * FPS))
        if self.loop:   # a loop's last frame is its first, exactly
            return [i / n * self.length for i in range(n + 1)]
        return [i / FPS for i in range(n + 1)]

    def channel(self, name, t):
        keyed = [(kt, c[name], e) for kt, c, e in self.keys if name in c]
        if not keyed:
            return np.asarray(self.rig.REST[name], float)
        if self.loop and keyed[-1][0] < self.length - 1e-6:
            keyed = keyed + [(self.length, keyed[0][1], keyed[0][2])]
        if t <= keyed[0][0]:
            return np.asarray(keyed[0][1], float)
        if t >= keyed[-1][0]:
            return np.asarray(keyed[-1][1], float)
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
                        out[2] = max(out[2], min(0.45, dist * 0.32) * math.sin(math.pi * u) if dist > 0.08 else 0)
                return unit(out) if name in DIRECTION else out
        return vals[-1]

    def controls(self, t):
        c = {name: self.channel(name, t) for name in self.rig.REST}
        c["lhw"], c["ltw"], c["rgw"] = [float(np.clip(c[k], 0, 1)) for k in ("lhw", "ltw", "rgw")]
        if self.corrupt:  # the same technique, predatory: lower, forward, the torso wound further against the hips
            c["pel"] = c["pel"] + np.array([0, -0.16, -0.03])
            c["pelR"] = c["pelR"] * np.array([1, 1.18, 1]) + np.array([6.0, 0, 0])
            c["chest"] = c["chest"] * np.array([1, 1.28, 1]) + np.array([8.0, 0, 0])
            c["neck"] = c["neck"] + np.array([-9.0, 0, 0])
            c["rf"] = c["rf"] + np.array([0.06, 0, 0, 0, 0])
            c["lf"] = c["lf"] + np.array([-0.06, 0, 0, 0, 0])
        return c

    def clear_floor(self, fist, haft, face):
        """The blade may touch the floor, never pass through it: pitch the weapon up about the fist just enough. Azimuth and edge stay as authored."""
        rg = self.rig
        pts = rg.samples["Weapon"][::4] - rg.GRIP0
        if self.airborne and fist[1] > GROUND + 1.0 and self.rise_guard:
            return haft, face
        for _ in range(4):
            low = float((pts @ rg.hand_rotation(haft, face).T)[:, 1].min() + fist[1])
            deficit = (GROUND + 0.03) - low
            if deficit <= 0:
                break
            flat = np.array([haft[0], 0.0, haft[2]])
            axis = unit(np.cross(unit(flat) if np.linalg.norm(flat) > 1e-3 else np.array([0, 0, -1.0]), (0, 1.0, 0)))
            angle = -deficit / 3.4 - 0.01
            turn = rodrigues(axis * -angle)
            turn = turn if (turn @ haft)[1] > haft[1] else turn.T
            haft, face = turn @ haft, turn @ face
        return haft, face

    def solve(self, c):
        rg = self.rig
        diag = {}
        local, world = {}, {"HumanoidRootPart": np.eye(4)}
        local["LowerTorso"] = homog(euler(c["pelR"]), c["pel"])
        world["LowerTorso"] = rg.pivoted(world["HumanoidRootPart"], "LowerTorso", local["LowerTorso"])
        local["UpperTorso"] = homog(euler(c["chest"]))
        world["UpperTorso"] = rg.pivoted(world["LowerTorso"], "UpperTorso", local["UpperTorso"])
        Rch = world["UpperTorso"][:3, :3]
        local["Head"] = homog(euler(c["neck"]))
        world["Head"] = rg.pivoted(world["UpperTorso"], "Head", local["Head"])
        # right arm: a fist the haft runs through. Overreach pulls the fist in, never turns the weapon
        S = (world["UpperTorso"] @ np.append(rg.JOINT["RightUpperArm"], 1))[:3]
        fist = S + np.asarray(c["rh"], float)
        if c["rgw"] > 0:
            fist = fist + (np.asarray(c["rg"], float) - fist) * c["rgw"]
        haft, face = self.clear_floor(fist, unit(c["haft"]), unit(c["face"]))
        c["haft"], c["face"] = haft, face
        Rh = rg.hand_rotation(haft, face)
        wrist_off = Rh @ (rg.JOINT["RightHand"] - rg.GRIP0)
        ru, rl, wrist = two_bone(S, fist + wrist_off, rg.ARM_U, rg.ARM_L, rg.ELBOW0, unit(c["relb"]), "arm_reach", diag)
        local["RightUpperArm"] = homog(Rch.T @ ru)
        world["RightUpperArm"] = rg.pivoted(world["UpperTorso"], "RightUpperArm", local["RightUpperArm"])
        local["RightLowerArm"] = homog(ru.T @ rl)
        world["RightLowerArm"] = rg.pivoted(world["RightUpperArm"], "RightLowerArm", local["RightLowerArm"])
        local["RightHand"] = homog(rl.T @ Rh)
        world["RightHand"] = rg.pivoted(world["RightLowerArm"], "RightHand", local["RightHand"])
        grip_at = (world["RightHand"] @ np.append(rg.GRIP0, 1))[:3]
        # left arm: free (forward kinematics in the chest's axes), on the haft, or reaching for a point; blended, so it can leave and rejoin the weapon in a move
        Su, Sf = Rch @ euler(c["lua"]), Rch @ euler(c["lfa"])
        Sh = Sf @ euler(c["lha"])
        hold, reach = c["lhw"], c["ltw"]
        if hold > 0 or reach > 0:
            SL = (world["UpperTorso"] @ np.append(rg.JOINT["LeftUpperArm"], 1))[:3]
            if hold >= reach:
                ax = unit(c["haft"])
                sl = float(c["lsl"])
                # the free hand slides on the haft: when its keyed spot is out of reach it slips along toward the shoulder instead of leaving the wood
                maxr = float(np.linalg.norm(rg.LARM_U) + np.linalg.norm(rg.LARM_L)) * 0.98
                near = float(np.clip(np.dot(SL - grip_at, ax), -2.5, -0.4))
                for _ in range(12):
                    if np.linalg.norm(grip_at + ax * sl - SL) <= maxr:
                        break
                    sl += (near - sl) * 0.35
                on = grip_at + ax * sl
                forearm = unit(on - (SL + unit(c["lelb"]) * 0.7))
                Rp = rg.palm_rotation(c["haft"], forearm)
                target = on - Rp @ (rg.PALM0 - rg.JOINT["LeftHand"])
                w = hold
                self_label = "left_grip"
            else:
                target = SL + np.asarray(c["lt"], float)
                Rp = None
                w = reach
                self_label = "left_reach"
            scratch = {}
            u_ik, f_ik, _ = two_bone(SL, target, rg.LARM_U, rg.LARM_L, rg.LELBOW0, unit(c["lelb"]), self_label, scratch)
            diag[self_label] = max(diag.get(self_label, 0.0), scratch[self_label] * w * w)   # a hand on its way to the haft is not yet expected there
            if Rp is None:
                Rp = f_ik @ euler(c["lha"])
            Su = ZR.mat(ZR.slerp(ZR.quat(Su), ZR.quat(u_ik), w))
            Sf = ZR.mat(ZR.slerp(ZR.quat(Sf), ZR.quat(f_ik), w))
            Sh = ZR.mat(ZR.slerp(ZR.quat(Sh), ZR.quat(Rp), w))
        local["LeftUpperArm"] = homog(Rch.T @ Su)
        world["LeftUpperArm"] = rg.pivoted(world["UpperTorso"], "LeftUpperArm", local["LeftUpperArm"])
        local["LeftLowerArm"] = homog(Su.T @ Sf)
        world["LeftLowerArm"] = rg.pivoted(world["LeftUpperArm"], "LeftLowerArm", local["LeftLowerArm"])
        local["LeftHand"] = homog(Sf.T @ Sh)
        world["LeftHand"] = rg.pivoted(world["LeftLowerArm"], "LeftHand", local["LeftHand"])
        # legs: x, z, lift, yaw, pitch from the rest ankle
        Rlt = world["LowerTorso"][:3, :3]
        for side, key, pole in (("Right", "rf", "rknee"), ("Left", "lf", "lknee")):
            x, z, lift, yaw, pitch = [float(v) for v in c[key]]
            leg = rg.LEGS[side]
            A = leg["ankle"] + np.array([x, lift, z])
            H = (world["LowerTorso"] @ np.append(rg.JOINT[side + "UpperLeg"], 1))[:3]
            # a leg reaching its limit rolls up onto the ball of the foot rather than pulling the foot along or locking straight
            c[key + "_heel"] = 0.0
            if lift < 0.2 and not clip_airborne(self):
                reach = float(np.linalg.norm(H - A)) / (float(np.linalg.norm(leg["u"])) + float(np.linalg.norm(leg["l"])))
                k = min(max((reach - 0.9) / 0.09, 0.0), 1.0)
                if k > 0:
                    th = k * k * (3 - 2 * k) * 42.0
                    up, fwd = foot_roll(-th)
                    d = ry(math.radians(yaw)) @ np.array([0, 0, -1.0])
                    A = A + np.array([0, up, 0]) + d * fwd
                    pitch = pitch - th
                    c[key + "_heel"] = th
            Rfoot = ry(math.radians(yaw)) @ rx(math.radians(pitch))
            ru_, rl_, _ = two_bone(H, A, leg["u"], leg["l"], leg["pole"], ry(math.radians(yaw)) @ unit(c[pole]), "leg_reach", diag)
            local[side + "UpperLeg"] = homog(Rlt.T @ ru_)
            world[side + "UpperLeg"] = rg.pivoted(world["LowerTorso"], side + "UpperLeg", local[side + "UpperLeg"])
            local[side + "LowerLeg"] = homog(ru_.T @ rl_)
            world[side + "LowerLeg"] = rg.pivoted(world[side + "UpperLeg"], side + "LowerLeg", local[side + "LowerLeg"])
            local[side + "Foot"] = homog(rl_.T @ Rfoot)
            world[side + "Foot"] = rg.pivoted(world[side + "LowerLeg"], side + "Foot", local[side + "Foot"])
        return local, world, diag

    def bake(self):
        times = self.frames()
        ctrl = [self.controls(t) for t in times]
        organic(self, times, ctrl)
        out = []
        for t, c in zip(times, ctrl):
            local, world, diag = self.solve(c)
            out.append([t, local, world, diag, c])
        derive_helpers(self, out)
        return out


# ---------------------------------------------------------------------------------------------------- the organic layer
OVERLAP = {  # channel: (omega, damping) for phase 1 and phase 2: hips lead, then chest, then head and the free arm settle behind. The weapon hand stays exactly on its key so contacts do not move.
    1: {"pel": (34, 0.85), "pelR": (30, 0.8), "chest": (20, 0.72), "neck": (13, 0.78), "relb": (22, 0.8), "lua": (12, 0.55), "lfa": (10, 0.5), "lha": (14, 0.6), "lt": (20, 0.7), "lelb": (16, 0.7)},
    2: {"pel": (32, 0.7), "pelR": (28, 0.62), "chest": (20, 0.5), "neck": (15, 0.55), "relb": (22, 0.65), "lua": (13, 0.42), "lfa": (11, 0.4), "lha": (16, 0.45), "lt": (20, 0.55), "lelb": (16, 0.6)},
}
MICRO = {  # (channel, axis, amplitude): the small unrest that keeps a hold from reading as a frozen pose
    1: [("chest", 0, 0.5), ("chest", 1, 0.4), ("neck", 0, 0.6), ("neck", 1, 0.8), ("pel", 1, 0.004), ("pelR", 2, 0.35), ("lua", 0, 0.6), ("lfa", 0, 0.8)],
    2: [("chest", 0, 0.9), ("chest", 1, 0.8), ("chest", 2, 0.5), ("neck", 0, 1.1), ("neck", 1, 1.4), ("pel", 1, 0.008), ("pelR", 2, 0.6), ("lua", 0, 1.1), ("lfa", 0, 1.6), ("lha", 0, 2.5)],
}


def organic(clip, times, ctrl):
    """Turns poses that all move together into a body: unrest in the holds, a heel-and-toe on every step with the weight shifting off that foot, then each joint following the one before it."""
    n = len(times)
    if n < 3:
        return
    rg = clip.rig
    rng = random.Random(zlib.crc32(clip.name.encode()))
    length = clip.length
    for ch, axis, amp in MICRO[rg.phase]:
        # whole cycles of the clip's length, so a loop closes; two rates so it never reads as a sine
        f1 = max(1, round(length * rng.uniform(0.22, 0.4)))
        f2 = max(f1 + 1, round(length * rng.uniform(0.7, 1.1)))
        p1, p2 = rng.uniform(0, 6.28), rng.uniform(0, 6.28)
        for t, c in zip(times, ctrl):
            v = np.array(c[ch], float)
            v[axis] += amp * (math.sin(2 * math.pi * f1 * t / length + p1) * 0.7 + math.sin(2 * math.pi * f2 * t / length + p2) * 0.3)
            c[ch] = v
    if not clip.authored_feet:
        step_feet(clip, times, ctrl)
    dt = 1.0 / FPS
    for ch, (omega, zeta) in OVERLAP[rg.phase].items():
        raw = [np.array(c[ch], float) for c in ctrl]
        lag = spring(raw, dt, omega, zeta, clip.loop)
        for i, (t, c) in enumerate(zip(times, ctrl)):
            w = 1.0
            if not clip.loop:
                w = 1 - smooth01((t - (length - 0.15)) / 0.15)
                if clip.raw_after is not None:
                    w *= 1 - smooth01((t - (clip.raw_after - 0.14)) / 0.14)
            v = raw[i] + (lag[i] - raw[i]) * w
            c[ch] = unit(v) if ch in DIRECTION else v


def smooth01(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def step_feet(clip, times, ctrl):
    """Finds every step in a keyed clip. The foot peels off toe-last, lands heel-first and rolls flat; the hips shift over the other foot for the length of the step."""
    n = len(times)
    for key, other_sign in (("rf", -1.0), ("lf", 1.0)):
        pos = np.array([c[key][:2] for c in ctrl], float)
        speed = np.zeros(n)
        speed[1:] = np.linalg.norm(pos[1:] - pos[:-1], axis=1) * FPS
        moving = speed > 0.35
        i = 0
        while i < n:
            if not moving[i]:
                i += 1
                continue
            j = i
            while j + 1 < n and moving[j + 1]:
                j += 1
            start, end = max(i - 1, 0), j
            dur = times[end] - times[start]
            dist = float(np.linalg.norm(pos[end] - pos[start]))
            if dist > 0.12 and dur > 0.03:
                strength = min(dist / 0.6, 1.0)
                forward = (pos[end] - pos[start])[1] < 0.05         # a retreating step lands toe-first
                for f in range(start, min(end + 8, n)):
                    t = times[f]
                    u = (t - times[start]) / dur
                    c = ctrl[f]
                    v = np.array(c[key], float)
                    if u <= 1.0:
                        peel = -24.0 * math.sin(math.pi * min(u / 0.45, 1.0)) if u < 0.45 else 0.0
                        land = 16.0 * smooth01((u - 0.45) / 0.55) if forward else -12.0 * smooth01((u - 0.45) / 0.55)
                        pitch = (peel + land) * strength
                    else:   # the slap: the rest of the foot comes down just after the heel
                        pitch = (16.0 if forward else -12.0) * strength * (1 - smooth01((t - times[end]) / 0.13))
                    up, fw = foot_roll(pitch)
                    v[4] += pitch
                    v[2] += max(up, 0.0)
                    c[key] = v
                    if u <= 1.0:   # the weight rides over the planted foot
                        w = math.sin(math.pi * u) * strength
                        p = np.array(c["pel"], float)
                        p[0] += other_sign * 0.1 * w
                        c["pel"] = p
                        r = np.array(c["pelR"], float)
                        r[2] += other_sign * -1.6 * w
                        c["pelR"] = r
            i = j + 1


# ---------------------------------------------------------------------------------------------------- derived joints
def thigh_flex(rig, world, side):
    """Forward raise of a thigh in the pelvis frame, degrees: + toward his front."""
    Rt = world["LowerTorso"][:3, :3].T @ world[side + "UpperLeg"][:3, :3]
    v0 = unit(rig.LEGS[side]["u"])
    v = Rt @ v0
    return math.degrees(math.atan2(-v[2], -v[1]) - math.atan2(-v0[2], -v0[1]))


def spring(targets, dt, omega, zeta, loop):
    """Follows a sequence of values a beat behind; a looped clip runs twice so its seam closes."""
    targets = [np.asarray(x, float) for x in targets]
    x, v = targets[0].copy(), np.zeros_like(targets[0])
    out = []
    seq = targets[:-1] if loop and len(targets) > 1 else targets   # a loop's last frame is its first
    for _ in range(3 if loop else 1):
        out = []
        for tgt in seq:
            for _ in range(4):
                h = dt / 4
                a = omega * omega * (tgt - x) - 2 * zeta * omega * v
                v = v + a * h
                x = x + v * h
            out.append(x.copy())
    if seq is not targets:
        out.append(out[0].copy())
    return out


def derive_helpers(clip, baked):
    """Phase 2's floating beads drift on their own small orbit and swing behind the body's travel. Everything that hangs (robe, hair, beard, sleeves) is skinned and simulated at run time; no clip keys it."""
    rg = clip.rig
    if rg.phase != 2:
        return
    dt = 1.0 / FPS
    speed, last = [], None
    for t, local, world, diag, c in baked:
        p = world["LowerTorso"][:3, 3]
        speed.append(np.zeros(3) if last is None else (p - last) / dt)
        last = p
    if clip.loop and len(speed) > 1:
        speed[0] = speed[-1]
    cycles = max(1, round(clip.length / 2.8))
    w0 = 2 * math.pi * cycles / clip.length
    for k, (bone, r, phase_) in enumerate((("Bead1", 0.16, 0.0), ("Bead2", 0.10, 2.1), ("Bead3", 0.20, 4.2))):
        lag = spring([np.clip(s, -8, 8) * -0.025 for s in speed], dt, 7.0, 0.5, clip.loop)
        for i, entry in enumerate(baked):
            t, local, world = entry[0], entry[1], entry[2]
            a = w0 * (i / (len(baked) - 1) * clip.length) + phase_    # the last frame is the clip's end whatever the frame grid says
            calm = min(1.0, clip.length / 2.8)   # a short clip carries the orbit's position, not its speed
            off = np.array([math.cos(a) * r, math.sin(a * 2) * r * 0.55, math.sin(a) * r * 0.8]) * calm + lag[i]
            local[bone] = homog(ry(math.sin(a) * 0.7 * calm) @ rx(math.sin(a) * 0.25 * calm), off)
            world[bone] = rg.pivoted(world[rg.PARENT[bone]], bone, local[bone])


# ---------------------------------------------------------------------------------------------------- export
TOL_DEG, TOL_POS = 0.6, 0.008


def decimate(rig, baked, keep_times):
    keep, n, i = [0], len(baked), 0
    while i < n - 1:
        j = i + 2
        while j < n:
            ok = True
            for k in range(i + 1, j):
                if any(abs(baked[k][0] - kt) < 1e-6 for kt in keep_times):
                    ok = False
                    break
                u = (baked[k][0] - baked[i][0]) / (baked[j][0] - baked[i][0])
                for part in rig.ALL:
                    a, b, m = baked[i][1][part], baked[j][1][part], baked[k][1][part]
                    q = ZR.slerp(ZR.quat(a[:3, :3]), ZR.quat(b[:3, :3]), u)
                    if ZR.angle_of(ZR.mat(q).T @ m[:3, :3]) > TOL_DEG or np.linalg.norm(a[:3, 3] + (b[:3, 3] - a[:3, 3]) * u - m[:3, 3]) > TOL_POS:
                        ok = False
                        break
                if not ok:
                    break
            if not ok:
                break
            j += 1
        i = j - 1
        keep.append(i)
    return keep


def pose_xml(rig, part, local, indent):
    pad = "\t" * indent
    M = local.get(part, np.eye(4))
    kids = "".join(pose_xml(rig, k, local, indent + 1) for k in rig.CHILDREN.get(part, []))
    return ('%s<Item class="Pose" referent="%s"><Properties><string name="Name">%s</string>'
            '<CoordinateFrame name="CFrame">%s</CoordinateFrame><float name="Weight">1</float>'
            '<token name="EasingStyle">0</token><token name="EasingDirection">0</token></Properties>\n%s%s</Item>\n'
            % (pad, ZX.ref(), part, ZX.cframe(M), kids, pad))


def write_rbxmx(clip, baked, path):
    ZX._ref[0] = 0
    idx = decimate(clip.rig, [(b[0], b[1]) for b in baked], list(clip.contacts))
    body = "".join('\t<Item class="Keyframe" referent="%s"><Properties><string name="Name">Keyframe</string>'
                   '<float name="Time">%.6f</float></Properties>\n%s\t</Item>\n' % (ZX.ref(), baked[i][0], pose_xml(clip.rig, "HumanoidRootPart", baked[i][1], 2)) for i in idx)
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">\n'
           '<Item class="KeyframeSequence" referent="%s"><Properties><string name="Name">%s</string>'
           '<bool name="Loop">%s</bool><token name="Priority">%d</token><float name="AuthoredHipHeight">2.192423</float>'
           '</Properties>\n%s</Item>\n</roblox>\n' % (ZX.ref(), clip.name, "true" if clip.loop else "false", ZX.PRIORITY[clip.priority], body))
    path.write_text(xml)
    return len(idx)


# ---------------------------------------------------------------------------------------------------- validation
def place(rig, world, name):
    pts = rig.samples[name]
    W = world[R.bone_of(rig.phase, name)]
    return pts @ W[:3, :3].T + W[:3, 3]


def blow(rig, world):
    """The weapon point farthest from his root axis: where it is, its radius, its yaw (+ right)."""
    pts = place(rig, world, "Weapon")
    r = np.hypot(pts[:, 0], pts[:, 2])
    i = int(np.argmax(r))
    p = pts[i]
    return p, float(r[i]), math.degrees(math.atan2(p[0], -p[2]))


def check_rigs():
    """src/shared/BossRigs.luau is what the game applies and rigdef.py is what the clips were solved on: they must agree, per form."""
    text = (ROOT / "src/shared/BossRigs.luau").read_text()
    for phase in (1, 2):
        block = re.search(r"AsuraBoss_GrandmasterShen_P%d = \{(.*?)\} :: Def" % phase, text, re.S)
        if not block:
            raise SystemExit("BossRigs.luau has no AsuraBoss_GrandmasterShen_P%d" % phase)
        found = {m[0]: (m[1], tuple(float(x) for x in m[2].split(","))) for m in re.findall(r'Bone = "(\w+)", Parent = "(\w+)",(?: Motor = "\w+",)? At = V\(([^)]*)\)', block.group(1))}
        wanted = {b: (v[0], tuple(v[1])) for b, v in {**R.JOINT[phase], **R.HELPER[phase]}.items()}
        if found != wanted:
            raise SystemExit("BossRigs.luau and rigdef.py disagree in P%d: %s" % (phase, ", ".join(sorted(k for k in set(found) | set(wanted) if found.get(k) != wanted.get(k)))))


def validate(clip, baked):
    rg = clip.rig
    w = {"arm_reach": 0.0, "left_grip": 0.0, "left_reach": 0.0, "leg_reach": 0.0, "lowest": 9.0, "weapon_low": 9.0, "planted_slide": 0.0, "weapon_through_head": 0.0, "weapon_through_chest": 0.0, "left_off_haft": 0.0, "loop_seam_deg": 0.0}
    problems = []
    last_feet = {}
    for t, local, world, diag, c in baked:
        for k in ("arm_reach", "left_grip", "left_reach", "leg_reach"):
            w[k] = max(w[k], diag.get(k, 0.0))
        if not clip.airborne:
            for name in ("RightFoot", "LeftFoot"):
                w["lowest"] = min(w["lowest"], float(place(rg, world, name)[:, 1].min()))
            w["weapon_low"] = min(w["weapon_low"], float(place(rg, world, "Weapon")[:, 1].min()))
        for side, key in (("Right", "rf"), ("Left", "lf")):
            A = (world[side + "Foot"] @ np.append(rg.JOINT[side + "Foot"], 1))[:3]
            flat = float(c[key][2]) <= 1e-6 and c.get(key + "_heel", 0.0) < 0.5
            prev = last_feet.get(side)
            if prev is not None and flat and prev[1] and not any(a <= t <= b for a, b in clip.feet_free):
                w["planted_slide"] = max(w["planted_slide"], float(np.linalg.norm((A - prev[0])[[0, 2]]) * FPS))
            last_feet[side] = (A, flat)
        wp = place(rg, world, "Weapon")[::5]
        head = (world["Head"] @ np.append(rg.JOINT["Head"] + (0, 0.5, 0), 1))[:3]
        w["weapon_through_head"] = max(w["weapon_through_head"], float(0.42 - np.linalg.norm(wp - head, axis=1).min()))
        chest = (world["UpperTorso"] @ np.append(rg.JOINT["UpperTorso"] + (0, 0.5, 0), 1))[:3]
        w["weapon_through_chest"] = max(w["weapon_through_chest"], float(0.4 - np.linalg.norm(wp - chest, axis=1).min()))
        if c["lhw"] >= 0.99 and c["lhw"] >= c["ltw"]:
            palm = (world["LeftHand"] @ np.append(rg.PALM0, 1))[:3]
            grip = (world["RightHand"] @ np.append(rg.GRIP0, 1))[:3]
            ax = unit(c["haft"])
            d = palm - grip
            w["left_off_haft"] = max(w["left_off_haft"], float(np.linalg.norm(d - ax * np.dot(d, ax))))
    if w["arm_reach"] > 0.3:
        problems.append("right hand short by %.2f" % w["arm_reach"])
    if w["left_grip"] > 0.3:
        problems.append("left hand short of the haft by %.2f" % w["left_grip"])
    if w["left_reach"] > 0.25:
        problems.append("left reach short by %.2f" % w["left_reach"])
    if w["leg_reach"] > 0.12:
        problems.append("leg short of its foot by %.2f" % w["leg_reach"])
    if w["lowest"] < GROUND - 0.1 and w["lowest"] < 9:
        problems.append("feet %.2f below ground" % (GROUND - w["lowest"]))
    if not clip.scrape and w["weapon_low"] < GROUND - 0.05 and w["weapon_low"] < 9:
        problems.append("blade %.2f below ground" % (GROUND - w["weapon_low"]))
    if w["planted_slide"] > 1.0:
        problems.append("planted foot slides %.2f rig/s" % w["planted_slide"])
    if w["weapon_through_head"] > 0.1:
        problems.append("weapon %.2f through his head" % w["weapon_through_head"])
    if w["weapon_through_chest"] > 0.18:
        problems.append("weapon %.2f through his chest" % w["weapon_through_chest"])
    if w["left_off_haft"] > 0.2:
        problems.append("left hand %.2f off the haft" % w["left_off_haft"])
    if clip.loop:
        a, b = baked[0][1], baked[-1][1]
        w["loop_seam_deg"] = round(max(ZR.angle_of(a[p][:3, :3].T @ b[p][:3, :3]) for p in rg.ALL), 2)
        if w["loop_seam_deg"] > 3.0:
            problems.append("loop seam %.1f deg" % w["loop_seam_deg"])
    if clip.active is not None:
        start, length, arc, reach, lunge = clip.active
        times = [b[0] for b in baked]
        ifirst = int(np.argmin([abs(x - start) for x in times]))
        ilast = int(np.argmin([abs(x - (start + length)) for x in times]))
        p0, r0, yaw0 = blow(rg, baked[ifirst][2])
        p1, r1, yaw1 = blow(rg, baked[ilast][2])
        best = max(blow(rg, baked[i][2])[1] for i in range(ifirst, ilast + 1))
        s = {"contact": [round(float(x), 2) for x in p0], "game_radius_at_contact": round(r0 * SCALE, 2), "game_radius_during_active": round(best * SCALE, 2), "server_reach": reach, "reach_gap": round(reach - best * SCALE, 2),
             "yaw_first": round(yaw0, 1), "yaw_last": round(yaw1, 1)}
        if best * SCALE < BODY_MET - 0.5:
            problems.append("blow lands %.1f studs out; the body is met at %.1f" % (best * SCALE, BODY_MET))
        if arc > 40 and arc < 300:
            s["sweep_deg"] = round(yaw1 - yaw0, 1)
            if yaw1 - yaw0 < min(arc * 0.45, 90):
                problems.append("sweeps %.0f deg left to right; the server fans %d" % (yaw1 - yaw0, arc))
        w["strike"] = s
    return w, problems
