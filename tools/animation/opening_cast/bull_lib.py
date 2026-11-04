"""The Iron Bull's clip solver: forward kinematics about the sculpt's own joints, analytic limb IK, derived pauldron and cloth motion, export and validation.

Unlike the other cast rigs his limbs do not sit on the stock R15 pivots and his rest pose is the sculpt (rigdef.py): a zero Transform on every joint shows
the model as designed. BossRigs.apply moves his rig attachments to these joints, all rotations stay axis-aligned, so for any bone
    W[bone] = W[parent] * Translate(joint) * Transform * Translate(-joint)    (W maps a rest-pose point to clip space)
and a bone's Transform is simply R_parent^T * R_bone. Clip space is HumanoidRootPart space at scale 1; the Animator scales translation with the Model.

Joint owners: the clip owns every joint. The pauldrons and cloth are derived from the limbs here at bake time and are ordinary keyed joints in the clip; no script
writes a joint at run time, so nothing can fight the Animator.
"""
import math
import re
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/blender/bull_import"))
sys.path.insert(0, str(ROOT / "tools/animation/general_zhao"))
import rigdef as R  # noqa: E402
import rig as ZR  # noqa: E402  # quat, mat, slerp, angle_of
import export as ZX  # noqa: E402  # cframe, ref, PRIORITY, content_hash

FPS = 30
GROUND = R.GROUND
SCALE = 1.7      # WorldDefinitions: the Bull's game scale
JOINT = {k: np.array(v[1], float) for k, v in R.JOINT.items()}
PARENT = {k: v[0] for k, v in R.JOINT.items()}
MOTOR = {k: v[2] for k, v in R.JOINT.items()}
ORDER = list(R.JOINT)
for k, v in R.HELPER.items():
    JOINT[k] = np.array(v[1], float)
    PARENT[k] = v[0]
HELPERS = list(R.HELPER)
ALL = ORDER + HELPERS
CHILDREN = {}
for k in ALL:
    CHILDREN.setdefault(PARENT[k], []).append(k)
SAMPLES_FILE = ROOT / "work/bull_import/samples.npz"
BONE_OF = {"Weapon": "RightHand", "Shield": "LeftLowerArm"}

# ---- maul and grip, measured on the sculpt
GRIP0 = np.array([1.41, -0.95, -0.05])
HAFT0 = np.array([0.35, -0.64, -1.42]) / np.linalg.norm([0.35, -0.64, -1.42])


def unit(v):
    v = np.asarray(v, float)
    return v / max(np.linalg.norm(v), 1e-9)


def orth(v, axis):
    v = np.asarray(v, float)
    return unit(v - axis * np.dot(v, axis))


FACE0 = orth((0.0, -1.0, 0.6), HAFT0)
TOE0, HEEL0 = None, None


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


def pivoted(W_parent, bone, L):
    j = JOINT[bone]
    return W_parent @ homog(None, j) @ L @ homog(None, -j)


def pole_of(a, b, c):
    """The side the middle joint bends to at rest: its offset from the line a-c."""
    axis = unit(c - a)
    return orth(b - a, axis)


ARM_U, ARM_L = JOINT["RightLowerArm"] - JOINT["RightUpperArm"], JOINT["RightHand"] - JOINT["RightLowerArm"]
ELBOW0 = pole_of(JOINT["RightUpperArm"], JOINT["RightLowerArm"], JOINT["RightHand"])
LEGS = {}
for side in ("Left", "Right"):
    h, k, a = JOINT[side + "UpperLeg"], JOINT[side + "LowerLeg"], JOINT[side + "Foot"]
    LEGS[side] = {"u": k - h, "l": a - k, "pole": pole_of(h, k, a), "ankle": a}


def two_bone(S, T, u0, l0, pole0, pole1, label, diag):
    """Solve shoulder/hip S, target T for rest bones u0, l0. Returns rotations of the two bones and how far T was beyond reach."""
    a, b = float(np.linalg.norm(u0)), float(np.linalg.norm(l0))
    d = T - S
    dist = float(np.linalg.norm(d))
    limit = (a + b) * 0.9995
    over = max(0.0, dist - limit)
    diag[label] = max(diag.get(label, 0.0), over)
    dist_c = min(max(dist, abs(a - b) + 1e-3), limit)
    axis = unit(d)
    along = (a * a - b * b + dist_c * dist_c) / (2 * dist_c)
    height = math.sqrt(max(a * a - along * along, 0.0))
    knee_dir = orth(pole1, axis)
    M = S + axis * along + knee_dir * height
    W = S + axis * dist_c
    ru = frame3(M - S, pole1) @ frame3(u0, pole0).T
    rl = frame3(W - M, pole1) @ frame3(l0, pole0).T
    return ru, rl, W


