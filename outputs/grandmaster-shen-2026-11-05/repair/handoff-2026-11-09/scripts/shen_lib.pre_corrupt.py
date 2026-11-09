"""Grandmaster Shen's clip solver, one instance per form: forward kinematics about each sculpt's own joints, analytic limb IK, a true two-handed guandao, and baked cloth, hair, beard and bead motion.

Each form's rest pose is its sculpt (tools/blender/shen_import/rigdef.py): a zero Transform on every joint shows the model as designed. BossRigs.apply moves the rig attachments to these joints, rotations stay axis-aligned, so
    W[bone] = W[parent] * Translate(joint) * Transform * Translate(-joint)    (W maps a rest-pose point to clip space)
Clip space is HumanoidRootPart space at scale 1; the Animator scales translation with the Model. +X his right, +Y up, -Z his front.

Joint owners: the clip owns every joint. Secondary motion is derived here at bake time and exported as ordinary keyed joints; no script writes a joint at run time, so nothing fights the Animator.
Blade convention: `face` is the direction the cutting edge points, `haft` runs from butt to blade. rx(+a) swings a hanging limb toward his front.
"""
import json
import os
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


def handover_arm(S, u0, l0, pole0, A, B, m):
    """(2026-11-08) An arm part way between two solutions A and B (upper arm, forearm, hand rotations), m of the way to B: the wrist travels the
    straight line between their wrists and the elbow swings round the shoulder-wrist line from one's side to the other's, solved as one arm; each
    bone keeps the share of its own twist, and the hand its share of its bend at the wrist. Slerping the three rotations instead had no way round
    when the two elbows lay opposite (a lead hand leaving the haft for a reach: 95-178 deg apart), and the arm turned over inside a frame."""
    if m <= 0.0:
        return A
    if m >= 1.0:
        return B
    ends = []
    for u, f, H in (A, B):
        e = S + u @ u0
        w = e + f @ l0
        ends.append((e, w, orth(e - S, unit(w - S))))
    (eA, wA, pA), (eB, wB, pB) = ends
    # the wrist swings round the shoulder (its direction turning, its distance changing evenly), not straight across: the straight line passed 0.75
    # from the shoulder, the shoulder-wrist line swept round and the elbow's hinge with it (phase 2 Guandao_Heavy f16, the upper arm 170 deg in a frame)
    dA, dB = unit(wA - S), unit(wB - S)
    turn = np.cross(dA, dB)
    ang = math.atan2(float(np.linalg.norm(turn)), float(dA @ dB))
    d = rodrigues(unit(turn) * ang * m) @ dA if np.linalg.norm(turn) > 1e-6 else dA
    T = S + d * (float(np.linalg.norm(wA - S)) * (1.0 - m) + float(np.linalg.norm(wB - S)) * m)
    # the elbow goes the straight way between the two elbows, and its side is read off where it is (the two sides themselves can lie nearly along the
    # shoulder-wrist line part way)
    ax = unit(T - S)
    pole = eA * (1.0 - m) + eB * m - S
    if np.linalg.norm(pole - ax * (pole @ ax)) < 1e-3:
        pole = pA * (1.0 - m) + pB * m
    sink = {}
    cA, cB, c = (two_bone(S, w, u0, l0, pole0, p, "handover", sink) for w, p in ((wA, pA), (wB, pB), (T, pole)))
    tw_u = ZR.slerp(ZR.quat(cA[0].T @ A[0]), ZR.quat(cB[0].T @ B[0]), m)     # each bone's own twist about its length, in its rest frame
    tw_f = ZR.slerp(ZR.quat(cA[1].T @ A[1]), ZR.quat(cB[1].T @ B[1]), m)
    u, f = c[0] @ ZR.mat(tw_u), c[1] @ ZR.mat(tw_f)
    return u, f, f @ ZR.mat(ZR.slerp(ZR.quat(A[1].T @ A[2]), ZR.quat(B[1].T @ B[2]), m))


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
        # (2026-11-07) the haft's real centreline (tools/blender/shen_import/haft_axis.py): the sculpted wood runs 0.04-0.15 off the landmark line and bends
        # gently. The fist turns about the wood itself, so its grip point moves onto the real centre; the lead hand follows the bend (lead_point)
        hx = json.loads((ROOT / f"work/shen_import/haft_p{phase}.json").read_text())
        kn = np.array(hx["knots"], float)
        e1, e2 = np.array(hx["e1"], float), np.array(hx["e2"], float)
        self._haft_knots = (kn[:, 0], np.outer(kn[:, 1], e1) + np.outer(kn[:, 2], e2))
        self.HAFT_R = float(hx["radius"])
        self.GRIP0 = self.GRIP0 + self.haft_centre(0.0)
        w = self.samples["Weapon"]
        t = (w - self.GRIP0) @ self.HAFT0
        self.SOCKET_S = float(np.dot(np.array(J.SOCKET, float) - self.GRIP0, self.HAFT0))
        blade = w[t > self.SOCKET_S + 0.05]
        off = (blade - self.GRIP0) - np.outer((blade - self.GRIP0) @ self.HAFT0, self.HAFT0)
        spine = np.linalg.svd(off - off.mean(0))[2][0]     # the blade's width axis; the tip sweeps to the spine side
        spine = spine if (off @ spine).max() > -(off @ spine).min() else -spine
        self.FACE0 = orth(-spine, self.HAFT0)              # the convex cutting edge is the other side
        self.TIP0 = w[int(np.argmax(t))]
        hand = R.left_hand(J, self.samples["LeftHand"], self.HAFT_R)
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
        # (2026-11-07) the arms' thickness, measured from the mesh (sleeve and bracer included), and a thinned weapon cloud: what the grip chooser keeps apart
        self.ARM_R = {}
        for side in ("Right", "Left"):
            prof = []
            for part, a, b, at in ((side + "UpperArm", J_[side + "UpperArm"], J_[side + "LowerArm"], (0.3, 0.8)), (side + "LowerArm", J_[side + "LowerArm"], J_[side + "Hand"], (0.15, 0.85))):
                q = self.samples[part] - a
                d = b - a
                u = q @ d / float(d @ d)
                r = np.linalg.norm(q - np.outer(u, d), axis=1)
                prof += [float(np.percentile(r[np.abs(u - x) < 0.12], 55)) for x in at]
            self.ARM_R[side] = tuple(prof)      # upper arm near the shoulder and elbow, forearm near the elbow and wrist
        sdf = np.load(ROOT / f"work/shen_import/sdf_p{phase}.npz")     # (2026-11-07) tools/blender/shen_import/body_sdf.py: each part's signed distance, measured on the real mesh
        self.SDF = {k[:-5]: (sdf[k], sdf[k[:-5] + "_origin"], float(sdf[k[:-5] + "_step"])) for k in sdf.files if k.endswith("_grid")}
        self.WCLOUD = w[::6] - self.GRIP0
        self.WCLOUD_S = self.WCLOUD @ self.HAFT0
        # (2026-11-07) and the glaive's real surface, dense (tools/blender/shen_import/weapon_cloud.py, one vertex per 0.04): the thinned cloud left 3
        # points across the butt cap, which then sat 0.109 inside his right forearm (phase 2 Idle) while every arm check read it clear. The arm checks
        # (held_clash, the grip chooser, validate) look with this one, culled to what an arm can reach
        self.WDENSE = np.load(ROOT / f"work/shen_import/wcloud_p{phase}.npz")["points"].astype(float) - self.GRIP0
        self.WDENSE_S = self.WDENSE @ self.HAFT0
        # (2026-11-07) the glaive's own solid (body_sdf.py, SDF_PARTS=Weapon), so the body is kept out of the weapon as well as the weapon out of the body:
        # the haft is thin, and a forearm or the belt slips between the weapon's sample points
        ws = np.load(ROOT / f"work/shen_import/sdf_p{phase}_Weapon.npz")
        self.WSDF = (ws["Weapon_grid"], ws["Weapon_origin"], float(ws["Weapon_step"]), ws["Weapon_axes"], ws["Weapon_centre"])
        self.WGRIP = self.GRIP0.copy()      # the weapon cloud's own origin: rest point = (world - origin) @ Rw + WGRIP
        # (2026-11-07) his surface with its real skin weights (tools/blender/shen_import/skin_points.py): each sample grouped by the bone it follows
        # most, posed by blending its bones as the game skins it, so the wrist crease, the heel of the palm and the top of the shoulder are where they
        # really are; `SKIN[part]` = rest points and [(bone, weight per point)]
        sk = np.load(ROOT / f"work/shen_import/surface_p{phase}.npz")
        bones = [str(b) for b in sk["bones"]]
        self.BODY_PTS, self.SKIN = {}, {}
        for part, keep in (("LowerTorso", 500), ("UpperTorso", 500), ("Head", 250), ("RightUpperArm", 250), ("RightLowerArm", 400), ("RightHand", 600),
                           ("LeftUpperArm", 250), ("LeftLowerArm", 400), ("LeftHand", 600), ("RightUpperLeg", 220), ("RightLowerLeg", 160),
                           ("LeftUpperLeg", 220), ("LeftLowerLeg", 160)):
            k = max(1, len(sk[part + "_P"]) // keep)
            P, W, B = sk[part + "_P"][::k].astype(float), sk[part + "_W"][::k].astype(float), sk[part + "_B"][::k]
            self.BODY_PTS[part] = P
            self.SKIN[part] = (P, [(bones[b], (W * (B == b)).sum(1)) for b in np.unique(B) if float((W * (B == b)).sum()) > 1e-6])
        # where each part's solid counts: its nearest own surface follows its own bone (as the mesh check judges it); see sdf_depth()
        # only the arms: the solid there wrongly includes the heel of the palm and the wrist crease; the torso's and legs' solids stay whole (erring
        # toward more clearance), since a haft through the belly could slip between skin samples
        self.RIGID = {k[:-6]: sk[k] for k in sk.files if k.endswith("_rigid") and "Arm" in k}
        self.LAX0 = unit(self.LHAND_ACROSS if self.LHAND_ACROSS @ np.array([0, 0, -1.0]) > 0 else -self.LHAND_ACROSS)     # the thumb's side: the fingers close about this line, so the haft lies along it
        self.REST = {
            "pel": (0.0, 0.0, 0.0), "pelR": (0.0, 0.0, 0.0), "chest": (0.0, 0.0, 0.0), "neck": (0.0, 0.0, 0.0),
            "rp": tuple(self.GRIP0), "rsl": 0.0, "haft": tuple(self.HAFT0), "face": tuple(self.FACE0), "relb": tuple(self.ELBOW0), "rlk": 0.0, "rhx": tuple(self.HAFT0),
            "lua": (0.0, 0.0, 0.0), "lfa": (0.0, 0.0, 0.0), "lha": (0.0, 0.0, 0.0), "lhw": 0.0, "lsl": 1.2, "ltw": 0.0, "lt": (-0.2, -1.2, -0.6), "lelb": (-0.5, -0.4, 0.7),
            "rf": (0.0, 0.0, 0.0, 0.0, 0.0), "lf": (0.0, 0.0, 0.0, 0.0, 0.0), "rknee": (0.0, 0.0, -1.0), "lknee": (0.0, 0.0, -1.0), "hov": 0.0,
            "rsw": 0.0, "lsw": 0.0,
            "wfree": 0.0, "wrp": tuple(self.GRIP0), "whaft": tuple(self.HAFT0), "wface": tuple(self.FACE0), "rt": (0.25, -1.3, -0.3), "rha": (0.0, 0.0, 0.0),   # (2026-11-06) weapon let go: its own pose; the right arm's free reach and hand
        }

    def haft_centre(self, s):
        """Rest-space offset of the real haft centre from the landmark line at s (rig units from the right grip), held at the clean slices' ends."""
        ks, off = self._haft_knots
        return np.array([np.interp(s, ks, off[:, j]) for j in range(3)])

    def lead_point(self, rp, haft, face, sl, rsl=0.0):
        """Where the lead hand's palm goes: the real centre of the wood `sl` along the haft from the fist, the fist being `rsl` along the weapon from its
        reference grip (the haft bends a little). (2026-11-07) was read at `sl` alone, as if the fist held the weapon's reference point: up to 0.12 off the wood."""
        return np.asarray(rp, float) + unit(haft) * sl + self.hand_rotation(unit(haft), unit(face)) @ (self.haft_centre(rsl + sl) - self.haft_centre(rsl))

    def weapon_origin(self, rp, haft, face, rsl):
        """(2026-11-07) Where the weapon's reference grip goes when the fist at rp holds it `rsl` along: the fist closes on the real centre of the wood
        there. The haft is S-bent: the plain line through the reference point runs 0.04-0.07 off the wood where the fist really holds (s = -1.8)."""
        haft = unit(haft)
        return np.asarray(rp, float) - haft * rsl - self.hand_rotation(haft, unit(face)) @ (self.haft_centre(rsl) - self.haft_centre(0.0))

    def fist_point(self, origin, haft, face, rsl):
        """The inverse of weapon_origin: where the fist is on a weapon whose reference grip is at origin."""
        haft = unit(haft)
        return np.asarray(origin, float) + haft * rsl + self.hand_rotation(haft, unit(face)) @ (self.haft_centre(rsl) - self.haft_centre(0.0))

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

    def __init__(self, rig, name, length, keys, loop=False, priority="Action", contacts=(), move=None, notes="", active=None, slot="", feet_free=(), corrupt=True, scrape=False, airborne=False, authored_feet=False, raw_after=None, hover=0.0, still_after=None, uncorrupt=None, floor_body=False):
        self.rig = rig
        self.slide_floor = None    # (2026-11-07) a cut may let the lead hand run further down the haft toward the fist (a big swing's sliding grip)
        self._side = None   # solve(): which side of each torso part the haft was on last frame, during a sweep through the clip in order
        self.hover = float(hover)   # phase 2 floats: the height this clip holds when it does not key `hov` itself
        self.name, self.length, self.loop, self.priority = name, float(length), loop, priority
        self.keys = sorted(((float(t), c, e) for t, c, e in keys), key=lambda k: k[0])
        self.contacts = [float(c) for c in contacts]
        self.move, self.notes, self.active = move, notes, active
        self.slot = slot or name
        self.feet_free = list(feet_free)
        self.corrupt = corrupt and rig.phase == 2
        self.floor_body = floor_body   # (2026-11-06) the whole body may meet the floor (a fall): rest_on_floor keeps every part on it, none through it
        self.uncorrupt = uncorrupt     # (2026-11-06) (t0, t1): the corruption layer lets go over this span (a body falling dead lies as a body, not as a stance)
        self.scrape, self.airborne = scrape, airborne
        self.still_after = still_after   # (2026-11-06) from here the body is lifeless: no breath or unrest (a finished death)
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
        if c["ltw"] > 0.0:     # (2026-11-08) how near (in time) the lead hand is to the haft, for its reach's elbow (solve)
            c["_lcarry"] = max(float(np.clip(self.channel("lhw", t + dt), 0, 1)) * (1.0 - smooth01(abs(dt) / LEAD_CARRY_TIME))
                               for dt in np.linspace(-LEAD_CARRY_TIME, LEAD_CARRY_TIME, 37))
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
            k = 1.0 if self.uncorrupt is None else 1.0 - smooth01((t - self.uncorrupt[0]) / (self.uncorrupt[1] - self.uncorrupt[0]))
            c["pel"] = c["pel"] + np.array([0, -0.1, -0.03]) * k
            c["pelR"] = c["pelR"] * np.array([1, 1 + 0.18 * k, 1]) + np.array([6.0, 0, 0]) * k
            c["chest"] = c["chest"] * np.array([1, 1 + 0.28 * k, 1]) + np.array([8.0, 0, 0]) * k
            c["neck"] = c["neck"] + np.array([20.0, 0, 0]) * k   # the torso hunches; the head stays up, glaring out from under the brows
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
        rp = self.clear_surface(rp, haft, rsl, world)
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

    def clear_surface(self, rp, haft, rsl, world, face=None, passes=4):
        """(2026-11-07) The capsules above keep the weapon on its side of him; this keeps it off his real surface (belly, robe front, chest, head),
        measured: the whole weapon steps out along the surface's own normal, square to the haft, by what its deepest point is in."""
        rg = self.rig
        face = unit(self._face) if face is None and getattr(self, "_face", None) is not None else face
        if face is None:
            return rp
        Rw = rg.hand_rotation(haft, face)
        cloud = rg.WCLOUD @ Rw.T
        for _ in range(passes):
            P = cloud + rg.weapon_origin(rp, haft, face, rsl)
            worst, push = CLEAR_MARGIN, None
            solids = BODY_SOLIDS + tuple(p for p in LEG_SOLIDS if p in world)     # (2026-11-07) and his legs: solve() places them before the weapon
            pose = pose_of(rg, world)
            for part in solids:
                W = world[part]
                at = (W @ np.append(rg.JOINT[part], 1))[:3]
                d = part_depth(rg, part, W[:3, :3], at, P)
                i = int(np.argmax(d))
                if d[i] > worst:
                    q = P[i]
                    g = np.array([part_depth(rg, part, W[:3, :3], at, np.array([q - e * 0.03, q + e * 0.03])) @ (1.0, -1.0) for e in np.eye(3)])   # toward outside
                    g = g - haft * float(g @ haft)
                    if float(np.linalg.norm(g)) > 1e-6:
                        worst, push = float(d[i]), unit(g)
            # and his surface out of the weapon: the weapon steps away from the deepest body point, along the weapon's own normal there
            origin = rg.weapon_origin(rp, haft, face, rsl)
            for part in solids:
                W = world[part]
                at = (W @ np.append(rg.JOINT[part], 1))[:3]
                B = body_points(rg, part, W[:3, :3], at, pose)
                d = weapon_depth(rg, Rw, origin, B)
                i = int(np.argmax(d))
                if d[i] > worst:
                    q = B[i]
                    g = np.array([weapon_depth(rg, Rw, origin, np.array([q + e * 0.02, q - e * 0.02])) @ (1.0, -1.0) for e in np.eye(3)])   # toward the weapon's inside: the weapon moves that way off the point
                    g = g - haft * float(g @ haft)
                    if float(np.linalg.norm(g)) > 1e-6:
                        worst, push = float(d[i]), unit(g)
            if push is None:
                break
            rp = rp + push * (worst - CLEAR_MARGIN + 0.02)
        return rp

    def arm(self, S, grip, axis, axis0, v0_len, pole_key, hand, u0, l0, pole0, label, diag, roll=None, slant=0.0, side="Right"):
        """How an arm really holds a haft. The elbow is a hinge, the forearm rolls about itself (pronation, carried by the lower arm bone), and the wrist only makes up what remains: the fist never turns backwards on the arm.
        `hand` is the fist's turn, chosen across the whole clip by swivel(); its axis is laid on the haft, the arm goes exactly to it, and the forearm takes all the twist it can."""
        axis0 = slanted(self.rig, axis0, side, slant)     # (2026-11-06) the haft may lie diagonally across the palm, as it does in a real grip
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
        c["_chest"] = (Rch, (world["UpperTorso"] @ np.append(rg.JOINT["UpperTorso"], 1))[:3])     # (2026-11-07) for the arms' skin blend in swivel()
        c["_pelvis"] = (world["LowerTorso"][:3, :3], (world["LowerTorso"] @ np.append(rg.JOINT["LowerTorso"], 1))[:3])     # (2026-11-08) and its torso test
        local["Head"] = homog(euler(c["neck"]))
        world["Head"] = rg.pivoted(world["UpperTorso"], "Head", local["Head"])
        # legs: x, z, lift, yaw, pitch from the rest ankle. (2026-11-07) Solved before the weapon, which keeps out of them as it does out of his body
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
        # the weapon first: the hands go to it. `rp` is where the right hand holds it, `rsl` where on the haft that is
        haft, face = unit(c["haft"]), unit(c["face"])
        rsl = float(c["rsl"])
        S = (world["UpperTorso"] @ np.append(rg.JOINT["RightUpperArm"], 1))[:3]
        self._face = face
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
        origin = rg.weapon_origin(rp, haft, face, rsl)      # the weapon's reference grip, the fist on the wood rsl from it
        haft, face = self.clear_floor(origin, haft, face)
        rp = rg.fist_point(origin, haft, face, rsl)
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
            want = rg.lead_point(rp, haft, face, sl, rsl) - SL
            gap = float(np.linalg.norm(want)) - maxr
            if gap > 0:
                lpro = unit(want * np.array([1.0, 0.5, 1.0])) * min(gap, PROTRACT)
                SL = SL + lpro
            c["_lgap"] = max(float(np.linalg.norm(rg.lead_point(rp, haft, face, sl, rsl) - SL)) - maxr, 0.0)
            floor = SLIDE_FLOOR if self.priority in ("Idle", "Movement") else (self.slide_floor or SLIDE_FLOOR_CUT)
            near = float(np.clip(np.dot(SL - rp, haft), min(floor, sl), sl))     # (2026-11-06) the lead hand may slide in only to the floor; past that the weapon comes to it
            for _ in range(14):
                if np.linalg.norm(rg.lead_point(rp, haft, face, sl, rsl) - SL) <= maxr:
                    break
                sl += (near - sl) * 0.35
        for _ in range(8):      # both hands must reach: what the right arm cannot hold the weapon gives up, and the left the same
            away = rp - S
            far = float(np.linalg.norm(away))
            if far > arm_len:
                rp = S + away * (arm_len / far)
            if hold > 0 and hold >= reach:
                on = rg.lead_point(rp, haft, face, sl, rsl)
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
        origin = rg.weapon_origin(rp, haft, face, rsl)
        haft, face = self.clear_floor(origin, haft, face)      # the reach may have carried the weapon down: the blade still never goes through the ground
        rp = rg.fist_point(origin, haft, face, rsl)
        for _ in range(2):      # (2026-11-07) the floor's tilt can carry the butt into his belly: clear the surface again, then the floor, until both hold
            moved = self.clear_surface(rp, haft, rsl, world, face)
            if float(np.linalg.norm(moved - rp)) < 1e-4:
                break
            origin = rg.weapon_origin(moved, haft, face, rsl)
            haft, face = self.clear_floor(origin, haft, face)
            rp = rg.fist_point(origin, haft, face, rsl)
        c["haft"], c["face"], c["rp"] = haft, face, rp
        wf = float(np.clip(c["wfree"], 0.0, 1.0))
        if wf > 0:   # (2026-11-06) the hands let go: the weapon is carried to its own keyed pose (a glaive dropped on the floor), still never through the ground; c keeps the held grip
            haft = unit(haft + (unit(c["whaft"]) - haft) * wf)
            face = orth(face + (unit(c["wface"]) - face) * wf, haft)
            origin = rg.weapon_origin(rp + (np.asarray(c["wrp"], float) - rp) * wf, haft, face, rsl)
            low = float(((rg.samples["Weapon"][::4] - rg.GRIP0) @ rg.hand_rotation(haft, face).T)[:, 1].min() + origin[1])
            origin = origin + np.array([0.0, max(0.0, GROUND + 0.02 - low), 0.0])     # a weapon out of the hands lies on the floor: lifted, not pitched about a fist that is not there
        Rw = rg.hand_rotation(haft, face)
        W = homog(Rw, origin - Rw @ rg.GRIP0)
        world["Glaive"] = W
        j = rg.JOINT["Glaive"]
        local["Glaive"] = homog(None, -j) @ np.linalg.inv(world[rg.PARENT["Glaive"]]) @ W @ homog(None, j)
        # the right arm. During a pinwheel the fist keeps its own axis while the haft turns on the fingers
        lock = float(c["rlk"])
        haft = c["haft"]
        axis = unit(haft + (unit(c["rhx"]) - haft) * lock) if lock > 0 else haft
        v_r = rg.GRIP0 - rg.JOINT["RightHand"]
        core = (world["UpperTorso"] @ np.append(rg.JOINT["UpperTorso"] + (0, 0.4, 0), 1))[:3]
        if wf < 0.5:
            c["_rgrip"] = (S, rp, axis, core)
        Rh, ru, rl, _, elbow, c["_rroll"] = self.arm(S, rp, axis, rg.HAFT0, v_r, c.get("rpole", c["relb"]), c.get("rhand"), rg.ARM_U, rg.ARM_L, rg.ELBOW0, "arm_reach", scratch_r := {}, c.get("rpole_roll"), c.get("rhand_slant", 0.0), "Right")
        diag["arm_reach"] = max(diag.get("arm_reach", 0.0), scratch_r["arm_reach"] * (1.0 - wf) ** 2)
        if wf > 0:   # the empty right arm reaches for its own spot (lying: the floor), the hand hanging off the forearm as keyed
            fu, ff, _ = two_bone(S, S + np.asarray(c["rt"], float), rg.ARM_U, rg.ARM_L, rg.ELBOW0, unit(c["relb"]), "right_reach", diag)
            ru = ZR.mat(ZR.slerp(ZR.quat(ru), ZR.quat(fu), wf))
            rl = ZR.mat(ZR.slerp(ZR.quat(rl), ZR.quat(ff), wf))
            Rh = ZR.mat(ZR.slerp(ZR.quat(Rh), ZR.quat(ff @ euler(c["rha"])), wf))
        local["RightUpperArm"] = homog(Rch.T @ ru, Rch.T @ rpro)
        world["RightUpperArm"] = rg.pivoted(world["UpperTorso"], "RightUpperArm", local["RightUpperArm"])
        local["RightLowerArm"] = homog(ru.T @ rl)
        world["RightLowerArm"] = rg.pivoted(world["RightUpperArm"], "RightLowerArm", local["RightLowerArm"])
        local["RightHand"] = homog(rl.T @ Rh)
        world["RightHand"] = rg.pivoted(world["RightLowerArm"], "RightHand", local["RightHand"])
        # the left arm: on the haft, reaching for a point, or free; blended, so it can leave and rejoin the weapon in a move
        Su, Sf = Rch @ euler(c["lua"]), Rch @ euler(c["lfa"])
        Sh = Sf @ euler(c["lha"])
        c.pop("_lvis", None)
        if hold > 0 or reach > 0:
            ik = []
            if hold > 0:
                on = rg.lead_point(rp, haft, face, sl, rsl)
                if hold > 0.5 and hold >= reach:
                    c["_lgrip"] = (SL, on, haft, core)
                Rp, u_ik, f_ik, _, _, c["_lroll"] = self.arm(SL, on, haft, rg.LAX0, v_l, c.get("lpole", c["lelb"]), c.get("lhand"), rg.LARM_U, rg.LARM_L, rg.LELBOW0, "left_grip", scratch := {}, c.get("lpole_roll"), c.get("lhand_slant", 0.0), "Left")
                c["_lsl"] = sl
                ik.append((hold, u_ik, f_ik, Rp))
                grip_short = scratch["left_grip"]
            if reach > 0:
                scratch = {}
                pole = unit(c["lelb"])
                carry = c.get("_lcarry", 0.0)
                if carry > 0.0 and "lpole" in c:     # (2026-11-08) a hand just off the haft (or about to take it) keeps its elbow where the grip had it, and
                    # swings it to the keyed side over LEAD_CARRY_TIME: keyed straight away, the reach's elbow lay opposite the grip's (95-178 deg at the
                    # forearm) and the hand-over, as quick as a heavy cut keys it, turned the whole arm over inside a frame (Guandao_Heavy)
                    g = orth(unit(c["lpole"]), unit(np.asarray(c["lt"], float)))
                    k = orth(pole, unit(np.asarray(c["lt"], float)))
                    th = math.acos(float(np.clip(g @ k, -1.0, 1.0)))
                    turn = np.cross(g, k)
                    pole = rodrigues(unit(turn) * th * (1.0 - carry)) @ g if th > 1e-4 and np.linalg.norm(turn) > 1e-6 else (g if carry > 0.5 else k)
                u_ik, f_ik, _ = two_bone(SL, SL + np.asarray(c["lt"], float), rg.LARM_U, rg.LARM_L, rg.LELBOW0, pole, "left_reach", scratch)
                ik.append((reach, u_ik, f_ik, f_ik @ euler(c["lha"])))
                reach_short = scratch["left_reach"]
            # (2026-11-06) letting go of the haft to reach (or back): near the crossover the two solutions blend, so the arm never jumps there; outside it the stronger one rules as before
            # (2026-11-08) the reach's share of the two, over the whole hand-over the keys give it: blended only while the weights were within 0.2 of each
            # other (and eased again on top of the keys' own easing), a release keyed over 2.4 frames swapped one arm for the other inside one frame
            # (Guandao_Heavy: phase 1 f23, phase 2 f15, the whole arm and the hand 120-130 deg in a frame)
            mix = reach / (hold + reach) if len(ik) == 2 else (0.0 if hold > 0 else 1.0)
            if hold > 0:    # a hand on its way to the haft is not yet expected there
                diag["left_grip"] = max(diag.get("left_grip", 0.0), grip_short * hold * hold * (1.0 - mix))
            if reach > 0:
                diag["left_reach"] = max(diag.get("left_reach", 0.0), reach_short * reach * reach * mix)
            c["_lvis"] = (mix, ik[-1][3] if reach > 0 else None)     # (2026-11-08) for swivel: the hand shown here is its grip carried toward this reach by mix
            if len(ik) == 2:
                u_ik, f_ik, Rp = handover_arm(SL, rg.LARM_U, rg.LARM_L, rg.LELBOW0, ik[0][1:], ik[1][1:], mix)
            else:
                u_ik, f_ik, Rp = ik[0][1:]
            w = min(1.0, hold + reach)     # (2026-11-08) a hand handed over between haft and reach is on one or the other throughout: at the larger of the two it sagged halfway back to its keyed pose mid-way (upper arm 159 deg in a frame)
            Su = ZR.mat(ZR.slerp(ZR.quat(Su), ZR.quat(u_ik), w))
            Sf = ZR.mat(ZR.slerp(ZR.quat(Sf), ZR.quat(f_ik), w))
            Sh = ZR.mat(ZR.slerp(ZR.quat(Sh), ZR.quat(Rp), w))
        local["LeftUpperArm"] = homog(Rch.T @ Su, Rch.T @ lpro)
        world["LeftUpperArm"] = rg.pivoted(world["UpperTorso"], "LeftUpperArm", local["LeftUpperArm"])
        local["LeftLowerArm"] = homog(Su.T @ Sf)
        world["LeftLowerArm"] = rg.pivoted(world["LeftUpperArm"], "LeftLowerArm", local["LeftLowerArm"])
        local["LeftHand"] = homog(Sf.T @ Sh)
        world["LeftHand"] = rg.pivoted(world["LeftLowerArm"], "LeftHand", local["LeftHand"])
        return local, world, diag

    def bake(self):
        times = self.frames()
        ctrl = [self.controls(t) for t in times]
        organic(self, times, ctrl)
        spine_reach(self, ctrl)
        if self.floor_body:
            rest_on_floor(self, ctrl)
        settle(self, ctrl)
        swivel(self, ctrl)
        for _ in range(3):      # a tilted haft moves the lead hand's spot: settle that correction too, choose the grips again, and look again
            if not wrist_yield(self, ctrl, passes=1):
                break
            settle(self, ctrl)
            swivel(self, ctrl)
        clear_free_arm(self, ctrl)
        clear_torso(self, ctrl, times)
        slide_fist(self, ctrl)
        tilt_haft(self, ctrl, times)
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
# (2026-11-08) most the trunk may trail its keys (degrees, each axis). A whip turns the chest 100 deg in two frames (phase 2 Guandao_Heavy, 0.31-0.383 s);
# trailing it by up to 66 deg, the chest still faced away at the contact while the weapon hand, which keeps its key, was already in front: the fist
# came 0.3-0.4 behind his back and both arms passed through his chest to reach it (0.38 deep). A trunk that leads the swing cannot lag the blade
LAG_CAP = {"chest": 20.0, "pelR": 20.0}
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
            alive = 1.0 if clip.still_after is None else 1.0 - smooth01((t - clip.still_after) / 0.4)
            v[axis] += alive * amp * (math.sin(2 * math.pi * f1 * t / length + p1) * 0.7 + math.sin(2 * math.pi * f2 * t / length + p2) * 0.3)
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
            if ch in LAG_CAP:      # (2026-11-08) softly, so a long lag eases into its cap
                cap = LAG_CAP[ch]
                v = raw[i] + cap * np.tanh((v - raw[i]) / cap)
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


def slanted(rig, axis0, side, slant):
    """The hand's line laid on the haft, turned `slant` degrees about the palm normal: the haft running diagonally across the palm."""
    if not slant:
        return axis0
    return rodrigues(wrist_frame(rig, side)[2] * math.radians(slant)) @ axis0


def wrist_cost(parts):
    """What a wrist pose costs beyond its plain bend: deviation past what a wrist gives, flexion past its stop, twist the forearm should have carried. The hand leaves its cuff past these."""
    tw, fl, dv = (abs(x) for x in parts)
    lt, lf, ld = WRIST_LIMITS
    # (2026-11-07) twist too is costed from a little inside its limit: free up to the limit, the choice sat on it and smoothing tipped it 1-6 deg past
    return 3.0 * max(0.0, dv - ld + 8.0) + 1.5 * max(0.0, fl - lf) + 1.0 * max(0.0, tw - lt + 8.0) + 2.0 * max(0.0, tw - lt) + 12.0 * max(0.0, dv - ld) + 6.0 * max(0.0, fl - lf - 10.0)


def wrist_excess(rig, R, side):
    """Degrees past WRIST_LIMITS on the worst axis (0 inside the range)."""
    p = wrist_parts(rig, R, side)
    return max(0.0, *(abs(x) - lim for x, lim in zip(p, WRIST_LIMITS)))


CLEAR_MARGIN = 0.0     # how deep a weapon point may sit in his surface before clear_surface moves it (the mesh check counts past 0.03)
BODY_SOLIDS = ("LowerTorso", "UpperTorso", "Head")     # (2026-11-07) what clear_body keeps the weapon out of, on their measured surfaces
LEG_SOLIDS = ("RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg")
CLASH_COST = 600.0   # swivel cost per rig unit an arm sinks into the weapon: 0.05 deep weighs like 30 deg of wrist bend
CLASH_GRAZE, CLASH_HARD = 0.015, 6000.0     # (2026-11-07) past a graze an arm in the weapon is all but forbidden: 0.03 deep weighs like 90 deg of wrist bend


def weapon_cloud(rig, c):
    """The weapon's thinned surface where control set c holds it (as solve() places it), and each point's place along the haft measured from the right fist."""
    haft, face = unit(c["haft"]), unit(c["face"])
    origin = rig.weapon_origin(c["rp"], haft, face, float(c["rsl"]))
    return rig.WDENSE @ rig.hand_rotation(haft, face).T + origin, rig.WDENSE_S - float(c["rsl"])


def weapon_place(rig, c):
    """The weapon's world rotation and the origin its cloud hangs from, where control set c holds it."""
    haft, face = unit(c["haft"]), unit(c["face"])
    return rig.hand_rotation(haft, face), rig.weapon_origin(c["rp"], haft, face, float(c["rsl"]))


def weapon_depth(rig, Rw, origin, P):
    """(2026-11-07) How deep each world point is inside the glaive placed by (Rw, origin), in its measured distance field; negative outside."""
    return weapon_depth_rest(rig, (P - origin) @ Rw + rig.WGRIP)


def weapon_depth_rest(rig, Q):
    """Depth inside the glaive of points in its rest frame (rig space, as the props file stands)."""
    grid, lo, step, axes, centre = rig.WSDF
    q = ((Q - centre) @ axes.T - lo) / step
    n = np.array(grid.shape) - 1
    i0 = np.clip(np.floor(q).astype(int), 0, n - 1)
    f = np.clip(q - i0, 0.0, 1.0)
    out = np.zeros(len(Q))
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                wgt = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out += wgt * grid[i0[:, 0] + dx, i0[:, 1] + dy, i0[:, 2] + dz]
    out[np.any((q < 0) | (q > n), axis=1)] = 0.5
    return -out


def body_points(rig, part, R, at, pose=None):
    """A part's thinned real surface, posed with world rotation R and its joint at `at`. (2026-11-07) With `pose` ({bone: (R, joint)}), each point
    blends the bones it is skinned to, as the game does; a bone not in `pose` moves with the part itself."""
    P, mix = rig.SKIN[part]
    if not pose or len(mix) == 1:
        return (P - rig.JOINT[part]) @ R.T + at
    out = np.zeros_like(P)
    for bone, w in mix:
        if bone == part or bone not in pose:
            Rb, ab, jb = R, at, rig.JOINT[part]
        else:
            (Rb, ab), jb = pose[bone], rig.JOINT[bone]
        out += w[:, None] * ((P - jb) @ Rb.T + ab)
    return out


def pose_of(rig, world):
    """Every solved body bone as body_points() takes it: world rotation and joint."""
    return {k: (W[:3, :3], (W @ np.append(rig.JOINT[k], 1))[:3]) for k, W in world.items() if k in rig.JOINT and k in rig.SKIN}


HAND_GRIP = 0.05     # how far a fist's or the lead hand's surface may press into the wood (the mesh check allows the hands the same)


def sdf_depth(rig, part, P):
    """How deep each rest-space point is inside a body part's real surface (trilinear in its distance field); negative outside."""
    grid, lo, step = rig.SDF[part]
    q = (P - lo) / step
    n = np.array(grid.shape) - 1
    i0 = np.clip(np.floor(q).astype(int), 0, n - 1)
    f = np.clip(q - i0, 0.0, 1.0)
    out = np.zeros(len(P))
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                wgt = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out += wgt * grid[i0[:, 0] + dx, i0[:, 1] + dy, i0[:, 2] + dz]
    outside = np.any((q < 0) | (q > n), axis=1)
    out[outside] = 0.5
    mask = getattr(rig, "RIGID", {}).get(part)
    if mask is not None:     # (2026-11-07) a solid carried rigidly by its bone does not stand for blended skin near a joint: there it is outside
        k = np.clip(np.rint(q).astype(int), 0, n)
        out[~mask[k[:, 0], k[:, 1], k[:, 2]]] = np.maximum(out[~mask[k[:, 0], k[:, 1], k[:, 2]]], 0.5)
    return -out


def part_depth(rig, part, Rw, at, P):
    """Depth of world points inside a part posed by world rotation Rw with its joint at `at` (rest-relative, as solve() places it)."""
    return sdf_depth(rig, part, (P - at) @ Rw + rig.JOINT[part])


def seg_depth(P, A, B, ra, rb):
    """How deep each point is inside a tapered capsule A-B (radius ra at A, rb at B); negative outside."""
    d = B - A
    u = np.clip((P - A) @ d / max(float(d @ d), 1e-9), 0.0, 1.0)
    return ra + (rb - ra) * u - np.linalg.norm(P - (A + np.outer(u, d)), axis=1)


def arm_clash(rig, side, S, elbow, wrist, P, ru=None, rl=None, place=None, hand=None, chest=None, hand_pose=None):
    """Deepest a weapon point sits inside this arm's real surface (upper arm with the rotation ru at the shoulder S, forearm with rl at the elbow; both
    rest-relative world rotations). Only points near the arm are looked up. 0 when clear. Without rotations, the measured tapered capsules stand in.
    (2026-11-07) With the weapon's place (Rw, origin), also how deep the arm's own surface sits in the weapon, and with the hand's world rotation,
    the hand's past HAND_GRIP: the haft is thinner than the gaps between its sample points.
    (2026-11-07) The arm's surface is skinned: it blends the chest (`chest`, (R, joint)), the arm's own bones and the hand (`hand`, or `hand_pose`
    (R, wrist) when the hand's own clash is counted elsewhere), as the game deforms it."""
    if len(P) == 0:
        return 0.0
    ru0, ru1, rf0, rf1 = rig.ARM_R[side]
    out = 0.0
    pose = {}
    if ru is not None and rl is not None:
        pose = {side + "UpperArm": (ru, S), side + "LowerArm": (rl, elbow)}
        if chest is not None:
            pose["UpperTorso"] = chest
        if hand is not None or hand_pose is not None:
            pose[side + "Hand"] = (hand, wrist) if hand is not None else hand_pose
    if hand is not None and place is not None:
        out = hand_clash(rig, side, hand, wrist, place, pose)
    for part, A, B, R, ra, rb in ((side + "UpperArm", S, elbow, ru, ru0, ru1), (side + "LowerArm", elbow, wrist, rl, rf0, rf1)):
        rough = seg_depth(P, A, B, ra, rb)
        near = rough > -0.25
        if not near.any():     # no weapon near this part: neither can be in the other
            continue
        if R is None or part not in rig.SDF:
            out = max(out, float(rough[near].max()))
        else:
            out = max(out, float(part_depth(rig, part, R, A, P[near]).max()))
            if place is not None:
                out = max(out, float(weapon_depth(rig, place[0], place[1], body_points(rig, part, R, A, pose)).max()))
    return max(0.0, out)


def hand_clash(rig, side, hand, wrist, place, pose=None):
    """How far a hand's surface sits in the weapon past the grip it is allowed (HAND_GRIP); 0 when clear. `pose`: the arm's bones, for the skin blend."""
    return max(0.0, float(weapon_depth(rig, place[0], place[1], body_points(rig, side + "Hand", hand, wrist, pose)).max()) - HAND_GRIP)


STEP_LIMITS_ACTION = (45.0, 75.0)   # most a forearm may roll and an elbow swing in one frame (deg) in a cut; carrying and moving keep 45/75
LEAD_CARRY_TIME = 0.15     # (2026-11-08) seconds over which a reaching lead arm's elbow swings from where its grip had it to the keyed side
GRIP_STEP_COST = 150.0     # (2026-11-08) a lead-hand step past GRIP_STEP_*: more than a graze in the wood (0.03 deep: 108), less than an arm in it (0.04: 174; at 600 phase 2 Guandao_Heavy took 0.065 at f10 to save one). The fist keeps 600
GRIP_STEP_ACTION, GRIP_STEP_HOLD = 60.0, 40.0    # (2026-11-08) most a hand may turn in one frame both in the world and on the haft (a twirl keeps the first small, a firm grip the second):
                                                # the path paid only a cost per degree, and a cheap lead hand flipped 179 deg between two frames of phase 2 Guandao_L1 (f10-11)
LEAD_TURN_COST = 0.12   # per degree the lead hand turns on the haft between frames, in attacks (the fist pays 0.4)
GRIP_TURNS = np.radians(np.arange(16) * 22.5)
GRIP_SLANTS = (-20.0, -10.0, 0.0, 10.0, 20.0)    # (2026-11-06) degrees the haft may run diagonally across the palm (index knuckle to heel of the hand)
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


FLOOR_PARTS = {   # part: the channel that lifts it off the floor
    "Head": "pel", "UpperTorso": "pel", "LowerTorso": "pel", "RightUpperArm": "pel", "LeftUpperArm": "pel", "RightUpperLeg": "pel", "LeftUpperLeg": "pel",
    "RightLowerLeg": "rf", "RightFoot": "rf", "LeftLowerLeg": "lf", "LeftFoot": "lf",
    "RightLowerArm": "rt", "RightHand": "rt", "LeftLowerArm": "lt", "LeftHand": "lt", "Weapon": "wrp",
}


def rest_on_floor(clip, ctrl, sigma=1.5, passes=4):
    """(2026-11-06) A falling body meets the floor and stops there. Each frame every body part (and a released weapon) is measured against the ground;
    what sinks through it is lifted by the channel that carries it - the pelvis for the trunk, the foot's lift for a shin, a free hand's reach for a forearm,
    the weapon's own rest for the glaive - smoothed over neighbouring frames so the contact eases on rather than popping."""
    rg = clip.rig
    n = len(ctrl)
    k = np.arange(-int(3 * sigma), int(3 * sigma) + 1)
    w = np.exp(-0.5 * (k / sigma) ** 2)
    w /= w.sum()
    chans = sorted(set(FLOOR_PARTS.values()))
    for _ in range(passes):
        need = {ch: np.zeros(n) for ch in chans}
        clip._side = {}
        for i, c in enumerate(ctrl):
            t2 = dict(c)
            _, world, _ = clip.solve(t2)
            for part, ch in FLOOR_PARTS.items():
                if ch in ("rt", "wrp") and float(c["wfree"]) < 0.05 or ch == "lt" and float(c["ltw"]) < 0.05:
                    continue
                deficit = GROUND + 0.01 - float(place(rg, world, part)[::3, 1].min())
                need[ch][i] = max(need[ch][i], deficit)
        clip._side = None
        if max(float(v.max()) for v in need.values()) < 0.005:
            return
        for ch, v in need.items():
            sm = np.zeros(n)
            for j, kk in enumerate(k):
                sm += w[j] * v[np.clip(np.arange(n) + kk, 0, n - 1)]
            sm = np.maximum(sm, v)
            for i, c in enumerate(ctrl):
                if sm[i] <= 0:
                    continue
                if ch in ("rf", "lf"):
                    f = np.array(c[ch], float)
                    f[2] += sm[i]
                    c[ch] = tuple(f)
                else:
                    c[ch] = tuple(np.asarray(c[ch], float) + np.array([0.0, sm[i], 0.0]))


def settle(clip, ctrl, sigma=2.0, passes=5):
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


REAR_SLIDE_MAX, REAR_SLIDE_GAP = 0.9, 1.0   # (2026-11-06) how far the rear hand may slide up the haft, and the least it leaves between the hands (rig units)
WRIST_BEND_MAX = 80.0   # (2026-11-06) how far the haft may lean off the rear forearm past the sculpt's own grip, degrees: what deviation, flexion and a diagonal grip together give


def wrist_yield(clip, ctrl, sigma=1.5, passes=3):
    """(2026-11-06) The rear hand and the weapon yield to the rear wrist. Where a pose lays the haft back along the right forearm (an arm stretched
    behind or above him, the weapon pointing the other way), no fist turn or elbow can hold it: the wrist would fold past 120 deg and the hand leave
    its cuff. First the rear hand slides up the haft toward the lead hand, as hands do in a slam - the weapon itself stays where it is, so the blade
    and its contacts do not move - which brings the fist in and lets the elbow bend. Only what that cannot cure tilts the haft about the fist toward
    the forearm. Both are smoothed across neighbouring frames so they ease in and out; the lead hand follows the haft."""
    rg = clip.rig
    n = len(ctrl)
    if n < 2:
        return False
    k = np.arange(-int(3 * sigma), int(3 * sigma) + 1)
    w = np.exp(-0.5 * (k / sigma) ** 2)
    w /= w.sum()
    f0 = unit(rg.JOINT["RightHand"] - rg.JOINT["RightLowerArm"])
    limit = math.degrees(math.acos(float(np.clip(f0 @ rg.HAFT0, -1, 1)))) + WRIST_BEND_MAX
    arm_len = float(np.linalg.norm(rg.ARM_U) + np.linalg.norm(rg.ARM_L))
    changed = False

    def spread(v):
        out = np.zeros_like(v)
        for j, kk in enumerate(k):
            idx = np.arange(n) + kk
            idx = idx % n if clip.loop else np.clip(idx, 0, n - 1)
            out += w[j] * v[idx]
        return out

    for _ in range(passes):
        slide = np.zeros(n)
        rot = np.zeros((n, 3))
        clip._side = {}
        for i, c in enumerate(ctrl):
            if float(c.get("wfree", 0.0)) >= 0.5:
                continue
            t2 = dict(c)
            _, world, _ = clip.solve(t2)
            E = (world["RightLowerArm"] @ np.append(rg.JOINT["RightLowerArm"], 1))[:3]
            W = (world["RightHand"] @ np.append(rg.JOINT["RightHand"], 1))[:3]
            f, h = unit(W - E), unit(t2["haft"])
            excess = math.degrees(math.acos(float(np.clip(f @ h, -1, 1)))) - limit
            if excess <= 0:
                continue
            S = (world["UpperTorso"] @ np.append(rg.JOINT["RightUpperArm"], 1))[:3]
            rp = np.asarray(t2["rp"], float)
            room = max(0.0, float(t2.get("_lsl", c["lsl"])) - float(c["rsl"]) - REAR_SLIDE_GAP)
            d = 0.0
            bent = float(np.linalg.norm(rp - S)) < 0.8 * arm_len      # the arm is already bent: sliding cannot help the elbow any more
            while not bent and d < min(room, REAR_SLIDE_MAX):     # slide until the arm can bend (well inside its reach) or the straight line from the shoulder is fine
                q = rp + h * d - S
                if float(np.linalg.norm(q)) < 0.8 * arm_len or math.degrees(math.acos(float(np.clip(unit(q) @ h, -1, 1)))) <= limit - 10.0:
                    break
                d += 0.05
            slide[i] = d
            if bent or d >= min(room, REAR_SLIDE_MAX) - 1e-6:     # bent already, or the slide ran out: tilt for the rest, about a well-defined axis even when haft and forearm are nearly opposite
                ax = np.cross(h, f)
                if np.linalg.norm(ax) < 0.25:
                    ax = np.cross(h, np.array([0.0, 1.0, 0.0])) if abs(h[1]) < 0.9 else np.cross(h, np.array([1.0, 0.0, 0.0]))
                rot[i] = unit(ax) * math.radians(min(excess + 2.0, 30.0))
        clip._side = None
        if float(slide.max()) < 1e-3 and float(np.abs(rot).max()) < 1e-3:
            break
        ss = np.maximum(spread(slide), slide)
        sr = spread(rot)
        sr = np.maximum(np.linalg.norm(sr, axis=1), np.linalg.norm(rot, axis=1))[:, None] * np.array([unit(v) if np.linalg.norm(v) > 1e-9 else v for v in sr])
        for i, c in enumerate(ctrl):
            h = unit(c["haft"])
            if ss[i] > 1e-4:
                c["rp"] = tuple(np.asarray(c["rp"], float) + h * ss[i])
                c["rsl"] = float(c["rsl"]) + ss[i]
            if np.linalg.norm(sr[i]) > 1e-6:
                Rr = rodrigues(sr[i])
                c["haft"] = tuple(Rr @ h)
                c["face"] = tuple(Rr @ unit(c["face"]))
                if float(c["rlk"]) > 0:
                    c["rhx"] = tuple(Rr @ unit(c["rhx"]))
        changed = True
    return changed


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
    arms = (("rpole", "rhand", "_rgrip", rg.HAFT0, rg.GRIP0 - rg.JOINT["RightHand"], "relb", rg.ARM_U, rg.ARM_L, rg.ELBOW0, "Right"),
            ("lpole", "lhand", "_lgrip", rg.LAX0, rg.PALM0 - rg.JOINT["LeftHand"], "lelb", rg.LARM_U, rg.LARM_L, rg.LELBOW0, "Left"))
    G, E = len(GRIP_TURNS) * len(GRIP_SLANTS), len(ELBOW_TURNS)
    for key, hkey, gkey, axis0, v0, pole_key, u0, l0, pole0, hand_side in arms:
        live = [i for i in range(n) if gkey in needs[i]]
        if not live:
            continue
        costs = {}
        quats = {}
        hands = {}
        poles = {}
        twists = {}
        rels = {}
        scratch = {}
        for i in live:
            S, grip, axis, core = needs[i][gkey]
            P, _ = weapon_cloud(rg, needs[i])
            P = P[np.linalg.norm(P - S, axis=1) < float(np.linalg.norm(u0) + np.linalg.norm(l0)) + 0.6]     # only what this arm can reach: arm_clash looks 0.25 past its capsules
            place = weapon_place(rg, needs[i])
            C = np.zeros((G, E))
            Qi = np.zeros((G, 4))
            Hi = []
            pole_base = unit(needs[i][pole_key])
            Pi = np.zeros((G, E, 3))
            Ti = np.zeros((G, E))
            # (2026-11-08) each elbow turn's arm in his torso (with the untilted grip's wrist: the turns of the fist move the wrist a few hundredths),
            # so the elbow keeps the arm out of his chest where the hand allows it (clear_torso moves the hands for what is left)
            tor = np.zeros(E)
            if "_chest" in needs[i] and "_pelvis" in needs[i]:
                Rh0 = short_arc(slanted(rg, axis0, hand_side, 0.0), axis)
                w0 = grip - Rh0 @ v0
                d0 = unit(w0 - S)
                k0 = orth(pole_base, d0)
                s0 = np.cross(d0, k0)
                for e, a in enumerate(ELBOW_TURNS):
                    ar = math.radians(a)
                    ru0_, rl0_, reached0 = two_bone(S, w0, u0, l0, pole0, k0 * math.cos(ar) + s0 * math.sin(ar), "x", {"x": 0.0})
                    el0 = S + ru0_ @ u0
                    tor[e] = arm_torso_pose(rg, hand_side, {hand_side + "UpperArm": (ru0_, S), hand_side + "LowerArm": (rl0_, el0), hand_side + "Hand": (Rh0, w0),
                                                            "UpperTorso": needs[i]["_chest"], "LowerTorso": needs[i]["_pelvis"]})
            torc = TORSO_COST * np.maximum(0.0, tor - ARM_TORSO_REST)
            for g in range(G):
                slant = GRIP_SLANTS[g // len(GRIP_TURNS)]
                Rh = rodrigues(axis * GRIP_TURNS[g % len(GRIP_TURNS)]) @ short_arc(slanted(rg, axis0, hand_side, slant), axis)
                Hi.append(Rh)
                Qi[g] = ZR.quat(Rh)
                wrist = grip - Rh @ v0
                hclash = hand_clash(rg, hand_side, Rh, wrist, place)     # the hand rides the haft: one look per grip turn
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
                    wp = wrist_parts(rg, (rodrigues(f * math.radians(phi)) @ rl).T @ Rh, hand_side)
                    clash = max(hclash, arm_clash(rg, hand_side, S, elbow, reached, P, ru, rodrigues(f * math.radians(phi)) @ rl, place, chest=needs[i].get("_chest"), hand_pose=(Rh, wrist)))     # (2026-11-07) an arm never passes through the weapon it holds, nor the weapon through it
                    C[g, e] = CLASH_COST * clash + CLASH_HARD * max(0.0, clash - CLASH_GRAZE) + bend + 0.3 * max(0.0, bend - 55.0) + 1.6 * max(0.0, bend - 85.0) + 0.1 * abs(a) + 0.08 * abs(phi) + 90.0 * inside + 200.0 * scratch["x"] + wrist_cost(wp) + 0.4 * abs(slant) + torc[e]
            costs[i], quats[i], hands[i], poles[i], twists[i] = C, Qi, Hi, Pi, Ti
            rels[i] = np.array([ZR.quat(place[0].T @ Rh) for Rh in Hi])     # the same grips in the weapon's own frame

        # (2026-11-07) the lead hand is a loose ring on the haft: in a cut the wood turns inside it (a regrip), so its turn costs less than the fist's
        turn_cost = LEAD_TURN_COST if hand_side == "Left" and clip.priority not in ("Idle", "Movement") else 0.4
        roll_step, elbow_step = (45.0, 75.0) if clip.priority in ("Idle", "Movement") else STEP_LIMITS_ACTION
        grip_step = GRIP_STEP_HOLD if clip.priority in ("Idle", "Movement") else GRIP_STEP_ACTION
        step_cost = GRIP_STEP_COST if hand_side == "Left" else 600.0
        # (2026-11-08) a frame beside a run on the haft but not in it (the lead hand going to or from a reach) takes that run's end turn, so the hand it
        # shows (that grip carried toward the reach, solve) hangs on the choice there: each such frame out to the reach alone is costed onto the run's
        # end like a step between held frames, turn for turn and with the same wall (phase 2 Guandao_Heavy f15: the hand left the haft 145 deg off its
        # grip in a frame when nothing asked the grip to turn toward where the reach goes)
        lset = set(live)
        if hand_side == "Left":
            for i in live:
                for way in (-1, 1):
                    prev_q, nb = quats[i], i + way
                    while 0 <= nb < n and nb not in lset and min(live, key=lambda q: abs(q - nb)) == i and needs[nb].get("_lvis", (0.0, None))[1] is not None:
                        m, Rr = needs[nb]["_lvis"]
                        qr = ZR.quat(Rr)
                        now_q = np.array([ZR.slerp(q, qr, m) for q in quats[i]])
                        Tb = np.degrees(2 * np.arccos(np.abs(np.sum(prev_q * now_q, axis=1)).clip(0.0, 1.0)))
                        costs[i] = costs[i] + (0.4 * Tb + step_cost * (Tb > grip_step))[:, None]
                        if m >= 1.0:
                            break
                        prev_q, nb = now_q, nb + way

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
                Tw = np.degrees(2 * np.arccos(np.abs(rels[p] @ rels[i].T).clip(0.0, 1.0)))
                flip = np.repeat(np.repeat(step_cost * (np.minimum(Tg, Tw) > grip_step), E, axis=0), E, axis=1)     # (2026-11-08) see GRIP_STEP_ACTION
                pa, pb = poles[p].reshape(-1, 3), poles[i].reshape(-1, 3)
                Te = np.degrees(np.arccos(np.clip(pa @ pb.T, -1.0, 1.0)))
                Tr = np.abs(twists[p].ravel()[:, None] - twists[i].ravel()[None, :])
                step = total[:, None] + turn_cost * np.repeat(np.repeat(Tg, E, axis=0), E, axis=1) + 0.35 * Te + 0.35 * Tr + 600.0 * (Tr > roll_step) + 600.0 * (Te > elbow_step) + flip    # a forearm or elbow can't whip round in a frame, whatever the wrist would save
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
        sl = np.zeros(n)
        for i in range(n):
            k = i if i in path else min(live, key=lambda q: abs(q - i))
            g, e = path[k]
            Q[i] = quats[k][g]
            sl[i] = GRIP_SLANTS[g // len(GRIP_TURNS)]
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
            c[hkey + "_slant"] = float(sum(w * sl[(i + off) % (n - 1) if clip.loop else min(max(i + off, 0), n - 1)] for off, w in zip(range(-2, 3), kernel)))
            c[key + "_roll"] = float(sum(w * ro[(i + off) % (n - 1) if clip.loop else min(max(i + off, 0), n - 1)] for off, w in zip(range(-2, 3), kernel)))
        # (2026-11-07) the smoothing is never allowed to carry an arm back into the weapon: every frame is solved as smoothed and measured on the real
        # surfaces, and where the arm is in the wood past a graze that frame takes the path's own choice, its neighbours half of it, so nothing pops
        Q_raw = np.array([quats[i if i in path else min(live, key=lambda q: abs(q - i))][path[i if i in path else min(live, key=lambda q: abs(q - i))][0]] for i in range(n)])
        fixed = 0
        for i in live:
            if smoothed_arm_clash(clip, ctrl[i], hand_side) <= CLASH_GRAZE:
                continue
            for j, wgt in ((i, 1.0), (i - 1, 0.5), (i + 1, 0.5)):
                if not 0 <= j < n:
                    continue
                c = ctrl[j]
                q0, q1 = ZR.quat(c[hkey]), Q_raw[j]
                q1 = q1 if float(q0 @ q1) >= 0 else -q1
                c[hkey] = ZR.mat(unit(q0 * (1 - wgt) + q1 * wgt))
                c[key] = unit(np.asarray(c[key]) * (1 - wgt) + el[j] * wgt)
                c[hkey + "_slant"] = float(c[hkey + "_slant"] * (1 - wgt) + sl[j] * wgt)
                c[key + "_roll"] = float(c[key + "_roll"] * (1 - wgt) + ro[j] * wgt)
            fixed += 1
        if fixed:
            clip._swivel_unsmoothed = getattr(clip, "_swivel_unsmoothed", 0) + fixed


FREE_ARM_SWINGS = np.arange(5.0, 125.0, 5.0)     # degrees a reaching arm may swing about the shoulder, away from the haft, to keep out of the wood


def clear_free_arm(clip, ctrl, sigma=2.5):
    """(2026-11-07) The lead arm off the haft (reaching for a point while the other hand swings the weapon) is placed by its keyed target alone, and the
    haft's far end can sweep through it. Each such frame is solved and measured on the real surfaces. Where the arm is in the weapon past a graze, the
    reach swings about the shoulder: one way in the chest's own frame and one angle for the whole passage, eased in and out around it, the smallest that
    clears every frame of it (frame-by-frame answers disagree, and averaging them clears nothing). The arm moves out of the haft's way as one gesture."""
    rg = clip.rig
    n = len(ctrl)
    free = [i for i, c in enumerate(ctrl) if float(c.get("ltw", 0.0)) >= 0.05 and float(c["ltw"]) >= float(c.get("lhw", 0.0))]
    bad = [i for i in free if smoothed_arm_clash(clip, ctrl[i], "Left") > CLASH_GRAZE]
    if not bad:
        return
    env = np.zeros(n)
    for j in bad:
        env = np.maximum(env, np.exp(-0.5 * ((np.arange(n) - j) / sigma) ** 2))
    # (2026-11-08) by the reach's share of the hand-over, not cut off where the haft's weight passes the reach's: the arm is part reach until the
    # grip has it all (solve blends them), and cut there its target swung 1.9 back in a frame (phase 1 Guandao_Heavy f22, forearm 109 deg)
    env *= np.array([float(c.get("ltw", 0.0)) / max(float(c.get("ltw", 0.0)) + float(c.get("lhw", 0.0)), 1e-6) for c in ctrl])
    look = [i for i in range(n) if env[i] > 0.05]
    chest = {}
    keep = clip._side
    clip._side = {}
    try:
        for i in look:
            chest[i] = clip.solve(dict(ctrl[i]))[1]["UpperTorso"][:3, :3]
    finally:
        clip._side = keep

    def trial(axis, deg):
        worst = 0.0
        out = {}
        for i in look:
            t2 = dict(ctrl[i])
            Rc = chest[i]
            t2["lt"] = tuple(Rc @ rodrigues(axis * math.radians(deg * env[i])) @ Rc.T @ np.asarray(ctrl[i]["lt"], float))
            worst = max(worst, smoothed_arm_clash(clip, t2, "Left"))
            out[i] = t2["lt"]
        return worst, out
    axes = [unit(np.array(v, float)) for v in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1), (1, 1, 0), (1, -1, 0), (-1, 1, 0), (-1, -1, 0),
                                                (0, 1, 1), (0, 1, -1), (0, -1, 1), (0, -1, -1), (1, 0, 1), (1, 0, -1), (-1, 0, 1), (-1, 0, -1))]
    start = max(smoothed_arm_clash(clip, ctrl[i], "Left") for i in bad)
    best = (start, 0.0, None, None)
    for deg in FREE_ARM_SWINGS:
        for ax in axes:
            worst, lts = trial(ax, deg)
            if worst < best[0] - 1e-4:
                best = (worst, deg, ax, lts)
        if best[0] <= CLASH_GRAZE:
            break
    if best[2] is None:
        return
    for i, lt in best[3].items():
        ctrl[i]["lt"] = lt
    clip._free_arm_cleared = (len(bad), round(start, 3), round(best[0], 3), float(best[1]))
    if os.environ.get("SHEN_DEBUG_FREE"):
        print("free arm: %d frames, %.3f -> %.3f by %.0f deg about %s" % (len(bad), start, best[0], best[1], np.round(best[2], 2)))


FIST_SLIDE = np.arange(0.04, 0.6, 0.04)     # how far (rig units) the right fist may run down the haft toward the butt to keep the wood behind it out of an arm
BUTT_HOLD = 0.25     # the fist stays this far up from the butt's end (its own half width and the end cap)


def slide_fist(clip, ctrl, sigma=2.5):
    """(2026-11-07) Where the haft behind the right fist (between fist and butt) still runs into an arm, the fist slides down the haft toward the butt by
    the least that clears it, as a guandao grip does to lengthen a cut. The fist stays where it is and the weapon runs through it, so neither arm moves:
    the wood past the fist shortens. Spread over the neighbouring frames (never below what a frame needs) so the slide is one motion."""
    rg = clip.rig
    n = len(ctrl)
    floor = float(rg.WCLOUD_S.min()) + BUTT_HOLD
    def worst(c):     # both arms (the wood behind the fist sweeps past the free lead arm as well as the one holding it), and his hip and belt
        return held_clash(clip, c)
    need = np.zeros(n)
    for i, c in enumerate(ctrl):
        if float(c.get("wfree", 0.0)) > 0.01:
            continue
        v0 = worst(c)
        if v0 <= CLASH_GRAZE:
            continue
        best = (v0, 0.0)
        for k in FIST_SLIDE:
            if float(c["rsl"]) - k < floor:
                break
            t2 = dict(c)
            t2["rsl"] = float(c["rsl"]) - k
            v = worst(t2)
            if v < best[0] - 1e-4:
                best = (v, k)
            if v <= CLASH_GRAZE:
                break
        need[i] = best[1]
    if not need.any():
        return
    for i, c in enumerate(ctrl):
        f = np.exp(-0.5 * ((np.arange(n) - i) / sigma) ** 2)
        k = float((need * f).max())
        if k > 1e-4:
            c["rsl"] = max(floor, float(c["rsl"]) - k)
    clip._fist_slid = (int((need > 0).sum()), round(float(need.max()), 3))
    if os.environ.get("SHEN_DEBUG_FREE"):
        print("fist slide: %d frames, up to %.2f" % clip._fist_slid)


HAFT_TILTS = np.arange(3.0, 33.0, 3.0)     # degrees the haft may tip about the fist to pass an arm instead of going through it
TILT_NEAR_CONTACT = 0.1     # seconds either side of a contact where the blade's line is left exactly as keyed


def tilt_haft(clip, ctrl, times):
    """(2026-11-07) In a twirl the haft wheels about the fist, and on each turn its length sweeps through the arm that holds it; neither the grip turn
    nor the elbow (swivel) can take an arm out of a plane the weapon sweeps, and moving the weapon drags the fist and the arm with it. So where an arm
    is still in the weapon past a graze, the haft tips about the fist, square to itself, by the least of HAFT_TILTS that clears both arms: the weapon
    passes beside the arm, as a real twirl does. The direction is found frame by frame (it turns with the haft); the tilts are then smoothed and any
    frame the smoothing put back into an arm keeps its own. Frames near a contact are left alone."""
    n = len(ctrl)

    def worst(c):
        return held_clash(clip, c)

    def tipped(c, rv):
        ang = float(np.linalg.norm(rv))
        t2 = dict(c)
        if ang > 1e-6:
            R = rodrigues(rv)
            t2["haft"], t2["face"] = tuple(R @ unit(c["haft"])), tuple(R @ unit(c["face"]))
        return t2
    near = [any(abs(t - k) < TILT_NEAR_CONTACT for k in clip.contacts) for t in times]
    rv = np.zeros((n, 3))
    base = [0.0] * n
    for i, c in enumerate(ctrl):
        if near[i] or float(c.get("wfree", 0.0)) > 0.01:
            continue
        base[i] = v0 = worst(c)
        if v0 <= CLASH_GRAZE:
            continue
        h = unit(c["haft"])
        e1 = unit(np.cross(h, (0.0, 1.0, 0.0)) if abs(h[1]) < 0.95 else np.cross(h, (1.0, 0.0, 0.0)))
        e2 = np.cross(h, e1)
        best = (v0, np.zeros(3))
        for deg in HAFT_TILTS:
            for a in np.arange(8) * math.pi / 4:
                r = (e1 * math.cos(a) + e2 * math.sin(a)) * math.radians(deg)
                v = worst(tipped(c, r))
                if v < best[0] - 1e-4:
                    best = (v, r)
            if best[0] <= CLASH_GRAZE:
                break
        rv[i] = best[1]
    if not rv.any():
        return
    sm = rv.copy()
    for i in range(n):
        acc, wsum = np.zeros(3), 0.0
        for off, w in ((-2, 1.0), (-1, 2.0), (0, 3.0), (1, 2.0), (2, 1.0)):
            k = min(max(i + off, 0), n - 1)
            if not near[k]:
                acc, wsum = acc + w * rv[k], wsum + w
        sm[i] = acc / wsum if wsum > 0 and not near[i] else 0.0
    done = 0
    for i, c in enumerate(ctrl):
        if near[i] or not sm[i].any() and not rv[i].any():
            continue
        t2 = tipped(c, sm[i])
        if rv[i].any() and worst(t2) > max(CLASH_GRAZE, worst(tipped(c, rv[i]))):
            t2 = tipped(c, rv[i])
        c["haft"], c["face"] = t2["haft"], t2["face"]
        done += 1
    clip._haft_tilted = (int((np.linalg.norm(rv, axis=1) > 0).sum()), round(float(np.degrees(np.linalg.norm(rv, axis=1).max())), 1))
    if os.environ.get("SHEN_DEBUG_FREE"):
        print("haft tilt: %d frames need it, up to %.0f deg; %d frames changed" % (clip._haft_tilted + (done,)))


ARM_TORSO_REST = 0.14     # (2026-11-08) arm skin this deep in his torso's real surface is an arm resting against him: both idles hang the upper arms
                          # 0.12-0.14 into the side of the chest, under the arm and unseen. Past it an arm is going through him (clear_torso)
ARM_TORSO_PUSH = np.arange(0.04, 0.64, 0.04)      # how far (rig units) the hands may come out from his chest to take an arm out of it
ARM_TORSO_DIRS = [unit(np.array(v, float)) for v in ((0, 0, -1), (0, 0.5, -1), (0, -0.5, -1), (0.6, 0, -1), (-0.6, 0, -1), (1, 0, -0.3), (-1, 0, -0.3),
                                                     (0.6, 0.5, -1), (-0.6, 0.5, -1), (0.6, -0.5, -1), (-0.6, -0.5, -1))]     # in the chest's own frame: his front is -z


def _torso_free(rg, part, torso):
    """The skin of an arm part at least 0.05 clear of a torso solid in the bind pose (what lies at or in it there is the sculpt's own join)."""
    cache = rg.__dict__.setdefault("_torso_free", {})
    if (part, torso) not in cache:
        cache[(part, torso)] = sdf_depth(rg, torso, rg.SKIN[part][0]) < -0.05
    return cache[(part, torso)]


def arm_torso_world(rg, world, pose=None):
    """(2026-11-08) How deep each arm's skin (hand, forearm, upper arm, blended as the game skins them) sits inside his torso's real surface
    (UpperTorso and LowerTorso distance fields), counting only skin clear of that solid in the bind pose. {"Right": depth, "Left": depth}, 0 when clear."""
    pose = pose or pose_of(rg, world)
    out = {}
    for side in ("Right", "Left"):
        m = 0.0
        for part in (side + "UpperArm", side + "LowerArm", side + "Hand"):
            W = world[part]
            B = body_points(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], pose)
            for t in ("UpperTorso", "LowerTorso"):
                keep = _torso_free(rg, part, t)
                if keep.any():
                    Wt = world[t]
                    m = max(m, float(part_depth(rg, t, Wt[:3, :3], (Wt @ np.append(rg.JOINT[t], 1))[:3], B[keep]).max()))
        out[side] = max(0.0, m)
    return out


