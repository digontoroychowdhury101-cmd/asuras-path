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
    row = []
    for i in F:
        c = ctrl[i]
        clip._side = {}; t2 = dict(c); _l, w, d = clip.solve(t2); clip._side = None
        a = L.arm_torso_world(rg, w)
        e = {sd: float(L.elbow_torso(rg, t2, sd).min()) for sd in ("Right", "Left")}
        ut = w["UpperTorso"]; at = (ut @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
        q = (np.asarray(c["rp"]) - at) @ ut[:3, :3]
        row.append("f%d act %.2f/%.2f best %.2f/%.2f fist %s" % (i, a["Right"], a["Left"], e["Right"], e["Left"], np.round(q, 2)))
    print(tag); print("   " + "\n   ".join(row), flush=True)
show("after organic+spine_reach")
L.clear_torso(clip, ctrl, times, early=True); show("after early clear_torso")
L.settle(clip, ctrl); show("after settle")
L.swivel(clip, ctrl); show("after swivel")