def hand_rotation(haft, face):
    return frame3(haft, face) @ frame3(HAFT0, FACE0).T


REST_CONTROLS = {
    "pel": (0.0, 0.0, 0.0), "pelR": (0.0, 0.0, 0.0), "chest": (0.0, 0.0, 0.0), "neck": (0.0, 0.0, 0.0), "lookW": 0.0, "look": (0.0, 1.5, -10.0),
    "rh": tuple(GRIP0 - JOINT["RightUpperArm"]), "haft": tuple(HAFT0), "face": tuple(FACE0), "relb": tuple(ELBOW0),
    "lua": (0.0, 0.0, 0.0), "lfa": (0.0, 0.0, 0.0), "lha": (0.0, 0.0, 0.0),
    "rf": (0.0, 0.0, 0.0, 0.0, 0.0), "lf": (0.0, 0.0, 0.0, 0.0, 0.0), "rknee": tuple(LEGS["Right"]["pole"]), "lknee": tuple(LEGS["Left"]["pole"]),
}
DIRECTION = {"haft", "face", "relb", "rknee", "lknee"}
FEET = {"rf", "lf"}
EASE = {
    "lin": lambda u: u, "in": lambda u: u * u, "out": lambda u: 1 - (1 - u) * (1 - u), "io": lambda u: u * u * (3 - 2 * u),
    "snap": lambda u: 1 - (1 - u) ** 3, "whip": lambda u: u * u * u,
}


def pose(**kw):
    return kw