def arm_torso_pose(rg, side, pose, stride=3):
    """(2026-11-08) arm_torso_world() for one arm from its bones alone (pose: {part: (world rotation, joint)} with the arm's parts, UpperTorso and
    LowerTorso), on every stride-th skin point: what swivel() weighs each elbow turn by."""
    m = 0.0
    for part in (side + "UpperArm", side + "LowerArm", side + "Hand"):
        if part not in pose:
            continue
        P, mix = rg.SKIN[part]
        P = P[::stride]
        R, at = pose[part]
        X = np.zeros_like(P)
        for bone, w in mix:
            w = np.broadcast_to(np.asarray(w, float), (len(rg.SKIN[part][0]),))[::stride]
            if bone == part or bone not in pose:
                Rb, ab, jb = R, at, rg.JOINT[part]
            else:
                (Rb, ab), jb = pose[bone], rg.JOINT[bone]
            X += w[:, None] * ((P - jb) @ Rb.T + ab)
        for t in ("UpperTorso", "LowerTorso"):
            keep = _torso_free(rg, part, t)[::stride]
            if keep.any():
                Rt, att = pose[t]
                m = max(m, float(part_depth(rg, t, Rt, att, X[keep]).max()))
    return max(0.0, m)


TORSO_COST = 600.0    # (2026-11-08) swivel cost per rig unit an arm sits in his torso past ARM_TORSO_REST, as an arm in the weapon (CLASH_COST)


