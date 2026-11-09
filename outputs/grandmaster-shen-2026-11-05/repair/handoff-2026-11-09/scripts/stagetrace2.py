# usage: stagetrace.py CLIP F1,F2,..   prints rp/haft/lt at those frames after each bake stage
import sys, os, numpy as np, time
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; fr = [int(x) for x in sys.argv[2].split(",")]
T0 = time.time()
def show(tag, ctrl):
    print("%-16s %5.0fs" % (tag, time.time() - T0), " ".join("f%d rp%s h%s" % (i, np.round(np.asarray(ctrl[i]["rp"], float), 2).tolist(), np.round(np.asarray(ctrl[i]["haft"], float), 2).tolist()) for i in fr), flush=True)
for st in ("organic", "spine_reach", "rest_on_floor", "settle", "swivel", "wrist_yield", "clear_free_arm", "clear_torso", "slide_fist", "tilt_haft", "depop", "close_loop"):
    f = getattr(L, st)
    def wrap(*a, _f=f, _n=st, **k):
        r = _f(*a, **k)
        ctrl = a[2] if _n in ("organic",) else a[1]
        show(_n, ctrl)
        return r
    setattr(L, st, wrap)
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
times = clip.frames(); ctrl0 = [clip.controls(t) for t in times]; show("keys", ctrl0)
out = clip.bake()
show("final-solve", [o[4] for o in out])
