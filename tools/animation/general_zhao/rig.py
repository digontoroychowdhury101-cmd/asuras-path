"""General Zhao's R15 rig at template scale 1, measured from a live enemy rig in Studio (AnimationConstraint joints,
axis-aligned rig attachments), plus forward kinematics and the analytic limb IK used to bake every clip.

Space is HumanoidRootPart space in Roblox axes: +X right, +Y up, -Z forward. A joint's Pose.CFrame is its Transform:
    Part1 = Part0 * Attachment0 * Transform * Attachment1:Inverse()
The guandao is bound to RightHand (LooksDuelists: haft along hand -Z through hand-local (0, -0.1, z), butt at z = +1.3,
blade tip ~9.2 studs from the hand centre). Animation never moves the binding; the left hand is solved onto the shaft.
"""
import math

import numpy as np

# part: (parent, Attachment0 position in parent, Attachment1 position in part, joint name)
JOINTS = {
    "LowerTorso": ("HumanoidRootPart", (0, -1.0, 0), (0, -0.2, 0), "Root"),
    "UpperTorso": ("LowerTorso", (0, 0.2, 0), (0, -0.849, 0), "Waist"),
    "Head": ("UpperTorso", (0, 0.849, 0), (0, -0.5758, 0), "Neck"),
    "RightUpperArm": ("UpperTorso", (0.9716, 0.5975, 0), (-0.5005, 0.4189, 0), "RightShoulder"),
    "RightLowerArm": ("RightUpperArm", (0, -0.355, 0), (0, 0.2747, 0), "RightElbow"),
    "RightHand": ("RightLowerArm", (0, -0.5322, 0), (0, 0.1316, 0), "RightWrist"),
    "LeftUpperArm": ("UpperTorso", (-0.9716, 0.5975, 0), (0.5005, 0.4189, 0), "LeftShoulder"),
    "LeftLowerArm": ("LeftUpperArm", (0, -0.355, 0), (0, 0.2747, 0), "LeftElbow"),
    "LeftHand": ("LeftLowerArm", (0, -0.5322, 0), (0, 0.1316, 0), "LeftWrist"),
    "RightUpperLeg": ("LowerTorso", (0.5, -0.2, 0), (0, 0.4714, 0), "RightHip"),
    "RightLowerLeg": ("RightUpperLeg", (0, -0.4493, 0), (0, 0.4133, 0), "RightKnee"),
    "RightFoot": ("RightLowerLeg", (0, -0.5965, 0), (0, 0.106, 0), "RightAnkle"),
    "LeftUpperLeg": ("LowerTorso", (-0.5, -0.2, 0), (0, 0.4714, 0), "LeftHip"),
    "LeftLowerLeg": ("LeftUpperLeg", (0, -0.4493, 0), (0, 0.4133, 0), "LeftKnee"),
    "LeftFoot": ("LeftLowerLeg", (0, -0.5965, 0), (0, 0.106, 0), "LeftAnkle"),
}
ORDER = list(JOINTS)  # parents always precede children
SIZES = {
    "HumanoidRootPart": (2, 2, 1), "LowerTorso": (1.991, 0.401, 1.004), "UpperTorso": (1.943, 1.698, 1.004),
    "Head": (1.159, 1.182, 1.161), "RightUpperArm": (1.001, 1.242, 1.002), "RightLowerArm": (1.001, 1.118, 1.002),
    "RightHand": (0.984, 0.316, 1.028), "LeftUpperArm": (1.001, 1.242, 1.002), "LeftLowerArm": (1.001, 1.118, 1.002),
    "LeftHand": (0.984, 0.316, 1.028), "RightUpperLeg": (0.993, 1.363, 0.973), "RightLowerLeg": (0.993, 1.301, 0.973),
    "RightFoot": (1.009, 0.312, 1.001), "LeftUpperLeg": (0.993, 1.363, 0.973), "LeftLowerLeg": (0.993, 1.301, 0.973),
    "LeftFoot": (1.009, 0.312, 1.001),
}
GROUND = -3.1924          # sole height in root space (HipHeight 2.1924 + half the root part)
FOOT_HALF = 0.156         # foot half height: a planted foot's centre sits at GROUND + FOOT_HALF
FOOT_LEN = 1.001
# Weapon bind: the v2 production guandao (assets/source/bosses/general_zhao/v2_design, Zhao_GuandaoHaft/Blade,
# welded to RightHand). Its haft runs along hand -Z through hand-local (-0.21, -0.03): the v2 hands sit 0.21 inward
# of the R15 hand centres, so the left fist's hole is at LeftHand-local (+0.21, -0.03). The blocky LooksDuelists
# fallback held it at (0, -0.1); clip grips were authored against that line, so right_arm moves the hand by
# AUTHORED_HAFT - HAFT and the weapon path is unchanged.
HAFT = np.array([-0.21, -0.03, 0.0])
LEFT_PALM = np.array([0.21, -0.03, 0.0])
AUTHORED_HAFT = np.array([0.0, -0.1, 0.0])
BUTT_Z, TIP_Z = 1.74, -9.2  # hand-local z of the butt spike and the blade tip
TIP = np.array([-0.21, 0.85, -9.2])  # crescent tip, the v2 blade's farthest vertex (9.24 studs from the hand)
EDGE = np.array([-0.21, 0.55, -8.1])  # lightning edge centre in RightHand space
BOSS_SCALE = 1.2


