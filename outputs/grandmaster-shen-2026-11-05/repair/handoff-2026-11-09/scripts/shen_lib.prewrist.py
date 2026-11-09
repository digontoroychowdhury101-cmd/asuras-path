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
SLIDE_FLOOR = 0.95       # carrying and guarding: nearest the solver slides a keyed lead hand to the fist when its spot is out of reach (was 0.5: the grip collapsed to one hand)
PROTRACT = 0.25         # rig units a shoulder joint may glide toward its hand (scapular protraction, about 8 cm at his scale); the skinned shoulder stretches with it
SLIDE_FLOOR_CUT = 0.85   # in an attack the lead hand may slide further down the haft on a follow-through it cannot follow, a real grip slide
HAND_SPACING_MIN = 0.8   # rig units between the right fist and the left palm along the haft; shoulder width is 1.44
TOE_OUT = 9.0      # degrees a relaxed human foot turns out from the line of travel
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
    # the hinge's axis, from the whole limb: it holds steady even when the joint is folded tight and a bone lies along the pole
    hinge = unit(np.cross(axis, orth(pole1, axis)))

    def framed(bone):
        x = unit(bone)
        y = unit(np.cross(hinge, x))
        return np.column_stack((x, y, np.cross(x, y)))

    return framed(M - S) @ frame3(u0, pole0).T, framed(W - M) @ frame3(l0, pole0).T, W


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
        self.PALM0 = np.array(J.LHAND, float)     # set from the hand itself below, once the samples are loaded
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
        hand = R.left_hand(J, self.samples["LeftHand"])
        self.PALM0 = hand[6]
        self.LHAND_ACROSS = hand[2]
        J_ = self.JOINT
        self.ARM_U, self.ARM_L = J_["RightLowerArm"] - J_["RightUpperArm"], J_["RightHand"] - J_["RightLowerArm"]
        self.ELBOW0 = pole_of(J_["RightUpperArm"], J_["RightLowerArm"], J_["RightHand"])
        self.LARM_U, self.LARM_L = J_["LeftLowerArm"] - J_["LeftUpperArm"], J_["LeftHand"] - J_["LeftLowerArm"]
        self.LELBOW0 = pole_of(J_["LeftUpperArm"], J_["LeftLowerArm"], J_["LeftHand"])
        self.LEGS = {}
        centre = J_["LowerTorso"][0]
        for side in ("Left", "Right"):
            h, k, a = J_[side + "UpperLeg"], J_[side + "LowerLeg"], J_[side + "Foot"]
            sign = 1.0 if side == "Right" else -1.0
            # the sculpt stands in a wide A-frame with its toes turned far out. Every clip works from a body's own stance instead: ankles under the hips, feet toed out a few degrees, the knee over the foot.
            f = self.samples[side + "Foot"]
            low = f[f[:, 1] < f[:, 1].min() + 0.25][:, [0, 2]]
            axis = np.linalg.svd(low - low.mean(0))[2][0]
            axis = -axis if axis[1] > 0 else axis
            psi = math.atan2(axis[0], -axis[1])                      # + toes toward +x
            forward = np.array([math.sin(psi), 0.0, -math.cos(psi)])
            u, l = k - h, a - k
            ankle = np.array([h[0] + sign * 0.07, a[1], h[2] + 0.1])
            self.LEGS[side] = {"u": u, "l": l, "pole": orth(forward, unit(u)), "ankle": ankle, "sculpt": a, "straight": ry(psi), "out": -sign * TOE_OUT, "reach": float(np.linalg.norm(u) + np.linalg.norm(l))}
        self.PELVIS_UP = 0.0
        s = (w - self.GRIP0) @ self.HAFT0
        self.SMIN, self.SMAX = float(s.min()), float(s.max())
        self.LAX0 = unit(self.LHAND_ACROSS if self.LHAND_ACROSS @ np.array([0, 0, -1.0]) > 0 else -self.LHAND_ACROSS)     # the thumb's side: the fingers close about this line, so the haft lies along it
        self.REST = {
            "pel": (0.0, 0.0, 0.0), "pelR": (0.0, 0.0, 0.0), "chest": (0.0, 0.0, 0.0), "neck": (0.0, 0.0, 0.0),
            "rp": tuple(self.GRIP0), "rsl": 0.0, "haft": tuple(self.HAFT0), "face": tuple(self.FACE0), "relb": tuple(self.ELBOW0), "rlk": 0.0, "rhx": tuple(self.HAFT0),
            "lua": (0.0, 0.0, 0.0), "lfa": (0.0, 0.0, 0.0), "lha": (0.0, 0.0, 0.0), "lhw": 0.0, "lsl": 1.2, "ltw": 0.0, "lt": (-0.2, -1.2, -0.6), "lelb": (-0.5, -0.4, 0.7),
            "rf": (0.0, 0.0, 0.0, 0.0, 0.0), "lf": (0.0, 0.0, 0.0, 0.0, 0.0), "rknee": (0.0, 0.0, -1.0), "lknee": (0.0, 0.0, -1.0), "hov": 0.0,
            "rsw": 0.0, "lsw": 0.0,
        }

    def pivoted(self, W_parent, bone, L):
        j = self.JOINT[bone]
        return W_parent @ homog(None, j) @ L @ homog(None, -j)

    def hand_rotation(self, haft, face):
        """The weapon's frame: its own bind axes carried onto the keyed haft and edge."""
        return frame3(haft, face) @ frame3(self.HAFT0, self.FACE0).T

    def fist_rotation(self, axis, forearm, face):
        """The right fist on the haft: the haft runs through it the way the sculpt holds it, and it rolls about the haft to continue the forearm. The weapon may roll inside the fist; the hand never turns backwards on the arm."""
        v0 = orth(self.GRIP0 - self.JOINT["RightHand"], self.HAFT0)
        return frame3(axis, _across(forearm, axis, face)) @ frame3(self.HAFT0, v0).T

    def palm_rotation(self, axis, forearm, face):
        """The left hand on the haft: thumb side toward the blade, the back of the hand continuing the forearm."""
        v0 = orth(self.PALM0 - self.JOINT["LeftHand"], self.LAX0)
        return frame3(axis, _across(forearm, axis, face)) @ frame3(self.LAX0, v0).T


