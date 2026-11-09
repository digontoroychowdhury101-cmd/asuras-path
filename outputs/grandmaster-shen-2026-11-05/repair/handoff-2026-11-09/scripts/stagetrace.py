# stagetrace.py CLIP F1,F2,... : bake CLIP (DEV / ARC_PATCH / ARC_CARRY as torsotest_patch) and after every stage solve the given frames alone;
# their fist (rp), slide and arm-in-torso R/L, to find the pass that puts an arm in his chest
import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D: sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + "/" + D)
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, frs = sys.argv[1], [int(x) for x in sys.argv[2].split(",")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
def show(tag, ctrl):
    keep = clip._side; clip._side = {}
    try:
        row = []
        for f in frs:
            c = dict(ctrl[f]); w = clip.solve(c)[1]; tor = L.arm_torso_world(clip.rig, w)
            row.append("f%d rp %s rsl %.2f R %.2f L %.2f" % (f, np.round(c["rp"], 2), float(c["rsl"]), tor["Right"], tor["Left"]))
        print("%-15s %s" % (tag, " | ".join(row)), flush=True)
    finally:
        clip._side = keep
show("keyed", [clip.controls(t) for t in clip.frames()])
for _st in ("organic", "spine_reach", "settle", "swivel", "wrist_yield", "clear_free_arm", "clear_torso", "slide_fist", "tilt_haft", "depop", "close_loop"):
    _f = getattr(L, _st)
    def _w(*a, _f=_f, _n=_st, **k):
        r = _f(*a, **k)
        show(_n, a[2] if _n == "organic" else a[1])
        return r
    setattr(L, _st, _w)
out = clip.bake()
row = []
for f in frs:
    tor = L.arm_torso_world(clip.rig, out[f][2]); row.append("f%d rp %s R %.2f L %.2f" % (f, np.round(out[f][4]["rp"], 2), tor["Right"], tor["Left"]))
print("%-15s %s" % ("final", " | ".join(row)))