# ----------------------------------------------------------------------------------------------- math
def v(*a):
    return np.array(a[0] if len(a) == 1 else a, dtype=float)


def unit(a):
    n = np.linalg.norm(a)
    return a / n if n > 1e-9 else a * 0


def rx(d):
    c, s = math.cos(math.radians(d)), math.sin(math.radians(d))
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def ry(d):
    c, s = math.cos(math.radians(d)), math.sin(math.radians(d))
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rz(d):
    c, s = math.cos(math.radians(d)), math.sin(math.radians(d))
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def euler(e):
    """CFrame.Angles(x, y, z) order (R = Rx * Ry * Rz), degrees."""
    return rx(e[0]) @ ry(e[1]) @ rz(e[2])


def axis_angle(axis, deg):
    a = unit(np.asarray(axis, float))
    x, y, z = a
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    C = 1 - c
    return np.array([[c + x * x * C, x * y * C - z * s, x * z * C + y * s],
                     [y * x * C + z * s, c + y * y * C, y * z * C - x * s],
                     [z * x * C - y * s, z * y * C + x * s, c + z * z * C]])


def quat(R):
    t = np.trace(R)
    if t > 0:
        s = math.sqrt(t + 1) * 2
        q = [0.25 * s, (R[2, 1] - R[1, 2]) / s, (R[0, 2] - R[2, 0]) / s, (R[1, 0] - R[0, 1]) / s]
    elif R[0, 0] > R[1, 1] and R[0, 0] > R[2, 2]:
        s = math.sqrt(1 + R[0, 0] - R[1, 1] - R[2, 2]) * 2
        q = [(R[2, 1] - R[1, 2]) / s, 0.25 * s, (R[0, 1] + R[1, 0]) / s, (R[0, 2] + R[2, 0]) / s]
    elif R[1, 1] > R[2, 2]:
        s = math.sqrt(1 + R[1, 1] - R[0, 0] - R[2, 2]) * 2
        q = [(R[0, 2] - R[2, 0]) / s, (R[0, 1] + R[1, 0]) / s, 0.25 * s, (R[1, 2] + R[2, 1]) / s]
    else:
        s = math.sqrt(1 + R[2, 2] - R[0, 0] - R[1, 1]) * 2
        q = [(R[1, 0] - R[0, 1]) / s, (R[0, 2] + R[2, 0]) / s, (R[1, 2] + R[2, 1]) / s, 0.25 * s]
    return unit(np.array(q))


def mat(q):
    w, x, y, z = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def slerp(q0, q1, t):
    d = float(np.dot(q0, q1))
    if d < 0:
        q1, d = -q1, -d
    if d > 0.9995:
        return unit(q0 + (q1 - q0) * t)
    th = math.acos(min(1.0, d))
    return (math.sin((1 - t) * th) * q0 + math.sin(t * th) * q1) / math.sin(th)


def angle_of(R):
    return math.degrees(math.acos(max(-1.0, min(1.0, (np.trace(R) - 1) / 2))))


def frame(R=None, p=(0, 0, 0)):
    M = np.eye(4)
    if R is not None:
        M[:3, :3] = R
    M[:3, 3] = p
    return M


def T(p):
    return frame(None, p)