def arm_torso(clip, c):
    """arm_torso_world() once control set c is solved."""
    keep = clip._side
    clip._side = {}
    try:
        _, world, _ = clip.solve(dict(c))
    finally:
        clip._side = keep
    return arm_torso_world(clip.rig, world)


def clear_torso(clip, ctrl, times, sigma=2.5):
    """(2026-11-08) Nothing kept his arms out of his own body: the weapon was kept out of him and the arms out of the weapon, and phase 2's broader chest
    took the fist at the butt and the forearm behind it 0.19 and 0.38 into him in the Heavy's follow-through (f18), with every elbow turn still 0.31 in.
    Where an arm is in his torso past ARM_TORSO_REST the hands come out from his chest: for the arms on the weapon the whole weapon moves (its fist
    point, rp), for a lead arm reaching off the haft its target (lt). One direction in the chest's own frame and one distance for the whole passage,
    eased in and out around it, the least that clears every frame of it, as clear_free_arm swings a reach. A move that puts an arm in the weapon (or the
    weapon in him) deeper than it was, or loses a grip, is not taken. Frames near a contact keep the weapon as keyed."""
    n = len(ctrl)
    if n == 0:
        return
    near = np.array([min([abs(t - k) for k in clip.contacts] or [9.0]) for t in times])
    gate = np.array([smooth01((x - TILT_NEAR_CONTACT) / 0.1) for x in near])     # nothing at a contact, all of it 0.1 s past the window
    holding = [float(c.get("lhw", 0.0)) > 0.0 and float(c.get("lhw", 0.0)) >= float(c.get("ltw", 0.0)) for c in ctrl]
    held = [float(c.get("wfree", 0.0)) <= 0.01 for c in ctrl]
    reaching = [float(c.get("ltw", 0.0)) >= 0.05 and not holding[i] for i, c in enumerate(ctrl)]
    deep = [arm_torso(clip, c) for c in ctrl]
    done = []
    for key, need, guard, gated in (
            ("rp", lambda i, d: max(d["Right"], d["Left"] if holding[i] else 0.0) if held[i] else 0.0, lambda c: held_clash(clip, c), True),
            ("lt", lambda i, d: d["Left"] if reaching[i] else 0.0, lambda c: smoothed_arm_clash(clip, c, "Left"), False)):
        bad = [i for i in range(n) if need(i, deep[i]) > ARM_TORSO_REST]
        clusters = []
        for i in bad:
            if clusters and i - clusters[-1][-1] <= 6:
                clusters[-1].append(i)
            else:
                clusters.append([i])
        for group in clusters:
            env = np.zeros(n)
            for j in group:
                env = np.maximum(env, np.exp(-0.5 * ((np.arange(n) - j) / sigma) ** 2))
            if gated:
                env *= gate
            if key == "lt":     # a reach is only part of the arm until the grip has none of it (solve blends them)
                env *= np.array([float(c.get("ltw", 0.0)) / max(float(c.get("ltw", 0.0)) + float(c.get("lhw", 0.0)), 1e-6) for c in ctrl])
            look = [i for i in range(n) if env[i] > 0.02]
            if not look:
                continue
            keep = clip._side
            clip._side = {}
            try:
                chest = {i: clip.solve(dict(ctrl[i]))[1]["UpperTorso"][:3, :3] for i in look}
            finally:
                clip._side = keep
            judged = [i for i in look if env[i] >= 0.5]     # what this move can clear; the rest of the passage only eases it in and out
            if not judged:
                continue
            start = max(need(i, deep[i]) for i in judged)
            base_guard = {i: guard(ctrl[i]) for i in look}

            def moved(dvec, m):
                return {i: tuple(np.asarray(ctrl[i][key], float) + chest[i] @ dvec * (m * env[i])) for i in look}

            def worst_of(vals):     # the passage's worst, and no eased frame left deeper than it was
                out = 0.0
                for i in look:
                    t2 = dict(ctrl[i])
                    t2[key] = vals[i]
                    v = need(i, arm_torso(clip, t2))
                    if i in judged:
                        out = max(out, v)
                    elif v > max(need(i, deep[i]), ARM_TORSO_REST) + 0.01:
                        return 9.0
                return out

            def safe(vals):
                for i in look:
                    t2 = dict(ctrl[i])
                    t2[key] = vals[i]
                    g = guard(t2)
                    if g >= GRIP_FAIL or g > max(base_guard[i], CLASH_GRAZE) + 1e-3:
                        return False
                return True
            best = (start, 0.0, None, None)
            for m in ARM_TORSO_PUSH:
                for dvec in ARM_TORSO_DIRS:
                    vals = moved(dvec, m)
                    v = worst_of(vals)
                    if os.environ.get("SHEN_DEBUG_TORSO"):
                        print("  try %s m %.2f dir %s -> %.3f (start %.3f, judged %s)" % (key, m, np.round(dvec, 2), v, start, judged))
                    if v < best[0] - 0.01 and safe(vals):
                        best = (v, float(m), dvec, vals)
                if best[0] <= ARM_TORSO_REST:
                    break
            if best[3] is None:
                continue
            for i, v in best[3].items():
                ctrl[i][key] = v
            done.append((key, group[0], group[-1], round(start, 3), round(best[0], 3), round(best[1], 2)))
    clip._torso_cleared = done
    if os.environ.get("SHEN_DEBUG_FREE"):
        for d in done:
            print("torso: %s f%d-%d %.3f -> %.3f by %.2f" % d)