def short_arc(a, b):
    """The smallest rotation taking direction a onto direction b."""
    a, b = unit(a), unit(b)
    v = np.cross(a, b)
    n = float(np.linalg.norm(v))
    if n < 1e-6:
        return np.eye(3) if a @ b > 0 else rodrigues(orth(np.array([0.3, 1.0, 0.2]), a) * math.pi)
    return rodrigues(v / n * math.atan2(n, float(a @ b)))


ROLL_LIMIT = 85.0


def best_roll(a0, a, f, hint):
    """The forearm roll, degrees, that brings the fist's axis nearest the haft. A haft nearly along the forearm asks nothing of the roll; beyond the limit it stays on the side it was already on."""
    p, q = a0 - f * (a0 @ f), a - f * (a @ f)
    want = math.degrees(math.atan2(float(f @ np.cross(p, q)), float(p @ q)))
    want = hint + ((want - hint + 180.0) % 360.0 - 180.0)
    weight = min(float(np.linalg.norm(p) * np.linalg.norm(q)) / 0.35, 1.0)
    return float(np.clip(hint + (want - hint) * weight, -ROLL_LIMIT, ROLL_LIMIT))


def _across(forearm, axis, fallback):
    """The forearm's direction across the haft; a forearm running along the haft has none, so the edge's direction stands in."""
    f = np.asarray(forearm, float)
    a = np.asarray(axis, float)
    p = f - a * np.dot(f, a)
    n = float(np.linalg.norm(p))
    b = np.asarray(fallback, float)
    q = b - a * np.dot(b, a)
    q = q / max(float(np.linalg.norm(q)), 1e-6)
    w = min(n / 0.35, 1.0)
    out = p / max(n, 1e-6) * w + q * (1 - w)
    return out / max(float(np.linalg.norm(out)), 1e-6)


DIRECTION = {"haft", "face", "relb", "rknee", "lknee", "lelb", "rhx"}
FEET = {"rf", "lf"}
EASE = {
    "lin": lambda u: u, "in": lambda u: u * u, "out": lambda u: 1 - (1 - u) * (1 - u), "io": lambda u: u * u * (3 - 2 * u),
    "snap": lambda u: 1 - (1 - u) ** 3, "whip": lambda u: u * u * u,
}


