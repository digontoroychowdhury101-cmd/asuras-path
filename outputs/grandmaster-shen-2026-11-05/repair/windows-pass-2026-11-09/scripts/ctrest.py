# ctrest.py CACHE.pkl F0 F1 [SIDE] : (Windows pass 2026-11-10) on controls ctcache.py saved after the bake's first settle (STAGE settle), run the
# rest of the bake as Clip.bake does (swivel, the wrist_yield / settle / swivel rounds, clear_free_arm, clear_torso, slide_fist, tilt_haft, depop,
# close_loop, joint_polish when POLISH=1), the export's in-order solve and the repo's validate. Prints, for one hand (SIDE, default Left) over
# F0..F1: each recheck_runs window (the frames past the wall, the frames it re-chose, the arm's depth before and after) and the hand's turn from
# frame to frame after swivel and in the export. DEV=<overlay dir under SHEN_SCRATCH> puts a patched shen_lib.py / shen_clips.py first, so a
# variant of a stage is tried in minutes, not a 40-minute bake (the stages before the first swivel are not rerun: a full bake, runall.py, decides).
# SAVE=path writes the exported frames (revalidate.py format). Writes nothing in the repo.
import os, sys, time, pickle, inspect, textwrap
import numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D:
    sys.path.insert(0, (os.environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair") + "/" + D)
os.chdir(ROOT)
if os.environ.get("POLISH") != "1":
    os.environ["SHEN_JOINT_POLISH"] = "0"
import shen_clips as SC, shen_lib as L, castlib as C

cache = pickle.load(open(sys.argv[1], "rb"))
assert cache["stage"] == "settle", cache["stage"]
f0, f1 = int(sys.argv[2]), int(sys.argv[3])
SIDE = sys.argv[4] if len(sys.argv) > 4 else "Left"
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + cache["clip"])
for k, v in cache["state"].items():
    setattr(clip, k, v)
for kv in filter(None, os.environ.get("SET", "").split(";")):     # SET="attr=value;...": Clip opt-ins to try
    k, v = kv.split("=", 1)
    setattr(clip, k.strip(), eval(v))
times = cache["times"]
ctrl = [dict(c) for c in cache["ctrl"]]
n = len(ctrl)


def ang(A, B):
    R = A[:3, :3].T @ B[:3, :3]
    return float(np.degrees(np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1))))


def solved(ctrl):
    keep = clip._side
    clip._side = {}
    try:
        return {i: clip.solve(dict(ctrl[i]))[1] for i in range(max(0, f0), min(n - 1, f1 + 1) + 1)}
    finally:
        clip._side = keep


def turns(W):
    ks = sorted(W)
    return " ".join("%d:%.0f" % (i, ang(W[i][SIDE + "Hand"], W[j][SIDE + "Hand"])) for i, j in zip(ks, ks[1:]))


# recheck_runs with a log of each window it walks: the run past the wall, the window, and per frame the state kept or taken
src = textwrap.dedent(inspect.getsource(L.recheck_runs))
anchor = "        pick.reverse()\n"
assert anchor in src
src = src.replace(anchor, anchor + "        LOG.append((hand_side, list(run), list(win), [(i, opts[j][pick[j]][0], state.get(i)) for j, i in enumerate(win)]))\n", 1)
LOG = []
ns = dict(L.__dict__)
ns["LOG"] = LOG
exec(compile(src, "recheck_runs_probe", "exec"), ns)
probe_rr = ns["recheck_runs"]


def rr(clip_, ctrl_, hand_side, *a, **k):
    if hand_side != SIDE:
        return probe_rr(clip_, ctrl_, hand_side, *a, **k)
    d0 = {i: L.arm_torso(clip_, ctrl_[i])[hand_side] for i in range(max(0, f0), min(n - 1, f1) + 1)}
    LOG.clear()
    r = probe_rr(clip_, ctrl_, hand_side, *a, **k)
    for side, run, win, rows in LOG:
        if win[-1] < f0 or win[0] > f1:
            continue
        print("  recheck run %s window %d-%d:" % (run, win[0], win[-1]), flush=True)
        for i, s, was in rows:
            print("    f%d %s depth %.3f -> %.3f" % (i, "keep" if s is None else "take %s (was %s)" % (s, was), d0.get(i, float("nan")),
                                                    L.arm_torso(clip_, ctrl_[i])[hand_side]), flush=True)
    return r


L.recheck_runs = rr
t0 = time.time()
L.swivel(clip, ctrl)
for _ in range(3):
    if not L.wrist_yield(clip, ctrl, passes=1):
        break
    L.settle(clip, ctrl)
    L.swivel(clip, ctrl)
print("after swivel rounds  %s hand %s" % (SIDE, turns(solved(ctrl))), flush=True)
L.clear_free_arm(clip, ctrl)
L.clear_torso(clip, ctrl, times)
L.slide_fist(clip, ctrl)
L.tilt_haft(clip, ctrl, times)
if os.environ.get("SHEN_FINAL_SETTLE") == "1":
    L.settle(clip, ctrl)
L.depop(clip, ctrl, times)
L.close_loop(clip, ctrl)
L.joint_polish(clip, ctrl, times)
out = []
clip._side = {}
for t, c in zip(times, ctrl):
    local, world, diag = clip.solve(c)
    out.append([t, local, world, diag, c])
clip._side = None
L.derive_helpers(clip, out)
s, p = getattr(SC, "validate", C.validate)(clip, out)
W = {i: out[i][2] for i in range(max(0, f0), min(n - 1, f1 + 1) + 1)}
print("export %s hand %s" % (SIDE, turns(W)))
print("export depth R/L " + " ".join("%d:%.3f/%.3f" % (i, d["Right"], d["Left"]) for i, d in ((i, L.arm_torso_world(clip.rig, W[i], dense=True)) for i in sorted(W))))
print("REST %s torso R %.3f L %.3f between R %s L %s pops fist %.3f blade %.3f slide %.3f | %s (%.0fs)" % (
    cache["clip"], s.get("arm_in_torso_right", 0), s.get("arm_in_torso_left", 0), s.get("arm_in_torso_between_right"), s.get("arm_in_torso_between_left"),
    s.get("pop_fist", 0), s.get("pop_blade", 0), s.get("pop_slide", 0), p, time.time() - t0), flush=True)
if os.environ.get("SAVE"):
    pickle.dump(out, open(os.environ["SAVE"], "wb"))