class Clip:
    """Timed partial control keys, Catmull-Rom between them; a channel a key omits holds through."""
    armed = "maul"

    def __init__(self, name, length, keys, loop=False, priority="Action", contacts=(), move=None, notes="", kind="", active=None, striker="maul", oath=False, slot="", feet_free=()):
        self.name, self.length, self.loop, self.priority = name, float(length), loop, priority
        self.keys = sorted(((float(t), c, e) for t, c, e in keys), key=lambda k: k[0])
        self.contacts = [float(c) for c in contacts]
        self.move, self.notes, self.kind, self.active, self.striker, self.oath = move, notes, kind, active, striker, oath
        self.slot = slot or name
        self.feet_free = list(feet_free)
        self.mask = None

    def frames(self):
        n = int(round(self.length * FPS))
        return [i / FPS for i in range(n + 1)]

    def channel(self, name, t):
        keyed = [(kt, c[name], e) for kt, c, e in self.keys if name in c]
        if not keyed:
            return np.asarray(REST_CONTROLS[name], float)
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
                        out[2] = max(out[2], min(0.55, dist * 0.32) * math.sin(math.pi * u) if dist > 0.08 else 0)
                return unit(out) if name in DIRECTION else out
        return vals[-1]

    def controls(self, t):
        c = {name: self.channel(name, t) for name in REST_CONTROLS}
        if self.oath:  # the oath layer: lower, shoulders forward, head down and driven; the hand stays relative to the shoulder
            c["pel"] = c["pel"] + np.array([0, -0.12, -0.04])
            c["pelR"] = c["pelR"] + np.array([5.0, 0, 0])
            c["chest"] = c["chest"] + np.array([9.0, 0, 0])
            c["neck"] = c["neck"] + np.array([-7.0, 0, 0])
            c["lua"] = c["lua"] + np.array([0, 0, 4.0])
        return c

    def solve(self, c):
        diag = {}
        local, world = {}, {"HumanoidRootPart": np.eye(4)}
        local["LowerTorso"] = homog(euler(c["pelR"]), c["pel"])
        world["LowerTorso"] = pivoted(world["HumanoidRootPart"], "LowerTorso", local["LowerTorso"])
        local["UpperTorso"] = homog(euler(c["chest"]))
        world["UpperTorso"] = pivoted(world["LowerTorso"], "UpperTorso", local["UpperTorso"])
        Rch = world["UpperTorso"][:3, :3]
        # head: its own pose, turned toward the look point by lookW
        head = euler(c["neck"])
        w_head = Rch @ head
        if float(c["lookW"]) > 0:
            neck_at = (world["UpperTorso"] @ np.append(JOINT["Head"], 1))[:3]
            f = unit(np.asarray(c["look"], float) - neck_at)
            want = frame3(-f, (0, 1, 0)) @ frame3((0, 0, 1), (0, 1, 0)).T
            q = ZR.slerp(ZR.quat(w_head), ZR.quat(want), float(c["lookW"]))
            w_head = ZR.mat(q)
        local["Head"] = homog(Rch.T @ w_head)
        world["Head"] = pivoted(world["UpperTorso"], "Head", local["Head"])
        # right arm: a grip the haft runs through. rh is the grip from the shoulder in clip axes; overreach pulls the fist in, never turns the maul
        S = (world["UpperTorso"] @ np.append(JOINT["RightUpperArm"], 1))[:3]
        Rh = hand_rotation(c["haft"], c["face"])
        wrist_off = Rh @ (JOINT["RightHand"] - GRIP0)
        ru, rl, wrist = two_bone(S, S + np.asarray(c["rh"], float) + wrist_off, ARM_U, ARM_L, ELBOW0, unit(c["relb"]), "arm_reach", diag)
        local["RightUpperArm"] = homog(Rch.T @ ru)
        world["RightUpperArm"] = pivoted(world["UpperTorso"], "RightUpperArm", local["RightUpperArm"])
        local["RightLowerArm"] = homog(ru.T @ rl)
        world["RightLowerArm"] = pivoted(world["RightUpperArm"], "RightLowerArm", local["RightLowerArm"])
        local["RightHand"] = homog(rl.T @ Rh)
        world["RightHand"] = pivoted(world["RightLowerArm"], "RightHand", local["RightHand"])
        # left arm: forward kinematics in the chest's axes, because the shield is strapped to the forearm and its face and length matter more than the fist
        Ru, Rf = euler(c["lua"]), euler(c["lfa"])
        local["LeftUpperArm"] = homog(Ru)
        world["LeftUpperArm"] = pivoted(world["UpperTorso"], "LeftUpperArm", local["LeftUpperArm"])
        local["LeftLowerArm"] = homog(Ru.T @ Rf)
        world["LeftLowerArm"] = pivoted(world["LeftUpperArm"], "LeftLowerArm", local["LeftLowerArm"])
        local["LeftHand"] = homog(euler(c["lha"]))
        world["LeftHand"] = pivoted(world["LeftLowerArm"], "LeftHand", local["LeftHand"])
        # legs: x, z, lift, yaw, pitch from the rest ankle
        Rlt = world["LowerTorso"][:3, :3]
        for side, key, pole in (("Right", "rf", "rknee"), ("Left", "lf", "lknee")):
            x, z, lift, yaw, pitch = [float(v) for v in c[key]]
            leg = LEGS[side]
            A = leg["ankle"] + np.array([x, lift, z])
            Rfoot = ry(math.radians(yaw)) @ rx(math.radians(pitch))
            H = (world["LowerTorso"] @ np.append(JOINT[side + "UpperLeg"], 1))[:3]
            ru_, rl_, reached = two_bone(H, A, leg["u"], leg["l"], leg["pole"], ry(math.radians(yaw)) @ unit(c[pole]), "leg_reach", diag)
            local[side + "UpperLeg"] = homog(Rlt.T @ ru_)
            world[side + "UpperLeg"] = pivoted(world["LowerTorso"], side + "UpperLeg", local[side + "UpperLeg"])
            local[side + "LowerLeg"] = homog(ru_.T @ rl_)
            world[side + "LowerLeg"] = pivoted(world[side + "UpperLeg"], side + "LowerLeg", local[side + "LowerLeg"])
            local[side + "Foot"] = homog(rl_.T @ Rfoot)
            world[side + "Foot"] = pivoted(world[side + "LowerLeg"], side + "Foot", local[side + "Foot"])
        return local, world, diag

    def bake(self):
        out = []
        for t in self.frames():
            c = self.controls(t)
            local, world, diag = self.solve(c)
            out.append([t, local, world, diag, c])
        derive_helpers(self, out)
        return out


