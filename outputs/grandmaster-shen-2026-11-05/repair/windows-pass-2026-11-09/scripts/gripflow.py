# gripflow.py CLIP F0 F1 [SIDE] : (Windows pass 2026-11-10) bake CLIP with the repo code (DEV=<dir under SHEN_SCRATCH> puts a patched
# shen_clips.py / shen_lib.py first) and after every bake stage (each swivel call too, and each recheck_runs inside it) print how far one hand
# (SIDE, default Left) and its forearm turn (world, degrees) from each frame to the next over F0..F1, each frame solved on its own, plus the
# grip and elbow state swivel's walk chose there. Shows which stage puts a sudden turn of the hand into a stretch that was smooth.
# SHEN_JOINT_POLISH=0 skips the polish (fast). Writes nothing.
import os, sys, time
import numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D:
    sys.path.insert(0, (os.environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair") + "/" + D)
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L

name, f0, f1 = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
SIDE = sys.argv[4] if len(sys.argv) > 4 else "Left"
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)


def ang(A, B):
    R = A[:3, :3].T @ B[:3, :3]
    return float(np.degrees(np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1))))


def turns(ctrl):
    keep = clip._side
    clip._side = {}
    W = {}
    try:
        for i in range(max(0, f0), min(len(ctrl) - 1, f1 + 1) + 1):
            W[i] = clip.solve(dict(ctrl[i]))[1]
    finally:
        clip._side = keep
    ks = sorted(W)
    return "hand " + " ".join("%d:%.0f" % (i, ang(W[i][SIDE + "Hand"], W[j][SIDE + "Hand"])) for i, j in zip(ks, ks[1:])) + \
        " | fore " + " ".join("%.0f" % ang(W[i][SIDE + "LowerArm"], W[j][SIDE + "LowerArm"]) for i, j in zip(ks, ks[1:]))


calls = {"swivel": 0}
for st in ("organic", "spine_reach", "settle", "swivel", "wrist_yield", "clear_free_arm", "clear_torso", "slide_fist", "tilt_haft", "depop", "close_loop", "joint_polish"):
    f = getattr(L, st)

    def wrap(*a, _f=f, _n=st, **k):
        r = _f(*a, **k)
        tag = _n
        if _n == "swivel":
            calls["swivel"] += 1
            tag = "swivel#%d" % calls["swivel"]
        print("%-15s %s" % (tag, turns(a[2] if _n == "organic" else a[1])), flush=True)
        return r
    setattr(L, st, wrap)

_rr = L.recheck_runs


def rr(clip_, ctrl, hand_side, live, path, *a, **k):
    if hand_side == SIDE:
        E, G16 = len(L.ELBOW_TURNS), len(L.GRIP_TURNS)
        st = []
        for i in range(f0, f1 + 1):
            if i in path:
                g, e = path[i]
                st.append("%d:(%g,%g,%g)" % (i, L.GRIP_SLANTS[g // G16], (g % G16) * 360.0 / G16, L.ELBOW_TURNS[e]))
        print("   walk path   %s" % " ".join(st), flush=True)
        print("   pre-recheck %s" % turns(ctrl), flush=True)
    r = _rr(clip_, ctrl, hand_side, live, path, *a, **k)
    if hand_side == SIDE:
        print("   recheck_runs changed %s frames: %s" % (r, turns(ctrl)), flush=True)
    return r


L.recheck_runs = rr
t0 = time.time()
out = clip.bake()
ks = list(range(max(0, f0), min(len(out) - 1, f1 + 1) + 1))
print("final in-order  hand " + " ".join("%d:%.0f" % (i, ang(out[i][2][SIDE + "Hand"], out[j][2][SIDE + "Hand"])) for i, j in zip(ks, ks[1:])))
print("%s %.0fs" % (name, time.time() - t0), flush=True)