def align(b_local, n_local, b_world, n_world):
    """Rotation taking local bone axis b to world b and, about it, local n as close as possible to world n."""
    b0, b1 = unit(np.asarray(b_local, float)), unit(np.asarray(b_world, float))
    n0 = unit(n_local - b0 * np.dot(n_local, b0))
    n1 = unit(n_world - b1 * np.dot(n_world, b1))
    if np.linalg.norm(n1) < 1e-6:
        n1 = unit(np.cross(b1, [0, 0, 1])) if abs(b1[2]) < 0.9 else unit(np.cross(b1, [1, 0, 0]))
    L = np.column_stack([b0, n0, np.cross(b0, n0)])
    W = np.column_stack([b1, n1, np.cross(b1, n1)])
    return W @ L.T


# ----------------------------------------------------------------------------------------------- kinematics
def fk(local):
    """local: {part: 4x4 Transform}. Returns {part: 4x4 world (root-space) frame} including HumanoidRootPart."""
    world = {"HumanoidRootPart": np.eye(4)}
    for part in ORDER:
        parent, a0, a1, _ = JOINTS[part]
        world[part] = world[parent] @ T(a0) @ local.get(part, np.eye(4)) @ T(-np.asarray(a1, float))
    return world


def joint_world(world, part):
    """World position of the joint that attaches `part` to its parent."""
    parent, a0, _, _ = JOINTS[part]
    return (world[parent] @ np.append(np.asarray(a0, float), 1))[:3]


def hand_frame(grip, direction, roll, up_hint=(0, 1, 0)):
    """RightHand world rotation for a shaft pointing along `direction` (hand -Z), rolled `roll` degrees about it.
    Roll 0 puts hand +Y (the blade's edge side) as close to world up as the direction allows."""
    d = unit(np.asarray(direction, float))
    up = np.asarray(up_hint, float)
    if abs(np.dot(d, unit(up))) > 0.97:
        up = np.array([0, 0, -1.0]) if abs(d[2]) < 0.97 else np.array([0, 1.0, 0])
    y = unit(up - d * np.dot(up, d))
    y = axis_angle(d, roll) @ y
    z = -d
    x = np.cross(y, z)
    return np.column_stack([x, y, z]), np.asarray(grip, float)


def two_bone(S, W, l1, l2, pole):
    """Elbow/knee position for chain S -> E -> W with lengths l1, l2, bending toward `pole` (a direction)."""
    D = W - S
    d = np.linalg.norm(D)
    reach = (l1 + l2) * 0.99995
    dc = min(max(d, abs(l1 - l2) + 1e-4), reach)
    u = unit(D) if d > 1e-9 else np.array([0, -1.0, 0])
    a = (l1 * l1 - l2 * l2 + dc * dc) / (2 * dc)
    h = math.sqrt(max(l1 * l1 - a * a, 0))
    p = np.asarray(pole, float)
    p = unit(p - u * np.dot(p, u))
    if np.linalg.norm(p) < 1e-6:
        p = unit(np.cross(u, [1, 0, 0]))
    return S + u * a + p * h, d - dc  # elbow, unreachable excess (>0 means the target was out of reach)


def solve_limb(world, local, upper, lower, end, target_R, target_end_pos, pole, hinge_sign):
    """Analytic IK for shoulder/hip -> elbow/knee -> wrist/ankle with the end part's world rotation fixed.
    Writes local Transforms for upper, lower and end; returns the reach excess (studs) for validation.
    hinge_sign: the bend direction of the lower bone about local +X (-1 forearm flexes toward -Z, +1 shin toward +Z)."""
    _, _, a1u, _ = JOINTS[upper]
    _, a0l, a1l, _ = JOINTS[lower]
    _, a0e, a1e, _ = JOINTS[end]
    S = joint_world(world, upper)
    W = target_end_pos + target_R @ np.asarray(a1e, float)  # wrist/ankle joint from the end part's target frame
    b1_local = np.asarray(a0l, float) - np.asarray(a1u, float)  # upper bone vector in upper-part space
    b2_local = np.asarray(a0e, float) - np.asarray(a1l, float)  # lower bone vector in lower-part space
    l1, l2 = np.linalg.norm(b1_local), np.linalg.norm(b2_local)
    E, excess = two_bone(S, W, l1, l2, pole)
    f = unit(W - E)
    # Upper: bone onto S->E; twist so the hinge (local X) is perpendicular to the lower bone and bends the right way.
    hinge_world = unit(np.cross(unit(E - S), f)) * (-hinge_sign)
    if np.linalg.norm(np.cross(unit(E - S), f)) < 1e-4:  # straight limb: keep the hinge from the pole
        hinge_world = unit(np.cross(unit(E - S), unit(np.asarray(pole, float)))) * (-hinge_sign)
    parentU = world[JOINTS[upper][0]][:3, :3]
    Ru = align(b1_local, np.array([1.0, 0, 0]), E - S, hinge_world)
    local[upper] = frame(parentU.T @ Ru)
    world[upper] = world[JOINTS[upper][0]] @ T(JOINTS[upper][1]) @ local[upper] @ T(-np.asarray(a1u, float))
    # Lower: bone onto E->W; split forearm/shin twist halfway between the hinge and the end part's X.
    end_x = target_R[:, 0]
    x_mix = unit(unit(Ru[:, 0] - f * np.dot(Ru[:, 0], f)) + unit(end_x - f * np.dot(end_x, f)))
    if np.linalg.norm(x_mix) < 1e-6:
        x_mix = Ru[:, 0]
    Rl = align(b2_local, np.array([1.0, 0, 0]), f, x_mix)
    local[lower] = frame(Ru.T @ Rl)
    world[lower] = world[upper] @ T(a0l) @ local[lower] @ T(-np.asarray(a1l, float))
    local[end] = frame(Rl.T @ target_R)
    world[end] = world[lower] @ T(a0e) @ local[end] @ T(-np.asarray(a1e, float))
    return excess


