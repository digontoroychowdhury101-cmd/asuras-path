"""Replay a clip's bake, printing the hands' frame-to-frame turn (in the hand's own key, i.e. relative to the haft solve) after each pass."""
import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, lo, hi = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
def ang(R): return float(np.degrees(np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1))))
fixed_log = {}
orig_ssc = L.smoothed_arm_clash
def snap(tag, ctrl):
    for key in ("rhand", "lhand"):
        if not all(key in c for c in ctrl):
            continue
        H = [np.asarray(c[key]) for c in ctrl]
        v = [ang(H[i - 1].T @ H[i]) for i in range(1, len(H))]
        print("%-14s %s %s" % (tag, key, " ".join("%3.0f" % v[i - 1] for i in range(max(lo, 1), min(hi, len(H) - 1) + 1))))
times = clip.frames(); ctrl = [clip.controls(t) for t in times]
L.organic(clip, times, ctrl); L.spine_reach(clip, ctrl)
if clip.floor_body: L.rest_on_floor(clip, ctrl)
L.settle(clip, ctrl)
# instrumented swivel: report the repair-pass frames
_orig = L.swivel
def sw(clip, ctrl):
    before = getattr(clip, "_swivel_unsmoothed", 0)
    _orig(clip, ctrl)
    print("  swivel repair frames:", getattr(clip, "_swivel_unsmoothed", 0) - before)
L.swivel = sw
print("frames %d..%d" % (lo, hi))
L.swivel(clip, ctrl); snap("swivel", ctrl)
for k in range(3):
    if not L.wrist_yield(clip, ctrl, passes=1): break
    L.settle(clip, ctrl); L.swivel(clip, ctrl); snap("swivel%d" % (k + 2), ctrl)
L.clear_free_arm(clip, ctrl); snap("clear_free", ctrl)
L.slide_fist(clip, ctrl); snap("slide_fist", ctrl)
L.tilt_haft(clip, ctrl, times); snap("tilt_haft", ctrl)