class Clip:
    rise_guard = False
    """Timed partial control keys, Catmull-Rom between them; a channel a key omits holds through. Phase 2's corruption (lower, forward, more torque) is a layer over the shared technique."""

    def __init__(self, rig, name, length, keys, loop=False, priority="Action", contacts=(), move=None, notes="", active=None, slot="", feet_free=(), corrupt=True, scrape=False, airborne=False, authored_feet=False, raw_after=None, hover=0.0):
        self.rig = rig
        self._side = None   # solve(): which side of each torso part the haft was on last frame, during a sweep through the clip in order
        self.hover = float(hover)   # phase 2 floats: the height this clip holds when it does not key `hov` itself
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
        c["lhw"], c["ltw"], c["rlk"] = [float(np.clip(c[k], 0, 1)) for k in ("lhw", "ltw", "rlk")]
        keyed = any("hov" in k[1] for k in self.keys)
        hov = float(c["hov"]) if keyed else self.hover
        if hov > 0.0:   # levitation carries the whole body and the weapon; the legs hang from it, toes down, one knee softer than the other
            cycles = max(1, round(self.length / 2.4))
            bob = 0.09 * math.sin(2 * math.pi * cycles * t / self.length) * min(hov / 0.6, 1.0)
            if not self.loop:
                bob *= smooth01(t / 0.2) * (1 - smooth01((t - (self.length - 0.2)) / 0.2))
            hang = min(hov / 0.6, 1.0)
            h = hov + bob
            c["pel"] = c["pel"] + np.array([0, h, 0])
            c["rp"] = c["rp"] + np.array([0, h, 0])
            for key, drop, toes in (("rf", 0.14, -40), ("lf", 0.04, -32)):   # the legs hang nearly straight from the hips, not knelt on the air
                f = np.array(c[key], float)
                f[1] *= 1 - 0.65 * hang
                f[3] *= 1 - 0.6 * hang
                c[key] = f + np.array([0, 0, h + drop * hang, 0, toes * hang])
        if self.corrupt:  # the same technique, predatory: lower, forward, the torso wound further against the hips
            c["pel"] = c["pel"] + np.array([0, -0.1, -0.03])
            c["pelR"] = c["pelR"] * np.array([1, 1.18, 1]) + np.array([6.0, 0, 0])
            c["chest"] = c["chest"] * np.array([1, 1.28, 1]) + np.array([8.0, 0, 0])
            c["neck"] = c["neck"] + np.array([20.0, 0, 0])   # the torso hunches; the head stays up, glaring out from under the brows
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

    def clear_body(self, rp, haft, rsl, world):
        """The weapon never passes through his torso or head: the whole weapon shifts sideways off them, hands with it."""
        rg = self.rig
        J = rg.JOINT
        Wc, Wp, Wh = world["UpperTorso"], world["LowerTorso"], world["Head"]
        caps = [(Wc @ np.append(J["UpperTorso"] + (0, 0.1, 0), 1), Wc @ np.append(J["Head"] + (0, -0.25, 0), 1), 0.66, None), (Wp @ np.append(J["LowerTorso"] + (0, -0.5, 0), 1), Wp @ np.append(J["UpperTorso"], 1), 0.62, None),
                (Wh @ np.append(J["Head"] + (0, 0.3, 0), 1), Wh @ np.append(J["Head"] + (0, 0.65, 0), 1), 0.5, None)]
        ss = np.linspace(rg.SMIN - rsl, rg.SMAX - rsl, 26)
        for _ in range(3):
            pts = rp + np.outer(ss, haft)
            worst, push = 0.0, None
            side_now = None
            for ci, (A, B, r, out) in enumerate(caps):
                A, B = A[:3], B[:3]
                d = B - A
                u = np.clip((pts - A) @ d / max(float(d @ d), 1e-6), 0, 1)
                near = A + np.outer(u, d)
                gap = pts - near
                dist = np.linalg.norm(gap, axis=1)
                i = int(np.argmin(dist))
                if r - dist[i] > worst:
                    worst = r - float(dist[i])
                    g = gap[i] - haft * float(gap[i] @ haft)
                    n = float(np.linalg.norm(g))
                    push = g / n if n > 1e-4 else np.array([1.0, 0, 0])
                    prev = self._side.get(ci) if self._side is not None else None
                    # (2026-11-06) the haft cannot pass through him: the same stretch of it stays on the side it was on last frame, or the hands jump across
                    if r + float(dist[i]) < 0.9 and prev is not None and abs(float(ss[i]) - prev[1]) < 0.8 and float(push @ prev[0]) < 0 and dist[i] < 0.5 * r:
                        alt = prev[0] - haft * float(prev[0] @ haft)
                        push = alt / max(float(np.linalg.norm(alt)), 1e-6)
                        worst = r + float(dist[i])
                    side_now = (ci, (push, float(ss[i])))
            if push is None:
                break
            if self._side is not None and side_now is not None:
                self._side[side_now[0]] = side_now[1]
            rp = rp + push * (worst + 0.02)
        if self._side is not None:     # remember which side of each body part the haft is on, penetrating or not
            pts = rp + np.outer(ss, haft)
            for ci, (A, B, r, out) in enumerate(caps):
                A, B = A[:3], B[:3]
                d = B - A
                u = np.clip((pts - A) @ d / max(float(d @ d), 1e-6), 0, 1)
                gap = pts - (A + np.outer(u, d))
                dist = np.linalg.norm(gap, axis=1)
                i = int(np.argmin(dist))
                if dist[i] < r + 0.35:
                    g = gap[i] - haft * float(gap[i] @ haft)
                    if float(np.linalg.norm(g)) > 1e-4:
                        self._side[ci] = (g / float(np.linalg.norm(g)), float(ss[i]))
                else:
                    self._side.pop(ci, None)
        return rp

    def arm(self, S, grip, axis, axis0, v0_len, pole_key, hand, u0, l0, pole0, label, diag, roll=None):
        """How an arm really holds a haft. The elbow is a hinge, the forearm rolls about itself (pronation, carried by the lower arm bone), and the wrist only makes up what remains: the fist never turns backwards on the arm.
        `hand` is the fist's turn, chosen across the whole clip by swivel(); its axis is laid on the haft, the arm goes exactly to it, and the forearm takes all the twist it can."""
        Rh = short_arc(axis0, axis) if hand is None else short_arc(hand @ axis0, axis) @ hand
        wrist = grip - Rh @ v0_len
        ru, rl, reached = two_bone(S, wrist, u0, l0, pole0, unit(pole_key), label, diag)
        elbow = S + ru @ u0
        f = unit(reached - elbow)
        phi = float(np.clip(twist_about(Rh @ rl.T, f), -ROLL_LIMIT, ROLL_LIMIT)) if roll is None else float(roll)
        rr = rodrigues(f * math.radians(phi)) @ rl
        return Rh, ru, rr, reached, elbow, phi

    def solve(self, c, auto_swivel=False):
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
        # the weapon first: the hands go to it. `rp` is where the right hand holds it, `rsl` where on the haft that is
        haft, face = unit(c["haft"]), unit(c["face"])
        rsl = float(c["rsl"])
        S = (world["UpperTorso"] @ np.append(rg.JOINT["RightUpperArm"], 1))[:3]
        rp = self.clear_body(np.asarray(c["rp"], float), haft, rsl, world)
        arm_len = float(np.linalg.norm(rg.ARM_U) + np.linalg.norm(rg.ARM_L)) + 0.06
        away = rp - S
        far = float(np.linalg.norm(away))
        rpro = np.zeros(3)
        if far > arm_len:   # (2026-11-06) the right shoulder blade glides toward a fist out of reach first, up to PROTRACT
            rpro = unit(away * np.array([1.0, 0.5, 1.0])) * min(far - arm_len, PROTRACT)
            S = S + rpro
            away = rp - S
            far = float(np.linalg.norm(away))
        if far > arm_len:   # past the reach of the arm the whole weapon comes in; it never leaves the hand
            rp = S + away * (arm_len / far)
        origin = rp - haft * rsl      # the haft point the sculpt's fist held
        haft, face = self.clear_floor(origin, haft, face)
        rp = origin + haft * rsl
        # the lead hand slides on the haft: a keyed spot out of reach slips toward the shoulder, and what is still out of reach brings the whole weapon across to it
        SL = (world["UpperTorso"] @ np.append(rg.JOINT["LeftUpperArm"], 1))[:3]
        lpro = np.zeros(3)
        c["_lgap"] = 0.0
        hold, reach = c["lhw"], c["ltw"]
        v_l = rg.PALM0 - rg.JOINT["LeftHand"]
        sl = float(c["lsl"])
        maxr = 9.0
        if hold > 0 and hold >= reach:
            maxr = float(np.linalg.norm(rg.LARM_U) + np.linalg.norm(rg.LARM_L)) * 0.98 + float(np.linalg.norm(v_l)) * 0.8
            # (2026-11-06) the shoulder blade glides: before the hand gives up its spot, the shoulder itself comes forward toward it (protraction), up to PROTRACT
            want = rp + haft * sl - SL
            gap = float(np.linalg.norm(want)) - maxr
            if gap > 0:
                lpro = unit(want * np.array([1.0, 0.5, 1.0])) * min(gap, PROTRACT)
                SL = SL + lpro
            c["_lgap"] = max(float(np.linalg.norm(rp + haft * sl - SL)) - maxr, 0.0)
            floor = SLIDE_FLOOR if self.priority in ("Idle", "Movement") else SLIDE_FLOOR_CUT
            near = float(np.clip(np.dot(SL - rp, haft), min(floor, sl), sl))     # (2026-11-06) the lead hand may slide in only to the floor; past that the weapon comes to it
            for _ in range(14):
                if np.linalg.norm(rp + haft * sl - SL) <= maxr:
                    break
                sl += (near - sl) * 0.35
        for _ in range(8):      # both hands must reach: what the right arm cannot hold the weapon gives up, and the left the same
            away = rp - S
            far = float(np.linalg.norm(away))
            if far > arm_len:
                rp = S + away * (arm_len / far)
            if hold > 0 and hold >= reach:
                on = rp + haft * sl
                gap = float(np.linalg.norm(on - SL)) - maxr
                if gap > 0:
                    rp = rp + unit(SL - on) * gap * hold * hold
        away = rp - S
        far = float(np.linalg.norm(away))
        if far > arm_len:
            rp = S + away * (arm_len / far)
        if far < 0.6:     # an elbow only folds so far: a hand never comes in to the shoulder, the weapon stays out with it
            rp = S + unit(away if far > 1e-3 else np.array([0.0, -0.5, -1.0])) * 0.6
        rp = self.clear_body(rp, haft, rsl, world)     # (2026-11-06) bringing the weapon to the lead hand may carry the haft into him: clear it again
        origin = rp - haft * rsl
        haft, face = self.clear_floor(origin, haft, face)      # the reach may have carried the weapon down: the blade still never goes through the ground
        rp = origin + haft * rsl
        c["haft"], c["face"], c["rp"] = haft, face, rp
        Rw = rg.hand_rotation(haft, face)
        W = homog(Rw, origin - Rw @ rg.GRIP0)
        world["Glaive"] = W
        j = rg.JOINT["Glaive"]
        local["Glaive"] = homog(None, -j) @ np.linalg.inv(world[rg.PARENT["Glaive"]]) @ W @ homog(None, j)
        # the right arm. During a pinwheel the fist keeps its own axis while the haft turns on the fingers
        lock = float(c["rlk"])
        axis = unit(haft + (unit(c["rhx"]) - haft) * lock) if lock > 0 else haft
        v_r = rg.GRIP0 - rg.JOINT["RightHand"]
        core = (world["UpperTorso"] @ np.append(rg.JOINT["UpperTorso"] + (0, 0.4, 0), 1))[:3]
        c["_rgrip"] = (S, rp, axis, core)
        Rh, ru, rl, _, elbow, c["_rroll"] = self.arm(S, rp, axis, rg.HAFT0, v_r, c.get("rpole", c["relb"]), c.get("rhand"), rg.ARM_U, rg.ARM_L, rg.ELBOW0, "arm_reach", diag, c.get("rpole_roll"))
        local["RightUpperArm"] = homog(Rch.T @ ru, Rch.T @ rpro)
        world["RightUpperArm"] = rg.pivoted(world["UpperTorso"], "RightUpperArm", local["RightUpperArm"])
        local["RightLowerArm"] = homog(ru.T @ rl)
        world["RightLowerArm"] = rg.pivoted(world["RightUpperArm"], "RightLowerArm", local["RightLowerArm"])
        local["RightHand"] = homog(rl.T @ Rh)
        world["RightHand"] = rg.pivoted(world["RightLowerArm"], "RightHand", local["RightHand"])
        # the left arm: on the haft, reaching for a point, or free; blended, so it can leave and rejoin the weapon in a move
        Su, Sf = Rch @ euler(c["lua"]), Rch @ euler(c["lfa"])
        Sh = Sf @ euler(c["lha"])
        if hold > 0 or reach > 0:
            if hold >= reach:
                on = rp + haft * sl
                if hold > 0.5:
                    c["_lgrip"] = (SL, on, haft, core)
                Rp, u_ik, f_ik, _, _, c["_lroll"] = self.arm(SL, on, haft, rg.LAX0, v_l, c.get("lpole", c["lelb"]), c.get("lhand"), rg.LARM_U, rg.LARM_L, rg.LELBOW0, "left_grip", scratch := {}, c.get("lpole_roll"))
                c["_lsl"] = sl
                w = hold
                self_label = "left_grip"
            else:
                target = SL + np.asarray(c["lt"], float)
                scratch = {}
                u_ik, f_ik, _ = two_bone(SL, target, rg.LARM_U, rg.LARM_L, rg.LELBOW0, unit(c["lelb"]), "left_reach", scratch)
                Rp = f_ik @ euler(c["lha"])
                w = reach
                self_label = "left_reach"
            diag[self_label] = max(diag.get(self_label, 0.0), scratch[self_label] * w * w)   # a hand on its way to the haft is not yet expected there
            Su = ZR.mat(ZR.slerp(ZR.quat(Su), ZR.quat(u_ik), w))
            Sf = ZR.mat(ZR.slerp(ZR.quat(Sf), ZR.quat(f_ik), w))
            Sh = ZR.mat(ZR.slerp(ZR.quat(Sh), ZR.quat(Rp), w))
        local["LeftUpperArm"] = homog(Rch.T @ Su, Rch.T @ lpro)
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
            Yaw = ry(math.radians(yaw + leg["out"]))
            # a leg reaching its limit rolls up onto the ball of the foot rather than pulling the foot along or locking straight
            c[key + "_heel"] = 0.0
            if lift < 0.2 and not clip_airborne(self):
                reach = float(np.linalg.norm(H - A)) / leg["reach"]
                k = min(max((reach - 0.985) / 0.04, 0.0), 1.0)
                if k > 0 and pitch > -5:
                    th = k * k * (3 - 2 * k) * 36.0
                    up, fwd = foot_roll(-th)
                    A = A + np.array([0, up, 0]) + (Yaw @ np.array([0, 0, -1.0])) * fwd
                    pitch = pitch - th
                    c[key + "_heel"] = th
            Rfoot = Yaw @ rx(math.radians(pitch)) @ leg["straight"]
            ru_, rl_, _ = two_bone(H, A, leg["u"], leg["l"], leg["pole"], Yaw @ unit(c[pole]), "leg_reach", diag)
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
        spine_reach(self, ctrl)
        settle(self, ctrl)
        swivel(self, ctrl)
        out = []
        self._side = {}
        for t, c in zip(times, ctrl):
            local, world, diag = self.solve(c)
            out.append([t, local, world, diag, c])
        self._side = None
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
    if not clip.authored_feet and not clip.hover and not any("hov" in k[1] for k in clip.keys):
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


