"""(2026-11-13) Grandmaster Shen: his arms' skin at the shoulder seam and armpit, as the review x-ray sees it, cleared after joint_polish.

The validator and joint_polish judge an arm in his torso on the arm's skin samples that lay clear of the torso in the bind pose
(shen_lib.arm_torso_world, dense). The review x-ray (tools/blender/shen_import/review.py, SHEN_REVIEW_CLASH=UpperTorso with both arms) judges
every arm vertex of the real mesh in UpperTorso's distance field, the seam's skin included, and it plays each clip inside a shot that fades in
from Idle and back out to Idle (shots_fade.py: 0.2 s smoothstep, joint by joint). Seven phase 2 clips were past its 0.18 there with the
validator clean (windows-pass REPORT section 16). Clip.seam opts a clip in; this pass then also counts:
  - the x-ray's own measure (XRay below: review.py's rules on the same mesh data, xray_p<phase>.npz from tools/blender/shen_import/xray_dump.py;
    checked equal to review.py's logged depths), per arm, at its depth less x_delta;
  - the review shot's fade poses (Idle 0.6 s, the clip, Idle 0.8 s at 30 fps: the fade in draws clip frames 1-5 mixed with Idle, the fade out
    mixes the clip's last drawn frame into Idle), on the frame each is drawn from. Idle comes from review_idle_p<phase>.npz (write_idle()).
Stages, in Clip.seam's order:
  ("nudge", {x_delta, sigmas, target, mags, degs, slides})   every run of frames past the wall on one arm is cleared by the cheapest eased change found among: the arm's elbow swung
                  about its shoulder-wrist line, the fist (with the haft and both grips) moved along ARM_TORSO_DIRS, the lead hand's place
                  on the haft (lsl). Kept only if both arms meet TARGET over the run and are no deeper elsewhere, the arm-in-weapon, reach,
                  grip and wrist limits are joint_polish's, no upper arm turns more in a frame than max(30 deg, the bake's) + 1, no pop the
                  clip kept under its limit passes it, and the frames outside the change solve exactly as before.
  ("polish", {"slide": bool, "x_delta": float, "margin": float, "turn_cap": bool})   joint_polish's windows (SLSQP, POLISH_PAD 2 here), on the same measures, with the lead
                  hand's place as a ninth control when slide.
Nothing else in the bake changes, and a clip without Clip.seam bakes exactly as before.
"""
import copy
import math
import os
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
FALL = {"Sk_LFing1": "Sk_LeftHand", "Sk_LFing2": "Sk_LeftHand"}     # the left fingers ride the hand here (the cloth step turns them in game)
SEAM_PAD = 2
NUDGE_TARGET = 0.16
NUDGE_DEGS = (6.0, 12.0)
NUDGE_MAGS = (0.03, 0.06, 0.1)
NUDGE_SLIDES = (0.1, 0.2, 0.3, -0.1)
NUDGE_MAXPASS = 12
NUDGE_SIGMAS = (1.5, 2.5, 4.0)
STEP_FREE = 30.0
REVIEW_FPS, REVIEW_FADE, REVIEW_IDLE_IN = 30, 0.2, 0.6


