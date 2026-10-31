"""Clip authoring: high-level control keys (root, chest, head look, guandao grip/direction/roll, left-hand slide along the
shaft, planted feet) eased between keys, solved per frame through rig.py's IK and baked to per-joint Transforms.

A key is (time, controls, ease). Every control channel interpolates on its own between the keys that set it, so a clip
only keys what changes. Ease names the curve of the segment that ends at that key.
"""
import copy
import math

import numpy as np

import rig
from rig import unit

FPS = 60  # bake rate; matches the 60 Hz server tick so contact frames land exactly

EASE = {
    "linear": lambda t: t,
    "in": lambda t: t * t * t,                      # slow start, hits hard
    "out": lambda t: 1 - (1 - t) ** 3,              # fast start, settles
    "inout": lambda t: t * t * (3 - 2 * t),         # smoothstep
    # strikes: rest-to-moving cubic Hermites that reach the contact key still travelling (end speed 1x / 1.5x the
    # segment's average) with no first-frame jump, so the blade lands on the contact, not a frame or five early
    "snap": lambda t: 2 * t * t - t ** 3,           # explosive release, arrives moving
    "whip": lambda t: 1.5 * t * t - 0.5 * t ** 3,   # tension held, then the strike accelerates through contact
    "settle": lambda t: 1 - (1 - t) ** 2,
    "hold": lambda t: 0.0,
    "step": lambda t: 1.0 if t >= 1 else 0.0,
}

DEFAULT = {
    "root": (0, 0, 0), "rootR": (0, 0, 0), "chest": (0, 0, 0), "neck": (0, 0, 0),
    "look": (0, 1.6, -40), "lookW": 0.85,
    "grip": (0.75, -0.95, 0.15), "dir": (0, 0, -1), "edge": (0, 1, 0), "roll": 0,
    "s": -1.7, "sMin": -2.8, "sMax": -0.9, "lroll": 0, "lfree": 0.0,
    "larm": (0, 0, 0), "lfore": (0, 0, 0), "lhand": (0, 0, 0),
    "lf": (-0.55, -0.55, 0, 10, 0), "rf": (0.75, 0.6, 0, 35, 0),  # x, z, lift, yaw, pitch (pitch pivots at toe)
    "relb": (1, -0.6, 0.6), "lelb": (-1, -0.8, 0.2), "lknee": (0, 0, -1), "rknee": (0.3, 0, -1),
}
VECTOR = {"root", "grip", "look", "relb", "lelb", "lknee", "rknee"}
EULER = {"rootR", "chest", "neck", "larm", "lfore", "lhand"}
SCALAR = {"lookW", "roll", "s", "sMin", "sMax", "lroll", "lfree"}
FEET = {"lf", "rf"}
DIRECTION = {"dir", "edge"}