BODY_IN_WEAPON = 0.03     # his body's skin may touch the wood this deep (the mesh check's margin) before the post passes act
GRIP_FAIL = 1.0     # what a candidate that loses a hand's grip (an arm short of the haft) counts as


def held_clash(clip, c):
    """(2026-11-07) Once control set c is solved: the deepest either arm sits in the weapon or the weapon in it, his skinned body and legs in the
    weapon past BODY_IN_WEAPON, and GRIP_FAIL when a hand no longer reaches the haft or a wrist turns past WRIST_LIMIT. One solve for all of it."""
    rg = clip.rig
    keep = clip._side
    clip._side = {}
    try:
        _local, world, diag = clip.solve(dict(c))
    finally:
        clip._side = keep
    if diag.get("arm_reach", 0.0) > 0.1 or diag.get("left_grip", 0.0) > 0.1:
        return GRIP_FAIL
    # nor one that turns a wrist past what validate() allows (a 30 deg tip of the haft once turned the fist 154 deg on the arm, Heavy)
    if float(ZR.angle_of(_local["RightHand"][:3, :3])) > WRIST_LIMIT or (float(c.get("lhw", 0.0)) >= 0.99 and float(ZR.angle_of(_local["LeftHand"][:3, :3])) > WRIST_LIMIT):
        return GRIP_FAIL
    G = world["Glaive"]
    place = (G[:3, :3], G[:3, 3] + G[:3, :3] @ rg.WGRIP)
    P = (rg.WDENSE @ G[:3, :3].T) + place[1]
    chest = (world["UpperTorso"][:3, :3], (world["UpperTorso"] @ np.append(rg.JOINT["UpperTorso"], 1))[:3])
    out = 0.0
    for side in ("Right", "Left"):
        j = [(world[k] @ np.append(rg.JOINT[k], 1))[:3] for k in (side + "UpperArm", side + "LowerArm", side + "Hand")]
        out = max(out, arm_clash(rg, side, j[0], j[1], j[2], P, world[side + "UpperArm"][:3, :3], world[side + "LowerArm"][:3, :3], place, world[side + "Hand"][:3, :3], chest))
    pose = pose_of(rg, world)
    for part in BODY_SOLIDS + LEG_SOLIDS:
        W = world[part]
        B = body_points(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], pose)
        out = max(out, float(weapon_depth(rg, place[0], place[1], B).max()) - (BODY_IN_WEAPON - CLASH_GRAZE))     # over the graze once past BODY_IN_WEAPON
    # (2026-11-08) and the arms' own skin in the wood, as validate measures it (bare: no allowance): tilting the haft for the fist put it back through
    # the free forearm (phase 1 Guandao_Heavy f17, 0.053) where no haft point lay inside the forearm to show it
    for part in ("RightUpperArm", "RightLowerArm", "LeftUpperArm", "LeftLowerArm"):
        W = world[part]
        B = body_points(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], pose)
        out = max(out, float(weapon_depth_rest(rg, (B - G[:3, 3]) @ G[:3, :3]).max()))
    return max(0.0, out)