class XRay:
    """review.py's arm x-ray: arm vertices inside UpperTorso's distance field past 0.03, only where the nearest UpperTorso vertex is over 0.8
    on Sk_UpperTorso, not counting vertices already inside in the bind pose; armature skinning with the weights normalised."""

    def __init__(self, phase):
        from scipy.spatial import cKDTree
        d = np.load(ROOT / ("work/shen_import/xray_p%d.npz" % phase))
        self.P, self.G = d["P"], d["G"]
        W = d["W"]
        self.W = W / np.maximum(W.sum(1, keepdims=True), 1e-9)
        self.bones = [str(b) for b in d["bones"]]
        used = self.W.sum(0) > 0
        self.used = [i for i in range(len(self.bones)) if used[i]]
        sdf = np.load(ROOT / ("work/shen_import/sdf_p%d.npz" % phase))
        self.grid, self.lo, self.st = sdf["UpperTorso_grid"], sdf["UpperTorso_origin"], float(sdf["UpperTorso_step"])
        self.kd = cKDTree(d["TP"])
        self.tw = d["TW"]
        self.base = self._hit(self.P)[1]

    def subset(self, keep):
        o = copy.copy(self)
        o.P, o.G, o.W, o.base = self.P[keep], self.G[keep], self.W[keep], self.base[keep]
        used = o.W.sum(0) > 0
        o.used = [i for i in range(len(self.bones)) if used[i]]
        return o

    def side_depth(self, bones, fallback=None):
        d, hit = self.depth(bones, fallback, per_vertex=True)
        out = {}
        for s, m in (("Left", self.G < 3), ("Right", self.G >= 3)):
            h = hit & m
            out[s] = float(d[h].max()) if h.any() else 0.0
        return out

    def _depth(self, Q):
        q = (Q - self.lo) / self.st
        hi = np.array(self.grid.shape) - 1
        i0 = np.clip(np.floor(q).astype(int), 0, hi - 1)
        f = np.clip(q - i0, 0.0, 1.0)
        d = np.zeros(len(Q))
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    wgt = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                    d += wgt * self.grid[i0[:, 0] + dx, i0[:, 1] + dy, i0[:, 2] + dz]
        d[np.any((q < 0) | (q > hi), axis=1)] = 1.0
        return -d

    def _hit(self, Q):
        d = self._depth(Q)
        hit = d > 0.03
        idx = np.nonzero(hit)[0]
        if len(idx):
            _, nn = self.kd.query(Q[idx])
            hit[idx[self.tw[nn] <= 0.8]] = False
        return d, hit

    def posed(self, bones, fallback=None):
        X = np.zeros_like(self.P)
        for i in self.used:
            b = self.bones[i]
            R, t = bones[b] if b in bones else bones[fallback[b]]
            w = self.W[:, i]
            m = w > 0
            X[m] += w[m, None] * (self.P[m] @ R.T + t)
        return X

    def depth(self, bones, fallback=None, per_vertex=False):
        X = self.posed(bones, fallback)
        R, t = bones["Sk_UpperTorso"]
        d, hit = self._hit((X - t) @ R)
        hit &= ~self.base
        if per_vertex:
            return d, hit
        return (float(d[hit].max()) if hit.any() else 0.0), int(hit.sum())


_XRAY = {}


def xray(phase):
    if phase not in _XRAY:
        _XRAY[phase] = XRay(phase)
    return _XRAY[phase]


def bones_of(world):
    return {"Sk_" + p: (M[:3, :3], M[:3, 3]) for p, M in world.items()}


def np_world(w):
    return {k: np.asarray(v, float) for k, v in w.items()}


def _cb():
    import cloth_bake
    return cloth_bake


def _smooth(t):
    x = t / REVIEW_FADE
    return x * x * (3 - 2 * x)


def _at(worlds, length, t, loop):
    q = (t % length) if loop else min(t, length)
    f = q * REVIEW_FPS
    i0 = min(int(f), len(worlds) - 1)
    i1 = min(i0 + 1, len(worlds) - 1)
    fr = f - int(f)
    if fr < 1e-9:
        return worlds[i0]
    return _cb().lerp_pose(worlds[i0], worlds[i1], fr)


def write_idle(phase, baked):
    """Save Idle's baked worlds (a list of [t, local, world, ...] as Clip.bake returns) for the review fades: review_idle_p<phase>.npz."""
    names = list(baked[0][2].keys())
    np.savez(ROOT / ("work/shen_import/review_idle_p%d.npz" % phase), names=np.array(names),
             worlds=np.array([[np.asarray(o[2][k], float) for k in names] for o in baked]), times=np.array([float(o[0]) for o in baked]))


def _idle(phase):
    d = np.load(ROOT / ("work/shen_import/review_idle_p%d.npz" % phase))
    names = [str(x) for x in d["names"]]
    return [{k: d["worlds"][i, j] for j, k in enumerate(names)} for i in range(len(d["times"]))], float(d["times"][-1])