def twist_about(A, f):
    """How far rotation A turns about unit axis f: its nearest rotation about f, degrees."""
    v = np.array([A[2, 1] - A[1, 2], A[0, 2] - A[2, 0], A[1, 0] - A[0, 1]])
    return math.degrees(math.atan2(float(f @ v), float(np.trace(A) - f @ A @ f)))


WRIST_LIMITS = (20.0, 75.0, 30.0)     # (2026-11-06) residual twist, flexion/extension, radial/ulnar deviation (deg) a wrist can show before the hand leaves its sleeve cuff


def rotvec(R):
    """Axis times angle (radians) of a rotation matrix."""
    ang = math.acos(float(np.clip((np.trace(R) - 1.0) / 2.0, -1.0, 1.0)))
    v = np.array([R[2, 1] - R[1, 2], R[0, 2] - R[2, 0], R[1, 0] - R[0, 1]])
    n = float(np.linalg.norm(v))
    if n < 1e-9:
        if ang < 1e-6:
            return np.zeros(3)
        w, V = np.linalg.eigh((R + R.T) / 2.0)   # a half turn: the axis is the eigenvector of +1
        return V[:, int(np.argmax(w))] * ang
    return v / n * ang


def wrist_frame(rig, side):
    """The wrist's anatomical axes in rest rig space: forearm, across the palm (flexion axis), palm normal (deviation axis)."""
    f = unit(rig.JOINT[side + "Hand"] - rig.JOINT[side + "LowerArm"])
    across = rig.LAX0 if side == "Left" else rig.HAFT0
    a = unit(across - f * float(across @ f))
    return f, a, np.cross(f, a)