def shaft_point(hand_world, s):
    """World point on the shaft at hand-local z = s (negative toward the blade)."""
    return (hand_world @ np.array([HAFT[0], HAFT[1], s, 1.0]))[:3]


def foot_frame(x, z, lift=0.0, yaw=0.0, pitch=0.0, pivot="toe"):
    """Foot centre frame: sole at GROUND + lift, yawed about Y, pitched about the foot's X through the toe or heel
    (pitch < 0 raises the heel when pivot is the toe)."""
    R = ry(yaw) @ rx(pitch)
    base = np.array([x, GROUND + lift, z])
    half = FOOT_LEN / 2
    if pivot == "toe":
        edge = np.array([0, 0, -half])
    elif pivot == "heel":
        edge = np.array([0, 0, half])
    else:
        edge = np.zeros(3)
    p_edge = base + ry(yaw) @ edge  # sole contact point on the ground
    centre = p_edge + R @ (np.array([0, FOOT_HALF, 0]) - edge)
    return R, centre


def obb_points(world, part, inflate=0.0):
    sx, sy, sz = (np.asarray(SIZES[part]) / 2) + inflate
    M = world[part]
    return [(M @ np.array([x, y, z, 1]))[:3] for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]


# Exit cost per local axis when pushing a shaft out of a part box: through the front or back first (the weapon passes
# in front of a body), then the sides, and over the top or under the bottom last.
EXIT_WEIGHT = np.array([1.4, 2.0, 1.0])


def segment_obb_push(world, part, p0, p1, inflate=0.0, samples=24):
    """The smallest world translation (by EXIT_WEIGHT) that carries a segment's deepest point out of a part box; zero
    when the segment is already clear."""
    M = world[part]
    inv = np.linalg.inv(M)
    half = np.asarray(SIZES[part]) / 2 + inflate
    best, push = 0.0, np.zeros(3)
    for i in range(samples + 1):
        q = (inv @ np.append(p0 + (p1 - p0) * (i / samples), 1))[:3]
        if np.any(np.abs(q) >= half):
            continue
        depth = half - np.abs(q)  # distance to the nearer face on each axis
        axis = int(np.argmin(depth * EXIT_WEIGHT))
        if depth[axis] > best:
            v = np.zeros(3)
            v[axis] = (depth[axis] + 0.01) * (1.0 if q[axis] >= 0 else -1.0)
            best, push = depth[axis], M[:3, :3] @ v
    return push


def segment_obb_distance(world, part, p0, p1, inflate=0.0, samples=24):
    """Smallest signed clearance from a segment to a part box (negative = inside)."""
    M = world[part]
    inv = np.linalg.inv(M)
    half = np.asarray(SIZES[part]) / 2 + inflate
    best = 1e9
    for i in range(samples + 1):
        p = p0 + (p1 - p0) * (i / samples)
        q = (inv @ np.append(p, 1))[:3]
        d = np.abs(q) - half
        outside = np.linalg.norm(np.maximum(d, 0))
        inside = min(max(d[0], d[1], d[2]), 0)
        best = min(best, outside + inside)
    return best