def review_extras(phase, length, n_frames):
    """{frame: [pose(world) -> world]}: the review shot's fade poses, on the clip frame each is drawn from."""
    cb = _cb()
    iw, ilen = _idle(phase)
    n = int(round(length * REVIEW_FPS))
    k_max = int(round(REVIEW_FADE * REVIEW_FPS))
    specs = [("in", k, _smooth(k / REVIEW_FPS), k / REVIEW_FPS) for k in range(1, k_max)] + \
            [("out", k, _smooth(k / REVIEW_FPS), (n - 1) / REVIEW_FPS) for k in range(1, k_max)]
    last_in = _at(iw, ilen, (int(round(REVIEW_IDLE_IN * REVIEW_FPS)) - 1) / REVIEW_FPS, True)
    out = {}
    for kind, k, u, t in specs:
        f = int(round(t * REVIEW_FPS))
        assert abs(t * REVIEW_FPS - f) < 1e-6 and f < n_frames
        if kind == "in":
            out.setdefault(f, []).append(lambda w, u=u: cb.fade_pose(last_in, np_world(w), u, phase))
        else:
            idle_k = _at(iw, ilen, k / REVIEW_FPS, True)
            out.setdefault(f, []).append(lambda w, u=u, idle_k=idle_k: cb.fade_pose(np_world(w), idle_k, u, phase))
    return out


class _Counting:
    """While active: shen_lib.arm_torso_world(..., dense=True) also counts the x-ray (xr, per arm, less delta)."""

    def __init__(self, L, xr, delta):
        self.L, self.xr, self.delta = L, xr, delta

    def __enter__(self):
        L, xr, delta = self.L, self.xr, self.delta
        self.orig = orig = L.arm_torso_world

        def counted(rg, world, pose=None, dense=False):
            r = orig(rg, world, pose, dense)
            if dense:
                x = xr.side_depth(bones_of(world), FALL)
                r = {s: max(r[s], x[s] - delta) for s in r}
            return r
        L.arm_torso_world = counted
        return self

    def __exit__(self, *a):
        self.L.arm_torso_world = self.orig


def _final(L, clip, ctrl, times):
    """Clip.bake()'s last solve, on a copy."""
    ctrl = copy.deepcopy(ctrl)
    out = []
    clip._side = {}
    for t, c in zip(times, ctrl):
        local, world, diag = clip.solve(c)
        out.append([t, local, world, diag, c])
    clip._side = None
    return out


def _subset(xr, base, extras, threshold):
    keep = np.zeros(len(xr.P), bool)
    for i, o in enumerate(base):
        for w in [o[2]] + [f_(o[2]) for f_ in extras.get(i, ())]:
            d, _h = xr.depth(bones_of(w), FALL, per_vertex=True)
            keep |= (d > threshold) & ~xr.base
    return xr.subset(keep)


def run(L, clip, ctrl, times):
    """Clip.seam's stages on ctrl (as joint_polish leaves it), in place. Returns a report per stage."""
    phase = 2 if "_P2_" in clip.name else 1
    report = []
    for stage, opts in clip.seam:
        base = _final(L, clip, ctrl, times)
        extras = review_extras(phase, base[-1][0], len(base))
        if stage == "nudge":
            xr = _subset(xray(phase), base, extras, -0.1)
            with _Counting(L, xr, float(opts.get("x_delta", 0.0))):
                report.append(("nudge", nudge_stage(L, clip, ctrl, times, extras, opts)))
        elif stage == "polish":
            xr = _subset(xray(phase), base, extras, -0.05)
            with _Counting(L, xr, float(opts.get("x_delta", 0.0))):
                report.append(("polish", polish_stage(L, clip, ctrl, times, extras, bool(opts.get("slide", False)), float(opts.get("margin", L.POLISH_MARGIN)), bool(opts.get("turn_cap", False)))))
        else:
            raise ValueError(stage)
    clip._seam = report
    return report


