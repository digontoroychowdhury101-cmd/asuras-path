import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
out = clip.bake()
ctrl = [o[4] for o in out]
clip._side = {}
seq = []
for c in ctrl:
    t2 = dict(c); _l, w, d = clip.solve(t2); seq.append((t2, w))
clip._side = None
for i, c in enumerate(ctrl):
    t2s, ws = seq[i]
    clip._side = {}; t2i = dict(c); _l, wi, di = clip.solve(t2i); clip._side = None
    ut = ws["UpperTorso"]; Rc = ut[:3, :3]; at = (ut @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
    f = lambda p: np.round((np.asarray(p) - at) @ Rc, 2)
    a_s = L.arm_torso_world(rg, ws); a_i = L.arm_torso_world(rg, wi)
    print("f%-2d key %s seq %s (R%.2f) ind %s (R%.2f)" % (i, f(c["rp"]), f(t2s["rp"]), a_s["Right"], f(t2i["rp"]), a_i["Right"]))