def wrist_parts(rig, R, side):
    """(twist, flex, dev) in degrees of a hand's rotation R on its forearm (both rest-relative)."""
    f, a, nrm = wrist_frame(rig, side)
    tw = twist_about(R, f)
    sw = R @ rodrigues(f * -math.radians(tw))
    v = np.degrees(rotvec(sw))
    return float(tw), float(v @ a), float(v @ nrm)


def wrist_excess(rig, R, side):
    """Degrees past WRIST_LIMITS on the worst axis (0 inside the range)."""
    p = wrist_parts(rig, R, side)
    return max(0.0, *(abs(x) - lim for x, lim in zip(p, WRIST_LIMITS)))


GRIP_TURNS = np.radians(np.arange(16) * 22.5)
ELBOW_TURNS = np.arange(14) * 360.0 / 14


def smooth_hold(Q, loop):
    """A hand turning on the haft and an elbow finding its place are slow things: they are never allowed to flick."""
    n = len(Q)
    out = np.zeros_like(Q)
    for i in range(n):
        q = np.zeros(4)
        for off, w in ((-2, 1.0), (-1, 2.0), (0, 3.0), (1, 2.0), (2, 1.0)):
            k = i + off
            if loop:
                k = k % (n - 1)
            else:
                k = min(max(k, 0), n - 1)
            q = q + w * (Q[k] if Q[k] @ Q[i] >= 0 else -Q[k])
        out[i] = q / np.linalg.norm(q)
    return out