def polish_stage(L, clip, ctrl, times, extras, slide, margin, turn_cap=False):
    from scipy.optimize import minimize
    n = len(ctrl)
    rg = clip.rig
    wall = L.ARM_TORSO_REST + L.TORSO_WALL

    def frame_depth(i, world):
        d = max(L.arm_torso_world(rg, world, dense=True).values())
        for f_ in extras.get(i, ()):
            d = max(d, max(L.arm_torso_world(rg, f_(world), dense=True).values()))
        return d

    def sweep():
        sides, worlds, depth, mids, entry = L._polish_sweep(clip, ctrl)
        return sides, worlds, [frame_depth(i, w) for i, w in enumerate(worlds)], mids, entry
    sides, worlds, depth, mids, entry = sweep()
    bad = sorted({i for i in range(1, n - 1) if depth[i] > wall} | {j for i in range(n - 1) if mids[i] > wall for j in (i, i + 1) if 0 < j < n - 1})
    runs = []
    for i in bad:
        if runs and i - runs[-1][1] <= 2 * SEAM_PAD:
            runs[-1][1] = i
        else:
            runs.append([i, i])
    report = []
    for a, b in runs:
        if report:
            sides, worlds, depth, mids, entry = sweep()
        A, B = max(0, a - SEAM_PAD), min(n - 1, b + SEAM_PAD)
        first = len(report)
        kw = dict(extras=extras, slide=slide, **({"turn_cap": True} if turn_cap else {}))
        report.append(L._polish_window(clip, ctrl, times, A, B, sides, worlds, depth, mids, entry, wall - margin, minimize, **kw))
        print("shen_seam polish %s" % report[-1], flush=True)
        if not report[-1]["kept"]:
            report.append(L._polish_window(clip, ctrl, times, A, B, sides, worlds, depth, mids, entry, wall - margin, minimize, elbows_only=True, **kw))
            print("shen_seam polish %s" % report[-1], flush=True)
        if not any(r["kept"] for r in report[first:]):
            sides, worlds, depth, mids, entry = sweep()
            report.append(L._polish_window(clip, ctrl, times, A, B, sides, worlds, depth, mids, entry, wall - margin, minimize, seed=True, **kw))
            print("shen_seam polish %s" % report[-1], flush=True)
    return report


def _upper_turns(worlds):
    out = []
    for i in range(1, len(worlds)):
        r = {}
        for s in ("Right", "Left"):
            A = worlds[i - 1]["UpperTorso"][:3, :3].T @ worlds[i - 1][s + "UpperArm"][:3, :3]
            B = worlds[i]["UpperTorso"][:3, :3].T @ worlds[i][s + "UpperArm"][:3, :3]
            r[s] = math.degrees(math.acos(float(np.clip((np.trace(A.T @ B) - 1) / 2, -1, 1))))
        out.append(r)
    return out


def nudge_stage(L, clip, ctrl, times, extras, opts=None):
    opts = opts or {}
    rg = clip.rig
    n = len(ctrl)
    wall = L.ARM_TORSO_REST + L.TORSO_WALL
    log = []
    for side in ("Right", "Left"):
        sides, worlds, _d, _m, _e = L._polish_sweep(clip, ctrl)

        def tor(i, world):
            t = L.arm_torso_world(rg, world, dense=True)[side]
            for f_ in extras.get(i, ()):
                t = max(t, L.arm_torso_world(rg, f_(world), dense=True)[side])
            return t
        depth = [tor(i, w) for i, w in enumerate(worlds)]
        mids = [L.arm_torso_world(rg, L.joint_mix(rg, worlds[i], worlds[i + 1], 0.5), dense=True)[side] for i in range(n - 1)]
        bad = sorted({i for i in range(1, n - 1) if depth[i] > wall} | {j for i in range(n - 1) if mids[i] > wall for j in (i, i + 1) if 0 < j < n - 1})
        runs = []
        for i in bad:
            if runs and i - runs[-1][1] <= 3:
                runs[-1][1] = i
            else:
                runs.append([i, i])
        for a, b in runs:
            sides, worlds, _d, _m, _e = L._polish_sweep(clip, ctrl)
            res = _nudge(L, clip, ctrl, times, extras, sides, worlds, _upper_turns(worlds), side, a, b, opts)
            log.append((side, a, b, res))
            print("shen_seam nudge %s f%d-%d: %s" % (side, a, b, res), flush=True)
    return log