# ---------------------------------------------------------------------------------------------------- derived joints
def limited_slerp(Rm, fraction, limit_deg):
    q = ZR.slerp(ZR.quat(np.eye(3)), ZR.quat(Rm), fraction)
    M = ZR.mat(q)
    angle = ZR.angle_of(M)
    if angle > limit_deg:
        q = ZR.slerp(ZR.quat(np.eye(3)), ZR.quat(M), limit_deg / angle)
        M = ZR.mat(q)
    return M


def thigh_flex(frame_world, side):
    """Forward raise of a thigh in the pelvis frame, degrees: + toward his front."""
    Rt = frame_world["LowerTorso"][:3, :3].T @ frame_world[side + "UpperLeg"][:3, :3]
    v = Rt @ unit(LEGS[side]["u"])
    v0 = unit(LEGS[side]["u"])
    return math.degrees(math.atan2(-v[2], -v[1]) - math.atan2(-v0[2], -v0[1]))


def spring(targets, dt, omega, zeta, loop):
    x, v = targets[0], 0.0
    passes = 2 if loop else 1
    out = []
    for p in range(passes):
        out = []
        for tgt in targets:
            for _ in range(4):
                h = dt / 4
                a = omega * omega * (tgt - x) - 2 * zeta * omega * v
                v += a * h
                x += v * h
            out.append(x)
    return out


def derive_helpers(clip, baked):
    """Pauldrons ride part of the way up with the arm; apron and cape hang from the belt, are pushed by the thighs and swing behind the pelvis."""
    dt = 1.0 / FPS
    cf, cb, roll = [], [], []
    last = None
    speeds = []
    for t, local, world, diag, c in baked:
        p = world["LowerTorso"][:3, 3]
        speeds.append(0.0 if last is None else -(p[2] - last[2]) / dt)  # forward speed of the pelvis
        last = p
    if clip.loop and len(speeds) > 1:
        speeds[0] = speeds[-1]
    for i, (t, local, world, diag, c) in enumerate(baked):
        Rlt = world["LowerTorso"][:3, :3]
        v = Rlt @ np.array([0, -1.0, 0])
        hang = math.degrees(math.atan2(v[2], -v[1]))  # the pelvis's own pitch: + hangs toward his back
        flexR, flexL = thigh_flex(world, "Right"), thigh_flex(world, "Left")
        front = max(flexR, flexL, 0.0) * 0.62 - hang * 0.7 + float(np.clip(speeds[i], -8, 8)) * -0.9
        back = min(flexR, flexL, 0.0) * 0.45 - hang * 0.7 + float(np.clip(speeds[i], -8, 8)) * -1.6
        cf.append(front)
        cb.append(back)
        roll.append(math.degrees(math.atan2(v[0], -v[1])))
    cf_s = spring(cf, dt, 16.0, 0.55, clip.loop)
    cb_s = spring(cb, dt, 11.0, 0.42, clip.loop)
    r_s = spring(roll, dt, 12.0, 0.5, clip.loop)
    for i, entry in enumerate(baked):
        t, local, world, diag, c = entry
        Rch = world["UpperTorso"][:3, :3]
        for side in ("Right", "Left"):
            rel = Rch.T @ world[side + "UpperArm"][:3, :3]
            L = limited_slerp(rel, 0.42, 48.0)
            local[side + "Pauldron"] = homog(L)
            world[side + "Pauldron"] = pivoted(world["UpperTorso"], side + "Pauldron", local[side + "Pauldron"])
        fx = max(cf_s[i], max(thigh_flex(world, "Right"), thigh_flex(world, "Left"), 0.0) * 0.62 - 2.0)
        fx = float(np.clip(fx, -14, 48))
        bx = float(np.clip(min(cb_s[i], min(thigh_flex(world, "Right"), thigh_flex(world, "Left"), 0.0) * 0.45 + 2.0), -24, 12))
        rl = float(np.clip(-r_s[i] * 0.6, -14, 14))
        # rx(+a) lifts a hanging plate toward his front
        local["ClothFront"] = homog(rz(math.radians(rl)) @ rx(math.radians(fx)))
        local["ClothBack"] = homog(rz(math.radians(rl)) @ rx(math.radians(bx)))
        world["ClothFront"] = pivoted(world["LowerTorso"], "ClothFront", local["ClothFront"])
        world["ClothBack"] = pivoted(world["LowerTorso"], "ClothBack", local["ClothBack"])