def smoothed_arm_clash(clip, c, side):
    """How deep this arm (upper arm, forearm, hand past its grip) sits in the weapon, or the weapon in it, once control set c is solved."""
    rg = clip.rig
    keep = clip._side
    clip._side = {}
    try:
        _, world, _ = clip.solve(dict(c))
    finally:
        clip._side = keep
    j = [(world[k] @ np.append(rg.JOINT[k], 1))[:3] for k in (side + "UpperArm", side + "LowerArm", side + "Hand")]
    G = world["Glaive"]
    place = (G[:3, :3], G[:3, 3] + G[:3, :3] @ rg.WGRIP)
    P = place_points = (rg.WDENSE @ G[:3, :3].T) + place[1]
    chest = (world["UpperTorso"][:3, :3], (world["UpperTorso"] @ np.append(rg.JOINT["UpperTorso"], 1))[:3])
    worst = arm_clash(rg, side, j[0], j[1], j[2], place_points, world[side + "UpperArm"][:3, :3], world[side + "LowerArm"][:3, :3], place, world[side + "Hand"][:3, :3], chest)
    # (2026-11-08) and the arm's own skin in the wood, as validate measures it: a free forearm crossing the haft's thin neck lay 0.053 inside it
    # (phase 1 Guandao_Heavy f17) with no haft point inside the forearm to show it, so nothing moved it
    pose = pose_of(rg, world)
    for part in (side + "UpperArm", side + "LowerArm"):
        W = world[part]
        B = body_points(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], pose)
        worst = max(worst, float(weapon_depth_rest(rg, (B - G[:3, 3]) @ G[:3, :3]).max()))
    return worst


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
            d = palm - (rg.lead_point(c["rp"], c["haft"], c["face"], float(c.get("_lsl", c["lsl"])), float(c["rsl"])) - ax * float(c.get("_lsl", c["lsl"])))
            w["left_off_haft"] = max(w["left_off_haft"], float(np.linalg.norm(d - ax * np.dot(d, ax))))
            fist_ = (world["RightHand"] @ np.append(rg.GRIP0, 1))[:3]
            w["hand_spacing"] = round(min(w.get("hand_spacing", 9.0), float(np.dot(palm - fist_, ax))), 3)   # the solver slides an out-of-reach lead hand back toward the fist
            w["wrist_left"] = max(w.get("wrist_left", 0.0), float(ZR.angle_of(local["LeftHand"][:3, :3])))
        P = place(rg, world, "Weapon")[::6]     # (2026-11-07) the weapon inside an arm or his body, measured on the real surfaces
        G = world["Glaive"]
        PD = rg.WDENSE @ G[:3, :3].T + G[:3, 3] + G[:3, :3] @ rg.WGRIP     # (2026-11-07) the arms against the dense surface: the butt cap fell between the thinned points
        for side in ("Right", "Left"):
            j = [(world[k] @ np.append(rg.JOINT[k], 1))[:3] for k in (side + "UpperArm", side + "LowerArm", side + "Hand")]
            k = "weapon_in_arm_" + side.lower()
            w[k] = max(w.get(k, 0.0), round(arm_clash(rg, side, j[0], j[1], j[2], PD, world[side + "UpperArm"][:3, :3], world[side + "LowerArm"][:3, :3]), 3))     # the weapon in the arm (the arm's own surface in the weapon is below)
        for part in BODY_SOLIDS + LEG_SOLIDS:
            k = "weapon_in_" + ("legs" if "Leg" in part else "torso")
            dep = float(part_depth(rg, part, world[part][:3, :3], (world[part] @ np.append(rg.JOINT[part], 1))[:3], P).max())
            w[k] = max(w.get(k, 0.0), round(max(0.0, dep), 3))
        # (2026-11-07) and his surface inside the weapon: arms bare, hands past the grip they are allowed
        G = world["Glaive"]
        pose = pose_of(rg, world)
        for part in BODY_SOLIDS + LEG_SOLIDS + ("RightUpperArm", "RightLowerArm", "LeftUpperArm", "LeftLowerArm", "RightHand", "LeftHand"):
            W = world[part]
            B = body_points(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], pose)
            dep = float(weapon_depth_rest(rg, (B - G[:3, 3]) @ G[:3, :3]).max()) - (HAND_GRIP if "Hand" in part else 0.0)
            k = "in_weapon_" + ("torso" if part in BODY_SOLIDS else "legs" if part in LEG_SOLIDS else "hands" if "Hand" in part else "arm_" + ("right" if "Right" in part else "left"))
            w[k] = max(w.get(k, 0.0), round(max(0.0, dep), 3))
        for side, v in arm_torso_world(rg, world, pose).items():     # (2026-11-08) his arms in his own torso (clear_torso)
            k = "arm_in_torso_" + side.lower()
            w[k] = max(w.get(k, 0.0), round(v, 3))
        fist = (world["RightHand"] @ np.append(rg.GRIP0, 1))[:3]
        d = fist - np.asarray(c["rp"], float)
        if float(c.get("wfree", 0.0)) < 0.01:     # a hand that has let go of the weapon is not off it
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
        if w.get("arm_in_torso_" + side, 0) > ARM_TORSO_REST + 0.04:
            problems.append("%s arm %.2f inside his torso" % (side, w["arm_in_torso_" + side]))
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
