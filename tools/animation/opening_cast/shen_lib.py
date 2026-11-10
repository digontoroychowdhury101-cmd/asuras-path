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
# (2026-11-09) how far a shoulder glides forward round his ribs as its hand crosses his front. The lead arm only: in the 15 phase 2 clips whose arms
# were in his chest, 0.35 on the lead arm took its worst from 0.295 avg to 0.208 (Strike 0.29 -> 0.16, Heavy 0.38 -> 0.21, Flourish 0.31 -> 0.14;
# Crimson Embrace and Rending Arc unmoved at 0.37-0.38); the fist's shoulder gliding as well moved its right arm both ways (L2 0.25 -> 0.20, Skyfall 0.21 -> 0.29, PostureBreak 0.10 -> 0.23)
XPRO = float(os.environ.get("SHEN_XPRO", "0.35"))
PRO_MEDIAL = float(os.environ.get("SHEN_PRO_MEDIAL", "0.0"))
PRO_SIDES = os.environ.get("SHEN_PRO_SIDES", "LR")
PRO_FLOOR = float(os.environ.get("SHEN_PRO_FLOOR", "0.1"))
PRO_YW = float(os.environ.get("SHEN_PRO_YW", "0.3"))
XPRO_DIR = [float(v) for v in os.environ.get("SHEN_XPRO_DIR", "0.3,0.15").split(",")]     # its share toward his middle and up, per unit forward
XPRO_SIDES = os.environ.get("SHEN_XPRO_SIDES", "L")     # which shoulders glide: L the lead (left) arm's, R the fist's


def protract_dir(Rch, want, side):
    """(2026-11-09) Which way a shoulder glides toward a hand out of reach: forward round the ribs, or out, a little up, but not in toward his middle.
    Straight at a hand across his front, the joint went 0.3 in toward his breastbone and took the upper arm into his chest with it (phase 2's Blood
    Wave f21-27 lead arm 0.37 deep, where moving the whole weapon 0.8 still left 0.22). side: +1 right arm, -1 left."""
    d = Rch.T @ unit(want)
    if ("R" if side > 0 else "L") in PRO_SIDES and -d[0] * side > 0.0:
        d[0] *= PRO_MEDIAL
    d = d * np.array([1.0, PRO_YW, 1.0])
    n = float(np.linalg.norm(d))
    return Rch @ (d / n) * min(1.0, n / PRO_FLOOR) if n > 1e-6 else np.zeros(3)


def cross_glide(Rch, shoulder, target, side):
    """(2026-11-09) A hand across his front takes the shoulder blade forward round the ribs with it (protraction): the joint glides forward
    (and a little in and up) by XPRO as the hand passes his middle line. side: +1 right arm, -1 left. World offset for the upper arm's joint."""
    if XPRO <= 0.0 or ("R" if side > 0 else "L") not in XPRO_SIDES:
        return np.zeros(3)
    d = Rch.T @ (np.asarray(target, float) - shoulder)
    medial = -d[0] * side        # how far toward (and past) his middle the hand is from this shoulder
    k = smooth01((medial - 0.3) / 0.6)
    if k <= 0.0:
        return np.zeros(3)
    return Rch @ unit(np.array([-XPRO_DIR[0] * side, XPRO_DIR[1], -1.0])) * XPRO * k
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
        # (2026-11-09) and every sample of the arms, for judging an arm in his torso (validate, joint_polish): on the thinned upper arm (every other
        # sample) a solve could leave the skin between the samples deep: phase 2's Crimson Embrace f48 measured 0.171 thinned, 0.199 on every
        # sample and 0.219 on the mesh itself (review.py's x-ray)
        self.SKIN_FULL = {}
        for part in ("RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand"):
            P, W, B = sk[part + "_P"].astype(float), sk[part + "_W"].astype(float), sk[part + "_B"]
            self.SKIN_FULL[part] = (P, [(bones[b], (W * (B == b)).sum(1)) for b in np.unique(B) if float((W * (B == b)).sum()) > 1e-6])
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


# (2026-11-09) channels interpolated as unit vectors. Only the blade's edge: cuts key it as a 2-degree difference of the haft (length 0.035), and
# splined against the guard's unit edge its direction swung ~90 deg for a frame at the end of most cuts. The haft and the elbow and knee poles were
# tried too: their keys' lengths shape the in-betweens, and unit keys put phase 2 Death's right arm back in his chest (0.14 -> 0.19, f40-44)
DIRECTION = {"face"}
FEET = {"rf", "lf"}
EASE = {
    "lin": lambda u: u, "in": lambda u: u * u, "out": lambda u: 1 - (1 - u) * (1 - u), "io": lambda u: u * u * (3 - 2 * u),
    "snap": lambda u: 1 - (1 - u) ** 3, "whip": lambda u: u * u * u,
}


ARM_SIDE_GAP, ARM_SIDE_W = 0.45, 2.0     # (2026-11-08) clear_body: a way out of his trunk whose fist leaves the right arm's line nearer his trunk's axis
                                         # than this is through him, weighed per rig unit as that much more travel
SIDE_CHANGE_COST = 0.35     # (2026-11-08) and the haft's leaving by the other side than last frame, as that much travel


CORRUPT_TWIST = [float(v) for v in os.environ.get("SHEN_CORRUPT_TWIST", "0,0").split(",")]


