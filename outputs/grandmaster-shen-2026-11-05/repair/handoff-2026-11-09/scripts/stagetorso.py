# usage: stagetorso.py CLIP a:b   arm-in-torso (R/L) per frame after each bake stage (sequential solve, fresh side memory); SHEN_DEV=1 uses scratchpad/dev
import sys, os, numpy as np, time
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
if os.environ.get("SHEN_DEV"): sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + "/dev")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; a, b = [int(x) for x in sys.argv[2].split(":")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
T0 = time.time()
def show(tag, ctrl):
    keep = getattr(clip, "_side", None); clip._side = {}
    row = []
    for i in range(len(ctrl)):
        c = dict(ctrl[i]); _l, world, _d = clip.solve(c)
        if a <= i <= b:
            d = L.arm_torso_world(clip.rig, world); row.append("%d:%.2f/%.2f" % (i, d["Right"], d["Left"]))
    clip._side = keep
    print("%-15s %4.0fs" % (tag, time.time() - T0), " ".join(row), flush=True)
for st in ("organic", "spine_reach", "settle", "swivel", "wrist_yield", "clear_free_arm", "clear_torso", "slide_fist", "tilt_haft", "depop", "close_loop"):
    f = getattr(L, st)
    def wrap(*args, _f=f, _n=st, **k):
        r = _f(*args, **k)
        show(_n, args[2] if _n == "organic" else args[1])
        return r
    setattr(L, st, wrap)
out = clip.bake()
show("final", [o[4] for o in out])