# ---------------------------------------------------------------------------------------------------- export
TOL_DEG, TOL_POS = 0.6, 0.008


def decimate(baked, keep_times):
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
                for part in ALL:
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


def pose_xml(part, local, indent):
    pad = "\t" * indent
    M = local.get(part, np.eye(4))
    kids = "".join(pose_xml(k, local, indent + 1) for k in CHILDREN.get(part, []))
    return ('%s<Item class="Pose" referent="%s"><Properties><string name="Name">%s</string>'
            '<CoordinateFrame name="CFrame">%s</CoordinateFrame><float name="Weight">1</float>'
            '<token name="EasingStyle">0</token><token name="EasingDirection">0</token></Properties>\n%s%s</Item>\n'
            % (pad, ZX.ref(), part, ZX.cframe(M), kids, pad))


def write_rbxmx(clip, baked, path):
    ZX._ref[0] = 0
    idx = decimate([(b[0], b[1]) for b in baked], list(clip.contacts))
    body = "".join('\t<Item class="Keyframe" referent="%s"><Properties><string name="Name">Keyframe</string>'
                   '<float name="Time">%.6f</float></Properties>\n%s\t</Item>\n' % (ZX.ref(), baked[i][0], pose_xml("HumanoidRootPart", baked[i][1], 2)) for i in idx)
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">\n'
           '<Item class="KeyframeSequence" referent="%s"><Properties><string name="Name">%s</string>'
           '<bool name="Loop">%s</bool><token name="Priority">%d</token><float name="AuthoredHipHeight">2.192423</float>'
           '</Properties>\n%s</Item>\n</roblox>\n' % (ZX.ref(), clip.name, "true" if clip.loop else "false", ZX.PRIORITY[clip.priority], body))
    path.write_text(xml)
    return len(idx)


# ---------------------------------------------------------------------------------------------------- validation
_samples = None


def samples():
    global _samples
    if _samples is None:
        data = np.load(SAMPLES_FILE)
        _samples = {k: data[k].astype(float) for k in data.files}
    return _samples


def place(world, name):
    pts = samples()[name]
    W = world[BONE_OF.get(name, name)]
    return pts @ W[:3, :3].T + W[:3, 3]


def striker_points(world, striker):
    return place(world, "Weapon" if striker == "maul" else "Shield")


def blow(world, striker):
    """The striker point farthest from his root axis, and its radius, yaw (+ right) and height."""
    pts = striker_points(world, striker)
    r = np.hypot(pts[:, 0], pts[:, 2])
    i = int(np.argmax(r))
    p = pts[i]
    return p, float(r[i]), math.degrees(math.atan2(p[0], -p[2]))


def check_rigs():
    """src/shared/BossRigs.luau is what the game applies and rigdef.py is what the clips were solved on: they must agree."""
    text = (Path(__file__).resolve().parents[3] / "src/shared/BossRigs.luau").read_text()
    found = {m[0]: (m[1], tuple(float(x) for x in m[2].split(","))) for m in re.findall(r'Bone = "(\w+)", Parent = "(\w+)",(?: Motor = "\w+",)? At = V\(([^)]*)\)', text)}
    wanted = {b: (v[0], tuple(v[1])) for b, v in {**R.JOINT, **R.HELPER}.items()}
    if found != wanted:
        raise SystemExit("BossRigs.luau and rigdef.py disagree: " + ", ".join(sorted(k for k in set(found) | set(wanted) if found.get(k) != wanted.get(k))))


