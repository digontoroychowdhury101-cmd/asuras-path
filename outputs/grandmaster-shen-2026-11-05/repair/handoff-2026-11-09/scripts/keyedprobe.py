# keyedprobe.py CLIP a:b : keyed controls only (no post passes), solved: arm-in-torso R/L and the fist in the chest frame; scratchpad/dev2 code
import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + "/dev2")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; a, b = [int(x) for x in sys.argv[2].split(":")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig; times = clip.frames(); clip._side = {}
row = []
for i in range(a, b + 1):
    t = dict(clip.controls(times[i])); _l, w, d = clip.solve(t); r = L.arm_torso_world(rg, w)
    Rc = w["UpperTorso"][:3, :3]; at = (w["UpperTorso"] @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
    row.append("%d:%.2f/%.2f z%.2f" % (i, r["Right"], r["Left"], ((np.asarray(t["rp"]) - at) @ Rc)[2]))
print(" ".join(row))