SPINE_YAW, SPINE_PITCH = 25.0, 14.0    # degrees the chest may turn and bow beyond its keys to carry the lead hand to its spot


def spine_reach(clip, ctrl, sigma=2.0, passes=2):
    """(2026-11-06) The whole body reaches, not just the arm. Where the lead hand's keyed spot on the haft is still out of reach after the shoulder blade
    glides (solve: PROTRACT), the chest turns and bows into it by as much as closes the gap (a finite-difference step on the remaining gap), smoothed
    across neighbouring frames so the trunk flows into the reach; the head turns back by most of it to keep his eyes on the target."""
    n = len(ctrl)
    if n < 2:
        return
    k = np.arange(-int(3 * sigma), int(3 * sigma) + 1)
    w = np.exp(-0.5 * (k / sigma) ** 2)
    w /= w.sum()

    def gap(c, dyaw=0.0, dpitch=0.0):
        t2 = dict(c)
        ch = tuple(c["chest"])
        t2["chest"] = (ch[0] + dpitch, ch[1] + dyaw, ch[2])
        clip.solve(t2)
        return float(t2.get("_lgap", 0.0))

    for _ in range(passes):
        add = np.zeros((n, 2))
        for i, c in enumerate(ctrl):
            g0 = gap(c)
            if g0 < 1e-3:
                continue
            gy = (gap(c, dyaw=3.0) - gap(c, dyaw=-3.0)) / 6.0
            gp = (gap(c, dpitch=3.0) - gap(c, dpitch=-3.0)) / 6.0
            norm = gy * gy + gp * gp
            if norm < 1e-8:
                continue
            add[i] = (-g0 * gy / norm, -g0 * gp / norm)
        if not add.any():
            return
        smooth = np.zeros_like(add)
        for j, kk in enumerate(k):
            idx = np.arange(n) + kk
            idx = idx % n if clip.loop else np.clip(idx, 0, n - 1)
            smooth += w[j] * add[idx]
        for i, c in enumerate(ctrl):
            dy = float(np.clip(smooth[i, 0], -SPINE_YAW, SPINE_YAW))
            dp = float(np.clip(smooth[i, 1], -SPINE_PITCH, SPINE_PITCH))
            if abs(dy) + abs(dp) < 1e-3:
                continue
            ch, nk = tuple(c["chest"]), tuple(c["neck"])
            c["chest"] = (ch[0] + dp, ch[1] + dy, ch[2])
            c["neck"] = (nk[0] - dp * 0.8, nk[1] - dy * 0.9, nk[2])


def settle(clip, ctrl, sigma=2.0, passes=2):
    """(2026-11-06) The solver's own corrections, spread over time. Where an authored pose cannot be held (the lead hand out of reach, the haft into his
    body), solve() moves the weapon on that frame alone, so a correction that switches on between two frames made the hands jump up to 1.4 rig units in
    one frame. Here each frame's correction is measured, smoothed across neighbouring frames and written back into the keyed grip, so the solver meets a
    path it can already hold and the hands ease into and out of the fix. Contacts keep their times; the blade at a contact moves only by the smoothed fix."""
    n = len(ctrl)
    if n < 3:
        return
    k = np.arange(-int(3 * sigma), int(3 * sigma) + 1)
    w = np.exp(-0.5 * (k / sigma) ** 2)
    w /= w.sum()
    for _ in range(passes):
        delta = np.zeros((n, 3))
        clip._side = {}
        for i, c in enumerate(ctrl):
            t2 = dict(c)
            clip.solve(t2)
            delta[i] = np.asarray(t2["rp"], float) - np.asarray(c["rp"], float)
        clip._side = None
        if float(np.abs(delta).max()) < 1e-3:
            return
        smooth = np.zeros_like(delta)
        for j, kk in enumerate(k):
            idx = np.arange(n) + kk
            idx = idx % n if clip.loop else np.clip(idx, 0, n - 1)
            smooth += w[j] * delta[idx]
        for i, c in enumerate(ctrl):
            c["rp"] = tuple(np.asarray(c["rp"], float) + smooth[i])