def validate(clip, baked):
    w = {"arm_reach": 0.0, "leg_reach": 0.0, "lowest": 9.0, "planted_slide": 0.0, "maul_through_head": 0.0, "shield_through_torso": 0.0, "loop_seam_deg": 0.0}
    problems = []
    last_feet = {}
    for frame_i, (t, local, world, diag, c) in enumerate(baked):
        w["arm_reach"] = max(w["arm_reach"], diag.get("arm_reach", 0.0))
        w["leg_reach"] = max(w["leg_reach"], diag.get("leg_reach", 0.0))
        for name, slack in (("Shield", 0.35), ("RightFoot", 0), ("LeftFoot", 0), ("RightLowerLeg", 0.25), ("LeftLowerLeg", 0.25)):  # a planted rim or greave edge may bite the ground
            w["lowest"] = min(w["lowest"], float(place(world, name)[:, 1].min()) + slack)
        W = world["RightHand"]  # the maul's head and haft; the chains hanging from it may trail on the ground
        head = samples()["Weapon"]
        head = head[head[:, 1] > -2.56]
        w["lowest"] = min(w["lowest"], float((head @ W[:3, :3].T + W[:3, 3])[:, 1].min()))
        # feet planted: a foot at the ground should not skate
        for side, key in (("Right", "rf"), ("Left", "lf")):
            A = (world[side + "Foot"] @ np.append(JOINT[side + "Foot"], 1))[:3]
            flat = float(c[key][2]) <= 1e-6
            prev = last_feet.get(side)
            if prev is not None and flat and prev[1]:
                free = any(a <= t <= b for a, b in clip.feet_free)
                speed = np.linalg.norm((A - prev[0])[[0, 2]]) * FPS
                if not free:
                    w["planted_slide"] = max(w["planted_slide"], float(speed))
            last_feet[side] = (A, flat)
        head = (world["Head"] @ np.append(0.2, [2.0, -0.2, 1]))[:3]
        d = np.linalg.norm(place(world, "Weapon")[::9] - head, axis=1)
        w["maul_through_head"] = max(w["maul_through_head"], float(0.55 - d.min()))
        chest = (world["UpperTorso"] @ np.array([0.1, 0.8, 0.05, 1]))[:3]
        d = np.linalg.norm(place(world, "Shield")[::9] - chest, axis=1)
        w["shield_through_torso"] = max(w["shield_through_torso"], float(0.5 - d.min()))
    if w["arm_reach"] > 0.45:
        problems.append("hand short of its target by %.2f" % w["arm_reach"])
    if w["leg_reach"] > 0.1:
        problems.append("leg short of its foot by %.2f" % w["leg_reach"])
    if w["lowest"] < GROUND - 0.08:
        problems.append("%.2f below ground" % (GROUND - w["lowest"]))
    if w["planted_slide"] > 1.0:
        problems.append("planted foot slides %.2f rig/s" % w["planted_slide"])
    if w["maul_through_head"] > 0.2:
        problems.append("maul passes %.2f through his head" % w["maul_through_head"])
    if w["shield_through_torso"] > 0.25:
        problems.append("shield passes %.2f through his chest" % w["shield_through_torso"])
    if clip.loop:
        a, b = baked[0][1], baked[-1][1]
        w["loop_seam_deg"] = round(max(ZR.angle_of(a[p][:3, :3].T @ b[p][:3, :3]) for p in ALL), 2)
        if w["loop_seam_deg"] > 3.0:
            problems.append("loop seam %.1f deg" % w["loop_seam_deg"])
    if clip.active is not None:
        start, length, arc, reach, lunge = clip.active
        times = [b[0] for b in baked]
        ifirst = int(np.argmin([abs(x - start) for x in times]))
        ilast = int(np.argmin([abs(x - (start + length)) for x in times]))
        p0, r0, yaw0 = blow(baked[ifirst][2], clip.striker)
        p1, r1, yaw1 = blow(baked[ilast][2], clip.striker)
        best = max(blow(baked[i][2], clip.striker)[1] for i in range(ifirst, ilast + 1))
        peak = max(blow(b[2], clip.striker)[1] for b in baked)
        s = {"contact": [round(float(x), 2) for x in p0], "game_radius_at_contact": round(r0 * SCALE, 2), "game_radius_during_active": round(best * SCALE, 2),
             "game_radius_peak": round(peak * SCALE, 2), "server_reach": reach, "server_reach_with_lunge": round(reach + lunge * 0.35, 2), "standoff": round(BODY_MET, 2),
             "yaw_first": round(yaw0, 1), "yaw_last": round(yaw1, 1)}
        s["reach_gap"] = round(reach - best * SCALE, 2)
        if best * SCALE < BODY_MET - 0.5:
            problems.append("blow lands %.1f studs out; the body is met at %.1f" % (best * SCALE, BODY_MET))
        if arc > 40:
            s["sweep_deg"] = round(yaw1 - yaw0, 1)
            if yaw1 - yaw0 < arc * 0.45:
                problems.append("sweeps %.0f deg left to right; the server fans %d" % (yaw1 - yaw0, arc))
        w["strike"] = s
    return w, problems


BODY_MET = 7.1     # MobSpacing.standoff: 0.75 x Iron Hook's reach 9.5