def _nudge(L, clip, ctrl, times, extras, sides, worlds, turns0, side, a, b, opts):
    sigmas = tuple(opts.get("sigmas", NUDGE_SIGMAS))
    rg = clip.rig
    n = len(ctrl)
    key = "rpole" if side == "Right" else None
    ctrl0 = [dict(c) for c in ctrl]
    part_s, part_w = (side + "UpperArm", side + "Hand")
    target = float(opts.get("target", NUDGE_TARGET))

    def axis(i):
        w = worlds[i]
        sh = (w[part_s] @ np.append(rg.JOINT[part_s], 1))[:3]
        wr = (w[part_w] @ np.append(rg.JOINT[part_w], 1))[:3]
        return L.unit(wr - sh)
    contact = {i for i in range(n) if any(abs(times[i] - t) < L.TILT_NEAR_CONTACT for t in clip.contacts)}

    def apply(i, deg, v, dl=0.0):
        c = dict(ctrl0[i])
        if abs(dl) > 1e-9:
            c["lsl"] = float(c["lsl"]) + dl
        if abs(deg) > 1e-9:
            k = key or ("lpole" if "lpole" in c else "lelb")
            if k not in c:
                return None
            c[k] = tuple(L.rodrigues(axis(i) * math.radians(deg)) @ np.asarray(c[k], float))
        if v is not None and i not in contact and float(np.abs(v).max()) > 1e-9:
            c["rp"] = tuple(np.asarray(c["rp"], float) + worlds[i]["UpperTorso"][:3, :3] @ v)
        return c

    def measure(i, c):
        clip._side = dict(sides[i])
        local, world, diag = clip.solve(dict(c))
        clip._side = None
        tr = L.arm_torso_world(rg, world, dense=True)
        for f_ in extras.get(i, ()):
            t2 = L.arm_torso_world(rg, f_(world), dense=True)
            tr = {s_: max(tr[s_], t2[s_]) for s_ in tr}
        return dict(tor=tr, clash=float(L.held_clash(clip, c)), arm_reach=float(diag.get("arm_reach", 0.0)), left_grip=float(diag.get("left_grip", 0.0)),
                    left_reach=float(diag.get("left_reach", 0.0)), wrist=float(L.ZR.angle_of(local["RightHand"][:3, :3])),
                    lwrist=float(L.ZR.angle_of(local["LeftHand"][:3, :3]))), world
    other = "Left" if side == "Right" else "Right"
    base = {}

    def check(i, m, in_run):
        bm = base[i]
        own_lim = target if in_run else max(target, bm["tor"][side])
        return [k for k, bad in (("own%.3f" % m["tor"][side], m["tor"][side] > own_lim), ("other", m["tor"][other] > max(target, bm["tor"][other]) + 1e-6),
                                 ("clash%.3f/%.3f" % (m["clash"], bm["clash"]), m["clash"] > max(L.CLASH_GRAZE, bm["clash"]) + 0.005),
                                 ("reach", m["arm_reach"] > max(0.02, bm["arm_reach"]) + 0.02), ("lgrip", m["left_grip"] > max(0.05, bm["left_grip"]) + 0.02),
                                 ("lreach", m["left_reach"] > max(0.05, bm["left_reach"]) + 0.02),
                                 ("wrist%.0f/%.0f" % (m["wrist"], bm["wrist"]), m["wrist"] > max(95.0, bm["wrist"])),
                                 ("lwrist", m["lwrist"] > max(95.0, bm["lwrist"]))) if bad]
    degs = [0.0] + [sg * d for d in opts.get("degs", NUDGE_DEGS) for sg in (1, -1)]
    slides = [0.0] + list(opts.get("slides", NUDGE_SLIDES))
    vecs = [None] + [L.ARM_TORSO_DIRS[j] * mg for mg in opts.get("mags", NUDGE_MAGS) for j in range(len(L.ARM_TORSO_DIRS))]
    cands = sorted(((abs(d) / 30.0 + (0.0 if v is None else float(np.linalg.norm(v)) / 0.1) + abs(dl) / 0.3, d, v, dl) for d in degs for v in vecs for dl in slides
                    if abs(d) > 0 or v is not None or abs(dl) > 0), key=lambda r: r[0])
    tried, screened = 0, 0
    for i in range(max(1, a - 12), min(n - 1, b + 13)):
        base[i] = measure(i, ctrl0[i])[0]
    run_ = list(range(a, b + 1))
    passing = []
    for cost, d, v, dl in cands:
        if len(passing) >= NUDGE_MAXPASS:
            break
        screened += 1
        fine = True
        for i in run_:
            c = apply(i, d, v, dl)
            if c is None or check(i, measure(i, c)[0], True):
                fine = False
                break
        if fine:
            passing.append((cost, d, v, dl))
    solved0 = L._solved(clip, ctrl, times)
    p0 = L.bake_pops(clip, solved0)
    for cost, d, v, dl in passing:
        for sigma in sigmas:
            tried += 1
            span = int(math.ceil(2.5 * sigma))
            frames = [i for i in range(max(1, a - span), min(n - 1, b + span + 1))]
            prof = {i: 1.0 if a <= i <= b else math.exp(-0.5 * ((i - (a if i < a else b)) / sigma) ** 2) for i in frames}
            ok, trial, W2 = True, {}, {}
            for i in frames:
                c = apply(i, d * prof[i], None if v is None else v * prof[i], dl * prof[i])
                m, w = measure(i, c)
                if check(i, m, a <= i <= b):
                    ok = False
                    break
                trial[i], W2[i] = c, w
            if not ok:
                continue
            Wall = [W2.get(i, worlds[i]) for i in range(n)]
            lo, hi = max(0, frames[0] - 1), min(n - 1, frames[-1] + 1)
            if any(max(L.arm_torso_world(rg, L.joint_mix(rg, Wall[i], Wall[i + 1], 0.5), dense=True).values()) > target + 0.01 for i in range(lo, hi)):
                continue
            t1 = _upper_turns(Wall)
            if any(t1[i][s_] > max(STEP_FREE, turns0[i][s_]) + 1.0 for i in range(lo, hi) for s_ in ("Right", "Left")):
                continue
            new = [dict(c) for c in ctrl]
            for i in frames:
                new[i] = trial[i]
            solved1 = L._solved(clip, new, times)
            outside = [i for i in range(n) if i not in frames and any(not np.allclose(np.asarray(solved0[i][2][p]), np.asarray(solved1[i][2][p]), atol=1e-7) for p in solved0[i][2])]
            p1 = L.bake_pops(clip, solved1)
            popped = [k for k in L.POP_LIMIT if p1[k][0] > max(p0[k][0], L.POP_LIMIT[k]) + 1e-6]
            if outside or popped:
                continue
            for i in frames:
                ctrl[i].clear()
                ctrl[i].update(trial[i])
            return dict(kept=True, sigma=sigma, deg=d, fist=None if v is None else np.round(v, 3).tolist(), slide=dl, frames=(frames[0], frames[-1]), screened=screened,
                        tried=tried, depth=(round(max(base[i]["tor"][side] for i in run_), 3), round(max(measure(i, trial[i])[0]["tor"][side] for i in run_), 3)))
    return dict(kept=False, screened=screened, passing=len(passing), tried=tried, depth0=round(max(base[i]["tor"][side] for i in run_), 3))


if __name__ == "__main__":
    # py tools/animation/opening_cast/shen_seam.py idle PHASE : bake Idle with the repo code and write review_idle_p<phase>.npz (the review fades' Idle)
    import sys
    sys.path.insert(0, str(ROOT / "tools/animation/opening_cast"))
    sys.path.insert(0, str(ROOT / "tools/animation/general_zhao"))
    os.chdir(ROOT)
    assert sys.argv[1] == "idle", sys.argv
    import shen_clips
    ph = int(sys.argv[2])
    clip = next(c for c in shen_clips.library() if c.name == "GrandmasterShen_P%d_Idle" % ph)
    write_idle(ph, clip.bake())
    print("review_idle_p%d.npz written" % ph)