def swivel(clip, ctrl):
    """How both arms hold the weapon across the whole clip. A hand on a haft has two free things: how far the fist has turned round the haft, and where the elbow sits about the shoulder-wrist line. Every combination is tried on every frame, and the one path through the clip that keeps the wrists least bent while moving the least is chosen at once, then smoothed. There is no iteration to fall on a wrong answer, so the arm cannot flick."""
    rg = clip.rig
    n = len(ctrl)
    if n == 0:
        return
    needs = []
    clip._side = {}
    for c in ctrl:
        t2 = dict(c)
        clip.solve(t2)
        needs.append(t2)
    clip._side = None
    arms = (("rpole", "rhand", "_rgrip", rg.HAFT0, rg.GRIP0 - rg.JOINT["RightHand"], "relb", rg.ARM_U, rg.ARM_L, rg.ELBOW0),
            ("lpole", "lhand", "_lgrip", rg.LAX0, rg.PALM0 - rg.JOINT["LeftHand"], "lelb", rg.LARM_U, rg.LARM_L, rg.LELBOW0))
    G, E = len(GRIP_TURNS), len(ELBOW_TURNS)
    for key, hkey, gkey, axis0, v0, pole_key, u0, l0, pole0 in arms:
        live = [i for i in range(n) if gkey in needs[i]]
        if not live:
            continue
        costs = {}
        quats = {}
        hands = {}
        poles = {}
        twists = {}
        scratch = {}
        for i in live:
            S, grip, axis, core = needs[i][gkey]
            base = short_arc(axis0, axis)
            C = np.zeros((G, E))
            Qi = np.zeros((G, 4))
            Hi = []
            pole_base = unit(needs[i][pole_key])
            Pi = np.zeros((G, E, 3))
            Ti = np.zeros((G, E))
            for g, turn in enumerate(GRIP_TURNS):
                Rh = rodrigues(axis * turn) @ base
                Hi.append(Rh)
                Qi[g] = ZR.quat(Rh)
                wrist = grip - Rh @ v0
                d = unit(wrist - S)
                keyed = orth(pole_base, d)
                side = np.cross(d, keyed)
                for e, a in enumerate(ELBOW_TURNS):
                    scratch["x"] = 0.0
                    ar = math.radians(a)
                    pole = keyed * math.cos(ar) + side * math.sin(ar)
                    Pi[g, e] = pole
                    a = min(a, 360.0 - a)       # how far this elbow is from where the pose keys it
                    ru, rl, reached = two_bone(S, wrist, u0, l0, pole0, pole, "x", scratch)
                    elbow = S + ru @ u0
                    f = unit(reached - elbow)
                    A = Rh @ rl.T
                    phi = float(np.clip(twist_about(A, f), -ROLL_LIMIT, ROLL_LIMIT))
                    Ti[g, e] = phi
                    bend = ZR.angle_of(rodrigues(f * math.radians(phi)).T @ A)
                    inside = max(0.0, 0.85 - float(np.hypot(*(elbow - core)[[0, 2]])))      # an elbow never buries itself in his ribs
                    C[g, e] = bend + 0.3 * max(0.0, bend - 55.0) + 1.6 * max(0.0, bend - 85.0) + 0.1 * abs(a) + 0.08 * abs(phi) + 90.0 * inside + 200.0 * scratch["x"]
            costs[i], quats[i], hands[i], poles[i], twists[i] = C, Qi, Hi, Pi, Ti

        def walk(fixed=None):
            """Every state to every state: the fist's real turn, the elbow's real travel and the forearm's roll all cost what they move, so nothing whips round for one frame."""
            total = costs[live[0]].ravel().copy()
            if fixed is not None:
                pin = np.full_like(total, 1e7)
                pin[fixed[0] * E + fixed[1]] = 0.0
                total = total + pin
            back = {}
            for p, i in zip(live, live[1:]):
                Tg = np.degrees(2 * np.arccos(np.abs(quats[p] @ quats[i].T).clip(0.0, 1.0)))
                pa, pb = poles[p].reshape(-1, 3), poles[i].reshape(-1, 3)
                Te = np.degrees(np.arccos(np.clip(pa @ pb.T, -1.0, 1.0)))
                Tr = np.abs(twists[p].ravel()[:, None] - twists[i].ravel()[None, :])
                step = total[:, None] + 0.4 * np.repeat(np.repeat(Tg, E, axis=0), E, axis=1) + 0.35 * Te + 0.35 * Tr + 600.0 * (Tr > 45.0) + 600.0 * (Te > 75.0)    # a forearm or elbow can't whip round in a frame, whatever the wrist would save
                back[i] = step.argmin(axis=0)
                total = step.min(axis=0) + costs[i].ravel()
                if fixed is not None and i == live[-1]:
                    pin = np.full_like(total, 1e7)
                    pin[fixed[0] * E + fixed[1]] = 0.0
                    total = total + pin
            at = int(total.argmin())
            path = {}
            for i in reversed(live):
                path[i] = (at // E, at % E)
                if i in back:
                    at = int(back[i][at])
            return path

        path = walk()
        if clip.loop and len(live) == n:
            path = walk(path[live[0]])
        Q = np.zeros((n, 4))
        el = np.zeros((n, 3))
        ro = np.zeros(n)
        for i in range(n):
            k = i if i in path else min(live, key=lambda q: abs(q - i))
            g, e = path[k]
            Q[i] = quats[k][g]
            el[i] = poles[k][g, e]
            ro[i] = twists[k][g, e]
        Q = smooth_hold(Q, clip.loop)
        kernel = np.array([1, 2, 3, 2, 1], float)
        kernel /= kernel.sum()
        for i, c in enumerate(ctrl):
            v = np.zeros(3)
            for off, w in zip(range(-2, 3), kernel):
                k = (i + off) % (n - 1) if clip.loop else min(max(i + off, 0), n - 1)
                v = v + w * el[k]
            c[key] = unit(v) if np.linalg.norm(v) > 1e-3 else el[i]
            c[hkey] = ZR.mat(Q[i])
            c[key + "_roll"] = float(sum(w * ro[(i + off) % (n - 1) if clip.loop else min(max(i + off, 0), n - 1)] for off, w in zip(range(-2, 3), kernel)))


def derive_helpers(clip, baked):
    """Nothing to derive: everything that hangs (robe, hair, beard, sleeves, the orbs) is skinned and simulated at run time; no clip keys it."""
    return


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


WRIST_LIMIT = 115.0   # past this a hand reads as facing the wrong way on the arm


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
            flat = float(c[key][2]) <= 1e-6 and c.get(key + "_heel", 0.0) < 0.5 and abs(float(c[key][4])) < 1.0
            prev = last_feet.get(side)
            if prev is not None and flat and prev[1] and not any(a <= t <= b for a, b in clip.feet_free):
                w["planted_slide"] = max(w["planted_slide"], float(np.linalg.norm((A - prev[0])[[0, 2]]) * FPS))
            last_feet[side] = (A, flat)
        wp = place(rg, world, "Weapon")[::5]
        head = (world["Head"] @ np.append(rg.JOINT["Head"] + (0, 0.5, 0), 1))[:3]
        w["weapon_through_head"] = max(w["weapon_through_head"], float(0.42 - np.linalg.norm(wp - head, axis=1).min()))
        chest = (world["UpperTorso"] @ np.append(rg.JOINT["UpperTorso"] + (0, 0.5, 0), 1))[:3]
        w["weapon_through_chest"] = max(w["weapon_through_chest"], float(0.4 - np.linalg.norm(wp - chest, axis=1).min()))
        w["wrist_right"] = max(w.get("wrist_right", 0.0), float(ZR.angle_of(local["RightHand"][:3, :3])))
        if c["lhw"] >= 0.99 and c["lhw"] >= c["ltw"]:
            palm = (world["LeftHand"] @ np.append(rg.PALM0, 1))[:3]
            ax = unit(c["haft"])
            d = palm - np.asarray(c["rp"], float)
            w["left_off_haft"] = max(w["left_off_haft"], float(np.linalg.norm(d - ax * np.dot(d, ax))))
            fist_ = (world["RightHand"] @ np.append(rg.GRIP0, 1))[:3]
            w["hand_spacing"] = round(min(w.get("hand_spacing", 9.0), float(np.dot(palm - fist_, ax))), 3)   # the solver slides an out-of-reach lead hand back toward the fist
            w["wrist_left"] = max(w.get("wrist_left", 0.0), float(ZR.angle_of(local["LeftHand"][:3, :3])))
        fist = (world["RightHand"] @ np.append(rg.GRIP0, 1))[:3]
        d = fist - np.asarray(c["rp"], float)
        w["right_off_haft"] = max(w.get("right_off_haft", 0.0), float(np.linalg.norm(d)))
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
    if clip.priority in ("Idle", "Movement") and w.get("hand_spacing", 9.0) < HAND_SPACING_MIN:   # carrying, guarding and moving are two-handed: bunched hands read as a one-handed carry
        problems.append("hands bunched %.2f apart on the haft" % w["hand_spacing"])
    if w["left_off_haft"] > 0.2:
        problems.append("left hand %.2f off the haft" % w["left_off_haft"])
    if w.get("right_off_haft", 0) > 0.25:
        problems.append("right hand %.2f off the haft" % w["right_off_haft"])
    for side in ("right", "left"):
        if w.get("wrist_" + side, 0) > WRIST_LIMIT:
            problems.append("%s wrist turned %.0f deg on the arm" % (side, w["wrist_" + side]))
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
