import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, frs = sys.argv[1], [int(x) for x in sys.argv[2].split(",")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
rg = clip.rig
for fr in frs:
    t = clip.frames()[fr]; k = clip.controls(t); c = dict(k); clip._side = {}
    w = clip.solve(c)[1]
    sh = (w["RightUpperArm"] @ np.append(rg.JOINT["RightUpperArm"], 1))[:3] if "RightUpperArm" in w else None
    el = (w["RightLowerArm"] @ np.append(rg.JOINT["RightLowerArm"], 1))[:3]
    ha = (w["RightHand"] @ np.append(rg.JOINT["RightHand"], 1))[:3]
    ut = w["UpperTorso"]; ctr = (ut @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
    fwd = ut[:3, :3] @ np.array([0, 0, -1.0])
    print("f%d chest %s pelR %s | torso joint %s fwd %s | R shoulder %s elbow %s hand %s | fist %s" % (fr, np.round(k["chest"], 0), np.round(k["pelR"], 0), np.round(ctr, 2), np.round(fwd, 2), np.round(sh, 2), np.round(el, 2), np.round(ha, 2), np.round(c["rp"], 2)))