class Clip:
    def __init__(self, name, length, keys, loop=False, priority="Action", markers=(), contacts=(), notes="",
                 hook="", timing="", base=None, layers=(), ground=(), velocity=(0.0, 0.0), preview=(), group="",
                 action="", wiring="existing", root_motion=False):
        self.name, self.length, self.loop, self.priority = name, float(length), loop, priority
        owned = {ch for _, c, _ in keys if c.get("_feet") for ch in c if ch in FEET}
        keys = [(t, c if c.get("_feet") else {k: v for k, v in c.items() if k not in owned}, e) for t, c, e in keys]
        self.keys = sorted(((float(t), {k: v for k, v in c.items() if k != "_feet"}, e) for t, c, e in keys),
                           key=lambda k: k[0])
        self.markers = sorted((float(t), n, str(val)) for t, n, val in markers)
        self.contacts = [float(c) for c in contacts]
        self.notes, self.hook, self.timing = notes, hook, timing
        self.base = dict(DEFAULT if base is None else base)
        self.layers = list(layers)  # functions (controls, t, clip) -> controls, applied after interpolation
        self.ground = [tuple(g) for g in ground]  # (start, end) windows where the guandao deliberately meets the floor
        self.velocity = tuple(velocity)  # nominal ground velocity (root space, scale 1) a locomotion cycle is built for
        self.preview = [float(p) for p in preview]
        self.group, self.action, self.wiring = group, action, wiring
        self.root_motion = root_motion  # footwork built against an assumed server turn/travel: feet move in root space

    def ground_contact(self, t):
        return any(a - 1e-6 <= t <= b + 1e-6 for a, b in self.ground)

    def manifest(self, keys, stats, problems):
        return {"group": self.group, "action": self.action, "length": round(self.length, 4), "loop": self.loop,
                "priority": self.priority, "contacts": self.contacts,
                "markers": [{"time": round(t, 4), "name": n, "value": v} for t, n, v in self.markers],
                "timing_source": self.timing, "playback_hook": self.hook, "wiring": self.wiring, "notes": self.notes,
                "nominal_ground_speed_scale1": round(math.hypot(*self.velocity), 3),
                "keyframes": keys, "file": self.name + ".rbxmx", "uploaded": False, "asset_id": None,
                "validation": stats, "problems": problems}

    def frames(self):
        n = int(round(self.length * FPS))
        return [i / FPS for i in range(n + 1)]

    # -------------------------------------------------------------------------- interpolation per channel
    def channel(self, name, t):
        keyed = [(kt, c[name], e) for kt, c, e in self.keys if name in c]
        if not keyed:
            return self.base[name]
        if self.loop and len(keyed) >= 1 and keyed[-1][0] < self.length:
            keyed = keyed + [(self.length, keyed[0][1], keyed[0][2])]  # wrap for a seamless loop
        if t <= keyed[0][0]:
            return keyed[0][1]
        for (t0, v0, _), (t1, v1, e1) in zip(keyed, keyed[1:]):
            if t <= t1:
                u = 0 if t1 <= t0 else (t - t0) / (t1 - t0)
                out = mix(name, v0, v1, EASE[e1](u))
                if name in FEET and t1 - t0 > 0.05:
                    out = step_arc(v0, v1, u, out)
                return out
        return keyed[-1][1]

    def controls(self, t):
        c = {name: self.channel(name, t) for name in self.base}
        for layer in self.layers:
            c = layer(c, t, self)
        return c

    # -------------------------------------------------------------------------- solve
    def solve(self, c):
        """Controls -> (local Transforms, world frames, diagnostics)."""
        local = {}
        root_R = rig.euler(c["rootR"])
        local["LowerTorso"] = rig.frame(root_R, c["root"])
        local["UpperTorso"] = rig.frame(rig.euler(c["chest"]))
        world = rig.fk(local)
        # head: blend a stabilised look-at with the chest-relative neck pose
        neck_local = rig.euler(c["neck"])
        head_pos = rig.joint_world(world, "Head")
        fwd = unit(np.asarray(c["look"], float) - head_pos)
        Rlook = rig.align(np.array([0, 0, -1.0]), np.array([0, 1.0, 0]), fwd, world["UpperTorso"][:3, :3][:, 1])
        Rchest = world["UpperTorso"][:3, :3]
        rel = Rchest.T @ Rlook
        q = rig.slerp(rig.quat(np.eye(3)), rig.quat(rel), float(c["lookW"]))
        rel = rig.mat(q)
        rel = clamp_rotation(rel, 75)
        local["Head"] = rig.frame(rel @ neck_local)
        world = rig.fk(local)
        diag = {}
        self.right_arm(world, local, c, diag)
        world = rig.fk(local)
        # left hand: on the shaft (sliding within [sMin, sMax] when the desired point is out of reach) or free FK
        if c["lfree"] >= 0.999:
            local["LeftUpperArm"] = rig.frame(rig.euler(c["larm"]))
            local["LeftLowerArm"] = rig.frame(rig.euler(c["lfore"]))
            local["LeftHand"] = rig.frame(rig.euler(c["lhand"]))
            world = rig.fk(local)
            diag["grip_s"], diag["left_excess"], diag["grip_error"] = None, 0.0, None
        else:
            s, excess = self.left_on_shaft(world, local, c)
            diag["grip_s"], diag["left_excess"] = s, excess
            if c["lfree"] > 1e-3:  # releasing or taking the shaft: blend the solved arm toward the free pose
                w = float(c["lfree"])
                for part, e in (("LeftUpperArm", "larm"), ("LeftLowerArm", "lfore"), ("LeftHand", "lhand")):
                    q0, q1 = rig.quat(local[part][:3, :3]), rig.quat(rig.euler(c[e]))
                    local[part] = rig.frame(rig.mat(rig.slerp(q0, q1, w)))
            world = rig.fk(local)
            diag["grip_error"] = grip_error(world, s) if c["lfree"] <= 1e-3 else None
        # legs: planted feet are IK targets, so a planted foot cannot slide
        for side, key, pole in (("Left", "lf", "lknee"), ("Right", "rf", "rknee")):
            x, z, lift, yaw, pitch = c[key]
            RF, pF = rig.foot_frame(x, z, lift, yaw, pitch)
            knee_pole = rig.ry(yaw) @ np.asarray(c[pole], float)
            diag[side.lower() + "_leg_excess"] = rig.solve_limb(world, local, side + "UpperLeg", side + "LowerLeg",
                                                                side + "Foot", RF, pF, knee_pole, 1)
        world = rig.fk(local)
        return local, world, diag

    def right_arm(self, world, local, c, diag):
        """RightHand = the guandao frame. The hand's +Y (the edge side) settles toward the forearm, as a fist around
        a shaft does; the keyed edge may turn it at most MAX_ROLL degrees about the shaft (forearm twist)."""
        d = unit(np.asarray(c["dir"], float))
        want = np.asarray(c["edge"], float)
        hint = want
        S = rig.joint_world(world, "RightUpperArm")
        for _ in range(3):
            RH, pH = rig.hand_frame(c["grip"], d, c["roll"], hint)
            pH = pH + RH @ (rig.AUTHORED_HAFT - rig.HAFT)
            W = pH + RH @ np.array([0, 0.1316, 0])
            over = np.linalg.norm(W - S) - REACH
            pull = max(0.0, float(over))
            if over > 0:  # never ask the arm for more than it has: pull the grip in along the overreach
                pH = pH - unit(W - S) * over
            trial_w, trial_l = dict(world), dict(local)
            excess = rig.solve_limb(trial_w, trial_l, "RightUpperArm", "RightLowerArm", "RightHand", RH, pH,
                                    c["relb"], -1)
            elbow = rig.joint_world(trial_w, "RightLowerArm")
            hint = roll_toward(d, elbow - (pH + RH @ np.array([0, 0.1316, 0])), want, MAX_ROLL)
        world.update(trial_w)
        local.update(trial_l)
        diag["right_pull"], diag["right_excess"] = pull, excess

    def left_on_shaft(self, world, local, c):
        """Front hand on the shaft: the reachable point nearest the keyed slide position, its fist wrapping toward
        its own forearm."""
        lo, hi = min(c["sMin"], c["sMax"]), max(c["sMin"], c["sMax"])
        want = min(max(c["s"], lo), hi)
        hand = world["RightHand"]
        S = rig.joint_world(world, "LeftUpperArm")
        ok = [s for s in np.arange(lo, hi + 1e-6, 0.02) if np.linalg.norm(rig.shaft_point(hand, s) - S) <= REACH - 0.03]
        if ok:
            s = min(ok, key=lambda v: abs(v - want))
        else:
            s = min(np.arange(lo, hi + 1e-6, 0.02), key=lambda v: np.linalg.norm(rig.shaft_point(hand, v) - S))
        s = float(s)
        d = -hand[:3, 2]
        hint = hand[:3, 1]
        for _ in range(3):
            RL = rig.hand_frame((0, 0, 0), d, c["lroll"], hint)[0]
            pL = rig.shaft_point(hand, s) - RL @ rig.LEFT_PALM
            trial_w, trial_l = dict(world), dict(local)
            excess = rig.solve_limb(trial_w, trial_l, "LeftUpperArm", "LeftLowerArm", "LeftHand", RL, pL, c["lelb"], -1)
            elbow = rig.joint_world(trial_w, "LeftLowerArm")
            hint = roll_toward(d, elbow - (pL + RL @ np.array([0, 0.1316, 0])), hint, 0.0)
        local.update(trial_l)
        return s, float(excess)

    # -------------------------------------------------------------------------- per-key repair
    def score(self, c, t):
        local, world, d = self.solve(c)
        hand = world["RightHand"]
        tip = (hand @ np.append(rig.TIP, 1))[:3]
        butt = rig.shaft_point(hand, rig.BUTT_Z)
        clear = min(rig.segment_obb_distance(world, p, butt, tip, 0.05, 16) for p in CLEAR_PARTS)
        pen = max(0.0, 0.08 - clear) * 4
        pen += d["left_excess"] * 2 + max(0.0, d["right_pull"] - 0.02) * 2 + d["right_excess"]
        if not self.ground_contact(t):
            edge = (hand @ np.append(rig.EDGE, 1))[:3]
            pen += max(0.0, rig.GROUND + 0.12 - min(tip[1], edge[1])) * 2
        return pen, world

    def repair(self, log=None):
        """Nudges each weapon key the least amount that keeps the shaft out of the body, the arms within reach and
        the blade off the floor. Intent (direction, edge, timing) is kept; only the grip position moves (and the
        direction tilts up when the blade would cut the floor)."""
        for i, (t, c, e) in enumerate(self.keys):
            if "grip" not in c:
                continue
            ctl = self.controls(t)
            pen, world = self.score(ctl, t)
            if pen < 1e-3:
                continue
            if not self.ground_contact(t):  # lift the blade out of the floor first
                hand_y = ctl["grip"][1]
                d = np.asarray(ctl["dir"], float)
                need = (rig.GROUND + 0.2 - hand_y) / 9.4
                if d[1] < need:
                    flat = unit(np.array([d[0], 0, d[2]]))
                    y = min(0.95, need)
                    d = unit(flat * math.sqrt(max(0.0, 1 - y * y)) + np.array([0, y, 0]))
                    c["dir"] = tuple(d)
                    ctl["dir"] = c["dir"]
                    pen, world = self.score(ctl, t)
            self.nudge(i, t, c, ctl, pen, world, log)

    def nudge(self, i, t, c, ctl, pen, world, log):
        if True:
            R = world["UpperTorso"][:3, :3]
            dirs = [-R[:, 2], R[:, 0], R[:, 1], -R[:, 1], R[:, 2], -R[:, 0],
                    unit(-R[:, 2] + R[:, 0]), unit(-R[:, 2] - R[:, 1]), unit(-R[:, 2] + R[:, 1])]
            best = (pen, np.zeros(3))
            g0 = np.asarray(ctl["grip"], float)
            # moving costs MOVE_COST per stud, so a marginal gain never buys a big jump; an in-between (breakdown)
            # key may move at most BREAKDOWN_REACH, so the hand path stays smooth at 60 Hz
            reach = 0.95 if i is not None else BREAKDOWN_REACH
            for step in np.arange(0.05, reach, 0.05):
                for dv in dirs:
                    trial = dict(ctl)
                    trial["grip"] = tuple(g0 + dv * step)
                    p, _ = self.score(trial, t)
                    p += step * MOVE_COST
                    if p < best[0] - 1e-4:
                        best = (p, dv * step)
                if best[0] < 1e-3 + step * MOVE_COST:
                    break
            chest = None
            if best[0] > 1e-3 and i is not None and not any(abs(t - k) < 0.02 for k in self.contacts):
                # still blocked away from a contact: swing the blade about the vertical (the butt then clears the
                # front of the body, as a real wind does), paying a little per degree so the smallest turn wins
                d0 = np.asarray(ctl["dir"], float)
                turned = None
                for yaw in (15, -15, 30, -30, 45, -45, 60, -60):
                    for grip in (g0 + best[1], g0):
                        trial = dict(ctl)
                        trial["dir"], trial["grip"] = tuple(rig.ry(yaw) @ d0), tuple(grip)
                        p, _ = self.score(trial, t)
                        p += abs(yaw) * 0.0004 + np.linalg.norm(grip - g0) * MOVE_COST
                        if p < best[0] - 1e-4:
                            best, turned = (p, grip - g0), trial["dir"]
                if turned:
                    c["dir"] = ctl["dir"] = turned
            if best[0] > 1e-3:  # still blocked: let the chest turn up to 25 degrees with the best grip found
                for yaw in (8, -8, 16, -16, 25, -25):
                    trial = dict(ctl)
                    trial["grip"] = tuple(g0 + best[1])
                    trial["chest"] = (ctl["chest"][0], ctl["chest"][1] + yaw, ctl["chest"][2])
                    p, _ = self.score(trial, t)
                    p += np.linalg.norm(best[1]) * MOVE_COST
                    if p < best[0] - 1e-4:
                        best, chest = (p, best[1]), trial["chest"]
            if np.linalg.norm(best[1]) > 0 or chest:
                c["grip"] = tuple(np.asarray(ctl["grip"], float) + best[1])
                if chest:
                    c["chest"] = chest
                if log is not None:
                    log.append((round(t, 3), round(float(np.linalg.norm(best[1])), 2), round(pen, 3), round(best[0], 3)))

    def breakdowns(self, log=None, rounds=10):
        """Adds grip breakdown keys where the swing between two keys carries the shaft through the body."""
        for _ in range(rounds):
            worst = (1e-3, None)
            key_times = [k[0] for k in self.keys if "grip" in k[1]]
            for t in np.arange(0, self.length + 1e-6, 1 / 60):
                if any(abs(t - kt) < BREAKDOWN_GAP for kt in key_times):  # never on consecutive frames: that zigzags
                    continue
                pen, _ = self.score(self.controls(t), t)
                if pen > worst[0]:
                    worst = (pen, float(t))
            if worst[1] is None:
                return
            t = worst[1]
            ctl = self.controls(t)
            nxt = next((k for k in self.keys if k[0] > t and "grip" in k[1]), None)
            entry = {"grip": ctl["grip"], "chest": ctl["chest"]}
            self.keys.append((t, entry, nxt[2] if nxt else "inout"))
            self.keys.sort(key=lambda k: k[0])
            pen, world = self.score(ctl, t)
            self.nudge(None, t, entry, ctl, pen, world, log)

    def bake(self):
        out = []
        for t in self.frames():
            c = self.controls(t)
            local, world, diag = self.solve(c)
            out.append((t, local, world, diag, c))
        return out


