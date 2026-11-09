import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; F = [int(x) for x in sys.argv[2].split(",")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
times = clip.frames(); ctrl = [clip.controls(t) for t in times]
L.organic(clip, times, ctrl); L.spine_reach(clip, ctrl)
def show(tag):
    clip._side = {}
    row = []
    for i, c in enumerate(ctrl):
        t2 = dict(c); _l, w, d = clip.solve(t2)
        if i in F:
            ut = w["UpperTorso"]; Rc = ut[:3, :3]; at = (ut @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
            row.append("f%d key %s -> %s" % (i, np.round((np.asarray(c["rp"]) - at) @ Rc, 2), np.round((np.asarray(t2["rp"]) - at) @ Rc, 2)))
    clip._side = None
    print(tag); print("   " + "\n   ".join(row), flush=True)
show("before settle (sequential solve)")
for p in range(5):
    L.settle(clip, ctrl, passes=1); show("after settle pass %d" % (p + 1))
