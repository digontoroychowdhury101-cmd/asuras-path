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
    "larm": (30, 0, -25), "lfore": (40, 0, 0), "lhand": (0, 0, 0),  # a released front hand: forward, for balance
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
        self.field = None  # per-frame corrections from fields(): grip offset (N, 3), elbow swivels and front-hand release

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
        c["rswivel"] = c["lswivel"] = 0.0
        if self.field is not None:
            grip, rsw, lsw, free = self.field
            x = np.arange(len(rsw)) / FPS
            c["grip"] = tuple(np.asarray(c["grip"], float) + [np.interp(t, x, grip[:, k]) for k in range(3)])
            c["rswivel"], c["lswivel"] = float(np.interp(t, x, rsw)), float(np.interp(t, x, lsw))
            c["lfree"] = max(float(c["lfree"]), float(np.interp(t, x, free)))
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
            pole = rig.axis_angle(unit(pH - S), c.get("rswivel", 0.0)) @ np.asarray(c["relb"], float)
            excess = rig.solve_limb(trial_w, trial_l, "RightUpperArm", "RightLowerArm", "RightHand", RH, pH, pole, -1)
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
        if not ok:  # out of reach in the keyed range: slide along the haft, as real hands do, before giving up
            ok = [s for s in np.arange(SLIDE[0], SLIDE[1] + 1e-6, 0.02)
                  if np.linalg.norm(rig.shaft_point(hand, s) - S) <= REACH - 0.03]
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
            pole = rig.axis_angle(unit(pL - S), c.get("lswivel", 0.0)) @ np.asarray(c["lelb"], float)
            excess = rig.solve_limb(trial_w, trial_l, "LeftUpperArm", "LeftLowerArm", "LeftHand", RL, pL, pole, -1)
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
        """Tilts a weapon key's direction up when its blade would cut the floor (outside the clip's ground windows).
        Everything else about the key is kept as authored."""
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
                    if log is not None:
                        log.append((round(t, 3), "blade lifted off the floor"))
            # body clearance is the per-frame correction fields' job (smooth, small, intent-keeping); the old key
            # nudge searched up to a stud and 60 degrees and could turn a follow-through backwards

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

    # -------------------------------------------------------------------------- per-frame correction fields
    def fields(self, rounds=2, log=None):
        """Smooth per-frame corrections, solved on every 60 Hz frame and then dilated and blurred so they never pop:
        a grip offset that carries the shaft out of the body (in front of it by preference, rig.EXIT_WEIGHT) and,
        per arm, the elbow swivel about the shoulder-wrist line that bends the wrist least."""
        times = self.frames()
        n = len(times)
        grip, rsw, lsw, free = np.zeros((n, 3)), np.zeros(n), np.zeros(n), np.zeros(n)
        self.field = (grip, rsw, lsw, free)
        for r in range(rounds):
            push, rbest, lbest, gap = np.zeros((n, 3)), np.zeros(n), np.zeros(n), np.zeros(n)
            for i, t in enumerate(times):
                c = self.controls(t)
                _, world, diag = self.solve(c)
                push[i] = self.clearance_push(c, world)
                rbest[i] = self.best_swivel(c, "rswivel", "Right", rsw[i])
                if diag.get("grip_s") is not None and c["lfree"] <= 1e-3:
                    lbest[i] = self.best_swivel(c, "lswivel", "Left", lsw[i])
                    gap[i] = 1.0 if (diag.get("grip_error") or 0.0) > 0.06 else 0.0
                else:
                    lbest[i] = lsw[i]
                    gap[i] = free[i]
            if r == 0:
                opens_released = gap[0] > 0  # the keyed first frame itself has the front hand out of reach
            grip += smooth_field(push)
            rsw[:] = smooth_field(rbest[:, None])[:, 0]
            lsw[:] = smooth_field(lbest[:, None])[:, 0]
            # the front hand lets go (smoothly) where no point of the haft is in its reach, instead of floating
            free[:] = np.maximum(free, np.clip(smooth_field(gap[:, None])[:, 0], 0.0, 1.0))
            if log is not None:
                log.append(("field", round(float(np.abs(push).max()), 3)))
        # taper to nothing at both ends, so every attack starts and ends exactly on its keyed pose (the idle guard): the
        # elbow swivels (non-zero even on the clean guard) over FIELD_EDGE, the grip, which a fast swing may need from
        # its second frame, over FIELD_EDGE_GRIP; the front hand's release over FIELD_EDGE too, except at a start whose
        # keyed pose already has the front hand out of reach (a clip that opens from a run needs the release at once)
        tail = self.length - np.asarray(times)
        edge = np.minimum(times, tail)
        smooth = lambda x: x * x * (3 - 2 * x)  # noqa: E731
        w = smooth(np.clip(edge / FIELD_EDGE, 0.0, 1.0))
        wg = smooth(np.clip(edge / FIELD_EDGE_GRIP, 0.0, 1.0))
        wf = smooth(np.clip((tail if opens_released else edge) / FIELD_EDGE, 0.0, 1.0))
        self.field = (grip * wg[:, None], rsw * w, lsw * w, free * wf)

    def clearance_push(self, c, world):
        """The smallest reachable move of the hands, forward, out to his right or between (in the chest's frame),
        that lets the shaft clear the body by CLEAR_MARGIN: a polearm crossing the body passes in front of it, and a
        forward-pointing one keeps its butt beside the right hip. Zero when already clear."""
        def clear(w):
            hand = w["RightHand"]
            tip = (hand @ np.append(rig.TIP, 1))[:3]
            butt = rig.shaft_point(hand, rig.BUTT_Z)
            return min(rig.segment_obb_distance(w, p, butt, tip, CLEAR_MARGIN, 16) for p in CLEAR_PARTS)
        if clear(world) >= 0:
            return 0.0
        d0 = self.solve(c)[2]
        R = world["UpperTorso"][:3, :3]
        g0 = np.asarray(c["grip"], float)
        best = (clear(world), np.zeros(3))
        for a in np.arange(0.1, MAX_FORWARD + 1e-6, 0.1):  # the smallest move first, whichever way works
            for v in (-R[:, 2], R[:, 0], unit(R[:, 0] - R[:, 2])):
                trial = dict(c)
                trial["grip"] = tuple(g0 + v * a)
                _, w, d = self.solve(trial)
                if d["right_pull"] > 0.05 + d0["right_pull"]:  # beyond the arm's reach the grip is pulled back anyway
                    continue
                k = clear(w)
                if k >= 0:
                    return v * a
                if k > best[0] + 1e-3:
                    best = (k, v * a)
        return best[1]

    def best_swivel(self, c, channel, side, current):
        """The swivel (degrees, within SWIVEL_RANGE of the authored pole) whose solve bends this wrist least; turning
        away from the authored elbow costs a little so near-ties keep the animator's choice."""
        best = (1e9, current)
        for sw in np.arange(-SWIVEL_RANGE, SWIVEL_RANGE + 1e-6, 15.0):
            trial = dict(c)
            trial[channel] = float(sw)
            _, world, _ = self.solve(trial)
            cost = wrist_bend(world, side) + abs(sw) * 0.15
            if cost < best[0]:
                best = (cost, float(sw))
        return best[1]

    def bake(self):
        out = []
        for t in self.frames():
            c = self.controls(t)
            local, world, diag = self.solve(c)
            out.append((t, local, world, diag, c))
        return out