REACH = 0.9216 + 0.8069 - 0.01
MOVE_COST = 0.12
BREAKDOWN_REACH = 0.35
BREAKDOWN_GAP = 0.04
CLEAR_PARTS = ("UpperTorso", "LowerTorso", "Head", "LeftUpperLeg", "RightUpperLeg")
MAX_ROLL = 75.0


def roll_toward(d, natural, want, max_deg):
    """A hand +Y hint about shaft d: the natural direction (toward the forearm) turned toward `want` by at most
    max_deg degrees."""
    n = unit(natural - d * np.dot(natural, d))
    w = unit(want - d * np.dot(want, d))
    if np.linalg.norm(n) < 1e-6:
        return w if np.linalg.norm(w) > 1e-6 else np.array([0, 1.0, 0])
    if np.linalg.norm(w) < 1e-6 or max_deg <= 0:
        return n
    ang = math.degrees(math.atan2(np.dot(np.cross(n, w), d), np.dot(n, w)))
    ang = max(-max_deg, min(max_deg, ang))
    return rig.axis_angle(d, ang) @ n


def grip_error(world, s):
    """Distance from the left hand's shaft line point to the actual shaft (0 = the shaft passes through the palm)."""
    target = rig.shaft_point(world["RightHand"], s)
    actual = (world["LeftHand"] @ np.append(rig.LEFT_PALM, 1.0))[:3]
    return float(np.linalg.norm(target - actual))


