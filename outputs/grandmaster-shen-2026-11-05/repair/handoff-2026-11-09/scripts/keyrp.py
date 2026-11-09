import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
rg = clip.rig
for i, t in enumerate(clip.frames()):
    c = clip.controls(t)
    local, world = {}, {"HumanoidRootPart": np.eye(4)}
    lt = rg.pivoted(world["HumanoidRootPart"], "LowerTorso", L.homog(L.euler(c["pelR"]), c["pel"]))
    ut = rg.pivoted(lt, "UpperTorso", L.homog(L.euler(c["chest"])))
    at = (ut @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
    q = (np.asarray(c["rp"]) - at) @ ut[:3, :3]
    h = np.asarray(c["haft"]) @ ut[:3, :3]
    sh = (ut @ np.append(rg.JOINT["RightUpperArm"], 1))[:3]; qs = (sh - at) @ ut[:3, :3]
    if i % 3 == 0: print("f%-2d keyed fist chest %s haft chest %s shoulderR %s" % (i, np.round(q, 2), np.round(h, 2), np.round(qs, 2)))