REACH = 0.9216 + 0.8069 - 0.01
CLEAR_MARGIN = 0.08
MAX_FORWARD = 0.5  # beyond this the correction rewrites the pose instead of nudging it
SLIDE = (-3.6, -0.45)  # how far along the haft the front hand may slide when its keyed range is out of reach
SWIVEL_RANGE = 75.0
FIELD_DILATE, FIELD_SIGMA = 3, 3.0  # frames
FIELD_EDGE, FIELD_EDGE_GRIP = 0.1, 2 / 60  # seconds


def wrist_bend(world, side):
    """Degrees between the hand's +Y and its forearm's axis (flexion/deviation; twist excluded)."""
    hy, fy = world[side + "Hand"][:3, 1], world[side + "LowerArm"][:3, 1]
    return math.degrees(math.acos(max(-1.0, min(1.0, float(np.dot(hy, fy))))))


def smooth_field(v):
    """Dilates each frame to the strongest correction within FIELD_DILATE frames, then Gaussian-blurs it, so a
    correction starts before and ends after the frames that need it and never steps."""
    n = len(v)
    mag = np.linalg.norm(v, axis=1)
    out = np.zeros_like(v)
    for i in range(n):
        lo, hi = max(0, i - FIELD_DILATE), min(n, i + FIELD_DILATE + 1)
        out[i] = v[lo + int(np.argmax(mag[lo:hi]))]
    k = np.arange(-3 * int(FIELD_SIGMA), 3 * int(FIELD_SIGMA) + 1)
    w = np.exp(-0.5 * (k / FIELD_SIGMA) ** 2)
    w /= w.sum()
    pad = np.pad(out, ((len(k) // 2, len(k) // 2), (0, 0)), mode="edge")
    return np.stack([np.convolve(pad[:, j], w, mode="valid") for j in range(v.shape[1])], axis=1)
MOVE_COST = 0.12
BREAKDOWN_REACH = 0.35
BREAKDOWN_GAP = 0.04
CLEAR_PARTS = ("UpperTorso", "LowerTorso", "Head", "LeftUpperLeg", "RightUpperLeg")
MAX_ROLL = 40.0  # turning the edge further about the shaft is wrist flexion a rigid fist cannot fake


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