def clamp_rotation(R, max_deg):
    ang = rig.angle_of(R)
    if ang <= max_deg:
        return R
    q = rig.quat(R)
    return rig.mat(rig.slerp(np.array([1.0, 0, 0, 0]), q, max_deg / ang))


def mix(name, a, b, u):
    if name in DIRECTION:
        a, b = unit(np.asarray(a, float)), unit(np.asarray(b, float))
        d = float(np.clip(np.dot(a, b), -1, 1))
        th = math.acos(d)
        if th < 1e-5:
            return a
        if abs(math.pi - th) < 1e-3:  # opposite: rotate through up
            axis = unit(np.cross(a, [0, 1, 0]))
            return rig.axis_angle(axis, math.degrees(th) * u) @ a
        return (math.sin((1 - u) * th) * a + math.sin(u * th) * b) / math.sin(th)
    if name in FEET:
        return tuple(x + (y - x) * u for x, y in zip(a, b))
    if isinstance(a, (tuple, list, np.ndarray)):
        return tuple(x + (y - x) * u for x, y in zip(a, b))
    return a + (b - a) * u


def step_arc(a, b, u, out):
    """A foot that changes place between two sparse keys steps (lifts in an arc, toe-off pitch) instead of sliding."""
    dist = math.hypot(b[0] - a[0], b[1] - a[1])
    if dist < 0.06:
        return out
    arc = min(0.35, 0.45 * dist + 0.08) * math.sin(math.pi * u)
    pitch = -14 * math.sin(math.pi * min(1.0, u * 1.6)) if u < 0.62 else 0.0
    return (out[0], out[1], out[2] + arc, out[3], out[4] + pitch)


def merged(*dicts, **kw):
    out = {}
    for d in dicts:
        out.update(copy.deepcopy(d))
    out.update(kw)
    return out


def add(vec, delta):
    return tuple(a + b for a, b in zip(vec, delta))