class Clip:
    rise_guard = False
    """Timed partial control keys, Catmull-Rom between them; a channel a key omits holds through. Phase 2's corruption (lower, forward, more torque) is a layer over the shared technique."""
    # (2026-11-09) per-clip opt-ins (shen_clips.build sets them; every other clip bakes exactly as before):
    # hold_start / hold_end {"Right"/"Left": (slant, grip turn, elbow turn)}: swivel's state for that hand on the clip's first / last frame (see
    # swivel), so the game's fades to and from Idle blend like with like; hold_entry: hold_start through the fade in (ENTRY_FADE) as well;
    # blow_envelope: wrist_yield eases a tilt at a blow over its neighbours at full height (see there); run_recheck: swivel's torso recheck walks
    # each run of frames past the wall as one (recheck_runs); (2026-11-10) recheck_spike: degrees a hand may turn between two frames in that walk
    # before each further degree costs RECHECK_SPIKE_COST; legs_guard: held_clash also weighs the weapon inside his legs (see there)
    hold_start = None
    hold_end = None
    hold_entry = False
    blow_envelope = False
    run_recheck = False
    recheck_spike = None
    legs_guard = False

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
        # (2026-11-09) a direction is interpolated as a unit vector: the cuts key the blade's edge as a 2-degree difference of the haft (length
        # 0.035), and splined against the guard's unit edge its direction swung, an edge turned 90 deg for one frame and back at the end of
        # nearly every cut (Strike f22, Feint f15, Rending Arc f64)
        vals = [unit(np.asarray(k[1], float)) if name in DIRECTION else np.asarray(k[1], float) for k in keyed]
        if t <= keyed[0][0]:
            return vals[0]
        if t >= keyed[-1][0]:
            return vals[-1]
        for i in range(len(keyed) - 1):
            t0, t1 = keyed[i][0], keyed[i + 1][0]
            if t <= t1:
                u = EASE[keyed[i + 1][2]]((t - t0) / (t1 - t0) if t1 > t0 else 1.0)
                p1, p2 = vals[i], vals[i + 1]
                if np.allclose(p1, p2, atol=1e-6):
                    out = p1
                else:
                    # (tangents scaled by the keys' spacing in time were tried: no edge flip they fixed that unit keys had not, and they changed
                    # every cut's return to the guard enough to put arms back in the chest in five clips that passed)
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
            c["pelR"] = c["pelR"] * np.array([1, 1 + CORRUPT_TWIST[0] * k, 1]) + np.array([6.0, 0, 0]) * k
            c["chest"] = c["chest"] * np.array([1, 1 + CORRUPT_TWIST[1] * k, 1]) + np.array([8.0, 0, 0]) * k
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
                    if ci < 2 and dist[i] < r:
                        # (2026-11-08) out of his trunk by the better of its two sides, weighing how far each is, whether the line from his right
                        # shoulder to the fist it leaves comes through him (ARM_SIDE_GAP from the trunk's axis), and a change of side from last frame
                        # (the haft cannot pass through him between frames). The nearest way out alone took phase 2's broader body left and behind:
                        # the Crescent Reap's fist, keyed in his chest by frames 6-10, went out to his right on frame 7 and his left on frame 8
                        # (a 1.3 hop, then his right arm 0.37 through his chest), the Cyclone's for the whole spin; the side kept from last frame
                        # held only within 0.24 of the axis
                        Sr = (Wc @ np.append(J["RightUpperArm"], 1))[:3]

                        def arm_gap(p):
                            q = rp + p
                            best_ = 9.0
                            for s_ in np.linspace(0.0, 1.0, 9):
                                x = Sr + (q - Sr) * s_
                                u_ = float(np.clip((x - A) @ d / max(float(d @ d), 1e-6), 0, 1))
                                best_ = min(best_, float(np.linalg.norm(x - (A + u_ * d))))
                            return best_
                        best_side = None
                        for sgn, need_ in ((1.0, r - float(dist[i])), (-1.0, r + float(dist[i]))):
                            pv = push * sgn
                            cost = need_ + ARM_SIDE_W * max(0.0, ARM_SIDE_GAP - arm_gap(pv * (need_ + 0.02)))
                            if prev is not None and abs(float(ss[i]) - prev[1]) < 0.8 and float(pv @ prev[0]) < 0:
                                cost += SIDE_CHANGE_COST
                            if best_side is None or cost < best_side[0]:
                                best_side = (cost, pv, need_)
                        push, worst = best_side[1], best_side[2]
                    # (2026-11-06) the haft cannot pass through him: the same stretch of it stays on the side it was on last frame, or the hands jump across
                    elif r + float(dist[i]) < 0.9 and prev is not None and abs(float(ss[i]) - prev[1]) < 0.8 and float(push @ prev[0]) < 0 and dist[i] < 0.5 * r:
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
        rpro = cross_glide(Rch, S, rp, 1)
        S = S + rpro
        away = rp - S
        far = float(np.linalg.norm(away))
        if far > arm_len:   # (2026-11-06) the right shoulder blade glides toward a fist out of reach first, up to PROTRACT
            extra = protract_dir(Rch, away, 1) * min(far - arm_len, PROTRACT)
            rpro = rpro + extra
            S = S + extra
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
        if hold > 0 or reach > 0:
            # (2026-11-09) by as much as the hand is on the haft or reaching: whole from the first hundredth of a regrip, the shoulder jumped
            lpro = cross_glide(Rch, SL, rg.lead_point(rp, haft, face, sl, rsl) if hold >= reach else SL + np.asarray(c["lt"], float), -1) * smooth01(max(hold, reach))
            SL = SL + lpro
        if hold > 0 and hold >= reach:
            maxr = float(np.linalg.norm(rg.LARM_U) + np.linalg.norm(rg.LARM_L)) * 0.98 + float(np.linalg.norm(v_l)) * 0.8
            # (2026-11-06) the shoulder blade glides: before the hand gives up its spot, the shoulder itself comes forward toward it (protraction), up to PROTRACT
            want = rg.lead_point(rp, haft, face, sl, rsl) - SL
            gap = float(np.linalg.norm(want)) - maxr
            if gap > 0:
                extra = protract_dir(Rch, want, -1) * min(gap, PROTRACT)
                lpro = lpro + extra
                SL = SL + extra
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
        # (2026-11-09) no settle here: smoothing the solver's corrections once more spread its neighbours' weapon over the frames clear_torso had
        # placed (phase 1's Death: right arm 0.02 -> 0.22 in his chest at f33) and changed no pop that depop does not take out
        if os.environ.get("SHEN_FINAL_SETTLE") == "1":
            settle(self, ctrl)
        depop(self, ctrl, times)
        close_loop(self, ctrl)
        joint_polish(self, ctrl, times)     # (2026-11-09) the runs of frames the passes above still leave past the wall, solved together (SLSQP)
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

    total = np.zeros((n, 2))     # (2026-11-09) what every pass has added so far: the limits hold for the sum, not for each pass
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
            # (2026-11-09) by as much as the hand is on the haft (its share of the arm, as left_grip weighs it): the whole step from the first
            # hundredth of a regrip turned the trunk its full limit while the hand was still mostly on its reach, and in phase 2's Crimson Embrace
            # (1.4-1.85 s) the chest, 50 deg round on his hips, carried the right shoulder past a fist out front: the right arm 0.37 into his back
            hold, reach = float(np.clip(c.get("lhw", 0.0), 0, 1)), float(np.clip(c.get("ltw", 0.0), 0, 1))
            share = hold * hold * (1.0 - (reach / (hold + reach) if reach > 0 else 0.0))
            add[i] = (-g0 * gy / norm * share, -g0 * gp / norm * share)
        if not add.any():
            return
        smooth = np.zeros_like(add)
        for j, kk in enumerate(k):
            idx = np.arange(n) + kk
            idx = idx % n if clip.loop else np.clip(idx, 0, n - 1)
            smooth += w[j] * add[idx]
        for i, c in enumerate(ctrl):
            # (2026-11-09) capped per pass, two passes turned the chest twice as far: phase 2's Crimson Embrace twisted 86 deg on his hips and bowed 55
            # (keyed 32 and 28) while the lead hand chased a haft held behind him, and both arms folded 0.38 into his chest (f40-50)
            dy = float(np.clip(total[i, 0] + smooth[i, 0], -SPINE_YAW, SPINE_YAW) - total[i, 0])
            dp = float(np.clip(total[i, 1] + smooth[i, 1], -SPINE_PITCH, SPINE_PITCH) - total[i, 1])
            total[i] += (dy, dp)
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
        mag = np.maximum(np.linalg.norm(sr, axis=1), np.linalg.norm(rot, axis=1))
        if clip.blow_envelope:
            # (2026-11-09) a tilt at a blow (a frame depop leaves as keyed) eases over its neighbours as an envelope, a gaussian of sigma frames at
            # its full height there, not the averaged spread: phase 1's Flowing Jian tilted 30 deg at f43, its neighbours about 3, a 0.58 blade
            # pop at its second blow that nothing after could smooth. A tilt off a blow keeps the averaged spread (depop takes what it leaves)
            times = clip.frames()
            for i in range(n):
                r = float(np.linalg.norm(rot[i]))
                if r < 1e-9 or not any(abs(times[i] - t) < 0.04 for t in clip.contacts):
                    continue
                for kk in k:
                    j = (i + kk) % n if clip.loop else i + kk
                    if 0 <= j < n:
                        mag[j] = max(mag[j], r * math.exp(-0.5 * (kk / sigma) ** 2))
        sr = mag[:, None] * np.array([unit(v) if np.linalg.norm(v) > 1e-9 else v for v in sr])
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
                    tor[e] = arm_torso_pose(rg, hand_side, {hand_side + "UpperArm": (ru0_, S), hand_side + "LowerArm": (rl0_, el0),
                                                            "UpperTorso": needs[i]["_chest"], "LowerTorso": needs[i]["_pelvis"]})
            # (2026-11-09) the hand is weighed for each turn of the fist, not with the untilted grip: the turns move the wrist a few hundredths but
            # roll the knuckles a hand's width, and phase 2 Heavy's swivel turned the fist so the right hand lay 0.25 inside his chest just before
            # the blow (f11, 0.10 before it), every elbow turn costed with a hand that was not there
            htor = np.zeros(G)
            for g in range(G):
                slant = GRIP_SLANTS[g // len(GRIP_TURNS)]
                Rh = rodrigues(axis * GRIP_TURNS[g % len(GRIP_TURNS)]) @ short_arc(slanted(rg, axis0, hand_side, slant), axis)
                Hi.append(Rh)
                Qi[g] = ZR.quat(Rh)
                wrist = grip - Rh @ v0
                if "_chest" in needs[i] and "_pelvis" in needs[i]:
                    htor[g] = arm_torso_pose(rg, hand_side, {hand_side + "Hand": (Rh, wrist), "UpperTorso": needs[i]["_chest"], "LowerTorso": needs[i]["_pelvis"]})
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
                    C[g, e] = CLASH_COST * clash + CLASH_HARD * max(0.0, clash - CLASH_GRAZE) + bend + 0.3 * max(0.0, bend - 55.0) + 1.6 * max(0.0, bend - 85.0) + 0.1 * abs(a) + 0.08 * abs(phi) + 90.0 * inside + 200.0 * scratch["x"] + wrist_cost(wp) + 0.4 * abs(slant) + torso_cost(max(tor[e], htor[g]))
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

        # (2026-11-09) a clip that opts in (Clip.hold_start / hold_end) starts or ends with this hand in a given state: grip slant, turn round the
        # haft and elbow turn (ELBOW_TURNS), pinned on its first or last frame (and through its fade in, hold_entry). Most clips that start and end
        # at the guard hold Idle's state there: their own cheapest was one elbow step (26 deg) from Idle's and Idle's their second cheapest (phase 2
        # Hit Light Front's end: 59.1 and 64.6), and the game's joint fade between the two swung the right upper arm 0.19 into his chest though
        # both ends sat at 0.12-0.16 (fadecheck2.py)
        def state_of(h):
            return None if h is None else (GRIP_SLANTS.index(h[0]) * len(GRIP_TURNS) + int(round(h[1] / (360.0 / len(GRIP_TURNS)))) % len(GRIP_TURNS)) * E \
                + int(round(h[2] / (360.0 / len(ELBOW_TURNS)))) % len(ELBOW_TURNS)
        s0, s1 = state_of((clip.hold_start or {}).get(hand_side)), state_of((clip.hold_end or {}).get(hand_side))
        tt = clip.frames()
        pinned = {i: s0 for i in live if s0 is not None and (i == 0 or (clip.hold_entry and tt[i] < ENTRY_FADE - 1e-9))}
        if s1 is not None and live[-1] == n - 1:
            pinned[n - 1] = s1

        def walk(fixed=None):
            """Every state to every state: the fist's real turn, the elbow's real travel and the forearm's roll all cost what they move, so nothing whips round for one frame."""
            total = costs[live[0]].ravel().copy()
            if live[0] in pinned:
                pin = np.full_like(total, 1e7)
                pin[pinned[live[0]]] = 0.0
                total = total + pin
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
                if i in pinned:
                    pin = np.full_like(total, 1e7)
                    pin[pinned[i]] = 0.0
                    total = total + pin
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

        def raw_of(j, c):
            t2 = dict(c)
            t2[hkey], t2[key], t2[hkey + "_slant"], t2[key + "_roll"] = ZR.mat(Q_raw[j]), el[j], sl[j], ro[j]
            return t2
        for i in live:
            if smoothed_arm_clash(clip, ctrl[i], hand_side) <= CLASH_GRAZE:
                # (2026-11-09) nor into his chest: the smoothed elbow is measured in his torso too, and where the frame's own choice sits shallower
                # (past ARM_TORSO_REST) it is restored the same way. The smoothing took phase 2's Deathblow Victim right arm 0.00 -> 0.17 at f39 and
                # Heaven Cleave's 0.09 -> 0.19 at its contact, which nothing after it could move
                d_s = arm_torso(clip, ctrl[i])[hand_side]
                if d_s <= ARM_TORSO_REST + 0.005 or arm_torso(clip, raw_of(i, ctrl[i]))[hand_side] >= d_s - 0.01:
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
        # (2026-11-09) swivel weighs each elbow turn's torso depth from the arm's bones on a third of its skin and with one wrist; where the arm it
        # leaves is past the wall on the real surfaces (phase 2 Rending Arc's right arm 0.12 -> 0.31 at f51, 0.00 -> 0.20 at f40), its cheapest
        # choices for that frame are solved and measured as the export will, and the cheapest that is out of the wall (or the shallowest, if none
        # is and it is 0.03 better) replaces it, its neighbours half way, unless it puts the arm in the weapon deeper than the frame had it
        wall = ARM_TORSO_REST + TORSO_WALL
        redo = 0
        if clip.run_recheck:     # (2026-11-09) per-clip opt-in: the recheck as one walk over each run of frames past the wall (recheck_runs)
            redo = recheck_runs(clip, ctrl, hand_side, live, path, costs, quats, rels, hands, poles, twists, (turn_cost, roll_step, elbow_step, grip_step, step_cost), wall)
        for i in ([] if clip.run_recheck else live):
            d = arm_torso(clip, ctrl[i])[hand_side]
            if d <= wall:
                continue
            clash0 = max(CLASH_GRAZE, smoothed_arm_clash(clip, ctrl[i], hand_side)) + 1e-3
            pick = None
            for flat in np.argsort(costs[i], axis=None)[:SWIVEL_RECHECK]:
                g, e = divmod(int(flat), E)
                t2 = dict(ctrl[i])
                t2[hkey], t2[key], t2[hkey + "_slant"], t2[key + "_roll"] = hands[i][g], poles[i][g, e], GRIP_SLANTS[g // len(GRIP_TURNS)], float(twists[i][g, e])
                d2 = arm_torso(clip, t2)[hand_side]
                if d2 >= d - 0.03 or smoothed_arm_clash(clip, t2, hand_side) > clash0:
                    continue
                if pick is None or d2 < pick[0]:
                    pick = (d2, g, e)
                if d2 <= wall:
                    break
            if pick is None:
                continue
            _, g, e = pick
            qn, pn, sn, rn = ZR.quat(hands[i][g]), poles[i][g, e], GRIP_SLANTS[g // len(GRIP_TURNS)], float(twists[i][g, e])
            for j, wgt in ((i, 1.0), (i - 1, 0.5), (i + 1, 0.5)):
                if not 0 <= j < n:
                    continue
                c = ctrl[j]
                q0 = ZR.quat(c[hkey])
                q1 = qn if float(q0 @ qn) >= 0 else -qn
                c[hkey] = ZR.mat(unit(q0 * (1 - wgt) + q1 * wgt))
                c[key] = unit(np.asarray(c[key]) * (1 - wgt) + pn * wgt)
                c[hkey + "_slant"] = float(c[hkey + "_slant"] * (1 - wgt) + sn * wgt)
                c[key + "_roll"] = float(c[key + "_roll"] * (1 - wgt) + rn * wgt)
            redo += 1
        if redo:
            clip._swivel_rechecked = getattr(clip, "_swivel_rechecked", 0) + redo


RUN_PAD = 2     # (2026-11-09) frames either side of a run past the wall that recheck_runs may re-choose too, so the run is walked into and out of
# (2026-11-10) per degree a hand turns between two frames past Clip.recheck_spike, in recheck_runs' walk. A lead hand turning on the haft is cheap
# there (LEAD_TURN_COST), and phase 1 Flowing Jian's f88, 0.011 past the wall alone, took a grip 45 deg round from both its neighbours: the left
# hand turned 41 and 46 deg out and back across f87-89 and flung the prayer beads up past his head. Priced, the walk ramps the grip over f86-88
# instead (slant -20 -> -10 -> 0, the hand 5-10 deg a frame) and f88 still clears (0.181 -> 0.140; ctrest.py)
RECHECK_SPIKE_COST = 10.0


def recheck_runs(clip, ctrl, hand_side, live, path, costs, quats, rels, hands, poles, twists, limits, wall):
    """(2026-11-09) swivel's torso recheck for a clip that opts in (Clip.run_recheck). The frame-by-frame recheck gives each frame past the wall
    its own cheapest clear choice and half of it to both neighbours; along a run of such frames the choices disagree, and phase 1 Flowing Jian's
    left hand ended f84-85 a half-mix of unrelated grips (the wrist turned 173 and 154 deg on the arm; swrecheck.py). Here each run, with RUN_PAD
    frames either side, is walked as swivel walks the clip: every frame keeps what it has or takes one of its SWIVEL_RECHECK cheapest choices that
    puts the arm no deeper in the weapon, each solved and measured as the export will and costed TORSO_HARD past the wall, and a step between two
    frames costs what walk() charges, from and to the frames either side as they stand. The chosen states replace their frames whole; the frame
    either side of the window takes half of its neighbour's change. Returns how many frames changed."""
    turn_cost, roll_step, elbow_step, grip_step, step_cost = limits
    E, G16 = len(ELBOW_TURNS), len(GRIP_TURNS)
    key, hkey = ("rpole", "rhand") if hand_side == "Right" else ("lpole", "lhand")
    n = len(ctrl)
    lset = set(live)
    deep = [i for i in live if arm_torso(clip, ctrl[i])[hand_side] > wall]
    runs = []
    for i in deep:
        if runs and i - runs[-1][-1] <= 1 + 2 * RUN_PAD:     # runs whose windows would meet are walked as one
            runs[-1].append(i)
        else:
            runs.append([i])
    state = {i: path[i] for i in live if i in path}

    def step(p, a, i, b):
        """walk()'s price for the hand going from state a at frame p to state b at frame i."""
        (ga, ea), (gb, eb) = a, b
        Tg = math.degrees(2 * math.acos(min(1.0, abs(float(quats[p][ga] @ quats[i][gb])))))
        Tw = math.degrees(2 * math.acos(min(1.0, abs(float(rels[p][ga] @ rels[i][gb])))))
        Te = math.degrees(math.acos(float(np.clip(poles[p][ga, ea] @ poles[i][gb, eb], -1.0, 1.0))))
        Tr = abs(float(twists[p][ga, ea]) - float(twists[i][gb, eb]))
        return turn_cost * Tg + 0.35 * Te + 0.35 * Tr + 600.0 * (Tr > roll_step) + 600.0 * (Te > elbow_step) + step_cost * (min(Tg, Tw) > grip_step) \
            + (RECHECK_SPIKE_COST * max(0.0, Tg - clip.recheck_spike) if clip.recheck_spike else 0.0)

    changed = 0
    for run in runs:
        win = [i for i in range(run[0] - RUN_PAD, run[-1] + RUN_PAD + 1) if i in state]
        opts = []     # per frame of the window: (state, or None to keep the frame as it stands; node cost; the state its steps are priced from)
        for i in win:
            d = arm_torso(clip, ctrl[i])[hand_side]
            clash0 = max(CLASH_GRAZE, smoothed_arm_clash(clip, ctrl[i], hand_side)) + 1e-3
            o = [(None, float(costs[i][state[i]]) + TORSO_HARD * max(0.0, d - wall), state[i])]
            for flat in np.argsort(costs[i], axis=None)[:SWIVEL_RECHECK]:
                g, e = divmod(int(flat), E)
                t2 = dict(ctrl[i])
                t2[hkey], t2[key], t2[hkey + "_slant"], t2[key + "_roll"] = hands[i][g], poles[i][g, e], GRIP_SLANTS[g // G16], float(twists[i][g, e])
                if smoothed_arm_clash(clip, t2, hand_side) > clash0:
                    continue
                o.append(((g, e), float(costs[i][g, e]) + TORSO_HARD * max(0.0, arm_torso(clip, t2)[hand_side] - wall), (g, e)))
            opts.append(o)
        before = max((q for q in state if q < win[0]), default=None)
        after = min((q for q in state if q > win[-1]), default=None)
        total = [o[1] + (step(before, state[before], win[0], o[2]) if before is not None else 0.0) for o in opts[0]]
        back = []
        for j in range(1, len(win)):
            p, i = win[j - 1], win[j]
            row, arg = [], []
            for o in opts[j]:
                c = [total[k] + step(p, opts[j - 1][k][2], i, o[2]) for k in range(len(opts[j - 1]))]
                k = int(np.argmin(c))
                row.append(c[k] + o[1])
                arg.append(k)
            total, back = row, back + [arg]
        if after is not None:
            total = [t + step(win[-1], o[2], after, state[after]) for t, o in zip(total, opts[-1])]
        k = int(np.argmin(total))
        pick = [k]
        for arg in reversed(back):
            k = arg[k]
            pick.append(k)
        pick.reverse()
        for j, (i, k) in enumerate(zip(win, pick)):
            s = opts[j][k][0]
            if s is None:
                continue
            g, e = s
            state[i] = s
            qn, pn, sn, rn = ZR.quat(hands[i][g]), poles[i][g, e], GRIP_SLANTS[g // G16], float(twists[i][g, e])
            for nb, wgt in ((i, 1.0), (i - 1, 0.5 if i == win[0] else 0.0), (i + 1, 0.5 if i == win[-1] else 0.0)):
                if wgt == 0.0 or not 0 <= nb < n:
                    continue
                c = ctrl[nb]
                q0 = ZR.quat(c[hkey])
                q1 = qn if float(q0 @ qn) >= 0 else -qn
                c[hkey] = ZR.mat(unit(q0 * (1 - wgt) + q1 * wgt))
                c[key] = unit(np.asarray(c[key]) * (1 - wgt) + pn * wgt)
                c[hkey + "_slant"] = float(c[hkey + "_slant"] * (1 - wgt) + sn * wgt)
                c[key + "_roll"] = float(c[key + "_roll"] * (1 - wgt) + rn * wgt)
            changed += 1
    return changed


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

    # (2026-11-08) nor through his own chest: a swing that takes the arm deeper into his torso than it was (past ARM_TORSO_REST) is not taken
    # (phase 2 Guandao_Heavy: swung clear of the haft, the free arm crossed his chest 0.35 deep for eight frames)
    tor0 = {i: arm_torso(clip, ctrl[i])["Left"] for i in look}

    def trial(axis, deg):
        worst = 0.0
        out = {}
        for i in look:
            t2 = dict(ctrl[i])
            Rc = chest[i]
            t2["lt"] = tuple(Rc @ rodrigues(axis * math.radians(deg * env[i])) @ Rc.T @ np.asarray(ctrl[i]["lt"], float))
            worst = max(worst, smoothed_arm_clash(clip, t2, "Left"))
            if worst < best[0] - 1e-4 and arm_torso(clip, t2)["Left"] > max(tor0[i], ARM_TORSO_REST) + 0.01:
                return 9.0, out
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


def close_loop(clip, ctrl):
    """(2026-11-09) The passes after the swivel (clear_free_arm, clear_torso, slide_fist, tilt_haft) work frame by frame and do not wrap round a
    loop: phase 2's turns came back 4-8 deg off their first frame (validate's loop seam; the torso pass moved 26 of TurnRight's 28 frames, the haft
    tilt 26 of TurnLeft's). What they leave between a loop's last frame and its first is taken back over the loop, linearly in time, so the last
    frame is the first again and no frame jumps."""
    n = len(ctrl)
    if not clip.loop or n < 3:
        return
    moved = False
    for key in ("rp", "lt", "rsl", "haft", "face"):
        if key not in ctrl[0] or key not in ctrl[-1]:
            continue
        d = np.asarray(ctrl[-1][key], float) - np.asarray(ctrl[0][key], float)
        if float(np.abs(d).max()) < 1e-6:
            continue
        moved = True
        for i in range(n):
            v = np.asarray(ctrl[i][key], float) - d * (i / (n - 1))
            ctrl[i][key] = float(v) if np.ndim(v) == 0 else tuple(v)
    if moved:
        for c in ctrl:
            c["haft"] = unit(np.asarray(c["haft"], float))
            c["face"] = orth(np.asarray(c["face"], float), c["haft"])
    # and the swivel's own choice for each hand (its path does not wrap either: phase 2's TurnRight came back with the lead hand 3 deg round the
    # haft and its elbow 0.06 off): poles, their roll, the grip's slant and the hand's turn, on the frames that hold them
    for key, kind in (("rpole", "dir"), ("lpole", "dir"), ("rpole_roll", "deg"), ("lpole_roll", "deg"), ("rhand_slant", "deg"), ("lhand_slant", "deg"),
                      ("rhand", "mat"), ("lhand", "mat")):
        if key not in ctrl[0] or key not in ctrl[-1] or ctrl[0][key] is None or ctrl[-1][key] is None:
            continue
        get = (lambda c: np.asarray(ZR.quat(np.asarray(c[key], float)), float)) if kind == "mat" else (lambda c: np.asarray(c[key], float))
        a, b = get(ctrl[0]), get(ctrl[-1])
        if kind == "mat" and float(a @ b) < 0:
            b = -b
        d = b - a
        if kind == "deg":
            d = (d + 180.0) % 360.0 - 180.0
        if float(np.abs(d).max()) < 1e-6:
            continue
        for i, c in enumerate(ctrl):
            if c.get(key) is None:
                continue
            v = get(c)
            if kind == "mat" and float(v @ a) < 0:
                v = -v
            v = v - d * (i / (n - 1))
            if kind == "mat":
                c[key] = ZR.mat(unit(v))
            elif kind == "dir":
                c[key] = unit(v)
            else:
                c[key] = float(v)


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


HAFT_TILTS = (4.0, 8.0, 13.0, 19.0, 25.0, 32.0)     # degrees the haft may tip about the fist to pass an arm instead of going through it
TILT_DIRS = 8                # ways it may tip, round the haft
TILT_NEAR_CONTACT = 0.1     # seconds either side of a contact where the blade's line is left exactly as keyed
TILT_REACH = 3               # frames either side of one that needs a tilt that may share it, so it eases in and out
TILT_DEG_COST = 0.3          # path cost per degree of tilt (CLASH_COST units: 30 deg weighs like 0.015 deep)
TILT_STEP_COST, TILT_STEP_FREE = 1.5, 3.0     # per degree the tilt changes from one frame to the next past TILT_STEP_FREE: a 13 deg jump weighs like 0.025 deep


def tilt_haft(clip, ctrl, times):
    """(2026-11-07) In a twirl the haft wheels about the fist, and on each turn its length sweeps through the arm that holds it; neither the grip turn
    nor the elbow (swivel) can take an arm out of a plane the weapon sweeps, and moving the weapon drags the fist and the arm with it. So where an arm
    is still in the weapon past a graze, the haft tips about the fist, square to itself, and the weapon passes beside the arm, as a real twirl does.
    (2026-11-08) The tilt is one path through the clip (as swivel chooses the grips): every frame near one that needs it weighs each tilt (size and way
    round the haft, measured from his up so it means the same on the next frame) by what is left in the arms, its size and its change from the last
    frame. Chosen frame by frame and smoothed, the tilts went to and fro (phase 2 Guandao_Art: 27, 30, 27, 30, 18, 30 deg in alternating directions on
    frames 0-5, the haft flicking 40 deg a frame, to take 0.06 down to 0.04). Frames near a contact are left alone."""
    n = len(ctrl)

    def worst(c, torso=None):
        return held_clash(clip, c, torso)

    def tipped(c, rv):
        ang = float(np.linalg.norm(rv))
        t2 = dict(c)
        if ang > 1e-6:
            R = rodrigues(rv)
            t2["haft"], t2["face"] = tuple(R @ unit(c["haft"])), tuple(R @ unit(c["face"]))
        return t2

    def rvec(c, p):     # the 2D tilt p (degrees, about his up-referenced axes square to this frame's haft) as a rotation vector
        h = unit(c["haft"])
        e1 = unit(np.cross(h, (0.0, 1.0, 0.0)) if abs(h[1]) < 0.95 else np.cross(h, (1.0, 0.0, 0.0)))
        e2 = np.cross(h, e1)
        return (e1 * p[0] + e2 * p[1]) * (math.pi / 180.0)
    near = [any(abs(t - k) < TILT_NEAR_CONTACT for k in clip.contacts) for t in times]
    free = [near[i] or float(c.get("wfree", 0.0)) > 0.01 for i, c in enumerate(ctrl)]
    deep0 = [[] for _ in ctrl]
    base = [0.0 if free[i] else worst(c, deep0[i]) for i, c in enumerate(ctrl)]
    deep0 = [d[0] if d else 0.0 for d in deep0]
    need = [i for i in range(n) if not free[i] and base[i] > CLASH_GRAZE]
    if not need:
        return
    may = sorted({k for i in need for k in range(i - TILT_REACH, i + TILT_REACH + 1) if 0 <= k < n and not free[k]})
    cands = [np.zeros(2)] + [np.array([d * math.cos(a), d * math.sin(a)]) for d in HAFT_TILTS for a in np.arange(TILT_DIRS) * 2 * math.pi / TILT_DIRS]
    opts, costs, vals = [], [], []
    for i, c in enumerate(ctrl):
        if i in may:
            o = cands
            dd = [deep0[i]]
            v = [base[i]] + [worst(tipped(c, rvec(c, p)), dd) for p in cands[1:]]
        else:
            o, v, dd = [np.zeros(2)], [base[i]], [deep0[i]]
        opts.append(o)
        vals.append(v)
        # (2026-11-09) and a tilt that takes an arm into his body costs as one into the weapon: the arm in the wood was all it weighed, and phase 2's
        # Blood Wave tipped the haft on f22-25 so the lead hand's spot came round and folded the left arm 0.36 into his chest (clear_torso had it at 0.11)
        costs.append(np.array([(CLASH_HARD if x >= GRIP_FAIL else 0.0) + CLASH_COST * max(0.0, x - CLASH_GRAZE) + TILT_DEG_COST * float(np.linalg.norm(p))
                               + CLASH_COST * max(0.0, d - max(deep0[i], ARM_TORSO_REST) - 0.005) for x, p, d in zip(v, o, dd)]))
    acc, back = [costs[0]], []
    for i in range(1, n):
        P, Q = np.array(opts[i - 1]), np.array(opts[i])
        step = TILT_STEP_COST * np.maximum(0.0, np.linalg.norm(Q[:, None, :] - P[None, :, :], axis=2) - TILT_STEP_FREE)
        tot = acc[-1][None, :] + step
        back.append(np.argmin(tot, axis=1))
        acc.append(costs[i] + tot[np.arange(len(Q)), back[-1]])
    k = int(np.argmin(acc[-1]))
    path = [k]
    for i in range(n - 1, 0, -1):
        k = int(back[i - 1][k])
        path.append(k)
    path.reverse()
    chosen = [np.array(opts[i][path[i]]) for i in range(n)]
    sm = [chosen[i] if free[i] else sum(w * chosen[min(max(i + o, 0), n - 1)] for o, w in ((-1, 0.25), (0, 0.5), (1, 0.25))) for i in range(n)]
    done, big = 0, 0.0
    for i, c in enumerate(ctrl):
        if free[i] or not chosen[i].any() and not sm[i].any():
            continue
        p = sm[i]
        if p is not chosen[i]:
            dd = []
            if worst(tipped(c, rvec(c, p)), dd) > max(CLASH_GRAZE, vals[i][path[i]]) + 0.005 or dd[0] > max(deep0[i], ARM_TORSO_REST) + 0.01:
                p = chosen[i]     # the smoothing put an arm back in (the weapon or his body): this frame keeps its own
        t2 = tipped(c, rvec(c, p))
        c["haft"], c["face"] = t2["haft"], t2["face"]
        done += 1
        big = max(big, float(np.linalg.norm(p)))
    clip._haft_tilted = (len(need), round(big, 1))
    if os.environ.get("SHEN_DEBUG_FREE"):
        print("haft tilt: %d frames need it, up to %.0f deg; %d frames changed" % (clip._haft_tilted + (done,)))


ARM_TORSO_REST = 0.14     # (2026-11-08) arm skin this deep in his torso's real surface is an arm resting against him: both idles hang the upper arms
                          # 0.12-0.14 into the side of the chest, under the arm and unseen. Past it an arm is going through him (clear_torso)
ARM_TORSO_DIRS = [unit(np.array(v, float)) for v in ((0, 0, -1), (0, 0.5, -1), (0, -0.5, -1), (0.6, 0, -1), (-0.6, 0, -1), (1, 0, -0.3), (-1, 0, -0.3),
                                                     (0.6, 0.5, -1), (-0.6, 0.5, -1), (0.6, -0.5, -1), (-0.6, -0.5, -1))]     # in the chest's own frame: his front is -z


def _torso_free(rg, part, torso, dense=False):
    """The skin of an arm part at least 0.05 clear of a torso solid in the bind pose (what lies at or in it there is the sculpt's own join)."""
    cache = rg.__dict__.setdefault("_torso_free", {})
    if (part, torso, dense) not in cache:
        cache[(part, torso, dense)] = sdf_depth(rg, torso, (rg.SKIN_FULL if dense else rg.SKIN)[part][0]) < -0.05
    return cache[(part, torso, dense)]


def arm_torso_world(rg, world, pose=None, dense=False):
    """(2026-11-08) How deep each arm's skin (hand, forearm, upper arm, blended as the game skins them) sits inside his torso's real surface
    (UpperTorso and LowerTorso distance fields), counting only skin clear of that solid in the bind pose. {"Right": depth, "Left": depth}, 0 when clear.
    dense: every skin sample (rg.SKIN_FULL), not the thinned set the passes weigh their choices by."""
    pose = pose or pose_of(rg, world)
    out = {}
    for side in ("Right", "Left"):
        m = 0.0
        for part in (side + "UpperArm", side + "LowerArm", side + "Hand"):
            W = world[part]
            if dense:
                P, mix = rg.SKIN_FULL[part]
                B = np.zeros_like(P)
                for bone, wt in mix:
                    (Rb, ab), jb = (pose[bone], rg.JOINT[bone]) if bone in pose else ((W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3]), rg.JOINT[part])
                    B += wt[:, None] * ((P - jb) @ Rb.T + ab)
            else:
                B = body_points(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], pose)
            for t in ("UpperTorso", "LowerTorso"):
                keep = _torso_free(rg, part, t, dense)
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
SWIVEL_RECHECK = 24     # (2026-11-09) how many of a frame's cheapest grip and elbow choices are solved and measured where swivel left an arm past the wall
TORSO_HARD, TORSO_WALL = 6000.0, 0.03     # (2026-11-09) and past REST + WALL (the validator flags REST + 0.04) all but forbidden, as an arm past a graze in the weapon


def torso_cost(d):
    """(2026-11-09) swivel's cost of an arm d deep in his torso. Linear alone (600 a unit past rest), an elbow turn that saved a wrist 70 deg of bend
    paid for an arm 0.12 further into his chest: phase 2 Rending Arc's swivel took the right arm from 0.00 to 0.26 at f62 and 0.02 to 0.33 at f69
    with clear choices on the table"""
    return TORSO_COST * max(0.0, d - ARM_TORSO_REST) + TORSO_HARD * max(0.0, d - ARM_TORSO_REST - TORSO_WALL)


def arm_torso(clip, c):
    """arm_torso_world() once control set c is solved."""
    keep = clip._side
    clip._side = {}
    try:
        _, world, _ = clip.solve(dict(c))
    finally:
        clip._side = keep
    return arm_torso_world(clip.rig, world)


def clear_torso(clip, ctrl, times, sigma=2.0):
    """(2026-11-08) Nothing kept his arms out of his own body: the weapon was kept out of him and the arms out of the weapon, and in phase 2's Heavy
    follow-through the fist sat behind his chest's middle on the far side, so the straight right arm ran through his chest to it (0.38 deep, f14-22,
    every elbow turn and every turn of the chest within 75 deg still 0.31 in). Where an arm is in his torso past ARM_TORSO_REST the hands move off
    him: for the arms on the weapon the whole weapon moves (its fist point, rp), for a lead arm reaching off the haft its target (lt). Each such frame
    finds the least move (ARM_TORSO_PUSH along ARM_TORSO_DIRS, in the chest's own frame) that clears it, or failing that the one that leaves it least
    deep; a move that puts an arm in the weapon (or the weapon in him) deeper than it was, or loses a grip, is not taken. The moves are then blended
    over the neighbouring frames (a gaussian of sigma frames, full at every frame that needs one) so the hands travel, and a frame the blend leaves
    deeper than its own move keeps its own. Frames near a contact keep the weapon as keyed."""
    n = len(ctrl)
    if n == 0:
        return
    def gate_at(t):     # nothing at a contact, all of it 0.1 s past the window
        g = 1.0
        for k in clip.contacts:
            if clip.active is not None and abs(clip.active[0] - k) < 1e-6 and t > k:
                # (2026-11-09) after the blow, from the end of its own active window (the server's hit, validate's strike): the follow-through may move.
                # Gated to 0.2 s past the contact, phase 2's Returning Tide kept its right fist at his left hip through f7-9 with the straight arm
                # 0.35 into his chest; the whole weapon 0.8 to his right clears it (0.11) and nothing smaller does (fist slid up the haft 0.8: 0.26)
                g = min(g, smooth01((t - k - clip.active[1]) / TORSO_AFTER_HIT))
            else:
                g = min(g, smooth01((abs(t - k) - TILT_NEAR_CONTACT) / 0.1))
        return g
    gate = np.array([gate_at(t) for t in times])
    holding = [float(c.get("lhw", 0.0)) > 0.0 and float(c.get("lhw", 0.0)) >= float(c.get("ltw", 0.0)) for c in ctrl]
    held = [float(c.get("wfree", 0.0)) <= 0.01 for c in ctrl]
    reaching = [float(c.get("ltw", 0.0)) >= 0.05 and not holding[i] for i, c in enumerate(ctrl)]
    share = np.array([float(c.get("ltw", 0.0)) / max(float(c.get("ltw", 0.0)) + float(c.get("lhw", 0.0)), 1e-6) for c in ctrl])
    keep = clip._side
    clip._side = {}
    try:
        chest = [clip.solve(dict(c))[1]["UpperTorso"][:3, :3] for c in ctrl]
    finally:
        clip._side = keep
    done = []
    for key, need, guard, weight in (
            ("rp", lambda i, d: max(d["Right"], d["Left"] if holding[i] else 0.0) if held[i] else 0.0, lambda c: held_clash(clip, c), gate),
            ("lt", lambda i, d: d["Left"] if reaching[i] else 0.0, lambda c: smoothed_arm_clash(clip, c, "Left"), share)):
        deep = [need(i, arm_torso(clip, c)) for i, c in enumerate(ctrl)]
        bad = [i for i in range(n) if deep[i] > ARM_TORSO_REST and weight[i] > 0.5]
        if not bad:
            continue
        base_guard = {}

        def guard_of(i):
            if i not in base_guard:
                base_guard[i] = guard(ctrl[i])
            return base_guard[i]

        def with_move(i, o):
            t2 = dict(ctrl[i])
            t2[key] = tuple(np.asarray(ctrl[i][key], float) + o)
            return t2

        def ok(i, t2):
            g = guard(t2)
            return g < GRIP_FAIL and g <= max(guard_of(i), CLASH_GRAZE) + 1e-3
        def shared(i, o):     # (2026-11-09) the frames round i can take the move too, eased as the blend below will ease it
            for d in (-2, -1, 1, 2):
                j = (i + d) % n if clip.loop else i + d
                if not 0 <= j < n or weight[j] <= 0.0 or j in bad:
                    continue
                t2 = with_move(j, o * math.exp(-0.5 * (d / sigma) ** 2) * weight[j])
                if not ok(j, t2) or need(j, arm_torso(clip, t2)) > max(deep[j], ARM_TORSO_REST) + 0.01:
                    return False
            return True
        own = {}
        for i in bad:
            # (2026-11-09) the least move that clears this frame and that its neighbours can share. Chosen for its own frame alone, phase 2's Feint
            # took its fist 0.39 off his chest on f4 where f3 and f5 could not follow without going into him or the weapon: a 0.5 one-frame jump
            best = (deep[i], np.zeros(3))
            alone = (deep[i], np.zeros(3))
            for m in ARM_TORSO_PUSH:
                for dvec in ARM_TORSO_DIRS:
                    o = chest[i] @ dvec * m
                    t2 = with_move(i, o)
                    v = need(i, arm_torso(clip, t2))
                    if v < min(best[0], alone[0]) - 0.01 and ok(i, t2):
                        if shared(i, o):
                            best = (v, o)
                        else:
                            alone = (v, o)
                if best[0] <= ARM_TORSO_REST:
                    break
            if not best[1].any() and alone[1].any():
                best = alone     # nothing its neighbours can share: its own, which the ease below limits
            if best[1].any():
                own[i] = best
        if not own:
            continue
        idx = np.arange(n)
        moves = np.zeros((n, 3))
        for j in range(n):
            wts = {i: math.exp(-0.5 * ((j - i) / sigma) ** 2) for i in own}
            tot = sum(wts.values())
            if tot < 1e-6:
                continue
            env = max(math.exp(-0.5 * ((j - i) / sigma) ** 2) for i in bad)
            moves[j] = sum(wts[i] * own[i][1] for i in own) / tot * env * weight[j]
        applied = np.zeros((n, 3))
        for j in range(n):
            if not moves[j].any():
                continue
            t2 = with_move(j, moves[j])
            v = need(j, arm_torso(clip, t2))
            if j in own and v > own[j][0] + 0.02:
                applied[j] = own[j][1] * weight[j]     # the blend put this frame back in: its own move
                continue
            if ok(j, t2) and v <= max(deep[j], ARM_TORSO_REST) + 0.01:
                applied[j] = moves[j]
                continue
            # (2026-11-09) a frame the blend only eases through takes as much of it as keeps it out of him and out of the weapon. Skipped outright,
            # phase 2's Flourish moved its fist 0.93 on f35 alone (f34 and f36 kept theirs) and the final solve carried it 1.4 across his body and back
            for f in (0.75, 0.5, 0.25):
                t2 = with_move(j, moves[j] * f)
                if ok(j, t2) and need(j, arm_torso(clip, t2)) <= max(deep[j], ARM_TORSO_REST) + 0.01:
                    applied[j] = moves[j] * f
                    break
        # (2026-11-09) and the hands never jump: from one frame to the next the move grows or shrinks by at most TORSO_STEP, and no frame stands
        # more than TORSO_BEND above its neighbours' mean. Where the frames round one that needs it cannot follow, that frame keeps less of its move
        # (validate still reports what is left in him) rather than popping: a step cap alone left phase 1's Flowing Jian a 0.79 one-frame bump (f52)
        mag = np.linalg.norm(applied, axis=1)
        cap = mag.copy()
        for _ in range(4 * n):
            before = cap.copy()
            for j in range(n):
                if clip.loop:
                    a, b = cap[(j - 1) % n], cap[(j + 1) % n]
                else:
                    a, b = cap[j - 1] if j > 0 else 0.0, cap[j + 1] if j < n - 1 else 0.0
                cap[j] = min(cap[j], min(a, b) + TORSO_STEP, 0.5 * (a + b) + TORSO_BEND)
            if np.abs(before - cap).max() < 1e-5:
                break
        changed = 0
        for j in range(n):
            if mag[j] < 1e-6:
                continue
            ctrl[j][key] = with_move(j, applied[j] * (cap[j] / mag[j]))[key]
            changed += 1
        worst0 = max(deep[i] for i in bad)
        worst1 = max(need(i, arm_torso(clip, ctrl[i])) for i in bad)
        done.append((key, len(bad), changed, round(worst0, 3), round(worst1, 3), round(float(np.linalg.norm(moves, axis=1).max()), 2)))
    clip._torso_cleared = done
    if os.environ.get("SHEN_DEBUG_FREE"):
        for d in done:
            print("torso: %s %d frames need it, %d moved; worst %.3f -> %.3f, moves up to %.2f" % d)


TORSO_BEND = 0.1     # (2026-11-09) rig units a frame's clear_torso move may stand above the mean of its neighbours' (POP_LIMIT's fist is 0.2)
TORSO_STEP = 0.3     # (2026-11-09) rig units clear_torso's move may change by from one frame to the next: a ramp that steep leaves its neighbours' midpoint by half of it, inside POP_LIMIT
TORSO_AFTER_HIT = 0.07     # (2026-11-09) seconds past a blow's active window over which clear_torso comes in
ARM_TORSO_PUSH = np.arange(0.1, 1.05, 0.1)        # (2026-11-08) how far (rig units) the hands may move off his chest to take an arm out of it


BODY_IN_WEAPON = 0.03     # his body's skin may touch the wood this deep (the mesh check's margin) before the post passes act
GRIP_FAIL = 1.0     # what a candidate that loses a hand's grip (an arm short of the haft) counts as


def held_clash(clip, c, torso=None):
    """(2026-11-07) Once control set c is solved: the deepest either arm sits in the weapon or the weapon in it, his skinned body and legs in the
    weapon past BODY_IN_WEAPON, and GRIP_FAIL when a hand no longer reaches the haft or a wrist turns past WRIST_LIMIT. One solve for all of it.
    torso: a list, given the deeper arm's depth in his torso (arm_torso_world) from the same solve."""
    rg = clip.rig
    keep = clip._side
    clip._side = {}
    try:
        _local, world, diag = clip.solve(dict(c))
    finally:
        clip._side = keep
    if torso is not None:
        torso.append(max(arm_torso_world(rg, world).values()))
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
    # (2026-11-10) and, where the clip opts in (Clip.legs_guard), the weapon inside his legs, on every weapon sample (validate's weapon_in_legs, which
    # thins them). His legs' skin in the wood (above) can be no deeper than the haft is thick, so a haft through his thigh reads as a graze: phase 2
    # Skyfall's fist slide, depop and polish took the wood ahead of the right fist 0.12 into his right thigh at f49 (0.16-0.18 on the rendered mesh)
    # with nothing here to see it. Past the same graze, slide_fist, tilt_haft, clear_torso and joint_polish weigh it as the body in the wood
    if clip.legs_guard:
        Pw = rg.samples["Weapon"] @ G[:3, :3].T + G[:3, 3]     # as place(rg, world, "Weapon"): the samples ride the Glaive bone
        for part in LEG_SOLIDS:
            W = world[part]
            out = max(out, float(part_depth(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], Pw).max()) - (BODY_IN_WEAPON - CLASH_GRAZE))
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


DEPOP_PASSES = 6     # (2026-11-09)
DEPOP_SHARE = 0.9    # a frame is treated where it leaves its neighbours by this share of POP_LIMIT
DEPOP_SPREAD = 2     # frames either side of one that jumps that share the smoothing


def depop(clip, ctrl, times):
    """(2026-11-09) The last word on the weapon. Every pass before this one decides frame by frame, and the solver corrects each frame alone (the haft
    kept on its side of him, the reach clamped, the lead hand pulled), so a correction could switch on for one frame: phase 2's Flourish moved its fist
    1.4 across his body on f35 and back, phase 1's Hesitant Moon slid the fist 0.4 down the haft on f46 alone. Here the frames are solved as the export
    will solve them; where what the bake did to the weapon (fist, haft line, slide; keys subtracted, as validate's bake_pops) leaves its neighbours and
    comes back, that change is smoothed (1-2-1, twice) over the frame and DEPOP_SPREAD either side, written back, and the frames are solved again: a
    correction the solver insists on returns on the next pass and spreads further into the neighbours each time, so it ends as a motion rather than a
    jump. Replacing a jumping frame by its neighbours instead put phase 2 L2's right arm back 0.32 into his chest (f8-9) where clear_torso had moved it."""
    n = len(ctrl)
    if n < 4:
        return
    keyed = [clip.controls(t) for t in times]

    def track(c, k):
        return np.concatenate([np.asarray(c["rp"], float) - np.asarray(k["rp"], float),
                               (unit(np.asarray(c["haft"], float)) - unit(np.asarray(k["haft"], float))) * 2.5,
                               [float(c["rsl"]) - float(k["rsl"])]])
    lim = np.array([POP_LIMIT["fist"], POP_LIMIT["blade"], POP_LIMIT["slide"], POP_LIMIT["edge"]]) * DEPOP_SHARE

    def nb(i):
        if clip.loop:
            return (i - 1) % n, (i + 1) % n
        return (i - 1, i + 1) if 0 < i < n - 1 else (None, None)
    treated = set()
    full = np.array([POP_LIMIT["fist"], POP_LIMIT["blade"], POP_LIMIT["slide"], POP_LIMIT["edge"]])
    best = None
    for p in range(DEPOP_PASSES + 1):
        keep = clip._side
        clip._side = {}
        solved = []
        try:
            for c in ctrl:
                t2 = dict(c)
                clip.solve(t2)
                solved.append(t2)
        finally:
            clip._side = keep
        D = np.array([track(s_, k) for s_, k in zip(solved, keyed)])
        F, K = np.array([pop_tracks(s_) for s_ in solved]), np.array([pop_tracks(k) for k in keyed])
        held = [float(c.get("wfree", 0.0)) < 0.01 for c in ctrl]
        bad, worst = [], 0.0
        for i in range(n):
            a, b = nb(i)
            if a is None or not (held[a] and held[i] and held[b]):
                continue
            e = pop_excess(F, K, i, a, b)
            worst = max(worst, float(np.max(e / full)))
            if (e > lim).any():
                bad.append(i)
        # (2026-11-09) each pass's frames are solved before the next pass writes, and the clip leaves with the best of them: the last pass's write was
        # never solved, and phase 2's Flourish left depop at 0.23 for the export's solve to put its fist 0.44 out on f17
        if best is None or worst < best[0] - 1e-6:
            best = (worst, [{k: ctrl[j][k] for k in ("rp", "haft", "face", "rsl")} for j in range(n)], set(treated))
        if not bad or p == DEPOP_PASSES:
            break
        region = set()
        for i in bad:
            for d in range(-DEPOP_SPREAD, DEPOP_SPREAD + 1):
                j = (i + d) % n if clip.loop else i + d
                # a contact keeps its blade where it was (phase 1 L1's smoothed contact fell 0.5 studs short of the server's blow)
                if 0 <= j < n and held[j] and not any(abs(times[j] - k) < 0.04 for k in clip.contacts):
                    a, b = nb(j)
                    if a is not None and held[a] and held[b]:
                        region.add(j)
        D2 = D.copy()
        for _s in range(2):
            Dn = D2.copy()
            for j in region:
                a, b = nb(j)
                Dn[j] = 0.25 * D2[a] + 0.5 * D2[j] + 0.25 * D2[b]
            D2 = Dn
        # (2026-11-09) the edge is smoothed as an edge: each neighbour's laid into this frame's new haft plane before the 1-2-1 average. Averaging the
        # bare unit vectors and squaring the result to the haft afterwards rolled phase 2 Skyfall's blade at random where they nearly cancelled or lay
        # along the haft, and the wrist followed it (right arm 0.16 -> 0.31 in his chest, f51 alone)
        Hn = {j: unit(unit(np.asarray(keyed[j]["haft"], float)) + D2[j, 3:6] / 2.5) for j in region}
        Fc = [unit(np.asarray(s_["face"], float)) for s_ in solved]
        for _s in range(2):
            Fn = list(Fc)
            for j in region:
                a, b = nb(j)
                h = Hn[j]
                m = sum(w * (Fc[x] - h * float(np.dot(Fc[x], h))) for w, x in ((0.25, a), (0.5, j), (0.25, b)))
                own = Fc[j] - h * float(np.dot(Fc[j], h))
                if float(np.linalg.norm(m)) > 0.3 and float(np.linalg.norm(own)) > 0.3:
                    Fn[j] = unit(m)
            Fc = Fn
        for j in region:
            k = keyed[j]
            h = Hn[j]
            ctrl[j]["rp"] = tuple(np.asarray(k["rp"], float) + D2[j, :3])
            ctrl[j]["haft"] = tuple(h)
            ctrl[j]["face"] = tuple(orth(Fc[j], h))
            ctrl[j]["rsl"] = float(k["rsl"]) + float(D2[j, 6])
            treated.add(j)
    if best is not None:
        for j in range(n):
            ctrl[j].update(best[1][j])
        treated = best[2]
    clip._depopped = sorted(treated)
    if os.environ.get("SHEN_DEBUG_FREE") and treated:
        print("depop: %d frames %s" % (len(treated), sorted(treated)))


POP_LIMIT = {"fist": 0.2, "blade": 0.45, "slide": 0.2, "edge": 0.45, "lead_reach": 0.2}     # (2026-11-09) rig units a frame may leave its neighbours' midpoint by, beyond the keys


def pop_tracks(c):
    """(2026-11-09) What bake_pops and depop follow of a frame's weapon: the fist (rp), a point 2.5 up the haft from it, the fist's slide (rsl),
    and a point 2.5 out along the blade's edge (its roll about the haft, which the first three cannot see)."""
    return np.concatenate([np.asarray(c["rp"], float), unit(np.asarray(c["haft"], float)) * 2.5, [float(c["rsl"])], unit(np.asarray(c["face"], float)) * 2.5])


def pop_excess(F, K, i, a, b):
    """(2026-11-09) How far frame i leaves the midpoint of frames a and b in the final tracks F beyond what it does in the keyed tracks K: a pop the
    bake added. A keyed swing that peaks there (the fist out at full stretch at a contact) and that the solver only flattens does not count."""
    def dev(X):
        d = X[i] - 0.5 * (X[a] + X[b])
        return np.array([np.linalg.norm(d[:3]), np.linalg.norm(d[3:6]), abs(d[6]), np.linalg.norm(d[7:10])])
    return dev(F) - dev(K)


# ---------------------------------------------------------------------------------------------------- the joint polish
POLISH_PAD = 4          # (2026-11-09) frames held either side of a run of frames with an arm past the wall; the run's frames move together
POLISH_ITERS = 150      # SLSQP iterations at most per window
POLISH_SCALE = np.array([0.1, 0.1, 0.1, 6.0, 6.0, 30.0, 30.0, 15.0])    # equal cost: 0.1 of fist, 6 deg of haft tilt, 30 deg of either elbow's swing, 15 deg of a free left arm's roll
POLISH_STEP = np.array([0.01, 0.01, 0.01, 1.0, 1.0, 3.0, 3.0, 2.0])     # forward-difference steps of the same controls
POLISH_SMOOTH = 4.0     # weight of the change's second difference over the window (its held ends count as no change), so it eases in and out
POLISH_MARGIN = 0.01    # the polish aims this far under the wall on every skin sample: the mesh itself has skin between the samples (0.02 deeper at most seen)


ENTRY_FADE = 0.15     # (2026-11-09) BossAnimations' fade into a reaction (0.1 into a planned attack, 0.2 into a gait)


def entry_specs(n):
    """(2026-11-09) The poses the game draws (at 60) while a clip fades in from the pose before it, taken as its own first frame (the states that lead
    into a clip end where it begins: Posture Break ends on the knee Deathblow Victim starts from): (a, b, s, u) = the clip at frames a..b mixed s,
    then mixed u of the way from frame 0 (joint_mix both times)."""
    out = []
    for k in range(1, int(round(ENTRY_FADE * 60))):
        f = k / 2.0
        a = min(int(f), n - 1)
        out.append((a, min(a + 1, n - 1), f - int(f), k / (ENTRY_FADE * 60)))
    return out


def blend_pose(rg, w0, wa, wb, s, u):
    """A pose entry_specs() or a halfway pose names: frames a..b mixed s, then u of the way from w0 (u = 1: the clip's own pose)."""
    x = joint_mix(rg, wa, wb, s) if s > 1e-9 else wa
    return x if u >= 1.0 - 1e-9 else joint_mix(rg, w0, x, u)


def _polish_sweep(clip, ctrl):
    """The export's own solve, every frame in order: the haft-side memory each frame starts from (clip._side before it), each frame's world, and how
    deep the deeper arm is in his torso on every skin sample, on each frame and halfway to the next (joint_mix: what the game draws between them)."""
    rg = clip.rig
    clip._side = {}
    sides, worlds, depth = [], [], []
    try:
        for c in ctrl:
            sides.append(dict(clip._side))
            _local, world, _diag = clip.solve(dict(c))
            worlds.append(world)
            depth.append(max(arm_torso_world(rg, world, dense=True).values()))
    finally:
        clip._side = None
    mids = [max(arm_torso_world(rg, joint_mix(rg, worlds[i], worlds[i + 1], 0.5), dense=True).values()) for i in range(len(ctrl) - 1)]
    entry = [max(arm_torso_world(rg, blend_pose(rg, worlds[0], worlds[a], worlds[b], s, u), dense=True).values()) for a, b, s, u in entry_specs(len(ctrl))]
    return sides, worlds, depth, mids, entry


def _solved(clip, ctrl, times):
    """(2026-11-09) The bake's last solve of these controls, every frame in order from no haft-side memory: [t, local, world, diag, ctrl] per frame."""
    clip._side = {}
    out = []
    try:
        for t, c in zip(times, ctrl):
            c2 = dict(c)
            local, world, diag = clip.solve(c2)[:3]
            out.append([t, local, world, diag, c2])
    finally:
        clip._side = None
    return out


def joint_polish(clip, ctrl, times):
    """(2026-11-09) Every pass before this one optimizes its own measure, one after another, and a later one can undo an earlier one: phase 2's
    Crimson Embrace kept its right arm 0.07 in his chest after the keys, the swivel put it 0.34 in, clear_torso took it to 0.27 and slide_fist put
    it back to 0.34; Deathblow Victim's went 0.17 -> 0.14 -> 0.15 -> 0.20 (swivel, clear_torso, slide_fist, depop). Here the frames of each run
    where an arm is still past the wall, on a frame or halfway between two (validate judges both), with POLISH_PAD held frames either side, are
    solved together with SciPy's SLSQP: per frame the fist point (3), a tilt of the haft about the fist with both grips riding it (2), a swing
    of each elbow about its shoulder-wrist line (2) and a roll of the left upper arm while it hangs free of the haft (1): phase 1's Running swung
    its free left arm 0.19 into his side between f4 and f5, out of reach of the weapon's controls. Every measure is the pipeline's own, from the same solve the export does: both arms
    POLISH_MARGIN under the wall in his torso on every skin sample (arm_torso_world dense, as validate), on each frame and halfway to the next;
    the arms and weapon no deeper in each other (held_clash); the solver's reach and grip misses, both wrists and the weapon's lowest point no
    worse than the bake left them. Frames at a contact keep the weapon exactly as keyed and may only swing the elbow. The objective is the least
    change and its second difference, so it eases in and out. A window is kept only when it ends shallower with no other constraint worse.
    Without SciPy the stage is skipped and validate still flags the arm. The offline prototypes on the dp11 bakes (thinned measure, frames only):
    Crimson Embrace f44-52 0.351 -> 0.171, Deathblow Victim f35-43 0.202 -> 0.170, no pop, grip or wrist worse; the mesh still had 0.219 at
    Crimson Embrace f48, between the thinned samples, hence every sample and the margin here."""
    n = len(ctrl)
    if n < 4 or os.environ.get("SHEN_JOINT_POLISH") == "0":
        return []
    wall = ARM_TORSO_REST + TORSO_WALL
    sides, worlds, depth, mids, entry = _polish_sweep(clip, ctrl)
    bad = sorted({i for i in range(1, n - 1) if depth[i] > wall} | {j for i in range(n - 1) if mids[i] > wall for j in (i, i + 1) if 0 < j < n - 1}
                 | {j for (a, b, _s, _u), d in zip(entry_specs(n), entry) if d > wall for j in range(1, b + 1) if j < n - 1})
    if not bad:
        return []
    try:
        from scipy.optimize import minimize
    except ImportError:
        print("joint_polish: SciPy is not installed (python3 -m pip install scipy); %d frames past the wall left for validate" % len(bad))
        return []
    runs = []
    for i in bad:
        if runs and i - runs[-1][1] <= 2 * POLISH_PAD:
            runs[-1][1] = i
        else:
            runs.append([i, i])
    report = []
    for a, b in runs:
        if report:
            sides, worlds, depth, mids, entry = _polish_sweep(clip, ctrl)     # after the window before it
        A, B = max(0, a - POLISH_PAD), min(n - 1, b + POLISH_PAD)
        report.append(_polish_window(clip, ctrl, times, A, B, sides, worlds, depth, mids, entry, wall - POLISH_MARGIN, minimize))
        print("joint_polish %s" % report[-1], flush=True)
        first = len(report) - 1
        if not report[-1]["kept"]:     # once more with the weapon left exactly as baked, only the elbows and the free arm turning: a smaller, smoother problem
            report.append(_polish_window(clip, ctrl, times, A, B, sides, worlds, depth, mids, entry, wall - POLISH_MARGIN, minimize, elbows_only=True))
            print("joint_polish %s" % report[-1], flush=True)
        if not any(r["feasible"] for r in report[first:]):
            # (2026-11-09) and once more from clear_torso's least fist move on each frame still past the wall (see _polish_window's seed): phase 2's
            # Death kneels at f36 with the right arm at full stretch, its front armpit 0.26 in his chest. Every small fist move made it deeper
            # (0.257 -> 0.266 over 0.08 toward his front) until the elbow could bend (0.046 at 0.2), so 150 SLSQP iterations moved the fist 0.03
            sides, worlds, depth, mids, entry = _polish_sweep(clip, ctrl)
            report.append(_polish_window(clip, ctrl, times, A, B, sides, worlds, depth, mids, entry, wall - POLISH_MARGIN, minimize, seed=True))
            print("joint_polish %s" % report[-1], flush=True)
    clip._polish = report
    return report


def _polish_window(clip, ctrl, times, A, B, sides, worlds, depth, mids, entry, target, minimize, elbows_only=False, seed=False):
    import time as _time
    rg = clip.rig
    frames = list(range(A + 1, B))
    nf, NV, NC = len(frames), 8, 9
    pos = {i: k for k, i in enumerate(frames)}
    # the poses between frames the game draws: every halfway step from A to B (the held ends' included) and, from the clip's start, its fade in
    pairs = [(i, i + 1, 0.5, 1.0) for i in range(A, B)] + ([sp for sp in entry_specs(len(ctrl)) if sp[1] <= B] if A == 0 else [])
    pair_base = [mids[a] for a, _b, _s, u in pairs if u >= 1.0] + [d for sp, d in zip(entry_specs(len(ctrl)), entry) if A == 0 and sp[1] <= B]
    NP = len(pairs)
    contact = [k for k, i in enumerate(frames) if any(abs(times[i] - t) < TILT_NEAR_CONTACT for t in clip.contacts)]
    ctrl0 = {i: dict(ctrl[i]) for i in frames}
    axes = {}
    for i in frames:
        w = worlds[i]
        sh = (w["RightUpperArm"] @ np.append(rg.JOINT["RightUpperArm"], 1))[:3]
        wr = (w["RightHand"] @ np.append(rg.JOINT["RightHand"], 1))[:3]
        lsh = (w["LeftUpperArm"] @ np.append(rg.JOINT["LeftUpperArm"], 1))[:3]
        lwr = (w["LeftHand"] @ np.append(rg.JOINT["LeftHand"], 1))[:3]
        h = unit(ctrl0[i]["haft"])
        e1 = unit(np.cross(h, (0.0, 1.0, 0.0)) if abs(h[1]) < 0.95 else np.cross(h, (1.0, 0.0, 0.0)))
        axes[i] = (unit(wr - sh), e1, np.cross(h, e1), unit(lwr - lsh))

    def apply(i, x):
        c = dict(ctrl0[i])
        sw, e1, e2, lsw = axes[i]
        c["rp"] = tuple(np.asarray(c["rp"], float) + x[0:3])
        rv = (e1 * x[3] + e2 * x[4]) * (math.pi / 180.0)
        if np.linalg.norm(rv) > 1e-9:
            Rt = rodrigues(rv)
            c["haft"], c["face"] = tuple(Rt @ unit(c["haft"])), tuple(Rt @ unit(c["face"]))
            for hk in ("rhand", "lhand"):     # the grips ride the haft
                if hk in c and np.shape(c[hk]) == (3, 3):
                    c[hk] = Rt @ np.asarray(c[hk], float)
        if abs(x[5]) > 1e-9 and "rpole" in c:
            c["rpole"] = tuple(rodrigues(sw * math.radians(x[5])) @ np.asarray(c["rpole"], float))
        lk = "lpole" if "lpole" in c else "lelb"     # the left elbow's pole, on the haft or reaching
        if abs(x[6]) > 1e-9 and lk in c:
            c[lk] = tuple(rodrigues(lsw * math.radians(x[6])) @ np.asarray(c[lk], float))
        if abs(x[7]) > 1e-9 and "lua" in c:     # the free arm's roll from his chest
            c["lua"] = (float(c["lua"][0]), float(c["lua"][1]), float(c["lua"][2]) + float(x[7]))
        return c

    def measure(i, c):
        clip._side = dict(sides[i])
        local, world, diag = clip.solve(dict(c))
        tor = arm_torso_world(rg, world, dense=True)
        return dict(R=tor["Right"], L=tor["Left"], clash=float(held_clash(clip, c)), arm_reach=float(diag.get("arm_reach", 0.0)),
                    left_grip=float(diag.get("left_grip", 0.0)), left_reach=float(diag.get("left_reach", 0.0)),
                    wrist=float(ZR.angle_of(local["RightHand"][:3, :3])), lwrist=float(ZR.angle_of(local["LeftHand"][:3, :3])),
                    lowest=float(place(rg, world, "Weapon")[:, 1].min())), world

    base = {i: measure(i, ctrl0[i])[0] for i in frames}
    lim = {i: dict(clash=max(CLASH_GRAZE, b["clash"]) + 0.005, arm_reach=max(0.02, b["arm_reach"]) + 0.02, left_grip=max(0.05, b["left_grip"]) + 0.02,
                   left_reach=max(0.05, b["left_reach"]) + 0.02, wrist=max(95.0, b["wrist"]), lwrist=max(95.0, b["lwrist"]),
                   lowest=min(GROUND - 0.05, b["lowest"])) for i, b in base.items()}

    def cons_frame(i, m):
        l = lim[i]
        return np.array([target - m["R"], target - m["L"], (l["clash"] - m["clash"]) * 4, l["arm_reach"] - m["arm_reach"], l["left_grip"] - m["left_grip"],
                         l["left_reach"] - m["left_reach"], (l["wrist"] - m["wrist"]) / 100.0, (l["lwrist"] - m["lwrist"]) / 100.0, m["lowest"] - l["lowest"]])
    cache, mcache = {}, {}

    def frame_eval(i, xi):
        key = (i, tuple(np.round(xi, 9)))
        if key not in cache:
            m, world = measure(i, apply(i, xi))
            cache[key] = (cons_frame(i, m), world)
        return cache[key]

    def xs(x, i):
        return x[pos[i] * NV:(pos[i] + 1) * NV] if i in pos else None

    def mid_eval(p, xa, xb):     # a pose between the pair's frames, as the game draws it; a held frame keeps its baked pose (frame 0 is held when A is 0)
        a, b, s_, u_ = pairs[p]
        key = (p, None if xa is None else tuple(np.round(xa, 9)), None if xb is None else tuple(np.round(xb, 9)))
        if key not in mcache:
            wa = worlds[a] if xa is None else frame_eval(a, xa)[1]
            wb = worlds[b] if xb is None else frame_eval(b, xb)[1]
            t = arm_torso_world(rg, blend_pose(rg, worlds[0], wa, wb, s_, u_), dense=True)
            mcache[key] = np.array([target - t["Right"], target - t["Left"]])
        return mcache[key]
    slack = np.zeros(nf * NC + NP * 2)

    def raw(x):
        return np.concatenate([frame_eval(i, xs(x, i))[0] for i in frames] + [mid_eval(p, xs(x, a), xs(x, b)) for p, (a, b, _s, _u) in enumerate(pairs)])

    def cons(x):
        return raw(x) + slack

    def cons_jac(x):     # a frame's measures depend on its own controls, a halfway pose on its two frames': forward differences per frame
        J = np.zeros((nf * NC + NP * 2, nf * NV))
        for k, i in enumerate(frames):
            xi = xs(x, i)
            g0 = frame_eval(i, xi)[0]
            near = [p for p, (a, b, _s, _u) in enumerate(pairs) if i in (a, b)]
            m0 = {p: mid_eval(p, xs(x, pairs[p][0]), xs(x, pairs[p][1])) for p in near}
            for j in range(NV):
                xp = xi.copy()
                xp[j] += POLISH_STEP[j]
                J[k * NC:(k + 1) * NC, k * NV + j] = (frame_eval(i, xp)[0] - g0) / POLISH_STEP[j]
                for p in near:
                    a, b = pairs[p][:2]
                    m1 = mid_eval(p, xp if a == i else xs(x, a), xp if b == i else xs(x, b))
                    J[nf * NC + 2 * p:nf * NC + 2 * p + 2, k * NV + j] = (m1 - m0[p]) / POLISH_STEP[j]
        return J
    D2 = np.zeros(((nf + 2) * NV, nf * NV))
    for k in range(nf + 2):
        for j, wgt in ((k - 2, 1.0), (k - 1, -2.0), (k, 1.0)):
            if 0 <= j < nf:
                D2[k * NV:(k + 1) * NV, j * NV:(j + 1) * NV] += wgt * np.eye(NV)
    Wsc = np.diag(np.tile(1.0 / POLISH_SCALE, nf))
    Q = Wsc @ (np.eye(nf * NV) + POLISH_SMOOTH * D2.T @ D2) @ Wsc
    bounds = []
    for k in range(nf):
        held = k in contact or elbows_only     # attack timing: the weapon stays as keyed at a contact
        bounds += [(0.0, 0.0) if held else (-0.6, 0.6)] * 3 + [(0.0, 0.0) if held else (-25.0, 25.0)] * 2 + [(-120.0, 120.0)] * 2 + [(-40.0, 40.0)]
    x0 = np.zeros(nf * NV)
    c0 = raw(x0)
    J0 = cons_jac(x0)
    for r in range(len(c0)):     # a measure no control here moves (a free left arm, an end held) is not asked to change: it is left as it is
        if c0[r] < 0 and np.abs(J0[r]).max() < 1e-6:
            slack[r] = 1e-3 - c0[r]
    start = np.zeros(nf * NV)
    if seed and not elbows_only:
        # (2026-11-09) A start past the place the gradients stall: on each frame still past the target, clear_torso's search (ARM_TORSO_PUSH along
        # ARM_TORSO_DIRS in his chest's frame, within the fist's bound) for the least fist move that meets every one of this frame's constraints,
        # the clearest of that size; blended over the frames round it (a gaussian of 2 frames, full on its own) as clear_torso blends. SLSQP
        # still decides the window from there, its objective still counted from the bake, and the result is kept on the same terms as any other.
        moves = {}
        for k, i in enumerate(frames):
            if k in contact:
                continue
            sl = slack[k * NC:(k + 1) * NC]
            if float((frame_eval(i, np.zeros(NV))[0] + sl)[:2].min()) >= 0.0:
                continue
            Rc = worlds[i]["UpperTorso"][:3, :3]
            for m in ARM_TORSO_PUSH:
                best = None
                for dvec in ARM_TORSO_DIRS:
                    xi = np.zeros(NV)
                    xi[:3] = Rc @ dvec * m
                    if np.abs(xi[:3]).max() > 0.6:
                        continue
                    v = frame_eval(i, xi)[0] + sl
                    if float(v.min()) >= -1e-4 and (best is None or float(v[:2].min()) > best[0]):
                        best = (float(v[:2].min()), xi[:3].copy())
                if best is not None:
                    moves[k] = best[1]
                    break
        for k in range(nf):
            if k in contact or not moves:
                continue
            j = max(moves, key=lambda j: (math.exp(-0.5 * ((k - j) / 2.0) ** 2), float(np.linalg.norm(moves[j]))))
            start[k * NV:k * NV + 3] = np.clip(moves[j] * math.exp(-0.5 * ((k - j) / 2.0) ** 2), -0.6, 0.6)
    track = {"best": None, "hist": []}

    def feasible(x):
        return float(cons(x).min()) >= -1e-4

    def callback(intermediate_result):     # stop once feasible and settled
        x, f = intermediate_result.x, float(intermediate_result.fun)
        if feasible(x) and (track["best"] is None or f < track["best"][0]):
            track["best"] = (f, x.copy())
        track["hist"].append(f)
        h = track["hist"]
        if track["best"] is not None and len(h) > 6 and abs(h[-6] - h[-1]) <= 1e-3 * max(abs(h[-1]), 1e-6):
            raise StopIteration
    t0 = _time.time()
    res = minimize(lambda x: float(x @ Q @ x), start, jac=lambda x: 2.0 * Q @ x, method="SLSQP", bounds=bounds,
                   constraints=[{"type": "ineq", "fun": cons, "jac": cons_jac}], callback=callback, options={"maxiter": POLISH_ITERS, "ftol": 1e-6})
    if feasible(res.x) and (track["best"] is None or float(res.fun) <= track["best"][0]):
        track["best"] = (float(res.fun), res.x.copy())
    x = track["best"][1] if track["best"] is not None else res.x
    c1 = raw(x)
    tor_rows = [k * NC + s for k in range(nf) for s in (0, 1)] + list(range(nf * NC, nf * NC + NP * 2))
    deep0 = max([depth[i] for i in frames] + pair_base)
    deep1 = max(target - float(c1[r]) for r in tor_rows)
    worse = [j for j in range(2, NC) if min(0.0, float(c0[:nf * NC][j::NC].min())) - float(c1[:nf * NC][j::NC].min()) > 1e-3]
    keep = deep1 < deep0 - 0.005 and not worse
    real, popped = None, []
    if keep:
        # (2026-11-09) and as the export will solve it: every frame in order, each starting from the haft side the frame before left (the measures
        # above hold each frame's side as the bake left it). Phase 1's Running took a second window 0.017 of fist away from the first's; on f3 that
        # turned the in-order solve to the haft's other side and the fist jumped 0.24 there (a 0.27 pop, the limit 0.2). The window stays only if
        # the arms end shallower there too and no pop the clip kept under its limit goes past it.
        trial = [dict(c) for c in ctrl]
        for k, i in enumerate(frames):
            trial[i] = apply(i, x[k * NV:(k + 1) * NV])
        p0, p1 = bake_pops(clip, _solved(clip, ctrl, times)), None
        tw = _solved(clip, trial, times)
        p1 = bake_pops(clip, tw)
        W = [o[2] for o in tw]
        real = max([max(arm_torso_world(rg, W[i], dense=True).values()) for i in frames]
                   + [max(arm_torso_world(rg, blend_pose(rg, W[0], W[a], W[b], s_, u_), dense=True).values()) for a, b, s_, u_ in pairs])
        popped = [k for k in POP_LIMIT if p1[k][0] > max(p0[k][0], POP_LIMIT[k]) + 1e-6]
        keep = real < deep0 and not popped
    if keep:
        for k, i in enumerate(frames):
            ctrl[i].clear()
            ctrl[i].update(trial[i])
    clip._side = None
    X = x.reshape(nf, NV)
    return dict(window=(A, B), elbows_only=elbows_only, seeded=bool(seed and start.any()), status=int(res.status), message=str(res.message), nit=int(res.nit), runtime_s=round(_time.time() - t0, 1),
                frame_evals=len(cache), feasible=track["best"] is not None, depth=(round(deep0, 3), round(float(deep1), 3)),
                solved_depth=None if real is None else round(float(real), 3), popped=popped, kept=keep, worse=worse,
                change=(round(float(np.abs(X[:, :3]).max()), 3), round(float(np.abs(X[:, 3:5]).max()), 1), round(float(np.abs(X[:, 5]).max()), 1),
                        round(float(np.abs(X[:, 6]).max()), 1), round(float(np.abs(X[:, 7]).max()), 1)))


def bake_pops(clip, baked):
    """(2026-11-09) One-frame jumps the bake added to the weapon (fist, haft line, slide, while the weapon is held) and to the lead hand's reach target
    in his chest's frame (while it reaches): where a frame leaves the midpoint of the frames either side by more than the keys do there (pop_excess).
    Phase 2's Flourish moved its fist 1.4 across his body on f35 alone. {what: (worst, frame)}"""
    n = len(baked)
    out = {k: (0.0, 0) for k in POP_LIMIT}
    if n < 3:
        return out
    F, K, LF, LK, held, reach = [], [], [], [], [], []
    for t, local, world, diag, c in baked:
        k = clip.controls(t)
        F.append(pop_tracks(c))
        K.append(pop_tracks(k))
        LF.append(np.asarray(c["lt"], float))
        LK.append(np.asarray(k["lt"], float))
        held.append(float(c.get("wfree", 0.0)) < 0.01)
        reach.append(float(c.get("ltw", 0.0)) >= 0.05 and float(c.get("ltw", 0.0)) >= float(c.get("lhw", 0.0)))
    F, K, LF, LK = np.array(F), np.array(K), np.array(LF), np.array(LK)
    for i in range(n):
        if clip.loop:
            a, b = (i - 1) % n, (i + 1) % n
        elif 0 < i < n - 1:
            a, b = i - 1, i + 1
        else:
            continue
        if held[a] and held[i] and held[b]:
            for v, k in zip(pop_excess(F, K, i, a, b), ("fist", "blade", "slide", "edge")):
                if v > out[k][0]:
                    out[k] = (float(v), i)
        if reach[a] and reach[i] and reach[b]:
            v = float(np.linalg.norm(LF[i] - 0.5 * (LF[a] + LF[b])) - np.linalg.norm(LK[i] - 0.5 * (LK[a] + LK[b])))
            if v > out["lead_reach"][0]:
                out["lead_reach"] = (v, i)
    return out


def joint_mix(rg, wa, wb, u):
    """(2026-11-09) The pose the game shows between two of these poses: each joint's own transform (relative to its parent part, as Motor6D.Transform)
    slerped and its offset mixed, then the parts placed down the chain from the root, as the Animator interpolates keyframes and fades one track
    into the next. Mixing the parts' places instead moves a hand along the straight line between its two spots, through his chest where it swings
    round him."""
    out = {}
    for k in ["HumanoidRootPart"] + list(rg.ORDER) + list(rg.HELPERS):
        if k in out or k not in wa or k not in wb:
            continue
        p = rg.PARENT.get(k)
        A, B = (np.linalg.inv(wa[p]) @ wa[k], np.linalg.inv(wb[p]) @ wb[k]) if p in out else (wa[k], wb[k])
        M = np.eye(4)
        M[:3, :3] = ZR.mat(ZR.slerp(ZR.quat(A[:3, :3]), ZR.quat(B[:3, :3]), u))
        M[:3, 3] = A[:3, 3] * (1 - u) + B[:3, 3] * u
        out[k] = out[p] @ M if p in out else M
    for k in wa:
        out.setdefault(k, wa[k])
    return out


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
        for side, v in arm_torso_world(rg, world, pose, dense=True).items():     # (2026-11-08) his arms in his own torso (clear_torso); (2026-11-09) every skin sample
            k = "arm_in_torso_" + side.lower()
            w[k] = max(w.get(k, 0.0), round(v, 3))
        fist = (world["RightHand"] @ np.append(rg.GRIP0, 1))[:3]
        d = fist - np.asarray(c["rp"], float)
        if float(c.get("wfree", 0.0)) < 0.01:     # a hand that has let go of the weapon is not off it
            w["right_off_haft"] = max(w.get("right_off_haft", 0.0), float(np.linalg.norm(d)))
    # (2026-11-09) and between the frames: the game shows the pose halfway between two keyframes (it draws faster than the 30 the clip is keyed at)
    # and interpolates each joint, so an arm swinging fast past him goes through his chest between two frames that are each clear (phase 2's
    # Deathblow Victim, 0.127 and 0.108 at f2 and f3, 0.183 between them)
    for i in range(len(baked) - 1):
        mid = joint_mix(rg, baked[i][2], baked[i + 1][2], 0.5)
        for side, v in arm_torso_world(rg, mid, dense=True).items():
            k = "arm_in_torso_between_" + side.lower()
            if v > w.get(k, (0.0, 0))[0]:
                w[k] = (round(v, 3), i)
    # (2026-11-09) and while it fades in (ENTRY_FADE, from a pose like its first frame: what leads into a clip ends where it begins): a bake that
    # turns an arm over in the first frames swings it through his chest in the fade (phase 2's Deathblow Victim from Posture Break, 0.34)
    for a, b, s_, u_ in entry_specs(len(baked)):
        for side, v in arm_torso_world(rg, blend_pose(rg, baked[0][2], baked[a][2], baked[b][2], s_, u_), dense=True).items():
            k = "arm_in_torso_entry_" + side.lower()
            w[k] = max(w.get(k, 0.0), round(v, 3))
    pops = bake_pops(clip, baked)     # (2026-11-09) one-frame jumps the bake put in that the keys do not have
    for k, v in pops.items():
        w["pop_" + k] = round(v[0], 3)
        if v[0] > POP_LIMIT[k]:
            problems.append("%s pops %.2f at f%d" % (k, v[0], v[1]))
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
        b = w.get("arm_in_torso_between_" + side, (0.0, 0))
        if b[0] > ARM_TORSO_REST + 0.04:
            problems.append("%s arm %.2f inside his torso between f%d and f%d" % (side, b[0], b[1], b[1] + 1))
        if w.get("arm_in_torso_entry_" + side, 0) > ARM_TORSO_REST + 0.04:
            problems.append("%s arm %.2f inside his torso fading in" % (side, w["arm_in_torso_entry_" + side]))
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
